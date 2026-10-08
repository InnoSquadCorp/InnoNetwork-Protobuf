#if Macros
import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import Testing
import os

@ProtobufAPIDefinition(method: .post, path: "/items/{id}", auth: .anonymous)
private struct ConfiguredEndpoint {
    typealias APIResponse = Google_Protobuf_Empty
    let id: Int
    let body: Google_Protobuf_StringValue
    let requestOptions: EncodedRequestOptions
    let protobufOptions: ProtobufCodecOptions
}

@ProtobufAPIDefinition(method: .get, path: "/identity", auth: .required)
private struct CachedEndpoint {
    typealias APIResponse = Google_Protobuf_StringValue
}
private actor CacheIdentity {
    var token = "alpha"
    func current() -> String { token }
    func change(_ value: String) { token = value }
}

@Suite("Macro/manual policy parity")
struct ProtobufMacroParityTests {
    @Test func macroAndManualCacheShareOnlyMatchingCredentials() async throws {
        var alpha = Google_Protobuf_StringValue()
        alpha.value = "alpha"
        var beta = Google_Protobuf_StringValue()
        beta.value = "beta"
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(
                statusCode: 200, data: try alpha.serializedData(),
                headers: ["Content-Type": "application/protobuf", "Cache-Control": "public, max-age=60"],
                url: URL(string: "https://example.com/identity")!),
            .http(
                statusCode: 200, data: try beta.serializedData(),
                headers: ["Content-Type": "application/protobuf", "Cache-Control": "public, max-age=60"],
                url: URL(string: "https://example.com/identity")!),
        ])
        let identity = CacheIdentity()
        let policy = RefreshTokenPolicy(
            currentToken: { await identity.current() }, refreshToken: { await identity.current() })
        let client = DefaultNetworkClient(
            configuration: .advanced(
                baseURL: URL(string: "https://example.com")!,
                auth: .init(refreshToken: policy),
                cache: .init(
                    responseCachePolicy: .cacheFirst(maxAge: .seconds(60)), responseCache: InMemoryResponseCache())),
            session: session)
        let manual = try EncodedRequest<Google_Protobuf_StringValue>.protobuf(
            method: .get, path: "/identity", auth: .required)
        #expect(try await client.request(CachedEndpoint()) == alpha)
        #expect(try await client.request(manual) == alpha)
        #expect(session.capturedRequestsInOrder.count == 1)
        await identity.change("beta")
        #expect(try await client.request(manual) == beta)
        #expect(try await client.request(CachedEndpoint()) == beta)
        #expect(session.capturedRequestsInOrder.count == 2)
        await identity.change("alpha")
        #expect(try await client.request(CachedEndpoint()) == alpha)
        #expect(session.capturedRequestsInOrder.count == 2)
    }

    @Test(arguments: [false, true], [Int64(1), 100]) func responseLimitCannotRaiseClientCap(macro: Bool, limit: Int64)
        async throws
    {
        var reply = Google_Protobuf_StringValue()
        reply.value = "oversized"
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(statusCode: 200, data: try reply.serializedData(), headers: ["Content-Type": "application/protobuf"])
        ])
        let client = DefaultNetworkClient(
            configuration: .advanced(
                baseURL: URL(string: "https://example.com")!, resilience: .init(bodyBuffering: .streaming(maxBytes: 4))),
            session: session)
        let endpoint = ConfiguredEndpoint(
            id: 1, body: .init(), requestOptions: .init(), protobufOptions: .init(decoding: .init(maximumEncodedResponseBytes: limit)))
        await #expect(throws: NetworkError.self) { try await execute(client, macro: macro, endpoint: endpoint) }
    }

    private func execute(_ client: DefaultNetworkClient, macro: Bool, endpoint: ConfiguredEndpoint) async throws
        -> Google_Protobuf_Empty
    {
        if macro { return try await client.request(endpoint) }
        return try await client.request(
            EncodedRequest<Google_Protobuf_Empty>.protobuf(
                method: .post, path: "/items/\(endpoint.id)", auth: .anonymous, body: endpoint.body,
                codec: endpoint.protobufOptions, options: endpoint.requestOptions))
    }

    @Test(arguments: [false, true]) func signingRetryAndMeasurements(macro: Bool) async throws {
        struct Sign: RequestSigner {
            func signatureHeaders(for request: URLRequest, body: RequestBody) async throws -> HTTPHeaders {
                guard case .data(let bytes) = body else { throw CancellationError() }
                return .init(["X-Signature": bytes.base64EncodedString()])
            }
        }
        struct Observe: ResponseInterceptor {
            let bytes: Data
            func adapt(_ response: Response, request: URLRequest) async throws -> Response {
                #expect(request.value(forHTTPHeaderField: "X-Signature") == bytes.base64EncodedString())
                return response
            }
        }
        var body = Google_Protobuf_StringValue()
        body.value = "secret"
        let bytes = try body.serializedData()
        let samples = OSAllocatedUnfairLock(initialState: [EncodedCodecMeasurement]())
        let options = EncodedRequestOptions(
            headers: .init(["Idempotency-Key": "parity"]),
            requestSigners: [Sign()], responseInterceptors: [Observe(bytes: bytes)],
            codecObserver: { sample in samples.withLock { $0.append(sample) } })
        let endpoint = ConfiguredEndpoint(id: 42, body: body, requestOptions: options, protobufOptions: .init())
        #expect(samples.withLock { $0.isEmpty })
        let session = MockURLSession()
        session.setScriptedResponses([
            .failure(URLError(.timedOut)), .http(statusCode: 200, headers: ["Content-Type": "application/protobuf"]),
        ])
        let client = DefaultNetworkClient(
            configuration: .advanced(
                baseURL: URL(string: "https://example.com")!,
                resilience: .init(retry: ExponentialBackoffRetryPolicy(maxRetries: 1, retryDelay: 0, jitterRatio: 0))),
            session: session)
        _ = try await execute(client, macro: macro, endpoint: endpoint)
        #expect(session.capturedRequestsInOrder.map(\.httpBody) == [bytes, bytes])
        #expect(samples.withLock { $0.map(\.stage) } == [.encoding, .decoding])
        #expect(samples.withLock { $0.allSatisfy(\.succeeded) })
    }

    @Test(arguments: [false, true], [0, 100]) func requestLimit(macro: Bool, limit: Int) async throws {
        var body = Google_Protobuf_StringValue()
        body.value = "bounded"
        let endpoint = ConfiguredEndpoint(
            id: 1, body: body, requestOptions: .init(), protobufOptions: .init(encoding: .init(maximumEncodedRequestBytes: limit)))
        let session = MockURLSession()
        session.setScriptedResponses([.http(statusCode: 200, headers: ["Content-Type": "application/protobuf"])])
        let client = DefaultNetworkClient(
            configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
        if limit == 0 {
            do {
                _ = try await execute(client, macro: macro, endpoint: endpoint)
                Issue.record("limit ignored")
            } catch NetworkError.configuration(reason: .invalidPayload(.requestBodyLimit)) {}
            #expect(session.capturedRequestsInOrder.isEmpty)
        } else {
            _ = try await execute(client, macro: macro, endpoint: endpoint)
            #expect(session.capturedRequestsInOrder.count == 1)
        }
    }

    @Test func concurrentEndpointsKeepIndependentBodies() async throws {
        let session = MockURLSession()
        session.setScriptedResponses(
            Array(repeating: .http(statusCode: 200, headers: ["Content-Type": "application/protobuf"]), count: 64))
        let client = DefaultNetworkClient(
            configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
        try await withThrowingTaskGroup(of: Void.self) { group in
            for id in 0..<64 {
                group.addTask {
                    var body = Google_Protobuf_StringValue()
                    body.value = "\(id)"
                    _ = try await client.request(
                        ConfiguredEndpoint(id: id, body: body, requestOptions: .init(), protobufOptions: .init()))
                }
            }
            try await group.waitForAll()
        }
        let requests = session.capturedRequestsInOrder
        #expect(requests.count == 64)
        for request in requests {
            let bytes = try #require(request.httpBody)
            #expect(try Google_Protobuf_StringValue(serializedBytes: bytes).value == request.url?.lastPathComponent)
        }
    }

    @Test func cancellationAfterEntryHasOneTerminalEvent() async throws {
        struct Hold: RequestInterceptor {
            let entered: AsyncStream<Void>.Continuation
            func adapt(_ request: URLRequest) async throws -> URLRequest {
                entered.yield(())
                try await Task.sleep(for: .seconds(60))
                return request
            }
        }
        let (entered, continuation) = AsyncStream<Void>.makeStream()
        let endpoint = ConfiguredEndpoint(
            id: 1, body: .init(), requestOptions: .init(requestInterceptors: [Hold(entered: continuation)]),
            protobufOptions: .init())
        let session = MockURLSession()
        let client = DefaultNetworkClient(
            configuration: .safeDefaults(baseURL: URL(string: "https://example.com")!), session: session)
        let handle = OperationNetworkClient(client: client).start(endpoint)
        var iterator = entered.makeAsyncIterator()
        await iterator.next()
        handle.cancel()
        do {
            _ = try await handle.value()
            Issue.record("cancellation ignored")
        } catch { #expect(error.kind == .cancelled) }
        var failed = 0
        for await event in handle.events { if case .failed = event { failed += 1 } }
        #expect(failed == 1)
        #expect(session.capturedRequestsInOrder.isEmpty)
        continuation.finish()
    }
}
#endif
