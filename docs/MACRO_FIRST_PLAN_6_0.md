---

> Historical record — retained for the source, date and environment below.
> For the published 6.1.1 contract, use the [current quick start](../README.md)
> and [documentation map](README.md). Unexecuted checks are not implied passes.

date: 2026-09-30
project: InnoNetwork / InnoNetwork-Protobuf
design: Macro-first binary endpoint declarations
owner: Codex (implementation)
decision-owner: Repository maintainer
status: In Progress
reviewed-by: []
approved-by: Repository maintainer via chat
approved-at: 2026-09-30
document-depth: standard
---

# Macro-first 전환 상세 작업 계획

## 1. 목표와 승인 경계

일반 사용자는 명명된 endpoint를 매크로로 선언하고 `client.request(endpoint)` 또는
`operations.start(endpoint)`로 실행한다. `EncodedRequest`는 공통 실행 기반이자
고급 수동 경로로 유지한다. Protobuf용 transport, retry, cancellation engine은 추가하지 않는다.

두 저장소의 public API, compiler plug-in, 소비자, 배포 순서를 조율하므로 standard 깊이를
선택했다. 최초 문서는 계획 전용 Draft였고, 이후 사용자의 “순서대로 진행해줘”로
로컬 구현을 승인받았다. 아래 단계는 순서대로 로컬 구현·검증 중이며 실제 결과는
[현재 검증 기록](MACRO_FIRST_VALIDATION_6_0.md)에 분리한다. 커밋명은 권장 분할 단위이며
이번 실행에서는 커밋, push, 원격 실행, 병합, 태그/출판을 하지 않는다.

비목표: gRPC, protobuf schema/protoc 생성 서비스, streaming codec, 모든 기존 JSON API의
강제 migration, 앱 소스 자동 변경, 새 성능 한도 도입, CI 보호 규칙 완화.

## 2. 확인한 기준 상태

2026-09-30 로컬 재확인 기준이다. 원격 최신 릴리스/CI는 이번 계획에서 다시 조회하지 않았다.

| 대상 | 기준 및 확인한 파일 | 상태 |
| --- | --- | --- |
| Core 작업 트리 | `InnoNetwork-encoded-request`, HEAD `9d8053d5f921ebf5c38cc2f816efe90c7db4a450` | 기존 encoded-request 구현이 미커밋으로 존재 |
| Adapter 작업 트리 | `InnoNetwork-Protobuf`, HEAD `e6dc0ff414b15e044e667d192c3e30cc88d346b0` | 기존 3개 로컬 커밋과 미커밋 redesign 보존 |
| 기존 macro | core `Sources/InnoNetwork/APIDefinition+Macro.swift`, `Sources/InnoNetworkMacros/` | `APIDefinition` conformance를 생성하며 기존 Codable 계약을 따름 |
| 실행 기반 | core `Sources/InnoNetwork/EncodedRequest.swift`, `V6/OperationNetworkClient.swift` | binary output은 Sendable이면 가능, 동일 executor/lifecycle 재사용 |
| Protobuf factory | adapter `Sources/InnoNetworkProtobuf/ProtobufCodec.swift` | 수동 factory만 있음; Message 제약, 지연 encoding, media/limit 정책 보유 |
| 의존성 | 양쪽 `Package.swift`, adapter `Examples/ConsumerSmoke/Package.swift` | SwiftProtobuf 1.38.1 이상, core SwiftSyntax 603.0.1 이상 603.0.x 범위; adapter는 현재 core `traits: []` |
| 플랫폼 검증 | adapter `Scripts/build_apple_platform_target.sh` | 현재 library target만 빌드하므로 매크로가 적용된 외부 endpoint의 플랫폼 소비 검증은 별도 필요 |

미커밋 기준 파일 SHA-256:

- Core `EncodedRequest.swift`: `3ba9ad39f4338047e7912e82429dd449814d5df1d201eac920f8ebb86a8c1621`
- Core `APIDefinition+Macro.swift`: `e340a82b78b119498461dd1e5b7aa2d4687b9beb5c7427ba9b693d2137922993`
- Core `APIDefinitionMacro.swift`: `53dbe5ef45c9b8598f2d311c22b767a59e4e1fc1e355729e994b4fd3ec80e07d`

