import Foundation

/// Pure parsing and dismissal rules shared by the Mission Control integration.
public enum MissionControlLayout {
    public static func shouldCloseAfterMissingWindow(hasSeenWindow: Bool, secondsSinceOpen: TimeInterval) -> Bool {
        hasSeenWindow || secondsSinceOpen >= 0.7
    }

    public static func desktopIndex(in values: [String]) -> Int? {
        for value in values {
            let words = value.lowercased().split { !$0.isLetter && !$0.isNumber }
            guard let desktopPosition = words.firstIndex(where: { $0 == "desktop" || $0 == "space" }) else { continue }
            for word in words.dropFirst(desktopPosition + 1) {
                if let index = Int(word), index > 0 { return index }
            }
        }
        return nil
    }
}
