import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import Testing

private enum EndpointStyle: Sendable, CaseIterable {
    case manual
    #if Macros
    case macro
    #endif
}

#if Macros
@ProtobufAPIDefinition(method: .post, path: "/protobuf", auth: .anonymous)
private struct AnonymousCompatibilityEndpoint {
    typealias APIResponse = TestUserResponse
    let body: TestUserRequest
    let requestOptions: EncodedRequestOptions
    var protobufOptions: ProtobufCodingOptions { .init(allowsMissingContentType: true) }
}
@ProtobufAPIDefinition(method: .post, path: "/protobuf", auth: .required)
private struct RequiredCompatibilityEndpoint {
    typealias APIResponse = TestUserResponse
    let body: TestUserRequest
    let requestOptions: EncodedRequestOptions
    var protobufOptions: ProtobufCodingOptions { .init(allowsMissingContentType: true) }
}
@ProtobufAPIDefinition(method: .post, path: "/protobuf", auth: .optional)
private struct OptionalCompatibilityEndpoint {
    typealias APIResponse = TestUserResponse
    let body: TestUserRequest
    let requestOptions: EncodedRequestOptions
    var protobufOptions: ProtobufCodingOptions { .init(allowsMissingContentType: true) }
}
#endif

private func executeCompatibility(
    client: DefaultNetworkClient, style: EndpointStyle,
    authentication: SessionAuthentication = .anonymous, idempotencyKey: String? = nil
) async throws -> TestUserResponse {
    switch style {
    case .manual:
        return try await client.request(
            CompatibilityRequest(sessionAuthentication: authentication, idempotencyKey: idempotencyKey))
    #if Macros
    case .macro:
        var headers = HTTPHeaders.default
        if let idempotencyKey { headers.update(name: "Idempotency-Key", value: idempotencyKey) }
        let options = EncodedRequestOptions(headers: headers)
        let body = TestUserRequest(userID: 42)
        switch authentication {
        case .anonymous:
            return try await client.request(AnonymousCompatibilityEndpoint(body: body, requestOptions: options))
        case .required:
            return try await client.request(RequiredCompatibilityEndpoint(body: body, requestOptions: options))
        case .optional:
            return try await client.request(OptionalCompatibilityEndpoint(body: body, requestOptions: options))
        }
    #endif
    }
}

private func CompatibilityRequest(
    sessionAuthentication: SessionAuthentication = .anonymous, idempotencyKey: String? = nil
) throws(NetworkError) -> EncodedRequest<TestUserResponse> {
    var headers = HTTPHeaders.default
    if let idempotencyKey {
        headers.update(name: "Idempotency-Key", value: idempotencyKey)
    }
    return try .protobuf(
        method: .post, path: "/protobuf", auth: sessionAuthentication,
        body: TestUserRequest(userID: 42), codec: .init(allowsMissingContentType: true),
        options: .init(headers: headers))
}

private actor CompatibilityTokenStore {
    private var token = "old"
    private(set) var refreshCount = 0

    func current() -> String { token }

    func refresh() -> String {
        token = "new"
        refreshCount += 1
        return token
    }
}

@Suite("InnoNetwork 6 public adapter compatibility")
struct InnoNetwork6CompatibilityTests {
    @Test("Required auth fails before transport when no policy is configured", arguments: EndpointStyle.allCases)
    fileprivate func requiredAuthenticationFailsClosed(style: EndpointStyle) async throws {
        let session = MockURLSession()
        let client = DefaultNetworkClient(configuration: configuration(), session: session)
        do {
            _ = try await executeCompatibility(client: client, style: style, authentication: .required)
            Issue.record("Required authentication unexpectedly sent a request")
        } catch NetworkError.configuration(reason: .invalidRequest) {
            #expect(session.capturedRequestsInOrder.isEmpty)
        }
    }

