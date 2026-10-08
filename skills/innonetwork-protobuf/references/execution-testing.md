# Core execution, diagnostics and recovery

Keep one application-owned Core client and its authentication, admission,
interceptors, retry, cache and operation policy. The adapter supplies buffered
serialization/decoding to Core rather than another network engine.

## Auth, retries and operation lifetime

Every factory/macro requires explicit auth intent. Required authentication fails
before serialization/transport when configuration is missing. Do not replace it
with anonymous mode to make a test or application pass.

Encoding happens once per invocation after preflight. Retries and 401 refresh
reuse those bytes; another invocation serializes again. A retryable POST needs
the application's idempotency policy and stable Idempotency-Key, with bounded
attempts. A media/decode/configuration failure does not justify automatic resend.

`client.request(...)` throws `NetworkError`. `OperationNetworkClient.start(...)`
returns an operation whose `value()` reports `NetworkFailure`; retain kind,
deadline stage and cancellation meaning rather than flattening them into a
generic transport error. Keep ownership of the operation and cancel it at the
application's intended lifetime boundary. Do not add an unrelated detached Task.
Synchronous codec work cannot be forcibly interrupted; Core checkpoints prevent
late success after cancellation/deadline. Shutdown rejects subsequent requests.

`EncodedRequestOptions.codecObserver` reports stage, byte count, monotonic duration
and success without payloads/tokens. It is synchronous: keep it short and thread
safe. Count encoding per invocation, physical attempts through Core observers.
Failure response bodies follow Core `captureFailurePayload`; use false where
payload-free diagnostics are required. Never log generated message contents as
a substitute for inspecting typed failure categories.

## Cached malformed bytes

Core can cache HTTP bytes before protobuf decode. A cacheable malformed 200 may
therefore fail again without another transport request. Decode failure does not
automatically evict, retry or bypass the cache.

For an explicit refresh of an idempotent GET, configure the client with
`.requestFreshness(wrapping: ...)` around the chosen response cache policy, then
update only the request's `Cache-Control` field to `no-cache`. Preserve the
existing options and headers, including representation/auth information.
A header alone is insufficient for every cache policy. `no-cache` requests
validation, not necessarily new bytes: a 304 can retain the malformed body.
Bound recovery and use the application's explicit removal/replacement policy
when appropriate; investigate schema/server mismatch rather than looping.

## Meaningful tests

Use generated messages and public test transports. Verify wire method/path/query,
Content-Type/Accept, serialized bytes and message values. Add the relevant failure
and passing control: strict/allowed media, nil/present-empty, exact quota boundary,
status/body mismatch, preflight before encoding, bounded retry with byte reuse,
or cancellation without late success. Avoid timing sleeps for ownership races.

The bundled exact-tag fixture is reproducible mock evidence. Use actual transport
and an application consumer when the task concerns cache persistence, socket
cancellation, TLS, device/platform lifecycle or service compatibility. Test runtime
behavior independently of a model's self-reported success.

Immutable sources: [cache recovery example](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/docs/CACHE_RECOVERY.md),
[Core boundary tests](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/blob/5e5f8316c94358235c3997e70e5e97aadc11df3a/Tests/InnoNetworkProtobufTests/ProtobufCoreBoundaryTests.swift),
[Core 6.1.1](https://github.com/InnoSquadCorp/InnoNetwork/tree/44e4ca28c50c03f817231a077c0f3bdfdbc859c8).