이전 실행의 core 1,963 pass/4 live skip, adapter 33 pass, 관련 TSAN 및 19개 성능 guard
결과는 기존 실행 기반의 재사용 근거다. 앞으로 추가할 매크로의 검증 결과로 계산하지 않는다.
구현 시작 시 HEAD, 전체 tracked patch, 새 파일 목록/해시, 원본 core 작업 트리의 상태를 다시 고정한다.

## 3. 권장 사용자 API와 대안

### 권장안: 같은 패턴, 코덱별 명시적 매크로

- JSON/기존 endpoint: `@APIDefinition(method:path:auth:)` 유지.
- Protobuf endpoint: adapter가 제공하는 `@ProtobufAPIDefinition(method:path:auth:)` 추가.
- 두 종류 모두 동일한 client/operation 사용 패턴, 경로 검증 규칙, 명시적 인증 계약을 따른다.
- 다음 예시는 로컬 후보의 사용 형태이며 아직 공개 배포 API가 아니다.
  `UserReply`와 `UpdateUserRequest`는 사용자가 생성한 Message 타입을 의미한다.

```swift
import InnoNetwork
import InnoNetworkProtobuf

@ProtobufAPIDefinition(method: .post, path: "/users/{id}", auth: .required)
struct UpdateUser {
    typealias APIResponse = UserReply // protoc-generated Message & Sendable
    let id: String
    let body: UpdateUserRequest       // protoc-generated Message & Sendable

    var protobufOptions: ProtobufCodingOptions {
        .init(maximumRequestBytes: 65_536, maximumResponseBytes: 1_048_576)
    }
}

let result = try await client.request(UpdateUser(id: "42", body: message))
let operation = operations.start(UpdateUser(id: "42", body: message))
let secondResult = try await operation.value()
```

위의 두 호출은 각각 새 요청을 시작하는 대안 예제이며, 같은 요청을 공유하지 않는다.
바이트 한도는 사용 예일 뿐 전역 기본값으로 도입하지 않는다.

### 비교한 대안과 결정

| 결정 | 권장 선택 | 대안 / 선택하지 않는 이유 | 재검토 조건 |
| --- | --- | --- | --- |
| macro 이름 | `@ProtobufAPIDefinition` | 단일 `@APIDefinition(codec: .protobuf)`는 기존 Codable conformance와 별도 codec 타입 추론/확장 계약을 함께 바꿔야 함 | 사용자가 동일 이름을 필수 요구하면 1단계에서 별도 설계. 단일 이름이 기술적으로 불가능하다는 뜻은 아님 |
| Core 계약 | additive `EncodedAPIDefinition` | 기존 Stable `APIDefinition`의 Codable 제약 제거는 JSON consumers에 불필요한 breaking 범위 확장 | Core 7 전면 통합을 별도 승인받을 때 |
| 생성기 공유 | host-only `InnoNetworkMacroSupport` product/target | 경로·auth parser 복제는 보안/진단 수정이 양쪽에서 어긋날 위험 | 1단계 외부 macro dependency proof가 실패하거나 지원 surface 비용이 과도하면 구현 전에 재검토 |
| 런타임 | 기존 `EncodedRequest` + executor | adapter 전용 client/operation engine은 상태·취소·재시도 중복을 복원함 | 변경하지 않음 |
| 기본 사용 | adapter Macros 기본 활성화 | macro-only는 compiler plug-in 장애 시 우회가 없음 | 명시적 macro-off consumer 유지 |

`InnoNetworkMacroSupport`는 앱 런타임 제품이 아니라 compiler 구현용 제품이다.
외부 adapter에서 접근하므로 실제 public build-tool surface로 목록화하고 버전/호환 계약을 둔다.
SwiftSyntax 타입을 사용하는 이 surface를 런타임 Stable API와 혼동하지 않는다. 초기 지원은 동일한
603.0.x 범위에 고정하고 minor/major 호환 정책과 Xcode 26/27 증거 없이는 확장하지 않는다.
새 build-tool product 때문에 product inventory도 실제로 수정하며 기존 9개라는 숫자를 유지하지 않는다.

## 4. 계층과 책임

```text
JSON @APIDefinition ──────── 기존 APIDefinition ───────────────┐
                                                           │
Protobuf @ProtobufAPIDefinition                              │
  └─ EncodedAPIDefinition → public codec factory             │
       └─ EncodedRequest ────────────────────────────────────┤
                                                           ↓
                 DefaultNetworkClient / OperationNetworkClient
                   → 기존 RequestExecutor / lifecycle

컴파일 시: 두 macro plug-in → InnoNetworkMacroSupport
런타임: Protobuf adapter → Core + SwiftProtobuf (SwiftSyntax 링크 금지)
```

