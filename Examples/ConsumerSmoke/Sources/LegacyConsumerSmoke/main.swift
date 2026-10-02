import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
    method: .get, path: "/empty", auth: .anonymous)
precondition(request.body == nil)
print("LegacyConsumerSmoke OK: compatibility product, new API")
