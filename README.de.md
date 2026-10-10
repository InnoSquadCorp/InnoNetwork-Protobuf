# InnoNetwork-Protobuf

[English](README.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

[6.1.1](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/releases/tag/6.1.1)

<!-- section:1 -->
## Umfang

Protocol Buffers über HTTP mit Cores Pipeline für kodierte Anfragen. Kein gRPC, Streaming-RPC oder Schemagenerator. Empfohlenes Produkt: InnoNetwork-Protobuf; Kompatibilitätsprodukt und Swift-Modul: InnoNetworkProtobuf.

Die sieben Schnellstarts behandeln dieselbe stabile Version, Installation, Beispiele, Lebenszyklen und Migration. Der ausführliche englische Leitfaden dient als gemeinsame Referenz; die Übersetzungen wurden nicht als muttersprachlich geprüft ausgewiesen.

<!-- section:2 -->
## Voraussetzungen

Swift 6.2 oder neuer, Swift-6-Sprachmodus. Nur Apple: iOS 16+, macOS 14+, tvOS 16+, watchOS 9+, visionOS 1+. Core ist exakt auf InnoNetwork 6.1.1 festgelegt.

SwiftProtobuf 1.38.1+; SwiftSyntax 604.0.x (compiler host).

<!-- section:3 -->
## Installation

Füge diese Paketabhängigkeiten und anschließend die Produkte dem verwendenden Target hinzu.

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
## Schnellstart

Die Beispiele wurden mit dem Quellcode abgeglichen; sie belegen keinen neuen Build oder Gerätetest. URLs, Zugangsdaten und Transportrichtlinien gehören der Anwendung.

Verwende von protoc erzeugte Message-&-Sendable-Typen ohne künstliche Codable-Konformität. Die bekannte Nachricht im Beispiel benötigt keine Schemagenerierung. Makros sind standardmäßig aktiv; traits: [] und EncodedRequest.protobuf werden im Leitfaden erklärt.

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
## Lebenszyklus und Fehler

Die Ausführung wirft NetworkError. Konfigurations-, Kodierungs- und ungültige Budgetfehler verwenden .configuration(reason: .invalidPayload(...)); Medien- und Dekodierungsfehler .decoding(stage: .responseBody, ...). Core besitzt Wiederholungs-, Authentifizierungs-, Frist- und Abbruchregeln. Pro Aufruf wird nach der Vorprüfung einmal kodiert; Wiederholungen verwenden dieselben Bytes. Synchrone Codec-Arbeit wird nicht erzwungen unterbrochen; Core prüft Abbrüche an seinen Grenzen. Das Anfragelimit greift nach der Kodierung, nicht vor der Speicherzuweisung; Antwortlimits begrenzen Cores Sammlung zusätzlich.

<!-- section:6 -->
## Migration

Ein fehlender Body unterscheidet sich von einer Nachricht mit Null-Byte-Kodierung. Für HTTP 204/205 dienen response: .empty() und EmptyResponse; Google_Protobuf_Empty ist eine Protobuf-Nachricht. Standard ist application/protobuf, das Legacy-Format ist optional. Kein automatisches erneutes Senden nach 415. Ersetze bei der Migration von 3.0.1 alte Protokolle, Client und ProtobufCodingOptions durch das Makro oder EncodedAPIDefinition und getrennte ProtobufCodecOptions.

<!-- section:7 -->
## Dokumentation und Prüfung

Führe diese Prüfungen im Repository aus. Statische Prüfungen ersetzen weder Swift-Builds, Makroexpansion und DocC noch Geräte- oder Diensttests. Entferne INNONETWORK_LOCAL_PATH aus der Umgebung, um den veröffentlichten Abhängigkeitsgraphen zu prüfen.

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
