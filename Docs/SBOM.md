# Software Bill of Materials

DeskOrbit 0.2.9 runtime dependency inventory:

| Component | Source | Purpose | Network capable |
|---|---|---|---|
| Swift standard library / SwiftUI / SwiftData | Apple toolchain | App/runtime/storage | No app networking used |
| AppKit / CoreGraphics / ApplicationServices | macOS | UI, Spaces, optional AX | No |
| Carbon | macOS | Global hotkeys | No |
| ServiceManagement | macOS | Opt-in login item | No |
| CryptoKit | macOS | Script approval hashes | No |
| OSLog | macOS | Privacy-safe diagnostics/signposts | No |
| URLSession | Apple Foundation | GitHub release check and license requests | Yes |

DeskOrbit contacts GitHub's public latest-release endpoint and Lemon Squeezy's
HTTPS License API directly with `URLSession`; no networking SDK is embedded.
Sparkle 2.9.6 remains release-time appcast tooling for older versions only and
is not present in the runtime app bundle.

Build and release automation uses GitHub's pinned-major `actions/checkout@v4`
and `actions/upload-artifact@v4`. Neither is included in the application or runs
on an end user's Mac.
