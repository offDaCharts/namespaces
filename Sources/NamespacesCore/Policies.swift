import Foundation

public enum CommercialPolicy {
    public static let trialLengthDays = 14
    public static let priceDisplay = "$9.99"

    /// Free beta licenses (a separate $0 Gumroad product) work through the end
    /// of February 2027, then the app asks for a paid key with a thank-you code.
    public static let betaEndDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "America/New_York")
        components.year = 2027; components.month = 3; components.day = 1
        return components.date!
    }()

    public static func betaDaysRemaining(now: Date = .now, endDate: Date = betaEndDate) -> Int {
        max(0, Int(ceil(endDate.timeIntervalSince(now) / 86_400)))
    }

    public static func trialDaysRemaining(firstLaunch: Date, now: Date = .now) -> Int {
        // A future first-launch timestamp means the system clock moved backwards.
        // Do not extend a trial in that state.
        guard firstLaunch <= now else { return 0 }
        let end = firstLaunch.addingTimeInterval(TimeInterval(trialLengthDays * 86_400))
        return max(0, Int(ceil(end.timeIntervalSince(now) / 86_400)))
    }
}

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

/// How a license re-check should change access. A previously activated copy
/// stays usable when the license server cannot be reached, but a definite
/// answer from the server (refunded, disabled, unknown or wrong-product key)
/// must not be mistaken for "offline": every non-2xx reply used to be treated
/// as an outage, so a refunded key stayed licensed forever.
public enum LicenseCheckOutcome: Equatable, Sendable {
    case valid
    case rejected(String)
    case unreachable

    /// - Parameters:
    ///   - httpStatus: nil when the request never got an HTTP reply.
    ///   - valid: the server's validity flag when the body decoded.
    public static func from(httpStatus: Int?, valid: Bool?, message: String?) -> LicenseCheckOutcome {
        guard let status = httpStatus else { return .unreachable }
        if status == 429 || status == 408 || status >= 500 { return .unreachable }
        if (200..<300).contains(status) {
            guard let valid else { return .unreachable }
            return valid ? .valid : .rejected(message ?? "This license is no longer valid.")
        }
        // 4xx: the server understood the request and said no.
        if valid == nil, message == nil { return .unreachable }
        return .rejected(message ?? "This license is no longer valid.")
    }
}
