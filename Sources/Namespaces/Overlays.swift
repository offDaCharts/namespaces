import AppKit
import ApplicationServices
import NamespacesCore
import SwiftUI

@MainActor
final class OverlayController {
    static let shared = OverlayController()
    private var previewPanels: [NSPanel] = []
    private var missionControlPanels: [UUID: MissionControlLabelPanel] = [:]
    private var hideTask: Task<Void, Never>?
    private var mouseMonitor: Any?
    private var missionControlRefreshTimer: Timer?
    private let missionControlObserver = MissionControlObserver()
    private weak var model: AppModel?

    func configure(model: AppModel) {
        self.model = model
        model.missionControlOverlayStatus = AXIsProcessTrusted()
            ? "Ready — opens automatically with Mission Control"
            : "Accessibility permission is required for thumbnail-aligned labels"
        missionControlObserver.start(
            stateChanged: { [weak self] active in
                guard let self else { return }
                if active { self.beginMissionControlSession() }
                else { self.endMissionControlSession() }
            },
            accessibilityChanged: { [weak self, weak model] trusted in
                guard let self, !self.missionControlObserver.isActive else { return }
                model?.missionControlOverlayStatus = trusted
                    ? "Ready — waiting for Mission Control"
                    : "Accessibility permission is required for thumbnail-aligned labels"
            }
        )
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] _ in Task { @MainActor in self?.handlePointer() } }
        }
    }

    /// Shows a manual preview outside Mission Control. Real Mission Control
    /// labels are managed by the observer and remain visible until it closes.
    func showSpaceLabels(duration: TimeInterval = 2.5) {
        guard let model, model.data.preferences.missionControlLabelsEnabled else { return }
        hidePreview()
        for screen in NSScreen.screens {
            let profiles = model.nativeSpaces
                .filter { $0.displayName == screen.localizedName || NSScreen.screens.count == 1 }
                .compactMap { native in model.profile(for: native) }
            guard !profiles.isEmpty else { continue }
            let view = SpaceStripView(profiles: profiles, activeID: model.activeProfile?.id) { [weak model] profile in model?.switchTo(profile) }
            let panel = NSPanel(contentViewController: NSHostingController(rootView: view))
            panel.styleMask = [.borderless, .nonactivatingPanel]; panel.isOpaque = false; panel.backgroundColor = .clear
            panel.level = .screenSaver; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            let width = min(screen.visibleFrame.width - 40, CGFloat(max(360, profiles.count * 125)))
            panel.setFrame(NSRect(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.maxY - 105, width: width, height: 62), display: true)
            panel.orderFrontRegardless(); previewPanels.append(panel)
        }
        hideTask?.cancel(); hideTask = Task { try? await Task.sleep(for: .seconds(duration)); if !Task.isCancelled { hidePreview() } }
    }

    private func handlePointer() {
        guard let model, model.data.preferences.hoverEnabled, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) else { return }
        let point = NSEvent.mouseLocation
        let activation = NSRect(x: screen.frame.midX - 130, y: screen.frame.maxY - 5, width: 260, height: 8)
        if activation.contains(point) && previewPanels.isEmpty && !missionControlObserver.isActive { showSpaceLabels(duration: 5) }
    }

    private func beginMissionControlSession() {
        guard let model else { return }
        hidePreview()
        guard model.data.preferences.missionControlLabelsEnabled else {
            model.missionControlOverlayStatus = "Disabled in General settings"
            return
        }
        model.refreshSpaces()
        refreshMissionControlLabels()
        missionControlRefreshTimer?.invalidate()
        missionControlRefreshTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshMissionControlLabels() }
        }
        if let missionControlRefreshTimer { RunLoop.main.add(missionControlRefreshTimer, forMode: .common) }
    }

    private func refreshMissionControlLabels() {
        guard missionControlObserver.isActive, let model,
              model.data.preferences.missionControlLabelsEnabled
        else { endMissionControlSession(); return }

        let targets = MissionControlLabelLocator.targets(model: model)
        let targetIDs = Set(targets.map(\.profile.id))
        let staleIDs = missionControlPanels.keys.filter { !targetIDs.contains($0) }
        for id in staleIDs {
            missionControlPanels[id]?.orderOut(nil)
            missionControlPanels.removeValue(forKey: id)
        }
        for target in targets {
            let panel: MissionControlLabelPanel
            if let existing = missionControlPanels[target.profile.id] {
                existing.update(profile: target.profile, activeID: model.activeProfile?.id)
                panel = existing
            } else {
                panel = MissionControlLabelPanel(profile: target.profile, activeID: model.activeProfile?.id)
                missionControlPanels[target.profile.id] = panel
            }
            if panel.frame != target.frame { panel.setFrame(target.frame, display: true) }
            panel.orderFrontRegardless()
        }
        if !targets.isEmpty {
            model.missionControlOverlayStatus = "Active — labels aligned to Mission Control thumbnails"
        } else if AXIsProcessTrusted() {
            model.missionControlOverlayStatus = "Active — waiting for exact thumbnail bounds"
        } else {
            model.missionControlOverlayStatus = "Active — grant Accessibility for exact thumbnail alignment"
        }
    }

    private func endMissionControlSession() {
        missionControlRefreshTimer?.invalidate()
        missionControlRefreshTimer = nil
        missionControlPanels.values.forEach { $0.orderOut(nil) }
        missionControlPanels.removeAll()
        if let model {
            model.missionControlOverlayStatus = !model.data.preferences.missionControlLabelsEnabled
                ? "Disabled in General settings"
                : AXIsProcessTrusted()
                    ? "Ready — waiting for Mission Control"
                    : "Accessibility permission is required for thumbnail-aligned labels"
        }
    }

    private func hidePreview() {
        hideTask?.cancel()
        hideTask = nil
        previewPanels.forEach { $0.orderOut(nil) }
        previewPanels.removeAll()
    }

    func hide() { hidePreview(); endMissionControlSession() }

    func shutdown() {
        hide()
        missionControlObserver.stop()
        if let mouseMonitor { NSEvent.removeMonitor(mouseMonitor); self.mouseMonitor = nil }
    }
}

