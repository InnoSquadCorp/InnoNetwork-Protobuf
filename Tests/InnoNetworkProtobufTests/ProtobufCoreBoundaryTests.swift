import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import Testing

#if Macros
@ProtobufAPIDefinition(method: .get, path: "/value", auth: .anonymous)
private struct CachedValueEndpoint {
    typealias APIResponse = Google_Protobuf_StringValue
    let requestOptions: EncodedRequestOptions
    let protobufOptions: ProtobufCodingOptions
}
#endif

private enum BoundaryEndpointStyle: CaseIterable, Sendable {
    #if Macros
    case macro
    #endif
    case manual
}

@Suite("Protobuf/Core cache and decoding boundaries")
struct ProtobufCoreBoundaryTests {
    private let baseURL = URL(string: "https://example.com")!
    private let endpointURL = URL(string: "https://example.com/value")!

    private func message() -> Google_Protobuf_StringValue {
        var value = Google_Protobuf_StringValue()
        value.value = "binary-value"
        return value
    }

    private func client(
        _ session: MockURLSession, auth: AuthPack = .init(), honorsRequestFreshness: Bool = false
    ) -> DefaultNetworkClient {
        let policy = ResponseCachePolicy.rfc9111Compliant(wrapping: .cacheFirst(maxAge: .seconds(60)))
        return DefaultNetworkClient(
            configuration: .advanced(
                baseURL: baseURL, auth: auth,
                cache: .init(
                    responseCachePolicy: honorsRequestFreshness
                        ? .requestFreshness(wrapping: policy) : policy,
                    responseCache: InMemoryResponseCache(), captureFailurePayload: false)),
            session: session)
    }

    private func execute(
        _ client: DefaultNetworkClient, style: BoundaryEndpointStyle,
        limit: Int64? = nil, options: EncodedRequestOptions = .init()
    ) async throws -> Google_Protobuf_StringValue {
        let codec = ProtobufCodingOptions(maximumResponseBytes: limit)
        switch style {
        #if Macros
        case .macro:
            return try await client.request(
                CachedValueEndpoint(requestOptions: options, protobufOptions: codec))
        #endif
        case .manual:
            return try await client.request(
                EncodedRequest<Google_Protobuf_StringValue>.protobuf(
                    method: .get, path: "/value", auth: .anonymous, codec: codec, options: options))
        }
    }