    @Test("Anonymous endpoints never invoke a configured token policy", arguments: EndpointStyle.allCases)
    fileprivate func anonymousSkipsTokenPolicy(style: EndpointStyle) async throws {
        let session = MockURLSession()
        session.setMockResponse(statusCode: 200, data: try responseData())
        let policy = RefreshTokenPolicy(
            currentToken: {
                Issue.record("Anonymous request read a token")
                return "unexpected"
            },
            refreshToken: {
                Issue.record("Anonymous request refreshed a token")
                return "unexpected"
            }
        )
        let client = DefaultNetworkClient(configuration: configuration(auth: policy), session: session)
        let result = try await executeCompatibility(client: client, style: style)
        #expect(result.userID == 42)
        #expect(session.capturedRequestsInOrder.count == 1)
        #expect(session.capturedRequest?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test(
        "Authenticated replay preserves protobuf bytes",
        arguments: [SessionAuthentication.required, .optional], EndpointStyle.allCases)
    fileprivate func refreshPreservesBinaryBody(authentication: SessionAuthentication, style: EndpointStyle)
        async throws
    {
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(statusCode: 401),
            .http(statusCode: 200, data: try responseData()),
        ])
        let tokens = CompatibilityTokenStore()
        let policy = RefreshTokenPolicy(
            currentToken: { await tokens.current() },
            refreshToken: { await tokens.refresh() }
        )
        let client = DefaultNetworkClient(configuration: configuration(auth: policy), session: session)
        let result = try await executeCompatibility(client: client, style: style, authentication: authentication)
        #expect(result.userID == 42)
        #expect(await tokens.refreshCount == 1)
        let requests = session.capturedRequestsInOrder
        try #require(requests.count == 2)
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer old")
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer new")
        let expectedBody = try TestUserRequest(userID: 42).serializedData()
        #expect(requests.allSatisfy { $0.httpBody == expectedBody })
        #expect(
            requests.allSatisfy {
                $0.value(forHTTPHeaderField: "Content-Type") == "application/protobuf"
            })
    }

    @Test("Decode failure preserves the 6.0 stage and HTTP response", arguments: EndpointStyle.allCases)
    fileprivate func structuredDecodingFailure(style: EndpointStyle) async throws {
        let session = MockURLSession()
        session.setMockResponse(statusCode: 200, data: Data([0xFF]))
        let client = DefaultNetworkClient(configuration: configuration(), session: session)
        do {
            _ = try await executeCompatibility(client: client, style: style)
            Issue.record("Malformed protobuf unexpectedly decoded")
        } catch NetworkError.decoding(let stage, _, let response) {
            #expect(stage == .responseBody)
            #expect(response.statusCode == 200)
        }
    }

    @Test("Pre-cancelled protobuf request does not reach transport", arguments: EndpointStyle.allCases)
    fileprivate func cancellationBeforeTransport(style: EndpointStyle) async throws {
        let session = MockURLSession()
        let client = DefaultNetworkClient(configuration: configuration(), session: session)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await executeCompatibility(client: client, style: style)
        }
        do {
            _ = try await task.value
            Issue.record("Cancelled request unexpectedly succeeded")
        } catch NetworkError.cancelled {
            #expect(session.capturedRequestsInOrder.isEmpty)
        }
    }

    @Test("POST timeout replay requires an idempotency key", arguments: [false, true], EndpointStyle.allCases)
    fileprivate func retrySafety(hasKey: Bool, style: EndpointStyle) async throws {
        let session = MockURLSession()
        session.setScriptedResponses([
            .failure(URLError(.timedOut)),
            .http(statusCode: 200, data: try responseData()),
        ])
        let retry = ExponentialBackoffRetryPolicy(maxRetries: 1, retryDelay: 0, jitterRatio: 0)
        let client = DefaultNetworkClient(configuration: configuration(retry: retry), session: session)
        if hasKey {
            let result = try await executeCompatibility(
                client: client, style: style, idempotencyKey: "compatibility-42")
            #expect(result.userID == 42)
            let attempts = session.capturedRequestsInOrder
            #expect(attempts.count == 2)
            #expect(
                attempts.allSatisfy {
                    $0.value(forHTTPHeaderField: "Idempotency-Key") == "compatibility-42"
                })
            #expect(attempts.first?.httpBody == attempts.last?.httpBody)
        } else {
            do {
                _ = try await executeCompatibility(client: client, style: style)
                Issue.record("Unsafe POST unexpectedly retried")
            } catch NetworkError.timeout {
                #expect(session.capturedRequestsInOrder.count == 1)
            }
        }
    }

    private func responseData() throws -> Data {
        try TestUserResponse(userID: 42, name: "Compatibility", email: "test@example.com")
            .serializedData()
    }

    private func configuration(auth: RefreshTokenPolicy? = nil, retry: RetryPolicy? = nil)
        -> NetworkConfiguration
    {
        .advanced(
            baseURL: URL(string: "https://example.com")!,
            resilience: ResiliencePack(retry: retry),
            auth: AuthPack(refreshToken: auth)
        )
    }
}
