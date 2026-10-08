import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import Testing
import os

@Suite("Protobuf exact byte boundaries")
struct ProtobufLimitBoundaryTests {
    private let baseURL = URL(string: "https://example.com")!

    private func message() -> Google_Protobuf_StringValue {
        var message = Google_Protobuf_StringValue()
        message.value = "exact-boundary"
        return message
    }

    private func response(_ bytes: Data) -> Response {
        Response(statusCode: 200, data: bytes, response: HTTPURLResponse(
            url: baseURL, statusCode: 200, httpVersion: nil,
            headerFields: ["Content-Type": "application/protobuf"])!)
    }

    @Test(arguments: [false, true])
    func negativeByteLimitsFailAtFactory(responseLimit: Bool) throws {
        let options = responseLimit
            ? ProtobufCodecOptions(decoding: .init(maximumEncodedResponseBytes: -1))
            : ProtobufCodecOptions(encoding: .init(maximumEncodedRequestBytes: -1))
        do {
            _ = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
                method: .post, path: "/negative", auth: .anonymous,
                body: message(), codec: options)
            Issue.record("Negative byte budget was accepted")
        } catch NetworkError.configuration(reason: .invalidPayload(.invalidLimit)) {
            // Exact factory-time category; no client/transport invocation is needed.
        }
    }

    @Test func standaloneDecoderRejectsNegativeByteLimit() throws {
        let bytes = try message().serializedData()
        let decoder = AnyResponseDecoder<Google_Protobuf_StringValue>.protobuf(
            options: .init(maximumEncodedResponseBytes: -1))
        do {
            _ = try decoder.decode(data: bytes, response: response(bytes))
            Issue.record("Standalone decoder accepted a negative budget")
        } catch NetworkError.decoding(let stage, let failure, _) {
            #expect(stage == .responseBody)
            #expect(failure.domain == EncodedPayloadFailure.errorDomain)
            #expect(failure.code == EncodedPayloadFailure.invalidLimit.rawValue)
        }
    }

    @Test(arguments: [-1, 0, 1])
    func requestBudgetAtExactSerializedSize(delta: Int) async throws {
        let body = message()
        let bytes = try body.serializedData()
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, headers: ["Content-Type": "application/protobuf"])])
        let client = DefaultNetworkClient(configuration: .safeDefaults(baseURL: baseURL), session: session)
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .post, path: "/request-limit", auth: .anonymous, body: body,
            codec: .init(encoding: .init(maximumEncodedRequestBytes: bytes.count + delta)))
        if delta < 0 {
            do {
                _ = try await client.request(request)
                Issue.record("N-1 request budget was ignored")
            } catch NetworkError.configuration(reason: .invalidPayload(.requestBodyLimit)) {}
            #expect(session.capturedRequestsInOrder.isEmpty)
        } else {
            #expect(try await client.request(request) == Google_Protobuf_Empty())
            #expect(session.capturedRequestsInOrder.count == 1)
            #expect(session.capturedRequest?.httpBody == bytes)
        }
        await client.shutdown()
    }

    @Test(arguments: [-1, 0, 1])
    func standaloneResponseBudgetAtExactSerializedSize(delta: Int) throws {
        let expected = message()
        let bytes = try expected.serializedData()
        let decoder = AnyResponseDecoder<Google_Protobuf_StringValue>.protobuf(
            options: .init(maximumEncodedResponseBytes: Int64(bytes.count + delta)))
        if delta < 0 {
            do {
                _ = try decoder.decode(data: bytes, response: response(bytes))
                Issue.record("N-1 decoder budget was ignored")
            } catch NetworkError.decoding(let stage, let failure, _) {
                #expect(stage == .responseBody)
                #expect(failure.domain == EncodedPayloadFailure.errorDomain)
                #expect(failure.code == EncodedPayloadFailure.responseBodyLimit.rawValue)
            }
        } else {
            #expect(try decoder.decode(data: bytes, response: response(bytes)) == expected)
        }
    }

    @Test(arguments: [-1, 0, 1])
    func clientResponseBudgetAtExactSerializedSize(delta: Int) async throws {
        let expected = message()
        let bytes = try expected.serializedData()
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, data: bytes, headers: ["Content-Type": "application/protobuf"])])
        let client = DefaultNetworkClient(configuration: .safeDefaults(baseURL: baseURL), session: session)
        let request = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
            method: .get, path: "/response-limit", auth: .anonymous,
            codec: .init(decoding: .init(maximumEncodedResponseBytes: Int64(bytes.count + delta))))
        if delta < 0 {
            do {
                _ = try await client.request(request)
                Issue.record("N-1 collection budget was ignored")
            } catch NetworkError.underlying(let failure, _) {
                // Core collection rejects before protobuf decoding; retain its category.
                #expect(failure.code == NetworkErrorCode.responseBodyLimitExceeded.rawValue)
            }
        } else {
            #expect(try await client.request(request) == expected)
        }
        #expect(session.capturedRequestsInOrder.count == 1)
        await client.shutdown()
    }

    @Test func zeroByteMessageFitsZeroBudgets() async throws {
        let body = Google_Protobuf_Empty()
        #expect(try body.serializedData().isEmpty)
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, headers: ["Content-Type": "application/protobuf"])])
        let client = DefaultNetworkClient(configuration: .safeDefaults(baseURL: baseURL), session: session)
        let request = try EncodedRequest<Google_Protobuf_Empty>.protobuf(
            method: .post, path: "/zero", auth: .anonymous, body: body,
            codec: .init(encoding: .init(maximumEncodedRequestBytes: 0),
                         decoding: .init(maximumEncodedResponseBytes: 0)))
        #expect(request.body != nil)
        #expect(try await client.request(request) == body)
        #expect(session.capturedRequestsInOrder.count == 1)
        #expect(session.capturedRequest?.value(forHTTPHeaderField: "Content-Type") == "application/protobuf")
        await client.shutdown()
    }
}