승인된 목표 구조이며 로컬 구현 중이다. 배포 여부와 검증 완료는 별도 기록한다.

### Runtime bridge 계약

- 새 `EncodedAPIDefinition: Sendable`은 `APIResponse: Sendable`, method/path/auth,
  `makeEncodedRequest() throws(NetworkError)`를 제공하는 작은 public 계약으로 설계한다.
- 생성된 구현은 codec factory와 HTTP options만 조합한다. serializer를 직접 실행하거나
  URLSession/Task/retry를 생성하지 않는다.
- client bridge는 factory를 호출당 한 번만 평가한다. body byte encoding은 기존 executor의
  URL/auth preflight 뒤에 한 번만 수행하고 retry/401 replay에서는 재사용한다.
- operation bridge는 기존 `startExecution` 내부의 취소/만료 확인 뒤에 factory를 호출한다.
  구성 오류도 handle의 typed failure/종료 event로 전달하고 `start` 자체는 throwing으로 바꾸지 않는다.
- replay/failure 분류에 사용한 method/auth와 factory 반환 값이 어긋나지 않도록 method/path/auth를
  한 번 snapshot하고 변환 결과와 일치 검사한다. 불일치는 전송 전 configuration failure다.
- `NetworkClient`에 새 protocol requirement를 추가하지 않는다. 기존 JSON fake에 구현 부담을 주지 않고
  `EncodedRequestClient` extension과 `OperationNetworkClient where Base: EncodedRequestClient`로 연결한다.
- 직접 request는 `NetworkError`, operation value는 기존 `NetworkFailure` 경계를 유지한다.
- 매크로 없는 수동 값과 factory는 계속 공개한다. 별도 저장소/영구 상태 migration은 없다.

## 5. 순차 구현과 커밋 단위

각 단계는 앞 단계의 완료 조건을 충족한 뒤 진행한다. 커밋 메시지는 제안이며 실제 커밋 권한과
정확한 파일 목록을 확인한 뒤 사용한다. 기존 미커밋 runtime redesign도 기반 커밋으로 먼저
분리하거나 선택적으로 함께 묶어, 한 커밋이 컴파일 불가능한 중간 상태가 되지 않게 한다.

### 1) 기준 고정과 최소 컴파일 실험

- Core/adapter의 기존 변경·생성 파일·기존 3개 커밋을 보존하고 source hash와 diff를 기록한다.
- 별도 진단 fixture에서 host-only 공유 product → 외부 adapter macro → 외부 소비자
  세 단계의 import/expansion을 확인한다. 현재 제품 source를 먼저 대규모 이동하지 않는다.
- public/private/nested endpoint 및 JSON+Protobuf 동시 import 시 conformance/overload 충돌을 확인한다.
- `EncodedAPIDefinition` bridge가 `request(endpoint)` / `start(endpoint)`를 지원하는 최소 예제를 만든다.
- **완료 조건:** 지원 toolchain에서 생성기 import, visibility, 기본 사용 문법이 성립한다.
  Xcode 26 로컬 미설치 시 로컬 성공은 Xcode 27만의 증거이고 26은 원격 gate로 남긴다.
- **실패 시:** parser 복제, SPI, unsafe cast, 새 runtime engine으로 임의 우회하지 않고 설계 결정을 재검토한다.

### 2) Core의 binary endpoint 선언 bridge

- 대상: 새 `Sources/InnoNetwork/EncodedAPIDefinition.swift`, 기존
  `EncodedRequest.swift`, `V6/OperationNetworkClient.swift`, 관련 tests.
- 위 runtime bridge 계약을 구현한다. factory 호출은 한 번, serialization은 지연한다.
- cancellation tag, deadline, replaySafety, factory failure의 mapping을 기존 lifecycle에 연결한다.
- 일반 성공, 구성 실패, 이미 취소, deadline 0, metadata mismatch, 중복 호출 없음의 테스트를 추가한다.
- **완료 조건:** binary-only fake가 동작하고 기존 JSON client/macro 소비자는 수정 없이 컴파일된다.
- 커밋: `feat(core): add encoded endpoint declaration bridge`.

### 3) 매크로 공통 검증기 분리

