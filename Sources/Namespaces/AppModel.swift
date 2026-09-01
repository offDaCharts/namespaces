import AppKit
import Combine
import Foundation
import NamespacesCore
import ServiceManagement

@MainActor
final class AppModel: ObservableObject {
    @Published var data = AppData()
    @Published var nativeSpaces: [NativeSpace] = []
    @Published var providerName = "Initializing"
    @Published var capabilityMessage = "Scanning macOS Spaces…"
    @Published var lastError: String?
    @Published var automationResults: [AutomationActionResult] = []
    @Published var isAutomationRunning = false
    @Published var presentationRevision = 0
    @Published var hotkeyRevision = 0
    @Published var providerCircuitOpen = false
    @Published var hotkeyFailures: [String] = []
    @Published var missionControlOverlayStatus = "Initializing Mission Control integration…"

    let store = DataStore()
    let license = LicenseController()
    private(set) var provider: SpaceProviding = FallbackSpaceProvider()
    private let runner = AutomationRunner()
    private var observers: [NSObjectProtocol] = []
    private var trackingTimer: Timer?
    private var saveTask: Task<Void, Never>?
    private var lastTrackedSpace: UUID?
    private var wasIdle = false
    private var currentSegmentID: UUID?
    private var lastHeartbeatSave = Date.distantPast
    private var providerFailureCount = 0
    private var lastObservedActiveID: UUID?
    private var lastWindowMove: (windowID: CGWindowID, source: UUID)?
    private var licenseObserver: AnyCancellable?
    var canUndoWindowMove: Bool { lastWindowMove != nil }

    var activeNativeSpace: NativeSpace? { nativeSpaces.first(where: \.isActive) }
    var activeProfile: SpaceProfile? { guard let native = activeNativeSpace else { return nil }; return profile(for: native) }
    var currentName: String { activeProfile?.name ?? activeNativeSpace.map { "Desktop \($0.index)" } ?? "DeskOrbit" }
    // Keep these as explicit closures rather than unapplied instance-method
    // references. Swift 6.0/6.1 can otherwise select a typed-throws overload of
    // compactMap even though profile(for:) is non-throwing.
    var profilesInDisplayOrder: [SpaceProfile] { nativeSpaces.compactMap { native in profile(for: native) } }

