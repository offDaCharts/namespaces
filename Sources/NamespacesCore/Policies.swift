import Foundation

public enum TrackingPolicy {
    public static func idleBoundary(now: Date, idleSeconds: TimeInterval, hasOpenSegment: Bool, wasIdle: Bool) -> Date {
        guard hasOpenSegment, !wasIdle, idleSeconds > 0 else { return now }
        return now.addingTimeInterval(-idleSeconds)
    }
}

public enum AutomationValidator {
    public static func errors(for action: AutomationAction) -> [String] {
        var errors: [String] = []
        if action.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Action title is required.") }
        if action.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { errors.append("Action target is required.") }
        if !(0.1...3600).contains(action.timeout) { errors.append("Timeout must be between 0.1 and 3600 seconds.") }
        switch action.kind {
        case .openURL:
            let scheme = URL(string: action.target)?.scheme?.lowercased()
            if !["http", "https", "mailto"].contains(scheme ?? "") { errors.append("Only http, https, and mailto URLs are allowed.") }
        case .openPath, .runScript:
            if !action.target.hasPrefix("/") { errors.append("Local paths must be absolute.") }
            if action.kind == .runScript, let interpreter = action.arguments.first, !interpreter.hasPrefix("/") { errors.append("The script interpreter must be an absolute path.") }
        case .launchApplication, .runShortcut: break
        }
        return errors
    }
}
