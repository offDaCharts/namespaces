import Foundation

public struct NativeSpace: Codable, Hashable, Identifiable, Sendable {
    public var id: UInt64
    public var displayID: String
    public var displayName: String
    public var index: Int
    public var isActive: Bool
    public var kind: SpaceKind

    public init(id: UInt64, displayID: String, displayName: String, index: Int, isActive: Bool, kind: SpaceKind = .desktop) {
        self.id = id
        self.displayID = displayID
        self.displayName = displayName
        self.index = index
        self.isActive = isActive
        self.kind = kind
    }
}

public enum SpaceKind: String, Codable, Sendable { case desktop, fullscreen, unknown }

public struct SpaceProfile: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var nativeID: UInt64
    public var displayID: String
    public var lastKnownIndex: Int?
    public var lastKnownKind: SpaceKind?
    public var name: String
    public var symbol: String
    public var colorHex: String
    public var aliases: [String]
    public var trackingEnabled: Bool
    public var billable: Bool
    public var hourlyRate: Double?
    public var shortcut: ShortcutSpec?
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), nativeID: UInt64, displayID: String, lastKnownIndex: Int? = nil, lastKnownKind: SpaceKind? = nil, name: String, symbol: String = "square.grid.2x2", colorHex: String = "#7C5CFC", aliases: [String] = [], trackingEnabled: Bool = true, billable: Bool = false, hourlyRate: Double? = nil, shortcut: ShortcutSpec? = nil, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.nativeID = nativeID; self.displayID = displayID; self.name = name
        self.lastKnownIndex = lastKnownIndex; self.lastKnownKind = lastKnownKind
        self.symbol = symbol; self.colorHex = colorHex; self.aliases = aliases
        self.trackingEnabled = trackingEnabled; self.billable = billable; self.hourlyRate = hourlyRate
        self.shortcut = shortcut; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public struct ShortcutSpec: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var display: String
    public init(keyCode: UInt32, modifiers: UInt32, display: String) {
        self.keyCode = keyCode; self.modifiers = modifiers; self.display = display
    }
}

public enum NoteKind: String, Codable, Sendable { case text, checklist }
public struct ChecklistItem: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var text: String = ""
    public var isCompleted: Bool = false
    public var completedAt: Date?
    public init(id: UUID = UUID(), text: String = "", isCompleted: Bool = false, completedAt: Date? = nil) {
        self.id = id; self.text = text; self.isCompleted = isCompleted; self.completedAt = completedAt
    }
}

public struct SpaceNote: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var spaceID: UUID
    public var title: String
    public var body: String
    public var kind: NoteKind
    public var items: [ChecklistItem]
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public init(id: UUID = UUID(), spaceID: UUID, title: String = "Note", body: String = "", kind: NoteKind = .text, items: [ChecklistItem] = [], isArchived: Bool = false, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.spaceID = spaceID; self.title = title; self.body = body; self.kind = kind
        self.items = items; self.isArchived = isArchived; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

public enum AutomationActionKind: String, Codable, CaseIterable, Sendable { case launchApplication, openPath, openURL, runShortcut, runScript }
public struct AutomationAction: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var kind: AutomationActionKind
    public var title: String
    public var target: String
    public var arguments: [String]
    public var isEnabled: Bool
    public var continueOnFailure: Bool
    public var timeout: TimeInterval
    public var approvedFingerprint: String?
    public init(id: UUID = UUID(), kind: AutomationActionKind, title: String, target: String = "", arguments: [String] = [], isEnabled: Bool = true, continueOnFailure: Bool = false, timeout: TimeInterval = 30, approvedFingerprint: String? = nil) {
        self.id = id; self.kind = kind; self.title = title; self.target = target; self.arguments = arguments
        self.isEnabled = isEnabled; self.continueOnFailure = continueOnFailure; self.timeout = timeout; self.approvedFingerprint = approvedFingerprint
    }
}

