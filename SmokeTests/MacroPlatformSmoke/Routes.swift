#if Macros
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

public enum Routes {
    @ProtobufAPIDefinition(method: .post, path: "/users/{id}", auth: .required)
    public struct Save {
        public typealias APIResponse = Google_Protobuf_Empty
        public let id: String
        public let body: Google_Protobuf_Empty?
    }
    @ProtobufAPIDefinition(method: .delete, path: "/users/{id}", auth: .required, response: .empty())
    public struct Delete {
        public typealias APIResponse = EmptyResponse
        public let id: Int
    }
}
#endif
