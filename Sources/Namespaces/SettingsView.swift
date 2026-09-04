import AppKit
import NamespacesCore
import SwiftUI

private enum SettingsSection: String, CaseIterable, Identifiable {
    case spaces = "Spaces", shortcuts = "Shortcuts", notes = "Notes", automations = "Automations", tracking = "Time Tracking", permissions = "Capabilities", data = "Data & Backup", general = "General", license = "License", about = "About"
    var id: String { rawValue }
    var icon: String { switch self {
    case .spaces: "square.grid.2x2"; case .shortcuts: "keyboard"; case .notes: "note.text"; case .automations: "play.square.stack"; case .tracking: "clock"; case .permissions: "checkmark.shield"; case .data: "externaldrive"; case .general: "gearshape"; case .license: "key"; case .about: "info.circle"
    } }
}

struct SettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var selection: SettingsSection? = .spaces
    @State private var search = ""
    private var filteredSections: [SettingsSection] { guard !search.isEmpty else { return SettingsSection.allCases }; return SettingsSection.allCases.filter { section in (section.rawValue + " " + keywords(section)).localizedCaseInsensitiveContains(search) } }

    var body: some View {
        NavigationSplitView {
            List(filteredSections, selection: $selection) { section in Label(section.rawValue, systemImage: section.icon).tag(section) }
                .navigationSplitViewColumnWidth(min: 180, ideal: 200)
                .searchable(text: $search, prompt: "Search Settings")
                .listStyle(.sidebar)
        } detail: {
            Group { switch selection ?? .spaces {
            case .spaces: SpacesSettingsView()
            case .shortcuts: ShortcutsSettingsView()
            case .notes: NotesSettingsView()
            case .automations: AutomationsSettingsView()
            case .tracking: TrackingSettingsView()
            case .permissions: CapabilitiesView()
            case .data: DataSettingsView()
            case .general: GeneralSettingsView()
            case .license: LicenseSettingsView()
            case .about: AboutView()
            } }.environmentObject(model).navigationTitle((selection ?? .spaces).rawValue)
        }
        .alert("DeskOrbit", isPresented: Binding(get: { model.lastError != nil }, set: { if !$0 { model.lastError = nil } })) { Button("OK") { model.lastError = nil } } message: { Text(model.lastError ?? "") }
    }
    private func keywords(_ section: SettingsSection) -> String { switch section { case .spaces: "names icons colors aliases billable"; case .shortcuts: "hotkeys keyboard jump back"; case .notes: "checklist markdown dock"; case .automations: "scripts apps files shortcuts routines"; case .tracking: "time idle sessions CSV billing history"; case .permissions: "accessibility provider WindowServer experimental"; case .data: "backup restore diagnostics reset privacy"; case .general: "login hover labels appearance offline"; case .license: "trial buy purchase activate key lemon"; case .about: "version data location help" } }
}

private struct ShortcutsSettingsView: View {
    @EnvironmentObject var model: AppModel
    private let options: [ShortcutSpec] = [
        .init(keyCode: 49, modifiers: 2048, display: "⌥Space"), .init(keyCode: 49, modifiers: 4096, display: "⌃Space"),
        .init(keyCode: 45, modifiers: 2048, display: "⌥N"), .init(keyCode: 1, modifiers: 2048, display: "⌥S"),
        .init(keyCode: 49, modifiers: 2560, display: "⌥⇧Space"), .init(keyCode: 49, modifiers: 4608, display: "⌃⇧Space")
    ]
    var body: some View { Page(title: "Keyboard Shortcuts", subtitle: "All global bindings are local, immediately registered, and can be disabled together.") {
        let prefs = Binding(get: { model.data.preferences }, set: { model.updatePreferences($0) })
        Toggle("Enable global shortcuts", isOn: prefs.globalShortcutsEnabled)
        shortcutRow("Quick Switcher", binding: prefs.quickSwitcherShortcut)
        shortcutRow("Jump Back", binding: prefs.jumpBackShortcut)
        Divider(); Text("Per-Space Shortcuts").font(.headline)
        ForEach(model.data.spaces) { profile in HStack { Image(systemName: profile.symbol); Text(profile.name); Spacer(); Text(profile.shortcut?.display ?? "Not assigned").foregroundStyle(.secondary) } }
        if !model.hotkeyFailures.isEmpty { Label("Could not register: \(model.hotkeyFailures.joined(separator: ", ")). Another app may own the shortcut.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
        let all = [prefs.wrappedValue.quickSwitcherShortcut, prefs.wrappedValue.jumpBackShortcut] + model.data.spaces.compactMap(\.shortcut)
        let conflicts = ShortcutValidator.conflicts(all)
        if !conflicts.isEmpty { Label("Two or more DeskOrbit actions use the same shortcut. Change one before relying on it.", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange) }
        HStack { Button("Reset Defaults") { var value = model.data.preferences; value.quickSwitcherShortcut = .init(keyCode: 49, modifiers: 2048, display: "⌥Space"); value.jumpBackShortcut = .init(keyCode: 49, modifiers: 2560, display: "⌥⇧Space"); value.globalShortcutsEnabled = true; model.updatePreferences(value) }; Button("Disable All") { var value = model.data.preferences; value.globalShortcutsEnabled = false; model.updatePreferences(value) } }
        Text("Custom arbitrary key recording is intentionally limited in this private build to a conflict-safe set of common combinations. Per-Space bindings use Option+1 through Option+9 in Spaces.").font(.caption).foregroundStyle(.secondary)
    } }
    private func shortcutRow(_ name: String, binding: Binding<ShortcutSpec>) -> some View { HStack { Text(name).frame(width: 160, alignment: .leading); Picker(name, selection: binding) { ForEach(options, id: \.self) { Text($0.display).tag($0) } }.labelsHidden().frame(width: 150); Spacer(); switch ShortcutValidator.validate(binding.wrappedValue) { case .valid: Label("Ready", systemImage: "checkmark.circle.fill").foregroundStyle(.green); case .warning(let text): Label(text, systemImage: "exclamationmark.triangle").foregroundStyle(.orange); case .invalid(let text): Label(text, systemImage: "xmark.circle").foregroundStyle(.red) } }.padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8)) }
}

