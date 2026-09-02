# DeskOrbit 0.2.8 — Restore v0.1.0 Native Anchors

This release corrects the earlier misunderstanding of v0.1.0's placement
approach. Its good spacing came from Apple's real Mission Control control
positions—not from the equal-slot emergency fallback.

- Restores v0.1.0's Dock Accessibility traversal, desktop-ordinal matching,
  coordinate conversion, candidate scoring, and native-anchor badge placement.
- Deletes guessed equal-slot placement from the runtime and core library.
  Missing permission or missing native anchors now produces no incorrectly
  spaced label instead of a convincing but misaligned row.
- Reports the exact native-anchor count after every Mission Control session,
  such as `8/8 native v0.1.0 anchors`.
- Explains the current ad-hoc signing limitation in General Settings. Every new
  build has a different macOS Accessibility identity until Developer ID signing
  is configured, so the replacement app may need to be removed and re-added in
  Privacy & Security → Accessibility.
- Retains the Tahoe launch fix and prompt Mission Control dismissal behavior.

The app remains self-contained and keeps the original Namespaces bundle ID, so
replacing the application preserves names, settings, and local data.
