import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf
import Testing

@Suite("Directional protobuf policy")
struct ProtobufPolicyTests {
    private func response(_ bytes: Data, contentType: String = "application/protobuf", status: Int = 200) -> Response {
        Response(statusCode: status, data: bytes, response: HTTPURLResponse(
            url: URL(string: "https://example.com")!, statusCode: status, httpVersion: nil,
            headerFields: ["Content-Type": contentType])!)
    }

    @Test func legacyRequestAndStandardResponseAreIndependent() throws {
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .post, path: "/", auth: .anonymous, body: Google_Protobuf_Empty(),
            codec: .init(encoding: .init(mediaType: .legacy)))
        #expect(request.options.headers.value(for: "Content-Type") == "application/x-protobuf")
        #expect(request.options.headers.value(for: "Accept") == "application/protobuf")
        #expect(try request.responseDecoder.decode(data: Data(), response: response(Data())) == Google_Protobuf_Empty())
    }

    @Test func acceptedResponseProfilesAreAdvertisedAndBounded() throws {
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .get, path: "/", auth: .anonymous,
            codec: .init(decoding: .init(maximumEncodedResponseBytes: 8, acceptedMediaTypes: [.standard, .legacy])),
            options: .init(headers: .init(["Accept": "Application/X-Protobuf, application/protobuf; encoding=binary"]), maximumResponseBytes: 4))
        #expect(request.options.headers.value(for: "Accept") == "application/protobuf, application/x-protobuf")
        #expect(request.options.maximumResponseBytes == 4)
        _ = try request.responseDecoder.decode(data: Data(), response: response(Data(), contentType: "application/x-protobuf"))
    }

    @Test func invalidResponsePolicyFailsBeforeExecution() throws {
        for policy in [ProtobufDecodingOptions(maximumDepth: 0), .init(acceptedMediaTypes: [])] {
            #expect(throws: NetworkError.self) {
                try EncodedRequest<Google_Protobuf_Empty>.protobuf(
                    method: .get, path: "/", auth: .anonymous, codec: .init(decoding: policy))
            }
        }
    }

    @Test func emptyResponseHasOnlyEncodingAndExplicitStatusPolicy() throws {
        let request = try EncodedRequest<EmptyResponse>.protobufEmptyResponse(
            method: .delete, path: "/", auth: .anonymous, statusCodes: [200, 204])
        #expect(request.options.headers.value(for: "Accept") == nil)
        _ = try request.responseDecoder.decode(data: Data(), response: response(Data(), contentType: "application/json"))
        #expect(throws: NetworkError.self) {
            try request.responseDecoder.decode(data: Data([1]), response: response(Data([1])))
        }
        let invalidCodes: [Set<Int>] = [[], [404], [199], [600]]
        for codes in invalidCodes {
            #expect(throws: NetworkError.self) {
                try EncodedRequest<EmptyResponse>.protobufEmptyResponse(
                    method: .get, path: "/", auth: .anonymous, statusCodes: codes)
            }
        }
    }

    @Test func malformedMessagesKeepPayloadFreeSpecificCategories() throws {
        let fixtures: [(Data, ProtobufDecodingFailure)] = [
            (Data([0]), .malformedMessage),
            (Data([0x0a, 2, 1]), .truncatedMessage),
            (Data([0x0a, 1, 0xff]), .invalidUTF8),
        ]
        let decoder = AnyResponseDecoder<Google_Protobuf_StringValue>.protobuf()
        for (bytes, expected) in fixtures {
            do {
                _ = try decoder.decode(data: bytes, response: response(bytes))
                Issue.record("Malformed bytes accepted")
            } catch NetworkError.decoding(let stage, let failure, _) {
                #expect(stage == .responseBody)
                #expect(failure.domain == ProtobufDecodingFailure.errorDomain)
                #expect(failure.code == expected.rawValue)
            }
        }
        do {
            _ = try AnyResponseDecoder<Google_Protobuf_UninterpretedOption.NamePart>.protobuf()
                .decode(data: Data(), response: response(Data()))
            Issue.record("Missing required fields accepted")
        } catch NetworkError.decoding(_, let failure, _) {
            #expect(failure.code == ProtobufDecodingFailure.missingRequiredFields.rawValue)
        }
    }
}