private struct Page<Content: View>: View {
    let title: String; let subtitle: String; @ViewBuilder var content: Content
    var body: some View { ScrollView { VStack(alignment: .leading, spacing: 14) { Text(title).font(.title.bold()); Text(subtitle).font(.callout).foregroundStyle(.secondary); content }.padding(24).frame(maxWidth: 920, alignment: .leading).frame(maxWidth: .infinity, alignment: .topLeading) } }
}

private struct SpacesSettingsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View { Page(title: "Spaces", subtitle: "Give every macOS desktop a name and a visual identity.") {
        HStack(spacing: 8) {
            Label("\(model.nativeSpaces.count) Spaces", systemImage: "rectangle.3.group")
            Text("· \(model.providerName)").foregroundStyle(.secondary)
            Spacer()
            Button { model.refreshSpaces() } label: { Label("Refresh", systemImage: "arrow.clockwise") }
        }.font(.callout)
        LazyVStack(spacing: 1) {
            ForEach(model.nativeSpaces) { native in
                if let profile = model.profile(for: native), let index = model.data.spaces.firstIndex(where: { $0.id == profile.id }) {
                    SpaceProfileEditor(profile: Binding(get: { model.data.spaces[index] }, set: { model.updateProfile($0) }), native: native)
                    if native.id != model.nativeSpaces.last?.id { Divider().padding(.leading, 50) }
                }
            }
        }.padding(.horizontal, 12).background(.quaternary.opacity(0.28), in: RoundedRectangle(cornerRadius: 10))
        let unmatched = model.data.spaces.filter { model.native(for: $0) == nil }
        if !unmatched.isEmpty { Divider(); Text("Saved but currently unmatched").font(.headline); Text("DeskOrbit keeps these records instead of guessing and attaching their notes or time to the wrong desktop.").font(.caption).foregroundStyle(.secondary); ForEach(unmatched) { profile in HStack { Image(systemName: "questionmark.diamond").foregroundStyle(.orange); VStack(alignment: .leading) { Text(profile.name); Text("Previously desktop \(profile.lastKnownIndex.map(String.init) ?? "?") · Native ID \(profile.nativeID)").font(.caption).foregroundStyle(.secondary) }; Spacer(); Menu("Link to Current Space…") { ForEach(model.nativeSpaces) { native in Button("\(native.displayName) · Desktop \(native.index)") { model.linkUnmatchedProfile(profile.id, to: native) } } } }.padding(10).background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 8)) } }
        if model.nativeSpaces.isEmpty { ContentUnavailableView("No Spaces discovered", systemImage: "rectangle.3.group", description: Text(model.capabilityMessage)) }
    } }
}

private struct SpaceProfileEditor: View {
    private struct ColorOption: Identifiable {
        let name: String
        let hex: String
        var id: String { hex }
    }