private struct YieldBeforeSharedRequestTransport: RequestInterceptor {
    func adapt(_ request: URLRequest) async throws -> URLRequest {
        // Yield each invocation after encoding; no unbounded barrier can strand a failing test.
        try await Task.sleep(for: .milliseconds(1))
        return request
    }
}

@Suite("Protobuf shared request value reuse")
struct ProtobufSharedRequestTests {
    @Test(arguments: [false, true])
    func oneEncodedRequestValueCanBeReusedConcurrently(operationRoute: Bool) async throws {
        let calls = 32
        var body = Google_Protobuf_StringValue()
        body.value = "shared-immutable-request"
        let expected = body
        let bytes = try expected.serializedData()
        let measurements = OSAllocatedUnfairLock(initialState: [EncodedCodecMeasurement]())
        let request = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
            method: .post, path: "/same-request", auth: .anonymous, body: body,
            codec: .init(encoding: .init(maximumEncodedRequestBytes: bytes.count),
                         decoding: .init(maximumEncodedResponseBytes: Int64(bytes.count))),
            options: .init(requestInterceptors: [YieldBeforeSharedRequestTransport()],
                           codecObserver: { sample in measurements.withLock { $0.append(sample) } }))
        body.value = "changed-after-request-creation"
        #expect(body.value != expected.value)
        #expect(measurements.withLock { $0.isEmpty })
        let session = MockURLSession()
        session.setScriptedResponses(Array(repeating: .http(
            statusCode: 200, data: bytes, headers: ["Content-Type": "application/protobuf"]), count: calls + 1))
        let client = DefaultNetworkClient(
            configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
        var completed = 0
        try await withThrowingTaskGroup(of: Google_Protobuf_StringValue.self) { group in
            for _ in 0..<calls {
                group.addTask {
                    if operationRoute { return try await OperationNetworkClient(client: client).start(request).value() }
                    return try await client.request(request)
                }
            }
            for try await reply in group {
                #expect(reply == expected)
                completed += 1
            }
        }
        #expect(completed == calls)
        #expect(session.capturedRequestsInOrder.count == calls)
        #expect(session.capturedRequestsInOrder.allSatisfy { $0.httpMethod == "POST" && $0.httpBody == bytes })
        let firstBatch = measurements.withLock { $0 }
        #expect(firstBatch.filter { $0.stage == .encoding }.count == calls)
        #expect(firstBatch.filter { $0.stage == .decoding }.count == calls)
        #expect(firstBatch.allSatisfy { $0.succeeded && $0.byteCount == bytes.count })
        // Reuse once more after the concurrent batch: no completed invocation may consume the value.
        #expect(try await client.request(request) == expected)
        let final = measurements.withLock { $0 }
        #expect(final.filter { $0.stage == .encoding }.count == calls + 1)
        #expect(final.filter { $0.stage == .decoding }.count == calls + 1)
        #expect(session.capturedRequestsInOrder.count == calls + 1)
        await client.shutdown()
    }
}
