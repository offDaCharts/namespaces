import Foundation

/// Builds the "Send Feedback / Report a Bug" message. Nothing here sends
/// anything: the app shows the exact text and the person picks the channel.
public enum FeedbackKind: String, CaseIterable, Sendable {
    case bug = "Bug"
    case idea = "Idea"
    case question = "Question"
    case praise = "Something that works well"
}

public struct FeedbackDraft: Equatable, Sendable {
    public var kind: FeedbackKind
    public var message: String
    public var contact: String
    public var diagnostics: String?
    public var crashExcerpt: String?

    public init(kind: FeedbackKind, message: String, contact: String = "", diagnostics: String? = nil, crashExcerpt: String? = nil) {
        self.kind = kind; self.message = message; self.contact = contact
        self.diagnostics = diagnostics; self.crashExcerpt = crashExcerpt
    }

    /// Subject lines start with a fixed tag so the feedback job can find them.
    public func subject(version: String) -> String {
        let firstLine = message.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let summary = firstLine.trimmingCharacters(in: .whitespaces).prefix(70)
        return "[DeskOrbit \(version) \(kind.rawValue.lowercased())] \(summary.isEmpty ? "Feedback" : String(summary))"
    }

    public func body() -> String {
        var parts = ["Type: \(kind.rawValue)", "", message.trimmingCharacters(in: .whitespacesAndNewlines)]
        let reply = contact.trimmingCharacters(in: .whitespacesAndNewlines)
        if !reply.isEmpty { parts += ["", "Reply to: \(reply)"] }
        if let diagnostics, !diagnostics.isEmpty { parts += ["", "---- diagnostics (privacy-redacted) ----", diagnostics] }
        if let crashExcerpt, !crashExcerpt.isEmpty { parts += ["", "---- crash report excerpt ----", crashExcerpt] }
        return parts.joined(separator: "\n")
    }
}

public enum FeedbackChannel {
    /// Browsers and mail apps reject very long URLs; GitHub's limit is about 8 KB.
    public static let maximumURLBodyCharacters = 6_000

    public static func mailtoURL(to address: String, subject: String, body: String) -> URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = address
        components.queryItems = [
            URLQueryItem(name: "subject", value: subject),
            URLQueryItem(name: "body", value: truncated(body)),
        ]
        return components.url
    }

    public static func githubIssueURL(repository: String, subject: String, body: String, labels: [String]) -> URL? {
        var components = URLComponents(string: "https://github.com/\(repository)/issues/new")
        components?.queryItems = [
            URLQueryItem(name: "title", value: subject),
            URLQueryItem(name: "body", value: truncated(body)),
            URLQueryItem(name: "labels", value: labels.joined(separator: ",")),
        ]
        return components?.url
    }

    public static func truncated(_ body: String) -> String {
        guard body.count > maximumURLBodyCharacters else { return body }
        return String(body.prefix(maximumURLBodyCharacters)) + "\n…(trimmed; use Copy Report for the full text)"
    }
}

/// Which crash reports are new since the person last answered the prompt.
public enum CrashReportPolicy {
    public static func newReports(_ reports: [(name: String, modified: Date)], since lastSeen: Date?, now: Date = .now) -> [String] {
        let floor = lastSeen ?? now.addingTimeInterval(-7 * 86_400)
        return reports
            .filter { ($0.name.hasPrefix("DeskOrbit") || $0.name.hasPrefix("Namespaces")) && $0.modified > floor }
            .sorted { $0.modified > $1.modified }
            .map(\.name)
    }

    /// Keeps the part of an .ips report that identifies the crash (exception,
    /// crashed thread, OS and app version) and drops the rest.
    public static func excerpt(_ text: String, limit: Int = 3_000) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let redacted = text.replacingOccurrences(of: home, with: "~")
        return redacted.count > limit ? String(redacted.prefix(limit)) + "\n…(trimmed)" : redacted
    }
}
