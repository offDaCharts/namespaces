# Privacy and Dependency Policy

Last verified: 2026-08-27, DeskOrbit 0.2.0.

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
history. Sparkle checks Kauibungalow's signed update feed and may send routine
compatibility data such as app version, macOS version, and architecture.

New network-capable or data-collection dependencies require owner approval, a
documented purpose, an offline degradation path, an SBOM update, and a privacy
review. Automatic upload SDKs are prohibited. Private data must never be logged;
OSLog/signposts use only static operation names and aggregate state.

Runtime dependency inventory: Apple system frameworks plus Sparkle 2.9.6 for
cryptographically signed software updates. Build CI uses pinned-major GitHub
Actions.
