# InnoNetwork-Protobuf

[English](README.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

[6.1.1](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/releases/tag/6.1.1)

<!-- section:1 -->
## 범위

Core의 인코딩 요청 파이프라인을 사용하는 HTTP Protocol Buffers 어댑터입니다. gRPC, 스트리밍 RPC, 스키마 생성기가 아닙니다. 권장 제품은 InnoNetwork-Protobuf이며 호환 제품과 Swift 모듈은 InnoNetworkProtobuf입니다.

일곱 빠른 시작 문서는 같은 안정 릴리스의 설치, 예제, 수명 주기, 마이그레이션을 다룹니다. 상세 영문 가이드는 공통 심화 자료입니다. 번역에 원어민 검수가 이루어졌다는 뜻은 아닙니다.

<!-- section:2 -->
## 요구 사항

Swift 6.2 이상, Swift 6 언어 모드. Apple 플랫폼 전용: iOS 16+, macOS 14+, tvOS 16+, watchOS 9+, visionOS 1+. Core 의존성은 InnoNetwork 6.1.1로 정확히 고정됩니다.

SwiftProtobuf 1.38.1+; SwiftSyntax 604.0.x (compiler host).

<!-- section:3 -->
## 설치

패키지 의존성을 추가한 뒤 사용하는 타깃에 제품을 연결하세요.

```swift
.package(url: "https://github.com/InnoSquadCorp/InnoNetwork.git", exact: "6.1.1"),
.package(url: "https://github.com/InnoSquadCorp/InnoNetwork-Protobuf.git", from: "6.1.1"),
.package(url: "https://github.com/apple/swift-protobuf.git", from: "1.38.1"),
```

```swift
.product(name: "InnoNetwork", package: "InnoNetwork"),
.product(name: "InnoNetwork-Protobuf", package: "InnoNetwork-Protobuf"),
.product(name: "SwiftProtobuf", package: "swift-protobuf"),
```

<!-- section:4 -->
## 빠른 시작

아래 예제는 소스와 대조한 예제이며 새 컴파일이나 기기 테스트 결과가 아닙니다. URL, 자격 증명, 전송 정책은 앱이 관리합니다.

protoc가 생성한 Message & Sendable 타입을 사용하고 가짜 Codable 준수를 추가하지 마세요. 아래 well-known 메시지는 별도 스키마 생성이 필요 없습니다. 매크로는 기본 활성화됩니다. traits: []와 수동 EncodedRequest.protobuf 팩터리는 상세 가이드에서 설명합니다.

```swift
import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import SwiftProtobuf

@ProtobufAPIDefinition(method: .post, path: "/echo", auth: .anonymous)
struct Echo {
    typealias APIResponse = Google_Protobuf_StringValue
    let body: Google_Protobuf_StringValue
    var protobufOptions: ProtobufCodecOptions {
        .init(
            encoding: .init(maximumEncodedRequestBytes: 8_192),
            decoding: .init(maximumEncodedResponseBytes: 8_192)
        )
    }
}

func echo(using client: DefaultNetworkClient) async throws -> Google_Protobuf_StringValue {
    var body = Google_Protobuf_StringValue()
    body.value = "hello"
    return try await client.request(Echo(body: body))
}
```

<!-- section:5 -->
## 소유권과 실패

실행은 NetworkError를 던집니다. 설정·인코딩·잘못된 한도는 .configuration(reason: .invalidPayload(...)), 미디어·디코딩 실패는 .decoding(stage: .responseBody, ...)입니다. 재시도, 인증, 기한, 취소는 Core가 관리합니다. 인코딩은 사전 검사 후 호출당 한 번 실행되며 재시도는 바이트를 재사용합니다. 동기 코덱 작업은 강제 중단되지 않으므로 Core 경계에서 취소를 확인합니다. 요청 바이트 한도는 할당 전이 아닌 인코딩 후 적용되고 응답 한도는 Core 수집 상한을 강화합니다.

<!-- section:6 -->
## 마이그레이션

본문 없음과 0바이트로 인코딩된 메시지는 다릅니다. HTTP 204/205에는 response: .empty()와 EmptyResponse를 사용합니다. Google_Protobuf_Empty는 protobuf 메시지입니다. 기본 미디어는 application/protobuf이며 레거시 미디어는 명시적으로 선택합니다. 415 후 자동 재전송하지 않습니다. 3.0.1에서 이전할 때 기존 프로토콜·클라이언트와 ProtobufCodingOptions를 매크로 또는 EncodedAPIDefinition, 방향별 ProtobufCodecOptions로 교체하세요.

<!-- section:7 -->
## 문서와 검증

다음 검사는 이 저장소에서 실행합니다. 정적 검사는 Swift 빌드, 매크로 확장, DocC, 기기·서비스 검증을 대체하지 않습니다. 공개 의존성 그래프를 확인할 때 INNONETWORK_LOCAL_PATH를 해제하세요.

- [Technical guide (English)](docs/GUIDE.md)
- [Documentation map / historical evidence](docs/README.md)
- [Migration (English)](docs/MIGRATION_6_0.md)
- [API stability](API_STABILITY.md)
- [AI development skill](skills/README.md)
- [Release qualification record](docs/releases/6.1.1.md)
- [Roadmap](docs/ROADMAP.md)
- [MIT License](LICENSE)

```bash
bash Scripts/check_static_contracts.sh
bash Scripts/check_docs_contract_sync.sh
env -u INNONETWORK_LOCAL_PATH swift test
```
