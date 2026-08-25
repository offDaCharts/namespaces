import Foundation
import SwiftData

@Model
final class AppDataRecord {
    @Attribute(.unique) var key: String
    var payload: Data
    var updatedAt: Date
    init(key: String = "current", payload: Data, updatedAt: Date = .now) { self.key = key; self.payload = payload; self.updatedAt = updatedAt }
}

public actor DataStore {
    public nonisolated let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let container: ModelContainer?

    public init(fileURL: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Namespaces", isDirectory: true)
        self.fileURL = fileURL ?? base.appendingPathComponent("Namespaces.json")
        self.encoder = JSONEncoder(); self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; self.encoder.dateEncodingStrategy = .iso8601
        self.decoder = JSONDecoder(); self.decoder.dateDecodingStrategy = .iso8601
        let configuration = ModelConfiguration("Namespaces", isStoredInMemoryOnly: fileURL != nil)
        self.container = try? ModelContainer(for: AppDataRecord.self, configurations: configuration)
    }

    public func load() throws -> AppData {
        if let container {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<AppDataRecord>(); descriptor.fetchLimit = 1
            if let record = try? context.fetch(descriptor).first, let decoded = try? decoder.decode(AppData.self, from: record.payload) { return decoded }
        }
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return AppData() }
        return try decoder.decode(AppData.self, from: Data(contentsOf: fileURL))
    }

    public func save(_ data: AppData) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let encoded = try encoder.encode(data)
        if let container {
            let context = ModelContext(container)
            var descriptor = FetchDescriptor<AppDataRecord>(); descriptor.fetchLimit = 1
            if let record = try context.fetch(descriptor).first { record.payload = encoded; record.updatedAt = .now }
            else { context.insert(AppDataRecord(payload: encoded)) }
            try context.save()
        }
        try encoded.write(to: fileURL, options: [.atomic, .completeFileProtection])
        if [7, 30].contains(data.preferences.rollingBackupRetention) { try createRollingBackup(encoded, retention: data.preferences.rollingBackupRetention) }
    }

    public func export(_ data: AppData, to url: URL) throws {
        try encoder.encode(data).write(to: url, options: .atomic)
    }

    public func exportPackage(_ data: AppData, to url: URL) throws {
        let parent = url.deletingLastPathComponent()
        let staging = parent.appendingPathComponent(".Namespaces-Export-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: staging) }
        try FileManager.default.createDirectory(at: staging.appendingPathComponent("Notes", isDirectory: true), withIntermediateDirectories: true)
        try encoder.encode(data).write(to: staging.appendingPathComponent("data.json"), options: .atomic)
        let manifest: [String: Any] = ["format": "Namespaces Backup", "schemaVersion": data.schemaVersion, "createdAt": ISO8601DateFormatter().string(from: .now), "includesTracking": true, "notes": data.notes.count, "automations": data.automations.count]
        try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys]).write(to: staging.appendingPathComponent("manifest.json"), options: .atomic)
        for note in data.notes {
            let safeTitle = note.title.replacingOccurrences(of: "[^A-Za-z0-9._ -]", with: "-", options: .regularExpression).prefix(80)
            let body = note.kind == .text ? "# \(note.title)\n\n\(note.body)\n" : "# \(note.title)\n\n" + note.items.map { "- [\($0.isCompleted ? "x" : " ")] \($0.text)" }.joined(separator: "\n") + "\n"
            try body.write(to: staging.appendingPathComponent("Notes/\(note.id.uuidString)-\(safeTitle).md"), atomically: true, encoding: .utf8)
        }
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        try FileManager.default.moveItem(at: staging, to: url)
    }

    public func decodeBackup(at url: URL) throws -> AppData {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isDirectoryKey])
        let source = values.isDirectory == true ? url.appendingPathComponent("data.json") : url
        let sourceValues = try source.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
        guard sourceValues.isRegularFile == true, (sourceValues.fileSize ?? 0) < 100_000_000 else { throw StoreError.invalidBackup }
        let value = try decoder.decode(AppData.self, from: Data(contentsOf: source))
        guard value.schemaVersion <= 1 else { throw StoreError.newerSchema }
        guard Set(value.spaces.map(\.id)).count == value.spaces.count,
              Set(value.notes.map(\.id)).count == value.notes.count,
              Set(value.automations.map(\.id)).count == value.automations.count,
              Set(value.segments.map(\.id)).count == value.segments.count else { throw StoreError.invalidBackup }
        let spaceIDs = Set(value.spaces.map(\.id))
        guard value.notes.allSatisfy({ spaceIDs.contains($0.spaceID) }),
              value.automations.allSatisfy({ spaceIDs.contains($0.spaceID) }),
              value.segments.allSatisfy({ spaceIDs.contains($0.spaceID) }) else { throw StoreError.invalidBackup }
        return value
    }

    public func reset() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) { try FileManager.default.removeItem(at: fileURL) }
        if let container {
            let context = ModelContext(container)
            try context.delete(model: AppDataRecord.self)
            try context.save()
        }
    }

    private func createRollingBackup(_ encoded: Data, retention: Int) throws {
        let directory = fileURL.deletingLastPathComponent().appendingPathComponent("Rolling Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]).filter { $0.pathExtension == "json" }
        let newest = existing.compactMap { try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate }.max() ?? .distantPast
        if Date().timeIntervalSince(newest) >= 86_400 {
            let stamp = ISO8601DateFormatter().string(from: .now).replacingOccurrences(of: ":", with: "-")
            try encoded.write(to: directory.appendingPathComponent("Namespaces-\(stamp).json"), options: [.atomic, .completeFileProtection])
        }
        let sorted = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles]).filter { $0.pathExtension == "json" }.sorted {
            (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) ?? .distantPast > (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? .distantPast) ?? .distantPast
        }
        for old in sorted.dropFirst(retention) { try FileManager.default.removeItem(at: old) }
    }

    public enum StoreError: LocalizedError { case invalidBackup, newerSchema
        public var errorDescription: String? { self == .invalidBackup ? "The backup is not a valid Namespaces file." : "This backup was created by a newer Namespaces version." }
    }
}

public enum CSVExporter {
    public static func trackingCSV(segments: [TrackingSegment], spaces: [SpaceProfile]) -> String {
        let formatter = ISO8601DateFormatter()
        var lines = ["id,space,application,bundle_id,start,end,duration_seconds,classification,billable,note"]
        for item in segments {
            let name = spaces.first(where: { $0.id == item.spaceID })?.name ?? "Unknown"
            lines.append([item.id.uuidString, name, item.appName, item.appBundleID, formatter.string(from: item.start), item.end.map { formatter.string(from: $0) } ?? "", String(format: "%.0f", item.duration), item.classification.rawValue, String(item.billable), item.note].map { escape($0) }.joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }
    private static func escape(_ value: String) -> String { "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\"" }
}
