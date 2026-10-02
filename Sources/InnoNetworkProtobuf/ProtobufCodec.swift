import Foundation
import InnoNetwork
import SwiftProtobuf

/// Explicit binary HTTP media profile. No JSON or gRPC framing is inferred.
public enum ProtobufMediaType: String, Sendable {
    case standard = "application/protobuf"
    case legacy = "application/x-protobuf"
}

/// Per-request protobuf policy. Byte budgets are transmission/collection limits,
/// not a bound on intermediate serializer allocations. Deterministic is not canonical.
public struct ProtobufCodingOptions: Sendable {
    public let maximumRequestBytes: Int?
    public let maximumResponseBytes: Int64?
    public let maximumDecodingDepth: Int
    public let discardUnknownFields: Bool
    public let deterministic: Bool
    public let mediaType: ProtobufMediaType
    public let acceptsLegacyMediaType: Bool
    public let allowsMissingContentType: Bool

    public init(
        maximumRequestBytes: Int? = nil,
        maximumResponseBytes: Int64? = nil,
        maximumDecodingDepth: Int = 100,
        discardUnknownFields: Bool = false,
        deterministic: Bool = false,
        mediaType: ProtobufMediaType = .standard,
        acceptsLegacyMediaType: Bool = false,
        allowsMissingContentType: Bool = false
    ) {
        self.maximumRequestBytes = maximumRequestBytes
        self.maximumResponseBytes = maximumResponseBytes
        self.maximumDecodingDepth = maximumDecodingDepth
        self.discardUnknownFields = discardUnknownFields
        self.deterministic = deterministic
        self.mediaType = mediaType
        self.acceptsLegacyMediaType = acceptsLegacyMediaType
        self.allowsMissingContentType = allowsMissingContentType
    }

    func validate() throws {
        guard maximumDecodingDepth > 0,
            maximumRequestBytes.map({ $0 >= 0 }) ?? true,
            maximumResponseBytes.map({ $0 >= 0 }) ?? true
        else { throw EncodedPayloadFailure.invalidLimit }
    }

    func validateMedia(_ raw: String?) throws {
        guard let raw else {
            if allowsMissingContentType { return }
            throw EncodedPayloadFailure.mediaType
        }
        let parts = raw.split(separator: ";", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let type = parts[0].lowercased()
        guard
            type == mediaType.rawValue
                || (acceptsLegacyMediaType && type == ProtobufMediaType.legacy.rawValue)
        else { throw EncodedPayloadFailure.mediaType }
        var seen = Set<String>()
        for part in parts.dropFirst() {
            let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { throw EncodedPayloadFailure.mediaType }
            let key = pair[0].trimmingCharacters(in: .whitespaces).lowercased()
            var value = pair[1].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            guard seen.insert(key).inserted,
                key == "encoding" && value == "binary"
            else { throw EncodedPayloadFailure.mediaType }
        }
    }

    func requestOptions(_ options: EncodedRequestOptions, hasBody: Bool) throws(NetworkError)
        -> EncodedRequestOptions
    {
        do { try validate() } catch { throw .configuration(reason: .invalidPayload(.invalidLimit)) }
        var result = options
        for name in ["Content-Type", "Accept"] {
            let values = result.headers.values(for: name)
            guard values.isEmpty || (values.count == 1 && values[0] == mediaType.rawValue) else {
                throw .configuration(reason: .invalidPayload(.mediaType))
            }
        }
        result.headers.update(name: "Accept", value: mediaType.rawValue)
        if hasBody {
            result.headers.update(name: "Content-Type", value: mediaType.rawValue)
        } else {
            result.headers.remove(name: "Content-Type")
        }
        if let maximumResponseBytes {
            result.maximumResponseBytes = min(
                maximumResponseBytes, result.maximumResponseBytes ?? maximumResponseBytes)
        }
        return result
    }
}

extension EncodedRequestBody {
    /// Creates a deferred encoder using only SwiftProtobuf's supported public API.
    public static func protobuf<Message: SwiftProtobuf.Message & Sendable>(
        _ message: Message, options: ProtobufCodingOptions = .init()
    ) -> Self {
        Self(contentType: options.mediaType.rawValue, maximumBytes: options.maximumRequestBytes) {
            try options.validate()
            var encoding = BinaryEncodingOptions()
            encoding.useDeterministicOrdering = options.deterministic
            return try message.serializedData(options: encoding)
        }
    }
}

extension AnyResponseDecoder where Output: SwiftProtobuf.Message {
    /// Empty bytes are decoded as a message; required proto2 fields remain enforced.
    public static func protobuf(options: ProtobufCodingOptions = .init()) -> Self {
        Self { data, response in
            do {
                try options.validate()
                try options.validateMedia(response.response?.value(forHTTPHeaderField: "Content-Type"))
                if let limit = options.maximumResponseBytes, Int64(data.count) > limit {
                    throw EncodedPayloadFailure.responseBodyLimit
                }
                var decoding = BinaryDecodingOptions()
                decoding.messageDepthLimit = options.maximumDecodingDepth
                decoding.discardUnknownFields = options.discardUnknownFields
                return try Output(serializedBytes: data, options: decoding)
            } catch is CancellationError {
                throw NetworkError.cancelled
            } catch {
                let failure = (error as? EncodedPayloadFailure) ?? .decoding
                throw NetworkError.decoding(
                    stage: .responseBody, underlying: SendableUnderlyingError(failure), response: response)
            }
        }
    }
}

extension EncodedRequest where Output: SwiftProtobuf.Message {
    /// Nil is an absent HTTP body; a present default message still has a body.
    public static func protobuf<Message: SwiftProtobuf.Message & Sendable>(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        body: Message?, codec: ProtobufCodingOptions = .init(), options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        Self(
            method: method, path: path, auth: auth,
            body: body.map { .protobuf($0, options: codec) },
            options: try codec.requestOptions(options, hasBody: body != nil),
            responseDecoder: .protobuf(options: codec))
    }

    /// Sends a protobuf body and decodes a protobuf response through the core executor.
    public static func protobuf<Message: SwiftProtobuf.Message & Sendable>(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        body: Message, codec: ProtobufCodingOptions = .init(), options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        Self(
            method: method, path: path, auth: auth, body: .protobuf(body, options: codec),
            options: try codec.requestOptions(options, hasBody: true),
            responseDecoder: .protobuf(options: codec))
    }

    /// Bodyless request; query items remain ordinary HTTP query values, not protobuf bytes.
    public static func protobuf(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        codec: ProtobufCodingOptions = .init(), options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        Self(
            method: method, path: path, auth: auth,
            options: try codec.requestOptions(options, hasBody: false),
            responseDecoder: .protobuf(options: codec))
    }
}

extension EncodedRequest where Output == EmptyResponse {
    /// A protobuf request body with explicit HTTP no-content (204/205) response semantics.
    public static func protobufNoContent<Message: SwiftProtobuf.Message & Sendable>(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        body: Message?, codec: ProtobufCodingOptions = .init(), options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        Self(
            method: method, path: path, auth: auth,
            body: body.map { .protobuf($0, options: codec) },
            options: try codec.requestOptions(options, hasBody: body != nil), responseDecoder: .noContent())
    }

    /// A bodyless request with an explicitly empty HTTP response, not a protobuf Empty message.
    public static func protobufNoContent(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        codec: ProtobufCodingOptions = .init(), options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        Self(
            method: method, path: path, auth: auth,
            options: try codec.requestOptions(options, hasBody: false), responseDecoder: .noContent())
    }
}
