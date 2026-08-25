import AppKit
import NamespacesCore
import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var model: AppModel
    @State private var page = 0
    let complete: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Group { switch page {
            case 0: welcome
            case 1: capabilities
            case 2: permission
            case 3: naming
            default: privacy
            } }.frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
            HStack { Text("Step \(page + 1) of 5").foregroundStyle(.secondary); Spacer(); if page > 0 { Button("Back") { page -= 1 } }; if page < 4 { Button("Continue") { page += 1 }.keyboardShortcut(.defaultAction) } else { Button("Start Using Namespaces") { UserDefaults.standard.set(true, forKey: "didCompleteOnboarding"); complete() }.keyboardShortcut(.defaultAction) } }.padding(18)
        }
    }

    private var welcome: some View { VStack(spacing: 20) { Image(systemName: "square.grid.2x2.fill").font(.system(size: 82)).foregroundStyle(.tint); Text("Welcome to Namespaces").font(.largeTitle.bold()); Text("Give native macOS Spaces meaningful names, switch instantly, keep local notes, run deliberate workspace routines, and understand where your time goes.").multilineTextAlignment(.center).foregroundStyle(.secondary).frame(maxWidth: 520); Label("Private and local by default", systemImage: "hand.raised.fill").font(.headline) }.padding(40) }

    private var capabilities: some View { VStack(alignment: .leading, spacing: 16) { Text("Your Mac").font(.largeTitle.bold()); Text(model.capabilityMessage).foregroundStyle(.secondary); status("Native Space discovery", model.provider.capabilities.contains(.enumerate)); status("Direct Space switching", model.provider.capabilities.contains(.switchSpace)); status("Window movement", model.provider.capabilities.contains(.moveWindow)); status("Mission Control labels", model.provider.capabilities.contains(.missionControlLabels)); HStack { Button("Scan Again") { model.selectProvider(); model.refreshSpaces() }; Text("\(model.nativeSpaces.count) Spaces found").foregroundStyle(.secondary) } }.padding(40).frame(maxWidth: 620, alignment: .leading) }

    private var permission: some View { VStack(alignment: .leading, spacing: 18) { Text("Accessibility Is Optional").font(.largeTitle.bold()); Text("Naming, menus, switching, notes, tracking, backups, and automations work without reading screen contents. Accessibility is used only to identify the standard window you deliberately move and to observe global drag/key gestures.").foregroundStyle(.secondary); status("Accessibility", AXIsProcessTrusted()); HStack { Button("Grant Accessibility…") { let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary; _ = AXIsProcessTrustedWithOptions(options) }; Button("Not Now") { page += 1 } }; Text("Namespaces never requests Screen Recording and never stores window titles, document paths, keystrokes, clipboard content, or screenshots.").font(.caption).foregroundStyle(.secondary) }.padding(40).frame(maxWidth: 620, alignment: .leading) }

    private var naming: some View { VStack(alignment: .leading, spacing: 14) { Text("Name Your Spaces").font(.largeTitle.bold()); Text("You can refine symbols, colors, aliases, and shortcuts later in Settings.").foregroundStyle(.secondary); ScrollView { VStack { ForEach(model.nativeSpaces) { native in if let profile = model.profile(for: native), let index = model.data.spaces.firstIndex(where: { $0.id == profile.id }) { HStack { Image(systemName: profile.symbol).foregroundStyle(Color(hex: profile.colorHex)); Text("\(native.index)").foregroundStyle(.secondary).frame(width: 24); TextField("Space name", text: Binding(get: { model.data.spaces[index].name }, set: { var updated = model.data.spaces[index]; updated.name = $0; model.updateProfile(updated) })); Text(native.displayName).font(.caption).foregroundStyle(.secondary) }.padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 9)) } } } } }.padding(40) }

    private var privacy: some View { VStack(alignment: .leading, spacing: 18) { Text("Ready to Go").font(.largeTitle.bold()); Label("No account or sign-in", systemImage: "person.crop.circle.badge.checkmark"); Label("No analytics, telemetry, ads, or automatic crash uploads", systemImage: "network.slash"); Label("Readable local data and user-controlled exports", systemImage: "externaldrive"); Label("Experimental macOS integration fails closed", systemImage: "checkmark.shield"); Text("Your data lives in ~/Library/Application Support/Namespaces. The app remains useful offline.").foregroundStyle(.secondary).padding(.top) }.padding(40).frame(maxWidth: 620, alignment: .leading) }
    private func status(_ name: String, _ available: Bool) -> some View { HStack { Image(systemName: available ? "checkmark.circle.fill" : "exclamationmark.triangle.fill").foregroundStyle(available ? .green : .orange); Text(name); Spacer(); Text(available ? "Available" : "Unavailable").foregroundStyle(.secondary) }.padding(11).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 9)) }
}
