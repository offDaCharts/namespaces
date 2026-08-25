import Foundation

public struct TopologySnapshot: Codable, Hashable, Sendable {
    public struct Display: Codable, Hashable, Identifiable, Sendable {
        public var id: String
        public var name: String
        public var spaces: [NativeSpace]
        public init(id: String, name: String, spaces: [NativeSpace]) { self.id = id; self.name = name; self.spaces = spaces }
    }
    public var capturedAt: Date
    public var displays: [Display]
    public init(capturedAt: Date = .now, displays: [Display]) throws {
        let allIDs = displays.flatMap { $0.spaces.map(\.id) }
        guard Set(allIDs).count == allIDs.count else { throw TopologyError.duplicateNativeSpaceID }
        guard Set(displays.map(\.id)).count == displays.count else { throw TopologyError.duplicateDisplayID }
        self.capturedAt = capturedAt; self.displays = displays
    }
    public var spaces: [NativeSpace] { displays.flatMap(\.spaces) }
}

public enum TopologyError: LocalizedError, Sendable {
    case duplicateNativeSpaceID, duplicateDisplayID
    public var errorDescription: String? { switch self { case .duplicateNativeSpaceID: "Topology contains a duplicate native Space identifier."; case .duplicateDisplayID: "Topology contains a duplicate display identifier." } }
}

public struct TopologyChange: Hashable, Sendable {
    public var added: [NativeSpace]
    public var removed: [NativeSpace]
    public var changed: [(old: NativeSpace, new: NativeSpace)]
    public init(from old: TopologySnapshot, to new: TopologySnapshot) {
        let oldByID = Dictionary(uniqueKeysWithValues: old.spaces.map { ($0.id, $0) })
        let newByID = Dictionary(uniqueKeysWithValues: new.spaces.map { ($0.id, $0) })
        added = new.spaces.filter { oldByID[$0.id] == nil }
        removed = old.spaces.filter { newByID[$0.id] == nil }
        changed = new.spaces.compactMap { value in guard let prior = oldByID[value.id], prior != value else { return nil }; return (prior, value) }
    }

    public static func == (lhs: Self, rhs: Self) -> Bool { lhs.added == rhs.added && lhs.removed == rhs.removed && lhs.changed.map { [$0.old, $0.new] } == rhs.changed.map { [$0.old, $0.new] } }
    public func hash(into hasher: inout Hasher) { hasher.combine(added); hasher.combine(removed); for pair in changed { hasher.combine(pair.old); hasher.combine(pair.new) } }
}

public enum ReconciliationConfidence: String, Codable, Sendable { case confirmed, probable, ambiguous, new }
public struct ReconciliationCandidate: Hashable, Sendable {
    public var profileID: UUID
    public var score: Int
    public var reasons: [String]
}
public struct ReconciliationResult: Hashable, Sendable {
    public var observation: NativeSpace
    public var confidence: ReconciliationConfidence
    public var candidate: ReconciliationCandidate?
}

public enum SpaceReconciler {
    /// Conservative scorer. Only exact IDs are confirmed automatically; a unique
    /// high-context match is presented as probable and must still be confirmed by UI.
    public static func reconcile(observations: [NativeSpace], profiles: [SpaceProfile]) -> [ReconciliationResult] {
        observations.map { observed in
            let ranked = profiles.map { profile -> ReconciliationCandidate in
                var score = 0; var reasons: [String] = []
                if profile.nativeID == observed.id { score += 100; reasons.append("exact native identifier") }
                if profile.displayID == observed.displayID { score += 25; reasons.append("same display") }
                if profile.lastKnownIndex == observed.index { score += 15; reasons.append("same ordinal") }
                if profile.lastKnownKind == observed.kind { score += 10; reasons.append("same Space kind") }
                return .init(profileID: profile.id, score: score, reasons: reasons)
            }.sorted { $0.score > $1.score }
            guard let best = ranked.first, best.score > 0 else { return .init(observation: observed, confidence: .new, candidate: nil) }
            if best.score >= 100 { return .init(observation: observed, confidence: .confirmed, candidate: best) }
            let runnerUp = ranked.dropFirst().first?.score ?? 0
            if best.score >= 45, best.score - runnerUp >= 15 { return .init(observation: observed, confidence: .probable, candidate: best) }
            return .init(observation: observed, confidence: .ambiguous, candidate: best)
        }
    }
}
