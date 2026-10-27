# Talk to DeskOrbit

DeskOrbit 0.3.0 includes a local Model Context Protocol (MCP) server in its
existing app executable. No Node, Python, API key, subscription, or separate
plugin is needed to run it. Python is used only by the developer smoke tests.

## Connect once

1. Put DeskOrbit.app in Applications and open it.
2. Enable **Settings → Agents → Allow agent connection**. It defaults to off.
3. Choose your agent and copy its setup from that screen. The path reflects
   the installed app, including spaces in the path.
4. Restart the client or start a new agent session after adding the server.

For Codex CLI, IDE, and desktop clients using the shared local MCP configuration:

```sh
codex mcp add deskorbit -- /Applications/DeskOrbit.app/Contents/MacOS/DeskOrbit --mcp
```

For Claude Code:

```sh
claude mcp add --transport stdio --scope user deskorbit -- /Applications/DeskOrbit.app/Contents/MacOS/DeskOrbit --mcp
```

For Claude Desktop (Settings → Developer → Edit Config), Cursor's local MCP
configuration, and other clients accepting `mcpServers`, merge this entry into
the existing configuration; do not replace other servers:

```json
{
  "mcpServers": {
    "deskorbit": {
      "command": "/Applications/DeskOrbit.app/Contents/MacOS/DeskOrbit",
      "args": ["--mcp"]
    }
  }
}
```

Other clients may use different configuration keys. Select **stdio** transport,
the executable above, and the single argument `--mcp`. Cloud-only chats and
remote coding environments cannot reach your Mac's local socket. The agent
process must run in the same macOS user account as DeskOrbit. Configuration
instructions are provided; vendor-client end-to-end certification is not claimed.

## Ask naturally

“Use DeskOrbit to name my five desktops Build, Research, Messages, Personal,
and Music. Preview coordinated colors and icons, then apply them.”

“Look at the app groups in my desktops and suggest names. Leave my custom
names alone unless I ask to replace them.”

The second request requires **Share app/window context**, separately opt-in.
It returns app names, bundle IDs and available Space assignments. Window titles
require another local opt-in, an explicit `include_titles: true` request, and
available macOS Screen Recording permission. DeskOrbit never prompts for that
permission automatically. Titles can contain private names or URLs. Context
may be sent to the agent's AI provider; review that provider's policies.

No screenshots, document bodies, notes, tracking history, license keys, or
automation scripts are exposed. Window text is untrusted data, never an
instruction to the agent. Unknown membership is explicitly marked unknown;
an app name alone cannot reliably identify a project.

## Tools and limits

| Tool | Purpose |
|---|---|
| `deskorbit_status` | Capabilities, version and permission state |
| `deskorbit_list_spaces` | Available and unmatched profiles, stable IDs and style |
| `deskorbit_palette` | Coordinated colors and supported icons |
| `deskorbit_configure_spaces` | Preview or apply up to 32 name/color/icon edits |
| `deskorbit_window_context` | Optional app/Space context, optionally titles |
| `deskorbit_switch_space` | Request switching to an existing Space |

Always list first and use returned `space_id` UUIDs, not guessed desktop numbers.
Configure defaults to preview (`apply: false`). Missing colors receive a
coordinated palette; supply the current color to preserve it. Missing icons are
preserved. Every edit is validated before any changes; valid batches update
together. Save failures report `applied: true, persisted: false` with a warning,
so the agent must not tell the user the changes are safely saved.

DeskOrbit does **not** create/delete desktops, move windows, run scripts, or
relink ambiguous saved data through MCP. Add missing desktops using Mission
Control's + button, then list again. Switching follows the app's existing trial/
license policy. During display transitions, wait and relist before changing data.

## Monitor continuity

The profile UUID is DeskOrbit's identity; native WindowServer UUIDs are used to
find that profile after a monitor move or native numeric-ID change. A unique
compatible numeric ID is the fallback for older saved data. Display position
and desktop number are never identity evidence. Renaming preserves notes,
tracking links, aliases, shortcuts and billing settings.

Screen notifications are debounced, with follow-up topology refreshes. Lost
profiles are retained. Ambiguous old duplicates are kept under **Spaces → Saved
but currently unmatched** for explicit relinking. If macOS replaces both the
native UUID and numeric ID, automatic matching cannot be guaranteed. There is
no supported Apple API that promises stable Space identities across every OS
and topology change. Actual unplug/replug testing on external-monitor hardware
remains part of the release checklist.

## Security and troubleshooting

The GUI owns persistence; helpers never open the database. Communication uses
a per-user Unix socket in a verified owner-only 0700 directory, a 0600 socket,
peer UID checks, an exclusive listener lock, bounded messages, bounded worker
connections and timeouts. There is no HTTP port, cloud relay or remote token.
This trusts processes running as your macOS user; it is not per-client identity
authentication. Only enable it for agent clients you trust. Turning it off
rejects subsequent commands; work already applied cannot be undone by disabling.

- **Open DeskOrbit / enable Agents:** keep the GUI running and enable the switch.
- **Another copy is serving:** quit the extra DeskOrbit copy, then toggle on again.
- **Unavailable Space:** list again; reconnect the monitor or relink in Settings.
- **No titles:** title opt-in and macOS permission are independent requirements.
- **No Space membership:** private WindowServer APIs may be unavailable; do not
  infer membership from whichever desktop happens to be active.
- **App moved:** copy setup again with the new executable path.
- **Disable/remove:** turn off the connection in DeskOrbit, then remove the
  `deskorbit` entry using your client's MCP settings.

## Primary references checked for this implementation

- [MCP stdio transport](https://modelcontextprotocol.io/specification/2025-11-25/basic/transports)
- [MCP lifecycle](https://modelcontextprotocol.io/specification/2025-11-25/basic/lifecycle)
- [MCP tools](https://modelcontextprotocol.io/specification/2025-11-25/server/tools)
- [Official OpenAI documentation: Codex MCP](https://developers.openai.com/codex/mcp)
- [Claude Code MCP](https://code.claude.com/docs/en/mcp)
- [Apple window-list API](https://developer.apple.com/documentation/coregraphics/cgwindowlistcopywindowinfo(_:_:))
- [Hammerspoon's Spaces implementation and limitations](https://github.com/Hammerspoon/hammerspoon/blob/master/extensions/spaces/libspaces.m)
- [yabai's window-to-Space implementation](https://github.com/asmvik/yabai/blob/master/src/window.c)

The WindowServer observations above are implementation evidence, not an Apple
compatibility guarantee. Supported deployment target remains macOS 14+.