public struct AutomationGroup: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var spaceID: UUID
    public var name: String
    public var details: String
    public var actions: [AutomationAction]
    public var isEnabled: Bool
    public init(id: UUID = UUID(), spaceID: UUID, name: String = "Setup Workspace", details: String = "", actions: [AutomationAction] = [], isEnabled: Bool = true) {
        self.id = id; self.spaceID = spaceID; self.name = name; self.details = details; self.actions = actions; self.isEnabled = isEnabled
    }
}

public enum TrackingClassification: String, Codable, Sendable { case active, idle, manual, recovered, uncertain }
public struct TrackingSegment: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var spaceID: UUID
    public var appBundleID: String
    public var appName: String
    public var start: Date
    public var end: Date?
    public var classification: TrackingClassification
    public var sessionID: UUID?
    public var billable: Bool
    public var note: String
    public var duration: TimeInterval { max(0, (end ?? .now).timeIntervalSince(start)) }
    public init(id: UUID = UUID(), spaceID: UUID, appBundleID: String = "", appName: String = "Unknown", start: Date = .now, end: Date? = nil, classification: TrackingClassification = .active, sessionID: UUID? = nil, billable: Bool = false, note: String = "") {
        self.id = id; self.spaceID = spaceID; self.appBundleID = appBundleID; self.appName = appName; self.start = start; self.end = end
        self.classification = classification; self.sessionID = sessionID; self.billable = billable; self.note = note
    }
}

public struct TrackingSession: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var name: String
    public var startedAt: Date
    public var endedAt: Date?
    public var isPaused: Bool
    public var note: String
    public init(id: UUID = UUID(), name: String, startedAt: Date = .now, endedAt: Date? = nil, isPaused: Bool = false, note: String = "") {
        self.id = id; self.name = name; self.startedAt = startedAt; self.endedAt = endedAt; self.isPaused = isPaused; self.note = note
    }
}

public struct TrackingAuditRecord: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID = UUID()
    public var segmentID: UUID
    public var action: String
    public var before: String
    public var after: String
    public var createdAt: Date = .now
    public init(segmentID: UUID, action: String, before: String, after: String, createdAt: Date = .now) {
        self.segmentID = segmentID; self.action = action; self.before = before; self.after = after; self.createdAt = createdAt
    }
}

public struct AppPreferences: Codable, Hashable, Sendable {
    public enum MenuLabelMode: String, Codable, CaseIterable, Sendable { case iconAndName, name, icon, colorAndName, number }
    public var menuLabelMode: MenuLabelMode = .iconAndName
    public var quickSwitcherShortcut = ShortcutSpec(keyCode: 49, modifiers: 2048, display: "⌥Space")
    public var jumpBackShortcut = ShortcutSpec(keyCode: 49, modifiers: 2560, display: "⌥⇧Space")
    public var idleThreshold: TimeInterval = 300
    public var trackingEnabled = true
    public var hoverEnabled = false
    public var missionControlLabelsEnabled = true
    public var enhancedIntegrationEnabled = true
    public var showFullscreenSpaces = true
    public var launchAtLogin = false
    public var trackingPaused = false
    /// 0 disables rolling backups; supported enabled values are 7 and 30.
    public var rollingBackupRetention = 0
    public var globalShortcutsEnabled = true
    public init() {}

