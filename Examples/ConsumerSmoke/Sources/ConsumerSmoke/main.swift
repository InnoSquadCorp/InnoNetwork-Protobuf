import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf

// Generated well-known messages keep this example self-contained. Applications
// can use their own protoc-generated Message types with the same endpoint shape.
struct GetValue: ProtobufAPIDefinition {
    typealias Parameter = Google_Protobuf_Int32Value
    typealias APIResponse = Google_Protobuf_StringValue

    var method: HTTPMethod { .post }
    var path: String { "/values.protobuf" }
    var sessionAuthentication: SessionAuthentication { .anonymous }
    let parameters: Google_Protobuf_Int32Value?
}

var input = Google_Protobuf_Int32Value()
input.value = 42
var output = Google_Protobuf_StringValue()
output.value = "protobuf-6"
let session = MockURLSession()
session.setMockResponse(statusCode: 200, data: try output.serializedData())

let client = DefaultNetworkClient(
    configuration: .safeDefaults(baseURL: URL(string: "https://api.example.com")!),
    session: session
)

let response = try await client.protobufRequest(GetValue(parameters: input))
precondition(response.value == "protobuf-6")
precondition(session.capturedRequestsInOrder.count == 1)
precondition(session.capturedRequest?.httpMethod == "POST")
precondition(session.capturedRequest?.url?.path == "/values.protobuf")
precondition(session.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/x-protobuf")
precondition(session.capturedRequest?.value(forHTTPHeaderField: "Authorization") == nil)
let sent = try Google_Protobuf_Int32Value(serializedBytes: session.capturedRequest?.httpBody ?? Data())
precondition(sent.value == 42)

print("ConsumerSmoke OK: protobuf request/response against remote InnoNetwork 6")