- Core `Sources/InnoNetworkMacros/APIDefinitionMacro+Arguments.swift`, `+Declarations.swift`,
  `+Path.swift`의 공통 부분을 host-only `Sources/InnoNetworkMacroSupport/`로 이동한다.
- method/auth parsing, path placeholder/percent encoding 검사, access level 계산, stored-property
  판별을 공유한다. JSON의 `Parameter`/Codable 생성 정책은 별도 JSON expansion entry point로
  유지한다. 실제 구현은 기존 JSON 생성기를 통째로 host support에 옮기고 기존 plugin을 얇은
  delegate로 두었다. 파일 간 내부 helper 접근을 유지하고 기존 56개 snapshot/검증을 그대로
  통과시키기 위한 구조 조정이며 JSON 생성 의미 변경은 아니다.
- payload allowlist와 macro 표시명/diagnostic ID는 profile로 구분해 JSON 의미를 바꾸지 않는다.
- 공유 target의 public 범위는 facade/결과 모델 최소한으로 제한하고 runtime product에 연결하지 않는다.
- **완료 조건:** 기존 expansion snapshots, compile-failure diagnostics, MacroUsage/MacroAdopterSmoke,
  macro-on/off graph가 모두 유지된다. 제품/심볼 inventory와 compile-time surface 계약을 갱신한다.
- 커밋: `refactor(macros): share endpoint declaration validation`.

### 4) Protobuf 매크로 패키징과 최소 생성

- 새 파일: `Sources/InnoNetworkProtobuf/ProtobufAPIDefinition+Macro.swift`,
  `Sources/InnoNetworkProtobufMacros/ProtobufAPIDefinitionMacro.swift`, `Plugin.swift`.
- `Package.swift`에 adapter `Macros` trait를 기본 활성화하고 compiler target/test target을 조건부 연결한다.
- Core와 동일한 SwiftSyntax 603.0.x 범위를 사용하고 새 버전 계열을 임의 도입하지 않는다.
- 생성 항목: `EncodedAPIDefinition` conformance, method/path/auth, `makeEncodedRequest`.
  `APIResponse`와 application-owned initializer/정책은 사용자가 선언한다.
- `protobufOptions`/`requestOptions`가 없으면 기본 factory 값, 있으면 그 값을 한 번 평가해 전달한다.
- **완료 조건:** generated message로 bodyless GET / body POST / path placeholder가 컴파일·실행되고,
  생성 코드가 public API만 사용한다. endpoint 생성 시 body encoding은 0회다.
- 커밋: `feat(protobuf): introduce macro-first endpoint declarations`.

### 5) Payload·query·empty semantics 완성

- body 없음, nonoptional Message, optional Message를 구분한다. nil은 무본문, non-nil 기본 Message는
  zero-byte protobuf body다. Optional/typealias 판별을 문자열 추측으로 구현하지 않고 typed overload로 보장한다.
- `query: Encodable & Sendable`는 기존 QueryEncoder를 통해 URL query로 변환한다.
  protobuf로 직렬화하지 않으며 body와 query가 동시에 있는 HTTP 요청도 지원한다.
- `requestOptions.queryItems`가 있으면 먼저 유지하고 인코딩된 query를 뒤에 추가한다.
  중복 key는 URLQueryItem의 기존 순서/반복 의미를 보존한다. encoder 선택은 명시적 `queryEncoder` 정책으로 둔다.
- schema Empty는 `Google_Protobuf_Empty`; HTTP no-content는 명시적
  `response: .noContent` 모드와 `APIResponse = EmptyResponse`로 분리한다.
  해당 모드의 기본 허용은 204/205이며 응답의 관측 body는 비어 있어야 한다.
- optional body/no-content에 필요한 public codec factory overload만 추가하고 media/header/limit 검증은
  기존 `ProtobufCodingOptions`의 한 구현을 재사용한다. 기본 Message 모드가 no-content를 추측하지 않는다.
- **완료 조건:** optional alias, proto2 required, unknown fields, invalid media, 잘못된 no-content status/body,
  query+body, empty query의 정상/실패 대조군이 있다. 새 query 오류의 payload-free configuration 분류도 고정한다.
- 커밋: `feat(protobuf): complete macro payload and response contracts`.

### 6) 오류 진단·타입 안전성 고정

- 문법 진단: struct 외 적용, missing APIResponse/auth, invalid literal path, 잘못된 placeholder,
  optional path, 소유 멤버 중복, 무시될 stored property, GET/HEAD/TRACE body, unsupported method form.
