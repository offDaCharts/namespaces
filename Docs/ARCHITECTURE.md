# Architecture

Last verified: 2026-08-27.

`NamespacesCore` owns Codable domain records, SwiftData/JSON persistence,
search, topology comparison, reconciliation scoring, backup packaging, and CSV.
The `Namespaces` executable owns AppKit/SwiftUI presentation and macOS adapters.
All private WindowServer symbol resolution is isolated in
`EnhancedSpaceProvider`; UI calls only the `SpaceProviding` capability surface.
Automation execution is actor-serialized and uses explicit `Process` arguments.

Dependency direction is `Namespaces -> NamespacesCore`; Core never imports the
app. Apple frameworks are linked by the executable. There are no third-party
runtime dependencies or dependency cycles.

The Swift package is the source of truth and opens directly in Xcode. This keeps
the project reproducible without generated `.xcodeproj` files.

## Mission Control integration

`MissionControlObserver` listens for the Dock's accessibility Exposé lifecycle
notifications, independent of the input method that opened Mission Control. A
conservative, throttled `CGWindowListCopyWindowInfo` scan repairs missed open or
close transitions. `MissionControlLabelLocator` maps the discovered native Space
topology into the exact deterministic per-display layout shipped in v0.1.0.
Placement uses the original screen inset, capped slot width, centering, vertical
offset, and name-width calculation. Dock accessibility geometry never overrides
those frames because Tahoe's partial and apparently complete trees both proved
unstable across machines.

`OverlayController` owns one reusable, nonactivating, click-through `NSPanel`
per visible desktop. Panels use the screen-saver window level, join all Spaces,
refresh only while Mission Control is active, and disappear after the confirmed
close transition. This is an overlay: Namespaces never injects into the Dock or
changes Apple's native Desktop strings. Mission Control AX details are
undocumented, so the integration exposes status, preserves names when unavailable,
and preserves names when macOS changes.
