#if Macros
  import InnoNetwork
  import InnoNetworkProtobuf
  import SwiftProtobuf
  import Testing

  @ProtobufAPIDefinition(
    method: .post, path: "/{class}/{id}/{_innoNetworkRequirePathValue}", auth: .anonymous)
  private struct EscapedProtobufEndpoint {
    typealias `APIResponse` = Google_Protobuf_Empty
    let `class`: String
    let `id`: String
    let _innoNetworkRequirePathValue: String
    let `body`: Google_Protobuf_Empty
    var `requestOptions`: EncodedRequestOptions { .init(maximumResponseBytes: 8) }
  }

  @Suite("Protobuf macro identifier hygiene")
  struct ProtobufIdentifierTests {
    @Test func preservesEscapedIdentifiersAndQualifiesUserMembers() throws {
      let endpoint = EscapedProtobufEndpoint(
        class: "a/b", id: "c d", _innoNetworkRequirePathValue: "e", body: .init())
      let request = try endpoint.makeEncodedRequest()
      #expect(endpoint.path == "/a%2Fb/c%20d/e")
      #expect(request.body != nil)
      #expect(request.options.maximumResponseBytes == 8)
    }
  }
#endif
