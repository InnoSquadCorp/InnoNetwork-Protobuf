import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import Testing

#if Macros
@ProtobufAPIDefinition(method: .post, path: "/erased", auth: .anonymous)
private struct ErasedClientEndpoint {
    typealias APIResponse = Google_Protobuf_StringValue
    let body: Google_Protobuf_StringValue
}

#endif

@Suite("Integrated public adapter regressions")
struct ProtobufIntegrationRegressionTests {
    #if Macros
    @Test func protocolErasedClientExecutesManualAndMacroRequests() async throws {
        var message = Google_Protobuf_StringValue()
        message.value = "existential consumer"
        let data = try message.serializedData()
        let session = MockURLSession()
        session.setScriptedResponses((0..<2).map { _ in
            .http(statusCode: 200, data: data, headers: ["Content-Type": "application/protobuf"])
        })
        let concrete = DefaultNetworkClient(
            configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
        let client: any EncodedRequestClient = concrete
        let manual = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
            method: .post, path: "/manual", auth: .anonymous, body: message)
        #expect(try await client.request(manual) == message)
        #expect(try await client.request(ErasedClientEndpoint(body: message)) == message)
        #expect(session.capturedRequestsInOrder.map(\.httpBody) == [data, data])
        #expect(session.capturedRequestsInOrder.map(\.httpMethod) == ["POST", "POST"])
        await concrete.shutdown()
    }

    #endif

    @Test(arguments: [
        "application/protobuf", " Application/Protobuf ",
        "Application/Protobuf; encoding=binary", "application/protobuf; encoding=\"binary\"",
    ])
    func equivalentRequestHeadersAreNormalized(value: String) throws {
        let headers = HTTPHeaders(["Content-Type": value, "Accept": value])
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .post, path: "/headers", auth: .anonymous,
            body: Google_Protobuf_Empty(), options: .init(headers: headers))
        #expect(request.options.headers.value(for: "Content-Type") == "application/protobuf")
        #expect(request.options.headers.value(for: "Accept") == "application/protobuf")
        let bodyless = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .get, path: "/headers", auth: .anonymous, options: .init(headers: headers))
        #expect(bodyless.options.headers.value(for: "Content-Type") == nil)
    }

    @Test(arguments: [
        "", "application/json", "application/x-protobuf", "application/protobuf, application/json",
        "application/protobuf; encoding=json", "application/protobuf; charset=utf-8",
        "application/protobuf; encoding=binary; encoding=binary",
    ])
    func incompatibleRequestHeadersRemainRejected(value: String) throws {
        for name in ["Content-Type", "Accept"] {
            #expect(throws: NetworkError.self) {
                try EncodedRequest<Google_Protobuf_Empty>.protobuf(
                    method: .post, path: "/headers", auth: .anonymous, body: Google_Protobuf_Empty(),
                    codec: .init(acceptsLegacyMediaType: true, allowsMissingContentType: true),
                    options: .init(headers: HTTPHeaders([name: value])))
            }
        }
    }

    @Test func duplicateRequestHeadersRemainRejected() throws {
        for name in ["Content-Type", "Accept"] {
            var headers = HTTPHeaders()
            headers.add(name: name, value: "application/protobuf")
            headers.add(name: name, value: "application/protobuf")
            #expect(throws: NetworkError.self) {
                try EncodedRequest<Google_Protobuf_Empty>.protobuf(
                    method: .post, path: "/headers", auth: .anonymous,
                    body: Google_Protobuf_Empty(), options: .init(headers: headers))
            }
        }
    }
}
