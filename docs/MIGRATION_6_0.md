# Breaking 6.0 migration

Requires exactly published Core 6.1.1. The adapter is still a release candidate;
its own tag must be published before remote-only consumers can resolve this pair.
Do not modify existing Core tags.

| Previous API | Replacement |
| --- | --- |
| ProtobufAPIDefinition protocol / parameters | @ProtobufAPIDefinition macro / body (manual EncodedRequest.protobuf fallback) |
| ProtobufNetworkClient / protobufRequest | EncodedRequestClient / request |
| ProtobufEmptyResponse (schema Empty) | Google_Protobuf_Empty |
| Implicit empty HTTP response | response: .noContent and APIResponse = EmptyResponse (manual protobufNoContent fallback) |
| protobufEmptyCapable | Strict message decoder or explicit HTTP no-content, not both |
| Implicit application/x-protobuf | application/protobuf default; explicit .legacy profile |
| Custom endpoint witnesses | EncodedRequestOptions, shared core types |
| Untyped adapter errors | NetworkError; handle invalidPayload in configuration-reason switches |

No-body requests no longer need a dummy Parameter type. Custom schema messages
stay protoc-generated; do not add fake Codable conformance. Body-only protobuf
with a no-content reply uses `EncodedRequestBody.protobuf` plus core's no-content
decoder. For a server intentionally returning empty 200, opt into `[200]` in the
no-content decoder rather than silently interpreting malformed protobuf as success.

The default adoption path is the macro shown in README. It requires an explicit
APIResponse, method/path/auth and stored typed body/query inputs. Optional body
aliases retain nil versus present-empty semantics. Policies belong in
protobufOptions/requestOptions/queryEncoder; arbitrary stored properties are not
silently ignored. Replace old `T: ProtobufAPIDefinition` constraints with core
`EncodedAPIDefinition`, not a macro type constraint. Both Macros traits can be
disabled for a manual consumer. The adapter's shared compiler support currently
pins the core dependency to exactly 6.1.1 and SwiftSyntax to 603.0.x.

Client mocks can conform only to EncodedRequestClient. Operations accept these
clients and share the same deadline/cancel/result gate as ordinary requests.
Caller cancellation and grouped cancellation remain separate core mechanisms.
Sync encoding cannot be forcibly interrupted; budget memory independently.

Interceptors are explicitly trusted application code. They can change body/headers
after encoding; the codec's request byte budget covers its own encoded output,
not arbitrary replacement bodies created by an interceptor.

The repository/product is InnoNetwork-Protobuf; import remains InnoNetworkProtobuf.
The old product alias is kept, but removed runtime protocols are not emulated.
For rollback restore the prior compatible core/adapter lockfile pair, never retag.
