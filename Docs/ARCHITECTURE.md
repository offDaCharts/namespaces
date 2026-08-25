# Architecture

Last verified: 2026-08-25, Namespaces 0.1.0.

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
