# DeskOrbit 0.2.5 — Original Overlay Restoration

This release restores the Mission Control overlay implementation and spacing
from the original Namespaces/DeskOrbit 0.1.0 build, while retaining the later
single-executable launch and prompt-dismissal fixes.

- Restores the original Mission Control detection path that worked on the
  affected macOS Tahoe 26.6.2 Mac.
- Restores 0.1.0's deterministic per-display fallback placement. Labels now
  appear even when Tahoe does not expose usable thumbnail bounds through the
  Dock accessibility tree.
- Restores the exact 0.1.0 spacing, widths, vertical position, panel behavior,
  and visual treatment.
- Still prefers live Dock accessibility positions when macOS exposes them.
- Retains the fast 50 ms active-session close check and active-Space dismissal
  added after 0.1.0, so labels disappear promptly when Mission Control closes.
- Requests Accessibility once per app version when labels are enabled and
  reports permission state in General Settings.
- “Show names on Mission Control thumbnails” remains enabled by default.

The app remains a self-contained executable with the original Namespaces bundle
identity, so replacing an older copy preserves names, settings, and local data.
