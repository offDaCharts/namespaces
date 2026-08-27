import Foundation

public struct MissionControlLayoutItem: Equatable, Sendable {
    public let index: Int
    public let name: String

    public init(index: Int, name: String) {
        self.index = index
        self.name = name
    }
}

/// Pure layout/parsing rules shared by the Mission Control integration and
/// tests. Keeping this free of AppKit makes animation fallbacks deterministic.
public enum MissionControlLayout {
    public static func shouldCloseAfterMissingWindow(hasSeenWindow: Bool, secondsSinceOpen: TimeInterval) -> Bool {
        hasSeenWindow || secondsSinceOpen >= 0.7
    }

    /// Pointer-based frames are useful only during the opening animation. Once
    /// exact Dock anchors have appeared, their disappearance means stale
    /// fallback labels must not be drawn over the ordinary desktop.
    public static func shouldRenderTargets(hasSeenExactTargets: Bool, hasExactTargets: Bool) -> Bool {
        !hasSeenExactTargets || hasExactTargets
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

    public static func fallbackFrames(items: [MissionControlLayoutItem], screenFrame: CGRect) -> [Int: CGRect] {
        guard !items.isEmpty else { return [:] }
        let sorted = items.sorted { $0.index < $1.index }
        let available = max(300, screenFrame.size.width - 60)
        // Mission Control distributes desktop thumbnails across almost the
        // entire display. Keep a modest outer gutter and cap only unusually
        // wide layouts; a small cap compresses many Spaces into the center.
        let slot = min(320, available / CGFloat(sorted.count))
        let total = slot * CGFloat(sorted.count)
        let startX = screenFrame.origin.x + screenFrame.size.width / 2 - total / 2
        var frames: [Int: CGRect] = [:]
        for (offset, item) in sorted.enumerated() {
            let maximumWidth = max(CGFloat(52), slot - 8)
            let desiredWidth = max(CGFloat(54), CGFloat(item.name.count) * 6.4 + 18)
            let width = min(maximumWidth, desiredWidth)
            let offsetX = CGFloat(offset) * slot
            let centeredInset = (slot - width) / 2
            let originX = startX + offsetX + centeredInset
            // Approximate the lower inset of Mission Control's expanded
            // thumbnail strip. Exact placement replaces this as soon as AX
            // exposes the native desktop controls.
            let originY = screenFrame.origin.y + screenFrame.size.height - CGFloat(136)
            let origin = CGPoint(x: originX, y: originY)
            let size = CGSize(width: width, height: 22)
            frames[item.index] = CGRect(origin: origin, size: size)
        }
        return frames
    }
}
