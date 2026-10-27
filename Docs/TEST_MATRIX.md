# Compatibility and Release Test Matrix

Updated: 2026-10-27. The table below records the previous 0.2.9 baseline;
0.3.0-specific evidence and outstanding gates follow.

| Configuration | Build | Discovery | Switching | Overlay | Window move | Status |
|---|---:|---:|---:|---:|---:|---|
| macOS 15.7.4 (24G517), Apple Silicon, one display, six Spaces | Pass | Pass | Provider path pass | Pass | Permission pending | Daily-use candidate |
| macOS 14 Sonoma | CI/build target | Pending hardware | Pending | Pending | Pending | Not yet claimed |
| macOS 26, Apple Silicon GitHub runner | Single-executable package + launch smoke test | Provider startup pass | Pending | Permission pending | Pending | Launch-gated in CI |
| Intel Mac | Universal policy documented | Pending hardware | Pending | Pending | Pending | Not yet claimed |
| Multiple displays / separate Spaces on | Pending hardware | Pending | Pending | Pending | Pending | Not yet claimed |

Manual release checklist: onboarding; Unicode/RTL names; all menu modes; external
and in-app Space switch; Jump Back; search/filter/rename; notes/checklists/export;
automation preflight/change invalidation/timeout; idle/sleep/lock recovery; session
controls/edit audit/CSV; backup round-trip; rolling retention; reset; display
disconnect; VoiceOver; keyboard navigation; Increase Contrast; Reduce Motion;
offline launch and operation; signature verification.

Accessibility permission is user-controlled. Until it is granted, focused-window
movement, Shift-drag, and Mission Control native-anchor placement are correctly
reported unavailable. Guessed label positions are never drawn.

Mission Control regression checks: original WindowServer detection; Dock AX
notification setup/teardown; v0.1.0 native ordinal parsing, coordinate conversion,
and anchor selection; no guessed fallback;
opening grace and first-scan close; native ordinal parsing;
multiple-display candidate scoping; panel reuse; disabled preference; screen
topology changes; and Accessibility revoked/restored while running.

## 0.3.0 agent/monitor additions

- Local macOS 15.7.4: 37 tests, universal packaging, packaged stdio protocol,
  live preview/apply/persist/restore stress test (20 cycles), denied permission
  checks, and optional app/Space context with titles omitted: pass.
- macOS 15/26 CI: packaged stdio and live GUI bridge tests added; require green
  runs for this revision before promotion. The harness waits for startup
  WindowServer discovery and display settling; it requires real desktop edits
  and restoration rather than skipping when discovery is unavailable.
- Monitor topology: five external Spaces merging into the laptop, returning in
  reverse order, numeric-ID churn, UUID matching and legacy duplicates covered
  by fixtures. Physical unplug/replug still pending, not implied by fixture pass.
- Display geometry: five visible sizes from 800×550 to 3840×2100, portrait-like
  tall windows and negative monitor origins pass pure layout tests.
- Native UI: initial Settings AX inspection passed; remaining Agents screenshot,
  narrow-window, light/dark, keyboard/VoiceOver and Increase Contrast checks
  blocked by native computer-use pipe failure. Resume these before public release.
- Codex/Claude/Cursor: official setup documentation supplied; actual client
  connection acceptance remains a manual check in those clients.
- Titles: verify permission combinations with disposable fixture titles before
  shipping; do not use private user document titles in QA logs.
- Disable: verify new commands rejected after toggle-off; process stop/offline
  rejection and non-persisted launch-only test permission overrides are checked.
