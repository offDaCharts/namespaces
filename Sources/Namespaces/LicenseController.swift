import Combine
import Foundation
import NamespacesCore
import Security

@MainActor
final class LicenseController: ObservableObject {
    enum State: Equatable {
        case trial(daysRemaining: Int)
        case licensed
        case beta(daysRemaining: Int)
        case betaEnded
        case expired
    }

    /// Which Gumroad product a key belongs to. Beta keys come from a separate
    /// $0 product with a capped quantity and stop working after the beta.
    enum Tier: String { case standard, beta }

    @Published private(set) var state: State
    @Published private(set) var isWorking = false
    @Published private(set) var lastError: String?

    let trialLengthDays = CommercialPolicy.trialLengthDays
    let priceDisplay = CommercialPolicy.priceDisplay
    let purchaseURL = URL(string: "https://deskorbit.kauibungalow.com/#buy")!

    private let defaults = UserDefaults.standard
    private let firstLaunchKey = "DeskOrbit.firstLaunchDate"
    private let service = "com.kauibungalow.deskorbit.license"
    private let account = "license-key"
    private let tierKey = "DeskOrbit.licenseTier"
    private var licenseKey: String?
    private var tier: Tier {
        get { Tier(rawValue: defaults.string(forKey: tierKey) ?? "") ?? .standard }
        set { defaults.set(newValue.rawValue, forKey: tierKey) }
    }

    /// Where a beta tester buys with the thank-you discount (a Gumroad offer
    /// link). Falls back to the site's buy section.
    var betaThanksURL: URL {
        Self.infoString("DeskOrbitBetaThanksURL").flatMap(URL.init(string:)) ?? purchaseURL
    }

