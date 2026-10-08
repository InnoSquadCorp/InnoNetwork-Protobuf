import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

// Well-known generated messages keep this example independent of protoc setup.
@ProtobufAPIDefinition(method: .post, path: "/echo/{id}", auth: .anonymous)
public struct Echo {
    public typealias APIResponse = Google_Protobuf_StringValue
    public let id: Int
    public let body: Google_Protobuf_StringValue
    public var protobufOptions: ProtobufCodecOptions {
        .init(encoding: .init(maximumEncodedRequestBytes: 8_192),
              decoding: .init(maximumEncodedResponseBytes: 8_192))
    }
    public init(id: Int, body: Google_Protobuf_StringValue) {
        self.id = id
        self.body = body
    }
}

@ProtobufAPIDefinition(method: .get, path: "/values/{id}", auth: .anonymous)
public struct GetValue {
    public typealias APIResponse = Google_Protobuf_StringValue
    public struct Query: Encodable, Sendable {
        public let locale: String
        public init(locale: String) { self.locale = locale }
    }
    public let id: Int
    public let query: Query
    public init(id: Int, query: Query) { self.id = id; self.query = query }
}

@ProtobufAPIDefinition(method: .delete, path: "/values/{id}", auth: .anonymous, response: .empty())
public struct DeleteValue {
    public typealias APIResponse = EmptyResponse
    public let id: Int
    public init(id: Int) { self.id = id }
}
