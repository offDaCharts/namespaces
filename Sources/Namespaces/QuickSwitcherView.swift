import NamespacesCore
import SwiftUI

struct QuickSwitcherView: View {
    @EnvironmentObject var model: AppModel
    @State private var query = ""
    @State private var selected = 0
    @State private var displayFilter = "all"
    @State private var renamingID: UUID?
    var onClose: () -> Void

    private var availableProfiles: [SpaceProfile] {
        model.profilesInDisplayOrder.filter { displayFilter == "all" || model.native(for: $0)?.displayID == displayFilter }
    }
    private var results: [SpaceProfile] {
        SpaceSearch.rank(query: query, profiles: availableProfiles, recents: model.data.recentSpaceIDs)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Menu {
                    Button("All Displays") { displayFilter = "all" }
                    Divider()
                    ForEach(Array(Dictionary(grouping: model.nativeSpaces, by: \.displayID).values.compactMap(\.first)), id: \.displayID) { display in
                        Button(display.displayName) { displayFilter = display.displayID }
                    }
                } label: {
                    HStack(spacing: 5) {
                        Text(displayFilter == "all" ? "All" : (model.nativeSpaces.first { $0.displayID == displayFilter }?.displayName ?? "All"))
                        Image(systemName: "chevron.down").font(.caption2)
                    }.font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.22), in: RoundedRectangle(cornerRadius: 6))
                }.menuStyle(.borderlessButton).fixedSize()
                Spacer()
                Text("⌥Space").font(.caption2).foregroundStyle(.tertiary)
            }.padding(.horizontal, 12).padding(.top, 12).padding(.bottom, 8)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Type to filter…", text: $query).textFieldStyle(.plain).onSubmit { activate() }
                if !query.isEmpty { Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(.tertiary) }
            }.padding(.horizontal, 10).frame(height: 34)
                .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 7))
                .padding(.horizontal, 12).padding(.bottom, 8)

            if let previous = model.data.recentSpaceIDs.first.flatMap({ id in model.data.spaces.first { $0.id == id } }) {
                Button { model.jumpBack(); onClose() } label: {
                    HStack(spacing: 8) {
                        Text("0").font(.caption.monospacedDigit()).frame(width: 22, height: 22).background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 5))
                        Image(systemName: "arrow.uturn.backward").font(.caption).foregroundStyle(.secondary)
                        Text("Last:").foregroundStyle(.secondary)
                        Text(previous.name).fontWeight(.medium).lineLimit(1)
                        Spacer()
                    }.font(.caption).padding(.horizontal, 12).frame(height: 32)
                }.buttonStyle(.plain)
                Divider().padding(.horizontal, 12)
            }

            if results.isEmpty {
                ContentUnavailableView("No matching Spaces", systemImage: "square.grid.2x2", description: Text("Try another name or alias."))
            } else {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(results.enumerated()), id: \.element.id) { index, profile in
                                row(profile, index: index).id(profile.id)
                            }
                        }.padding(8)
                    }.onChange(of: selected) { _, value in if results.indices.contains(value) { proxy.scrollTo(results[value].id) } }
                }
            }

            Divider().opacity(0.7)
            HStack(spacing: 12) {
                Text("↑↓ Navigate")
                Text("↩ Switch")
                Text("esc Close")
                Spacer()
                Button("Rename") { beginRename() }.buttonStyle(.plain).keyboardShortcut(.return, modifiers: .command)
            }.font(.caption2).foregroundStyle(.tertiary).padding(.horizontal, 12).frame(height: 30)
        }
        .frame(width: 380, height: 410)
        .background(.ultraThickMaterial)
        .onChange(of: query) { selected = 0 }
        .onChange(of: displayFilter) { _, _ in selected = 0; if displayFilter != "all", !model.nativeSpaces.contains(where: { $0.displayID == displayFilter }) { displayFilter = "all" } }
        .onKeyPress(.upArrow) { selected = max(0, selected - 1); return .handled }
        .onKeyPress(.downArrow) { selected = min(max(0, results.count - 1), selected + 1); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
    }

    private func row(_ profile: SpaceProfile, index: Int) -> some View {
        let isSelected = index == selected
        let isCurrent = profile.id == model.activeProfile?.id
        return Button { model.switchTo(profile); onClose() } label: {
            HStack(spacing: 9) {
                Text("\(index + 1)").font(.caption.weight(.semibold).monospacedDigit()).foregroundStyle(.white)
                    .frame(width: 25, height: 25).background(Color(hex: profile.colorHex).opacity(0.82), in: RoundedRectangle(cornerRadius: 6))
                if renamingID == profile.id {
                    TextField("Space name", text: Binding(get: { model.data.spaces.first(where: { $0.id == profile.id })?.name ?? profile.name }, set: { value in var copy = profile; copy.name = value; model.updateProfile(copy) })).onSubmit { renamingID = nil }
                } else {
                    Text(profile.name).fontWeight(isSelected ? .semibold : .regular).lineLimit(1)
                }
                Spacer()
                if let native = model.native(for: profile) { Text("Desktop \(native.index)").font(.caption).foregroundStyle(.tertiary) }
                if isCurrent { Circle().fill(Color(hex: profile.colorHex)).frame(width: 6, height: 6).accessibilityLabel("Current Space") }
            }.padding(.horizontal, 8).frame(height: 38).contentShape(Rectangle())
                .background(isSelected ? Color(hex: profile.colorHex).opacity(isCurrent ? 0.20 : 0.12) : .clear, in: RoundedRectangle(cornerRadius: 7))
                .overlay { if isSelected { RoundedRectangle(cornerRadius: 7).stroke(Color(hex: profile.colorHex).opacity(0.38), lineWidth: 1) } }
        }.buttonStyle(.plain).onHover { if $0 { selected = index } }
    }

    private func activate() { guard results.indices.contains(selected) else { return }; model.switchTo(results[selected]); onClose() }
    private func beginRename() { guard results.indices.contains(selected) else { return }; renamingID = results[selected].id }
}

extension Color {
    init(hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted), radix: 16) ?? 0x7C5CFC
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}
