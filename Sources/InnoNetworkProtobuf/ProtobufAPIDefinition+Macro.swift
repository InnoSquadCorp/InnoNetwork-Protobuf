import InnoNetwork

/// Explicit response contract; a protobuf Empty message is not HTTP no-content.
public enum ProtobufResponseMode: Sendable {
    case message
    case empty(statusCodes: Set<Int> = [204, 205])
}

#if Macros
/// Declares a typed HTTP protobuf endpoint using the core's execution pipeline.
/// Declare APIResponse explicitly and store body/query/path inputs on the struct.
/// Optional body nil means no body. Query is ordinary URLQueryEncoder input.
/// Optional policy properties: protobufOptions, requestOptions and queryEncoder.
/// HTTP no-content requires response: .empty() and APIResponse = EmptyResponse.
@attached(
    extension, conformances: EncodedAPIDefinition,
    names: named(method), named(path), named(sessionAuthentication), named(makeEncodedRequest))
public macro ProtobufAPIDefinition(
    method: HTTPMethod, path: String, auth: SessionAuthentication,
    response: ProtobufResponseMode = .message
) = #externalMacro(module: "InnoNetworkProtobufMacros", type: "ProtobufAPIDefinitionMacro")
#endif
