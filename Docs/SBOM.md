# Software Bill of Materials

Namespaces 0.1.0 has no third-party runtime packages.

| Component | Source | Purpose | Network capable |
|---|---|---|---|
| Swift standard library / SwiftUI / SwiftData | Apple toolchain | App/runtime/storage | No app networking used |
| AppKit / CoreGraphics / ApplicationServices | macOS | UI, Spaces, optional AX | No |
| Carbon | macOS | Global hotkeys | No |
| ServiceManagement | macOS | Opt-in login item | No |
| CryptoKit | macOS | Script approval hashes | No |
| OSLog | macOS | Privacy-safe diagnostics/signposts | No |
