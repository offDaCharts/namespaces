import OSLog

enum Metrics {
    static let logger = Logger(subsystem: "com.kauibungalow.deskorbit", category: "lifecycle")
    static let signposter = OSSignposter(subsystem: "com.kauibungalow.deskorbit", category: "performance")
}