    @EnvironmentObject var model: AppModel
    @Binding var profile: SpaceProfile
    let native: NativeSpace
    @State private var showsDetails = false
    private let symbols: [(String, String)] = [
        ("Grid", "square.grid.2x2"), ("Build", "hammer"), ("Terminal", "terminal"),
        ("Web", "globe"), ("Documents", "doc.text"), ("Design", "paintpalette"),
        ("Music", "music.note"), ("Team", "person.2"), ("Reading", "book"),
        ("Work", "briefcase"), ("Home", "house"), ("Ideas", "sparkles")
    ]
    private let colors = [
        ColorOption(name: "Namespace Purple", hex: "#7C5CFC"),
        ColorOption(name: "Blue", hex: "#0A84FF"),
        ColorOption(name: "Green", hex: "#30D158"),
        ColorOption(name: "Orange", hex: "#FF9F0A"),
        ColorOption(name: "Red", hex: "#FF453A"),
        ColorOption(name: "Purple", hex: "#BF5AF2"),
        ColorOption(name: "Cyan", hex: "#64D2FF"),
        ColorOption(name: "Gray", hex: "#8E8E93"),
        ColorOption(name: "Yellow", hex: "#FFD60A"),
        ColorOption(name: "Mint", hex: "#63E6E2"),
        ColorOption(name: "Teal", hex: "#40C8E0"),
        ColorOption(name: "Indigo", hex: "#5E5CE6"),
        ColorOption(name: "Pink", hex: "#FF375F"),
        ColorOption(name: "Brown", hex: "#AC8E68"),
    ]
    private let shortcutOptions: [(String, ShortcutSpec?)] = {
        let keyCodes: [UInt32] = [18, 19, 20, 21, 23, 22, 26, 28, 25]
        return [("None", nil)] + keyCodes.enumerated().map { ("⌥\($0.offset + 1)", ShortcutSpec(keyCode: $0.element, modifiers: 2048, display: "⌥\($0.offset + 1)")) }
    }()
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Color(hex: profile.colorHex).opacity(0.20))
                    Image(systemName: profile.symbol).font(.system(size: 16, weight: .medium)).foregroundStyle(Color(hex: profile.colorHex))
                }.frame(width: 34, height: 34)
                VStack(alignment: .leading, spacing: 2) {
                    TextField("Space name", text: $profile.name).font(.body.weight(.semibold)).textFieldStyle(.plain)
                    Text("\(native.displayName) · \(native.kind == .fullscreen ? "Fullscreen" : "Desktop") \(native.index)")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                if native.isActive { Label("Current", systemImage: "circle.fill").font(.caption).foregroundStyle(.green) }
                Button("Switch") { model.switchTo(profile) }.controlSize(.small).disabled(native.isActive)
                Button { withAnimation(.easeInOut(duration: 0.16)) { showsDetails.toggle() } } label: {
                    Image(systemName: "chevron.right").rotationEffect(.degrees(showsDetails ? 90 : 0)).frame(width: 16)
                }.buttonStyle(.plain).foregroundStyle(.secondary).help(showsDetails ? "Hide options" : "Show options")
            }
            if showsDetails {
                HStack(spacing: 12) {
                    Picker("Icon", selection: $profile.symbol) {
                        ForEach(symbols, id: \.1) { name, symbol in Label(name, systemImage: symbol).tag(symbol) }
                    }.frame(width: 145)
                    Picker("Color", selection: $profile.colorHex) {
                        ForEach(colorOptions) { option in
                            Label {
                                Text("\(option.name) · \(option.hex)")
                            } icon: {
                                Image(nsImage: swatchImage(option.hex)).renderingMode(.original)
                            }
                            .labelStyle(.titleAndIcon)
                            .tag(option.hex)
                        }
                    }.frame(width: 190)
                    Toggle("Track time", isOn: $profile.trackingEnabled)
                    Toggle("Billable", isOn: $profile.billable)
                    Picker("Shortcut", selection: $profile.shortcut) {
                        ForEach(shortcutOptions, id: \.0) { option in Text(option.0).tag(option.1) }
                    }.frame(width: 125)
                    Spacer(minLength: 0)
                }.controlSize(.small)
                TextField("Search aliases, separated by commas", text: Binding(get: { profile.aliases.joined(separator: ", ") }, set: { profile.aliases = $0.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty } }))
                    .textFieldStyle(.roundedBorder).controlSize(.small).padding(.leading, 44)
            }
        }.padding(.vertical, 10)
    }

    private var colorOptions: [ColorOption] {
        guard !colors.contains(where: { $0.hex == profile.colorHex }) else { return colors }
        return [ColorOption(name: "Custom", hex: profile.colorHex)] + colors
    }

    private func swatchImage(_ hex: String) -> NSImage {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x7C5CFC
        let color = NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
        let image = NSImage(size: NSSize(width: 14, height: 14), flipped: false) { rect in
            let swatch = NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1))
            color.setFill()
            swatch.fill()
            NSColor.white.withAlphaComponent(0.35).setStroke()
            swatch.lineWidth = 0.75
            swatch.stroke()
            return true
        }
        image.isTemplate = false
        return image
    }
}

private struct NotesSettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedSpace: UUID?
    var body: some View { Page(title: "Notes & Checklists", subtitle: "Local notes belong to a named Space and are never uploaded.") {
        Picker("Space", selection: $selectedSpace) { Text("Choose a Space").tag(UUID?.none); ForEach(model.data.spaces) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 300)
        HStack { Button("New Note") { add(.text) }.disabled(selectedSpace == nil); Button("New Checklist") { add(.checklist) }.disabled(selectedSpace == nil); Button("Hide All Note Windows") { WindowCoordinator.shared.hideAllNotes() } }
        ForEach(model.data.notes.filter { selectedSpace == nil || $0.spaceID == selectedSpace }) { note in
            HStack { Image(systemName: note.kind == .checklist ? "checklist" : "note.text"); VStack(alignment: .leading) { Text(note.title).bold(); Text(note.updatedAt.formatted()).font(.caption).foregroundStyle(.secondary) }; Spacer(); Button("Open") { WindowCoordinator.shared.showNote(note, model: model) }; Button("Export…") { export(note) }; Button(role: .destructive) { model.deleteNote(note.id) } label: { Image(systemName: "trash") } }.padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 9))
        }
    } }
    private func add(_ kind: NoteKind) { guard let id = selectedSpace else { return }; let note = model.addNote(spaceID: id, kind: kind); WindowCoordinator.shared.showNote(note, model: model) }
    private func export(_ note: SpaceNote) { let panel = NSSavePanel(); panel.nameFieldStringValue = note.title.replacingOccurrences(of: "/", with: "-") + ".md"; guard panel.runModal() == .OK, let url = panel.url else { return }; let markdown = note.kind == .text ? "# \(note.title)\n\n\(note.body)\n" : "# \(note.title)\n\n" + note.items.map { "- [\($0.isCompleted ? "x" : " ")] \($0.text)" }.joined(separator: "\n") + "\n"; do { try markdown.write(to: url, atomically: true, encoding: .utf8) } catch { model.lastError = error.localizedDescription } }
}

