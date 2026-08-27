# Architecture

Last verified: 2026-08-26, Namespaces 0.1.3.

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
close transitions. `MissionControlLabelLocator` walks only the Dock AX tree,
matches Apple's desktop ordinals to the existing native Space topology, converts
Quartz coordinates to AppKit coordinates, and produces one label target per
desktop. A deterministic top-row layout covers the brief opening animation
before the AX hierarchy settles.

`OverlayController` owns one reusable, nonactivating, click-through `NSPanel`
per visible desktop. Panels use the screen-saver window level, join all Spaces,
refresh only while Mission Control is active, and disappear after the confirmed
close transition. This is an overlay: Namespaces never injects into the Dock or
changes Apple's native Desktop strings. Mission Control AX details are
undocumented, so the integration exposes status, preserves names when unavailable,
and fails closed after macOS changes.
