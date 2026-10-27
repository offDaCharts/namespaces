import Foundation

public enum SpaceIdentity {
    /// Match stable identities globally before considering numeric IDs. Never use
    /// display position as proof of identity, and never assign a profile twice.
    public static func matches(_ observations: [NativeSpace], profiles: [SpaceProfile]) -> [UInt64: UUID] {
        var result: [UInt64: UUID] = [:]
        var used = Set<UUID>()
        let nativeCounts = Dictionary(grouping: observations, by: \.id)
        for observation in observations where nativeCounts[observation.id]?.count == 1 {
            guard let uuid = normalized(observation.persistentID),
                  observations.filter({ normalized($0.persistentID) == uuid }).count == 1 else { continue }
            let candidates = profiles.filter { $0.needsRelinking != true && normalized($0.persistentID) == uuid }
            if candidates.count == 1, let profile = candidates.first {
                result[observation.id] = profile.id; used.insert(profile.id)
            }
        }
        for observation in observations where result[observation.id] == nil && nativeCounts[observation.id]?.count == 1 {
            let candidates = profiles.filter { profile in
                guard profile.needsRelinking != true, !used.contains(profile.id), profile.nativeID == observation.id else { return false }
                if let lhs = normalized(profile.persistentID), let rhs = normalized(observation.persistentID), lhs != rhs { return false }
                return profile.lastKnownKind == nil || profile.lastKnownKind == observation.kind
            }
            // Old versions sometimes created duplicates after a display move.
            // Ambiguity is retained for explicit relinking, never resolved by age.
            if candidates.count == 1, let profile = candidates.first {
                result[observation.id] = profile.id; used.insert(profile.id)
            }
        }
        return result
    }

    public static func normalized(_ value: String?) -> String? {
        guard let value, let uuid = UUID(uuidString: value), uuid != UUID(uuid: (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) else { return nil }
        return uuid.uuidString
    }

    public static func reconcile(_ observations: [NativeSpace], profiles: inout [SpaceProfile]) {
        guard Set(observations.map(\.id)).count == observations.count else { return }
        let mapping = matches(observations, profiles: profiles)
        let claimed = Set(mapping.values)
        for native in observations {
            if let id = mapping[native.id], let index = profiles.firstIndex(where: { $0.id == id }) {
                profiles[index].nativeID = native.id
                profiles[index].displayID = native.displayID
                profiles[index].lastKnownIndex = native.index
                profiles[index].lastKnownKind = native.kind
                if let uuid = normalized(native.persistentID) { profiles[index].persistentID = uuid }
            } else {
                // Preserve ambiguous saved data without generating a new profile
                // on every refresh. Only a deliberate relink revives these bindings.
                for index in profiles.indices where !claimed.contains(profiles[index].id) {
                    let sameUUID = normalized(native.persistentID).map { $0 == normalized(profiles[index].persistentID) } ?? false
                    let storedUUID = normalized(profiles[index].persistentID)
                    let observedUUID = normalized(native.persistentID)
                    let compatible = storedUUID == nil || observedUUID == nil || storedUUID == observedUUID
                    if (profiles[index].nativeID == native.id && compatible) || sameUUID { profiles[index].needsRelinking = true }
                }
                profiles.append(SpaceProfile(nativeID: native.id, displayID: native.displayID,
                    lastKnownIndex: native.index, lastKnownKind: native.kind, persistentID: normalized(native.persistentID),
                    name: "\(native.kind == .fullscreen ? "Fullscreen" : "Desktop") \(native.index)",
                    colorHex: SpacePalette.color(at: native.index - 1)))
            }
        }
    }
}

public enum SpacePalette {
    public static let colors: [(name: String, hex: String)] = [
        ("Iris", "#7C5CFC"), ("Ocean", "#0A84FF"), ("Mint", "#30BFA3"),
        ("Amber", "#E59A24"), ("Rose", "#E85D86"), ("Sky", "#40B8D5"),
        ("Orchid", "#B768D9"), ("Fern", "#81A844")
    ]
    public static func color(at index: Int) -> String { colors[abs(index % colors.count)].hex }
}