struct NoteEditorView: View {
    @EnvironmentObject var model: AppModel
    let noteID: UUID
    private var index: Int? { model.data.notes.firstIndex(where: { $0.id == noteID }) }
    var body: some View {
        if let index {
            let binding = Binding(get: { model.data.notes[index] }, set: { model.updateNote($0) })
            VStack(spacing: 0) {
                HStack { TextField("Title", text: binding.title).font(.headline).textFieldStyle(.plain); Button("Dock / Undock") { WindowCoordinator.shared.toggleDock(noteID: noteID) }.font(.caption) }.padding(12); Divider()
                if binding.wrappedValue.kind == .text { TextEditor(text: binding.body).font(.body).padding(8) }
                else { ChecklistEditor(note: binding) }
            }.frame(minWidth: 280, minHeight: 250)
        } else { ContentUnavailableView("Note unavailable", systemImage: "note.text") }
    }
}

private struct ChecklistEditor: View {
    @Binding var note: SpaceNote
    @State private var newItem = ""
    var body: some View { VStack(spacing: 8) {
        ScrollView { ForEach($note.items) { $item in HStack { Toggle("", isOn: $item.isCompleted).labelsHidden().onChange(of: item.isCompleted) { _, done in item.completedAt = done ? .now : nil }; TextField("Item", text: $item.text); Button { note.items.removeAll { $0.id == item.id } } label: { Image(systemName: "xmark") }.buttonStyle(.plain) }.padding(.horizontal, 10) } }
        HStack { TextField("New checklist item", text: $newItem).onSubmit(add); Button("Add", action: add).disabled(newItem.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }.padding(10)
    } }
    private func add() { let value = newItem.trimmingCharacters(in: .whitespacesAndNewlines); guard !value.isEmpty else { return }; note.items.append(ChecklistItem(text: value)); newItem = "" }
}

private struct AutomationsSettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var selectedSpace: UUID?
    var body: some View { Page(title: "On-Click Automations", subtitle: "Deliberately run ordered local actions. Nothing runs merely because you enter a Space.") {
        Picker("Space", selection: $selectedSpace) { Text("Choose a Space").tag(UUID?.none); ForEach(model.data.spaces) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 300)
        HStack { Button("Add Group") { if let id = selectedSpace { model.addAutomation(spaceID: id) } }.disabled(selectedSpace == nil); Button("Export Definitions…", action: exportGroups).disabled(model.data.automations.isEmpty); Button("Import Definitions…", action: importGroups).disabled(selectedSpace == nil) }
        ForEach(model.data.automations.filter { selectedSpace == nil || $0.spaceID == selectedSpace }) { group in AutomationGroupEditor(groupID: group.id) }
        if model.isAutomationRunning { ProgressView("Running automation…") }
        ForEach(model.automationResults) { result in Label("\(result.title): \(result.message)", systemImage: result.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill").foregroundStyle(result.succeeded ? .green : .red) }
    } }
    private func exportGroups() { let panel = NSSavePanel(); panel.nameFieldStringValue = "Namespaces-Automations.json"; guard panel.runModal() == .OK, let url = panel.url else { return }; do { let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]; var groups = model.data.automations; for gi in groups.indices { for ai in groups[gi].actions.indices { groups[gi].actions[ai].approvedFingerprint = nil } }; try encoder.encode(groups).write(to: url, options: .atomic) } catch { model.lastError = error.localizedDescription } }
    private func importGroups() { guard let selectedSpace else { return }; let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; guard panel.runModal() == .OK, let url = panel.url else { return }; do { let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0; guard size < 5_000_000 else { throw CocoaError(.fileReadTooLarge) }; let groups = try JSONDecoder().decode([AutomationGroup].self, from: Data(contentsOf: url)); guard groups.count <= 100, groups.flatMap(\.actions).count <= 1000 else { throw CocoaError(.fileReadCorruptFile) }; let alert = NSAlert(); alert.messageText = "Import \(groups.count) automation groups?"; alert.informativeText = "All actions will be shown in the editor and require fresh approval before first execution. Nothing runs during import."; alert.addButton(withTitle: "Import"); alert.addButton(withTitle: "Cancel"); if alert.runModal() == .alertFirstButtonReturn { model.importAutomations(groups, into: selectedSpace) } } catch { model.lastError = "Automation import rejected: \(error.localizedDescription)" } }
}

private struct AutomationGroupEditor: View {
    @EnvironmentObject var model: AppModel
    let groupID: UUID
    private var index: Int? { model.data.automations.firstIndex(where: { $0.id == groupID }) }
    var body: some View { if let index {
        let group = Binding(get: { model.data.automations[index] }, set: { model.updateAutomation($0) })
        DisclosureGroup { VStack(spacing: 8) {
            TextField("Description", text: group.details)
            ForEach(group.actions) { action in if let ai = group.wrappedValue.actions.firstIndex(where: { $0.id == action.id }) { HStack(alignment: .top) { ActionEditor(action: Binding(get: { group.wrappedValue.actions[ai] }, set: { group.wrappedValue.actions[ai] = $0 })); VStack { Button { guard ai > 0 else { return }; group.wrappedValue.actions.swapAt(ai, ai - 1) } label: { Image(systemName: "arrow.up") }.disabled(ai == 0); Button { guard ai + 1 < group.wrappedValue.actions.count else { return }; group.wrappedValue.actions.swapAt(ai, ai + 1) } label: { Image(systemName: "arrow.down") }.disabled(ai + 1 == group.wrappedValue.actions.count); Button(role: .destructive) { group.wrappedValue.actions.remove(at: ai) } label: { Image(systemName: "trash") } }.buttonStyle(.borderless).padding(.top, 10) } } }
            Menu("Add Action") { ForEach(AutomationActionKind.allCases, id: \.self) { kind in Button(kind.rawValue) { group.wrappedValue.actions.append(AutomationAction(kind: kind, title: kind.rawValue)) } } }
        }.padding(.top, 10) } label: { HStack { TextField("Group name", text: group.name).font(.headline); Spacer(); Toggle("Enabled", isOn: group.isEnabled).labelsHidden(); Button("Run") { model.runAutomation(group.wrappedValue) }; Button(role: .destructive) { model.deleteAutomation(groupID) } label: { Image(systemName: "trash") } } }
        .padding(12).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 10))
    } }
}