- property contract: body/query는 명시적 타입이 있는 instance stored property, 정책은 instance stored/computed
  property만 허용한다. static/lazy/잘못된 alias·중복 매크로는 조용히 무시하지 않는다.
- unknown/dynamic method는 macro simple mode에서 거절하고 수동 API로 안내한다.
- Message/Sendable/Encodable 및 typealias의 실제 의미는 생성된 generic factory를 Swift compiler가 검사한다.
  구문 매크로가 다른 모듈의 conformance를 알아낸다고 가정하지 않는다.
- expansion snapshot + 실제 compile-fail fixtures + 실패 이유에 대응하는 compile-pass control을 함께 둔다.
  exit code만 보지 않고 예상 diagnostic category/위치도 검증한다.
- **완료 조건:** public/internal/private/nested/generic의 지원·비지원 범위가 명시되고 양 toolchain의
  진단 차이를 fixture로 수용한다. 오류문에 payload/token이 포함되지 않는다.
- 커밋: `test(macros): lock protobuf expansion and diagnostics`.

### 7) 공통 실행 의미 동등성 검증

- 동일 endpoint를 macro와 수동 EncodedRequest 양쪽으로 실행하여 method, URL, headers,
  body bytes, response, error category, terminal event를 비교한다.
- 인증 required/no-policy, refresh 성공/실패, 401 replay, 안전한 재시도/keyed POST,
  늦은 서명과 response interceptor의 최종 request context를 검증한다.
- 취소는 preflight/queue/transport 및 동기 codec 전후 checkpoint, deadline은 대기·실행 경계를 검증한다.
  codec 중간의 강제 CPU 중단은 약속하지 않는다.
- size/depth limit, 동일 GET 캐시·병합과 인증 분리, 동시 서로 다른 body/path, factory/encoder 횟수,
  observer exactly-once 의미를 확인한다. 정상 대조군과 deterministic 진입 장벽을 사용한다.
- **완료 조건:** 관련 TSAN/회귀 테스트 및 다음 검증 표를 증거/제한으로 닫는다.
- 커밋: `test(protobuf): verify macro and manual execution parity`.

### 8) 기본 소비자와 문서 migration

- README/DocSmoke/ConsumerSmoke의 첫 예제를 매크로로 교체한다. 수동 예제는 Advanced로 이동한다.
- JSON+Protobuf를 함께 import하는 외부 consumer와 별도 macro-off consumer를 만든다.
  macro-off는 별도 package graph로 검증하여 다른 의존성이 trait를 재활성화하는 영향을 분리한다.
- 기존 `LegacyConsumerSmoke`는 제품 이름 호환 검사로 유지한다. 과거 제거된 runtime API의 호환 증거로 부르지 않는다.
- Core의 `traits: []`가 반드시 제거되어야 하는 것은 아니다. adapter 자체 Macros를 활성화하면
  protobuf macro를 제공할 수 있다. JSON macro도 사용하는 소비자에서 core Macros를 명시적으로 활성화한다.
- source/manifest/활성 resolved graph를 다시 조사해 실제 참조만 갱신한다. 이전에 확인한 legacy
  root lockfile 14쌍은 활성 그래프라는 새 증거 없이 변경하지 않는다. 앱 migration은 별도 범위다.
- SwiftSyntax/trust/최소 toolchain, manual fallback, optional/empty semantics, 오류 정책을 문서화한다.
- **완료 조건:** 문서의 완성형 Swift 예제가 외부 consumer로 컴파일·실행된다.
- 커밋: `docs(protobuf): make macros the primary adoption path`.

### 9) 빌드 비용과 CI 경로 정리

- macros on/off × core/protobuf 단독/혼합 graph를 검사한다. 기본 graph에는 필요한 compiler product,
  opt-out graph에는 컴파일된 macro/SwiftSyntax artifact가 없어야 한다. resolved dependency가 남는 것과
  실제 compiler target을 빌드하는 것을 구분한다.
- 5개 플랫폼에서 library뿐 아니라 매크로를 적용한 consumer target도 cross-build한다.
  host macro 실행 파일과 target SDK 코드의 빌드 영역을 분리한다.
- 기존 core consumer 분리/최종 필수 gate를 유지한다. adapter의 macro diagnostics, macro consumer,
  manual-off consumer를 지정된 lane에 한 번씩 배치하고 docs의 중복 clean build를 피한다.
