# Recovering a cached Protobuf decoding failure

Core caches HTTP bytes before the Protobuf decoder runs. A cacheable HTTP 200
with malformed bytes can therefore fail decoding again on a cache hit. A decode
failure does not automatically evict the entry or resend the request. This is
not a reason to retry every decoding error: the server may still return the
same invalid message, or the client's schema may be incompatible.

For an explicit refresh of an idempotent GET, configure the application's client
with `.requestFreshness(wrapping: .rfc9111Compliant(wrapping: .cacheFirst(maxAge:
.seconds(60))))` and a response cache. The duration is an example, not a required
default. `.requestFreshness` is opt-in; adding a request header alone is not
sufficient for every cache policy.

The following macro-first example is compiled and executed by
[ConsumerSmoke](../Examples/ConsumerSmoke/Sources/ConsumerSmoke/CacheRecovery.swift).
The documentation check requires this block to match that source exactly.
Import `InnoNetwork`, `InnoNetworkProtobuf` and `SwiftProtobuf` in the consuming file.

```swift
@ProtobufAPIDefinition(method: .get, path: "/cached-value", auth: .anonymous)
struct CachedValue {
    typealias APIResponse = Google_Protobuf_StringValue
    let requestOptions: EncodedRequestOptions
}

func refreshCachedValue(using client: DefaultNetworkClient) async throws
    -> Google_Protobuf_StringValue
{
    // The client must opt into .requestFreshness(wrapping: ...).
    var options = EncodedRequestOptions()
    // Update one field: retain the representation's default headers.
    options.headers.update(name: "Cache-Control", value: "no-cache")
    return try await client.request(CachedValue(requestOptions: options))
}
```

Preserve the endpoint's existing options and headers when adapting this example
to an application. Replacing the entire header collection may remove defaults
such as `Accept-Language` or change authorization/representation identity. The
example creates default options because this endpoint has no custom options.
Use `.headers.update` to change only `Cache-Control` on the appropriate options.

`no-cache` requests validation before reuse; it does **not** promise a new body.
With a validator, the server may return 304 and the original malformed body may
still fail decoding. Handle that failure without an unbounded retry loop. When
necessary, use the application's explicit cache removal/replacement policy and
investigate the server/schema mismatch. Configure non-cacheable server responses
with `Cache-Control: no-store` where appropriate.

The executable example uses a response without a validator and proves two failed
reads make one transport request, one explicit refresh obtains corrected bytes,
and the next ordinary read uses the corrected cache without another request.
It is a deterministic mocked consumer check, not live-service evidence.

Response byte limits still apply on cache hits and after response/decoding
interceptors. With `captureFailurePayload: false`, decoding failures preserve
their error category without exposing the malformed body. These paths are
covered for both macro declarations and manual factories in
[ProtobufCoreBoundaryTests](../Tests/InnoNetworkProtobufTests/ProtobufCoreBoundaryTests.swift).
