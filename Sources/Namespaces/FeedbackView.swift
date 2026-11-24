import AppKit
import Foundation
import NamespacesCore
import SwiftUI

/// "Send Feedback / Report a Bug…". The person writes a note, sees the exact
/// diagnostics that would go with it, and picks how to send it (email or a
/// GitHub issue, or an HTTPS endpoint when a build configures one). DeskOrbit
/// never uploads anything on its own.
enum FeedbackConfig {
    static var email: String { info("DeskOrbitFeedbackEmail") ?? "quin+deskorbit@kauibungalow.com" }
    static var repository: String { info("DeskOrbitFeedbackRepository") ?? "offDaCharts/namespaces" }
    static var endpoint: URL? { info("DeskOrbitFeedbackURL").flatMap(URL.init(string:)).flatMap { $0.scheme == "https" ? $0 : nil } }
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development" }

    private static func info(_ key: String) -> String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }
}

enum CrashReports {
    private static let lastSeenKey = "DeskOrbit.crashPromptLastSeen"
    private static let disabledKey = "DeskOrbit.crashPromptDisabled"
    static var directory: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true) }

    static func all() -> [(name: String, modified: Date)] {
        let files = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])) ?? []
        return files.map { ($0.lastPathComponent, (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast) }
    }

    static func latestExcerpt() -> String? {
        guard let name = CrashReportPolicy.newReports(all(), since: .distantPast).first,
              let text = try? String(contentsOf: directory.appendingPathComponent(name), encoding: .utf8) else { return nil }
        return "File: \(name)\n" + CrashReportPolicy.excerpt(text)
    }

    /// New crash reports since the last answer, unless the person turned the prompt off.
    static func pending() -> [String] {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: disabledKey) else { return [] }
        return CrashReportPolicy.newReports(all(), since: defaults.object(forKey: lastSeenKey) as? Date)
    }

    static func markSeen() { UserDefaults.standard.set(Date(), forKey: lastSeenKey) }
    static func disablePrompt() { UserDefaults.standard.set(true, forKey: disabledKey); markSeen() }
}

struct FeedbackView: View {
    @EnvironmentObject var model: AppModel
    var startWithCrash = false
    let close: () -> Void
    @State private var kind: FeedbackKind = .bug
    @State private var message = ""
    @State private var contact = ""
    @State private var includeDiagnostics = true
    @State private var includeCrash = false
    @State private var showDetails = false
    @State private var status: String?
    @State private var statusIsError = false
    @State private var sending = false
    @State private var diagnostics = ""
    @State private var crash: String?

    private var draft: FeedbackDraft {
        FeedbackDraft(kind: kind, message: message, contact: contact,
                      diagnostics: includeDiagnostics ? diagnostics : nil,
                      crashExcerpt: includeCrash ? crash : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Send Feedback").font(.title2.bold())
            Text("Bugs, ideas, odd monitor setups: all of it helps. You see everything before it is sent, and you choose how to send it.")
                .font(.callout).foregroundStyle(.secondary)
            Picker("Type", selection: $kind) { ForEach(FeedbackKind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }
                .pickerStyle(.segmented).labelsHidden()
            TextEditor(text: $message)
                .font(.body).frame(minHeight: 110)
                .overlay(alignment: .topLeading) { if message.isEmpty { Text("What happened, or what would you like? For bugs: what you did, what you expected, what you saw.").foregroundStyle(.tertiary).padding(6).allowsHitTesting(false) } }
                .overlay { RoundedRectangle(cornerRadius: 7).stroke(.quaternary) }
            TextField("Your email for a reply (optional)", text: $contact).textFieldStyle(.roundedBorder)
            Toggle("Include diagnostics: app and macOS version, displays (count, sizes, scaling), Spaces count, permissions. No names, notes, window titles or license key.", isOn: $includeDiagnostics)
            if crash != nil {
                Toggle("Include the most recent DeskOrbit crash report (first part only, home folder hidden)", isOn: $includeCrash)
            }
            DisclosureGroup("Show exactly what will be sent", isExpanded: $showDetails) {
                TextEditor(text: .constant(draft.body()))
                    .font(.system(.caption, design: .monospaced)).frame(minHeight: 160)
                    .overlay { RoundedRectangle(cornerRadius: 7).stroke(.quaternary) }
            }
            if let status {
                Label(status, systemImage: statusIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                    .foregroundStyle(statusIsError ? .red : .green).font(.caption)
            }
            HStack {
                if FeedbackConfig.endpoint != nil {
                    Button("Send") { Task { await post() } }.keyboardShortcut(.defaultAction).disabled(!canSend || sending)
                }
                Button("Send by Email…") { openEmail() }.disabled(!canSend)
                    .keyboardShortcut(FeedbackConfig.endpoint == nil ? .defaultAction : nil)
                Button("Open GitHub Issue…") { openIssue() }.disabled(!canSend)
                Button("Copy") { copy() }.disabled(!canSend)
                Spacer()
                Button("Close", action: close).keyboardShortcut(.cancelAction)
            }
        }
        .padding(22)
        .frame(minWidth: 620, idealWidth: 660)
        .onAppear {
            diagnostics = SupportReport.make(from: model).text
            crash = CrashReports.latestExcerpt()
            if startWithCrash, crash != nil { includeCrash = true; kind = .bug; message = "DeskOrbit quit unexpectedly. What I was doing: " }
        }
    }

    private var canSend: Bool { !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var subject: String { draft.subject(version: FeedbackConfig.version) }

    private func openEmail() {
        guard let url = FeedbackChannel.mailtoURL(to: FeedbackConfig.email, subject: subject, body: draft.body()) else { return }
        if NSWorkspace.shared.open(url) { done("Your mail app has the message ready. Send it from there.") }
        else { copy(); fail("No mail app opened. The text is copied: paste it into an email to \(FeedbackConfig.email).") }
    }

    private func openIssue() {
        guard let url = FeedbackChannel.githubIssueURL(repository: FeedbackConfig.repository, subject: subject, body: draft.body(), labels: ["feedback", kind == .bug ? "bug" : "enhancement"]) else { return }
        NSWorkspace.shared.open(url)
        done("GitHub opened with the issue filled in. Issues there are public, so remove anything you'd rather not share.")
    }

    private func copy() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString("Subject: \(subject)\n\n\(draft.body())", forType: .string)
        done("Copied. Paste it into an email to \(FeedbackConfig.email).")
    }

    private func post() async {
        guard let endpoint = FeedbackConfig.endpoint else { return }
        sending = true; defer { sending = false }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"; request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let payload: [String: String] = ["subject": subject, "body": draft.body(), "kind": kind.rawValue, "version": FeedbackConfig.version, "contact": contact]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) { done("Sent. Thank you!") }
            else { fail("The feedback service didn't accept it. Try Send by Email instead.") }
        } catch { fail("Couldn't reach the feedback service. Try Send by Email instead.") }
    }

    private func done(_ text: String) { statusIsError = false; status = text; if includeCrash { CrashReports.markSeen() } }
    private func fail(_ text: String) { statusIsError = true; status = text }
}
