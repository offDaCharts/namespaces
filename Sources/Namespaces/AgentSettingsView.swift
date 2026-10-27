import AppKit
import NamespacesCore
import SwiftUI

struct AgentSettingsView: View {
    @EnvironmentObject var model: AppModel
    @AppStorage(AgentConnection.enabledKey) private var enabled = false
    @AppStorage(AgentConnection.contextKey) private var context = false
    @AppStorage(AgentConnection.titlesKey) private var titles = false
    @State private var client = "Codex"
    @State private var copied = false
    private let clients = ["Codex", "Claude Code", "Claude Desktop", "Cursor", "Other MCP client"]
    private var executable: String { Bundle.main.executableURL?.path ?? "/Applications/DeskOrbit.app/Contents/MacOS/DeskOrbit" }
    private var quotedExecutable: String { "'" + executable.replacingOccurrences(of: "'", with: "'\\''") + "'" }
    private var configuration: String {
        switch client {
        case "Codex": return "codex mcp add deskorbit -- \(quotedExecutable) --mcp"
        case "Claude Code": return "claude mcp add --transport stdio --scope user deskorbit -- \(quotedExecutable) --mcp"
        default:
            let config: [String: Any] = ["mcpServers": ["deskorbit": ["command": executable, "args": ["--mcp"]]]]
            return String(decoding: (try? JSONSerialization.data(withJSONObject: config, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])) ?? Data(), as: UTF8.self)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Label("Your agent, your Spaces", systemImage: "sparkles").font(.title2.bold())
                Text("Ask Claude, Codex, or another local MCP agent to name your desktops and give them a coordinated look.").foregroundStyle(.secondary)
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Allow agent connection", isOn: $enabled)
                        Label(model.agentStatus, systemImage: enabled ? "link" : "link.badge.plus").font(.callout).foregroundStyle(.secondary)
                        Text("Connected agents can read and change Space names, colors and icons, and switch desktops. Only local processes in your macOS account can connect. Turning this off immediately blocks new commands.").font(.caption).foregroundStyle(.secondary)
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Connect once") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Keep DeskOrbit in Applications and running while your agent uses it.").font(.callout)
                        Picker("Agent", selection: $client) { ForEach(clients, id: \.self) { Text($0) } }.frame(maxWidth: 320)
                        Text(client == "Codex" || client == "Claude Code" ? "Run this command in Terminal, then start a new agent session." : client == "Claude Desktop" ? "Merge this entry into Claude Desktop's Developer → Edit Config, then restart Claude." : "Add this entry in your client's local MCP configuration. Preserve any existing servers.").font(.callout).foregroundStyle(.secondary)
                        Text(configuration).font(.system(.caption, design: .monospaced)).textSelection(.enabled).fixedSize(horizontal: false, vertical: true).padding(12).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                        Button(copied ? "Copied" : "Copy setup") { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(configuration, forType: .string); copied = true }
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Optional naming suggestions") {
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle("Share app/window context", isOn: $context).disabled(!enabled)
                        Text("Shares app names and Space assignments when your agent requests them. Your agent may send this information to its AI provider. DeskOrbit does not collect screenshots or document contents.").font(.caption).foregroundStyle(.secondary)
                        Toggle("Also allow window titles", isOn: $titles).disabled(!enabled || !context)
                        Text("Titles may contain private document names. They are shared only when requested, and macOS Screen Recording permission may be required. DeskOrbit never requests that permission automatically.").font(.caption).foregroundStyle(.secondary)
                    }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
                }
                Text("Try: “Use DeskOrbit to name my five desktops Build, Research, Messages, Personal, and Music. Show me a coordinated palette, then apply it.”").font(.callout).textSelection(.enabled)
                Text("Need more desktops? Add them with the + button in Mission Control, then ask your agent to refresh. Cloud-only chats cannot access this local connection.").font(.caption).foregroundStyle(.secondary)
            }.padding(24).frame(maxWidth: 800, alignment: .leading).frame(maxWidth: .infinity, alignment: .leading)
        }
        .onChange(of: enabled) { _, _ in model.agentConnection.configure() }
        .onChange(of: client) { _, _ in copied = false }
    }
}
