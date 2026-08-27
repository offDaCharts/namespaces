# DeskOrbit 0.2.0 — Exact Mission Control Alignment

This release replaces DeskOrbit's Mission Control positioning system and gives
the app's primary interface a cohesive native-macOS redesign.

Mission Control labels are now derived only from the Dock accessibility tree's
actual expanded thumbnail rectangles. Compact `Desktop N` text controls,
full-width containers, and guessed equal-width positions are rejected. Every
badge inherits its thumbnail's center and usable width and is refreshed during
the Mission Control animation. When exact geometry is temporarily unavailable,
DeskOrbit waits without drawing an incorrect overlay.

The label treatment is quieter and closer to SpaceJump's demonstrated design:
nearly full-width translucent color plates, restrained 12-point type, a fine
highlight, and minimal shadow. Automated tests cover up to 16 Spaces across
standard, portrait, ultrawide, negative-origin, and multi-display-style frames.

The quick switcher is now a compact material panel with numbered color tiles,
inline search, a display filter, previous-Space access, native desktop metadata,
and lower-key selection styling. Space settings use a dense inset list with
advanced controls disclosed on demand. The menu-bar menu uses the same numbered
color language, making Space identity consistent throughout the app.

The update preserves all existing names, colors, notes, automations, tracking
history, shortcuts, preferences, and license state in the existing local store
and Keychain locations.
