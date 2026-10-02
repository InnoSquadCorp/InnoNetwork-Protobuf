import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf

// BEGIN CACHE_RECOVERY_EXAMPLE
@ProtobufAPIDefinition(method: .get, path: "/cached-value", auth: .anonymous)
struct CachedValue {
    typealias APIResponse = Google_Protobuf_StringValue
    let requestOptions: EncodedRequestOptions
}

func refreshCachedValue(using client: DefaultNetworkClient) async throws
    -> Google_Protobuf_StringValue
{
    // The client must opt into .requestFreshness(wrapping: ...).
    var options = EncodedRequestOptions()
    // Update one field: retain the representation's default headers.
    options.headers.update(name: "Cache-Control", value: "no-cache")
    return try await client.request(CachedValue(requestOptions: options))
}
// END CACHE_RECOVERY_EXAMPLE

func runCacheRecoveryExample() async throws {
    let session = MockURLSession()
    let url = URL(string: "https://example.com/cached-value")!
    var expected = Google_Protobuf_StringValue()
    expected.value = "recovered"
    session.setScriptedResponses([
        .http(
            statusCode: 200, data: Data([0xff]),
            headers: ["Content-Type": "application/protobuf", "Cache-Control": "max-age=60"], url: url),
        .http(
            statusCode: 200, data: try expected.serializedData(),
            headers: ["Content-Type": "application/protobuf", "Cache-Control": "max-age=60"], url: url),
    ])
    let client = DefaultNetworkClient(
        configuration: .advanced(
            baseURL: URL(string: "https://example.com")!,
            cache: .init(
                responseCachePolicy: .requestFreshness(
                    wrapping: .rfc9111Compliant(wrapping: .cacheFirst(maxAge: .seconds(60)))),
                responseCache: InMemoryResponseCache(), captureFailurePayload: false)),
        session: session)
    do {
        for _ in 0..<2 {
            do {
                _ = try await client.request(CachedValue(requestOptions: .init()))
                throw CacheRecoveryFailure.malformedMessageAccepted
            } catch NetworkError.decoding(let stage, _, let response) {
                precondition(stage == .responseBody && response.data.isEmpty)
            }
        }
        precondition(session.capturedRequestsInOrder.count == 1)
        let recovered = try await refreshCachedValue(using: client)
        precondition(recovered == expected)
        let cached = try await client.request(CachedValue(requestOptions: .init()))
        precondition(cached == expected)
        let requests = session.capturedRequestsInOrder
        precondition(requests.count == 2)
        precondition(requests.last?.value(forHTTPHeaderField: "Cache-Control") == "no-cache")
        precondition(
            requests.first?.value(forHTTPHeaderField: "Accept-Language")
                == requests.last?.value(forHTTPHeaderField: "Accept-Language"))
    } catch {
        await client.shutdown()
        throw error
    }
    await client.shutdown()
}

private enum CacheRecoveryFailure: Error {
    case malformedMessageAccepted
}
