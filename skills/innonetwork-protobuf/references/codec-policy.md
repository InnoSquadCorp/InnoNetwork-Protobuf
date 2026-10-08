# Directional media, empty values and limits

`ProtobufCodecOptions(encoding:decoding:)` separates request and response policy.
`ProtobufEncodingOptions` owns Content-Type, `deterministic` and
`maximumEncodedRequestBytes: Int?`. `ProtobufDecodingOptions` owns
`acceptedMediaTypes`, `allowsMissingContentType`, `maximumDepth`,
`discardUnknownFields`, and `maximumEncodedResponseBytes: Int64?`.

The default profile is `application/protobuf` (`.standard`). `.legacy` means
`application/x-protobuf`. A legacy request may receive a standard response:

```swift
let codec = ProtobufCodecOptions(
    encoding: .init(mediaType: .legacy),
    decoding: .init(acceptedMediaTypes: [.standard, .legacy]))
```

Accept advertises the entire response set. Supplied Accept must match that set
without duplicates, and Content-Type must agree with the encoding profile.
Conflicting/duplicate headers fail configuration. The strict binary MIME subset
accepts only `encoding=binary`; additional schema/charset/JSON parameters and
gRPC media/framing are unsupported. There is no format guessing or retry with a
different media type after HTTP 415. Missing response Content-Type needs explicit
`allowsMissingContentType: true`; it does not relax request header validation.

## Three distinct empty cases

| Intent | Contract |
| --- | --- |
| No request body | Omit `body` or pass typed optional nil; no Content-Type |
| Present protobuf message with zero encoded bytes | Pass the message; body and Content-Type remain present |
| HTTP no-content response | `APIResponse = EmptyResponse`, macro `response: .empty()` (204/205) or explicit successful `statusCodes`; response must have no observed body |

`Google_Protobuf_Empty` is a generated protobuf message with unknown fields and
their equality/serialization behavior. It is not an alias for HTTP no-content.
For manual HTTP-empty requests use `EncodedRequest<EmptyResponse>.
protobufEmptyResponse(...)`, which accepts encoding options and status codes,
not unused response-decoding policy. To accept empty HTTP 200, opt in with
`.empty(statusCodes: [200, 204])`. Malformed bytes never become successful empty
responses. Proto3 zero-byte messages decode normally; proto2 required fields
remain required.

## Resource and error boundaries

- Byte budgets must be nonnegative; decoding depth must be positive and its
  accepted-media set nonempty. Factory-time validation can fail before execution.
- Request quota is checked after encoding and before transport. It does not cap
  temporary encoder allocation/CPU or bodies replaced by trusted interceptors.
- Factory response quota tightens Core's collection limit and is checked again
  before decode. It cannot raise an existing lower limit. Serialized-byte quota
  and maximumDepth are not a total decoded-memory ceiling.
- Depth defaults to 100; unknown fields are retained unless explicitly discarded.
  Deterministic ordering is opt-in and not canonical cross-language signing data.
- Encoding/configuration/request-limit failure uses `NetworkError.configuration`
  with `EncodedPayloadFailure`; do not classify it as a retryable timeout.
- Decode/media failures use `.decoding(stage: .responseBody, ...)`. Read
  `ProtobufDecodingFailure.errorDomain` and codes for malformed/truncated messages,
  invalid UTF-8, required fields, depth, extensions or media. Limit failures retain
  Core's `EncodedPayloadFailure` codes; Core collection overflow can arrive as
  `.underlying` with `NetworkErrorCode.responseBodyLimitExceeded` before decoding.

Immutable [codec implementation](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/Sources/InnoNetworkProtobuf/ProtobufCodec.swift)
and [boundary tests](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/Tests/InnoNetworkProtobufTests/ProtobufLimitAndReuseTests.swift)
define the baseline behavior.
