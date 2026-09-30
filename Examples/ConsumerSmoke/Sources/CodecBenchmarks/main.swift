import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import os

// Informational first baseline, not a regression guard or peak-memory claim.
struct Sample: Encodable {
    let name: String
    let bytes: Int
    let encodingNanoseconds: Int64
    let decodingNanoseconds: Int64
}

func nanoseconds(_ duration: Duration) -> Int64 {
    duration.components.seconds * 1_000_000_000 + duration.components.attoseconds / 1_000_000_000
}

func measure<Message: SwiftProtobuf.Message & Sendable>(
    _ name: String, message: Message, deterministic: Bool = false
) async throws -> [Sample] {
    let bytes = try message.serializedData()
    var samples: [Sample] = []
    for iteration in 0..<8 {
        let observed = OSAllocatedUnfairLock(initialState: [EncodedCodecMeasurement]())
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(statusCode: 200, data: bytes, headers: ["Content-Type": "application/protobuf"])
        ])
        let client = DefaultNetworkClient(
            configuration: .advanced(
                baseURL: URL(string: "https://example.invalid")!,
                resilience: .init(bodyBuffering: .streaming(maxBytes: 16 * 1024 * 1024))),
            session: session)
        let request = try EncodedRequest<Message>.protobuf(
            method: .post, path: "/measure", auth: .anonymous, body: message,
            codec: .init(maximumRequestBytes: 16 * 1024 * 1024, deterministic: deterministic),
            options: .init(codecObserver: { sample in observed.withLock { $0.append(sample) } }))
        let result = try await client.request(request)
        precondition(result.isEqualTo(message: message))
        let timings = observed.withLock { $0 }
        precondition(timings.count == 2 && timings.allSatisfy(\.succeeded))
        if iteration >= 2 {
            samples.append(
                .init(
                    name: name, bytes: bytes.count,
                    encodingNanoseconds: nanoseconds(timings[0].duration),
                    decodingNanoseconds: nanoseconds(timings[1].duration)))
        }
        await client.shutdown()
    }
    return samples
}

var samples: [Sample] = []
for size in [8 * 1024, 1024 * 1024, 8 * 1024 * 1024] {
    var message = Google_Protobuf_BytesValue()
    message.value = Data(repeating: 0x41, count: size)
    samples += try await measure("bytes-\(size)", message: message)
}
var map = Google_Protobuf_Struct()
for index in 0..<1000 {
    var value = Google_Protobuf_Value()
    value.numberValue = Double(index)
    map.fields["key-\(index)"] = value
}
samples += try await measure("map-1000-deterministic", message: map, deterministic: true)
var nested = Google_Protobuf_Value()
nested.stringValue = "leaf"
for _ in 0..<20 {
    var list = Google_Protobuf_ListValue()
    list.values = [nested]
    var value = Google_Protobuf_Value()
    value.listValue = list
    nested = value
}
samples += try await measure("nested-20", message: nested)
let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
print(String(decoding: try encoder.encode(samples), as: UTF8.self))
