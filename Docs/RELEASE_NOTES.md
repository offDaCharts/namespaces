# Namespaces 0.1.0 — Private Build

This release is usable on the verified Apple Silicon/macOS 15 configuration and
includes naming, navigation, overlays, notes, safe on-click automations, tracking,
backups, diagnostics, and window-movement controls.

Mission Control naming now detects keyboard, trackpad, Dock, and Hot Corner
activation and places a reusable colored name/symbol panel over each matching
desktop control until Mission Control closes. Settings reports whether exact AX
alignment is active and provides a direct Accessibility request. A deterministic
layout fallback prevents missing labels during Mission Control's opening animation.

Known boundaries: Apple does not provide public APIs for direct Spaces metadata,
so enhanced switching/movement uses dynamically resolved private symbols and may
degrade after macOS updates. Namespaces overlays do not rename Apple's own Desktop
labels. Accessibility is required for thumbnail-aligned Mission Control labels,
focused-window movement, and Shift-drag. No updater or network client is included. Developer ID signing,
notarization, Intel hardware verification, multi-display verification, and the AX
window-move manual check require external credentials/hardware/user permission.
