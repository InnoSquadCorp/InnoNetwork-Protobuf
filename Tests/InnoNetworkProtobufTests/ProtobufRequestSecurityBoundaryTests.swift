import Foundation
import InnoNetwork
import InnoNetworkProtobuf
import InnoNetworkTestSupport
import SwiftProtobuf
import Testing
import os

private struct BoundaryProtobufDefinition: EncodedAPIDefinition {
    typealias APIResponse = Google_Protobuf_Empty
    let factoryCalls: OSAllocatedUnfairLock<Int>
    var method: HTTPMethod { .get }
    var path: String { "/security-boundary" }
    var sessionAuthentication: SessionAuthentication { .anonymous }

    func makeEncodedRequest() throws(NetworkError) -> EncodedRequest<APIResponse> {
        factoryCalls.withLock { $0 += 1 }
        return try .protobuf(method: method, path: path, auth: sessionAuthentication)
    }
}

private struct SecuredBoundaryProtobufDefinition: EncodedAPIDefinition, RequestSecurityProviding {
    let base: BoundaryProtobufDefinition
    let requestSecurity: RequestSecurity
    var method: HTTPMethod { base.method }
    var path: String { base.path }
    var sessionAuthentication: SessionAuthentication { base.sessionAuthentication }

    func makeEncodedRequest() throws(NetworkError) -> EncodedRequest<Google_Protobuf_Empty> {
        try base.makeEncodedRequest()
    }
}

private struct UnusedProtobufCredentialProvider: RequestCredentialProvider {
    func select(
        alternatives: [[RequestSecurity.Scheme]], origin: URL
    ) async throws -> RequestSecurity.Selection {
        Issue.record("Unsupported encoded credentials must not select a provider")
        throw RequestSecurityFailure.unsupportedExecution
    }

    func credential(
        for scheme: RequestSecurity.Scheme, selection: RequestSecurity.Selection, origin: URL
    ) async throws -> RequestSecurity.Credential {
        Issue.record("Unsupported encoded credentials must not acquire credentials")
        throw RequestSecurityFailure.unsupportedExecution
    }
}

@Suite("Core 6.1.1 named credential boundary")
struct ProtobufRequestSecurityBoundaryTests {
    @Test(arguments: [false, true])
    func rejectsNamedCredentialsBeforeProtobufFactoryAndTransport(operationRoute: Bool) async throws {
        let origin = try #require(URL(string: "https://example.com"))
        let session = MockURLSession()
        session.setScriptedResponses([
            .http(statusCode: 200, data: Data(), headers: ["Content-Type": "application/protobuf"])
        ])
        let concrete = DefaultNetworkClient(configuration: .safeDefaults(baseURL: origin), session: session)
        let client: any EncodedRequestClient = concrete
        let factoryCalls = OSAllocatedUnfairLock(initialState: 0)
        let base = BoundaryProtobufDefinition(factoryCalls: factoryCalls)
        let secured = SecuredBoundaryProtobufDefinition(
            base: base,
            requestSecurity: try RequestSecurity(
                origin: origin, alternatives: [[.bearer(id: "named")]],
                provider: UnusedProtobufCredentialProvider()))

        if operationRoute {
            do {
                _ = try await OperationNetworkClient(client: concrete).start(secured).value()
                Issue.record("Named protobuf credentials unexpectedly succeeded")
            } catch let failure {
                let expected = NetworkFailure(migratingV5: .underlying(
                    SendableUnderlyingError(
                        domain: "InnoNetwork.RequestSecurity",
                        code: RequestSecurityFailure.unsupportedExecution.rawValue,
                        message: "Expected credential boundary rejection"), nil))
                #expect(failure.kind == .configuration)
                #expect(failure.recovery == .doNotRetry)
                #expect(failure.code == expected.code)
            }
        } else {
            do {
                _ = try await client.request(secured)
                Issue.record("Named protobuf credentials unexpectedly succeeded")
            } catch {
                if case .underlying(let failure, _) = error {
                    #expect(failure.domain == "InnoNetwork.RequestSecurity")
                    #expect(failure.code == RequestSecurityFailure.unsupportedExecution.rawValue)
                } else {
                    Issue.record("Unexpected credential boundary error: \(error)")
                }
            }
        }
        #expect(factoryCalls.withLock { $0 } == 0)
        #expect(session.capturedRequestsInOrder.isEmpty)

        // The same factory and transport work when named credentials are absent.
        if operationRoute {
            #expect(try await OperationNetworkClient(client: concrete).start(base).value() == Google_Protobuf_Empty())
        } else {
            #expect(try await client.request(base) == Google_Protobuf_Empty())
        }
        #expect(factoryCalls.withLock { $0 } == 1)
        #expect(session.capturedRequestsInOrder.count == 1)
        await concrete.shutdown()
    }
}
