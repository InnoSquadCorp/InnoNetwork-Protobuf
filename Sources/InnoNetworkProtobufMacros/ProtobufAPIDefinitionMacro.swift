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
        var noContent = false
        if let argument = node.arguments?.as(LabeledExprListSyntax.self)?.first(where: { $0.label?.text == "response" })
        {
            guard let member = argument.expression.as(MemberAccessExprSyntax.self),
                member.base.map({
                    ["ProtobufResponseMode", "InnoNetworkProtobuf.ProtobufResponseMode"].contains($0.trimmedDescription)
                }) ?? true,
                ["message", "noContent"].contains(member.declName.baseName.text)
            else { throw invalid("response must be .message or .noContent.", at: argument) }
            noContent = member.declName.baseName.text == "noContent"
        }
        let access = plan.accessPrefix
        let codec =
            plan.presentPolicies.contains("protobufOptions")
            ? "self.protobufOptions" : "InnoNetworkProtobuf.ProtobufCodingOptions()"
        let options =
            plan.presentPolicies.contains("requestOptions")
            ? "self.requestOptions" : "InnoNetwork.EncodedRequestOptions()"
        let encoder =
            plan.presentPolicies.contains("queryEncoder") ? "self.queryEncoder" : "InnoNetwork.URLQueryEncoder()"
        let query = plan.hasQuery ? "try \(options).addingQuery(self.query, encoder: \(encoder))" : options
        let factory = noContent ? "protobufNoContent" : "protobuf"
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
                            \(raw: body)codec: \(raw: codec), options: options)
                    }
                }
                """)
        ]
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
