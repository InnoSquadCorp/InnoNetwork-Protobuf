import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

#if Macros
@ProtobufAPIDefinition(method: .post, path: "/echo", auth: .anonymous)
struct Echo {
    typealias APIResponse = Google_Protobuf_StringValue
    let body: Google_Protobuf_StringValue
    var protobufOptions: ProtobufCodecOptions {
        .init(encoding: .init(maximumEncodedRequestBytes: 8_192), decoding: .init(maximumEncodedResponseBytes: 8_192))
    }
}
#endif
var message = Google_Protobuf_StringValue()
message.value = "hello"
#if Macros
let request = try Echo(body: message).makeEncodedRequest()
#else
let request = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
    method: .post, path: "/echo", auth: .anonymous, body: message,
    codec: .init(encoding: .init(maximumEncodedRequestBytes: 8_192), decoding: .init(maximumEncodedResponseBytes: 8_192)))
#endif
let response = Response(
    statusCode: 200, data: try message.serializedData(), request: nil,
    response: HTTPURLResponse(
        url: URL(string: "https://example.com")!, statusCode: 200,
        httpVersion: nil, headerFields: ["Content-Type": "application/protobuf"])!)
let decoded = try request.responseDecoder.decode(data: response.data, response: response)
precondition(decoded == message)
print("InnoNetworkProtobufDocSmoke OK")
