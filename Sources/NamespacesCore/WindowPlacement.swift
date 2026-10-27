import Foundation
import CoreGraphics

public enum WindowPlacement {
    /// Clamp the entire window, including the title bar, to the available area.
    /// A one-pixel overlap is not sufficient to call a window reachable.
    public static func fit(_ window: CGRect, in visibleFrame: CGRect) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: 8, dy: 8)
        let width = min(window.width, max(1, bounds.width))
        let height = min(window.height, max(1, bounds.height))
        return CGRect(x: min(max(bounds.minX, window.minX), bounds.maxX - width),
                      y: min(max(bounds.minY, window.minY), bounds.maxY - height), width: width, height: height)
    }
}