    init() {
        licenseObserver = license.objectWillChange.sink { [weak self] in self?.objectWillChange.send() }
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refreshSpaces() } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.trackingTick(forceBoundary: true) } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.closeOpenSegment(classification: .active) } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refreshSpaces(); self?.trackingTick(forceBoundary: true) } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in
            self?.closeOpenSegment(classification: .active)
            OverlayController.shared.hide()
            WindowCoordinator.shared.hideAllNotes()
        } })
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in Task { @MainActor in self?.refreshSpaces(); self?.trackingTick(forceBoundary: true) } })
        Task { await bootstrap() }
    }

    private func bootstrap() async {
        do { data = try await store.load() } catch { lastError = "Could not load local data: \(error.localizedDescription)" }
        selectProvider(); refreshSpaces(); registerTrackingTimer()
    }

    func selectProvider() {
        provider = FallbackSpaceProvider(); providerCircuitOpen = false; providerFailureCount = 0
        if data.preferences.enhancedIntegrationEnabled {
            let enhanced = EnhancedSpaceProvider()
            if enhanced.capabilities.contains(.enumerate), (try? enhanced.spaces().isEmpty) == false { provider = enhanced }
        }
        providerName = provider.name
        capabilityMessage = provider.capabilities.contains(.enumerate) ? "Enhanced discovery is active. Mission Control integration is experimental." : "Fallback mode: existing saved Spaces remain available, but native discovery is unavailable."
    }

    func refreshSpaces() {
        let interval = Metrics.signposter.beginInterval("Topology refresh")
        defer { Metrics.signposter.endInterval("Topology refresh", interval) }
        do {
            let discovered = try provider.spaces()
            nativeSpaces = discovered
            providerFailureCount = 0
            reconcile(discovered)
            if let active = activeProfile?.id, active != lastObservedActiveID { lastObservedActiveID = active; recordRecent(active) }
            trackingTick(forceBoundary: false)
        } catch {
            if provider is EnhancedSpaceProvider {
                providerFailureCount += 1
                if providerFailureCount >= 3 {
                    providerCircuitOpen = true; provider = FallbackSpaceProvider(); providerName = provider.name
                    capabilityMessage = "Enhanced integration failed repeatedly and was disabled for this run. Retry from Capabilities after checking macOS compatibility."
                }
            }
            if nativeSpaces.isEmpty { lastError = error.localizedDescription }
        }
    }

    func retryEnhancedProvider() { selectProvider(); refreshSpaces() }

    private func reconcile(_ discovered: [NativeSpace]) {
        var changed = false
        for native in discovered {
            if let index = data.spaces.firstIndex(where: { $0.nativeID == native.id && $0.displayID == native.displayID }) {
                if data.spaces[index].lastKnownIndex != native.index || data.spaces[index].lastKnownKind != native.kind {
                    data.spaces[index].lastKnownIndex = native.index; data.spaces[index].lastKnownKind = native.kind; changed = true
                }
            }
        }
        for native in discovered where profile(for: native) == nil {
            // Never guess across native-ID churn. Keeping an old record unmatched is
            // safer than attaching notes or tracked time to the wrong desktop.
            data.spaces.append(SpaceProfile(nativeID: native.id, displayID: native.displayID, lastKnownIndex: native.index, lastKnownKind: native.kind, name: native.kind == .fullscreen ? "Fullscreen \(native.index)" : "Desktop \(native.index)"))
            changed = true
        }
        if changed { scheduleSave() }
    }

    func linkUnmatchedProfile(_ profileID: UUID, to native: NativeSpace) {
        guard let oldIndex = data.spaces.firstIndex(where: { $0.id == profileID }), let generated = profile(for: native), generated.id != profileID else { return }
        let targetHasContent = data.notes.contains(where: { $0.spaceID == generated.id }) || data.automations.contains(where: { $0.spaceID == generated.id }) || data.segments.contains(where: { $0.spaceID == generated.id })
        guard !targetHasContent else { lastError = "The current target already has notes, automations, or tracked time. Export a backup and resolve the records manually rather than merging silently."; return }
        data.spaces.removeAll { $0.id == generated.id }
        guard let newIndex = data.spaces.firstIndex(where: { $0.id == profileID }) else { return }
        data.spaces[newIndex].nativeID = native.id; data.spaces[newIndex].displayID = native.displayID; data.spaces[newIndex].lastKnownIndex = native.index; data.spaces[newIndex].lastKnownKind = native.kind; data.spaces[newIndex].updatedAt = .now
        scheduleSave(); objectWillChange.send(); presentationRevision += 1
        _ = oldIndex
    }

    func profile(for native: NativeSpace) -> SpaceProfile? { data.spaces.first { $0.nativeID == native.id && $0.displayID == native.displayID } }
    func native(for profile: SpaceProfile) -> NativeSpace? { nativeSpaces.first { $0.id == profile.nativeID && $0.displayID == profile.displayID } }

    func updateProfile(_ profile: SpaceProfile) {
        guard let index = data.spaces.firstIndex(where: { $0.id == profile.id }) else { return }
        let shortcutChanged = data.spaces[index].shortcut != profile.shortcut
        var value = profile; value.updatedAt = .now; data.spaces[index] = value; scheduleSave(); objectWillChange.send(); presentationRevision += 1
        if shortcutChanged { hotkeyRevision += 1 }
    }

    func switchTo(_ profile: SpaceProfile) {
        guard requireLicense() else { return }
        guard let native = native(for: profile) else { lastError = "This Space is not currently available."; return }
        do {
            try provider.switchTo(native)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in self?.refreshSpaces() }
        } catch { lastError = error.localizedDescription }
    }

    func jumpBack() {
        guard let active = activeProfile?.id, let prior = data.recentSpaceIDs.first(where: { $0 != active }), let profile = data.spaces.first(where: { $0.id == prior }) else { lastError = "There is no previous available Space yet."; return }
        switchTo(profile)
    }

    func moveFrontmostWindow(to profile: SpaceProfile, follow: Bool = false) {
        guard requireLicense() else { return }
        guard let native = native(for: profile) else { lastError = "The target Space is unavailable."; return }
        do {
            let windowID = try FocusedWindowResolver.windowID()
            try provider.moveWindow(windowID, to: native)
            if let source = activeProfile?.id { lastWindowMove = (windowID, source) }
            if follow { switchTo(profile) }
        } catch { lastError = error.localizedDescription }
    }

    func moveWindow(_ windowID: CGWindowID, to profile: SpaceProfile, follow: Bool = false) {
        guard requireLicense() else { return }
        guard let native = native(for: profile) else { lastError = "The target Space is unavailable."; return }
        do { if let source = activeProfile?.id { lastWindowMove = (windowID, source) }; try provider.moveWindow(windowID, to: native); if follow { switchTo(profile) } }
        catch { lastError = error.localizedDescription }
    }

    func undoWindowMove() {
        guard let move = lastWindowMove, let source = data.spaces.first(where: { $0.id == move.source }), let native = native(for: source) else { lastError = "There is no available window move to undo."; return }
        do { try provider.moveWindow(move.windowID, to: native); lastWindowMove = nil }
        catch { lastError = "Undo failed: \(error.localizedDescription)" }
    }

    private func recordRecent(_ id: UUID) {
        data.recentSpaceIDs.removeAll(where: { $0 == id }); data.recentSpaceIDs.insert(id, at: 0)
        data.recentSpaceIDs = Array(data.recentSpaceIDs.prefix(20)); scheduleSave()
    }

    func addNote(spaceID: UUID, kind: NoteKind) -> SpaceNote {
        let note = SpaceNote(spaceID: spaceID, title: kind == .checklist ? "Checklist" : "Note", kind: kind)
        data.notes.append(note); scheduleSave(); return note
    }
    func updateNote(_ note: SpaceNote) { let interval = Metrics.signposter.beginInterval("Note save"); defer { Metrics.signposter.endInterval("Note save", interval) }; if let i = data.notes.firstIndex(where: { $0.id == note.id }) { var n = note; n.updatedAt = .now; data.notes[i] = n; scheduleSave(); objectWillChange.send() } }
    func deleteNote(_ id: UUID) { data.notes.removeAll { $0.id == id }; scheduleSave() }

    func addAutomation(spaceID: UUID) { data.automations.append(AutomationGroup(spaceID: spaceID)); scheduleSave() }
    func updateAutomation(_ group: AutomationGroup) { if let i = data.automations.firstIndex(where: { $0.id == group.id }) { data.automations[i] = group; scheduleSave(); objectWillChange.send() } }
    func deleteAutomation(_ id: UUID) { data.automations.removeAll { $0.id == id }; scheduleSave() }
    func importAutomations(_ groups: [AutomationGroup], into spaceID: UUID) {
        let copies = groups.map { group in var value = group; value.id = UUID(); value.spaceID = spaceID; value.actions = value.actions.map { action in var copy = action; copy.id = UUID(); copy.approvedFingerprint = nil; return copy }; return value }
        data.automations.append(contentsOf: copies); scheduleSave(); objectWillChange.send()
    }
    func runAutomation(_ group: AutomationGroup) {
        guard requireLicense() else { return }
        Task {
            guard !isAutomationRunning else { return }
            let enabled = group.actions.filter(\.isEnabled)
            guard !enabled.isEmpty else { lastError = "This automation has no enabled actions."; return }
            var fingerprints: [UUID: String] = [:]
            for action in enabled { fingerprints[action.id] = await runner.fingerprint(action) }
            let changed = enabled.filter { $0.approvedFingerprint != fingerprints[$0.id] }
            if !changed.isEmpty {
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = "Approve automation “\(group.name)”?"
                alert.informativeText = enabled.enumerated().map { index, action in
                    let target = action.target.isEmpty ? "(no target)" : action.target
                    return "\(index + 1). \(action.title) — \(action.kind.rawValue): \(target)"
                }.joined(separator: "\n") + "\n\nScripts are approved by both configuration and file contents. You will be asked again if either changes."
                alert.addButton(withTitle: "Approve & Run")
                alert.addButton(withTitle: "Cancel")
                guard alert.runModal() == .alertFirstButtonReturn else { return }
                guard let groupIndex = data.automations.firstIndex(where: { $0.id == group.id }) else { return }
                for actionIndex in data.automations[groupIndex].actions.indices {
                    let id = data.automations[groupIndex].actions[actionIndex].id
                    if let fingerprint = fingerprints[id] { data.automations[groupIndex].actions[actionIndex].approvedFingerprint = fingerprint }
                }
                scheduleSave()
            }
            guard let approvedGroup = data.automations.first(where: { $0.id == group.id }) else { return }
            isAutomationRunning = true; automationResults = []
            await runner.run(approvedGroup) { [weak self] result in Task { @MainActor in self?.automationResults.append(result) } }
            isAutomationRunning = false
        }
    }

    @discardableResult
    func requireLicense() -> Bool {
        guard license.hasAccess else {
            lastError = "Your 14-day DeskOrbit trial has ended. Activate a license in Settings to continue switching Spaces, moving windows, and running automations."
            return false
        }
        return true
    }

    func updatePreferences(_ preferences: AppPreferences) {
        let shortcutsChanged = data.preferences.quickSwitcherShortcut != preferences.quickSwitcherShortcut || data.preferences.jumpBackShortcut != preferences.jumpBackShortcut || data.preferences.globalShortcutsEnabled != preferences.globalShortcutsEnabled
        data.preferences = preferences; scheduleSave(); objectWillChange.send(); presentationRevision += 1
        if shortcutsChanged { hotkeyRevision += 1 }
        if preferences.launchAtLogin != (SMAppService.mainApp.status == .enabled) {
            do { if preferences.launchAtLogin { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() } } catch { lastError = "Launch at login could not be changed: \(error.localizedDescription)" }
        }
    }

    private func registerTrackingTimer() {
        trackingTimer?.invalidate(); trackingTimer = .scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in Task { @MainActor in self?.trackingTick(forceBoundary: false) } }
        trackingTick(forceBoundary: true)
    }

    func trackingTick(forceBoundary: Bool) {
        guard data.preferences.trackingEnabled, !data.preferences.trackingPaused, let profile = activeProfile, profile.trackingEnabled else { closeOpenSegment(classification: .active); return }
        let activityTypes: [CGEventType] = [.mouseMoved, .leftMouseDown, .rightMouseDown, .otherMouseDown, .scrollWheel, .keyDown]
        let idleSeconds = activityTypes.map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }.min() ?? 0
        let idle = idleSeconds > data.preferences.idleThreshold
        let app = NSWorkspace.shared.frontmostApplication
        let current = currentSegmentID.flatMap { id in data.segments.first(where: { $0.id == id }) }
        let needsBoundary = forceBoundary || current?.spaceID != profile.id || current?.appBundleID != (app?.bundleIdentifier ?? "") || idle != wasIdle
        if needsBoundary {
            // Only backdate a transition from an existing active segment. On a
            // cold launch while the Mac is already idle, counting time before
            // Namespaces started would invent history.
            let now = Date.now
            let boundary = idle ? TrackingPolicy.idleBoundary(now: now, idleSeconds: idleSeconds, hasOpenSegment: current != nil, wasIdle: wasIdle) : now
            closeOpenSegment(at: boundary, classification: wasIdle ? .idle : .active)
            let segment = TrackingSegment(spaceID: profile.id, appBundleID: app?.bundleIdentifier ?? "", appName: app?.localizedName ?? "Unknown", start: boundary, end: .now, classification: idle ? .idle : .active, sessionID: data.sessions.last(where: { $0.endedAt == nil && !$0.isPaused })?.id, billable: profile.billable)
            data.segments.append(segment); currentSegmentID = segment.id
            lastTrackedSpace = profile.id; wasIdle = idle; scheduleSave()
        } else if let id = currentSegmentID, let index = data.segments.firstIndex(where: { $0.id == id }) {
            data.segments[index].end = .now
            if Date().timeIntervalSince(lastHeartbeatSave) >= 30 { lastHeartbeatSave = .now; scheduleSave() }
        }
    }

    func closeOpenSegment(classification: TrackingClassification) {
        closeOpenSegment(at: .now, classification: classification)
    }

    private func closeOpenSegment(at date: Date, classification: TrackingClassification) {
        if let id = currentSegmentID, let i = data.segments.firstIndex(where: { $0.id == id }) {
            data.segments[i].end = max(data.segments[i].start, date); data.segments[i].classification = classification; scheduleSave()
        } else if let i = data.segments.lastIndex(where: { $0.end == nil }) {
            data.segments[i].end = min(date, data.segments[i].start.addingTimeInterval(30)); data.segments[i].classification = .recovered; scheduleSave()
        }
        currentSegmentID = nil
    }

    func startSession(name: String) { endSession(); data.sessions.append(TrackingSession(name: name)); trackingTick(forceBoundary: true); scheduleSave() }
    func endSession() { if let i = data.sessions.lastIndex(where: { $0.endedAt == nil }) { data.sessions[i].endedAt = .now; trackingTick(forceBoundary: true); scheduleSave() } }
    func toggleSessionPause() {
        guard let i = data.sessions.lastIndex(where: { $0.endedAt == nil }) else { lastError = "There is no active session."; return }
        data.sessions[i].isPaused.toggle(); trackingTick(forceBoundary: true); scheduleSave()
    }
    func renameActiveSession(_ name: String) { if let i = data.sessions.lastIndex(where: { $0.endedAt == nil }) { data.sessions[i].name = name; scheduleSave() } }

    func updateSegment(_ segment: TrackingSegment) {
        guard segment.end.map({ $0 >= segment.start }) ?? true, let i = data.segments.firstIndex(where: { $0.id == segment.id }) else { lastError = "A segment cannot end before it starts."; return }
        let old = data.segments[i]
        let overlaps = data.segments.contains { other in guard other.id != segment.id, other.spaceID == segment.spaceID, let end = segment.end, let otherEnd = other.end else { return false }; return segment.start < otherEnd && other.start < end }
        guard !overlaps else { lastError = "That edit overlaps another segment in the same Space."; return }
        data.segments[i] = segment
        data.trackingAudit.append(.init(segmentID: segment.id, action: "edit", before: auditSummary(old), after: auditSummary(segment)))
        scheduleSave(); objectWillChange.send()
    }

    func deleteSegment(_ id: UUID) {
        guard let segment = data.segments.first(where: { $0.id == id }) else { return }
        data.segments.removeAll { $0.id == id }
        data.trackingAudit.append(.init(segmentID: id, action: "delete", before: auditSummary(segment), after: "deleted"))
        if currentSegmentID == id { currentSegmentID = nil }
        scheduleSave()
    }

    private func auditSummary(_ segment: TrackingSegment) -> String {
        "start=\(segment.start.ISO8601Format());end=\(segment.end?.ISO8601Format() ?? "open");space=\(segment.spaceID.uuidString);session=\(segment.sessionID?.uuidString ?? "none");class=\(segment.classification.rawValue);billable=\(segment.billable)"
    }

    func importBackup(_ imported: AppData) async {
        closeOpenSegment(classification: .active)
        do { try await store.save(imported); data = imported; selectProvider(); refreshSpaces() }
        catch { lastError = "Restore failed and current data was preserved: \(error.localizedDescription)" }
    }
    func factoryReset() async {
        closeOpenSegment(classification: .active)
        do {
            try await store.reset(); data = AppData(); UserDefaults.standard.removeObject(forKey: "didCompleteOnboarding")
            selectProvider(); refreshSpaces(); WindowCoordinator.shared.showOnboarding(model: self)
        } catch { lastError = "Reset failed: \(error.localizedDescription)" }
    }
    func scheduleSave() {
        saveTask?.cancel(); let snapshot = data
        saveTask = Task { try? await Task.sleep(for: .milliseconds(250)); if !Task.isCancelled { try? await store.save(snapshot) } }
    }
}
