import Foundation

public enum RuntimeCompatibility {
    /// DeskOrbit's enhanced provider calls undocumented WindowServer symbols.
    /// Their ABI is not stable across major macOS releases, so a newly released
    /// major version must start in the public-API fallback until it is validated.
    public static func requiresTahoeCompatibilityMode(
        operatingSystemVersion: OperatingSystemVersion = ProcessInfo.processInfo.operatingSystemVersion,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        if environment["DESKORBIT_ENABLE_EXPERIMENTAL_TAHOE_SPACES"] == "1" { return false }
        if environment["DESKORBIT_FORCE_TAHOE_COMPATIBILITY"] == "1" { return true }
        return operatingSystemVersion.majorVersion >= 26
    }
}
