# DeskOrbit 0.2.3 — Single-Executable Tahoe Fix

This release fixes the actual packaging regression that made DeskOrbit appear
not to open on macOS Tahoe even though the earlier Namespaces releases opened.

- Removed the embedded Sparkle framework, updater app, two XPC services, and
  autoupdate helper from the runtime app bundle.
- Restored the single-executable bundle structure used by the working Namespaces
  releases. CI rejects any future build that accidentally embeds frameworks or
  XPC services.
- Restored the original `com.offdacharts.namespaces` bundle identity. The
  visible product name remains DeskOrbit, but macOS can now associate it with
  the already-approved Namespaces app and its existing UserDefaults/TCC state.
- Replaced Sparkle at runtime with a small update checker built from Apple system
  frameworks. It offers the latest GitHub release for manual replacement.
- Replacing DeskOrbit never changes `~/Library/Application Support/Namespaces`,
  UserDefaults, or Keychain data, so names, notes, tracking, preferences, and
  license state survive updates.
- Restored enhanced native Spaces discovery and Mission Control labels on Tahoe;
  0.2.2's provisional compatibility-mode diagnosis was incorrect.
- Retained visible post-update launch behavior and privacy-safe launch milestones
  at `~/Library/Logs/DeskOrbit/launch.log`.

Mission Control styling and geometry are unchanged.
