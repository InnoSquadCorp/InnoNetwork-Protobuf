# InnoNetwork-Protobuf

[English](README.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

[6.1.1](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/releases/tag/6.1.1)

<!-- section:1 -->
## 対象範囲

Core のエンコード済みリクエスト実行基盤を利用する HTTP Protocol Buffers アダプターです。gRPC、ストリーミング RPC、スキーマ生成は提供しません。推奨製品は InnoNetwork-Protobuf、互換製品と Swift モジュールは InnoNetworkProtobuf です。

7 言語のクイックスタートは、同じ安定版の導入、例、ライフサイクル、移行を扱います。詳細な英語ガイドを共通の上級リファレンスとします。翻訳はネイティブ話者による確認を意味しません。

<!-- section:2 -->
## 動作要件

Swift 6.2 以降、Swift 6 言語モード。Apple 専用: iOS 16+、macOS 14+、tvOS 16+、watchOS 9+、visionOS 1+。Core は InnoNetwork 6.1.1 に厳密に固定されます。

SwiftProtobuf 1.38.1+; SwiftSyntax 604.0.x (compiler host).

<!-- section:3 -->
## インストール

以下のパッケージ依存関係を追加し、利用するターゲットに製品を追加してください。

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
## クイックスタート

以下はソースと照合した例であり、新たなコンパイルや実機テストの結果ではありません。URL、認証情報、転送ポリシーはアプリが管理します。

protoc 生成の Message & Sendable 型を使用し、便宜的な Codable 準拠を追加しないでください。例の標準メッセージにはスキーマ生成が不要です。マクロは既定で有効です。traits: [] と手動の EncodedRequest.protobuf は詳細ガイドを参照してください。

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
## 所有権とエラー

実行は NetworkError を送出します。設定・エンコード・無効な上限には .configuration(reason: .invalidPayload(...))、メディア・デコード失敗には .decoding(stage: .responseBody, ...) を使用します。再試行、認証、期限、キャンセルは Core が管理します。事前検査後に呼び出しごとに一度エンコードし、再試行ではバイト列を再利用します。同期コーデック処理は強制中断せず、Core の境界でキャンセルを確認します。要求上限はメモリ確保前ではなくエンコード後に適用され、応答上限は Core の収集上限をさらに制限します。

<!-- section:6 -->
## 移行

本文なしと 0 バイトにエンコードされたメッセージは異なります。HTTP 204/205 には response: .empty() と EmptyResponse を使います。Google_Protobuf_Empty は protobuf メッセージです。既定は application/protobuf で、旧形式は明示的に選択します。415 後の自動再送はありません。3.0.1 からの移行では旧プロトコル、クライアント、ProtobufCodingOptions をマクロまたは EncodedAPIDefinition と方向別 ProtobufCodecOptions に置き換えます。

<!-- section:7 -->
## ドキュメントと検証

これらのチェックは本リポジトリで実行します。静的チェックは Swift ビルド、マクロ展開、DocC、実機・サービス検証の代わりにはなりません。公開済み依存グラフの検証時は INNONETWORK_LOCAL_PATH を解除してください。

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
