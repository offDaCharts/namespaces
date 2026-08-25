import OSLog

enum Metrics {
    static let logger = Logger(subsystem: "com.offdacharts.namespaces", category: "lifecycle")
    static let signposter = OSSignposter(subsystem: "com.offdacharts.namespaces", category: "performance")
}
