#if Macros && os(macOS)
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing
@testable import InnoNetworkProtobufMacros

@Suite("Protobuf macro expansion")
struct ExpansionTests {
    @Test func bodylessRequest() {
        assertMacroExpansion(
            """
            @ProtobufAPIDefinition(method: .get, path: "/value", auth: .anonymous)
            struct GetValue {
                typealias APIResponse = Value
            }
            """,
            expandedSource: """
                struct GetValue {
                    typealias APIResponse = Value
                }

                extension GetValue: InnoNetwork.EncodedAPIDefinition {
                    internal var method: InnoNetwork.HTTPMethod {
                        .get
                    }
                    internal var sessionAuthentication: InnoNetwork.SessionAuthentication {
                        .anonymous
                    }
                    internal var path: Swift.String {
                        "/value"
                    }
                    internal func makeEncodedRequest() throws(InnoNetwork.NetworkError) -> InnoNetwork.EncodedRequest<APIResponse> {
                        let options = InnoNetwork.EncodedRequestOptions()
                        return try InnoNetwork.EncodedRequest<APIResponse>.protobuf(
                            method: self.method, path: self.path, auth: self.sessionAuthentication,
                            codec: InnoNetworkProtobuf.ProtobufCodecOptions(), options: options)
                    }
                }
                """,
            macros: ["ProtobufAPIDefinition": ProtobufAPIDefinitionMacro.self])
    }

    @Test func missingResponse() {
        assertMacroExpansion(
            """
            @ProtobufAPIDefinition(method: .get, path: "/value", auth: .anonymous)
            struct GetValue {}
            """, expandedSource: "struct GetValue {}",
            diagnostics: [
                DiagnosticSpec(
                    message: "@ProtobufAPIDefinition requires an explicit typealias APIResponse.", line: 2, column: 8)
            ],
            macros: ["ProtobufAPIDefinition": ProtobufAPIDefinitionMacro.self])
    }
}
#endif
