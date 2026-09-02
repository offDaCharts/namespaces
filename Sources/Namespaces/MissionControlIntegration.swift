import AppKit
import ApplicationServices
import Foundation
import NamespacesCore

/// A resolved place to draw a custom Space name while Mission Control is open.
struct MissionControlLabelTarget: Equatable {
    enum Source: Equatable { case accessibility, fallback }

    let profile: SpaceProfile
    let frame: CGRect
    let source: Source
}

/// Detects Mission Control independently of how it was invoked. Dock
/// accessibility notifications are immediate for keyboard, gesture, Dock, and
/// Hot Corner activation. A conservative WindowServer scan repairs missed
/// notifications and handles the short period after Accessibility is granted.
@MainActor
final class MissionControlObserver {
    private static let dockNotifications = [
        "AXExposeShowAllWindows",
        "AXExposeShowFrontWindows",
        "AXExposeShowDesktop",
        "AXExposeExit",
    ]

    private var dockElement: AXUIElement?
    private var axObserver: AXObserver?
    private var distributedObservers: [NSObjectProtocol] = []
    private var pollTimer: Timer?
    private var activePollTimer: Timer?
    private var activeSpaceObserver: NSObjectProtocol?
    private var stateChanged: ((Bool) -> Void)?
    private var accessibilityChanged: ((Bool) -> Void)?
    private var lastAccessibilityState = false
    private var activeSince: CFTimeInterval = 0
    private var hasSeenMissionControlWindow = false

    private(set) var isActive = false

    func start(stateChanged: @escaping (Bool) -> Void, accessibilityChanged: @escaping (Bool) -> Void) {
        guard pollTimer == nil else { return }
        self.stateChanged = stateChanged
        self.accessibilityChanged = accessibilityChanged
        lastAccessibilityState = AXIsProcessTrusted()
        accessibilityChanged(lastAccessibilityState)
        installDockObserverIfPossible()
        installDistributedObservers()
        activeSpaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.setActive(false) }
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
        if let pollTimer { RunLoop.main.add(pollTimer, forMode: .common) }
        poll()
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        activePollTimer?.invalidate()
        activePollTimer = nil
        if let activeSpaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activeSpaceObserver)
            self.activeSpaceObserver = nil
        }
        removeDockObserver()
        let center = DistributedNotificationCenter.default()
        distributedObservers.forEach(center.removeObserver)
        distributedObservers.removeAll()
        setActive(false)
        stateChanged = nil
        accessibilityChanged = nil
    }

    private func installDockObserverIfPossible() {
        guard axObserver == nil, AXIsProcessTrusted(),
              let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        else { return }

        let element = AXUIElementCreateApplication(dock.processIdentifier)
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, _, notification, refcon in
            guard let refcon else { return }
            let owner = Unmanaged<MissionControlObserver>.fromOpaque(refcon).takeUnretainedValue()
            let name = notification as String
            Task { @MainActor in owner.handleDockNotification(name) }
        }
        guard AXObserverCreate(dock.processIdentifier, callback, &observer) == .success,
              let observer
        else { return }

        let refcon = Unmanaged.passUnretained(self).toOpaque()
        var installed = false
        for notification in Self.dockNotifications {
            let result = AXObserverAddNotification(observer, element, notification as CFString, refcon)
            installed = installed || result == .success
        }
        guard installed else { return }

        dockElement = element
        axObserver = observer
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }

    private func removeDockObserver() {
        guard let observer = axObserver, let element = dockElement else { return }
        for notification in Self.dockNotifications {
            AXObserverRemoveNotification(observer, element, notification as CFString)
        }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        axObserver = nil
        dockElement = nil
    }

    private func installDistributedObservers() {
        let names = [
            "com.apple.expose.start", "com.apple.expose.stop",
            "com.apple.MissionControl.start", "com.apple.MissionControl.stop",
        ]
        let center = DistributedNotificationCenter.default()
        for name in names {
            distributedObservers.append(center.addObserver(
                forName: Notification.Name(name), object: nil, queue: .main
            ) { [weak self] _ in
                Task { @MainActor in self?.setActive(name.hasSuffix(".start")) }
            })
        }
    }

    private func handleDockNotification(_ notification: String) {
        setActive(notification != "AXExposeExit")
    }

    private func poll() {
        let accessibility = AXIsProcessTrusted()
        if accessibility != lastAccessibilityState {
            lastAccessibilityState = accessibility
            if !accessibility { removeDockObserver() }
            accessibilityChanged?(accessibility)
        }
        if axObserver == nil { installDockObserverIfPossible() }
        let detected = windowServerShowsMissionControl()
        if detected {
            setActive(true)
            hasSeenMissionControlWindow = true
        } else if isActive {
            // Give only the opening animation a grace period. After a real
            // Mission Control window appears, one missing scan is a close.
            let elapsed = CACurrentMediaTime() - activeSince
            if MissionControlLayout.shouldCloseAfterMissingWindow(hasSeenWindow: hasSeenMissionControlWindow, secondsSinceOpen: elapsed) {
                setActive(false)
            }
        }
    }

    private func setActive(_ active: Bool) {
        guard active != isActive else { return }
        isActive = active
        if active {
            activeSince = CACurrentMediaTime()
            hasSeenMissionControlWindow = false
            activePollTimer?.invalidate()
            activePollTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.poll() }
            }
            if let activePollTimer { RunLoop.main.add(activePollTimer, forMode: .common) }
        } else {
            activePollTimer?.invalidate()
            activePollTimer = nil
            hasSeenMissionControlWindow = false
        }
        stateChanged?(active)
    }

    private func windowServerShowsMissionControl() -> Bool {
        guard let windows = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return false }

        var hasOverlay = false
        var hasDockCompanion = false
        for window in windows where (window[kCGWindowOwnerName as String] as? String) == "Dock" {
            let name = window[kCGWindowName as String] as? String ?? ""
            guard name.isEmpty else { continue }
            let layer = window[kCGWindowLayer as String] as? Int ?? 0
            if (18...24).contains(layer), let bounds = window[kCGWindowBounds as String] as? [String: CGFloat] {
                let width = bounds["Width"] ?? 0
                let height = bounds["Height"] ?? 0
                hasOverlay = hasOverlay || NSScreen.screens.contains {
                    width >= $0.frame.width * 0.8 && height >= $0.frame.height * 0.8
                }
            }
            if layer <= 18 { hasDockCompanion = true }
        }
        return hasOverlay && hasDockCompanion
    }
}

