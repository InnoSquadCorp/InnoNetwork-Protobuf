import Foundation
import InnoNetwork
import InnoNetworkPersistentCache
import InnoNetworkProtobuf
import SwiftProtobuf

@APIDefinition(method: .get, path: "/{route}", auth: .anonymous)
private struct JSONFixtureRequest {
    typealias APIResponse = JSONReply
    let route: String
}
private struct JSONReply: Decodable, Sendable { let value: String }

@ProtobufAPIDefinition(method: .post, path: "/protobuf", auth: .anonymous)
private struct ProtobufEcho {
    typealias APIResponse = Google_Protobuf_StringValue
    let body: Google_Protobuf_StringValue
}

public struct ValidationResult: Identifiable, Codable, Sendable, Equatable {
    public let id: String
    public let passed: Bool
    public let detail: String
}

public struct ValidationReport: Codable, Sendable, Equatable {
    public let generatedAt: Date
    public let environment: String
    public let results: [ValidationResult]
    public var passed: Bool { !results.isEmpty && results.allSatisfy(\.passed) }
}

private struct CheckFailure: Error { let message: String }

public enum ValidationSuite {
    /// Synthetic payloads only. Cache survives launch; reports contain no credentials.
    public static func run(directory: URL) async throws -> ValidationReport {
        let fixture = try LoopbackFixture()
        defer { fixture.stop() }
        try await fixture.start()
        let transport = TransportPack(timeout: 8, cachePolicy: .reloadIgnoringLocalCacheData, allowsInsecureHTTP: true)
        let client = DefaultNetworkClient(
            configuration: .advanced(baseURL: LoopbackFixture.baseURL, transport: transport))
        var results: [ValidationResult] = []
        func check(_ id: String, _ body: () async throws -> String) async {
            do { results.append(ValidationResult(id: id, passed: true, detail: try await body())) } catch {
                results.append(ValidationResult(id: id, passed: false, detail: String(describing: error)))
            }
        }
        await check("JSON macro / socket") {
            let reply = try await client.request(JSONFixtureRequest(route: "json"))
            try require(reply.value == "fixture" && fixture.count("/json") == 1, "JSON/socket mismatch")
            return "Typed JSON over URLSession; one physical request"
        }
        await check("Protobuf macro / echo") {
            var body = Google_Protobuf_StringValue()
            body.value = "macro-first binary payload"
            let reply = try await client.request(ProtobufEcho(body: body))
            try require(reply == body && fixture.count("/protobuf") == 1, "Binary echo mismatch")
            return "Encoded bytes echoed through a real HTTP socket"
        }
        let retry = DefaultNetworkClient(
            configuration: .advanced(
                baseURL: LoopbackFixture.baseURL,
                resilience: .init(
                    retry: ExponentialBackoffRetryPolicy(maxRetries: 1, retryDelay: 0.01, jitterRatio: 0)),
                transport: transport))
        await check("503 / bounded retry") {
            let reply = try await retry.request(JSONFixtureRequest(route: "retry"))
            try require(reply.value == "fixture" && fixture.count("/retry") == 2, "Expected one retry")
            return "503 then 200; exactly two transport attempts"
        }
        await retry.shutdown()
        let limited = DefaultNetworkClient(
            configuration: .advanced(
                baseURL: LoopbackFixture.baseURL, resilience: .init(bodyBuffering: .streaming(maxBytes: 128)),
                transport: transport))
        await check("Response byte limit") {
            do {
                _ = try await limited.request(JSONFixtureRequest(route: "oversize"))
                throw CheckFailure(message: "Oversize unexpectedly succeeded")
            } catch let error as NetworkError {
                let failure = NetworkFailure(migratingV5: error)
                try require(
                    failure.code == NetworkErrorCode.responseBodyLimitExceeded.rawValue,
                    "Unexpected limit failure: \(failure)")
                return "4 KiB response rejected by a 128-byte budget"
            }
        }
        await limited.shutdown()
        await check("In-flight cancellation") {
            let operation = OperationNetworkClient(client: client).start(JSONFixtureRequest(route: "delay"))
            // Observe server entry, not an arbitrary sleep before cancellation.
            let deadline = ContinuousClock.now + .seconds(5)
            while fixture.count("/delay") == 0 && ContinuousClock.now < deadline {
                try await Task.sleep(for: .milliseconds(10))
            }
            guard fixture.count("/delay") == 1 else {
                operation.cancel()
                throw CheckFailure(message: "No request entry")
            }
            operation.cancel()
            do {
                _ = try await operation.value()
                throw CheckFailure(message: "Cancelled operation succeeded")
            } catch let failure as NetworkFailure {
                try require(failure.kind == .cancelled, "Unexpected cancellation: \(failure)")
                return "Cancelled after server admission; terminal cancelled failure"
            }
        }
        await client.shutdown()

        await check("Persistent cache / relaunch") {
            let cache = try PersistentResponseCache(
                configuration: .init(directoryURL: directory.appendingPathComponent("cache")))
            let existed = await cache.statistics().entryCount > 0
            let cachedClient = DefaultNetworkClient(
                configuration: .advanced(
                    baseURL: LoopbackFixture.baseURL,
                    cache: .init(
                        responseCachePolicy: .rfc9111Compliant(wrapping: .cacheFirst(maxAge: .seconds(3600))),
                        responseCache: cache),
                    transport: transport))
            do {
                let first = try await cachedClient.request(JSONFixtureRequest(route: "cache"))
                let second = try await cachedClient.request(JSONFixtureRequest(route: "cache"))
                try require(first.value == "fixture" && second.value == "fixture", "Cache payload mismatch")
                try require(fixture.count("/cache") == (existed ? 0 : 1), "Unexpected cache transport count")
                await cachedClient.shutdown()
                return existed
                    ? "Restored previous launch; zero network requests"
                    : "Cold launch persisted; second read used cache"
            } catch {
                await cachedClient.shutdown()
                throw error
            }
        }
        await check("Bounded telemetry") {
            let cache = try PersistentResponseCache(
                configuration: .init(directoryURL: directory.appendingPathComponent("telemetry"), maxEntries: 1))
            await cache.removeAll()
            _ = await cache.drainTelemetryEvents()
            for index in 0..<64 {
                await cache.set(
                    ResponseCacheKey(method: "GET", url: "https://fixture.invalid/\(index)"),
                    CachedResponse(data: Data([1])))
            }
            let events = await cache.drainTelemetryEvents()
            try require(
                events == [.scrubbedEntries(reason: .storageBudget, count: 63, byteCount: 63)],
                "Unexpected totals: \(events)")
            try require(await cache.telemetrySnapshot().isEmpty, "Drain did not reset")
            return "63 evictions retained as one aggregate; drain resets"
        }
        try Task.checkCancellation()
        let report = ValidationReport(
            generatedAt: Date(), environment: ProcessInfo.processInfo.operatingSystemVersionString, results: results)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: directory.appendingPathComponent("latest-report.json"), options: .atomic)
        return report
    }

    private static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw CheckFailure(message: message) }
    }
}
