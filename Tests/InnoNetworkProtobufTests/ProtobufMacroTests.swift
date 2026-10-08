#if Macros
import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import Testing

@ProtobufAPIDefinition(method: .post, path: "/echo/{id}", auth: .anonymous)
private struct MacroEcho {
    typealias APIResponse = Google_Protobuf_StringValue
    let id: String
    let body: Google_Protobuf_StringValue
    let query: EchoQuery
    var requestOptions: EncodedRequestOptions { .init(queryItems: [URLQueryItem(name: "tag", value: "first")]) }
    var queryEncoder: URLQueryEncoder { .init(arrayEncodingStrategy: .repeated) }
}
private struct EchoQuery: Encodable, Sendable { let tag: [String] }

private typealias OptionalMessage = Google_Protobuf_Empty?
@ProtobufAPIDefinition(method: .post, path: "/empty", auth: .anonymous)
private struct MacroOptional {
    typealias APIResponse = Google_Protobuf_Empty
    let body: OptionalMessage
}
@ProtobufAPIDefinition(method: .delete, path: "/empty", auth: .anonymous, response: .noContent)
private struct MacroDelete {
    typealias APIResponse = EmptyResponse
}
@ProtobufAPIDefinition(method: .put, path: "/empty", auth: .anonymous, response: .noContent)
private struct MacroPut {
    typealias APIResponse = EmptyResponse
    let body: Google_Protobuf_Empty
}

@Suite("Macro-first protobuf execution")
struct ProtobufMacroTests {
    @Test func bodyQueryPathAndOperation() async throws {
        var body = Google_Protobuf_StringValue()
        body.value = "payload"
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(statusCode: 200, data: try body.serializedData(), headers: ["Content-Type": "application/protobuf"])
        ])
        let client = DefaultNetworkClient(
            configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
        let endpoint = MacroEcho(id: "team/a", body: body, query: EchoQuery(tag: ["second", "third"]))
        #expect(try await OperationNetworkClient(client: client).start(endpoint).value() == body)
        let request = try #require(session.capturedRequest)
        #expect(request.url?.absoluteString == "https://example.com/echo/team%2Fa?tag=first&tag=second&tag=third")
        #expect(request.httpBody == (try body.serializedData()))
        let manual = try endpoint.makeEncodedRequest()
        #expect(manual.options.queryItems.map(\.value) == ["first", "second", "third"])
    }

    @Test func optionalAliasPreservesAbsentAndZeroByteBodies() throws {
        let absent = try MacroOptional(body: nil).makeEncodedRequest()
        let present = try MacroOptional(body: Google_Protobuf_Empty()).makeEncodedRequest()
        #expect(absent.body == nil)
        #expect(present.body != nil)
        #expect(absent.options.headers.values(for: "Content-Type").isEmpty)
        #expect(present.options.headers.values(for: "Content-Type") == ["application/protobuf"])
    }

    @Test func noContentIsExplicitAndRejectsBody() async throws {
        let session = MockURLSession()
        session.setMockResponse(statusCode: 204)
        let client = DefaultNetworkClient(
            configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
        _ = try await client.request(MacroDelete())
        _ = try await client.request(MacroPut(body: Google_Protobuf_Empty()))
        session.setMockResponse(statusCode: 204, data: Data([1]))
        await #expect(throws: NetworkError.self) { try await client.request(MacroDelete()) }
        session.setMockResponse(statusCode: 200)
        await #expect(throws: NetworkError.self) { try await client.request(MacroDelete()) }
    }
}
#endif
