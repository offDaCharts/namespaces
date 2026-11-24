# DeskOrbit 0.3.1

First signed and notarized public release. Licenses now come from Gumroad.

- **Buy and activate through Gumroad.** Paste the key from your receipt in
  Settings → License. One purchase covers up to 3 Macs.
- **Free beta keys.** Beta testers' keys work through Feb 28, 2027, with a
  thank-you discount on the full version afterwards.
- **Send Feedback / Report a Bug** in the menu bar menu: write a note, review
  the exact diagnostics (macOS version, displays and scaling, Spaces count;
  never names, notes or window titles), then send by email or as a GitHub issue.
- **Crash reports are opt-in.** After a crash DeskOrbit asks once whether to
  send the report, and shows it first.
- Mission Control labels now appear on non-English Macs (German, French,
  Spanish, Japanese, Chinese and more).
- Labels no longer overlap with many Spaces on a small screen.
- Two identical monitors, and "Displays have separate Spaces" turned off, now
  get the right labels (matched by display UUID).
- A refunded key stops working; network outages still keep an activated Mac
  working.
- Settings rows wrap instead of cutting off at the smallest window size.

## Included from 0.3.0 — Talk to Your Spaces

- Adds a built-in, local MCP connection for Codex, Claude Code, Claude Desktop,
  Cursor and compatible stdio clients, with copyable setup in Settings → Agents.
- Names and styles up to 32 existing Spaces in one validated batch. Preview is
  the default; omitted colors use a coordinated palette. No extra runtime needed.
- Offers app/window-based naming context behind a separate opt-in. Window titles
  require another explicit opt-in and request. Notes, tracking, scripts and
  license data are never exposed to agents.
- Keeps names, colors and profile-linked data attached across monitor moves
  using native Space UUIDs, with compatible numeric-ID fallback for older data.
  Preserves uncertain matches for manual relinking instead of using desktop order.
- Debounces display reconfiguration, pauses tracking while the topology settles,
  and retries discovery afterward. Agent changes wait during reconnection.
- Fits complete app windows into the visible screen area, supports shorter
  Settings windows, makes onboarding resizable and adapts Space-detail controls.
- Fixes Quick Switcher's Last shortcut targeting the current Space, resets stale
  display filters after disconnection and makes profile editing resilient to
  topology-driven list changes.
- Keeps the established Mission Control anchor placement unchanged.

Compatibility: macOS 14+; universal Apple Silicon/Intel binary. Full matrix and
remaining physical-monitor, Intel, macOS 14 and visual checks are recorded in
`TEST_MATRIX.md` and `VERIFICATION.md`. This release cannot create native desktops
or guarantee identity if macOS replaces both native identifiers.

## Included public-launch preparation


- Updates the commercial offer to a $9.99 one-time purchase with a 14-day trial
  and three Mac activations.
- Adds a privacy-redacted support report that is previewed before explicit copy
  or save; DeskOrbit does not upload it.
- Gives each installation a stable activation-label suffix so similarly named
  Macs can be managed safely.
- Makes public release automation fail closed unless Developer ID,
  notarization, and Sparkle signing credentials are present.
- Leaves the proven v0.1.0 Mission Control anchor placement and the current
  overlay lifecycle untouched.

## Previous release: 0.2.9 — Polished UI, Frozen Placement

That release restores the presentation layer from the researched 0.2.0 macOS UI
pass without changing the working 0.2.8 Mission Control placement or lifecycle.

- Restores the refined Mission Control badge treatment: 12-point rounded
  semibold type, slightly softer color opacity, a subtle half-point highlight,
  reduced shadow, and graceful scaling for longer names.
- Keeps every label frame exactly as supplied by the v0.1.0 native-anchor path.
  Anchor discovery, coordinate conversion, frame calculation, panel placement,
  refresh timing, window level, and dismissal are unchanged from 0.2.8.
- Retains the polished 0.2.0 Quick Switcher and compact Spaces settings list,
  which were already present in the current codebase.
- Refines the Accessibility warning into a compact native-style status callout
  while preserving the anchor-count diagnostics that identified the prior issue.

The app remains self-contained and preserves existing names, settings, notes,
tracking data, and other local data when replaced.
