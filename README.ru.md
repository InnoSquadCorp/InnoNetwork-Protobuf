# InnoNetwork-Protobuf

[English](README.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

[6.1.1](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/releases/tag/6.1.1)

<!-- section:1 -->
## Возможности

Protocol Buffers по HTTP через конвейер кодированных запросов Core. Здесь нет gRPC, потокового RPC или генератора схем. Рекомендуемый продукт — InnoNetwork-Protobuf; совместимый продукт и модуль Swift — InnoNetworkProtobuf.

Семь кратких руководств охватывают одну стабильную версию, установку, пример, жизненный цикл и миграцию. Подробное руководство на английском остаётся общей справкой; перевод не означает проверку носителем языка.

<!-- section:2 -->
## Требования

Swift 6.2+, языковой режим Swift 6. Только Apple: iOS 16+, macOS 14+, tvOS 16+, watchOS 9+, visionOS 1+. Core закреплён строго на InnoNetwork 6.1.1.

SwiftProtobuf 1.38.1+; SwiftSyntax 604.0.x (compiler host).

<!-- section:3 -->
## Установка

Добавьте зависимости пакетов, затем продукты в использующий их target.

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
## Быстрый старт

Примеры сверены с исходным кодом, но это не результат новой компиляции или теста на устройстве. URL, учётные данные и политики транспорта принадлежат приложению.

Используйте созданные protoc типы Message & Sendable, без фиктивного Codable. Стандартное сообщение в примере не требует генерации схемы. Макросы включены по умолчанию; traits: [] и ручная фабрика EncodedRequest.protobuf описаны в подробном руководстве.

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
## Жизненный цикл и ошибки

Выполнение выбрасывает NetworkError. Ошибки настройки, кодирования и недопустимых лимитов используют .configuration(reason: .invalidPayload(...)); ошибки типа данных и декодирования — .decoding(stage: .responseBody, ...). Core управляет повторами, аутентификацией, сроками и отменой. После предварительных проверок кодирование выполняется один раз на вызов; повторы используют те же байты. Синхронный кодек не прерывается принудительно: отмена проверяется на границах Core. Лимит запроса действует после кодирования, а не до выделения памяти; лимит ответа сужает предел сбора Core.

<!-- section:6 -->
## Миграция

Отсутствующее тело отличается от сообщения с нулевой длиной кодировки. Для HTTP 204/205 используйте response: .empty() и EmptyResponse; Google_Protobuf_Empty — сообщение protobuf. По умолчанию используется application/protobuf, прежний тип выбирается явно; после 415 нет автоматической повторной отправки. При миграции с 3.0.1 замените старые протокол, клиент и ProtobufCodingOptions макросом или EncodedAPIDefinition и раздельными ProtobufCodecOptions.

<!-- section:7 -->
## Документация и проверка

Запускайте проверки в этом репозитории. Статические проверки не заменяют сборку Swift, раскрытие макросов, DocC и приёмочные тесты устройств или сервисов. Уберите INNONETWORK_LOCAL_PATH из окружения для проверки опубликованного графа зависимостей.

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
