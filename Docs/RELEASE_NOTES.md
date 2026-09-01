# DeskOrbit 0.2.2 — Tahoe-Safe Launch

This release fixes DeskOrbit appearing to do nothing when opened on macOS Tahoe
26.6.2 while the same build opened normally on macOS Sequoia.

- Startup now presents DeskOrbit before initializing optional update services.
- macOS 26 starts in Tahoe compatibility mode and does not call undocumented
  WindowServer Spaces functions during launch.
- Settings opens automatically on Tahoe and explains which private-API features
  are temporarily unavailable. Existing names, notes, tracking, preferences, and
  license state are preserved.
- Reopening the app still brings Settings forward.
- A privacy-safe local launch trail is available at
  `~/Library/Logs/DeskOrbit/launch.log` if startup ever needs diagnosis.
- CI now packages and launches the self-contained application on an official
  macOS 26 GitHub runner in addition to the existing macOS 15 test suite.

Mission Control thumbnail styling and geometry are unchanged from 0.2.1.
