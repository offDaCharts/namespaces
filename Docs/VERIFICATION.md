# Release Candidate Verification

Verified 2026-08-25 on macOS 15.7.4 (24G517), Apple Silicon, Xcode 26.2,
Swift 6.2.3.

- 15 unit/integration tests pass from a clean SwiftPM build.
- Migration-tolerant decoding and SwiftData/JSON persistence round trips pass.
- Backup package round trip preserves data and emits Markdown note files.
- Topology duplicate rejection/diff and conservative reconciliation tests pass.
- Unicode/diacritic search, recency ranking, CSV escaping, shortcut conflicts,
  automation validation, and cold-launch idle boundaries pass.
- Universal Release binary contains `x86_64 arm64` slices.
- App bundle signature, plist, entitlements, DMG filesystem checksum, and SHA-256
  manifest verify successfully.
- Static offline/dependency and prohibited-log-content scans pass.
- Exact packaged Release app launches, discovers six Spaces, and retains naming.
- Five onboarding steps, Spaces, Shortcuts, Tracking, Automation, Data/Backup,
  and Quick Switcher surfaces were inspected live through macOS accessibility UI.
- Quick Switcher search, Escape dismissal, display filter, action buttons, and
  Mission Control/top overlay creation were exercised live.

Not falsely claimed: window movement awaits owner-granted Accessibility;
multi-display, Intel hardware, and other macOS releases await those environments;
Developer ID/notarization awaits credentials. These do not prevent immediate
private use on the verified Mac, and unsupported capabilities fail closed.
