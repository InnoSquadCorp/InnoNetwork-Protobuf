import Foundation
import ValidationKit

private enum ValidationCLIError: Error { case failedChecks }

@main struct ValidationCLI {
    static func main() async throws {
        guard CommandLine.arguments.count == 2 else {
            fatalError("Usage: ValidationCLI <artifact-directory>; run twice to verify persistent reopen")
        }
        let report = try await ValidationSuite.run(directory: URL(fileURLWithPath: CommandLine.arguments[1]))
        for result in report.results { print("\(result.passed ? "PASS" : "FAIL") \(result.id): \(result.detail)") }
        guard report.passed else { throw ValidationCLIError.failedChecks }
    }
}