    private enum CodingKeys: String, CodingKey { case menuLabelMode, quickSwitcherShortcut, jumpBackShortcut, idleThreshold, trackingEnabled, hoverEnabled, missionControlLabelsEnabled, enhancedIntegrationEnabled, showFullscreenSpaces, launchAtLogin, trackingPaused, rollingBackupRetention, globalShortcutsEnabled }
    public init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy: CodingKeys.self)
        menuLabelMode = try c.decodeIfPresent(MenuLabelMode.self, forKey: .menuLabelMode) ?? menuLabelMode
        quickSwitcherShortcut = try c.decodeIfPresent(ShortcutSpec.self, forKey: .quickSwitcherShortcut) ?? quickSwitcherShortcut
        jumpBackShortcut = try c.decodeIfPresent(ShortcutSpec.self, forKey: .jumpBackShortcut) ?? jumpBackShortcut
        idleThreshold = try c.decodeIfPresent(TimeInterval.self, forKey: .idleThreshold) ?? idleThreshold
        trackingEnabled = try c.decodeIfPresent(Bool.self, forKey: .trackingEnabled) ?? trackingEnabled
        hoverEnabled = try c.decodeIfPresent(Bool.self, forKey: .hoverEnabled) ?? hoverEnabled
        missionControlLabelsEnabled = try c.decodeIfPresent(Bool.self, forKey: .missionControlLabelsEnabled) ?? missionControlLabelsEnabled
        enhancedIntegrationEnabled = try c.decodeIfPresent(Bool.self, forKey: .enhancedIntegrationEnabled) ?? enhancedIntegrationEnabled
        showFullscreenSpaces = try c.decodeIfPresent(Bool.self, forKey: .showFullscreenSpaces) ?? showFullscreenSpaces
        launchAtLogin = try c.decodeIfPresent(Bool.self, forKey: .launchAtLogin) ?? launchAtLogin
        trackingPaused = try c.decodeIfPresent(Bool.self, forKey: .trackingPaused) ?? trackingPaused
        rollingBackupRetention = try c.decodeIfPresent(Int.self, forKey: .rollingBackupRetention) ?? rollingBackupRetention
        globalShortcutsEnabled = try c.decodeIfPresent(Bool.self, forKey: .globalShortcutsEnabled) ?? globalShortcutsEnabled
    }
}

public enum ShortcutValidation: Equatable, Sendable { case valid, warning(String), invalid(String) }
public enum ShortcutValidator {
    private static let shift: UInt32 = 512
    public static func validate(_ shortcut: ShortcutSpec) -> ShortcutValidation {
        guard shortcut.modifiers & ~shift != 0 else { return .invalid("Global shortcuts require Command, Option, or Control; Shift alone is not enough.") }
        if shortcut.display == "⌘Q" || shortcut.display == "⌘W" || shortcut.display == "⌘Tab" || shortcut.display == "⌘Space" { return .warning("This is a common macOS shortcut and may conflict with the system or other apps.") }
        return .valid
    }
    public static func conflicts(_ shortcuts: [ShortcutSpec]) -> Set<String> {
        let grouped = Dictionary(grouping: shortcuts) { "\($0.keyCode):\($0.modifiers)" }
        return Set(grouped.filter { $0.value.count > 1 }.keys)
    }
    public static func signature(_ value: ShortcutSpec) -> String { "\(value.keyCode):\(value.modifiers)" }
}

public struct AppData: Codable, Sendable {
    public var schemaVersion = 1
    public var spaces: [SpaceProfile] = []
    public var notes: [SpaceNote] = []
    public var automations: [AutomationGroup] = []
    public var segments: [TrackingSegment] = []
    public var sessions: [TrackingSession] = []
    public var trackingAudit: [TrackingAuditRecord] = []
    public var preferences = AppPreferences()
    public var recentSpaceIDs: [UUID] = []
    public init() {}
    private enum CodingKeys: String, CodingKey { case schemaVersion, spaces, notes, automations, segments, sessions, trackingAudit, preferences, recentSpaceIDs }
    public init(from decoder: Decoder) throws {
        self.init(); let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        spaces = try c.decodeIfPresent([SpaceProfile].self, forKey: .spaces) ?? []
        notes = try c.decodeIfPresent([SpaceNote].self, forKey: .notes) ?? []
        automations = try c.decodeIfPresent([AutomationGroup].self, forKey: .automations) ?? []
        segments = try c.decodeIfPresent([TrackingSegment].self, forKey: .segments) ?? []
        sessions = try c.decodeIfPresent([TrackingSession].self, forKey: .sessions) ?? []
        trackingAudit = try c.decodeIfPresent([TrackingAuditRecord].self, forKey: .trackingAudit) ?? []
        preferences = try c.decodeIfPresent(AppPreferences.self, forKey: .preferences) ?? AppPreferences()
        recentSpaceIDs = try c.decodeIfPresent([UUID].self, forKey: .recentSpaceIDs) ?? []
    }
}
