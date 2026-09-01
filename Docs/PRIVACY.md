# Privacy and Dependency Policy

Last verified: 2026-09-01, DeskOrbit 0.2.4.

DeskOrbit is local-first. It contains no analytics, advertising, remote
configuration, account requirement, telemetry, or crash-upload networking.
It never captures screenshots, window titles, URLs, clipboard data, document
content, browser history, or keystroke content. Global monitors observe only the
event types/modifiers necessary for configured shortcuts and window movement.
When Mission Control labels are enabled, Accessibility reads the Dock's desktop
control titles, positions, and sizes so labels can be aligned. It does not read
other applications' accessibility trees and does not require Screen Recording.

License activation, validation, and deactivation use Lemon Squeezy's License API
over HTTPS. Those requests include only the license key and a Mac instance label;
they exclude Space names, notes, automations, application activity, and tracking
history. DeskOrbit's native update check requests only GitHub's public latest-
release metadata; it does not send Space names, app activity, or a device ID.

New network-capable or data-collection dependencies require owner approval, a
documented purpose, an offline degradation path, an SBOM update, and a privacy
review. Automatic upload SDKs are prohibited. Private data must never be logged;
OSLog/signposts use only static operation names and aggregate state.

DeskOrbit writes a local launch-stage trail to
`~/Library/Logs/DeskOrbit/launch.log`. It contains timestamps and static startup
milestone names only—never Space names, notes, paths, application activity,
license keys, or other user content—and is never uploaded.

Runtime dependency inventory: Apple system frameworks only. Sparkle is used as
release-time tooling to serve older clients but is not linked, embedded, or run
on an end user's Mac. Build CI uses pinned-major GitHub Actions.