private struct MissionControlBadgeView: View {
    let profile: SpaceProfile
    let activeID: UUID?

    var body: some View {
        Text(profile.name).lineLimit(1).minimumScaleFactor(0.75)
        .font(.system(size: 12, weight: .semibold, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: profile.colorHex).opacity(profile.id == activeID ? 0.76 : 0.68), in: RoundedRectangle(cornerRadius: 5))
        .overlay { RoundedRectangle(cornerRadius: 5).stroke(.white.opacity(0.14), lineWidth: 0.5) }
        .shadow(color: .black.opacity(0.14), radius: 1, y: 0.5)
    }
}

@MainActor
private final class MissionControlLabelPanel: NSPanel {
    private let hostingView: NSHostingView<MissionControlBadgeView>

    init(profile: SpaceProfile, activeID: UUID?) {
        hostingView = NSHostingView(rootView: MissionControlBadgeView(profile: profile, activeID: activeID))
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        contentView = hostingView
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        ignoresMouseEvents = true
        level = NSWindow.Level(Int(CGWindowLevelForKey(.screenSaverWindow)))
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .stationary]
        isReleasedWhenClosed = false
    }

    func update(profile: SpaceProfile, activeID: UUID?) {
        hostingView.rootView = MissionControlBadgeView(profile: profile, activeID: activeID)
    }
}

private struct SpaceStripView: View {
    let profiles: [SpaceProfile]
    let activeID: UUID?
    let select: (SpaceProfile) -> Void
    var body: some View {
        HStack(spacing: 6) {
            ForEach(profiles) { profile in
                Button { select(profile) } label: {
                    HStack(spacing: 6) { Image(systemName: profile.symbol); Text(profile.name).lineLimit(1) }
                        .font(.system(size: 12, weight: profile.id == activeID ? .bold : .medium))
                        .padding(.horizontal, 10).padding(.vertical, 9)
                        .background(profile.id == activeID ? Color(hex: profile.colorHex).opacity(0.55) : Color.black.opacity(0.38), in: RoundedRectangle(cornerRadius: 9))
                }.buttonStyle(.plain)
            }
        }.padding(8).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14)).shadow(radius: 12)
    }
}

