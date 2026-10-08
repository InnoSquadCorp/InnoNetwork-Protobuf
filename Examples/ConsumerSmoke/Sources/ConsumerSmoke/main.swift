import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf

@APIDefinition(method: .get, path: "/json", auth: .anonymous)
struct JSONEndpoint {
    typealias APIResponse = JSONReply
}
struct JSONReply: Codable, Sendable { let value: String }
public enum ProtobufRoutes {
    @ProtobufAPIDefinition(method: .post, path: "/echo", auth: .anonymous)
    public struct Echo {
        public typealias APIResponse = Google_Protobuf_StringValue
        public let body: Google_Protobuf_StringValue
    }
}
var message = Google_Protobuf_StringValue()
message.value = "external consumer"
let request = ProtobufRoutes.Echo(body: message)
let session = MockURLSession()
session.setScriptedResponses([
    .http(
        statusCode: 200, data: try message.serializedData(),
        headers: ["Content-Type": "application/protobuf"]),
    .http(statusCode: 200, data: Data(#"{"value":"json"}"#.utf8), headers: ["Content-Type": "application/json"]),
])
let client = DefaultNetworkClient(
    configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
let operation = OperationNetworkClient(client: client).start(request)
let result = try await operation.value()
precondition(result == message)
let encoded = try message.serializedData()
precondition(session.capturedRequest?.httpBody == encoded)
let json = try await client.request(JSONEndpoint())
let erasedClient: any EncodedRequestClient = client
session.setScriptedResponses([
    .http(statusCode: 200, data: encoded, headers: ["Content-Type": "application/protobuf"]),
    .http(statusCode: 200, data: encoded, headers: ["Content-Type": "application/protobuf"]),
])
let erasedMacroResult = try await erasedClient.request(request)
precondition(erasedMacroResult == message)
let manual = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
    method: .post, path: "/manual", auth: .anonymous, body: message)
let erasedManualResult = try await erasedClient.request(manual)
precondition(erasedManualResult == message)
precondition(json.value == "json")
await client.shutdown()
try await runCacheRecoveryExample()
print("ConsumerSmoke OK: public nested protobuf macro, operation, JSON macro coexistence, cache recovery")
