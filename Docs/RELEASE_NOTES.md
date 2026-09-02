# DeskOrbit 0.2.9 — Polished UI, Frozen Placement

This release restores the presentation layer from the researched 0.2.0 macOS UI
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
