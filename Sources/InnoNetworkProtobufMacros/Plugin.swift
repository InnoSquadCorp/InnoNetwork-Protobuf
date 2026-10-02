import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct InnoNetworkProtobufPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [ProtobufAPIDefinitionMacro.self]
}