- 로컬은 단계별 focused 검사, 완성된 후보에서 전체 검사. 작은 로컬 커밋마다 push하지 않는다.
  원격은 승인된 완성 후보 SHA를 기준으로 진행하고 실패가 없으면 중복 dispatch하지 않는다.
- CI의 required check를 생략하거나 다른 SHA의 성공을 재사용하지 않는다. cache는 성공 판정이 아니다.
- cache key는 toolchain build ID/host architecture/target SDK/build driver/traits/SwiftSyntax/lockfile을 구분한다.
  실행기 용량 변경, 전역 trust bypass, 보호 규칙 변경은 자동 수행하지 않는다.
- **성능:** 기존 0/10/50/200 endpoint, clean/no-op/endpoint-edit harness를 확장해 반복 측정한다.
  기존 runtime 14 + JSON 5 guard는 기존 한도로 유지한다. protobuf macro의 새 compile-time baseline은
  측정 전 SLO로 부르지 않고 raw time/빌드 target/메모리와 환경 차이를 기록한다.
- **완료 조건:** macro-off 경로의 추가 compiler 비용 없음, no-op에서 불필요한 재컴파일 없음,
  선언당 생성 코드 규모가 일정하며 macro/manual runtime byte 동등성/기존 성능 기준을 통과한다.
- 커밋: `ci(protobuf): validate macro traits and consumers without duplicate builds`.

### 10) Public contract와 릴리스 후보 마감

- API_STABILITY, symbol allowlist/tier budgets, product inventory, docs contracts, migration/release notes를
  실제 확정된 선언 기준으로 갱신한다. 검증 실패를 없애기 위한 임의 budget 확대는 하지 않는다.
- 기존 Stable JSON macro/consumer는 유지한다. 새 macro는 expansion/negative/외부 소비자와
  최소 toolchain 증거가 완료된 계약만 Stable 후보로 분류한다.
- Core additive 변경은 6.1 후보, adapter의 기존 수동/SPI 계약 정리는 6.0 breaking 후보로 유지한다.
  기존 Stable core API를 깨야 한다면 6.1로 강행하지 않고 Core 7 범위/버전을 다시 결정한다.
- 최종 source 동결 후 core/adapter 전체 tests, 관련 TSAN, 5-platform consumer, 문서/fixture,
  기존 성능 및 새 macro build 측정을 묶어 검증한다. 이전 test 수를 목표값으로 사용하지 않는다.
- 후속 승인 시 core PR → required CI → 보호 병합 → core 6.1 출판 → adapter 공개 최소/최신
  의존성 검증 → adapter PR/CI/보호 병합 → manual validate-only Release 순서로 진행한다.
  adapter public-only CI가 아직 없는 core 6.1을 resolve하도록 먼저 반복 실행하지 않는다.
- Core 출판 전 cross-repo 테스트가 필요하면 정확한 승인 candidate SHA를 checkout한 local override
  검증을 별도로 표시한다. 그 결과를 공개 태그 해석 검증이라고 부르지 않는다.
- Publish Release skipped와 final SHA를 확인한 뒤 실제 adapter tag/출판은 별도 승인으로 진행한다.
- **완료 조건:** 최종 SHA/의존성 revision/플랫폼별 결과/잔여 외부 제한을 분리한 handoff.
- 커밋: `docs(release): finalize macro-first compatibility and validation contracts`.

## 6. 검증 행렬과 종료 기준

아래는 승인 당시 검증 목록이다. 실제 단계별 구현·pass/fail·남은 한계는
[현재 검증 기록](MACRO_FIRST_VALIDATION_6_0.md)에서 관리하며, 공개 출판까지 완료했다고 해석하지 않는다.

