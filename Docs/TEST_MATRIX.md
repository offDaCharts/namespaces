# Compatibility and Release Test Matrix

Last verified: 2026-09-01.

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
reported unavailable. Labels remain hidden until exact thumbnail bounds are available.

Mission Control regression checks: Dock AX notification setup/teardown; gesture-
independent WindowServer detection; opening grace and first-scan close; native ordinal parsing;
compact-label and full-width-container rejection; multiple-display candidate
scoping; panel reuse; disabled preference; screen topology changes; and
Accessibility revoked/restored while running. Pure geometry tests cover 1–16
thumbnails across standard, portrait, ultrawide, negative-origin, and
multi-display-style frames. No release may reintroduce estimated positions.
