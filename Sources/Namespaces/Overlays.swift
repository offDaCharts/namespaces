import AppKit
import ApplicationServices
import NamespacesCore
import SwiftUI

@MainActor
final class OverlayController {
    static let shared = OverlayController()
    private var panels: [NSPanel] = []
    private var hideTask: Task<Void, Never>?
    private var keyMonitor: Any?
    private var mouseMonitor: Any?
    private weak var model: AppModel?

    func configure(model: AppModel) {
        self.model = model
        if keyMonitor == nil {
            keyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                let missionControlKey = event.keyCode == 99 || (event.keyCode == 126 && event.modifierFlags.contains(.control))
                if missionControlKey { Task { @MainActor in try? await Task.sleep(for: .milliseconds(280)); self?.showSpaceLabels(duration: 3) } }
            }
        }
        if mouseMonitor == nil {
            mouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown]) { [weak self] _ in Task { @MainActor in self?.handlePointer() } }
        }
    }

    func showSpaceLabels(duration: TimeInterval = 2.5) {
        guard let model, model.data.preferences.missionControlLabelsEnabled else { return }
        hide()
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
            panel.orderFrontRegardless(); panels.append(panel)
        }
        hideTask?.cancel(); hideTask = Task { try? await Task.sleep(for: .seconds(duration)); if !Task.isCancelled { hide() } }
    }

    private func handlePointer() {
        guard let model, model.data.preferences.hoverEnabled, let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) else { return }
        let point = NSEvent.mouseLocation
        let activation = NSRect(x: screen.frame.midX - 130, y: screen.frame.maxY - 5, width: 260, height: 8)
        if activation.contains(point) && panels.isEmpty { showSpaceLabels(duration: 5) }
    }

    func hide() { hideTask?.cancel(); hideTask = nil; panels.forEach { $0.orderOut(nil) }; panels.removeAll() }
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
