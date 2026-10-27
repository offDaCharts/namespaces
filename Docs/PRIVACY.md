# Privacy and Dependency Policy

Updated: 2026-10-27, DeskOrbit 0.3.0 candidate.

DeskOrbit is local-first. It contains no analytics, advertising, remote
configuration, account requirement, telemetry, or crash-upload networking.
It never captures screenshots, clipboard data, document content, browser history,
or keystroke content. Window titles are excluded by default; see the explicit
agent opt-ins below. Global monitors observe only the
event types/modifiers necessary for configured shortcuts and window movement.
When Mission Control labels are enabled, Accessibility observes the Dock's
Mission Control lifecycle notifications and reads its desktop control titles,
positions, and sizes. It does not read other applications' accessibility trees
and does not require Screen Recording.

The local MCP connection defaults to off. When enabled, processes in the same
macOS account can read and edit Space names/colors/icons and request switching.
Optional app/window context shares app names, bundle IDs and Space assignments
only on request. A separate title toggle and an explicit request are needed to
include window titles, which may contain private names or URLs. macOS permission
may also be required; DeskOrbit does not request it automatically. Context is
not saved to the database or logged. Connected agents may transmit returned
information to their own providers. No notes, tracking records, automation
scripts, license keys or document bodies are exposed by MCP. Transport is local
stdio plus an owner-restricted Unix socket, not an HTTP server or cloud relay.
Connection opt-ins are local settings and are not included in exported backups.

License activation, validation, and deactivation use Lemon Squeezy's License API
over HTTPS. Those requests include only the license key and a Mac instance label
made from the local computer name and a random installation-ID prefix;
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

The optional support report is generated locally and shown in full before the
user can copy or save it. It contains app/OS/build information, capability and
permission state, display geometry, aggregate record counts, static launch
stages, and DeskOrbit crash-report filenames. It intentionally excludes Space
names, note/checklist content, file paths, window titles, app identifiers and
activity, automation names and bodies, tracking details, the device name,
license keys, and license activation IDs. DeskOrbit never uploads it.

Runtime dependency inventory: Apple system frameworks only. Sparkle is used as
release-time tooling to serve older clients but is not linked, embedded, or run
on an end user's Mac. Build CI uses pinned-major GitHub Actions.
