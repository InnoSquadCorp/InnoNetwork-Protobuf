import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

// The compatibility product must still expose the original Swift module.
let client: any ProtobufNetworkClient = DefaultNetworkClient(
    configuration: .safeDefaults(baseURL: URL(string: "https://api.example.com")!)
)
let empty = ProtobufEmptyResponse()
let bytes = try empty.serializedData()
precondition(bytes.isEmpty)
_ = client
print("LegacyConsumerSmoke OK: InnoNetworkProtobuf product and module retained")
