import AppKit
import Combine
import NamespacesCore
import Sparkle
import SwiftUI

@MainActor
final class WindowCoordinator {
    static let shared = WindowCoordinator()
    private var settingsWindow: NSWindow?
    private var switcherPanel: NSPanel?
    private var onboardingWindow: NSWindow?
    private var noteWindows: [UUID: NSWindow] = [:]

    func showSettings(model: AppModel) {
        if let settingsWindow { settingsWindow.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }
        let view = SettingsView().environmentObject(model)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "DeskOrbit Settings"; window.setContentSize(NSSize(width: 900, height: 650)); window.minSize = NSSize(width: 760, height: 520)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]; window.center(); window.isReleasedWhenClosed = false
        settingsWindow = window; window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    func showOnboarding(model: AppModel) {
        if let onboardingWindow { onboardingWindow.makeKeyAndOrderFront(nil); return }
        let view = OnboardingView { [weak self] in self?.onboardingWindow?.close(); self?.onboardingWindow = nil; self?.showSettings(model: model) }.environmentObject(model)
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Welcome to DeskOrbit"; window.styleMask = [.titled, .closable]; window.setContentSize(NSSize(width: 720, height: 520)); window.center(); window.isReleasedWhenClosed = false
        onboardingWindow = window; window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    func showSwitcher(model: AppModel) {
        let interval = Metrics.signposter.beginInterval("Quick Switcher open")
        defer { Metrics.signposter.endInterval("Quick Switcher open", interval) }
        if let panel = switcherPanel, panel.isVisible { panel.orderOut(nil); return }
        let view = QuickSwitcherView(onClose: { [weak self] in self?.switcherPanel?.orderOut(nil) }).environmentObject(model)
        let panel = switcherPanel ?? NSPanel(contentViewController: NSHostingController(rootView: view))
        panel.styleMask = [.titled, .fullSizeContentView, .nonactivatingPanel]; panel.titleVisibility = .hidden; panel.titlebarAppearsTransparent = true
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.contentView?.wantsLayer = true; panel.contentView?.layer?.cornerRadius = 14; panel.contentView?.layer?.masksToBounds = true
        panel.isFloatingPanel = true; panel.level = .popUpMenu; panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.setContentSize(NSSize(width: 380, height: 410)); panel.isReleasedWhenClosed = false
        let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame { panel.setFrameOrigin(NSPoint(x: frame.midX - 190, y: frame.midY - 170)) }
        switcherPanel = panel; panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    }

    func showNote(_ note: SpaceNote, model: AppModel) {
        if let window = noteWindows[note.id] { window.makeKeyAndOrderFront(nil); return }
        let view = NoteEditorView(noteID: note.id).environmentObject(model)
        let panel = NSPanel(contentViewController: NSHostingController(rootView: view))
        panel.title = note.title; panel.styleMask = [.titled, .closable, .resizable, .utilityWindow]; panel.level = .floating
        panel.collectionBehavior = [.fullScreenAuxiliary]; panel.setContentSize(NSSize(width: 330, height: 340)); panel.isReleasedWhenClosed = false
        panel.center(); noteWindows[note.id] = panel; panel.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        if let profile = model.data.spaces.first(where: { $0.id == note.spaceID }), let native = model.native(for: profile), model.provider.capabilities.contains(.moveWindow) {
            try? model.provider.moveWindow(CGWindowID(panel.windowNumber), to: native)
        }
    }

    func hideAllNotes() { noteWindows.values.forEach { $0.orderOut(nil) } }
    func restoreReachableWindows() {
        let visible = NSScreen.screens.map(\.visibleFrame)
        for window in ([settingsWindow, switcherPanel, onboardingWindow].compactMap { $0 } + Array(noteWindows.values)) where !visible.contains(where: { $0.intersects(window.frame) }) {
            guard let frame = NSScreen.main?.visibleFrame else { continue }
            let origin = NSPoint(x: min(max(frame.minX, window.frame.minX), frame.maxX - min(window.frame.width, frame.width)), y: min(max(frame.minY, window.frame.minY), frame.maxY - min(window.frame.height, frame.height)))
            window.setFrameOrigin(origin)
        }
    }
    func toggleDock(noteID: UUID) {
        guard let window = noteWindows[noteID], let screen = window.screen ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        let docked = abs(window.frame.maxX - frame.maxX) < 4
        if docked { window.setFrameOrigin(NSPoint(x: frame.midX - window.frame.width / 2, y: frame.midY - window.frame.height / 2)) }
        else { window.setFrameOrigin(NSPoint(x: frame.maxX - window.frame.width, y: frame.midY - window.frame.height / 2)) }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    // Keep optional integrations out of pre-window initialization. This is
    // especially important on a new macOS major release where private Spaces
    // APIs or an updater helper can otherwise fail before any UI is presented.
    lazy var model = AppModel()
    private lazy var updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)
    private var statusItem: NSStatusItem!
    private var cancellables: Set<AnyCancellable> = []
    private var screenObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        LaunchDiagnostics.record("applicationDidFinishLaunching")
        let defaults = UserDefaults.standard
        let completedOnboarding = defaults.bool(forKey: "didCompleteOnboarding")
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let shouldPresentUpdatedApp = completedOnboarding
            && defaults.string(forKey: "DeskOrbit.lastPresentedVersion") != currentVersion
        let isTahoeCompatibilityMode = RuntimeCompatibility.requiresTahoeCompatibilityMode()
        let needsVisibleLaunch = isTahoeCompatibilityMode || !completedOnboarding || shouldPresentUpdatedApp || !model.license.hasAccess
        NSApp.setActivationPolicy(needsVisibleLaunch ? .regular : .accessory)
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = NSMenu(); statusItem.menu?.delegate = self
        Publishers.CombineLatest(model.$data, model.$nativeSpaces).sink { [weak self] _, _ in self?.updateStatusLabel() }.store(in: &cancellables)
        model.$presentationRevision.dropFirst().sink { [weak self] _ in self?.updateStatusLabel() }.store(in: &cancellables)
        model.$hotkeyRevision.dropFirst().sink { [weak self] _ in self?.configureHotKeys() }.store(in: &cancellables)
        configureHotKeys(); updateStatusLabel()
        OverlayController.shared.configure(model: model)
        DragMoveController.shared.configure(model: model)
        screenObserver = NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in try? await Task.sleep(for: .milliseconds(500)); OverlayController.shared.hide(); WindowCoordinator.shared.restoreReachableWindows(); self?.model.refreshSpaces() }
        }
        // Present first; initialize the updater only after DeskOrbit has an
        // operational menu item/window. A failed optional service must never
        // make a menu-bar app look like it did not launch.
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if isTahoeCompatibilityMode {
                defaults.set(currentVersion, forKey: "DeskOrbit.lastPresentedVersion")
                WindowCoordinator.shared.showSettings(model: self.model)
            } else if !completedOnboarding {
                defaults.set(currentVersion, forKey: "DeskOrbit.lastPresentedVersion")
                WindowCoordinator.shared.showOnboarding(model: self.model)
            } else if shouldPresentUpdatedApp {
                defaults.set(currentVersion, forKey: "DeskOrbit.lastPresentedVersion")
                WindowCoordinator.shared.showSettings(model: self.model)
            } else if !self.model.license.hasAccess {
                WindowCoordinator.shared.showSettings(model: self.model)
            }
            LaunchDiagnostics.record("primary UI presentation completed")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
                _ = self?.updaterController
                LaunchDiagnostics.record("updater initialized")
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { WindowCoordinator.shared.showSettings(model: model) }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.closeOpenSegment(classification: .active); OverlayController.shared.shutdown(); WindowCoordinator.shared.hideAllNotes(); HotKeyCenter.shared.unregisterAll()
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "deskorbit" || url.scheme == "namespaces" {
            switch url.host {
            case "settings": WindowCoordinator.shared.showSettings(model: model)
            case "switcher": WindowCoordinator.shared.showSwitcher(model: model)
            case "refresh": model.refreshSpaces()
            case "jump-back": model.jumpBack()
            case "labels": OverlayController.shared.showSpaceLabels(duration: 10)
            default: break
            }
        }
    }

    private func updateStatusLabel() {
        guard let button = statusItem.button else { return }
        let profile = model.activeProfile; let mode = model.data.preferences.menuLabelMode
        button.image = switch mode { case .name, .number: nil; case .colorAndName: colorDot(profile?.colorHex ?? "#7C5CFC"); default: NSImage(systemSymbolName: profile?.symbol ?? "square.grid.2x2", accessibilityDescription: "DeskOrbit") }
        button.title = switch mode {
        case .icon: ""
        case .number: model.activeNativeSpace.map { "\($0.index)" } ?? ""
        default: model.currentName == "DeskOrbit" && mode != .name ? "" : model.currentName
        }
        button.toolTip = "DeskOrbit — \(model.currentName)"
    }

    private func colorDot(_ hex: String) -> NSImage {
        let image = NSImage(size: NSSize(width: 12, height: 12)); image.lockFocus()
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x7C5CFC
        NSColor(red: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: 1).setFill()
        NSBezierPath(ovalIn: NSRect(x: 2, y: 2, width: 8, height: 8)).fill(); image.unlockFocus(); image.isTemplate = false; return image
    }

    func menuWillOpen(_ menu: NSMenu) { rebuildMenu(menu) }
    private func rebuildMenu(_ menu: NSMenu) {
        let interval = Metrics.signposter.beginInterval("Menu rebuild")
        defer { Metrics.signposter.endInterval("Menu rebuild", interval) }
        menu.removeAllItems()
        if let active = model.activeProfile, let native = model.native(for: active) {
            let header = NSMenuItem(title: active.name, action: #selector(openActiveNote), keyEquivalent: "")
            header.image = numberedColorTile(number: native.index, hex: active.colorHex, size: 18)
            header.target = self; header.toolTip = "Open the current Space note"; menu.addItem(header)
        }
        menu.addItem(.separator())
        var lastDisplay: String?
        for native in model.nativeSpaces {
            if native.displayID != lastDisplay { let heading = NSMenuItem(title: native.displayName, action: nil, keyEquivalent: ""); heading.isEnabled = false; menu.addItem(heading); lastDisplay = native.displayID }
            guard let profile = model.profile(for: native) else { continue }
            let item = NSMenuItem(title: profile.name, action: #selector(selectSpace(_:)), keyEquivalent: native.index < 10 ? String(native.index) : "")
            item.target = self; item.representedObject = profile.id.uuidString; item.state = native.isActive ? .on : .off
            item.image = numberedColorTile(number: native.index, hex: profile.colorHex, size: 18)
            item.toolTip = "\(native.displayName) · Desktop \(native.index)"; menu.addItem(item)
        }
        menu.addItem(.separator())
        let quick = NSMenuItem(title: "Quick Switcher…", action: #selector(showSwitcher), keyEquivalent: " "); quick.keyEquivalentModifierMask = [.option]; quick.target = self; menu.addItem(quick)
        let back = NSMenuItem(title: "Jump Back", action: #selector(jumpBack), keyEquivalent: " "); back.keyEquivalentModifierMask = [.option, .shift]; back.target = self; menu.addItem(back)
        if model.provider.capabilities.contains(.moveWindow) {
            let moveParent = NSMenuItem(title: "Move Frontmost Window", action: nil, keyEquivalent: "")
            let moveMenu = NSMenu()
            for profile in model.profilesInDisplayOrder where profile.id != model.activeProfile?.id { let item = NSMenuItem(title: profile.name, action: #selector(moveWindow(_:)), keyEquivalent: ""); item.target = self; item.representedObject = profile.id.uuidString; if let native = model.native(for: profile) { item.image = numberedColorTile(number: native.index, hex: profile.colorHex, size: 16) }; moveMenu.addItem(item) }
            moveParent.submenu = moveMenu; menu.addItem(moveParent)
            if model.canUndoWindowMove { let undo = NSMenuItem(title: "Undo Last Window Move", action: #selector(undoWindowMove), keyEquivalent: "z"); undo.target = self; menu.addItem(undo) }
        }
        let labels = NSMenuItem(title: "Show Space Labels", action: #selector(showLabels), keyEquivalent: "l"); labels.target = self; menu.addItem(labels)
        if let active = model.activeProfile {
            let notes = model.data.notes.filter { $0.spaceID == active.id && !$0.isArchived }
            let noteParent = NSMenuItem(title: "Notes (\(notes.count))", action: nil, keyEquivalent: "")
            let noteMenu = NSMenu(); for note in notes { let item = NSMenuItem(title: note.title, action: #selector(openNote(_:)), keyEquivalent: ""); item.target = self; item.representedObject = note.id.uuidString; noteMenu.addItem(item) }
            let newNote = NSMenuItem(title: "New Note", action: #selector(newActiveNote), keyEquivalent: "n"); newNote.target = self; noteMenu.addItem(newNote); noteParent.submenu = noteMenu; menu.addItem(noteParent)
            let automations = model.data.automations.filter { $0.spaceID == active.id && $0.isEnabled }
            if !automations.isEmpty { let parent = NSMenuItem(title: "Run Automation", action: nil, keyEquivalent: ""); let submenu = NSMenu(); for group in automations { let item = NSMenuItem(title: group.name, action: #selector(runAutomation(_:)), keyEquivalent: ""); item.target = self; item.representedObject = group.id.uuidString; submenu.addItem(item) }; parent.submenu = submenu; menu.addItem(parent) }
        }
        let trackingState = !model.data.preferences.trackingEnabled ? "Disabled" : model.data.preferences.trackingPaused ? "Paused" : "Recording locally"
        let tracking = NSMenuItem(title: "Time Tracking: \(trackingState)", action: #selector(toggleTrackingPause), keyEquivalent: ""); tracking.target = self; menu.addItem(tracking)
        menu.addItem(.separator())
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ","); settings.target = self; menu.addItem(settings)
        let capabilities = NSMenuItem(title: "Capabilities & Permissions…", action: #selector(showSettings), keyEquivalent: ""); capabilities.target = self; menu.addItem(capabilities)
        let refresh = NSMenuItem(title: "Refresh Spaces", action: #selector(refresh), keyEquivalent: "r"); refresh.target = self; menu.addItem(refresh)
        let help = NSMenuItem(title: "Help & Privacy…", action: #selector(showHelp), keyEquivalent: "?"); help.target = self; menu.addItem(help)
        let updates = NSMenuItem(title: "Check for Updates…", action: #selector(checkUpdates), keyEquivalent: ""); updates.target = self; menu.addItem(updates)
        let license = NSMenuItem(title: "License: \(model.license.statusTitle)", action: #selector(showSettings), keyEquivalent: ""); license.target = self; menu.addItem(license)
        menu.addItem(.separator()); let quit = NSMenuItem(title: "Quit DeskOrbit", action: #selector(quit), keyEquivalent: "q"); quit.target = self; menu.addItem(quit)
    }

    private func numberedColorTile(number: Int, hex: String, size: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x7C5CFC
            let color = NSColor(red: CGFloat((value >> 16) & 0xff) / 255, green: CGFloat((value >> 8) & 0xff) / 255, blue: CGFloat(value & 0xff) / 255, alpha: 0.88)
            color.setFill(); NSBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), xRadius: 4, yRadius: 4).fill()
            let text = "\(number)" as NSString
            let font = NSFont.monospacedDigitSystemFont(ofSize: max(8, size * 0.52), weight: .semibold)
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
            let textSize = text.size(withAttributes: attributes)
            text.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2), withAttributes: attributes)
            return true
        }
        image.isTemplate = false
        return image
    }

    private func configureHotKeys() {
        HotKeyCenter.shared.unregisterAll()
        model.hotkeyFailures = []
        guard model.data.preferences.globalShortcutsEnabled else { return }
        let quick = model.data.preferences.quickSwitcherShortcut
        if HotKeyCenter.shared.register(quick, action: { [weak self] in if let self { WindowCoordinator.shared.showSwitcher(model: self.model) } }) == nil { model.hotkeyFailures.append("Quick Switcher (\(quick.display))") }
        let back = model.data.preferences.jumpBackShortcut
        if HotKeyCenter.shared.register(back, action: { [weak self] in self?.model.jumpBack() }) == nil { model.hotkeyFailures.append("Jump Back (\(back.display))") }
        for profile in model.data.spaces { if let shortcut = profile.shortcut, HotKeyCenter.shared.register(shortcut, action: { [weak self] in self?.model.switchTo(profile) }) == nil { model.hotkeyFailures.append("\(profile.name) (\(shortcut.display))") } }
    }

    @objc private func selectSpace(_ sender: NSMenuItem) { guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw), let profile = model.data.spaces.first(where: { $0.id == id }) else { return }; model.switchTo(profile) }
    @objc private func runAutomation(_ sender: NSMenuItem) { guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw), let group = model.data.automations.first(where: { $0.id == id }) else { return }; model.runAutomation(group) }
    @objc private func moveWindow(_ sender: NSMenuItem) { guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw), let profile = model.data.spaces.first(where: { $0.id == id }) else { return }; model.moveFrontmostWindow(to: profile) }
    @objc private func undoWindowMove() { model.undoWindowMove() }
    @objc private func openActiveNote() { guard let active = model.activeProfile else { return }; let note = model.data.notes.first(where: { $0.spaceID == active.id && !$0.isArchived }) ?? model.addNote(spaceID: active.id, kind: .text); WindowCoordinator.shared.showNote(note, model: model) }
    @objc private func openNote(_ sender: NSMenuItem) { guard let raw = sender.representedObject as? String, let id = UUID(uuidString: raw), let note = model.data.notes.first(where: { $0.id == id }) else { return }; WindowCoordinator.shared.showNote(note, model: model) }
    @objc private func newActiveNote() { guard let active = model.activeProfile else { return }; WindowCoordinator.shared.showNote(model.addNote(spaceID: active.id, kind: .text), model: model) }
    @objc private func toggleTrackingPause() { var prefs = model.data.preferences; prefs.trackingPaused.toggle(); model.updatePreferences(prefs); model.trackingTick(forceBoundary: true) }
    @objc private func showHelp() { let alert = NSAlert(); alert.messageText = "DeskOrbit Help & Privacy"; alert.informativeText = "Use ⌥Space to switch by name and ⌥⇧Space to jump back. Hold Shift while dragging a standard window to reveal move targets after granting Accessibility. Data stays in ~/Library/Application Support/Namespaces and is never uploaded."; alert.addButton(withTitle: "OK"); alert.runModal() }
    @objc private func checkUpdates() { updaterController.checkForUpdates(nil) }
    @objc private func showSwitcher() { WindowCoordinator.shared.showSwitcher(model: model) }
    @objc private func jumpBack() { model.jumpBack() }
    @objc private func showLabels() { OverlayController.shared.showSpaceLabels() }
    @objc private func showSettings() { WindowCoordinator.shared.showSettings(model: model) }
    @objc private func refresh() { model.refreshSpaces() }
    @objc private func quit() { model.closeOpenSegment(classification: .active); NSApp.terminate(nil) }
}

@main
enum NamespacesMain {
    @MainActor
    static func main() {
        LaunchDiagnostics.record("process entered main")
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
    }
}

private enum LaunchDiagnostics {
    static func record(_ message: String) {
        let manager = FileManager.default
        guard let library = manager.urls(for: .libraryDirectory, in: .userDomainMask).first else { return }
        let directory = library.appendingPathComponent("Logs/DeskOrbit", isDirectory: true)
        let file = directory.appendingPathComponent("launch.log")
        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: .now)) \(message)\n"
        do {
            try manager.createDirectory(at: directory, withIntermediateDirectories: true)
            if manager.fileExists(atPath: file.path), let handle = try? FileHandle(forWritingTo: file) {
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Data(line.utf8))
            } else {
                try Data(line.utf8).write(to: file, options: .atomic)
            }
        } catch {
            // Diagnostics are best-effort and must never affect launch.
        }
    }
}
