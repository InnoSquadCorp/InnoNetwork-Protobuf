import Foundation
import InnoNetworkMacroSupport
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct ProtobufAPIDefinitionMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        let plan = try EndpointDefinitionExpansion.analyzeEncoded(
            attribute: node, declaration: declaration, type: type, macroName: "@ProtobufAPIDefinition",
            policyNames: ["protobufOptions", "requestOptions", "queryEncoder"])
        if declaration.attributes.compactMap({ $0.as(AttributeSyntax.self) }).filter({
            $0.attributeName.trimmedDescription.split(separator: ".").last == "ProtobufAPIDefinition"
        }).count > 1 {
            throw invalid("must not be applied more than once.", at: node)
        }
        if !plan.hasQuery && plan.presentPolicies.contains("queryEncoder") {
            throw invalid("queryEncoder requires a query property.", at: declaration)
        }
        var emptyStatusCodes: [Int]?
        if let argument = node.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == "response" }) {
            if let member = argument.expression.as(MemberAccessExprSyntax.self),
                member.declName.baseName.text == "message", validModeBase(member) {
                // Default protobuf message response.
            } else if let call = argument.expression.as(FunctionCallExprSyntax.self),
                let member = call.calledExpression.as(MemberAccessExprSyntax.self),
                member.declName.baseName.text == "empty", validModeBase(member),
                call.trailingClosure == nil, call.additionalTrailingClosures.isEmpty {
                if call.arguments.isEmpty { emptyStatusCodes = [204, 205] }
                else {
                    guard call.arguments.count == 1, let value = call.arguments.first,
                        value.label?.text == "statusCodes", let array = value.expression.as(ArrayExprSyntax.self)
                    else { throw invalid("empty response requires a literal statusCodes array, for example .empty(statusCodes: [200, 204]).", at: argument) }
                    let codes = array.elements.compactMap { $0.expression.as(IntegerLiteralExprSyntax.self).flatMap { Int($0.literal.text) } }
                    guard !codes.isEmpty, codes.count == array.elements.count,
                        codes.allSatisfy({ (200...299).contains($0) }), Set(codes).count == codes.count
                    else { throw invalid("empty response statusCodes must contain unique successful HTTP integer codes (200...299).", at: argument) }
                    emptyStatusCodes = codes
                }
                if let alias = declaration.memberBlock.members.compactMap({ $0.decl.as(TypeAliasDeclSyntax.self) })
                    .first(where: { $0.name.text == "APIResponse" }),
                    ["Google_Protobuf_Empty", "SwiftProtobuf.Google_Protobuf_Empty"].contains(alias.initializer.value.trimmedDescription) {
                    throw invalid("empty HTTP responses require APIResponse = InnoNetwork.EmptyResponse; Google_Protobuf_Empty is a protobuf message.", at: alias)
                }
            } else { throw invalid("response must be .message or .empty(statusCodes: [204, 205]).", at: argument) }
        }
        let access = plan.accessPrefix
        let codec =
            plan.presentPolicies.contains("protobufOptions")
            ? "self.protobufOptions" : "InnoNetworkProtobuf.ProtobufCodecOptions()"
        let options =
            plan.presentPolicies.contains("requestOptions")
            ? "self.requestOptions" : "InnoNetwork.EncodedRequestOptions()"
        let encoder =
            plan.presentPolicies.contains("queryEncoder") ? "self.queryEncoder" : "InnoNetwork.URLQueryEncoder()"
        let query = plan.hasQuery ? "try \(options).addingQuery(self.query, encoder: \(encoder))" : options
        let factory = emptyStatusCodes == nil ? "protobuf" : "protobufEmptyResponse"
        let responseOptions: String
        if let codes = emptyStatusCodes {
            responseOptions = "encoding: (\(codec)).encoding, statusCodes: [\(codes.map(String.init).joined(separator: ", "))]"
        } else { responseOptions = "codec: \(codec)" }
        let body = plan.hasBody ? "body: self.body, " : ""
        return [
            try ExtensionDeclSyntax(
                """
                extension \(raw: plan.typeName): InnoNetwork.EncodedAPIDefinition {
                    \(raw: access)var method: InnoNetwork.HTTPMethod { \(raw: plan.methodExpression) }
                    \(raw: access)var sessionAuthentication: InnoNetwork.SessionAuthentication { \(raw: plan.authenticationExpression) }
                    \(raw: plan.pathWitness.replacingOccurrences(of: "@APIDefinition", with: "@ProtobufAPIDefinition"))
                    \(raw: access)func makeEncodedRequest() throws(InnoNetwork.NetworkError) -> InnoNetwork.EncodedRequest<APIResponse> {
                        let options = \(raw: query)
                        return try InnoNetwork.EncodedRequest<APIResponse>.\(raw: factory)(
                            method: self.method, path: self.path, auth: self.sessionAuthentication,
                            \(raw: body)\(raw: responseOptions), options: options)
                    }
                }
                """)
        ]
    }

    private static func validModeBase(_ member: MemberAccessExprSyntax) -> Bool {
        member.base.map { ["ProtobufResponseMode", "InnoNetworkProtobuf.ProtobufResponseMode"].contains($0.trimmedDescription) } ?? true
    }

    private static func invalid(_ message: String, at node: some SyntaxProtocol) -> DiagnosticsError {
        DiagnosticsError(diagnostics: [Diagnostic(node: Syntax(node), message: MacroError(message))])
    }
}

private struct MacroError: DiagnosticMessage {
    let detail: String
    init(_ detail: String) { self.detail = detail }
    var message: String { "@ProtobufAPIDefinition " + detail }
    var diagnosticID: MessageID { .init(domain: "InnoNetworkProtobufMacros", id: "invalid-contract") }
    var severity: DiagnosticSeverity { .error }
}
