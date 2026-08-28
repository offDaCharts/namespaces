# Software Bill of Materials

DeskOrbit 0.2.1 runtime dependency inventory:

| Component | Source | Purpose | Network capable |
|---|---|---|---|
| Swift standard library / SwiftUI / SwiftData | Apple toolchain | App/runtime/storage | No app networking used |
| AppKit / CoreGraphics / ApplicationServices | macOS | UI, Spaces, optional AX | No |
| Carbon | macOS | Global hotkeys | No |
| ServiceManagement | macOS | Opt-in login item | No |
| CryptoKit | macOS | Script approval hashes | No |
| OSLog | macOS | Privacy-safe diagnostics/signposts | No |
| Sparkle 2.9.6 | sparkle-project/Sparkle | Signed software updates | Yes — Kauibungalow update feed only |

DeskOrbit also contacts Lemon Squeezy's HTTPS License API directly with
`URLSession`; no Lemon Squeezy SDK is embedded.

Build and release automation uses GitHub's pinned-major `actions/checkout@v4`
and `actions/upload-artifact@v4`. Neither is included in the application or runs
on an end user's Mac.
