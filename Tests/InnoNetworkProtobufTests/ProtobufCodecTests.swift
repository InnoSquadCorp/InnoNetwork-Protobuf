import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import Testing

@Suite("Protobuf binary codec contract")
struct ProtobufCodecTests {
    @Test func deterministicMapEncodingUsesTheConfiguredPolicy() async throws {
        var first = Google_Protobuf_Struct()
        var second = Google_Protobuf_Struct()
        for index in 0..<100 {
            var value = Google_Protobuf_Value()
            value.numberValue = Double(index)
            first.fields[String(index)] = value
        }
        for index in (0..<100).reversed() { second.fields[String(index)] = first.fields[String(index)] }
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(statusCode: 200, data: Data(), headers: ["Content-Type": "application/protobuf"]),
            .http(statusCode: 200, data: Data(), headers: ["Content-Type": "application/protobuf"]),
        ])
        let client = DefaultNetworkClient(
            configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
        for message in [first, second] {
            let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
                method: .post, path: "/map", auth: .anonymous,
                body: message, codec: .init(deterministic: true))
            _ = try await client.request(request)
        }
        var encoding = BinaryEncodingOptions()
        encoding.useDeterministicOrdering = true
        let expected = try first.serializedData(options: encoding)
        #expect(session.capturedRequestsInOrder.map(\.httpBody) == [expected, expected])
    }

    private func response(_ data: Data, type: String? = "application/protobuf", status: Int = 200)
        -> Response
    {
        Response(
            statusCode: status, data: data,
            response: HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: status, httpVersion: nil, headerFields: type.map { ["Content-Type": $0] })!)
    }

    @Test func generatedEmptyPreservesUnknownEquality() throws {
        let plain = Google_Protobuf_Empty()
        let data = Data([8, 1])
        let decoder = AnyResponseDecoder<Google_Protobuf_Empty>.protobuf()
        let unknown = try decoder.decode(data: data, response: response(data))
        #expect(plain != unknown)
        #expect(!plain.isEqualTo(message: unknown))
        #expect(try unknown.serializedData() == data)
        #expect(try decoder.decode(data: Data(), response: response(Data())) == plain)
        let discarding = AnyResponseDecoder<Google_Protobuf_Empty>.protobuf(
            options: .init(discardUnknownFields: true))
        #expect(try discarding.decode(data: data, response: response(data)) == plain)
    }

    @Test(arguments: [
        "application/protobuf", "Application/Protobuf; encoding=binary",
        "application/protobuf; encoding=\"binary\"",
    ])
    func supportedMedia(type: String) throws {
        _ = try AnyResponseDecoder<Google_Protobuf_Empty>.protobuf().decode(
            data: Data(), response: response(Data(), type: type))
    }

    @Test(arguments: [
        "application/json", "application/grpc", "application/x-protobuf",
        "application/protobuf; encoding=json",
        "application/protobuf; version=1", "application/protobuf; version=\"1\"",
        "application/protobuf; version=2",
        "application/protobuf; encoding=binary; encoding=binary",
        "application/protobuf, application/json",
        "application/protobuf; charset=utf-8", "application/protobuf;",
    ])
    func rejectsMedia(type: String) throws {
        do {
            _ = try AnyResponseDecoder<Google_Protobuf_Empty>.protobuf().decode(
                data: Data(), response: response(Data(), type: type))
            Issue.record("Expected media rejection")
        } catch NetworkError.decoding(_, let reason, _) {
            #expect(reason.domain == EncodedPayloadFailure.errorDomain)
            #expect(reason.code == EncodedPayloadFailure.mediaType.rawValue)
        }
    }

    @Test func legacyAndMissingAreExplicit() throws {
        let data = Data()
        #expect(throws: NetworkError.self) {
            try AnyResponseDecoder<Google_Protobuf_Empty>.protobuf().decode(
                data: data, response: response(data, type: nil))
        }
        let tolerant = AnyResponseDecoder<Google_Protobuf_Empty>.protobuf(
            options: .init(acceptsLegacyMediaType: true, allowsMissingContentType: true))
        _ = try tolerant.decode(data: data, response: response(data, type: nil))
        _ = try tolerant.decode(data: data, response: response(data, type: "application/x-protobuf"))
    }

    @Test func bodylessHasNoDummyMessageOrContentType() throws {
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .get, path: "/empty", auth: .anonymous)
        #expect(request.body == nil)
        #expect(request.options.headers.value(for: "Content-Type") == nil)
        #expect(request.options.headers.value(for: "Accept") == "application/protobuf")
        #expect(throws: NetworkError.self) {
            try EncodedRequest<Google_Protobuf_Empty>.protobuf(
                method: .get, path: "/empty", auth: .anonymous,
                options: .init(headers: HTTPHeaders(["Accept": "application/json"])))
        }
    }

    @Test func noContentIsNotAnEmptyMessage() throws {
        let decoder = AnyResponseDecoder<EmptyResponse>.noContent()
        _ = try decoder.decode(data: Data(), response: response(Data(), type: nil, status: 204))
        #expect(throws: NetworkError.self) {
            try decoder.decode(data: Data([8, 1]), response: response(Data([8, 1]), status: 204))
        }
        #expect(throws: NetworkError.self) {
            try decoder.decode(data: Data(), response: response(Data()))
        }
    }

    @Test func depthLimitHasPassingControl() throws {
        var value = Google_Protobuf_Value()
        value.stringValue = "leaf"
        for _ in 0..<20 {
            var list = Google_Protobuf_ListValue()
            list.values = [value]
            var nested = Google_Protobuf_Value()
            nested.listValue = list
            value = nested
        }
        let data = try value.serializedData()
        let shallow = AnyResponseDecoder<Google_Protobuf_Value>.protobuf(
            options: .init(maximumDecodingDepth: 5))
        #expect(throws: NetworkError.self) { try shallow.decode(data: data, response: response(data)) }
        #expect(
            try AnyResponseDecoder<Google_Protobuf_Value>.protobuf().decode(
                data: data, response: response(data)) == value)
    }

    @Test func malformedAndRequiredFieldsFail() throws {
        let data = Data([0xff])
        #expect(throws: NetworkError.self) {
            try AnyResponseDecoder<Google_Protobuf_Empty>.protobuf().decode(
                data: data, response: response(data))
        }
        // Descriptor proto contains a required name_part and is_extension pair.
        #expect(throws: NetworkError.self) {
            try AnyResponseDecoder<Google_Protobuf_UninterpretedOption.NamePart>.protobuf().decode(
                data: Data(), response: response(Data()))
        }
        var required = Google_Protobuf_UninterpretedOption.NamePart()
        required.namePart = "name"
        required.isExtension = false
        let valid = try required.serializedData()
        _ = try AnyResponseDecoder<Google_Protobuf_UninterpretedOption.NamePart>.protobuf().decode(
            data: valid, response: response(valid))
    }

    @Test func budgetsAndConcurrentOperations() async throws {
        let session = MockURLSession()
        session.mockResponse = response(Data()).response!
        let client = DefaultNetworkClient(
            configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
        var value = Google_Protobuf_StringValue()
        value.value = "too large"
        let oversized = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .post, path: "/echo", auth: .anonymous,
            body: value, codec: .init(maximumRequestBytes: 1))
        await #expect(throws: NetworkError.self) { try await client.request(oversized) }
        #expect(session.capturedRequestsInOrder.isEmpty)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<64 {
                group.addTask {
                    var body = Google_Protobuf_Int32Value()
                    body.value = Int32(i)
                    let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
                        method: .post, path: "/\(i)", auth: .anonymous, body: body)
                    _ = try await OperationNetworkClient(client: client).start(request).value()
                }
            }
            try await group.waitForAll()
        }
        #expect(session.capturedRequestsInOrder.count == 64)
        for sent in session.capturedRequestsInOrder {
            let body = try Google_Protobuf_Int32Value(serializedBytes: sent.httpBody!)
            #expect(sent.url?.lastPathComponent == String(body.value))
        }
    }
}