private struct ActionEditor: View {
    @Binding var action: AutomationAction
    var body: some View { VStack(alignment: .leading, spacing: 7) { HStack { Toggle("", isOn: $action.isEnabled).labelsHidden(); Picker("", selection: $action.kind) { ForEach(AutomationActionKind.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.labelsHidden().frame(width: 160); TextField("Action title", text: $action.title); Toggle("Continue on failure", isOn: $action.continueOnFailure) }; HStack { TextField(targetPrompt, text: $action.target); if action.kind == .openPath || action.kind == .runScript || action.kind == .launchApplication { Button("Choose…", action: chooseTarget) } }; TextField(argumentsPrompt, text: Binding(get: { action.arguments.joined(separator: ", ") }, set: { action.arguments = $0.split(separator: ",", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) } })); HStack { Text("Timeout"); TextField("seconds", value: $action.timeout, format: .number).frame(width: 70); Text("Arguments are passed directly as an array; no shell command is assembled.").font(.caption).foregroundStyle(.secondary) } }.padding(10).background(.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 8)) }
    private var targetPrompt: String { switch action.kind { case .launchApplication: "Application bundle identifier"; case .openPath: "Absolute file or folder path"; case .openURL: "https:// URL"; case .runShortcut: "Apple Shortcut name"; case .runScript: "Absolute script path" } }
    private var argumentsPrompt: String { action.kind == .runScript ? "Interpreter first, then arguments (comma-separated), e.g. /bin/zsh, --verbose" : "Arguments (comma-separated; optional)" }
    private func chooseTarget() {
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false
        if action.kind == .launchApplication { panel.directoryURL = URL(fileURLWithPath: "/Applications"); panel.canChooseDirectories = false; panel.allowedContentTypes = [.application] }
        else if action.kind == .openPath { panel.canChooseDirectories = true; panel.canChooseFiles = true }
        else { panel.canChooseDirectories = false; panel.canChooseFiles = true }
        guard panel.runModal() == .OK, let url = panel.url else { return }
        if action.kind == .launchApplication { action.target = Bundle(url: url)?.bundleIdentifier ?? ""; if action.title == AutomationActionKind.launchApplication.rawValue { action.title = url.deletingPathExtension().lastPathComponent } }
        else if action.kind == .runScript {
            do { let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Namespaces/Scripts", isDirectory: true); try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700]); let destination = directory.appendingPathComponent("\(UUID().uuidString)-\(url.lastPathComponent)"); try FileManager.default.copyItem(at: url, to: destination); try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: destination.path); action.target = destination.path } catch { action.target = "" }
        } else { action.target = url.path }
    }
}

private struct TrackingSettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var sessionName = "Focus Session"
    @State private var range: SummaryRange = .today
    @State private var spaceFilter: UUID?
    @State private var classFilter: TrackingClassification?
    @State private var editing: TrackingSegment?
    private var startDate: Date { let calendar = Calendar.current; switch range { case .today: return calendar.startOfDay(for: .now); case .week: return calendar.date(byAdding: .day, value: -7, to: .now)!; case .month: return calendar.date(byAdding: .month, value: -1, to: .now)!; case .all: return .distantPast } }
    private var filtered: [TrackingSegment] { model.data.segments.filter { $0.start >= startDate && (spaceFilter == nil || $0.spaceID == spaceFilter) && (classFilter == nil || $0.classification == classFilter) } }
    private var activeTotal: TimeInterval { filtered.filter { $0.classification == .active || $0.classification == .manual }.reduce(0) { $0 + $1.duration } }
    private var idleTotal: TimeInterval { filtered.filter { $0.classification == .idle }.reduce(0) { $0 + $1.duration } }
    private var billableTotal: TimeInterval { filtered.filter(\.billable).reduce(0) { $0 + $1.duration } }
    var body: some View { Page(title: "Time Tracking", subtitle: "Auditable local segments by Space and frontmost application. No window titles or content are collected.") {
        HStack { SummaryTile(name: "Active", value: format(activeTotal)); SummaryTile(name: "Idle", value: format(idleTotal)); SummaryTile(name: "Billable", value: format(billableTotal)); Spacer() }
        HStack { TextField("Session name", text: $sessionName).frame(width: 180); Button("Start Session") { model.startSession(name: sessionName) }; Button(model.data.sessions.last(where: { $0.endedAt == nil })?.isPaused == true ? "Resume Session" : "Pause Session") { model.toggleSessionPause() }; Button("End Session") { model.endSession() }; Spacer(); Toggle("Pause all tracking", isOn: Binding(get: { model.data.preferences.trackingPaused }, set: { var p = model.data.preferences; p.trackingPaused = $0; model.updatePreferences(p); model.trackingTick(forceBoundary: true) })) }
        HStack { Picker("Range", selection: $range) { ForEach(SummaryRange.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(width: 150); Picker("Space", selection: $spaceFilter) { Text("All Spaces").tag(UUID?.none); ForEach(model.data.spaces) { Text($0.name).tag(Optional($0.id)) } }.frame(width: 180); Picker("Class", selection: $classFilter) { Text("All Classes").tag(TrackingClassification?.none); ForEach([TrackingClassification.active, .idle, .manual, .recovered, .uncertain], id: \.self) { Text($0.rawValue.capitalized).tag(Optional($0)) } }.frame(width: 170); Spacer(); Text("\(filtered.count) segments · \(model.data.trackingAudit.count) audited edits").foregroundStyle(.secondary) }
        Grid(alignment: .leading, horizontalSpacing: 13, verticalSpacing: 7) { GridRow { Text("Space").bold(); Text("Application").bold(); Text("Start").bold(); Text("Duration").bold(); Text("Class").bold(); Text("") }; ForEach(filtered.suffix(200).reversed()) { segment in GridRow { Text(model.data.spaces.first(where: { $0.id == segment.spaceID })?.name ?? "Unknown"); Text(segment.appName); Text(segment.start.formatted(date: .abbreviated, time: .shortened)); Text(format(segment.duration)); Text(segment.classification.rawValue.capitalized); HStack(spacing: 5) { Button("Edit") { editing = segment }.buttonStyle(.link); Button("Delete", role: .destructive) { model.deleteSegment(segment.id) }.buttonStyle(.link) } } } }
        if filtered.isEmpty { ContentUnavailableView("No tracking segments", systemImage: "clock", description: Text("Adjust the filters or use your Mac while tracking is enabled.")) }
    }.sheet(item: $editing) { segment in SegmentEditor(segment: segment, spaces: model.data.spaces, sessions: model.data.sessions) { model.updateSegment($0); editing = nil } onCancel: { editing = nil } } }
    private func format(_ value: TimeInterval) -> String { let seconds = Int(value); return String(format: "%02d:%02d:%02d", seconds / 3600, (seconds / 60) % 60, seconds % 60) }
    private enum SummaryRange: String, CaseIterable { case today = "Today", week = "7 Days", month = "30 Days", all = "All Time" }
}

private struct SummaryTile: View { let name: String; let value: String; var body: some View { VStack(alignment: .leading) { Text(name).foregroundStyle(.secondary); Text(value).font(.title2.bold()) }.padding(12).background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10)) } }

