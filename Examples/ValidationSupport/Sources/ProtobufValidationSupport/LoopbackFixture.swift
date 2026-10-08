import Foundation
import Network
import os

/// Sample-only HTTP fixture. Real sockets and URLSession, not a production server.
/// Fixed loopback port keeps persistent cache identity stable across app launches.
public final class LoopbackFixture: Sendable {
    public static let baseURL = URL(string: "http://127.0.0.1:18764")!
    private let queue = DispatchQueue(label: "network-validation.fixture")
    private let listener: NWListener
    private struct State {
        var counts: [String: Int] = [:]
        var connections: [ObjectIdentifier: NWConnection] = [:]
        var stopped = false
        var ready: CheckedContinuation<Void, any Error>?
    }
    private let state = OSAllocatedUnfairLock(initialState: State())

    public init() throws {
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: 18764)
        parameters.allowLocalEndpointReuse = true
        listener = try NWListener(using: parameters)
    }

    public func start() async throws {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let stopped = state.withLock { state in
                    if state.stopped { return true }
                    state.ready = continuation
                    return false
                }
                guard !stopped else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                listener.stateUpdateHandler = { [weak self] status in
                    guard let self else { return }
                    switch status {
                    case .ready: self.completeStart(nil)
                    case .failed(let error): self.completeStart(error)
                    case .cancelled: self.completeStart(CancellationError())
                    default: break
                    }
                }
                listener.newConnectionHandler = { [weak self] connection in self?.accept(connection) }
                listener.start(queue: queue)
            }
        } onCancel: {
            self.stop()
        }
    }

    private func completeStart(_ error: (any Error)?) {
        let continuation = state.withLock { state in
            let continuation = state.ready
            state.ready = nil
            return continuation
        }
        if let error { continuation?.resume(throwing: error) } else { continuation?.resume() }
    }

    public func stop() {
        let connections = state.withLock { state in
            state.stopped = true
            let connections = Array(state.connections.values)
            state.connections.removeAll()
            return connections
        }
        completeStart(CancellationError())
        listener.cancel()
        for connection in connections { connection.cancel() }
    }

    public func count(_ path: String) -> Int { state.withLock { $0.counts[path, default: 0] } }

    private func accept(_ connection: NWConnection) {
        let admitted = state.withLock { state in
            guard !state.stopped, state.connections.count < 32 else { return false }
            state.connections[ObjectIdentifier(connection)] = connection
            return true
        }
        guard admitted else {
            connection.cancel()
            return
        }
        connection.start(queue: queue)
        receive(connection, accumulated: Data())
    }

    private func close(_ connection: NWConnection) {
        state.withLock { $0.connections[ObjectIdentifier(connection)] = nil }
        connection.cancel()
    }

    private func receive(_ connection: NWConnection, accumulated: Data) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 16_384) { [weak self] data, _, complete, error in
            guard let self else {
                connection.cancel()
                return
            }
            var bytes = accumulated
            if let data { bytes.append(data) }
            guard error == nil, bytes.count <= 65_536 else {
                self.close(connection)
                return
            }
            if let separator = bytes.range(of: Data("\r\n\r\n".utf8)) {
                let header = String(decoding: bytes[..<separator.lowerBound], as: UTF8.self)
                let lines = header.components(separatedBy: "\r\n")
                let fields = lines.dropFirst().compactMap { line -> (String, String)? in
                    guard let colon = line.firstIndex(of: ":") else { return nil }
                    return (
                        line[..<colon].lowercased(),
                        line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                    )
                }
                let lengths = fields.filter { $0.0 == "content-length" }
                guard lengths.count <= 1,
                    let length = Int(lengths.first?.1 ?? "0"), (0...32_768).contains(length),
                    !fields.contains(where: { $0.0 == "transfer-encoding" })
                else {
                    self.close(connection)
                    return
                }
                if bytes.count - separator.upperBound >= length {
                    let path = lines[0].split(separator: " ").dropFirst().first.map(String.init) ?? "/"
                    let attempt = self.state.withLock { state in
                        state.counts[path, default: 0] += 1
                        return state.counts[path, default: 0]
                    }
                    let body = Data(bytes[separator.upperBound..<separator.upperBound + length])
                    self.respond(connection, path: path, body: body, attempt: attempt)
                    return
                }
            }
            guard !complete else {
                self.close(connection)
                return
            }
            self.receive(connection, accumulated: bytes)
        }
    }

    private func respond(_ connection: NWConnection, path: String, body: Data, attempt: Int) {
        let status = path == "/retry" && attempt == 1 ? 503 : 200
        let protobuf = path == "/protobuf"
        let payload =
            protobuf
            ? body
            : Data(
                (path == "/oversize"
                    ? "{\"value\":\"\(String(repeating: "x", count: 4_096))\"}" : "{\"value\":\"fixture\"}").utf8)
        let contentType = protobuf ? "application/protobuf" : "application/json"
        let cacheControl = path == "/cache" ? "public, max-age=3600" : "no-store"
        var response = Data(
            "HTTP/1.1 \(status) Fixture\r\nContent-Length: \(payload.count)\r\nContent-Type: \(contentType)\r\nCache-Control: \(cacheControl)\r\nConnection: close\r\n\r\n"
                .utf8)
        response.append(payload)
        let reply = response
        queue.asyncAfter(deadline: .now() + (path == "/delay" ? 3 : 0)) { [weak self] in
            guard let self else {
                connection.cancel()
                return
            }
            connection.send(content: reply, completion: .contentProcessed { _ in self.close(connection) })
        }
    }
}
