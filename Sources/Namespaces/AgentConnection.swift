import AppKit
import Darwin
import NamespacesCore

/// The GUI is the only writer of AppData. MCP helpers forward requests through
/// a per-user Unix socket and never open or overwrite the database themselves.
@MainActor
final class AgentConnection {
    private weak var model: AppModel?
    private var source: DispatchSourceRead?
    private var lockFD: Int32 = -1
    private var activeConnections = 0
    private var generation = UUID()
    static let enabledKey = "DeskOrbit.agents.enabled"
    static let contextKey = "DeskOrbit.agents.windowContext"
    static let titlesKey = "DeskOrbit.agents.windowTitles"

    init(model: AppModel) { self.model = model }

    func configure() {
        guard UserDefaults.standard.bool(forKey: Self.enabledKey) else { stop(); return }
        guard source == nil else { return }
        do {
            try LocalAgentSocket.prepareDirectory()
            lockFD = open(LocalAgentSocket.directory + "/server.lock", O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
            guard lockFD >= 0, flock(lockFD, LOCK_EX | LOCK_NB) == 0 else { throw AgentError("Another DeskOrbit app is already serving agents. Quit the extra copy.") }
            var info = stat()
            if lstat(LocalAgentSocket.path, &info) == 0 {
                guard (info.st_mode & S_IFMT) == S_IFSOCK, info.st_uid == getuid() else { throw AgentError("Unsafe local agent socket path.") }
                unlink(LocalAgentSocket.path)
            }
            let fd = socket(AF_UNIX, SOCK_STREAM, 0)
            guard fd >= 0 else { throw AgentError("Cannot create agent socket.") }
            var installed = false
            defer { if !installed { close(fd) } }
            LocalAgentSocket.configure(fd)
            guard try LocalAgentSocket.withAddress({ bind(fd, $0, $1) }) == 0,
                  chmod(LocalAgentSocket.path, 0o600) == 0, listen(fd, 8) == 0 else { throw AgentError("Cannot start agent connection.") }
            _ = fcntl(fd, F_SETFL, O_NONBLOCK)
            let watcher = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .main)
            watcher.setEventHandler { [weak self] in
                MainActor.assumeIsolated { self?.acceptConnection(fd) }
            }
            watcher.setCancelHandler { close(fd) }
            source = watcher; installed = true; watcher.resume()
            model?.agentStatus = "Ready for local agents"
        } catch {
            if lockFD >= 0 { close(lockFD); lockFD = -1 }
            model?.agentStatus = error.localizedDescription
        }
    }

    func stop() {
        generation = UUID()
        if source != nil { source?.cancel(); source = nil; unlink(LocalAgentSocket.path) }
        if lockFD >= 0 { close(lockFD); lockFD = -1 }
        model?.agentStatus = "Agent connection is off"
    }

    private func acceptConnection(_ listener: Int32) {
        let fd = accept(listener, nil, nil)
        guard fd >= 0 else { return }
        guard activeConnections < 8, LocalAgentSocket.isSameUser(fd) else { close(fd); return }
        LocalAgentSocket.configure(fd)
        activeConnections += 1
        let expectedGeneration = generation
        Task.detached { [weak self] in
            defer { close(fd) }
            do {
                let request = try JSONDecoder().decode(JSONValue.self, from: LocalAgentSocket.readMessage(fd))
                let reply = await self?.handle(request, generation: expectedGeneration) ?? .object(["error": .string("DeskOrbit closed.")])
                try LocalAgentSocket.writeMessage(reply.encoded(), to: fd)
            } catch {
                try? LocalAgentSocket.writeMessage(JSONValue.object(["error": .string(error.localizedDescription)]).encoded(), to: fd)
            }
            await self?.connectionFinished()
        }
    }

    private func connectionFinished() { activeConnections -= 1 }
    private func handle(_ request: JSONValue, generation expected: UUID) async -> JSONValue {
        do {
            guard expected == generation, UserDefaults.standard.bool(forKey: Self.enabledKey), let model else { throw AgentError("Agent access is disabled.") }
            guard let name = request["name"].string else { throw AgentError("Missing tool name.") }
            let args = request["arguments"]
            try AgentTools.validate(name: name, arguments: args)
            let value = try await model.executeAgentTool(name, arguments: args)
            return .object(["result": value])
        } catch { return .object(["error": .string(error.localizedDescription)]) }
    }
}

