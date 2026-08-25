import Foundation

public enum SpaceSearch {
    public static func rank(query: String, profiles: [SpaceProfile], recents: [UUID]) -> [SpaceProfile] {
        let needle = normalize(query)
        guard !needle.isEmpty else {
            return profiles.sorted { lhs, rhs in
                let li = recents.firstIndex(of: lhs.id) ?? Int.max
                let ri = recents.firstIndex(of: rhs.id) ?? Int.max
                return li == ri ? lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending : li < ri
            }
        }
        return profiles.compactMap { profile -> (SpaceProfile, Int)? in
            let candidates = [profile.name] + profile.aliases
            let best = candidates.map { score(needle, normalize($0)) }.max() ?? 0
            return best > 0 ? (profile, best + max(0, 20 - (recents.firstIndex(of: profile.id) ?? 20))) : nil
        }.sorted { $0.1 == $1.1 ? $0.0.name < $1.0.name : $0.1 > $1.1 }.map(\.0)
    }
    private static func normalize(_ text: String) -> String { text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current).lowercased() }
    private static func score(_ q: String, _ value: String) -> Int {
        if value == q { return 1000 }
        if value.hasPrefix(q) { return 800 - value.count }
        if value.split(separator: " ").contains(where: { $0.hasPrefix(q) }) { return 650 - value.count }
        if let range = value.range(of: q) { return 500 - value.distance(from: value.startIndex, to: range.lowerBound) }
        var i = q.startIndex; var gaps = 0; var last: String.Index?
        for p in value.indices where i < q.endIndex && value[p] == q[i] {
            if let last { gaps += value.distance(from: last, to: p) - 1 }
            last = p; i = q.index(after: i)
        }
        return i == q.endIndex ? max(1, 300 - gaps) : 0
    }
}
