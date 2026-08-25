# Namespaces 0.1.0 — Private Build

This release is usable on the verified Apple Silicon/macOS 15 configuration and
includes naming, navigation, overlays, notes, safe on-click automations, tracking,
backups, diagnostics, and window-movement controls.

Known boundaries: Apple does not provide public APIs for direct Spaces metadata,
so enhanced switching/movement uses dynamically resolved private symbols and may
degrade after macOS updates. Namespaces overlays do not rename Apple's own Desktop
labels. Accessibility is required only for focused-window/drag movement and the
ordinal fallback. No updater or network client is included. Developer ID signing,
notarization, Intel hardware verification, multi-display verification, and the AX
window-move manual check require external credentials/hardware/user permission.
