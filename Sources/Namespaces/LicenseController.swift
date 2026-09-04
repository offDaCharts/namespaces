import Combine
import Foundation
import NamespacesCore
import Security

@MainActor
final class LicenseController: ObservableObject {
    enum State: Equatable {
        case trial(daysRemaining: Int)
        case licensed
        case expired
    }

    @Published private(set) var state: State
    @Published private(set) var isWorking = false
    @Published private(set) var lastError: String?

    let trialLengthDays = CommercialPolicy.trialLengthDays
    let priceDisplay = CommercialPolicy.priceDisplay
    let purchaseURL = URL(string: "https://deskorbit.kauibungalow.com/#buy")!

    private let defaults = UserDefaults.standard
    private let firstLaunchKey = "DeskOrbit.firstLaunchDate"
    private let instanceIDKey = "DeskOrbit.licenseInstanceID"
    private let installationIDKey = "DeskOrbit.installationID"
    private let service = "com.kauibungalow.deskorbit.license"
    private let account = "license-key"
    private var licenseKey: String?

    init() {
        if defaults.object(forKey: firstLaunchKey) == nil {
            defaults.set(Date(), forKey: firstLaunchKey)
        }
        licenseKey = Self.readKeychain(service: service, account: account)
        state = licenseKey == nil ? .trial(daysRemaining: 14) : .licensed
        refreshLocalState()
        if licenseKey != nil {
            Task { await validate() }
        }
    }

    var hasAccess: Bool { state != .expired }

    var statusTitle: String {
        switch state {
        case .licensed: "Licensed"
        case .trial(let days): days == 1 ? "1 day left in trial" : "\(days) days left in trial"
        case .expired: "Trial expired"
        }
    }

    var maskedLicenseKey: String? {
        guard let licenseKey, licenseKey.count > 8 else { return nil }
        return "••••-••••-\(licenseKey.suffix(4))"
    }

    func activate(_ rawKey: String) async -> Bool {
        let key = rawKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            lastError = "Enter the license key from your purchase email."
            return false
        }

        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            let response: ActivateResponse = try await post(
                path: "activate",
                fields: ["license_key": key, "instance_name": instanceName]
            )
            guard response.activated, let instance = response.instance else {
                throw LicenseError.server(response.error ?? "The license could not be activated.")
            }
            try Self.writeKeychain(key, service: service, account: account)
            defaults.set(instance.id, forKey: instanceIDKey)
            licenseKey = key
            state = .licensed
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    func validate() async {
        guard let key = licenseKey else {
            refreshLocalState()
            return
        }

        var fields = ["license_key": key]
        if let instanceID = defaults.string(forKey: instanceIDKey) {
            fields["instance_id"] = instanceID
        }

        do {
            let response: ValidateResponse = try await post(path: "validate", fields: fields)
            if response.valid {
                state = .licensed
                lastError = nil
            } else {
                state = .expired
                lastError = response.error ?? "This license is no longer valid."
            }
        } catch {
            // A previously activated copy remains usable offline. Validation will
            // retry on the next launch or when the user opens License settings.
            state = .licensed
            lastError = "License validation is temporarily unavailable. DeskOrbit remains active offline."
        }
    }

    func deactivate() async -> Bool {
        guard let key = licenseKey, let instanceID = defaults.string(forKey: instanceIDKey) else {
            clearLicense()
            return true
        }

        isWorking = true
        lastError = nil
        defer { isWorking = false }

        do {
            let response: DeactivateResponse = try await post(
                path: "deactivate",
                fields: ["license_key": key, "instance_id": instanceID]
            )
            guard response.deactivated else {
                throw LicenseError.server(response.error ?? "The activation could not be released.")
            }
            clearLicense()
            return true
        } catch {
            lastError = error.localizedDescription
            return false
        }
    }

    private func refreshLocalState() {
        guard licenseKey == nil else {
            state = .licensed
            return
        }
        let firstLaunch = defaults.object(forKey: firstLaunchKey) as? Date ?? .now
        let remaining = CommercialPolicy.trialDaysRemaining(firstLaunch: firstLaunch)
        state = remaining > 0 ? .trial(daysRemaining: remaining) : .expired
    }

    private func clearLicense() {
        Self.deleteKeychain(service: service, account: account)
        defaults.removeObject(forKey: instanceIDKey)
        licenseKey = nil
        refreshLocalState()
    }

    private func post<Response: Decodable>(path: String, fields: [String: String]) async throws -> Response {
        var request = URLRequest(url: URL(string: "https://api.lemonsqueezy.com/v1/licenses/\(path)")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = fields.sorted(by: { $0.key < $1.key }).map(URLQueryItem.init)
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (data, urlResponse) = try await URLSession.shared.data(for: request)
        guard let response = urlResponse as? HTTPURLResponse else { throw LicenseError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            if let failure = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                throw LicenseError.server(failure.error)
            }
            throw LicenseError.server("The license server returned HTTP \(response.statusCode).")
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private var instanceName: String {
        let computer = Host.current().localizedName ?? "Mac"
        let installationID: String
        if let existing = defaults.string(forKey: installationIDKey) {
            installationID = existing
        } else {
            installationID = UUID().uuidString
            defaults.set(installationID, forKey: installationIDKey)
        }
        return "\(computer) · DeskOrbit · \(installationID.prefix(8))"
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

private struct ActivateResponse: Decodable {
    let activated: Bool
    let error: String?
    let instance: LicenseInstance?
}

private struct ValidateResponse: Decodable {
    let valid: Bool
    let error: String?
}

private struct DeactivateResponse: Decodable {
    let deactivated: Bool
    let error: String?
}

private struct ErrorResponse: Decodable { let error: String }
private struct LicenseInstance: Decodable { let id: String }

private enum LicenseError: LocalizedError {
    case invalidResponse
    case server(String)
    case keychain(OSStatus)

    var errorDescription: String? {
        switch self {
        case .invalidResponse: "The license server returned an invalid response."
        case .server(let message): message
        case .keychain(let status): "The license could not be saved securely (Keychain error \(status))."
        }
    }
}
