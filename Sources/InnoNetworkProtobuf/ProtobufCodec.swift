import Foundation
import InnoNetwork
import SwiftProtobuf

/// Explicit binary HTTP media profile. No JSON or gRPC framing is inferred.
public enum ProtobufMediaType: String, Sendable, Hashable {
    case standard = "application/protobuf"
    case legacy = "application/x-protobuf"
}

/// Payload-free protobuf decoding categories. No foreign error text or bytes are retained.
public enum ProtobufDecodingFailure: Int, Error, Sendable, CustomNSError {
    case malformedMessage = 1
    case truncatedMessage
    case invalidUTF8
    case missingRequiredFields
    case nestingLimitExceeded
    case extensionDecodingFailure
    case invalidMediaType

    public static var errorDomain: String { "InnoNetworkProtobuf.Decoding" }
    public var errorCode: Int { rawValue }
    public var errorUserInfo: [String: Any] { [:] }

    static func classify(_ error: any Error) -> Self {
        if let failure = error as? Self { return failure }
        guard let failure = error as? BinaryDecodingError else { return .malformedMessage }
        switch failure {
        case .trailingGarbage, .malformedProtobuf: return .malformedMessage
        case .truncated: return .truncatedMessage
        case .invalidUTF8: return .invalidUTF8
        case .missingRequiredFields: return .missingRequiredFields
        case .messageDepthLimit: return .nestingLimitExceeded
        case .internalExtensionError: return .extensionDecodingFailure
        @unknown default: return .malformedMessage
        }
    }
}

/// Request serialization only. The byte budget is checked after encoding, before transport;
/// it does not cap temporary allocation or synchronous CPU time. Deterministic is not canonical.
public struct ProtobufEncodingOptions: Sendable {
    public let maximumEncodedRequestBytes: Int?
    public let deterministic: Bool
    public let mediaType: ProtobufMediaType

    public init(maximumEncodedRequestBytes: Int? = nil, deterministic: Bool = false,
                mediaType: ProtobufMediaType = .standard) {
        self.maximumEncodedRequestBytes = maximumEncodedRequestBytes
        self.deterministic = deterministic
        self.mediaType = mediaType
    }

    func validate() throws {
        guard maximumEncodedRequestBytes.map({ $0 >= 0 }) ?? true else {
            throw EncodedPayloadFailure.invalidLimit
        }
    }
}

/// Response decoding only. The byte ceiling bounds serialized input, not the decoded object graph.
/// Collection is also bounded when these options are used by an EncodedRequest factory.
public struct ProtobufDecodingOptions: Sendable {
    public let maximumEncodedResponseBytes: Int64?
    public let maximumDepth: Int
    public let discardUnknownFields: Bool
    public let acceptedMediaTypes: Set<ProtobufMediaType>
    public let allowsMissingContentType: Bool

    public init(maximumEncodedResponseBytes: Int64? = nil, maximumDepth: Int = 100,
                discardUnknownFields: Bool = false,
                acceptedMediaTypes: Set<ProtobufMediaType> = [.standard],
                allowsMissingContentType: Bool = false) {
        self.maximumEncodedResponseBytes = maximumEncodedResponseBytes
        self.maximumDepth = maximumDepth
        self.discardUnknownFields = discardUnknownFields
        self.acceptedMediaTypes = acceptedMediaTypes
        self.allowsMissingContentType = allowsMissingContentType
    }

    func validate() throws {
        guard maximumDepth > 0, maximumEncodedResponseBytes.map({ $0 >= 0 }) ?? true else {
            throw EncodedPayloadFailure.invalidLimit
        }
        guard !acceptedMediaTypes.isEmpty else { throw ProtobufDecodingFailure.invalidMediaType }
    }

    func validateMedia(_ raw: String?) throws {
        guard let raw else {
            if allowsMissingContentType { return }
            throw ProtobufDecodingFailure.invalidMediaType
        }
        let type = try ProtobufMedia.parse(raw)
        guard acceptedMediaTypes.contains(type) else { throw ProtobufDecodingFailure.invalidMediaType }
    }