private struct SegmentEditor: View {
    @State var segment: TrackingSegment
    let spaces: [SpaceProfile]; let sessions: [TrackingSession]; let onSave: (TrackingSegment) -> Void; let onCancel: () -> Void
    var body: some View { VStack(alignment: .leading, spacing: 14) { Text("Edit Tracking Segment").font(.title2.bold()); DatePicker("Start", selection: $segment.start); DatePicker("End", selection: Binding(get: { segment.end ?? .now }, set: { segment.end = $0 })); Picker("Space", selection: $segment.spaceID) { ForEach(spaces) { Text($0.name).tag($0.id) } }; Picker("Session", selection: $segment.sessionID) { Text("None").tag(UUID?.none); ForEach(sessions) { Text($0.name).tag(Optional($0.id)) } }; Picker("Classification", selection: $segment.classification) { ForEach([TrackingClassification.active, .idle, .manual, .recovered, .uncertain], id: \.self) { Text($0.rawValue.capitalized).tag($0) } }; Toggle("Billable", isOn: $segment.billable); TextField("Correction note", text: $segment.note); HStack { Spacer(); Button("Cancel", action: onCancel); Button("Save") { onSave(segment) }.keyboardShortcut(.defaultAction) } }.padding(24).frame(width: 440) }
}