| 요구 | 검증 | 담당 단계 |
| --- | --- | --- |
| 선언 중심 사용 | macro endpoint를 client/operation에 직접 전달하는 외부 실행 fixture | 1, 4, 8 |
| 기존 JSON 호환 | 기존 snapshots/negative/E2E 및 두 macro 동시 import | 3, 6, 8 |
| 경로·인증 안전성 | encoded slash/Unicode/dot/Optional path, explicit auth, no anonymous send | 3, 6, 7 |
| Body/query 의미 | optional/alias/nil/zero-byte, query+body, duplicate query 순서 | 5, 7 |
| Response 의미 | required proto2/unknown fields/media/no-content + 정상 대조군 | 5, 7 |
| 준비·재시도 | factory/encoder 횟수, 401/idempotent retry, metadata mismatch | 2, 7 |
| 취소·deadline | 진입 장벽 기반 취소/대기 만료/late success 차단/종료 event 1회 | 2, 7 |
| 동시성·자원 | 64 독립 요청, TSAN, byte/depth limit와 client cap 비확대 | 7 |
| 캐시·서명·병합 | manual과 동일 정책/credential 경계/최종 signed context | 7 |
| 관측·보안 | payload-free 오류/codec event, SPI/강제 캐스트 없음 | 6, 7 |
| macro-off | 독립 graph build + compiler artifact 부재 + runtime API 동일 | 8, 9 |
| 플랫폼·의존성 | Xcode 26/27, 5-platform macro consumer, 최소/최신 public core·protobuf | 9, 10 |
| 빌드·런타임 성능 | repeated build baseline + 기존 19 guards; 변동/원시 자료 보존 | 9, 10 |
| 릴리스 안전성 | Draft/Ready, annotated tag/정확 SHA/validate-only Publish skipped | 10 |

로컬 기능 완료와 배포 준비 완료를 분리한다. 모든 applicable local 행의 증거가 확보되면 로컬 구현을
보고할 수 있지만, Xcode 26 원격 검증·공개 core 태그·Release gate가 남아 있으면 배포 가능이라고 하지 않는다.
실기기/전용 서버/IdP/exporter 검증은 환경이 제공되지 않으면 구체적인 채택 제한으로 남긴다.

## 7. 미결정 사항과 복구

| 항목 | 권장안 / 부족한 증거 | 결정 주체·시점 |
| --- | --- | --- |
| 별도 macro 이름 수용 | 승인한 `@ProtobufAPIDefinition`으로 로컬 구현; 단일 이름은 범위 밖 | 사용자 승인 반영 |
| 공유 build-tool product | 독립 3-package probe와 mixed consumer 통과; host 전용 공개 선언 12개로 기록 | 로컬 결정 완료, 최소 toolchain은 원격 gate |
| Xcode 26 호환 | 기존 runtime 결과로 macro 호환을 대신할 수 없음 | 구현 담당, 원격 final candidate gate |
| 새 macro 빌드 시간 예산 | protobuf SwiftPM 5회 반복 완료; 200개 clean/no-op/edit 중앙값 19.70/3.08/5.32초. 별도 SLO 없음 | maintainer, 측정 검토 후 결정 |
| 실제 배포 권한 | 이 계획 요청은 배포 승인 아님 | 사용자, 10단계 출판 전 |

실험 실패 시 기존 미커밋 runtime 구현으로 돌아갈 수 있도록 정확한 patch를 보존한다.
공개 릴리스 뒤에는 태그 이동/삭제 없이 fix-forward를 기본으로 한다. 사용자의 emergency fallback은
동일 codec factory의 수동 EncodedRequest이며 JSON engine이나 구 SPI에 재연결하지 않는다.
push가 별도 승인돼 성공한 경우에만 원격 parity/작업 트리 보존 확인 후 지정된 XcodeBuildMCP cleanup을
수행한다. 활성 빌드를 중단하지 않으며 회수 용량과 최종 여유 공간을 기록한다.

## 8. 근거와 변경 이력

- 현재 구현 근거: 위 baseline의 core/adapter manifest, macro source, codec factory, operation source,
  `Scripts/check_macro_compile_failures.sh`, `Scripts/measure_macro_builds.py`, adapter platform/CI scripts.
- [SwiftPM dependency traits](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/addingdependencies/):
  default traits와 빈 trait 집합의 의미. 독립 graph에서 실제 활성 결과를 검증한다.
- [SE-0450 Package Traits](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0450-swiftpm-package-traits.md):
  additive trait 설계의 근거.
- [Apple: Expand on Swift macros](https://developer.apple.com/videos/play/wwdc2023/10167/):
  typed arguments/generated code 검증의 근거. library conformance 검사는 compiler fixture로 고정한다.

2026-09-30: 최초 Draft 이후 사용자의 “순서대로 진행해줘”로 로컬 구현 승인.
독립 리뷰는 수행되지 않았으며 푸시·병합·출판 승인은 이 승인에 포함하지 않는다.
2026-09-30: 로컬 구현·해당 검증 완료. 10단계의 공개 의존성/원격 CI/출판 절차는
미실행이며, 최초 성능 변동과 toolchain/채택 제한은 현재 검증 기록에 유지한다.
