# DeskOrbit 0.2.4 — Tahoe Mission Control Detection

This release restores automatic Space-name overlays in Mission Control on macOS
Tahoe while retaining 0.2.3's single-executable launch fix.

- Detects Tahoe's actual Mission Control signature: a display-sized,
  non-shareable Dock window at WindowServer layer 18.
- Removes the older requirement for a second unnamed Dock companion window and
  no longer filters the relevant desktop-level window out of the scan.
- Independently detects visible Mission Control thumbnails through the Dock's
  Accessibility tree, covering gestures, keyboard shortcuts, Hot Corners, and
  future WindowServer presentation changes.
- Requests Accessibility again once per app version when labels are enabled.
  This is necessary because each ad-hoc-signed build receives a new code identity
  until Developer ID signing is configured.
- General Settings now clearly reports when the label preference is enabled but
  Accessibility is not actually trusted, with a direct link to re-approve it.
- “Show names on Mission Control thumbnails” remains enabled by default.

The app remains one executable with the original Namespaces bundle identity;
names, settings, and other local data are preserved across replacement.
