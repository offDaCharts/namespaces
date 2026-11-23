import Foundation

/// Gumroad license-key verification (https://api.gumroad.com/v2/licenses/verify).
///
/// Gumroad is merchant of record and issues one key per sale. Its public verify
/// call needs no secret, so it is safe to ship in the app. Unlike Lemon Squeezy
/// it has no per-Mac "instance": it only counts verifications that ask to
/// increment (`uses`). DeskOrbit increments once when a Mac activates and
/// re-checks without incrementing, so `uses` approximates activated Macs.
/// Releasing a Mac cannot decrement the count without the seller's API token,
/// which must never ship in the app; support frees a slot from the dashboard.
public enum GumroadLicense {
    public static let verifyURL = URL(string: "https://api.gumroad.com/v2/licenses/verify")!
    /// Activations allowed per key. The site promises three Macs; two spare
    /// activations absorb reinstalls because Gumroad cannot release a slot.
    public static let maximumActivations = 5

    public struct Purchase: Decodable, Equatable, Sendable {
        public var refunded: Bool?
        public var disputed: Bool?
        public var chargebacked: Bool?
        public var subscriptionCancelledAt: String?
        public var subscriptionFailedAt: String?
        public var email: String?

        enum CodingKeys: String, CodingKey {
            case refunded, disputed, chargebacked, email
            case subscriptionCancelledAt = "subscription_cancelled_at"
            case subscriptionFailedAt = "subscription_failed_at"
        }
    }

    public struct VerifyResponse: Decodable, Equatable, Sendable {
        public var success: Bool
        public var uses: Int?
        public var message: String?
        public var purchase: Purchase?
    }

    public static func requestBody(productID: String, licenseKey: String, incrementUses: Bool) -> Data {
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "product_id", value: productID),
            URLQueryItem(name: "license_key", value: licenseKey),
            URLQueryItem(name: "increment_uses_count", value: incrementUses ? "true" : "false"),
        ]
        // URLComponents leaves "+" unescaped, which form decoding reads as a space.
        let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
        return Data(encoded.utf8)
    }

    /// Interprets a verify reply. `incremented` says whether this call counted
    /// an activation, in which case the activation limit applies.
    public static func outcome(httpStatus: Int?, data: Data?, incremented: Bool) -> LicenseCheckOutcome {
        let body = data.flatMap { try? JSONDecoder().decode(VerifyResponse.self, from: $0) }
        guard let status = httpStatus else { return .unreachable }
        if status == 429 || status == 408 || status >= 500 { return .unreachable }
        guard let body else { return .unreachable }
        guard body.success else {
            return .rejected(body.message ?? "That license key does not exist for DeskOrbit.")
        }
        if let purchase = body.purchase {
            if purchase.refunded == true { return .rejected("This purchase was refunded, so its license is no longer active.") }
            if purchase.chargebacked == true || purchase.disputed == true {
                return .rejected("This purchase is disputed, so its license is paused. Contact support if this is a mistake.")
            }
        }
        if incremented, let uses = body.uses, uses > maximumActivations {
            return .rejected("This key has been activated on \(maximumActivations) Macs already. Email support to move it to this Mac.")
        }
        return .valid
    }
}