    init() {
        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(Date(), forKey: firstLaunchKey)
        }
        licenseKey = Self.readKeychain(service: service, account: account)
        state = .trial(daysRemaining: CommercialPolicy.trialLengthDays)
        refreshLocalState()
        if licenseKey != nil {
            Task { await validate() }
        }
    }

    var hasAccess: Bool { state != .expired && state != .betaEnded }
    var isBeta: Bool { tier == .beta }

    var statusTitle: String {
        switch state {
        case .licensed: "Licensed"
        case .trial(let days): days == 1 ? "1 day left in trial" : "\(days) days left in trial"
        case .beta(let days): days == 1 ? "Beta tester · 1 day left" : "Beta tester · \(days) days left"
        case .betaEnded: "Beta ended — thank you!"
        case .expired: "Trial expired"
        }
    }

    var maskedLicenseKey: String? {
        guard let licenseKey, licenseKey.count > 8 else { return nil }
        return "••••-••••-\(licenseKey.suffix(4))"
    }

    /// The Gumroad product this build sells. Set `DeskOrbitGumroadProductID`
    /// in Info.plist (Gumroad → product → Content → License key → product ID).
    private var productID: String? { Self.infoString("DeskOrbitGumroadProductID") }
    /// The free beta product (Info.plist `DeskOrbitGumroadBetaProductID`).
    private var betaProductID: String? { Self.infoString("DeskOrbitGumroadBetaProductID") }

    private static func infoString(_ key: String) -> String? {
        let value = (Bundle.main.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return value?.isEmpty == false ? value : nil
    }

    private func product(for tier: Tier) -> String? { tier == .beta ? betaProductID : productID }

    private func licensedState(for tier: Tier) -> State {
        guard tier == .beta else { return .licensed }
        let days = CommercialPolicy.betaDaysRemaining()
        return days > 0 ? .beta(daysRemaining: days) : .betaEnded
    }

    func activate(_ rawKey: String) async -> Bool {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            lastError = "Enter the license key from your purchase email."
            return false
        }
        guard productID != nil || betaProductID != nil else {
            lastError = "This build of DeskOrbit is not connected to a store yet."
            return false
        }

        isWorking = true
        lastError = nil
        defer { isWorking = false }

        // Try the paid product first, then the beta product. A key belongs to
        // exactly one of them, so at most one counts an activation.
        var outcome = LicenseCheckOutcome.rejected("That license key does not exist for DeskOrbit.")
        var matchedTier = Tier.standard
        for candidate in [Tier.standard, .beta] {
            guard let id = product(for: candidate) else { continue }
            outcome = await verify(productID: id, key: key, incrementUses: true)
            matchedTier = candidate
            if case .rejected = outcome { continue }
            break
        }
        if matchedTier == .beta, case .valid = outcome, CommercialPolicy.betaDaysRemaining() == 0 {
            outcome = .rejected("The DeskOrbit beta has ended, so beta keys no longer activate. Thank you for testing!")
        }

        switch outcome {
        case .valid:
            do {
                try Self.writeKeychain(key, service: service, account: account)
            } catch {
                lastError = error.localizedDescription
                return false
            }
            licenseKey = key
            tier = matchedTier
            state = licensedState(for: matchedTier)
            return true
        case .rejected(let message):
            lastError = message
            return false
        case .unreachable:
            lastError = "The license server could not be reached. Check your connection and try again."
            return false
        }
    }

    func validate() async {
        guard let key = licenseKey else {
            refreshLocalState()
            return
        }
        let currentTier = tier
        guard let productID = product(for: currentTier) else {
            // Keys activated by an earlier build stay usable.
            state = licensedState(for: currentTier)
            return
        }
        switch await verify(productID: productID, key: key, incrementUses: false) {
        case .valid:
            state = licensedState(for: currentTier)
            lastError = state == .betaEnded ? "The beta ended on Feb 28, 2027. Use the thank-you discount below to keep DeskOrbit." : nil
        case .rejected(let message):
            state = .expired
            lastError = message
        case .unreachable:
            // A previously activated copy remains usable offline. Validation will
            // retry on the next launch or when the user opens License settings.
            state = licensedState(for: currentTier)
            lastError = "License validation is temporarily unavailable. DeskOrbit remains active offline."
        }
    }

    /// Gumroad cannot release an activation without the seller token, so this
    /// only forgets the key on this Mac. The License page says so.
    func deactivate() async -> Bool {
        clearLicense()
        return true
    }

    private func refreshLocalState() {
        guard licenseKey == nil else {
            state = licensedState(for: tier)
            return
        }
        let firstLaunch = defaults.object(forKey: firstLaunchKey) as? Date ?? .now
        let remaining = CommercialPolicy.trialDaysRemaining(firstLaunch: firstLaunch)
        state = remaining > 0 ? .trial(daysRemaining: remaining) : .expired
    }

    private func clearLicense() {
        Self.deleteKeychain(service: service, account: account)
        defaults.removeObject(forKey: "DeskOrbit.licenseInstanceID")
        defaults.removeObject(forKey: tierKey)
        licenseKey = nil
        refreshLocalState()
    }

    private func verify(productID: String, key: String, incrementUses: Bool) async -> LicenseCheckOutcome {
        var request = URLRequest(url: GumroadLicense.verifyURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = GumroadLicense.requestBody(productID: productID, licenseKey: key, incrementUses: incrementUses)
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return GumroadLicense.outcome(httpStatus: (response as? HTTPURLResponse)?.statusCode, data: data, incremented: incrementUses)
        } catch {
            return .unreachable
        }
    }

    private static func readKeychain(service: String, account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func writeKeychain(_ value: String, service: String, account: String) throws {
        deleteKeychain(service: service, account: account)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
            kSecValueData as String: Data(value.utf8),
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw LicenseError.keychain(status) }
    }

    private static func deleteKeychain(service: String, account: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
    }
}

private enum LicenseError: LocalizedError {
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .keychain(let status): "The license could not be saved securely (Keychain error \(status))."
        }
    }
}
