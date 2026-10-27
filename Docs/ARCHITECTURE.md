# Architecture

Updated: 2026-10-27.

`NamespacesCore` owns Codable domain records, SwiftData/JSON persistence,
search, topology comparison, reconciliation scoring, backup packaging, and CSV.
The `Namespaces` executable owns AppKit/SwiftUI presentation and macOS adapters.
All private WindowServer symbol resolution is isolated in
`EnhancedSpaceProvider` and the opt-in `WindowContext` adapter; UI calls the
`SpaceProviding` capability surface.
Automation execution is actor-serialized and uses explicit `Process` arguments.

Dependency direction is `Namespaces -> NamespacesCore`; Core never imports the
app. Apple frameworks are linked by the executable. There are no third-party
runtime dependencies or dependency cycles.

The Swift package is the source of truth and opens directly in Xcode. This keeps
the project reproducible without generated `.xcodeproj` files.

## Local agents and identity

The app executable checks `--mcp` before AppKit startup. In that mode it serves
newline-delimited JSON-RPC on stdio, with only MCP tools capabilities, and sends
tool calls to `AgentConnection` in the running GUI over owner-restricted Unix
IPC. Only the GUI mutates AppData; valid style batches are committed together
and awaited for persistence. The listener uses a single-owner lock, peer-UID
checks, generation revocation, 256 KiB messages, eight workers and five-second
socket timeouts. Accepted Darwin sockets explicitly clear inherited nonblocking
mode. Helpers never initialize the GUI, tracking, license networking or storage.

`SpaceIdentity` matches unique native UUIDs globally, then unique compatible
numeric IDs, independent of display location. It reserves matches before
creating new records, preserves ambiguous duplicates for manual relinking, and
never reattaches by desktop ordinal. Monitor notifications pause tracking for
the settling interval, debounce refresh and schedule two later refreshes.
`WindowPlacement` clamps complete app windows to the best intersecting visible
screen, including negative display origins and reduced vertical space.

## Mission Control integration

`MissionControlObserver` listens for the Dock's accessibility Exposé lifecycle
notifications, independent of the input method that opened Mission Control. A
conservative, throttled `CGWindowListCopyWindowInfo` scan repairs missed open or
close transitions. `MissionControlLabelLocator` uses v0.1.0's Dock AX traversal,
matches Apple's desktop ordinals to native Space topology, converts Quartz
coordinates to AppKit coordinates, and centers each badge on the native anchor.
There is intentionally no estimated equal-slot fallback: missing approval or
missing anchors produces a diagnostic instead of incorrectly spaced labels.

`OverlayController` owns one reusable, nonactivating, click-through `NSPanel`
per visible desktop. Panels use the screen-saver window level, join all Spaces,
refresh only while Mission Control is active, and disappear after the confirmed
close transition. This is an overlay: Namespaces never injects into the Dock or
changes Apple's native Desktop strings. Mission Control AX details are
undocumented, so the integration exposes status, preserves names when unavailable,
and preserves names when macOS changes.