private struct CapabilitiesView: View {
    @EnvironmentObject var model: AppModel
    var body: some View { Page(title: "Permissions & Capabilities", subtitle: "DeskOrbit fails closed when an experimental macOS integration is unavailable.") {
        LabeledContent("Provider", value: model.providerName); LabeledContent("Status", value: model.capabilityMessage)
        CapabilityRow(name: "Discover native Spaces", available: model.provider.capabilities.contains(.enumerate))
        CapabilityRow(name: "Direct switching", available: model.provider.capabilities.contains(.switchSpace))
        CapabilityRow(name: "Move windows", available: model.provider.capabilities.contains(.moveWindow))
        CapabilityRow(name: "Mission Control overlays", available: model.provider.capabilities.contains(.missionControlLabels) && AXIsProcessTrusted())
        CapabilityRow(name: "Accessibility", available: AXIsProcessTrusted())
        LabeledContent("Mission Control status", value: model.missionControlOverlayStatus)
        if model.providerCircuitOpen { Label("Enhanced integration circuit is open after three failures.", systemImage: "bolt.trianglebadge.exclamationmark.fill").foregroundStyle(.orange) }
        HStack { Button("Retry Enhanced Provider") { model.retryEnhancedProvider() }; Button("Request Accessibility Access") { let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary; _ = AXIsProcessTrustedWithOptions(options) }; Button("Open Accessibility Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) } }
    } }
}

private struct CapabilityRow: View { let name: String; let available: Bool; var body: some View { HStack { Image(systemName: available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(available ? .green : .orange); Text(name); Spacer(); Text(available ? "Available" : "Unavailable").foregroundStyle(.secondary) }.padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8)) } }

private struct DataSettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var supportReport: SupportReport?
    var body: some View {
        Page(title: "Data & Backup", subtitle: "All data is local. Backups are readable versioned JSON and tracking exports are CSV.") {
            LabeledContent("Local store", value: model.store.fileURL.path); LabeledContent("Spaces", value: "\(model.data.spaces.count)"); LabeledContent("Notes", value: "\(model.data.notes.count)"); LabeledContent("Tracking segments", value: "\(model.data.segments.count)")
            HStack { Button("Export Full Backup…", action: exportBackup); Button("Restore Backup…", action: importBackup); Button("Export Tracking CSV…", action: exportCSV); Button("Create Support Report…") { supportReport = SupportReport.make(from: model) } }
            HStack { Picker("Automatic local backups", selection: Binding(get: { model.data.preferences.rollingBackupRetention }, set: { var p = model.data.preferences; p.rollingBackupRetention = $0; model.updatePreferences(p) })) { Text("Off").tag(0); Text("Keep 7 daily copies").tag(7); Text("Keep 30 daily copies").tag(30) }.frame(width: 320); Spacer(); Button("Factory Reset…", role: .destructive, action: factoryReset) }
            Text("Restore validates the schema and file size before replacing local state. Support reports are previewed before export and exclude Space names, notes, paths, app activity, automation contents, and license keys.").font(.caption).foregroundStyle(.secondary)
        }
        .sheet(item: $supportReport) { report in SupportReportPreview(report: report) { supportReport = nil } }
    }
    private func exportBackup() { let panel = NSSavePanel(); panel.nameFieldStringValue = "Namespaces-Backup.namespacesbackup"; guard panel.runModal() == .OK, let url = panel.url else { return }; Task { do { try await model.store.exportPackage(model.data, to: url) } catch { await MainActor.run { model.lastError = error.localizedDescription } } } }
    private func importBackup() { let panel = NSOpenPanel(); panel.canChooseDirectories = true; panel.canChooseFiles = true; guard panel.runModal() == .OK, let url = panel.url else { return }; Task { do { let data = try await model.store.decodeBackup(at: url); let approved = await MainActor.run { let alert = NSAlert(); alert.messageText = "Restore Namespaces Backup?"; alert.informativeText = "This validated backup contains \(data.spaces.count) Spaces, \(data.notes.count) notes, \(data.automations.count) automation groups, and \(data.segments.count) tracking segments. Current data will be replaced only if the validated replacement is saved successfully."; alert.addButton(withTitle: "Restore"); alert.addButton(withTitle: "Cancel"); return alert.runModal() == .alertFirstButtonReturn }; if approved { await model.importBackup(data) } } catch { await MainActor.run { model.lastError = error.localizedDescription } } } }
    private func factoryReset() { let alert = NSAlert(); alert.alertStyle = .critical; alert.messageText = "Reset Namespaces?"; alert.informativeText = "This removes all Namespaces names, notes, automations, tracking history, and settings from this Mac. Export a backup first if you may need them. This cannot be undone."; alert.addButton(withTitle: "Cancel"); alert.addButton(withTitle: "Reset Everything"); guard alert.runModal() == .alertSecondButtonReturn else { return }; Task { await model.factoryReset() } }
    private func exportCSV() { let panel = NSSavePanel(); panel.nameFieldStringValue = "Namespaces-Tracking.csv"; guard panel.runModal() == .OK, let url = panel.url else { return }; do { try CSVExporter.trackingCSV(segments: model.data.segments, spaces: model.data.spaces).write(to: url, atomically: true, encoding: .utf8) } catch { model.lastError = error.localizedDescription } }
}

