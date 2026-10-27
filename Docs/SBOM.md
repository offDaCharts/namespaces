# Software Bill of Materials

DeskOrbit 0.3.0 runtime dependency inventory:

| Component | Source | Purpose | Network capable |
|---|---|---|---|
| Swift standard library / SwiftUI / SwiftData | Apple toolchain | App/runtime/storage | No app networking used |
| AppKit / CoreGraphics / ApplicationServices | macOS | UI, Spaces, optional AX | No |
| Carbon | macOS | Global hotkeys | No |
| ServiceManagement | macOS | Opt-in login item | No |
| CryptoKit | macOS | Script approval hashes | No |
| OSLog | macOS | Privacy-safe diagnostics/signposts | No |
| URLSession | Apple Foundation | GitHub release check and license requests | Yes |
| Darwin Unix sockets / Foundation JSON | macOS | Local opt-in MCP IPC | Local only; no TCP/HTTP listener |

DeskOrbit contacts GitHub's public latest-release endpoint and Lemon Squeezy's
HTTPS License API directly with `URLSession`; no networking SDK is embedded.
Sparkle 2.9.6 remains release-time appcast tooling for older versions only and
is not present in the runtime app bundle.

Build and release automation uses GitHub's pinned-major `actions/checkout@v4`
and `actions/upload-artifact@v4`. Neither is included in the application or runs
on an end user's Mac.

The small MCP tools-only protocol implementation is repository-owned Swift.
It adds no third-party runtime packages. Python's standard library is used for
developer/CI subprocess smoke tests only; it is not shipped or required by users.
