# Compatibility and Release Test Matrix

Last verified: 2026-08-26, Namespaces 0.1.2.

| Configuration | Build | Discovery | Switching | Overlay | Window move | Status |
|---|---:|---:|---:|---:|---:|---|
| macOS 15.7.4 (24G517), Apple Silicon, one display, six Spaces | Pass | Pass | Provider path pass | Pass | Permission pending | Daily-use candidate |
| macOS 14 Sonoma | CI/build target | Pending hardware | Pending | Pending | Pending | Not yet claimed |
| macOS 26, Apple Silicon | Build toolchain only | Pending hardware | Pending | Pending | Pending | Not yet claimed |
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
reported unavailable. The label fallback remains local and noninteractive.

Mission Control regression checks: Dock AX notification setup/teardown; gesture-
independent WindowServer detection; opening grace and first-scan close; native ordinal parsing;
fallback containment and ordering; long-name non-overlap; multiple-display
candidate scoping; panel reuse; disabled preference; screen topology changes; and
Accessibility revoked/restored while running.