private struct GeneralSettingsView: View {
    @EnvironmentObject var model: AppModel
    var body: some View { Page(title: "General", subtitle: "Appearance, lifecycle, privacy, and experimental behavior.") {
        let prefs = Binding(get: { model.data.preferences }, set: { model.updatePreferences($0) })
        Picker("Menu-bar label", selection: prefs.menuLabelMode) { ForEach(AppPreferences.MenuLabelMode.allCases, id: \.self) { Text($0.rawValue).tag($0) } }.frame(width: 300)
        Toggle("Launch at login", isOn: prefs.launchAtLogin); Toggle("Automatic local time tracking", isOn: prefs.trackingEnabled)
        HStack { Text("Idle threshold"); TextField("seconds", value: prefs.idleThreshold, format: .number).frame(width: 90); Text("seconds").foregroundStyle(.secondary) }
        Toggle("Enhanced native Spaces integration", isOn: prefs.enhancedIntegrationEnabled)
            .onChange(of: prefs.wrappedValue.enhancedIntegrationEnabled) { _, _ in model.selectProvider(); model.refreshSpaces() }
        Toggle("Show names on Mission Control thumbnails", isOn: prefs.missionControlLabelsEnabled)
        LabeledContent("Mission Control status", value: model.missionControlOverlayStatus)
        Text("DeskOrbit adds click-through colored labels over Mission Control. Apple’s Desktop 1, Desktop 2 labels are not modified. Accessibility lets DeskOrbit detect trackpad gestures and follow each thumbnail without disabling SIP.").font(.caption).foregroundStyle(.secondary)
        if prefs.wrappedValue.missionControlLabelsEnabled && !AXIsProcessTrusted() {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange).font(.title3)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Accessibility needs approval").font(.callout.weight(.semibold))
                    Text("Remove older Namespaces or DeskOrbit entries, add /Applications/DeskOrbit.app, then relaunch. Guessed labels stay hidden.").font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 12)
                Button("Open Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!) }.controlSize(.small)
            }
            .padding(10)
            .background(.orange.opacity(0.07), in: RoundedRectangle(cornerRadius: 9))
            .overlay { RoundedRectangle(cornerRadius: 9).stroke(.orange.opacity(0.18), lineWidth: 0.5) }
        }
        Toggle("Reveal Space strip by hovering at the top center", isOn: prefs.hoverEnabled)
        HStack { Button("Preview Space Labels") { OverlayController.shared.showSpaceLabels(duration: 5) }; Button("Grant Accessibility…") { let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary; _ = AXIsProcessTrustedWithOptions(options) }; Menu("Move Frontmost Window") { ForEach(model.profilesInDisplayOrder) { profile in Button(profile.name) { model.moveFrontmostWindow(to: profile) } } } }
        Divider(); Label("DeskOrbit makes no analytics, telemetry, advertising, or crash-report uploads.", systemImage: "hand.raised.fill").foregroundStyle(.secondary)
    } }
}

private struct LicenseSettingsView: View {
    @EnvironmentObject var model: AppModel
    @State private var licenseKey = ""

    var body: some View { Page(title: "License", subtitle: "One purchase covers up to three Macs and includes lifetime updates.") {
        HStack(spacing: 12) {
            Image(systemName: model.license.hasAccess ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 34))
                .foregroundStyle(model.license.hasAccess ? .green : .orange)
            VStack(alignment: .leading) {
                Text(model.license.statusTitle).font(.title3.bold())
                if let key = model.license.maskedLicenseKey { Text(key).font(.caption.monospaced()).foregroundStyle(.secondary) }
            }
        }

        if model.license.maskedLicenseKey == nil {
            SecureField("License key", text: $licenseKey).textFieldStyle(.roundedBorder).frame(maxWidth: 460)
            HStack {
                Button("Activate License") { Task { if await model.license.activate(licenseKey) { licenseKey = "" } } }
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.license.isWorking || licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Buy DeskOrbit — \(model.license.priceDisplay)") { NSWorkspace.shared.open(model.license.purchaseURL) }
            }
        } else {
            HStack {
                Button("Validate Now") { Task { await model.license.validate() } }.disabled(model.license.isWorking)
                Button("Deactivate This Mac") { Task { _ = await model.license.deactivate() } }.disabled(model.license.isWorking)
            }
        }

        if model.license.isWorking { ProgressView("Contacting the license server…") }
        if let error = model.license.lastError { Label(error, systemImage: "exclamationmark.circle").foregroundStyle(.orange) }
        Divider()
        Text("DeskOrbit sends only the license key and an instance label for this Mac to Lemon Squeezy when you activate, validate, or deactivate. Your Space names, notes, automations, application usage, and tracking data stay on this Mac.").font(.caption).foregroundStyle(.secondary)
    } }
}

private struct AboutView: View {
    @EnvironmentObject var model: AppModel
    private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.2.1" }
    var body: some View { Page(title: "DeskOrbit", subtitle: "Name, switch, and organize your Mac Spaces.") {
        Image(systemName: "square.grid.2x2.fill").font(.system(size: 72)).foregroundStyle(.tint); Text("Version \(version)").font(.headline); Text("Kauibungalow LLC · macOS \(ProcessInfo.processInfo.operatingSystemVersionString)")
        Divider(); Text("DeskOrbit adds its own labels and controls around native Spaces. It does not modify Apple's Desktop labels, inject code into Dock, disable SIP, capture the screen, or upload usage data.").foregroundStyle(.secondary)
        LabeledContent("Provider", value: model.providerName); LabeledContent("Data", value: model.store.fileURL.path)
    } }
}

private extension ProcessInfo {
    var machineHardwareName: String {
        var size = 0; sysctlbyname("hw.machine", nil, &size, nil, 0); var bytes = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &bytes, &size, nil, 0)
        return String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
}
