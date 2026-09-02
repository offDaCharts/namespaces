# DeskOrbit 0.2.6 — Stable Original Spacing

This release preserves the Mission Control overlay implementation and exact
fallback geometry from the original Namespaces/DeskOrbit 0.1.0 build while
preventing partial Tahoe accessibility results from disrupting that spacing.

- Restores the original Mission Control detection path that worked on the
  affected macOS Tahoe 26.6.2 Mac.
- Restores 0.1.0's deterministic per-display fallback placement. Labels now
  appear even when Tahoe does not expose usable thumbnail bounds through the
  Dock accessibility tree.
- Restores the exact 0.1.0 spacing, widths, vertical position, panel behavior,
  and visual treatment.
- Applies placement atomically per display: either every label follows a native
  Mission Control position, or the entire display uses the complete 0.1.0 row.
  Native and fallback positions are never mixed within one display.
- Fixes uneven gaps and shifted labels caused when Tahoe exposed positions for
  only some Mission Control thumbnails.
- Still prefers live Dock accessibility positions when macOS exposes them.
- Retains the fast 50 ms active-session close check and active-Space dismissal
  added after 0.1.0, so labels disappear promptly when Mission Control closes.
- Requests Accessibility once per app version when labels are enabled and
  reports permission state in General Settings.
- “Show names on Mission Control thumbnails” remains enabled by default.

The app remains a self-contained executable with the original Namespaces bundle
identity, so replacing an older copy preserves names, settings, and local data.
