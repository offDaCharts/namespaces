# Namespaces 0.1.1 — Private Build

This release is usable on the verified Apple Silicon/macOS 15 configuration and
includes naming, navigation, overlays, notes, safe on-click automations, tracking,
backups, diagnostics, and window-movement controls.

Prebuilt universal DMG and ZIP downloads are now published through GitHub
Releases. Destination Macs do not need Xcode, Swift, Homebrew, or a source clone.
The release pipeline verifies both architectures, the app signature, archive
integrity, and SHA-256 checksums before publishing.

Mission Control naming now detects keyboard, trackpad, Dock, and Hot Corner
activation and places a reusable colored name panel over each matching
desktop control until Mission Control closes. Settings reports whether exact AX
alignment is active and provides a direct Accessibility request. A deterministic
layout fallback prevents missing labels during Mission Control's opening animation.
The thumbnail treatment now mirrors SpaceJump's official demo more closely:
compact text-only translucent pills inset at the bottom of each preview, with
smaller type, restrained rounding, and a minimal shadow. Confirmed Mission
Control exits remove all panels on the first missing WindowServer scan.
Version 0.1.1 also adds a fast close-state observer and suppresses the animated
fallback as soon as Mission Control's real thumbnail anchors disappear, so
labels do not linger over ordinary application windows after dismissal.

Installing a newer app bundle preserves all user data because settings and
content live outside the bundle in `~/Library/Application Support/Namespaces`.
Updates are currently installed manually from GitHub Releases; replacing the app
in Applications does not reset names, preferences, notes, or tracking history.

Known boundaries: Apple does not provide public APIs for direct Spaces metadata,
so enhanced switching/movement uses dynamically resolved private symbols and may
degrade after macOS updates. Namespaces overlays do not rename Apple's own Desktop
labels. Accessibility is required for thumbnail-aligned Mission Control labels,
focused-window movement, and Shift-drag. No automatic updater or network client is included. Developer ID signing,
notarization, Intel hardware verification, multi-display verification, and the AX
window-move manual check require external credentials/hardware/user permission.
