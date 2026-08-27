import AppKit
import ApplicationServices
import Foundation
import NamespacesCore

/// A resolved place to draw a custom Space name while Mission Control is open.
struct MissionControlLabelTarget: Equatable {
    let profile: SpaceProfile
    let frame: CGRect
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
        let thumbnailFrame: CGRect
    }

    private struct QueueItem {
        let element: AXUIElement
        let depth: Int
        let ancestorFrames: [CGRect]
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
            guard let screen else { continue }
            let match = candidates.enumerated().filter { offset, candidate in
                !claimedCandidates.contains(offset)
                    && candidate.index == native.index
                    && screen.frame.insetBy(dx: -2, dy: -2).contains(candidate.thumbnailFrame.center)
            }.min { candidateScore($0.element.thumbnailFrame, screen: screen) < candidateScore($1.element.thumbnailFrame, screen: screen) }

            if let match, let frame = MissionControlLayout.badgeFrame(in: match.element.thumbnailFrame, screen: screen.frame) {
                claimedCandidates.insert(match.offset)
                resolved.append(MissionControlLabelTarget(
                    profile: profile,
                    frame: frame
                ))
            }
        }

        // Full-screen app records can create gaps in WindowServer's managed
        // indices even though Mission Control numbers only desktop controls.
        // Resolve any remaining items positionally within their display.
        var resolvedIDs = Set(resolved.map(\.profile.id))
        for screen in NSScreen.screens {
            let remainingPairs = pairs
                .filter { belongs($0.0, to: screen) && !resolvedIDs.contains($0.1.id) }
                .sorted { $0.0.index < $1.0.index }
            let remainingCandidates = candidates.enumerated()
                .filter { !claimedCandidates.contains($0.offset) && screen.frame.insetBy(dx: -2, dy: -2).contains($0.element.thumbnailFrame.center) }
                .sorted { $0.element.thumbnailFrame.midX < $1.element.thumbnailFrame.midX }
            for (pair, candidate) in zip(remainingPairs, remainingCandidates) {
                guard let frame = MissionControlLayout.badgeFrame(in: candidate.element.thumbnailFrame, screen: screen.frame) else { continue }
                claimedCandidates.insert(candidate.offset)
                resolvedIDs.insert(pair.1.id)
                resolved.append(MissionControlLabelTarget(
                    profile: pair.1,
                    frame: frame
                ))
            }
        }
        return resolved
    }

    private static func accessibilityCandidates() -> [Candidate] {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return [] }
        let root = AXUIElementCreateApplication(dock.processIdentifier)
        var queue = [QueueItem(element: root, depth: 0, ancestorFrames: [])]
        var cursor = 0
        var candidates: [Candidate] = []

        while cursor < queue.count, cursor < 1_500 {
            let item = queue[cursor]
            cursor += 1
            let ownFrame = frame(of: item.element).map(cocoaFrame(fromQuartz:))
            if let index = MissionControlLayout.desktopIndex(in: strings(for: item.element)) {
                let possibleFrames = [ownFrame].compactMap { $0 } + Array(item.ancestorFrames.reversed())
                if let thumbnail = possibleFrames.first(where: { frame in
                    NSScreen.screens.contains { MissionControlLayout.isExpandedThumbnail(frame, on: $0.frame) }
                }) {
                    candidates.append(Candidate(index: index, thumbnailFrame: thumbnail))
                }
            }
            guard item.depth < 12 else { continue }
            var ancestors = item.ancestorFrames
            if let ownFrame { ancestors.append(ownFrame) }
            if ancestors.count > 8 { ancestors.removeFirst(ancestors.count - 8) }
            if let children: [AXUIElement] = attribute(kAXChildrenAttribute as CFString, of: item.element) {
                queue.append(contentsOf: children.map { QueueItem(element: $0, depth: item.depth + 1, ancestorFrames: ancestors) })
            } else if let visibleChildren: [AXUIElement] = attribute(kAXVisibleChildrenAttribute as CFString, of: item.element) {
                queue.append(contentsOf: visibleChildren.map { QueueItem(element: $0, depth: item.depth + 1, ancestorFrames: ancestors) })
            }
        }

        // The same thumbnail can be represented by a container and multiple
        // descendants. Keep one exact rectangle per native desktop control.
        candidates.sort {
            if $0.index != $1.index { return $0.index < $1.index }
            if abs($0.thumbnailFrame.midY - $1.thumbnailFrame.midY) > 2 { return $0.thumbnailFrame.midY > $1.thumbnailFrame.midY }
            return $0.thumbnailFrame.area < $1.thumbnailFrame.area
        }
        var unique: [Candidate] = []
        for candidate in candidates where !unique.contains(where: {
            $0.index == candidate.index
                && abs($0.thumbnailFrame.minX - candidate.thumbnailFrame.minX) < 3
                && abs($0.thumbnailFrame.minY - candidate.thumbnailFrame.minY) < 3
                && abs($0.thumbnailFrame.width - candidate.thumbnailFrame.width) < 3
                && abs($0.thumbnailFrame.height - candidate.thumbnailFrame.height) < 3
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
        distanceFromTop(frame, screen: screen) + frame.area * 0.0001
    }
}

private extension CGRect {
    var center: CGPoint { CGPoint(x: midX, y: midY) }
    var area: CGFloat { width * height }
}
