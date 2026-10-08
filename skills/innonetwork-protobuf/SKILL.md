---
name: innonetwork-protobuf
description: Implement, test, diagnose, or migrate Swift Protocol Buffers over HTTP with InnoNetwork-Protobuf when the project uses this adapter or the user requests it. Use for ProtobufAPIDefinition, generated messages, binary media policy, codec limits, and Core execution. Not a gRPC client, schema generator, or a reason to replace unrelated JSON networking.
---

# InnoNetwork-Protobuf

Use the consumer's resolved adapter and Core contracts. This skill supports
stable **6.1.x** (`>=6.1.0 <6.2.0`); its historical validated baseline is the adapter's
withdrawn **6.1.1 tag** with **InnoNetwork 6.1.1**. A newly issued tag requires
its own identity and consumer validation. A support range is not evidence that
every patch exists or has been tested. See [support.json](references/support.json).

## Establish both dependencies

Read the manifest and applicable lockfile for adapter/Core versions and revisions,
products, traits and toolchain. Identify local paths as local. Preserve the
consumer's chosen versions unless the task calls for a dependency change.

- The 6.1.1 adapter requires **exact Core 6.1.1**, not an arbitrary Core 6.1.x.
  For another adapter patch, inspect that patch's manifest before selecting its
  Core counterpart; matching version labels do not prove compatible constraints.
- Keep later stable 6.1.x patches, check their tag/API/manifest differences and
  test the changed consumer. Do not downgrade to the fixture or claim untested
  patches passed. No adapter 6.1.0 tag was present at the recorded check.
- For 3.x, 6.0, 6.2+, prereleases or moving branches, establish their exact surface
  first. The historical 3.x protocol shares the new macro's spelling but is not
  compatible with it. [Compatibility and migration](references/compatibility.md).
- For new adoption, verify the actual tag and resolved commit. The 6.1.1 tag was
  verified separately from its GitHub Release page, which was absent at check.
  Historical pre-publication wording does not override the verified tag identity.

## Choose a workflow

| Task | Read |
| --- | --- |
| Named HTTP endpoint, body/query, test transport | [implementation.md](references/implementation.md) and [compiled endpoints](assets/consumer/Sources/ProtobufSkillExample/Endpoints.swift) |
| Media compatibility, Empty, malformed bytes, limits | [codec-policy.md](references/codec-policy.md) |
| Auth, retries, operations, cancellation, cached decode failure | [execution-testing.md](references/execution-testing.md) |
| Version pair, products, macro opt-out, 3.x migration | [compatibility.md](references/compatibility.md) |

Read only the references needed by the task. Use `@ProtobufAPIDefinition` on an
explicit struct for named endpoints. Use generated `SwiftProtobuf.Message &
Sendable` values; never add fake Codable conformance or hand-write their wire
implementation. The bundled example uses well-known generated messages so it
does not need protoc. Existing application schemas keep their generation pipeline.

## Preserve these contracts

- Link `InnoNetwork-Protobuf`; import `InnoNetworkProtobuf`. Execute through Core's
  `DefaultNetworkClient`/`EncodedRequestClient` and `OperationNetworkClient`.
  No SPI, separate transport engine or removed `ProtobufNetworkClient` is needed.
- Authentication is explicit. Missing required auth is not fixed by weakening it.
- Request encoding and response decoding have separate options. Compatibility
  with legacy or missing response media headers is explicit, never autodetected.
- `Google_Protobuf_Empty` is a message. HTTP no-content uses `EmptyResponse` with
  `response: .empty()` and matching status/empty-body checks. Nil body and a
  present message that encodes to zero bytes are different HTTP requests.
- Encoding is deferred once per invocation; retries/refresh reuse its bytes.
  Request byte limits reject after encoding, not before temporary allocation.
  Response serialized-byte limits do not bound the decoded object graph.
- Core owns auth/retry/cancellation/deadline/cache policy. Codec failures are not
  transport failures to retry blindly. No implicit 415 resend or gRPC framing.

## Verify the consumer

Use public `InnoNetworkTestSupport` only in test/preview targets. Test the changed
request, wire headers/body, returned message and relevant rejection path. The
[bundled tests](assets/consumer/Tests/ProtobufSkillExampleTests/ConsumerTests.swift)
exercise macros, optional/empty bodies, directional media, limits, retry reuse,
auth preflight, payload-free errors, unknown fields and operation deadlines.

```bash
python3 scripts/validate_consumer.py --release-tag 6.1.1 \
  --expected-adapter-revision "$REVIEWED_ADAPTER_SHA" \
  --expected-tag-object "$REVIEWED_ANNOTATED_TAG_OBJECT" \
  --scratch-path /tmp/protobuf-skill-validation
```

Obtain both expected identities from the reviewed release record. The helper
compares them with the official remote annotated tag before resolution and again
after tests; arbitrary input SHAs alone cannot pass. It changes only the adapter
seed revision in an isolated copy, then requires actual SwiftPM resolution and
all eight clean remote checkout identities to match. The bundled lock and prior
evidence remain historical. Without release arguments, the helper attempts only
the historical pinned fixture and does not validate a newly issued tag.

Run from this skill directory or use the helper's absolute path. It copies the
fixture outside the skill, verifies remote pins, active graph and clean checkout
SHAs, then runs strict-concurrency tests with warnings as errors. It requires
macOS, Python 3, Swift/Xcode and network access for a cold cache. Unset the
development-only `INNONETWORK_LOCAL_PATH`; a local pair is separate evidence.

Report both library revisions, what passed and unverified boundaries. Mock tests
do not prove live service/device behavior, later patches, AI host behavior or
public plugin publication.
