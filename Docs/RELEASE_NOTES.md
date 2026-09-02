# DeskOrbit 0.2.7 — Forced 0.1.0 Spacing

This release forces every Mission Control label to use the exact equal-slot
geometry from the original Namespaces/DeskOrbit 0.1.0 build. Tahoe accessibility
positions can no longer override or alter that spacing.

- Restores the original Mission Control detection path that worked on the
  affected macOS Tahoe 26.6.2 Mac.
- Restores 0.1.0's deterministic per-display fallback placement. Labels now
  appear even when Tahoe does not expose usable thumbnail bounds through the
  Dock accessibility tree.
- Restores the exact 0.1.0 spacing, widths, vertical position, panel behavior,
  and visual treatment.
- Removes all native-position overrides from label placement. Every display
  always uses the complete 0.1.0 row.
- Keeps newer Mission Control detection and prompt-dismissal behavior separate
  from placement, so those fixes cannot change spacing.
- Retains the fast 50 ms active-session close check and active-Space dismissal
  added after 0.1.0, so labels disappear promptly when Mission Control closes.
- Requests Accessibility once per app version when labels are enabled and
  reports permission state in General Settings.
- “Show names on Mission Control thumbnails” remains enabled by default.

The app remains a self-contained executable with the original Namespaces bundle
identity, so replacing an older copy preserves names, settings, and local data.
