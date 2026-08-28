# DeskOrbit 0.2.1 — Reliable Visible Launch

This release fixes a launch experience where DeskOrbit could be running without
showing a visible window or an obvious menu-bar item.

On a first launch, after an update, or when license attention is required,
DeskOrbit now temporarily uses a normal macOS application presence and brings
Onboarding or Settings to the foreground. Reopening DeskOrbit while it is already
running also brings Settings forward instead of silently returning to its hidden
menu-bar process.

The exact Mission Control thumbnail alignment, redesigned overlays, compact quick
switcher, settings interface, and data-preserving update behavior from 0.2.0 are
unchanged.
