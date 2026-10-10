# InnoNetwork-Protobuf

[English](README.md) · [한국어](README.ko.md) · [Español](README.es.md) · [Deutsch](README.de.md) · [简体中文](README.zh-Hans.md) · [日本語](README.ja.md) · [Русский](README.ru.md)

[6.1.1](https://github.com/InnoSquadCorp/InnoNetwork-Protobuf/releases/tag/6.1.1)

<!-- section:1 -->
## Alcance

Protocol Buffers sobre HTTP mediante el ejecutor codificado de Core. No ofrece gRPC, RPC en streaming ni generación de esquemas. El producto recomendado es InnoNetwork-Protobuf; el producto compatible y el módulo Swift son InnoNetworkProtobuf.

Las siete guías rápidas cubren la misma versión estable, instalación, ejemplo, ciclo de vida y migración. La guía detallada en inglés es la referencia avanzada común; las traducciones no implican revisión por hablantes nativos.

<!-- section:2 -->
## Requisitos

Swift 6.2 o posterior, modo de lenguaje Swift 6. Solo Apple: iOS 16+, macOS 14+, tvOS 16+, watchOS 9+, visionOS 1+. Core está fijado exactamente a InnoNetwork 6.1.1.

SwiftProtobuf 1.38.1+; SwiftSyntax 604.0.x (compiler host).

<!-- section:3 -->
## Instalación

Añade estas dependencias y después los productos al target consumidor.

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
## Inicio rápido

Los ejemplos se han contrastado con el código fuente; no representan una nueva compilación ni prueba en dispositivos. La aplicación gestiona URLs, credenciales y políticas de transporte.

Utiliza tipos Message & Sendable generados por protoc, sin conformidad Codable artificial. El mensaje conocido del ejemplo no requiere generar un esquema. Las macros están activadas por defecto; la guía explica traits: [] y la fábrica manual EncodedRequest.protobuf.

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
## Propiedad y errores

La ejecución lanza NetworkError. Configuración, codificación y límites inválidos usan .configuration(reason: .invalidPayload(...)); medios y decodificación usan .decoding(stage: .responseBody, ...). Core controla reintentos, autenticación, plazos y cancelación. Se codifica una vez por invocación tras las comprobaciones previas; los reintentos reutilizan los bytes. El códec síncrono no se interrumpe por la fuerza: Core comprueba la cancelación en sus límites. El límite de petición se aplica después de codificar, no antes de asignar memoria; el de respuesta restringe el límite de recopilación de Core.

<!-- section:6 -->
## Migración

La ausencia de cuerpo difiere de un mensaje codificado en cero bytes. Para HTTP 204/205 usa response: .empty() y EmptyResponse; Google_Protobuf_Empty es un mensaje protobuf. application/protobuf es el valor predeterminado; el formato heredado requiere selección explícita. No se reenvía automáticamente tras 415. Desde 3.0.1 sustituye protocolo, cliente y ProtobufCodingOptions antiguos por la macro o EncodedAPIDefinition y ProtobufCodecOptions direccionales.

<!-- section:7 -->
## Documentación y validación

Ejecuta estas comprobaciones desde este repositorio. Las pruebas estáticas no sustituyen compilación Swift, expansión de macros, DocC ni aceptación en dispositivos o servicios. Elimina INNONETWORK_LOCAL_PATH del entorno para validar el grafo publicado.

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
