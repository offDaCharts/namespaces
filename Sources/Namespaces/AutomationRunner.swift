import AppKit
import CryptoKit
import Foundation
import NamespacesCore

struct AutomationActionResult: Identifiable, Sendable {
    let id = UUID(); let actionID: UUID; let title: String; let succeeded: Bool; let message: String
}

actor AutomationRunner {
    func fingerprint(_ action: AutomationAction) -> String {
        var source = Data(([action.kind.rawValue, action.target] + action.arguments).joined(separator: "\u{1f}").utf8)
        if action.kind == .runScript, let contents = FileManager.default.contents(atPath: action.target) {
            source.append(contents)
        }
        return SHA256.hash(data: source).map { String(format: "%02x", $0) }.joined()
    }

    func run(_ group: AutomationGroup, progress: @escaping @Sendable (AutomationActionResult) -> Void) async {
        for action in group.actions where action.isEnabled {
            if Task.isCancelled { break }
            do {
                try await execute(action)
                progress(.init(actionID: action.id, title: action.title, succeeded: true, message: "Completed"))
            } catch {
                progress(.init(actionID: action.id, title: action.title, succeeded: false, message: error.localizedDescription))
                if !action.continueOnFailure { break }
            }
        }
    }

    private func execute(_ action: AutomationAction) async throws {
        if let validation = AutomationValidator.errors(for: action).first { throw RunError.validation(validation) }
        switch action.kind {
        case .launchApplication:
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: action.target) else { throw RunError.missingTarget(action.target) }
            _ = try await NSWorkspace.shared.openApplication(at: url, configuration: .init())
        case .openPath:
            guard FileManager.default.fileExists(atPath: action.target) else { throw RunError.missingTarget(action.target) }
            NSWorkspace.shared.open(URL(fileURLWithPath: action.target))
        case .openURL:
            guard let url = URL(string: action.target), ["http", "https", "mailto"].contains(url.scheme?.lowercased() ?? "") else { throw RunError.invalidTarget }
            NSWorkspace.shared.open(url)
        case .runShortcut:
            try await runProcess("/usr/bin/shortcuts", arguments: ["run", action.target], timeout: action.timeout)
        case .runScript:
            let interpreter = action.arguments.first ?? "/bin/zsh"
            let extra = Array(action.arguments.dropFirst())
            guard FileManager.default.fileExists(atPath: action.target) else { throw RunError.missingTarget(action.target) }
            try await runProcess(interpreter, arguments: [action.target] + extra, timeout: action.timeout)
        }
    }

    private func runProcess(_ executable: String, arguments: [String], timeout: TimeInterval) async throws {
        let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = arguments
        let errorPipe = Pipe(); process.standardOutput = FileHandle.nullDevice; process.standardError = errorPipe
        try process.run()
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning, Date() < deadline {
            try await Task.sleep(for: .milliseconds(100))
            if Task.isCancelled { process.terminate(); throw CancellationError() }
        }
        if process.isRunning { process.terminate(); throw RunError.timedOut }
        guard process.terminationStatus == 0 else {
            let message = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile().prefix(2048), encoding: .utf8) ?? "Exit \(process.terminationStatus)"
            throw RunError.processFailed(message)
        }
    }

    enum RunError: LocalizedError {
        case missingTarget(String), invalidTarget, timedOut, processFailed(String), validation(String)
        var errorDescription: String? { switch self {
        case .missingTarget(let value): "Target not found: \(value)"
        case .invalidTarget: "The target is invalid or uses a disallowed URL scheme."
        case .timedOut: "The action timed out."
        case .processFailed(let reason): reason
        case .validation(let reason): reason
        } }
    }
}
