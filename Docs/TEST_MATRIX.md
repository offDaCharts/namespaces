# Compatibility and Release Test Matrix

Last verified: 2026-09-02.

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
movement, Shift-drag, and exact Mission Control thumbnail alignment are correctly
reported unavailable. Mission Control labels still use the original 0.1.0
deterministic placement fallback, so they are not hidden merely because Tahoe
withholds thumbnail bounds.

Mission Control regression checks: original WindowServer detection; Dock AX
notification setup/teardown; Accessibility-tree alignment; the exact 0.1.0
fallback algorithm; atomic per-display fallback when AX results are incomplete;
opening grace and first-scan close; native ordinal parsing;
multiple-display candidate scoping; panel reuse; disabled preference; screen
topology changes; and Accessibility revoked/restored while running. Pure layout
tests verify ordering, containment, long-name caps, and non-overlap. Changes to
fallback constants require explicit visual validation against 0.1.0.
