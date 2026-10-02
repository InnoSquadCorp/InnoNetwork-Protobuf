import Observation
import SwiftUI
import ValidationKit

@MainActor @Observable final class ValidationModel {
    var report: ValidationReport?
    var error: String?
    var running = false
    func run() async {
        guard !running else { return }
        running = true
        error = nil
        defer { running = false }
        do {
            let root = URL.documentsDirectory.appendingPathComponent("NetworkValidation")
            report = try await ValidationSuite.run(directory: root)
        } catch is CancellationError { error = "Cancelled" } catch { self.error = String(describing: error) }
    }
}

@main struct NetworkValidationApp: App {
    var body: some Scene { WindowGroup { ValidationScreen() } }
}

struct ValidationScreen: View {
    @State private var model = ValidationModel()
    @State private var runID = 0
    var body: some View {
        NavigationStack {
            List {
                ValidationSummary(running: model.running, report: model.report, error: model.error)
                if let report = model.report {
                    ForEach(report.results) { result in ValidationRow(result: result) }
                }
                Section {
                    Text("Local fixture • unpublished candidate • no production credentials")
                        .font(.footnote).foregroundStyle(.secondary)
                    Text(
                        "Relaunch to verify disk restoration. This is not a production IdP, AWS or background-restoration test."
                    )
                    .font(.footnote).foregroundStyle(.secondary)
                    Button("Run again") { runID += 1 }.disabled(model.running)
                }
            }
            .navigationTitle("Network validation")
            .task(id: runID) { await model.run() }
        }
    }
}

struct ValidationSummary: View {
    let running: Bool
    let report: ValidationReport?
    let error: String?
    var body: some View {
        Section {
            if running { ProgressView("Validating real transport…") }
            if let report {
                Label(
                    report.passed ? "All checks passed" : "Validation failed",
                    systemImage: report.passed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(report.passed ? .green : .red)
                Text(report.environment).font(.caption)
            }
            if let error { Text(error).foregroundStyle(.red) }
        }
    }
}

struct ValidationRow: View {
    let result: ValidationResult
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(result.id, systemImage: result.passed ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(result.passed ? .green : .red)
            Text(result.detail).font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}
