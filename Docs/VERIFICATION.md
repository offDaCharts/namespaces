# Release Candidate Verification

## 0.3.0 candidate — 2026-10-27

Local environment: macOS 15.7.4, Apple Silicon, Xcode 26.2 / Swift 6.2.3.

- 37 tests pass, including 18 new identity, batch-validation, MCP lifecycle,
  socket framing and screen geometry tests.
- Five-Space merge/reconnect/reorder simulation preserves profile IDs and style;
  recycled IDs, UUID changes, duplicate legacy records and no-guess behavior pass.
- Universal arm64/x86_64 Release build passes with one executable and no helpers.
- Exact packaged MCP binary passes initialize, notifications, discovery,
  validation, ping and EOF shutdown checks without opening the GUI.
- Live GUI bridge passes preview/no-mutation, all-or-nothing invalid-batch
  rejection, palette, apply/persist and restoration. Twenty consecutive complete
  live cycles passed after fixing Darwin's inherited nonblocking socket flag.
- Optional app/Space context works locally; tests inspect structure without
  logging app/window content. Titles remain omitted; disabled-context/title
  requests fail closed. No Screen Recording permission was requested.
- Local socket ownership/mode verified: 0700 directory, 0600 socket.
- Temporary test styling was restored; test permission overrides are launch-only,
  not persisted defaults. Existing local names and data are retained.
- Initial native Settings accessibility inspection passed (three discovered
  Spaces, existing names, unmatched records retained, new Agents navigation).
  Further screenshot/interaction QA was blocked by the computer-use backend
  error “Sky Computer Use native pipe closed before response”, including retries
  and a runtime reset. Do not mark Agents layout/light/dark/VoiceOver QA complete.
- Geometry tests cover 800×550, 1280×700, 1920×1050, 2560×1400 and 3840×2100
  visible areas, negative origins, oversized and offscreen windows. These are
  deterministic geometry checks, not screenshots or physical monitor tests.
- CI now includes live packaged MCP tests on macOS 15 and macOS 26; record run
  results before promotion. No vendor agent-client live certification is claimed.

Public release blockers: Developer ID Application certificate/private key and
notarization credentials are absent locally and in GitHub. Only Apple Development
and iPhone Distribution identities are installed. Keep release as draft and do
not update the public latest release/appcast until signing and QA gates pass.

Outstanding: real external-monitor unplug/replug (both separate-Spaces modes),
macOS 14 runtime, physical Intel hardware, native Agents UI visual/accessibility
checks, and live Codex/Claude client setup. Private WindowServer behavior is not
guaranteed on every future macOS release.

## Historical 0.2.9 verification (not rerun in full for 0.3.0)

Recorded 2026-09-02 on macOS 15.7.4 (24G517), Apple Silicon, Xcode 26.2,
Swift 6.2.3.

- 19 unit/integration tests pass from a clean SwiftPM build, including the
  approved commercial offer and trial-boundary/clock-rollback policy.
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
- The privacy-redacted support report requires an explicit preview followed by
  a separate copy or save action; it has no upload action.
- Public release automation fails closed when any Developer ID, notarization,
  or Sparkle signing credential is absent.
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
- Mission Control ordinal parsing and prompt close behavior after positive
  detection are covered by deterministic unit tests. The automation harness cannot synthesize
  the system-wide Mission Control gesture, so live overlay activation remains an
  owner-permission manual check on each supported macOS release.

Not falsely claimed: multi-display and Intel hardware await those environments;
Developer ID/notarization awaits credentials. These do not prevent immediate
private use after macOS approval, and unsupported capabilities fail closed.
