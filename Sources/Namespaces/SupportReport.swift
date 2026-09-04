import AppKit
import Foundation
import SwiftUI

struct SupportReport: Identifiable {
    let id: UUID
    let text: String

    @MainActor
    static func make(from model: AppModel) -> SupportReport {
        let id = UUID()
        let capabilities = [
            "enumerate=\(model.provider.capabilities.contains(.enumerate))",
            "switch=\(model.provider.capabilities.contains(.switchSpace))",
            "moveWindow=\(model.provider.capabilities.contains(.moveWindow))",
            "labels=\(model.provider.capabilities.contains(.missionControlLabels))",
        ].joined(separator: ", ")
        let displaySummary = NSScreen.screens.enumerated().map { index, screen in
            let frame = screen.frame
            return "display-\(index + 1): \(Int(frame.width))x\(Int(frame.height)) @\(String(format: "%.1f", screen.backingScaleFactor))x"
        }.joined(separator: "; ")
        let recentLaunchStages = launchStages().suffix(30).joined(separator: "\n")
        let crashReports = crashReportNames().prefix(3).joined(separator: ", ")
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "development"

        let text = """
        DeskOrbit Support Report (privacy-redacted)
        Report ID: \(id.uuidString)
        Generated: \(Date.now.ISO8601Format())
        Version: \(version) (\(build))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: \(machineHardwareName)
        Provider: \(model.providerName)
        Provider status: \(model.capabilityMessage)
        Provider circuit open: \(model.providerCircuitOpen)
        Capabilities: \(capabilities)
        Accessibility approved: \(AXIsProcessTrusted())
        Mission Control status: \(model.missionControlOverlayStatus)
        Displays: \(displaySummary.isEmpty ? "none detected" : displaySummary)
        Spaces observed: \(model.nativeSpaces.count)
        Saved profiles: \(model.data.spaces.count)
        Unmatched profiles: \(model.data.spaces.filter { model.native(for: $0) == nil }.count)
        Notes count: \(model.data.notes.count)
        Automation group count: \(model.data.automations.count)
        Tracking segment count: \(model.data.segments.count)
        Last error category: \(model.lastError == nil ? "none" : "present (content redacted)")
        DeskOrbit crash reports available locally: \(crashReports.isEmpty ? "none detected" : crashReports)

        Recent privacy-safe launch stages:
        \(recentLaunchStages.isEmpty ? "none available" : recentLaunchStages)

        Excluded by design: Space names, note and checklist content, file paths,
        window titles, app identifiers and activity, automation names and bodies,
        tracking details, device name, license key, and license activation ID.

        Nothing in this report has been uploaded. Saving, copying, or sharing it
        requires a separate action from you.
        """
        return SupportReport(id: id, text: text)
    }

    private static var machineHardwareName: String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &bytes, &size, nil, 0)
        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    private static func launchStages() -> [String] {
        let file = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DeskOrbit/launch.log")
        guard let text = try? String(contentsOf: file, encoding: .utf8) else { return [] }
        return text.split(separator: "\n").map(String.init)
    }

    private static func crashReportNames() -> [String] {
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return files
            .filter { $0.lastPathComponent.hasPrefix("DeskOrbit") }
            .sorted { lhs, rhs in
                let left = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let right = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return left > right
            }
            .map(\.lastPathComponent)
    }
}

struct SupportReportPreview: View {
    let report: SupportReport
    let dismiss: () -> Void
    @State private var status: String?
    @State private var statusIsError = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("DeskOrbit Support Report").font(.title2.bold())
            Text("Review the exact privacy-redacted text before you save, copy, or share it. DeskOrbit never sends this automatically.")
                .font(.callout).foregroundStyle(.secondary)
            TextEditor(text: .constant(report.text))
                .font(.system(.caption, design: .monospaced))
                .frame(minWidth: 680, minHeight: 420)
                .overlay { RoundedRectangle(cornerRadius: 7).stroke(.quaternary) }
            if let status {
                Label(status, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(statusIsError ? .red : .green)
                    .font(.caption)
            }
            HStack {
                Button("Copy Report") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(report.text, forType: .string)
                    statusIsError = false
                    status = "Copied. You decide where to paste it."
                }
                Button("Save Report…") { save() }
                Spacer()
                Button("Done", action: dismiss).keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
    }

    private func save() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "DeskOrbit-Support-\(report.id.uuidString.prefix(8)).txt"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try report.text.write(to: url, atomically: true, encoding: .utf8)
            statusIsError = false
            status = "Saved locally. Nothing was uploaded."
        } catch {
            statusIsError = true
            status = "The report could not be saved: \(error.localizedDescription)"
        }
    }
}
