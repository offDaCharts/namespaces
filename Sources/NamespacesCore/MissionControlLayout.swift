import CoreGraphics
import Foundation

/// Pure geometry/parsing rules used by the Mission Control integration.
///
/// Namespaces never invents Mission Control positions. The app supplies frames
/// read from the Dock accessibility hierarchy and this type only validates a
/// frame and derives a badge that remains centered inside that thumbnail.
public enum MissionControlLayout {
    public static let badgeHeight: CGFloat = 22
    public static let horizontalInset: CGFloat = 6
    public static let bottomInset: CGFloat = 5

    public static func shouldCloseAfterMissingWindow(hasSeenWindow: Bool, secondsSinceOpen: TimeInterval) -> Bool {
        hasSeenWindow || secondsSinceOpen >= 0.7
    }

    /// Tahoe exposes Mission Control as a non-shareable, display-sized Dock
    /// window at layer 18. Older releases have used nearby overlay layers, so
    /// accept the narrow known range while still requiring display-sized bounds.
    public static func isMissionControlDockWindow(
        layer: Int,
        sharingState: Int?,
        size: CGSize,
        screenSizes: [CGSize]
    ) -> Bool {
        guard (18...24).contains(layer), sharingState != 1 else { return false }
        return screenSizes.contains { screen in
            size.width >= screen.width * 0.80
                && size.height >= screen.height * 0.80
                && size.width <= screen.width * 1.20
                && size.height <= screen.height * 1.20
        }
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

    /// Rejects compact native labels, full-width Space-bar containers, and
    /// ordinary windows. An accepted frame must look like an expanded desktop
    /// thumbnail in the upper Mission Control band of its display.
    public static func isExpandedThumbnail(_ frame: CGRect, on screen: CGRect) -> Bool {
        guard frame.width >= 70, frame.height >= 50,
              frame.width <= screen.width * 0.60,
              frame.height <= screen.height * 0.34,
              frame.midX >= screen.minX - 2, frame.midX <= screen.maxX + 2
        else { return false }

        let distanceFromTop = screen.maxY - frame.maxY
        let upperBandDepth = min(CGFloat(360), screen.height * 0.40)
        return distanceFromTop >= -8
            && distanceFromTop <= upperBandDepth
            && frame.minY >= screen.maxY - upperBandDepth - 40
    }

    /// Matches SpaceJump's demonstrated treatment: a restrained, nearly
    /// full-width badge inset into the bottom of the real thumbnail.
    public static func badgeFrame(in thumbnail: CGRect, screen: CGRect) -> CGRect? {
        guard isExpandedThumbnail(thumbnail, on: screen) else { return nil }
        let width = thumbnail.width - horizontalInset * 2
        guard width >= 54 else { return nil }
        let result = CGRect(
            x: thumbnail.minX + horizontalInset,
            y: thumbnail.minY + bottomInset,
            width: width,
            height: badgeHeight
        ).integral
        return screen.insetBy(dx: 2, dy: 2).contains(result) ? result : nil
    }
}
