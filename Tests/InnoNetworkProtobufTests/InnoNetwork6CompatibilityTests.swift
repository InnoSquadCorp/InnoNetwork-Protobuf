import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import Testing

private struct CompatibilityRequest: ProtobufAPIDefinition {
    typealias Parameter = TestUserRequest
    typealias APIResponse = TestUserResponse

    var parameters: TestUserRequest? { TestUserRequest(userID: 42) }
    var method: HTTPMethod { .post }
    var path: String { "/protobuf" }
    var sessionAuthentication: SessionAuthentication = .anonymous
    var idempotencyKey: String?
    var headers: HTTPHeaders {
        var result = HTTPHeaders.default
        result.add(.contentType(ContentType.protobuf.rawValue))
        if let idempotencyKey {
            result.add(HTTPHeader(name: "Idempotency-Key", value: idempotencyKey))
        }
        return result
    }
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
    @Test("Required auth fails before transport when no policy is configured")
    func requiredAuthenticationFailsClosed() async throws {
        let session = MockURLSession()
        let client = DefaultNetworkClient(configuration: configuration(), session: session)
        do {
            _ = try await client.protobufRequest(CompatibilityRequest(sessionAuthentication: .required))
            Issue.record("Required authentication unexpectedly sent a request")
        } catch NetworkError.configuration(reason: .invalidRequest) {
            #expect(session.capturedRequestsInOrder.isEmpty)
        }
    }

    @Test("Anonymous endpoints never invoke a configured token policy")
    func anonymousSkipsTokenPolicy() async throws {
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
        let result = try await client.protobufRequest(CompatibilityRequest())
        #expect(result.userID == 42)
        #expect(session.capturedRequestsInOrder.count == 1)
        #expect(session.capturedRequest?.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test("Authenticated replay preserves protobuf bytes", arguments: [SessionAuthentication.required, .optional])
    func refreshPreservesBinaryBody(authentication: SessionAuthentication) async throws {
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
        let result = try await client.protobufRequest(CompatibilityRequest(sessionAuthentication: authentication))
        #expect(result.userID == 42)
        #expect(await tokens.refreshCount == 1)
        let requests = session.capturedRequestsInOrder
        try #require(requests.count == 2)
        #expect(requests[0].value(forHTTPHeaderField: "Authorization") == "Bearer old")
        #expect(requests[1].value(forHTTPHeaderField: "Authorization") == "Bearer new")
        let expectedBody = try TestUserRequest(userID: 42).serializedData()
        #expect(requests.allSatisfy { $0.httpBody == expectedBody })
        #expect(requests.allSatisfy {
            $0.value(forHTTPHeaderField: "Content-Type") == "application/x-protobuf"
        })
    }

    @Test("Decode failure preserves the 6.0 stage and HTTP response")
    func structuredDecodingFailure() async throws {
        let session = MockURLSession()
        session.setMockResponse(statusCode: 200, data: Data([0xFF]))
        let client = DefaultNetworkClient(configuration: configuration(), session: session)
        do {
            _ = try await client.protobufRequest(CompatibilityRequest())
            Issue.record("Malformed protobuf unexpectedly decoded")
        } catch NetworkError.decoding(let stage, _, let response) {
            #expect(stage == .responseBody)
            #expect(response.statusCode == 200)
        }
    }

    @Test("Pre-cancelled protobuf request does not reach transport")
    func cancellationBeforeTransport() async throws {
        let session = MockURLSession()
        let client = DefaultNetworkClient(configuration: configuration(), session: session)
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await client.protobufRequest(CompatibilityRequest())
        }
        do {
            _ = try await task.value
            Issue.record("Cancelled request unexpectedly succeeded")
        } catch NetworkError.cancelled {
            #expect(session.capturedRequestsInOrder.isEmpty)
        }
    }

    @Test("POST timeout replay requires an idempotency key", arguments: [false, true])
    func retrySafety(hasKey: Bool) async throws {
        let session = MockURLSession()
        session.setScriptedResponses([
            .failure(URLError(.timedOut)),
            .http(statusCode: 200, data: try responseData()),
        ])
        let retry = ExponentialBackoffRetryPolicy(maxRetries: 1, retryDelay: 0, jitterRatio: 0)
        let client = DefaultNetworkClient(configuration: configuration(retry: retry), session: session)
        let request = CompatibilityRequest(idempotencyKey: hasKey ? "compatibility-42" : nil)
        if hasKey {
            let result = try await client.protobufRequest(request)
            #expect(result.userID == 42)
            let attempts = session.capturedRequestsInOrder
            #expect(attempts.count == 2)
            #expect(attempts.allSatisfy {
                $0.value(forHTTPHeaderField: "Idempotency-Key") == "compatibility-42"
            })
            #expect(attempts.first?.httpBody == attempts.last?.httpBody)
        } else {
            do {
                _ = try await client.protobufRequest(request)
                Issue.record("Unsafe POST unexpectedly retried")
            } catch NetworkError.timeout {
                #expect(session.capturedRequestsInOrder.count == 1)
            }
        }
    }

    private func responseData() throws -> Data {
        try TestUserResponse(userID: 42, name: "Compatibility", email: "test@example.com").serializedData()
    }

    private func configuration(auth: RefreshTokenPolicy? = nil, retry: RetryPolicy? = nil) -> NetworkConfiguration {
        .advanced(
            baseURL: URL(string: "https://example.com")!,
            resilience: ResiliencePack(retry: retry),
            auth: AuthPack(refreshToken: auth)
        )
    }
}
