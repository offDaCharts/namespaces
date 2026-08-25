import NamespacesCore
import SwiftUI

struct QuickSwitcherView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var selected = 0
    @State private var displayFilter = "all"
    @State private var renamingID: UUID?
    var onClose: () -> Void

    private var availableProfiles: [SpaceProfile] { model.profilesInDisplayOrder.filter { profile in displayFilter == "all" || model.native(for: profile)?.displayID == displayFilter } }
    private var results: [SpaceProfile] { SpaceSearch.rank(query: query, profiles: availableProfiles, recents: model.data.recentSpaceIDs) }

    var body: some View {
        VStack(spacing: 0) {
            HStack { Image(systemName: "magnifyingglass").foregroundStyle(.secondary); TextField("Switch to a Space", text: $query).textFieldStyle(.plain).font(.title3).onSubmit { activate() }; Picker("Display", selection: $displayFilter) { Text("All Displays").tag("all"); ForEach(Array(Dictionary(grouping: model.nativeSpaces, by: \.displayID).values.compactMap(\.first)), id: \.displayID) { Text($0.displayName).tag($0.displayID) } }.labelsHidden().frame(width: 125) }
                .padding(16)
            Divider()
            if results.isEmpty { ContentUnavailableView("No matching Spaces", systemImage: "square.grid.2x2", description: Text("Try a different name or refresh Spaces.")) }
            else { ScrollViewReader { proxy in ScrollView { LazyVStack(spacing: 4) { ForEach(Array(results.enumerated()), id: \.element.id) { index, profile in row(profile, index: index).id(profile.id) } }.padding(8) }.onChange(of: selected) { _, value in if results.indices.contains(value) { proxy.scrollTo(results[value].id) } } } }
            Divider(); HStack { Button("Rename") { beginRename() }.keyboardShortcut(.return, modifiers: .command); Button("Note") { openNote() }.keyboardShortcut("n", modifiers: .command); Button("Checklist") { newChecklist() }.keyboardShortcut("t", modifiers: .command); Spacer(); Text("↑↓ · ↩ Switch · esc"); Text(model.providerName) }.font(.caption).foregroundStyle(.secondary).padding(10)
        }
        .frame(width: 430, height: 430)
        .background(.ultraThickMaterial)
        .onChange(of: query) { selected = 0 }
        .onChange(of: displayFilter) { _, _ in selected = 0; if displayFilter != "all", !model.nativeSpaces.contains(where: { $0.displayID == displayFilter }) { displayFilter = "all" } }
        .onKeyPress(.upArrow) { selected = max(0, selected - 1); return .handled }
        .onKeyPress(.downArrow) { selected = min(max(0, results.count - 1), selected + 1); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private func row(_ profile: SpaceProfile, index: Int) -> some View {
        Button { model.switchTo(profile); onClose() } label: {
            HStack(spacing: 12) {
                Image(systemName: profile.symbol).frame(width: 28, height: 28).background(Color(hex: profile.colorHex).opacity(0.25), in: RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading) { if renamingID == profile.id { TextField("Space name", text: Binding(get: { model.data.spaces.first(where: { $0.id == profile.id })?.name ?? profile.name }, set: { value in var copy = profile; copy.name = value; model.updateProfile(copy) })).onSubmit { renamingID = nil } } else { Text(profile.name).fontWeight(index == selected ? .semibold : .regular) }; if let native = model.native(for: profile) { Text("\(native.displayName) · Desktop \(native.index)").font(.caption).foregroundStyle(.secondary) } }
                Spacer(); if profile.id == model.activeProfile?.id { Text("Current").font(.caption).foregroundStyle(.secondary) } else if profile.id == model.data.recentSpaceIDs.first { Text("Previous").font(.caption).foregroundStyle(.secondary) }
            }.padding(9).contentShape(Rectangle()).background(index == selected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 9))
        }.buttonStyle(.plain).onHover { if $0 { selected = index } }
    }
    private func activate() { guard results.indices.contains(selected) else { return }; model.switchTo(results[selected]); onClose() }
    private func beginRename() { guard results.indices.contains(selected) else { return }; renamingID = results[selected].id }
    private func openNote() { guard results.indices.contains(selected) else { return }; let profile = results[selected]; let note = model.data.notes.first(where: { $0.spaceID == profile.id && !$0.isArchived }) ?? model.addNote(spaceID: profile.id, kind: .text); WindowCoordinator.shared.showNote(note, model: model) }
    private func newChecklist() { guard results.indices.contains(selected) else { return }; let note = model.addNote(spaceID: results[selected].id, kind: .checklist); WindowCoordinator.shared.showNote(note, model: model) }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x7C5CFC
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
