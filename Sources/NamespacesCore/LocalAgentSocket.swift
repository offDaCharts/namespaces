import Darwin
import Foundation

public enum LocalAgentSocket {
    public static var directory: String { "/tmp/deskorbit-agent-\(getuid())" }
    public static var path: String { directory + "/bridge.sock" }
    public static let maximumMessageBytes = 262_144

    public static func prepareDirectory() throws {
        if mkdir(directory, 0o700) != 0 && errno != EEXIST { throw AgentError("Cannot create the private agent directory.") }
        var info = stat()
        guard lstat(directory, &info) == 0, (info.st_mode & S_IFMT) == S_IFDIR,
              info.st_uid == getuid(), (info.st_mode & 0o077) == 0 else { throw AgentError("The local agent directory has unsafe ownership or permissions.") }
    }

    public static func withAddress<T>(_ body: (UnsafePointer<sockaddr>, socklen_t) throws -> T) throws -> T {
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        let bytes = Array(path.utf8) + [0]
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw AgentError("Agent socket path is too long.") }
        withUnsafeMutableBytes(of: &address.sun_path) { buffer in buffer.copyBytes(from: bytes) }
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        return try withUnsafePointer(to: &address) { pointer in
            try pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { try body($0, socklen_t(MemoryLayout<sockaddr_un>.size)) }
        }
    }

    public static func configure(_ fd: Int32) {
        // Darwin accept() inherits the listener's nonblocking flag. Each worker
        // must use bounded blocking reads, otherwise a valid request can race
        // the first read and be rejected with EAGAIN before its bytes arrive.
        let flags = fcntl(fd, F_GETFL)
        if flags >= 0 { _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK) }
        var yes: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &yes, socklen_t(MemoryLayout.size(ofValue: yes)))
        var timeout = timeval(tv_sec: 5, tv_usec: 0)
        setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &timeout, socklen_t(MemoryLayout.size(ofValue: timeout)))
        _ = fcntl(fd, F_SETFD, FD_CLOEXEC)
    }

    public static func isSameUser(_ fd: Int32) -> Bool {
        var uid: uid_t = 0; var gid: gid_t = 0
        return getpeereid(fd, &uid, &gid) == 0 && uid == getuid()
    }

    public static func readMessage(_ fd: Int32) throws -> Data {
        var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while data.count <= maximumMessageBytes {
            let count = Darwin.read(fd, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            guard count > 0 else { throw AgentError("Agent connection closed or timed out.") }
            let chunk = buffer.prefix(count)
            if let newline = chunk.firstIndex(of: 10) {
                data.append(contentsOf: chunk.prefix(newline))
                guard data.count <= maximumMessageBytes else { throw AgentError("Message is too large.") }
                return data
            }
            data.append(contentsOf: chunk)
        }
        throw AgentError("Message is too large.")
    }

    public static func writeMessage(_ data: Data, to fd: Int32) throws {
        guard data.count <= maximumMessageBytes else { throw AgentError("Response is too large. Narrow the request.") }
        let framed = data + Data([10])
        try framed.withUnsafeBytes { buffer in
            var offset = 0
            while offset < buffer.count {
                let count = Darwin.write(fd, buffer.baseAddress!.advanced(by: offset), buffer.count - offset)
                if count < 0 && errno == EINTR { continue }
                guard count > 0 else { throw AgentError("Cannot write to agent connection.") }
                offset += count
            }
        }
    }

    public static func call(name: String, arguments: JSONValue) throws -> JSONValue {
        try prepareDirectory()
        let fd = socket(AF_UNIX, SOCK_STREAM, 0)
        guard fd >= 0 else { throw AgentError("Could not open the local agent connection.") }
        defer { close(fd) }; configure(fd)
        let connected = try withAddress { connect(fd, $0, $1) }
        guard connected == 0, isSameUser(fd) else { throw AgentError("Open DeskOrbit and enable Settings → Agents → Allow agent connection. The app must be running on this Mac.") }
        try writeMessage(JSONValue.object(["name": .string(name), "arguments": arguments]).encoded(), to: fd)
        let reply = try JSONDecoder().decode(JSONValue.self, from: readMessage(fd))
        if let error = reply["error"].string { throw AgentError(error) }
        return reply["result"]
    }

    public static func runStdio() {
        var session = MCPProtocol()
        // Read bounded chunks: readLine() would allocate without a size limit.
        var pending = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = Darwin.read(STDIN_FILENO, &buffer, buffer.count)
            if count < 0 && errno == EINTR { continue }
            if count <= 0 { return }
            for byte in buffer.prefix(count) {
                if byte == 10 {
                    if let reply = session.response(to: pending, execute: call), let encoded = try? reply.encoded() {
                        do { try writeMessage(encoded, to: STDOUT_FILENO) } catch { return }
                    }
                    pending.removeAll(keepingCapacity: true)
                } else {
                    pending.append(byte)
                    if pending.count > maximumMessageBytes { return }
                }
            }
        }
    }
}
