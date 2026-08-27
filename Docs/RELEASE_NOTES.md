# DeskOrbit 0.1.6 — Launch Candidate

This release introduces the DeskOrbit name, Kauibungalow LLC bundle identity,
a 14-day full-feature trial, secure Keychain license storage, Lemon Squeezy
license activation for up to three Macs, and signed Sparkle updates. It is usable
on the verified Apple Silicon/macOS 15 configuration and
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

Known boundaries: Apple does not provide public APIs for direct Spaces metadata,
so enhanced switching/movement uses dynamically resolved private symbols and may
degrade after macOS updates. DeskOrbit overlays do not rename Apple's own Desktop
labels. Accessibility is required for thumbnail-aligned Mission Control labels,
focused-window movement, and Shift-drag. Developer ID signing and notarization are
configured in release automation; Intel hardware, multi-display, and AX
window-move checks still require their respective hardware and user permission.
