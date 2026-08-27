# Privacy and Dependency Policy

Last verified: 2026-08-26, Namespaces 0.1.2.

Namespaces v1 is offline and local-first. It contains no analytics, advertising,
remote configuration, account, telemetry, crash-upload, or update networking.
It never captures screenshots, window titles, URLs, clipboard data, document
content, browser history, or keystroke content. Global monitors observe only the
event types/modifiers necessary for configured shortcuts and window movement.
When Mission Control labels are enabled, Accessibility reads the Dock's desktop
control titles, positions, and sizes so labels can be aligned. It does not read
other applications' accessibility trees and does not require Screen Recording.

New network-capable or data-collection dependencies require owner approval, a
documented purpose, an offline degradation path, an SBOM update, and a privacy
review. Automatic upload SDKs are prohibited. Private data must never be logged;
OSLog/signposts use only static operation names and aggregate state.

Runtime dependency inventory: Apple system frameworks only (AppKit, SwiftUI,
SwiftData, Carbon, ServiceManagement, CryptoKit, OSLog). Build CI uses the pinned
major `actions/checkout@v4` action and no runtime package dependency.
