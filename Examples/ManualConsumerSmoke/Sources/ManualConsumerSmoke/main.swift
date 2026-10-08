import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

let absent = try EncodedRequest<Google_Protobuf_Empty>.protobuf(method: .get, path: "/empty", auth: .anonymous)
let present = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
    method: .post, path: "/empty", auth: .anonymous, body: Google_Protobuf_Empty())
precondition(absent.body == nil && present.body != nil)
print("ManualConsumerSmoke OK: both Macros traits disabled")