    @Test(
        "304 keeps binary bytes and media type, then becomes a cache hit",
        arguments: BoundaryEndpointStyle.allCases)
    fileprivate func binaryRevalidation(style: BoundaryEndpointStyle) async throws {
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(
                statusCode: 200, data: try message().serializedData(),
                headers: [
                    "Content-Type": "application/protobuf", "Cache-Control": "no-cache", "ETag": "\"v1\"",
                ],
                url: endpointURL),
            .http(
                statusCode: 304, headers: ["ETag": "\"v1\"", "Cache-Control": "max-age=60"],
                url: endpointURL),
        ])
        let core = client(session)
        #expect(try await execute(core, style: style) == message())
        #expect(try await execute(core, style: style) == message())
        #expect(session.capturedRequestsInOrder.count == 2)
        #expect(session.capturedRequest?.value(forHTTPHeaderField: "If-None-Match") == "\"v1\"")
        #expect(try await execute(core, style: style) == message())
        #expect(session.capturedRequestsInOrder.count == 2)
    }

    @Test(
        "JSON and Protobuf at one URI keep separate representations",
        arguments: BoundaryEndpointStyle.allCases)
    fileprivate func mediaCacheIsolation(style: BoundaryEndpointStyle) async throws {
        struct JSONValue: Codable, Sendable { let value: String }
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(
                statusCode: 200, data: try message().serializedData(),
                headers: [
                    "Content-Type": "application/protobuf", "Cache-Control": "max-age=60", "Vary": "Accept",
                ],
                url: endpointURL),
            .http(
                statusCode: 200, data: Data(#"{"value":"json-value"}"#.utf8),
                headers: [
                    "Content-Type": "application/json", "Cache-Control": "max-age=60", "Vary": "Accept",
                ],
                url: endpointURL),
        ])
        let core = client(session)
        var jsonOptions = EncodedRequestOptions()
        jsonOptions.headers.update(name: "Accept", value: "application/json")
        let json = EncodedRequest<JSONValue>(
            method: .get, path: "/value", auth: .anonymous, options: jsonOptions,
            responseDecoder: .json(decoder: JSONDecoder()))
        #expect(try await execute(core, style: style) == message())
        #expect(try await core.request(json).value == "json-value")
        #expect(try await execute(core, style: style) == message())
        #expect(try await core.request(json).value == "json-value")
        let requests = session.capturedRequestsInOrder
        #expect(requests.count == 2)
        #expect(
            requests.map { $0.value(forHTTPHeaderField: "Accept") } == [
                "application/protobuf", "application/json",
            ])
        #expect(
            requests.first?.value(forHTTPHeaderField: "Accept-Language")
                == requests.last?.value(forHTTPHeaderField: "Accept-Language"))
    }

    @Test(
        "Cache hits cannot bypass a stricter caller byte limit",
        arguments: BoundaryEndpointStyle.allCases)
    fileprivate func cachedResponseLimit(style: BoundaryEndpointStyle) async throws {
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(
                statusCode: 200, data: try message().serializedData(),
                headers: ["Content-Type": "application/protobuf", "Cache-Control": "max-age=60"],
                url: endpointURL)
        ])
        let core = client(session)
        #expect(try await execute(core, style: style, limit: 100) == message())
        do {
            _ = try await execute(core, style: style, limit: 1)
            Issue.record("Cached bytes bypassed caller cap")
        } catch NetworkError.underlying(let error, _) {
            #expect(error.code == NetworkErrorCode.responseBodyLimitExceeded.rawValue)
        }
        #expect(try await execute(core, style: style, limit: 100) == message())
        #expect(session.capturedRequestsInOrder.count == 1)
    }

    @Test(
        "Response and decoding interceptors cannot bypass byte limits",
        arguments: BoundaryEndpointStyle.allCases, [false, true])
    fileprivate func transformedResponseLimit(style: BoundaryEndpointStyle, afterResponse: Bool)
        async throws
    {
        struct ExpandResponse: ResponseInterceptor {
            let bytes: Data
            func adapt(_ response: Response, request: URLRequest) async throws -> Response {
                Response(
                    statusCode: response.statusCode, data: bytes, request: request,
                    response: try #require(response.response))
            }
        }
        struct ExpandDecode: DecodingInterceptor {
            let bytes: Data
            func willDecode(data: Data, response: Response) async throws -> Data { bytes }
        }
        let bytes = try message().serializedData()
        let auth =
            afterResponse
            ? AuthPack(additionalResponseInterceptors: [ExpandResponse(bytes: bytes)])
            : AuthPack(additionalDecodingInterceptors: [ExpandDecode(bytes: bytes)])
        let session = MockURLSession()
        session.setScriptedResponses(
            Array(
                repeating: .http(
                    statusCode: 200,
                    headers: ["Content-Type": "application/protobuf", "Cache-Control": "no-store"],
                    url: endpointURL), count: 2))
        let core = client(session, auth: auth)
        do {
            _ = try await execute(core, style: style, limit: 1)
            Issue.record("Transformed bytes bypassed caller cap")
        } catch NetworkError.underlying(let error, _) {
            #expect(error.code == NetworkErrorCode.responseBodyLimitExceeded.rawValue)
        }
        #expect(try await execute(core, style: style, limit: 100) == message())
    }

    @Test(
        "Malformed-message errors redact bytes and preserve their category",
        arguments: BoundaryEndpointStyle.allCases)
    fileprivate func decodingPrivacy(style: BoundaryEndpointStyle) async throws {
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(
                statusCode: 200, data: Data([0xff]),
                headers: ["Content-Type": "application/protobuf", "Cache-Control": "no-store"],
                url: endpointURL),
            .http(
                statusCode: 200, data: try message().serializedData(),
                headers: ["Content-Type": "application/protobuf"], url: endpointURL),
        ])
        let core = client(session)
        do {
            _ = try await execute(core, style: style)
            Issue.record("Malformed message accepted")
        } catch NetworkError.decoding(let stage, let error, let response) {
            #expect(stage == .responseBody)
            #expect(error.domain == EncodedPayloadFailure.errorDomain)
            #expect(error.code == EncodedPayloadFailure.decoding.rawValue)
            #expect(response.data.isEmpty)
        }
        #expect(try await execute(core, style: style) == message())
        #expect(session.capturedRequestsInOrder.count == 2)
    }

    @Test(
        "Explicit freshness recovers malformed cached bytes without changing representation identity",
        arguments: BoundaryEndpointStyle.allCases)
    fileprivate func cacheRecovery(style: BoundaryEndpointStyle) async throws {
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(
                statusCode: 200, data: Data([0xff]),
                headers: ["Content-Type": "application/protobuf", "Cache-Control": "max-age=60"],
                url: endpointURL),
            .http(
                statusCode: 200, data: try message().serializedData(),
                headers: ["Content-Type": "application/protobuf", "Cache-Control": "max-age=60"],
                url: endpointURL),
        ])
        let core = client(session, honorsRequestFreshness: true)
        for _ in 0..<2 {
            do {
                _ = try await execute(core, style: style)
                Issue.record("Malformed bytes accepted")
            } catch NetworkError.decoding(_, _, _) {}
        }
        #expect(session.capturedRequestsInOrder.count == 1)
        var freshOptions = EncodedRequestOptions()
        freshOptions.headers.update(name: "Cache-Control", value: "no-cache")
        #expect(try await execute(core, style: style, options: freshOptions) == message())
        let requests = session.capturedRequestsInOrder
        #expect(requests.count == 2)
        #expect(requests.last?.value(forHTTPHeaderField: "Cache-Control") == "no-cache")
        #expect(
            requests.first?.value(forHTTPHeaderField: "Accept-Language")
                == requests.last?.value(forHTTPHeaderField: "Accept-Language"))
        #expect(try await execute(core, style: style) == message())
        #expect(session.capturedRequestsInOrder.count == 2)
    }
}