    var acceptHeader: String { acceptedMediaTypes.map(\.rawValue).sorted().joined(separator: ", ") }
}

/// Independent request and response policy. Neither direction constrains the other's media profile.
public struct ProtobufCodecOptions: Sendable {
    public let encoding: ProtobufEncodingOptions
    public let decoding: ProtobufDecodingOptions

    public init(encoding: ProtobufEncodingOptions = .init(), decoding: ProtobufDecodingOptions = .init()) {
        self.encoding = encoding
        self.decoding = decoding
    }

    func requestOptions(_ options: EncodedRequestOptions, hasBody: Bool) throws(NetworkError)
        -> EncodedRequestOptions {
        do { try encoding.validate(); try decoding.validate() }
        catch let failure as EncodedPayloadFailure { throw .configuration(reason: .invalidPayload(failure)) }
        catch { throw .configuration(reason: .invalidPayload(.mediaType)) }
        var result = try ProtobufMedia.requestOptions(options, encoding: encoding, hasBody: hasBody)
        let values = result.headers.values(for: "Accept")
        guard values.count <= 1 else { throw .configuration(reason: .invalidPayload(.mediaType)) }
        if let raw = values.first {
            do {
                let media = try raw.split(separator: ",", omittingEmptySubsequences: false).map {
                    try ProtobufMedia.parse(String($0))
                }
                guard Set(media) == decoding.acceptedMediaTypes, media.count == Set(media).count else {
                    throw ProtobufDecodingFailure.invalidMediaType
                }
            } catch { throw .configuration(reason: .invalidPayload(.mediaType)) }
        }
        result.headers.update(name: "Accept", value: decoding.acceptHeader)
        if let limit = decoding.maximumEncodedResponseBytes {
            result.maximumResponseBytes = min(limit, result.maximumResponseBytes ?? limit)
        }
        return result
    }
}

private enum ProtobufMedia {
    // Deliberately strict binary profile: only encoding=binary is supported. This is not
    // a general MIME parser; additional schema parameters require a future explicit policy.
    static func parse(_ raw: String) throws -> ProtobufMediaType {
        let parts = raw.split(separator: ";", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = parts.first, let type = ProtobufMediaType(rawValue: first.lowercased()) else {
            throw ProtobufDecodingFailure.invalidMediaType
        }
        var seen = Set<String>()
        for part in parts.dropFirst() {
            let pair = part.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard pair.count == 2 else { throw ProtobufDecodingFailure.invalidMediaType }
            let key = pair[0].trimmingCharacters(in: .whitespaces).lowercased()
            var value = pair[1].trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\""), value.hasSuffix("\""), value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            guard seen.insert(key).inserted, key == "encoding", value == "binary" else {
                throw ProtobufDecodingFailure.invalidMediaType
            }
        }
        return type
    }

    static func requestOptions(_ options: EncodedRequestOptions, encoding: ProtobufEncodingOptions,
                               hasBody: Bool) throws(NetworkError) -> EncodedRequestOptions {
        do { try encoding.validate() } catch { throw .configuration(reason: .invalidPayload(.invalidLimit)) }
        var result = options
        let values = result.headers.values(for: "Content-Type")
        guard values.count <= 1 else { throw .configuration(reason: .invalidPayload(.mediaType)) }
        if let raw = values.first {
            do {
                guard try parse(raw) == encoding.mediaType else { throw ProtobufDecodingFailure.invalidMediaType }
            } catch { throw .configuration(reason: .invalidPayload(.mediaType)) }
        }
        if hasBody { result.headers.update(name: "Content-Type", value: encoding.mediaType.rawValue) }
        else { result.headers.remove(name: "Content-Type") }
        return result
    }
}

extension EncodedRequestBody {
    /// Creates a deferred encoder using only SwiftProtobuf's supported public API.
    public static func protobuf<Message: SwiftProtobuf.Message & Sendable>(
        _ message: Message, options: ProtobufEncodingOptions = .init()
    ) -> Self {
        Self(contentType: options.mediaType.rawValue, maximumBytes: options.maximumEncodedRequestBytes) {
            try options.validate()
            var encoding = BinaryEncodingOptions()
            encoding.useDeterministicOrdering = options.deterministic
            return try message.serializedData(options: encoding)
        }
    }
}

