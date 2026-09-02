# Release Candidate Verification

Updated 2026-09-02 on macOS 15.7.4 (24G517), Apple Silicon, Xcode 26.2,
Swift 6.2.3.

- 19 unit/integration tests pass from a clean SwiftPM build.
- Migration-tolerant decoding and SwiftData/JSON persistence round trips pass.
- Backup package round trip preserves data and emits Markdown note files.
- Topology duplicate rejection/diff and conservative reconciliation tests pass.
- Unicode/diacritic search, recency ranking, CSV escaping, shortcut conflicts,
  automation validation, and cold-launch idle boundaries pass.
- Universal Release binary contains `x86_64 arm64` slices.
- Self-contained DMG and universal ZIP verify successfully, preserve the app's
  code signature, and match the published SHA-256 manifest.
- App bundle signature, plist, entitlements, DMG filesystem checksum, and SHA-256
  manifest verify successfully.
- Static offline/dependency and prohibited-log-content scans pass.
- Exact packaged Release app launches, discovers six Spaces, and retains naming.
- An isolated clean first launch produced a visible 720 × 548 onboarding window
  plus the menu-bar item.
- An isolated completed-onboarding launch began menu-bar-only; reopening the
  running app then produced a visible 900 × 702 Settings window.
- The exact release bundle contains one executable and no embedded frameworks,
  updater applications, XPC services, or helper executables.
- The release workflow is gated by a self-contained app launch on GitHub's
  official `macos-26` Apple Silicon runner.
- Five onboarding steps, Spaces, Shortcuts, Tracking, Automation, Data/Backup,
  and Quick Switcher surfaces were inspected live through macOS accessibility UI.
- Quick Switcher search, Escape dismissal, display filter, action buttons, and
  Mission Control/top overlay creation were exercised live.
- Mission Control ordinal parsing, original 0.1.0 fallback ordering/containment,
  long-name non-overlap, and prompt close behavior after positive detection are
  covered by deterministic unit tests. The automation harness cannot synthesize
  the system-wide Mission Control gesture, so live overlay activation remains an
  owner-permission manual check on each supported macOS release.

Not falsely claimed: multi-display and Intel hardware await those environments;
Developer ID/notarization awaits credentials. These do not prevent immediate
private use after macOS approval, and unsupported capabilities fail closed.