/// Reads the Dock's Mission Control accessibility tree and resolves the
/// on-screen bounds of labels such as “Desktop 3”. It intentionally reads only
/// Dock metadata and never captures screenshots or other applications' text.
@MainActor
enum MissionControlLabelLocator {
    private struct Candidate {
        let index: Int
        let cocoaFrame: CGRect
    }

    static func targets(model: AppModel) -> [MissionControlLabelTarget] {
        let pairs = model.nativeSpaces.compactMap { native -> (NativeSpace, SpaceProfile)? in
            guard native.kind == .desktop, let profile = model.profile(for: native) else { return nil }
            return (native, profile)
        }
        guard !pairs.isEmpty else { return [] }

        let candidates = AXIsProcessTrusted() ? accessibilityCandidates() : []
        var claimedCandidates = Set<Int>()
        var resolved: [MissionControlLabelTarget] = []

        for (native, profile) in pairs {
            let screen = screen(for: native) ?? NSScreen.main
            guard let screen, spaceBarIsExpanded(on: screen, candidates: candidates) else { continue }
            let match = candidates.enumerated().filter { offset, candidate in
                !claimedCandidates.contains(offset)
                    && candidate.index == native.index
                    && screen.frame.insetBy(dx: -2, dy: -2).contains(candidate.cocoaFrame.center)
            }.min { candidateScore($0.element.cocoaFrame, screen: screen) < candidateScore($1.element.cocoaFrame, screen: screen) }

            if let match {
                claimedCandidates.insert(match.offset)
                resolved.append(MissionControlLabelTarget(
                    profile: profile,
                    frame: badgeFrame(for: match.element.cocoaFrame, name: profile.name, screen: screen),
                    source: .accessibility
                ))
            }
        }

        // Full-screen app records can create gaps in WindowServer's managed
        // indices even though Mission Control numbers only desktop controls.
        // Resolve any remaining items positionally within their display.
        var resolvedIDs = Set(resolved.map(\.profile.id))
        for screen in NSScreen.screens {
            guard spaceBarIsExpanded(on: screen, candidates: candidates) else { continue }
            let remainingPairs = pairs
                .filter { belongs($0.0, to: screen) && !resolvedIDs.contains($0.1.id) }
                .sorted { $0.0.index < $1.0.index }
            let remainingCandidates = candidates.enumerated()
                .filter { !claimedCandidates.contains($0.offset) && screen.frame.insetBy(dx: -2, dy: -2).contains($0.element.cocoaFrame.center) }
                .sorted { $0.element.cocoaFrame.midX < $1.element.cocoaFrame.midX }
            for (pair, candidate) in zip(remainingPairs, remainingCandidates) {
                claimedCandidates.insert(candidate.offset)
                resolvedIDs.insert(pair.1.id)
                resolved.append(MissionControlLabelTarget(
                    profile: pair.1,
                    frame: badgeFrame(for: candidate.element.cocoaFrame, name: pair.1.name, screen: screen),
                    source: .accessibility
                ))
            }
        }

        // Never mix native anchors with independently centered fallback slots.
        // Tahoe can expose only part of the Dock tree; laying out just those
        // missing Spaces caused the row to shift and overlap. A display is now
        // atomic: use native centers only when every Space resolved, otherwise
        // use the complete, known-good 0.1.0 layout for that display.
        for screen in NSScreen.screens {
            guard spaceBarIsExpanded(on: screen, candidates: candidates) else { continue }
            let screenPairs = pairs.filter { belongs($0.0, to: screen) }
            let screenProfileIDs = Set(screenPairs.map { $0.1.id })
            let resolvedCount = resolved.lazy.filter { screenProfileIDs.contains($0.profile.id) }.count
            guard MissionControlLayout.shouldUseFallback(
                resolvedCount: resolvedCount,
                expectedCount: screenPairs.count
            ) else { continue }
            resolved.removeAll { screenProfileIDs.contains($0.profile.id) }
            resolved.append(contentsOf: fallbackTargets(screenPairs, screen: screen))
        }
        return resolved
    }

