import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import ProtobufSkillExample
import SwiftProtobuf
import Testing
import os

@Suite(.timeLimit(.minutes(1)))
struct ConsumerTests {
    private let baseURL = URL(string: "https://example.com")!
    private let media = ["Content-Type": "application/protobuf"]

    private func message(_ text: String = "hello") -> Google_Protobuf_StringValue {
        var value = Google_Protobuf_StringValue()
        value.value = text
        return value
    }

    private func client(_ session: MockURLSession) -> DefaultNetworkClient {
        DefaultNetworkClient(configuration: .safeDefaults(baseURL: baseURL), session: session)
    }

    @Test func macroPostUsesGeneratedMessageAndTypedPath() async throws {
        let body = message()
        let bytes = try body.serializedData()
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, data: bytes, headers: media)])
        let client = client(session)
        #expect(try await client.request(Echo(id: 7, body: body)) == body)
        let request = try #require(session.capturedRequest)
        #expect(request.url?.path == "/echo/7")
        #expect(request.httpMethod == "POST")
        #expect(request.httpBody == bytes)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/protobuf")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/protobuf")
        await client.shutdown()
    }

    @Test func macroGetUsesHTTPQueryWithoutBody() async throws {
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, data: try message().serializedData(), headers: media)])
        let client = client(session)
        #expect(try await client.request(GetValue(id: 8, query: .init(locale: "ko"))) == message())
        let request = try #require(session.capturedRequest)
        #expect(request.url?.path == "/values/8")
        #expect(request.httpMethod == "GET")
        #expect(URLComponents(url: try #require(request.url), resolvingAgainstBaseURL: false)?.queryItems == [.init(name: "locale", value: "ko")])
        #expect(request.httpBody == nil)
        #expect(request.value(forHTTPHeaderField: "Content-Type") == nil)
        await client.shutdown()
    }

    @Test(arguments: [200, 204, 205])
    func httpNoContentRequiresStatusAndEmptyBody(status: Int) async throws {
        let session = MockURLSession()
        session.setMockResponse(statusCode: status)
        let client = client(session)
        if status == 200 {
            await #expect(throws: NetworkError.self) { try await client.request(DeleteValue(id: 1)) }
        } else {
            _ = try await client.request(DeleteValue(id: 1))
        }
        session.setMockResponse(statusCode: status, data: Data([1]))
        await #expect(throws: NetworkError.self) { try await client.request(DeleteValue(id: 1)) }
        await client.shutdown()
    }

    @Test func nilAndPresentEmptyMessagesRemainDifferentBodies() async throws {
        let session = MockURLSession()
        session.setScriptedResponses(Array(repeating: .http(statusCode: 200, headers: media), count: 2))
        let client = client(session)
        for body: Google_Protobuf_Empty? in [nil, Google_Protobuf_Empty()] {
            let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
                method: .post, path: "/empty-message", auth: .anonymous, body: body)
            #expect((request.body == nil) == (body == nil))
            #expect(try await client.request(request) == Google_Protobuf_Empty())
        }
        let sent = session.capturedRequestsInOrder
        #expect(sent.count == 2)
        #expect(sent[0].httpBody == nil)
        #expect(sent[0].value(forHTTPHeaderField: "Content-Type") == nil)
        #expect(sent[1].httpBody == Data())
        #expect(sent[1].value(forHTTPHeaderField: "Content-Type") == "application/protobuf")
        await client.shutdown()
    }

    @Test func directionalMediaPolicyDoesNotCoupleRequestAndResponse() async throws {
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, data: try message().serializedData(), headers: media)])
        let client = client(session)
        let request = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
            method: .post, path: "/legacy-request", auth: .anonymous, body: message(),
            codec: .init(encoding: .init(mediaType: .legacy)))
        #expect(try await client.request(request) == message())
        #expect(session.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/x-protobuf")
        #expect(session.capturedRequest?.value(forHTTPHeaderField: "Accept") == "application/protobuf")
        await client.shutdown()
    }

    @Test(arguments: ["application/json", "application/grpc", "application/protobuf; charset=utf-8"])
    func strictResponseMediaRejectsUnsupportedProfiles(contentType: String) async throws {
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, headers: ["Content-Type": contentType])])
        let client = client(session)
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(method: .get, path: "/value", auth: .anonymous)
        do {
            _ = try await client.request(request)
            Issue.record("Expected media rejection")
        } catch NetworkError.decoding(let stage, let failure, _) {
            #expect(stage == .responseBody)
            #expect(failure.domain == ProtobufDecodingFailure.errorDomain)
            #expect(failure.code == ProtobufDecodingFailure.invalidMediaType.rawValue)
        }
        #expect(session.capturedRequestsInOrder.count == 1)
        await client.shutdown()
    }

    @Test(arguments: [false, true])
    func missingContentTypeIsExplicitCompatibility(allowed: Bool) async throws {
        let session = MockURLSession()
        session.setMockResponse(statusCode: 200)
        let client = client(session)
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .get, path: "/value", auth: .anonymous,
            codec: .init(decoding: .init(allowsMissingContentType: allowed)))
        if allowed { #expect(try await client.request(request) == Google_Protobuf_Empty()) }
        else { await #expect(throws: NetworkError.self) { try await client.request(request) } }
        await client.shutdown()
    }

    @Test(arguments: [-1, 0])
    func requestByteBudgetHasPassingBoundary(delta: Int) async throws {
        let body = message()
        let bytes = try body.serializedData()
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, headers: media)])
        let client = client(session)
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .post, path: "/bounded", auth: .anonymous, body: body,
            codec: .init(encoding: .init(maximumEncodedRequestBytes: bytes.count + delta)))
        if delta < 0 {
            do { _ = try await client.request(request); Issue.record("Expected request budget rejection") }
            catch NetworkError.configuration(reason: .invalidPayload(.requestBodyLimit)) {}
            #expect(session.capturedRequestsInOrder.isEmpty)
        } else {
            _ = try await client.request(request)
            #expect(session.capturedRequest?.httpBody == bytes)
        }
        await client.shutdown()
    }

    @Test(arguments: [-1, 0])
    func responseByteBudgetHasPassingBoundary(delta: Int) async throws {
        let body = message()
        let bytes = try body.serializedData()
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, data: bytes, headers: media)])
        let client = client(session)
        let request = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
            method: .get, path: "/bounded", auth: .anonymous,
            codec: .init(decoding: .init(maximumEncodedResponseBytes: Int64(bytes.count + delta))))
        if delta < 0 {
            do { _ = try await client.request(request); Issue.record("Expected collection rejection") }
            catch NetworkError.underlying(let failure, _) {
                #expect(failure.code == NetworkErrorCode.responseBodyLimitExceeded.rawValue)
            }
        } else { #expect(try await client.request(request) == body) }
        #expect(session.capturedRequestsInOrder.count == 1)
        await client.shutdown()
    }

    @Test func retryReusesBytesAndAnotherInvocationEncodesAgain() async throws {
        let measurements = OSAllocatedUnfairLock(initialState: [EncodedCodecMeasurement]())
        let bytes = try message().serializedData()
        let session = MockURLSession()
        session.setScriptedResponses([
            .failure(URLError(.timedOut)),
            .http(statusCode: 200, data: bytes, headers: media),
            .http(statusCode: 200, data: bytes, headers: media)
        ])
        let client = DefaultNetworkClient(configuration: .advanced(
            baseURL: baseURL, resilience: .init(retry: ExponentialBackoffRetryPolicy(
                maxRetries: 1, retryDelay: 0, jitterRatio: 0))), session: session)
        let request = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
            method: .post, path: "/retry", auth: .anonymous, body: message(),
            options: .init(headers: HTTPHeaders(["Idempotency-Key": "protobuf-fixture"]),
                           codecObserver: { sample in measurements.withLock { $0.append(sample) } }))
        #expect(measurements.withLock { $0.isEmpty })
        #expect(try await client.request(request) == message())
        #expect(session.capturedRequestsInOrder.map(\.httpBody) == [bytes, bytes])
        #expect(measurements.withLock { $0.filter { $0.stage == .encoding }.count } == 1)
        #expect(try await client.request(request) == message())
        #expect(measurements.withLock { $0.filter { $0.stage == .encoding }.count } == 2)
        #expect(session.capturedRequestsInOrder.count == 3)
        await client.shutdown()
    }

    @Test func requiredAuthRejectsBeforeCodecAndTransport() async throws {
        let count = OSAllocatedUnfairLock(initialState: 0)
        let session = MockURLSession()
        let client = client(session)
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .post, path: "/private", auth: .required, body: message(),
            options: .init(codecObserver: { _ in count.withLock { $0 += 1 } }))
        await #expect(throws: NetworkError.self) { try await client.request(request) }
        #expect(count.withLock { $0 } == 0)
        #expect(session.capturedRequestsInOrder.isEmpty)
        await client.shutdown()
    }

    @Test func malformedBytesHaveSpecificPayloadFreeError() async throws {
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, data: Data([0x0a, 2, 1]), headers: media)])
        let client = DefaultNetworkClient(configuration: .advanced(
            baseURL: baseURL, cache: .init(captureFailurePayload: false)), session: session)
        do {
            _ = try await client.request(GetValue(id: 1, query: .init(locale: "en")))
            Issue.record("Expected truncated-message failure")
        } catch NetworkError.decoding(let stage, let failure, let response) {
            #expect(stage == .responseBody)
            #expect(failure.domain == ProtobufDecodingFailure.errorDomain)
            #expect(failure.code == ProtobufDecodingFailure.truncatedMessage.rawValue)
            #expect(response.data.isEmpty)
        }
        await client.shutdown()
    }

    @Test func schemaEmptyPreservesUnknownFields() throws {
        let bytes = Data([0x08, 0x01])
        let response = Response(statusCode: 200, data: bytes, response: HTTPURLResponse(
            url: baseURL, statusCode: 200, httpVersion: nil, headerFields: media)!)
        let value = try AnyResponseDecoder<Google_Protobuf_Empty>.protobuf().decode(data: bytes, response: response)
        #expect(value != Google_Protobuf_Empty())
        #expect(try value.serializedData() == bytes)
    }

    @Test func expiredOperationAndShutdownRejectBeforeTransport() async throws {
        let count = OSAllocatedUnfairLock(initialState: 0)
        let session = MockURLSession()
        let client = client(session)
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .post, path: "/expired", auth: .anonymous, body: message(),
            options: .init(codecObserver: { _ in count.withLock { $0 += 1 } }))
        let operation = OperationNetworkClient(client: client).start(request, deadline: .init(after: .zero))
        do { _ = try await operation.value(); Issue.record("Expected expired operation") }
        catch { #expect(error.kind == .timeout); #expect(error.deadlineStage == .requestPreparation) }
        await client.shutdown()
        do { _ = try await client.request(request); Issue.record("Expected closed-client rejection") }
        catch NetworkError.cancelled {}
        #expect(count.withLock { $0 } == 0)
        #expect(session.capturedRequestsInOrder.isEmpty)
    }
}