extension AnyResponseDecoder where Output: SwiftProtobuf.Message {
    /// Empty bytes are decoded as a message; required proto2 fields remain enforced.
    public static func protobuf(options: ProtobufDecodingOptions = .init()) -> Self {
        Self { data, response in
            do {
                try options.validate()
                try options.validateMedia(response.response?.value(forHTTPHeaderField: "Content-Type"))
                if let limit = options.maximumEncodedResponseBytes, Int64(data.count) > limit {
                    throw EncodedPayloadFailure.responseBodyLimit
                }
                var decoding = BinaryDecodingOptions()
                decoding.messageDepthLimit = options.maximumDepth
                decoding.discardUnknownFields = options.discardUnknownFields
                return try Output(serializedBytes: data, options: decoding)
            } catch is CancellationError {
                throw NetworkError.cancelled
            } catch {
                let underlying: SendableUnderlyingError
                if let failure = error as? EncodedPayloadFailure { underlying = SendableUnderlyingError(failure) }
                else { underlying = SendableUnderlyingError(ProtobufDecodingFailure.classify(error)) }
                throw NetworkError.decoding(stage: .responseBody, underlying: underlying, response: response)
            }
        }
    }
}

extension EncodedRequest where Output: SwiftProtobuf.Message {
    /// Nil is an absent HTTP body; a present default message still has a body.
    public static func protobuf<Message: SwiftProtobuf.Message & Sendable>(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        body: Message?, codec: ProtobufCodecOptions = .init(), options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        Self(
            method: method, path: path, auth: auth,
            body: body.map { .protobuf($0, options: codec.encoding) },
            options: try codec.requestOptions(options, hasBody: body != nil),
            responseDecoder: .protobuf(options: codec.decoding))
    }

    /// Sends a protobuf body and decodes a protobuf response through the core executor.
    public static func protobuf<Message: SwiftProtobuf.Message & Sendable>(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        body: Message, codec: ProtobufCodecOptions = .init(), options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        Self(
            method: method, path: path, auth: auth, body: .protobuf(body, options: codec.encoding),
            options: try codec.requestOptions(options, hasBody: true),
            responseDecoder: .protobuf(options: codec.decoding))
    }

    /// Bodyless request; query items remain ordinary HTTP query values, not protobuf bytes.
    public static func protobuf(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        codec: ProtobufCodecOptions = .init(), options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        Self(
            method: method, path: path, auth: auth,
            options: try codec.requestOptions(options, hasBody: false),
            responseDecoder: .protobuf(options: codec.decoding))
    }
}

extension EncodedRequest where Output == EmptyResponse {
    /// Explicit empty HTTP response contract. No protobuf decoder or response media policy is used.
    public static func protobufEmptyResponse<Message: SwiftProtobuf.Message & Sendable>(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        body: Message?, encoding: ProtobufEncodingOptions = .init(),
        statusCodes: Set<Int> = [204, 205], options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        guard !statusCodes.isEmpty, statusCodes.allSatisfy({ (200...299).contains($0) }) else {
            throw .configuration(reason: .invalidRequest("Empty response status codes must be nonempty successful HTTP codes."))
        }
        return Self(method: method, path: path, auth: auth,
                    body: body.map { .protobuf($0, options: encoding) },
                    options: try ProtobufMedia.requestOptions(options, encoding: encoding, hasBody: body != nil),
                    responseDecoder: .noContent(statusCodes: statusCodes))
    }

    /// A bodyless request with an explicitly empty HTTP response, not a protobuf Empty message.
    public static func protobufEmptyResponse(
        method: HTTPMethod, path: String, auth: SessionAuthentication,
        encoding: ProtobufEncodingOptions = .init(), statusCodes: Set<Int> = [204, 205],
        options: EncodedRequestOptions = .init()
    ) throws(NetworkError) -> Self {
        try protobufEmptyResponse(method: method, path: path, auth: auth,
                                  body: Optional<Google_Protobuf_Empty>.none, encoding: encoding,
                                  statusCodes: statusCodes, options: options)
    }
}