    private static func accessibilityCandidates() -> [Candidate] {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return [] }
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        var queue: [(AXUIElement, Int)] = [(root, 0)]
        var cursor = 0
        var candidates: [Candidate] = []

        while cursor < queue.count, cursor < 1_500 {
            let (element, depth) = queue[cursor]
            cursor += 1
            if let index = MissionControlLayout.desktopIndex(in: strings(for: element)),
               let quartzFrame = frame(of: element), quartzFrame.width > 1, quartzFrame.height > 1 {
                let cocoaFrame = cocoaFrame(fromQuartz: quartzFrame)
                if NSScreen.screens.contains(where: { $0.frame.insetBy(dx: -4, dy: -4).intersects(cocoaFrame) }) {
                    candidates.append(Candidate(index: index, cocoaFrame: cocoaFrame))
                }
            }
            guard depth < 12 else { continue }
            if let children: [AXUIElement] = attribute(kAXChildrenAttribute as CFString, of: element) {
                queue.append(contentsOf: children.map { ($0, depth + 1) })
            } else if let visibleChildren: [AXUIElement] = attribute(kAXVisibleChildrenAttribute as CFString, of: element) {
                queue.append(contentsOf: visibleChildren.map { ($0, depth + 1) })
            }
        }

        // The same title may occur on a container and its child. Prefer the
        // compact text/control frame nearest the top and discard near-duplicates.
        candidates.sort {
            if $0.index != $1.index { return $0.index < $1.index }
            if abs($0.cocoaFrame.midY - $1.cocoaFrame.midY) > 2 { return $0.cocoaFrame.midY > $1.cocoaFrame.midY }
            return $0.cocoaFrame.area < $1.cocoaFrame.area
        }
        var unique: [Candidate] = []
        for candidate in candidates where !unique.contains(where: {
            $0.index == candidate.index && hypot($0.cocoaFrame.midX - candidate.cocoaFrame.midX, $0.cocoaFrame.midY - candidate.cocoaFrame.midY) < 8
        }) { unique.append(candidate) }
        return unique
    }

    private static func strings(for element: AXUIElement) -> [String] {
        [kAXTitleAttribute, kAXDescriptionAttribute, kAXValueAttribute, kAXHelpAttribute, kAXIdentifierAttribute, kAXRoleDescriptionAttribute]
            .compactMap { attribute($0 as CFString, of: element) as String? }
    }

    private static func frame(of element: AXUIElement) -> CGRect? {
        guard let positionValue: AXValue = attribute(kAXPositionAttribute as CFString, of: element),
              let sizeValue: AXValue = attribute(kAXSizeAttribute as CFString, of: element)
        else { return nil }
        var position = CGPoint.zero
        var size = CGSize.zero
        guard AXValueGetValue(positionValue, .cgPoint, &position),
              AXValueGetValue(sizeValue, .cgSize, &size)
        else { return nil }
        return CGRect(origin: position, size: size)
    }

    private static func attribute<T>(_ name: CFString, of element: AXUIElement) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name, &value) == .success else { return nil }
        return value as? T
    }

    private static func cocoaFrame(fromQuartz frame: CGRect) -> CGRect {
        let mainHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: frame.minX, y: mainHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    private static func badgeFrame(for anchor: CGRect, name: String, screen: NSScreen?) -> CGRect {
        let desiredWidth = min(190, max(54, CGFloat(name.count) * 6.4 + 18))
        let width = anchor.height > 50 ? min(desiredWidth, max(54, anchor.width - 12)) : desiredWidth
        let height: CGFloat = 22
        var x = anchor.midX - width / 2
        // Compact anchors are Apple's Desktop labels below the previews, so
        // move upward into the preview. Large anchors are preview controls.
        var y = anchor.height > 50 ? anchor.minY + 5 : anchor.maxY + 5
        if let frame = screen?.frame {
            x = min(max(x, frame.minX + 4), frame.maxX - width - 4)
            y = min(max(y, frame.minY + 4), frame.maxY - height - 4)
        }
        return CGRect(x: x.rounded(), y: y.rounded(), width: width, height: height)
    }

    private static func fallbackTargets(_ pairs: [(NativeSpace, SpaceProfile)], screen: NSScreen) -> [MissionControlLabelTarget] {
        let frames = MissionControlLayout.fallbackFrames(
            items: pairs.map { MissionControlLayoutItem(index: $0.0.index, name: $0.1.name) },
            screenFrame: screen.frame
        )
        return pairs.compactMap { pair in
            guard let frame = frames[pair.0.index] else { return nil }
            return MissionControlLabelTarget(
                profile: pair.1,
                frame: frame,
                source: .fallback
            )
        }
    }

    private static func screen(for native: NativeSpace) -> NSScreen? {
        NSScreen.screens.first { belongs(native, to: $0) }
    }

    private static func belongs(_ native: NativeSpace, to screen: NSScreen) -> Bool {
        if NSScreen.screens.count == 1 { return true }
        return native.displayName == screen.localizedName
    }

    private static func distanceFromTop(_ frame: CGRect, screen: NSScreen?) -> CGFloat {
        guard let screen else { return 0 }
        return abs(screen.frame.maxY - frame.maxY)
    }

    private static func candidateScore(_ frame: CGRect, screen: NSScreen?) -> CGFloat {
        let compactPenalty: CGFloat = frame.height <= 44 && frame.width <= 260 ? 0 : 100_000
        return compactPenalty + frame.area + distanceFromTop(frame, screen: screen) * 0.1
    }

    private static func spaceBarIsExpanded(on screen: NSScreen, candidates: [Candidate]) -> Bool {
        let hasExpandedControl = candidates.contains {
            screen.frame.insetBy(dx: -2, dy: -2).contains($0.cocoaFrame.center)
                && $0.cocoaFrame.height > 50
                && $0.cocoaFrame.width > 70
        }
        let pointer = NSEvent.mouseLocation
        let pointerIsAtTop = screen.frame.contains(pointer) && screen.frame.maxY - pointer.y <= 220
        return hasExpandedControl || pointerIsAtTop
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
    var area: CGFloat { width * height }
}
