import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

// Both package Macros traits are disabled. Exercise URLSession and real loopback sockets.
let fixture = try LoopbackFixture()
defer { fixture.stop() }
try await fixture.start()
let concrete = DefaultNetworkClient(configuration: .advanced(
    baseURL: LoopbackFixture.baseURL,
    transport: .init(timeout: 8, cachePolicy: .reloadIgnoringLocalCacheData, allowsInsecureHTTP: true)))
let client: any EncodedRequestClient = concrete
var message = Google_Protobuf_StringValue()
message.value = "macro-disabled real transport"
let request = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
    method: .post, path: "/protobuf", auth: .anonymous, body: message)
let echoed = try await client.request(request)
precondition(echoed == message && fixture.count("/protobuf") == 1)
let absent = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
    method: .get, path: "/protobuf", auth: .anonymous)
let emptyMessage = try await client.request(absent)
precondition(absent.body == nil && emptyMessage == Google_Protobuf_Empty())
let noContent = try EncodedRequest<EmptyResponse>.protobufEmptyResponse(
    method: .get, path: "/protobuf", auth: .anonymous, statusCodes: [200])
_ = try await client.request(noContent)
precondition(fixture.count("/protobuf") == 3)
let invalidMedia = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
    method: .get, path: "/json", auth: .anonymous)
do {
    _ = try await client.request(invalidMedia)
    preconditionFailure("JSON response must not be decoded as protobuf")
} catch NetworkError.decoding(_, let failure, let response) {
    precondition(failure.domain == ProtobufDecodingFailure.errorDomain)
    precondition(failure.code == ProtobufDecodingFailure.invalidMediaType.rawValue)
    precondition(response.data.isEmpty)
}
await concrete.shutdown()
print("ManualConsumerSmoke OK: macros disabled, existential client, URLSession echo/empty/media rejection")
