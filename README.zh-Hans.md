# InnoNetwork-Protobuf

[English](README.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

[6.1.1](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/releases/tag/6.1.1)

<!-- section:1 -->
## 范围

通过 Core 的编码请求管线实现 HTTP Protocol Buffers。不提供 gRPC、流式 RPC 或模式生成。推荐产品为 InnoNetwork-Protobuf；兼容产品和 Swift 模块为 InnoNetworkProtobuf。

七种语言的快速入门覆盖同一稳定版本、安装、示例、生命周期和迁移。详细英文指南是共享的高级参考；翻译不代表经过母语审校。

<!-- section:2 -->
## 环境要求

Swift 6.2 及以上，Swift 6 语言模式。仅支持 Apple 平台：iOS 16+、macOS 14+、tvOS 16+、watchOS 9+、visionOS 1+。Core 精确固定为 InnoNetwork 6.1.1。

SwiftProtobuf 1.38.1+; SwiftSyntax 604.0.x (compiler host).

<!-- section:3 -->
## 安装

添加以下包依赖，并将产品添加到使用它们的 target。

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
## 快速开始

以下示例已与源代码核对，但不代表重新完成编译或设备测试。URL、凭据和传输策略由应用管理。

使用 protoc 生成的 Message & Sendable 类型，不要伪造 Codable 遵循。示例中的标准消息无需另行生成模式。宏默认启用；详细指南介绍 traits: [] 和手动 EncodedRequest.protobuf 工厂。

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
## 生命周期与错误

执行抛出 NetworkError。配置、编码及无效预算使用 .configuration(reason: .invalidPayload(...))；媒体和解码失败使用 .decoding(stage: .responseBody, ...)。重试、认证、期限和取消由 Core 管理。预检后每次调用编码一次，重试复用字节。同步编解码不会被强制中断，取消在 Core 边界检查。请求字节限制在编码后生效，不能限制分配前的内存；响应限制会收紧 Core 的收集上限。

<!-- section:6 -->
## 迁移

没有正文与编码为零字节的消息不同。HTTP 204/205 使用 response: .empty() 和 EmptyResponse；Google_Protobuf_Empty 是 protobuf 消息。默认使用 application/protobuf，旧媒体类型必须明确选择；415 后不会自动重发。从 3.0.1 迁移时，用宏或 EncodedAPIDefinition 及分方向的 ProtobufCodecOptions 替换旧协议、客户端和 ProtobufCodingOptions。

<!-- section:7 -->
## 文档与验证

在本仓库中运行这些检查。静态检查不能替代 Swift 构建、宏展开、DocC 或设备及服务验收。验证已发布的依赖图时，请移除环境变量 INNONETWORK_LOCAL_PATH。

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