extension AppModel {
    func executeAgentTool(_ name: String, arguments: JSONValue) async throws -> JSONValue {
        if topologyIsSettling && ["deskorbit_configure_spaces", "deskorbit_switch_space", "deskorbit_window_context"].contains(name) {
            throw AgentError("Displays are reconnecting. Wait a moment, then list Spaces again before retrying.")
        }
        switch name {
        case "deskorbit_status":
            return .object(["version": .string(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.3.0"),
                "provider": .string(providerName), "can_discover_spaces": .bool(provider.capabilities.contains(.enumerate)),
                "can_create_spaces": .bool(false), "can_switch_spaces": .bool(provider.capabilities.contains(.switchSpace) && license.hasAccess),
                "window_context_enabled": .bool(UserDefaults.standard.bool(forKey: AgentConnection.contextKey)),
                "window_titles_enabled": .bool(UserDefaults.standard.bool(forKey: AgentConnection.titlesKey)),
                "accessibility_granted": .bool(AXIsProcessTrusted()), "screen_recording_granted": .bool(CGPreflightScreenCaptureAccess()),
                "minimum_macos": .string("14.0")])
        case "deskorbit_list_spaces":
            refreshSpaces()
            let available = profilesInDisplayOrder
            let missing = data.spaces.filter { native(for: $0) == nil }
            return .object(["spaces": .array((available + missing).map { profile in
                let observation = native(for: profile)
                return .object(["space_id": .string(profile.id.uuidString), "name": .string(profile.name), "color": .string(profile.colorHex), "symbol": .string(profile.symbol),
                    "available": .bool(observation != nil), "display": observation.map { .string($0.displayName) } ?? .null,
                    "display_id": .string(profile.displayID), "index": observation.map { .number(Double($0.index)) } ?? .null,
                    "active": .bool(observation?.isActive ?? false), "kind": .string(observation?.kind.rawValue ?? profile.lastKnownKind?.rawValue ?? "unknown")])
            }), "can_create_spaces": .bool(false), "topology_settling": .bool(topologyIsSettling)])
        case "deskorbit_palette":
            return .object(["colors": .array(SpacePalette.colors.map { .object(["name": .string($0.name), "hex": .string($0.hex)]) }),
                "symbols": .array(SpaceEdit.symbols.map(JSONValue.string))])
        case "deskorbit_configure_spaces":
            refreshSpaces()
            let edits = try SpaceEdit.parse(arguments["spaces"], profiles: data.spaces, available: Set(profilesInDisplayOrder.map(\.id)))
            let apply = arguments["apply"].bool ?? false
            let changes: [JSONValue] = edits.map { edit in
                let old = data.spaces.first { $0.id == edit.id }!
                return .object(["space_id": .string(edit.id.uuidString), "previous_name": .string(old.name), "name": .string(edit.name), "previous_color": .string(old.colorHex), "color": .string(edit.color), "symbol": .string(edit.symbol)])
            }
            if apply {
                var updated = data
                for edit in edits {
                    guard let index = updated.spaces.firstIndex(where: { $0.id == edit.id }) else { continue }
                    updated.spaces[index].name = edit.name; updated.spaces[index].colorHex = edit.color
                    updated.spaces[index].symbol = edit.symbol; updated.spaces[index].updatedAt = .now
                }
                // Commit the complete batch together. The GUI remains the writer.
                data = updated; presentationRevision += 1; hotkeyRevision += 1
                do { try await saveImmediately() }
                catch {
                    lastError = "Agent changes are visible, but saving failed: \(error.localizedDescription)"
                    scheduleSave()
                    return .object(["applied": .bool(true), "persisted": .bool(false), "changes": .array(changes),
                        "warning": .string("Changes applied in memory; saving failed and will be retried. Do not quit DeskOrbit until the save issue is resolved.")])
                }
            }
            return .object(["applied": .bool(apply), "persisted": .bool(apply), "changes": .array(changes)])
        case "deskorbit_window_context":
            guard UserDefaults.standard.bool(forKey: AgentConnection.contextKey) else { throw AgentError("Enable Share app/window context in DeskOrbit → Settings → Agents first.") }
            let titles = arguments["include_titles"].bool ?? false
            guard !titles || UserDefaults.standard.bool(forKey: AgentConnection.titlesKey) else { throw AgentError("Window titles require a separate opt-in in DeskOrbit → Settings → Agents.") }
            refreshSpaces()
            return WindowContext.snapshot(model: self, includeTitles: titles)
        case "deskorbit_switch_space":
            guard license.hasAccess else { throw AgentError("Activate a DeskOrbit license to switch Spaces after the trial.") }
            refreshSpaces()
            guard let raw = arguments["space_id"].string, let id = UUID(uuidString: raw), let profile = data.spaces.first(where: { $0.id == id }), let space = native(for: profile) else { throw AgentError("Space is unavailable. List Spaces again.") }
            try provider.switchTo(space)
            return .object(["switch_requested": .bool(true), "space_id": .string(raw)])
        default: throw AgentError("Unknown tool.")
        }
    }
}
