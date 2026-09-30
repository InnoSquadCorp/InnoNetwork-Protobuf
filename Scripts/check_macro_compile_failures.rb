#!/usr/bin/env ruby
# Compile positive and negative external-client declarations against the actual plugin.
require 'fileutils'
require 'open3'
require 'rbconfig'

root = File.expand_path('..', __dir__)
Dir.chdir(root)
def run!(*args)
  output, status = Open3.capture2e(*args)
  abort(output) unless status.success?
  output.strip
end
run!('swift', 'build', '--target', 'InnoNetworkProtobuf')
bin = run!('swift', 'build', '--show-bin-path')
plugin = ["#{bin}/InnoNetworkProtobufMacros", "#{bin}/InnoNetworkProtobufMacros-tool"].find { |path| File.executable?(path) }
abort 'Built macro executable not found' unless plugin
sdk = run!('xcrun', '--sdk', 'macosx', '--show-sdk-path')
arch = run!('uname', '-m')
output_dir = File.join(root, '.build', 'macro-compile-fixtures')
FileUtils.mkdir_p(output_dir)
imports = "import InnoNetwork\nimport InnoNetworkProtobuf\nimport SwiftProtobuf\n"
positive = <<~SWIFT
  public enum Routes {
    @ProtobufAPIDefinition(method: .post, path: "/users/{id}", auth: .required)
    public struct Save {
      public typealias APIResponse = Google_Protobuf_Empty
      public let id: String
      public let body: Google_Protobuf_Empty?
    }
  }
  @ProtobufAPIDefinition(method: .delete, path: "/users/{id}", auth: .anonymous, response: .noContent)
  private struct Delete {
    typealias APIResponse = EmptyResponse
    let id: Int
  }
  @ProtobufAPIDefinition(method: .post, path: "/", auth: .anonymous)
  struct GenericEndpoint<Body: Message & Sendable> {
    typealias APIResponse = Google_Protobuf_Empty
    let body: Body?
  }
SWIFT
cases = {
  'missing-response' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad {}', 'requires an explicit typealias APIResponse'],
  'get-body' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; let body: Google_Protobuf_Empty }', 'GET endpoints cannot declare a body'],
  'unused-property' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; let ignored: Int }', "stored property 'ignored' is not used"],
  'owned-member' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; let method = HTTPMethod.get }', 'owns method'],
  'query-policy-without-query' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; let queryEncoder = URLQueryEncoder() }', 'queryEncoder requires a query'],
  'non-message-body' => ['@ProtobufAPIDefinition(method: .post, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; let body: String }', "'String' conform to 'Message'"],
  'non-message-response' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = String }', "(aka 'String') conform to 'Message'"],
  'wrong-no-content-response' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous, response: .noContent) struct Bad { typealias APIResponse = Google_Protobuf_Empty }', "be equivalent"],
  'non-encodable-query' => ['struct Query: Sendable {}\n@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; let query: Query }'.gsub('\\n', "\n"), "'Query' conform to 'Encodable'"],
  'explicit-conformance' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad: EncodedAPIDefinition { typealias APIResponse = Google_Protobuf_Empty }', 'owns endpoint conformance'],
  'static-policy' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; static let protobufOptions = ProtobufCodingOptions() }', 'must be an instance policy property'],
  'dynamic-method' => ['let chosen = HTTPMethod.get\n@ProtobufAPIDefinition(method: chosen, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty }'.gsub('\\n', "\n"), 'requires an explicit supported HTTP method'],
  'computed-body' => ['@ProtobufAPIDefinition(method: .post, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; var body: Google_Protobuf_Empty { .init() } }', 'body must be an instance stored property'],
  'not-a-struct' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) enum Bad { typealias APIResponse = Google_Protobuf_Empty }', 'can only be attached to a struct'],
  'missing-auth' => ['@ProtobufAPIDefinition(method: .get, path: "/") struct Bad { typealias APIResponse = Google_Protobuf_Empty }', "missing argument for parameter 'auth'"],
  'invalid-route' => ['@ProtobufAPIDefinition(method: .get, path: "/items?secret=1", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty }', 'path must not contain query or fragment'],
  'optional-route' => ['@ProtobufAPIDefinition(method: .get, path: "/{id}", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; let id: String? }', 'cannot reference an Optional stored property'],
  'optional-route-alias' => ['typealias ID = String?\n@ProtobufAPIDefinition(method: .get, path: "/{id}", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty; let id: ID }'.gsub('\\n', "\n"), 'path placeholder values cannot be Optional'],
  'duplicate-macro' => ['@ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) @ProtobufAPIDefinition(method: .get, path: "/", auth: .anonymous) struct Bad { typealias APIResponse = Google_Protobuf_Empty }', 'must not be applied more than once'],
}
compiler = ['xcrun', 'swiftc', '-typecheck', '-swift-version', '6', '-target', "#{arch}-apple-macos14.0", '-sdk', sdk,
            '-I', bin, '-I', "#{bin}/Modules", '-load-plugin-executable', "#{plugin}#InnoNetworkProtobufMacros"]
[['positive-before', positive, nil], *cases.map { |name, (source, diagnostic)| [name, source, diagnostic] }, ['positive-after', positive, nil]].each do |name, source, expected|
  fixture = File.join(output_dir, "#{name}.swift")
  File.write(fixture, imports + source + "\n")
  output, status = Open3.capture2e(*compiler, fixture)
  File.write(File.join(output_dir, "#{name}.log"), output)
  # Do not accept a matching source echo or fixture filename as a diagnostic.
  diagnostic_matches = expected && output.lines.any? { |line| line.include?('error:') && line.include?(expected) }
  valid = expected ? (!status.success? && diagnostic_matches && output.include?(File.basename(fixture) + ':')) : status.success?
  abort "#{name}: unexpected compiler result\n#{output}" unless valid
  puts "#{name}: PASS"
end
puts "macro compile contracts: #{cases.length} rejected declarations and two passing controls"
