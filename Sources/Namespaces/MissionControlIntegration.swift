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

/// Resolves custom labels with the immutable v0.1.0 per-display geometry.
@MainActor
enum MissionControlLabelLocator {
    static func targets(model: AppModel) -> [MissionControlLabelTarget] {
        let pairs = model.nativeSpaces.compactMap { native -> (NativeSpace, SpaceProfile)? in
            guard native.kind == .desktop, let profile = model.profile(for: native) else { return nil }
            return (native, profile)
        }
        guard !pairs.isEmpty else { return [] }
        // Placement is deliberately frozen to the exact v0.1.0 equal-slot
        // algorithm. Tahoe's undocumented Dock AX geometry proved unstable even
        // when it appeared complete, so it must never override these frames.
        var resolved: [MissionControlLabelTarget] = []
        for screen in NSScreen.screens {
            let screenPairs = pairs.filter { belongs($0.0, to: screen) }
            resolved.append(contentsOf: fallbackTargets(screenPairs, screen: screen))
        }
        return resolved
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
                frame: frame
            )
        }
    }

    private static func belongs(_ native: NativeSpace, to screen: NSScreen) -> Bool {
        if NSScreen.screens.count == 1 { return true }
        return native.displayName == screen.localizedName
    }

}