enum FocusedWindowResolver {
    private typealias AXWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    static func windowID() throws -> CGWindowID {
        guard AXIsProcessTrusted() else { throw ResolveError.accessibility }
        guard let app = NSWorkspace.shared.frontmostApplication else { throw ResolveError.noWindow }
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &raw) == .success, let raw else { throw ResolveError.noWindow }
        let window = unsafeDowncast(raw, to: AXUIElement.self)
        var roleValue: CFTypeRef?; var minimizedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXRoleAttribute as CFString, &roleValue) == .success,
              (roleValue as? String) == kAXWindowRole,
              AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
              (minimizedValue as? Bool) != true else { throw ResolveError.noWindow }
        guard let symbol = dlsym(dlopen(nil, RTLD_NOW), "_AXUIElementGetWindow") else { throw ResolveError.unsupported }
        let function = unsafeBitCast(symbol, to: AXWindowFn.self)
        var id: CGWindowID = 0
        guard function(window, &id) == .success, id != 0 else { throw ResolveError.noWindow }
        return id
    }
    enum ResolveError: LocalizedError { case accessibility, noWindow, unsupported
        var errorDescription: String? { switch self { case .accessibility: "Grant Accessibility access before moving windows."; case .noWindow: "The frontmost application does not have a movable standard window."; case .unsupported: "Focused-window identification is unavailable on this macOS build." } }
    }
}

@MainActor
final class DragMoveController {
    static let shared = DragMoveController()
    private weak var model: AppModel?
    private var monitor: Any?
    private var panel: NSPanel?
    private var draggedWindow: CGWindowID?
    private var targets: [SpaceProfile] = []

    func configure(model: AppModel) {
        self.model = model
        guard monitor == nil else { return }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDragged, .leftMouseUp, .flagsChanged]) { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDragged:
            guard event.modifierFlags.contains(.shift) else { if panel != nil { cancel() }; return }
            if panel == nil { begin() }
        case .leftMouseUp:
            if panel != nil { complete(at: NSEvent.mouseLocation) }
        case .flagsChanged:
            if panel != nil, !event.modifierFlags.contains(.shift) { cancel() }
        default: break
        }
    }

    private func begin() {
        guard AXIsProcessTrusted(), let model, model.provider.capabilities.contains(.moveWindow), let id = try? FocusedWindowResolver.windowID() else { return }
        targets = model.profilesInDisplayOrder.filter { $0.id != model.activeProfile?.id }
        guard !targets.isEmpty, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main else { return }
        draggedWindow = id
        let view = DragTargetsView(profiles: targets)
        let panel = NSPanel(contentViewController: NSHostingController(rootView: view))
        panel.styleMask = [.borderless, .nonactivatingPanel]; panel.backgroundColor = .clear; panel.isOpaque = false; panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        let width = min(screen.visibleFrame.width - 40, CGFloat(max(360, targets.count * 125)))
        panel.setFrame(NSRect(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.maxY - 180, width: width, height: 72), display: true)
        panel.orderFrontRegardless(); self.panel = panel
    }

    private func complete(at point: NSPoint) {
        defer { cancel() }
        guard let panel, panel.frame.contains(point), let window = draggedWindow, let model else { return }
        let relative = max(0, min(panel.frame.width - 1, point.x - panel.frame.minX))
        let index = min(targets.count - 1, Int(relative / (panel.frame.width / CGFloat(targets.count))))
        model.moveWindow(window, to: targets[index])
    }

    private func cancel() { panel?.orderOut(nil); panel = nil; draggedWindow = nil; targets = [] }
}

private struct DragTargetsView: View {
    let profiles: [SpaceProfile]
    var body: some View { HStack(spacing: 4) { ForEach(profiles) { profile in VStack(spacing: 5) { Image(systemName: profile.symbol); Text(profile.name).lineLimit(1) }.frame(maxWidth: .infinity).padding(10).background(Color(hex: profile.colorHex).opacity(0.45), in: RoundedRectangle(cornerRadius: 9)) } }.padding(8).background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14)).overlay(alignment: .bottom) { Text("Release over a Space to move · release elsewhere to cancel").font(.caption2).offset(y: 16) } }
}
