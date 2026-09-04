# Namespaces for macOS: Product and Engineering Specification

## 1. Introduction

DeskOrbit (originally developed as Namespaces) is a privacy-first macOS menu-bar application for naming, navigating, and augmenting native macOS Spaces. The current product is moving from private daily use into a signed, notarized direct-download commercial release.

The application should match the useful parts of SpaceJump and improve on its weakest areas: fragile Mission Control integration, unclear capability boundaries, stale Space mappings, hidden keyboard behavior, automation safety, documentation inconsistency, insufficient backup/restore, and ambiguous privacy behavior.

Namespaces does not replace Mission Control or implement a separate virtual desktop manager. It discovers and controls the user's native Spaces, attaches durable local metadata to them, and provides dependable interfaces for switching, identifying, moving windows, recording context, tracking time, and deliberately starting workspace routines.

This document specifies the complete product and is intended to be given directly to a current Codex coding agent for end-to-end implementation. The phases, requirement IDs, and acceptance criteria provide traceability and verification; they are not instructions to use Ralph, stateless agents, fresh-context loops, ten-minute iterations, or one-agent-per-story execution.

### 1.1 Codex execution contract

When asked to implement this specification, Codex should own the repository and outcome continuously from initial scaffolding through a working, verified private release candidate.

- Read this entire specification and inspect the repository before changing files.
- Create and maintain a live implementation plan derived from the delivery phases and current repository state.
- Implement the complete specified product, not merely a scaffold, architectural sample, prototype, or naming/switching MVP.
- Treat the numbered requirements in Section 13 as a coverage checklist. Group and implement related requirements together when that is more efficient and coherent.
- Preserve context through source code, tests, documentation, commits when requested, and the implementation journal. Do not assume a fresh stateless agent for every requirement.
- Replan when macOS behavior, private API compatibility, test evidence, or repository constraints invalidate an assumption.
- Keep the app runnable throughout development and complete dependency foundations before dependent UI.
- Verify each integrated feature at the appropriate level: unit tests, integration tests, UI tests, live macOS interaction, performance checks, or compatibility checks.
- Use mocks for deterministic development, but do not claim a native Spaces feature complete until it is exercised against live macOS behavior where technically possible.
- Continue through all delivery phases unless genuinely blocked by unavailable signing credentials, hardware/OS coverage, user-granted permissions, or an external Apple limitation.
- If blocked, finish every independent in-scope item, record exact evidence, and identify the smallest user action needed to continue.
- Do not weaken privacy, security, data-integrity, or capability-degradation requirements simply to make a feature appear complete.
- Completion means the Phase 8 exit gate and REQ-108 release-candidate criteria are satisfied, with any unavoidable limitations explicitly documented.

## 2. Product Decisions

- **Initial commercial audience:** A founding cohort of 25–40 invited macOS users, followed by a public paid beta.
- **Distribution:** Signed and notarized direct distribution under Kauibungalow LLC. A Mac App Store build is out of scope while enhanced/private Space APIs are required.
- **Minimum OS:** macOS 14 Sonoma.
- **Hardware:** Apple Silicon and Intel where feasible; every release must at least build as a universal binary until an explicit decision changes this.
- **UI stack:** SwiftUI for settings and data-oriented views; AppKit for menu-bar, overlay, non-activating panel, window-level, drag monitoring, and Mission Control integration.
- **Language/toolchain:** Swift 6 language mode with strict concurrency enabled incrementally; current stable Xcode.
- **Storage:** Local SwiftData store with explicit versioned schemas and migrations.
- **Privacy:** No analytics, telemetry, automatic crash upload, product account,
  advertising SDK, or remote configuration. Network access is limited to
  user-initiated license operations and update checks; core Space data remains
  local and usable offline.
- **Sync:** No sync in v1. Optional, explicit iCloud sync may be designed later, but local storage remains authoritative until that feature ships.
- **Space integration:** A public-first provider interface with enhanced private WindowServer functionality isolated behind a replaceable adapter.
- **Commercial model:** $9.99 one-time purchase, one license key, up to three simultaneous Mac activations, 14-day full-featured trial, and lifetime updates for the product as currently promised.
- **Sales platform:** Lemon Squeezy as merchant of record and license-key service.
- **Brand:** DeskOrbit by Kauibungalow LLC, sold from `deskorbit.kauibungalow.com`.

## 3. Goals

- Let a user identify the active Space by name, icon, and color at all times.
- Open a searchable Space switcher within 100 ms at p95 after warm launch.
- Complete a supported Space switch without Namespaces adding more than 50 ms of overhead.
- Persist metadata accurately across application restarts, logouts, display reconnects, Space reordering, and ordinary Space creation/deletion.
- Never silently attach notes, automations, or tracked time to a confidently identified wrong Space.
- Expose capability state and degradation clearly when a macOS release breaks enhanced integration.
- Keep all user content and usage history local in v1.
- Provide automatic, auditable per-Space and per-application time records with idle exclusion.
- Move a selected window to a target Space with clear confirmation and failure recovery.
- Support multiple monitors with and without “Displays have separate Spaces.”
- Make every global shortcut discoverable, editable, conflict-checked, and disableable.
- Make script and application automations deliberate, reviewable, cancellable where possible, and safe by default.
- Provide backup, restore, CSV export, and diagnostic export without hidden personal information.
- Ship with unit, integration, UI, performance, migration, and manual macOS compatibility tests.

## 4. Non-Goals

- Replacing the macOS WindowServer, Dock, Mission Control, or Spaces implementation.
- Disabling System Integrity Protection.
- Injecting code into Dock, Mission Control, or other Apple processes.
- Kernel extensions, privileged daemons, or root access.
- A tiling window manager.
- Saving and restoring arbitrary window layouts in v1.
- Automatically executing scripts merely because the user passes through a Space.
- Team accounts, web dashboards, billing, invoicing, payroll, or cloud project management.
- Cross-platform support.
- Stage Manager group renaming in v1.
- App Store distribution while enhanced private Space APIs are enabled.
- Cloud sync, collaboration, or remote control in v1.
- Automatic categorization using captured screen contents.
- Screenshots, OCR, key logging, clipboard recording, document-title capture, or browser-history collection.

## 5. Personas and Primary Workflows

### 5.1 Multi-project developer

Uses a Space per repository, switches by project name, keeps a checklist with the repository, starts a deliberate “Setup Project” automation, and reviews focus time by project and application.

### 5.2 Freelancer

Uses a Space per client, expects idle-safe time totals, exports CSV for billing, and needs an unmistakable warning if tracking becomes uncertain.

### 5.3 Researcher or student

Uses named subject Spaces, local notes, checklists, direct hotkeys, and fast search without needing time tracking or automations.

### 5.4 Multi-display power user

Uses independent Space sets per display, disconnects and reconnects a laptop from monitors, and needs mappings to reconcile without swapping project identities.

### 5.5 Privacy-sensitive user

Wants the full application to work offline, needs an inspectable local data model, and expects exports and diagnostics to make redaction explicit.

## 6. Functional Specification

### 6.1 Space discovery and identity

Namespaces must maintain a live model of displays, native Spaces, active Space per display, Space ordering, and Space type when available (desktop, fullscreen application, tiled/fullscreen pair, or unknown).

Every observed native Space receives an ephemeral observation record. Persistent user metadata is linked only after the reconciliation engine establishes a match. The system must distinguish:

- A native runtime identifier that may change across reboot.
- A persistent Namespaces UUID.
- Display identity and current display membership.
- Current ordinal position.
- Space kind and optional owning application for fullscreen Spaces.
- First/last seen timestamps.
- Confidence of the current mapping.

Reconciliation inputs, in descending order of reliability:

1. Exact current-session native identifier.
2. Preserved display identity plus a stable signature supplied by the enhanced provider.
3. Previous display, order, neighboring-space signatures, kind, and fullscreen owner.
4. Explicit user confirmation.

When confidence is ambiguous, the app must preserve records as “Unmatched” rather than guessing. The UI must let the user merge, reassign, archive, or create metadata for unmatched Spaces.

### 6.2 Capability-based Space providers

All Space operations must go through a `SpaceProvider` protocol. The application must never call private WindowServer functions directly outside the enhanced provider package.

Required provider operations:

- Enumerate displays and Spaces.
- Observe active-Space changes.
- Return active Space per display.
- Switch to a Space.
- Move a window to a Space.
- Identify Mission Control state when supported.
- Return window-to-Space membership when supported.
- Return an explicit capability set.
- Return typed, user-presentable errors.

Providers:

- **EnhancedWindowServerProvider:** Dynamically resolves private symbols at runtime; supports enumeration, direct switching, window movement, and Mission Control coordination where compatible.
- **PublicFallbackProvider:** Uses supported macOS behavior, configured Mission Control shortcuts, Accessibility, and application activation where applicable. It may expose fewer capabilities and must never pretend to support unavailable operations.
- **MockSpaceProvider:** Deterministic provider for tests, previews, and UI development.

Enhanced integration must be guarded by:

- OS build allowlist/compatibility table.
- Runtime symbol checks.
- Non-destructive startup probe.
- Circuit breaker after repeated failures.
- User-visible capability status.
- Local compatibility diagnostics.
- A setting to disable enhanced integration.

### 6.3 Naming, icons, and colors

Each persistent Space supports:

- Name, required after onboarding but capable of a generated temporary default.
- Optional symbol selected from a curated SF Symbols catalog.
- Optional emoji fallback.
- Color selected from an accessible palette or custom color.
- Appearance preview in light, dark, and increased-contrast modes.
- Optional direct hotkey.
- Tracking enabled/disabled state.
- Optional billable flag and hourly-rate metadata stored locally.

Names must support Unicode, spaces, emoji, right-to-left text, and reasonable length. UI surfaces should truncate visually without truncating stored content.

### 6.4 Menu-bar interface

The menu-bar item supports configurable display modes:

- Icon only.
- Space name only.
- Icon and name.
- Color dot and name.
- Compact numbered mode.

The dropdown must show:

- Current Space at the top.
- Spaces grouped by display when displays have separate Spaces.
- Name, icon, color, number, display, and active state.
- Search when the list exceeds a configurable threshold.
- Switch action.
- Jump Back action.
- Notes action and note count.
- Automation action and group count.
- Tracking/session state.
- Settings, Help, Check for Updates, and Quit.

The menu must remain usable with VoiceOver, Full Keyboard Access, increased contrast, Reduce Motion, and right-to-left localization.

### 6.5 Quick Switcher

The Quick Switcher is a non-activating floating panel that appears on the display containing the pointer by default, with an option to use the active window's display.

Required behavior:

- Configurable global shortcut; default proposed as `⌥Space` because `⌘0` is used by several applications.
- Search Space name, aliases, icon description, and display label.
- Fuzzy ranking with exact prefix and recency boosts.
- Arrow-key navigation.
- `Return` switches.
- `Escape` closes without action.
- `1–9` selects/jumps only when search is empty and the setting is enabled.
- `⌘Return` begins inline rename.
- `⌘N` opens the selected Space's notes.
- `⌘T` creates a checklist for the selected Space.
- `⌘R` opens its automation groups.
- `⌘H` toggles visibility of all Namespaces notes.
- Display filter: All or a specific display.
- Active, previous, unmatched, and unavailable states are visually distinct.
- No selection is committed merely by dismissing the panel.
- Switch failures leave the panel open and show a recoverable error.

### 6.6 Jump Back and navigation history

Maintain a bounded navigation history of successfully activated Spaces. Ignore transient duplicate observations and failed switches.

Features:

- Dedicated configurable Jump Back shortcut.
- Optional double-press of the Quick Switcher shortcut.
- Toggle reliably between the two most recent valid Spaces.
- Configurable history depth for a “Recent Spaces” submenu.
- Remove deleted or unmatched Space references safely.
- Keep history in memory by default; optionally persist only the last valid Space IDs locally.

### 6.7 Per-Space shortcuts

- Record arbitrary keyboard combinations that include at least one non-Shift modifier.
- Detect conflicts with application-level Namespaces shortcuts.
- Warn about known macOS-reserved and common shortcuts.
- Allow the user to keep a warned shortcut explicitly.
- Register/unregister shortcuts immediately.
- Show failures when another process owns a shortcut.
- Provide a searchable shortcut settings table.
- Provide Reset to Defaults and Disable All Global Shortcuts.

### 6.8 Drag to Move and click-to-pin

Window movement must require Accessibility permission and provider capability.

Flow:

1. Observe a window drag without logging pointer content.
2. When the configured modifier is held, identify the dragged standard window through Accessibility.
3. Present a non-activating target overlay on relevant displays.
4. Highlight the hovered/clicked target.
5. On drop or explicit confirmation, request the provider to move the window.
6. Verify the move where membership inspection is supported.
7. Restore focus and report success/failure without trapping the pointer.

Options:

- Hold-to-show mode.
- Click-to-pin mode for accessibility and trackpad comfort.
- Move window and stay on current Space.
- Move window and follow it.
- Include/exclude fullscreen Spaces.
- Cancel with Escape.

Safety:

- Never move desktop elements, menus, sheets, popovers, minimized windows, or protected system windows.
- Reject windows that do not expose a standard AX role and valid frame.
- Disable the feature automatically if provider or Accessibility capability is unavailable.
- Include a visible undo action when the source Space is known.

### 6.9 Space Hover

Space Hover provides an optional mouse interface:

- Configurable activation area: notch, menu-bar center, left edge, right edge, or disabled.
- Configurable dwell delay and accidental-activation cooldown.
- Correct geometry for notched and non-notched displays.
- Separate overlay per display.
- Click to switch.
- Optional click-and-drag window target mode.
- Escape and pointer departure dismiss the overlay.
- Must not cover system status items indefinitely.
- Automatically disables during presentations, screen sharing, fullscreen video, or when Do Not Disturb-style suppression is manually enabled.

### 6.10 Mission Control labels

Mission Control labels are an enhanced, explicitly experimental capability.

Requirements:

- Do not modify Dock or Mission Control processes.
- Do not replace Apple's system text.
- Detect Mission Control presentation and dismissal when provider support is available.
- Render borderless, non-activating overlay labels aligned with Space thumbnails.
- Show icon, name, and color with configurable minimum width.
- Recalculate layout for multiple displays, reordered Spaces, expanded thumbnails, and display scaling.
- Avoid intercepting Mission Control clicks unless click-to-switch is explicitly enabled and verified safe.
- Hide immediately when Mission Control exits, screen locks, display configuration changes, or geometry confidence drops.
- Include a per-OS compatibility switch and “Disable automatically after errors” circuit breaker.
- Provide a visual calibration/debug mode without storing screenshots.
- Treat this feature as optional; all other functionality must work when it is disabled.

### 6.11 Notes and checklists

Every Space can own any number of local notes.

Note types:

- Plain text.
- Checklist.

Properties:

- UUID, Space UUID, title, body, type, creation/update dates.
- Checklist items with stable UUID, text, order, completion state, and completion date.
- Window geometry stored per display configuration.
- Floating, docked, collapsed, hidden, and always-on-top-within-Space state.
- Optional color inherited from the Space or independently selected.

Behavior:

- Open current Space's note palette via a global shortcut.
- Create, rename, duplicate, archive, and delete notes.
- Undo destructive actions during the current session.
- Auto-save edits with debouncing and crash-safe transactions.
- Keep note windows associated with their Space.
- Restore only notes that were open before quit when the mapping is confident.
- Dock to any screen edge with safe-area awareness.
- Toggle all note windows without altering their stored open state.
- Search notes from Settings, but never mix content into the Space switcher's search unless explicitly enabled.
- Export selected notes as Markdown and checklists as Markdown task lists.

### 6.12 Automation groups

Automations are manually run routines. Each group has a UUID, Space UUID, name, description, order, enabled state, and ordered actions.

Supported v1 actions:

- Launch application by bundle identifier.
- Open file or folder through a security-scoped bookmark.
- Open URL after showing the destination during setup.
- Run an Apple Shortcut by identifier/name.
- Run an executable script stored inside the Namespaces Application Support directory.

Execution rules:

- User must deliberately start a group.
- Display a preflight summary before first execution and whenever actions changed.
- Execute enabled actions in order by default; optionally continue on failure per action.
- Record local start/end time, outcome, duration, and sanitized error—not script output by default.
- Display live progress and permit cancellation between actions.
- Apply per-action timeouts.
- Never use `shell -c` with concatenated user input.
- Execute scripts using an explicit interpreter and argument array.
- Store scripts as separate files with displayed hashes and modification detection.
- Require reconfirmation when a script changed outside Namespaces.
- Do not request administrator privileges.
- Do not auto-download scripts or automation definitions.
- Importing a group must show every action and require explicit confirmation.

Potential later actions:

- Set Focus mode through supported Shortcuts rather than private APIs.
- Hide/quit applications with a confirmation policy.
- Arrange known windows if a separate workspace-layout feature is approved.

### 6.13 Time and session tracking

Tracking modes:

- Continuous automatic tracking by active Space.
- Named session spanning one or more Spaces.
- Paused.
- Disabled globally or per Space.

Time-entry model:

- Start and end monotonic timestamps plus wall-clock timestamps.
- Space UUID and optional native observation ID.
- Active application bundle identifier and localized name.
- Session UUID when applicable.
- Classification: active, idle, manual adjustment, recovered, or uncertain.
- Optional user note and billable flag.
- Data-quality/confidence field.

Rules:

- Begin a segment only after an active Space is confidently identified.
- Close the prior segment atomically when Space or frontmost application changes.
- Coalesce adjacent equivalent segments separated by a small configurable gap.
- Detect system sleep, lock, logout, app termination, and wake.
- Use system idle time; default idle threshold 5 minutes and user configurable.
- Exclude idle duration from active totals by default while retaining an idle segment for auditability.
- On wake, never backfill the sleeping interval as active time.
- Recover an open segment after crash as uncertain and end it at the last durable heartbeat.
- Permit manual edit, split, merge, reassign, and delete with an audit record.
- Keep tracking entirely local.

Reports:

- Today, week, month, and custom date range.
- Group by Space, session, application, and day.
- Active versus idle/uncertain totals.
- Billable versus nonbillable totals.
- CSV export using locale-independent ISO 8601 timestamps and explicit duration seconds.
- Optional human-friendly summary CSV.
- No productivity score, surveillance score, or moralized “good/bad app” labels.

### 6.14 External displays

- Observe display connect, disconnect, sleep, wake, resolution, scale, rotation, and primary-display changes.
- Store a local display alias separately from unstable hardware identifiers.
- Group Spaces by display in every relevant UI.
- Reconcile mappings without assuming display array order.
- Support “Displays have separate Spaces” both enabled and disabled.
- Move panels to a visible display when their prior display disappears.
- Restore geometry conservatively when a display returns.
- Never merge metadata merely because two displays have the same resolution.

### 6.15 Settings, onboarding, and permissions

Onboarding sequence:

1. Explain what Spaces are and what Namespaces adds.
2. Run capability scan.
3. Explain Accessibility before opening the system prompt.
4. Offer enhanced Space integration separately from basic functionality.
5. Discover Spaces and ask the user to confirm initial mappings/names.
6. Offer, but do not force, launch at login.
7. Show and test the Quick Switcher shortcut.
8. Offer optional tracking, notes, hover, Mission Control labels, and drag-to-move individually.
9. Finish with a local privacy summary and backup location.

Settings sections:

- Spaces.
- Switcher & Shortcuts.
- Window Movement.
- Notes.
- Automations.
- Time Tracking.
- Displays.
- Mission Control (Experimental).
- Permissions & Capabilities.
- Data & Backup.
- Updates.
- Advanced Diagnostics.
- About.

Permissions must be requested just in time. A status screen must distinguish Accessibility, Automation, login item, and any later notification permission. Revoked permission must degrade gracefully without repetitive prompts.

### 6.16 Local backup, restore, and export

Backup format: versioned `.namespaces-backup` package containing JSON metadata, Markdown note content, checklist JSON, automation manifests/scripts, and optional tracking CSV or JSON. It must never contain security-scoped bookmark blobs without explicit warning because bookmarks may reveal local paths and may not transfer safely.

Requirements:

- Manual backup to a user-selected location.
- Automatic rolling local backups disabled by default, configurable to 7/30 copies.
- Restore preview showing adds, updates, conflicts, and unsupported versions.
- Restore into a transaction with rollback on failure.
- Export all user content without proprietary encoding.
- Import validation with size, schema, path-traversal, and script review protections.
- Factory reset must require explicit confirmation and produce an optional backup first.

### 6.17 Diagnostics and compatibility

Diagnostics must be local and user-controlled.

Include:

- App version, build, architecture, macOS version/build.
- Provider and capability states.
- Permission states without bypass instructions.
- Display and Space topology using redacted Namespaces UUID prefixes by default.
- Recent typed internal errors and circuit-breaker state.
- Persistence migration status.
- Performance counters.
- Optional inclusion of Space names, app identifiers, paths, or script names; all off by default.
- “Copy diagnostics” and “Export diagnostics” with a preview/redaction screen.

No automatic transmission is permitted.

## 7. UX and Visual Design

- Native macOS visual language; do not clone SpaceJump branding or trade dress.
- Product identity should emphasize namespace/context concepts rather than “jump.”
- Use semantic system colors and materials.
- Meet WCAG-inspired contrast targets and honor Increase Contrast.
- Honor Reduce Motion and Reduce Transparency.
- Full VoiceOver labels, values, actions, and focus order.
- All controls reachable with keyboard navigation.
- Minimum effective target size of 28×28 points for compact macOS controls, larger where practical.
- Never rely on color alone: pair it with icon, text, or shape.
- Provide clear states for unavailable, experimental, degraded, unmatched, active, previous, paused, idle, and error.
- Provide a searchable in-app shortcut reference.
- Destructive actions use confirmation only when undo/restore is not sufficient.
- Errors explain what failed, what data was preserved, and the next safe action.

## 8. Technical Architecture

### 8.1 Repository layout

```text
Namespaces.xcodeproj
Namespaces/
  App/
  AppLifecycle/
  DesignSystem/
  Features/
    MenuBar/
    QuickSwitcher/
    Spaces/
    WindowMove/
    MissionControlLabels/
    SpaceHover/
    Notes/
    Automations/
    TimeTracking/
    Settings/
    Onboarding/
    DataManagement/
    Diagnostics/
  Persistence/
  Resources/
Packages/
  NamespacesDomain/
  SpaceProviderKit/
  EnhancedSpaceProvider/
  AccessibilityKit/
  HotkeyKit/
  AutomationKit/
  TrackingKit/
  DiagnosticsKit/
  TestSupport/
NamespacesTests/
NamespacesUITests/
Scripts/
Documentation/
```

### 8.2 Process model

Start with one LSUIElement menu-bar process. Do not add a helper or privileged process without a demonstrated need. Use `SMAppService.mainApp` for launch-at-login. If future crash isolation for experimental APIs becomes necessary, move only the enhanced provider into an XPC service with a narrow Codable request/response protocol.

### 8.3 State and concurrency

- `AppCoordinator` on `@MainActor` owns feature coordinators and presentation.
- `SpaceTopologyService` actor owns provider observations and reconciliation.
- `PersistenceService`/SwiftData model actor owns durable writes.
- `TrackingEngine` actor owns time segment state.
- `AutomationRunner` actor serializes group runs and cancellation.
- `HotkeyService` owns Carbon/global shortcut registration behind a protocol.
- UI consumes immutable snapshots/observable view models on the main actor.
- No shared mutable global state.
- Every long-running stream has explicit cancellation and lifecycle ownership.

### 8.4 Persistence schema

Version 1 entities:

- `SpaceRecord`
- `SpaceObservation`
- `DisplayRecord`
- `NoteRecord`
- `ChecklistItemRecord`
- `AutomationGroupRecord`
- `AutomationActionRecord`
- `AutomationRunRecord`
- `TrackingSegmentRecord`
- `TrackingSessionRecord`
- `TrackingEditRecord`
- `ShortcutRecord`
- `NavigationHistoryRecord`
- `AppPreferenceRecord`
- `CompatibilityRecord`

All entities use Namespaces-generated UUIDs, explicit creation/update dates, and schema-level delete rules. User content must not depend on native Space identifiers as primary keys.

### 8.5 Logging

Use `Logger`/OSLog with privacy annotations. Default logs may contain category, operation, typed error code, duration, and redacted UUID. User names, note text, checklist text, window titles, script bodies, local paths, and license-like values are private and must never be interpolated into default logs.

### 8.6 Dependencies

Prefer Apple frameworks. Any dependency must have:

- A documented purpose.
- Compatible license.
- Pinned version.
- Software bill of materials entry.
- Review of network behavior and data collection.
- A replacement/removal plan.

Do not add analytics, crash-reporting, advertising, experimentation, or remote-config SDKs.

## 9. Performance and Reliability Requirements

- Idle resident memory target below 80 MB on a representative Mac after stabilization.
- Idle CPU average below 0.5% over five minutes with no UI open.
- No polling faster than once per second outside a short-lived user interaction; prefer event streams.
- Quick Switcher warm-open p95 below 100 ms.
- Menu dropdown warm-open p95 below 100 ms.
- Space topology refresh completes below 250 ms for 32 Spaces where provider supports enumeration.
- Tracking writes are batched/debounced but last durable heartbeat is no older than 30 seconds.
- Notes auto-save within 500 ms after typing stops.
- Provider failures never crash the app.
- Corrupt or incompatible persistent data opens recovery mode rather than overwriting the store.
- All overlays close on lock, sleep, Fast User Switching, app termination, and provider disconnect.

## 10. Security and Privacy Requirements

- No network requests in private v1; add a network-deny integration test around core workflows where practical.
- No analytics identifiers.
- No screen capture permission.
- No content capture from windows.
- Accessibility access is used only for explicit window/interaction features.
- Scripts never run automatically on Space entry.
- Imported scripts require review and confirmation.
- Security-scoped bookmarks are stored only for user-selected resources.
- Sensitive data is protected with standard user-level file permissions and macOS Data Protection behavior where available.
- Any future sync is off by default, end-user enabled, independently spec'd, and migrates local data only after preview/consent.
- Any future crash reporting is separately opt-in and must show the exact payload before first transmission.

## 11. Testing Strategy

### 11.1 Unit tests

- Space reconciliation and ambiguity handling.
- Fuzzy search and ranking.
- Navigation history.
- Shortcut validation/conflicts.
- Tracking segmentation, idle, sleep, wake, crash recovery, DST, and time-zone changes.
- CSV escaping and locale independence.
- Automation validation, ordering, timeout, cancellation, and script hashes.
- Backup validation, migrations, and path-traversal defense.
- Display geometry and panel restoration.
- Capability degradation and circuit breaker.

### 11.2 Integration tests

- SwiftData store and schema migration.
- Provider-to-topology event stream using mocks.
- Permission revocation while features are active.
- Tracking across simulated topology and application changes.
- Notes persistence and geometry restoration.
- Automation with disposable test apps, folders, Shortcuts stubs, and scripts.
- Backup round trip.

### 11.3 UI tests

- Onboarding paths with permissions granted/denied/deferred.
- Settings navigation.
- Quick Switcher keyboard-only behavior.
- Rename, color, icon, note, checklist, and automation editing.
- Tracking reports and exports.
- Unmatched Space recovery.
- Accessibility identifiers and keyboard focus.

### 11.4 Manual compatibility matrix

- Latest two minor releases of each supported major macOS version.
- Apple Silicon and Intel if still claimed.
- One display, two displays, three displays.
- Notched and non-notched Mac.
- Separate Spaces per display on and off.
- Auto-rearrange Spaces on and off.
- Fullscreen apps and tiled windows.
- Stage Manager on and off.
- Reduce Motion, Reduce Transparency, Increase Contrast, VoiceOver.
- Sleep/wake, lock/unlock, logout/login, Fast User Switching.
- Dock restart and display hot-plug.
- Spaces added, removed, and reordered while Namespaces runs and while it is quit.

## 12. Delivery Phases and Exit Gates

### Phase 0: Foundation

Repository, app shell, packages, CI, formatting, local persistence, dependency policy, and mock provider.

**Exit gate:** Clean clone builds and tests on CI; menu-bar app opens Settings; no network SDKs.

### Phase 1: Space core

Provider protocol, enhanced/fallback providers, topology, reconciliation, naming, menu bar, onboarding, permissions, and capability diagnostics.

**Exit gate:** Spaces can be discovered, named, persisted, reconciled, and selected without silent misassignment.

### Phase 2: Navigation

Quick Switcher, fuzzy search, history, Jump Back, per-Space shortcuts, display filters, and shortcut help.

**Exit gate:** Keyboard-only switching is fast, testable, and failure-aware on supported configurations.

### Phase 3: Context surfaces

Notes, checklists, docking, Space Hover, and Mission Control labels.

**Exit gate:** Context UI follows only confidently mapped Spaces and hides safely during lifecycle changes.

### Phase 4: Window movement

Accessibility-based dragged-window identification, overlays, move/follow modes, verification, and undo.

**Exit gate:** Supported standard windows move reliably without accidental operations on system/nonstandard windows.

### Phase 5: Automations

Groups, action editors, security-scoped resources, execution engine, safety review, history, and import/export.

**Exit gate:** Every execution is deliberate, ordered, auditable, cancellable between actions, and safe against argument injection.

### Phase 6: Time tracking

Tracking engine, idle/sleep handling, sessions, history, edits, reports, and CSV.

**Exit gate:** Golden timeline tests and multi-day manual tests produce auditable totals with no sleep/idle inflation.

### Phase 7: Data resilience

Backup/restore, diagnostic export, factory reset, migration harness, and recovery mode.

**Exit gate:** Backup round trip and migration fixtures preserve all user content; corrupt imports cannot damage the live store.

### Phase 8: Hardening and private release

Accessibility audit, performance profiling, OS matrix, documentation, signing, notarization, and private distribution.

**Exit gate:** Release checklist passes on all supported configurations with no critical defects.

### Phase 9: Optional commercialization

Separate future PRD for licensing, purchases, support, update hosting, consented diagnostics, privacy/legal text, and release operations.

**Exit gate:** Not part of current implementation scope.

## 13. Traceable Implementation Requirements

The following IDs translate the specification into verifiable engineering work packages. They are ordered broadly by dependency, but they are not iteration boundaries or mandates for separate agent turns. Codex should batch adjacent requirements, parallelize independent investigation where appropriate, and revise the working order when repository evidence supports doing so. Acceptance criteria define required evidence, not a legacy loop protocol.

### REQ-001: Establish the Xcode project
**Description:** As a developer, I need a reproducible macOS project so every later feature builds on the same foundation.

**Acceptance Criteria:**
- [ ] Add a macOS 14+ app target named Namespaces and unit/UI test targets.
- [ ] Configure Swift 6 warnings and a universal Debug/Release architecture policy.
- [ ] Add build and test commands to README.
- [ ] Swift typecheck/build passes.

### REQ-002: Configure the menu-bar application lifecycle
**Description:** As a user, I want Namespaces to run as a menu-bar utility without an unnecessary Dock window.

**Acceptance Criteria:**
- [ ] Configure `LSUIElement` and create the application lifecycle coordinator.
- [ ] A placeholder status item exposes Settings and Quit.
- [ ] Closing Settings does not terminate the app.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-003: Create the package/module boundaries
**Description:** As a developer, I want risky integration and domain logic separated from UI code.

**Acceptance Criteria:**
- [ ] Add local packages for Domain, SpaceProviderKit, EnhancedSpaceProvider, AccessibilityKit, HotkeyKit, AutomationKit, TrackingKit, DiagnosticsKit, and TestSupport.
- [ ] Dependency direction is documented and contains no cycles.
- [ ] App target imports packages through declared APIs.
- [ ] Swift typecheck/build passes.

### REQ-004: Add continuous integration
**Description:** As a developer, I want every change automatically built and tested.

**Acceptance Criteria:**
- [ ] Add CI that builds Debug and runs unit tests on a supported macOS runner.
- [ ] Cache behavior does not hide a clean-build failure.
- [ ] CI status and local equivalent commands are documented.
- [ ] Swift typecheck/build passes.

### REQ-005: Define dependency and privacy policy
**Description:** As a privacy-sensitive user, I want dependencies constrained before features add hidden data collection.

**Acceptance Criteria:**
- [ ] Add documentation forbidding analytics, advertising, remote-config, and automatic crash-upload SDKs.
- [ ] Add an SBOM/dependency inventory template.
- [ ] Record approval requirements for new network-capable dependencies.
- [ ] Swift typecheck/build passes.

### REQ-006: Define core domain value types
**Description:** As a developer, I need stable typed identifiers and capability types.

**Acceptance Criteria:**
- [ ] Define IDs for Namespace Space, native Space observation, display, note, automation, session, and segment.
- [ ] Define Space kind, capability, confidence, and typed provider error enums.
- [ ] Types are Codable, Sendable, and unit tested where appropriate.
- [ ] Swift typecheck/build passes.

### REQ-007: Define the SpaceProvider protocol
**Description:** As a developer, I want the application independent from a particular macOS integration technique.

**Acceptance Criteria:**
- [ ] Protocol covers enumeration, active Space stream, switching, window movement, membership, and Mission Control state.
- [ ] Every optional operation is represented by an explicit capability.
- [ ] Unsupported operations return a typed unsupported error.
- [ ] Swift typecheck/build passes.

### REQ-008: Implement MockSpaceProvider
**Description:** As a developer, I want deterministic Space scenarios for feature development and tests.

**Acceptance Criteria:**
- [ ] Mock provider can add, remove, reorder, activate, and move mock windows among Spaces.
- [ ] It can simulate displays, errors, capability loss, and Mission Control state.
- [ ] Fixtures cover single and multi-display topologies.
- [ ] Swift typecheck/build passes.

### REQ-009: Define SwiftData schema version 1
**Description:** As a developer, I need durable local records that do not use native Space IDs as primary keys.

**Acceptance Criteria:**
- [ ] Add all v1 entities listed in the persistence specification with UUIDs and timestamps.
- [ ] Define relationships and delete rules explicitly.
- [ ] Create an in-memory test container.
- [ ] Swift typecheck/build passes.

### REQ-010: Add persistence service and transactions
**Description:** As a developer, I want actor-isolated persistence operations.

**Acceptance Criteria:**
- [ ] Add create/read/update/archive operations for Space and display records.
- [ ] All writes execute through a model actor/isolated service.
- [ ] Transaction failures surface typed errors without deleting the store.
- [ ] Swift typecheck/build passes.

### REQ-011: Add schema migration harness
**Description:** As a developer, I need every future data-model change testable before release.

**Acceptance Criteria:**
- [ ] Declare a versioned schema and migration-plan location.
- [ ] Add a fixture-based migration test harness.
- [ ] Document how to add a new schema fixture.
- [ ] Swift typecheck/build passes.

### REQ-012: Implement topology snapshots
**Description:** As a developer, I want an immutable representation of displays and Spaces.

**Acceptance Criteria:**
- [ ] Snapshot contains ordered displays, ordered Spaces, active states, kinds, and capabilities.
- [ ] Invalid duplicate native IDs are rejected with diagnostics.
- [ ] Snapshot comparison identifies added, removed, moved, and changed observations.
- [ ] Swift typecheck/build passes.

### REQ-013: Implement the reconciliation scoring engine
**Description:** As a user, I want names to remain attached to the correct Space across topology changes.

**Acceptance Criteria:**
- [ ] Score exact native identity, display signature, order/neighbors, kind, and fullscreen owner separately.
- [ ] Return confirmed, probable, ambiguous, or new outcomes.
- [ ] Ambiguous input never mutates an existing Space mapping automatically.
- [ ] Unit tests cover reorder, deletion, insertion, reboot-like ID churn, and monitor disconnect.
- [ ] Swift typecheck/build passes.

### REQ-014: Persist Space observations safely
**Description:** As a developer, I want topology observations recorded without overwriting user metadata.

**Acceptance Criteria:**
- [ ] Persist first/last seen, native ID, display, ordinal, kind, and confidence.
- [ ] User name/icon/color are stored only on `SpaceRecord`.
- [ ] Observation cleanup retains enough history for reconciliation.
- [ ] Swift typecheck/build passes.

### REQ-015: Build unmatched Space resolution UI
**Description:** As a user, I want to resolve uncertain mappings instead of accepting a guess.

**Acceptance Criteria:**
- [ ] UI lists unmatched observations and candidate Space records with reasons/confidence.
- [ ] User can link, create new, archive old, or defer.
- [ ] No choice is preselected when ambiguity is high.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-016: Add the enhanced provider symbol loader
**Description:** As a developer, I want private integration to fail closed when symbols change.

**Acceptance Criteria:**
- [ ] Private symbols are dynamically resolved only inside EnhancedSpaceProvider.
- [ ] Missing symbols produce an unsupported capability, not a crash.
- [ ] No private symbol type leaks into SpaceProviderKit or the app target.
- [ ] Swift typecheck/build passes.

### REQ-017: Enumerate Spaces with the enhanced provider
**Description:** As a user, I want native Spaces and displays discovered automatically on compatible macOS builds.

**Acceptance Criteria:**
- [ ] Provider returns ordered display/Space observations and active Space per display.
- [ ] Fullscreen/unknown types are represented without forced conversion to desktop.
- [ ] Malformed WindowServer output is rejected safely.
- [ ] Manual test instructions include multi-display verification.
- [ ] Swift typecheck/build passes.

### REQ-018: Observe active-Space changes
**Description:** As a user, I want UI and tracking to update when I switch Spaces by any method.

**Acceptance Criteria:**
- [ ] Provider emits active changes initiated by gestures, Mission Control, shortcuts, Dock, and Namespaces.
- [ ] Duplicate events are coalesced.
- [ ] Stream cancellation releases observers.
- [ ] Swift typecheck/build passes.

### REQ-019: Switch Spaces through the enhanced provider
**Description:** As a user, I want direct navigation to a selected Space.

**Acceptance Criteria:**
- [ ] Switch request accepts a native observation ID and display context.
- [ ] Success is confirmed by a subsequent active-Space observation with timeout.
- [ ] Failure returns a typed error and preserves prior history.
- [ ] Swift typecheck/build passes.

### REQ-020: Implement public fallback capabilities
**Description:** As a user, I want basic functionality when enhanced integration is unavailable.

**Acceptance Criteria:**
- [ ] Fallback provider advertises only operations it can execute on the current configuration.
- [ ] It supports user-configured ordinal switching through standard Mission Control shortcuts where available.
- [ ] UI can explain how to configure missing shortcuts without changing System Settings automatically.
- [ ] Swift typecheck/build passes.

### REQ-021: Add provider selection and circuit breaker
**Description:** As a user, I want a broken enhanced provider automatically contained.

**Acceptance Criteria:**
- [ ] Startup selects enhanced provider only after compatibility and non-destructive probe success.
- [ ] Repeated fatal provider errors open the circuit and fall back where possible.
- [ ] User can retry or disable enhanced integration.
- [ ] Circuit state is included in local diagnostics.
- [ ] Swift typecheck/build passes.

### REQ-022: Build the capability status screen
**Description:** As a user, I want to know which features work and why.

**Acceptance Criteria:**
- [ ] Screen lists detection, switching, window movement, membership, and Mission Control-label capabilities.
- [ ] Each unavailable capability shows a reason and safe next action.
- [ ] Experimental/private capabilities are labeled clearly.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-023: Add Accessibility permission service
**Description:** As a user, I want Accessibility requested only with a clear explanation.

**Acceptance Criteria:**
- [ ] Service reports trusted, denied/not granted, and unknown states.
- [ ] Prompt is triggered only by onboarding or an explicit feature action.
- [ ] Revocation updates dependent features without repeated prompts.
- [ ] Swift typecheck/build passes.

### REQ-024: Implement Space naming editor
**Description:** As a user, I want to assign a meaningful Unicode name to every Space.

**Acceptance Criteria:**
- [ ] Editor supports Unicode, spaces, emoji, and right-to-left text.
- [ ] Empty names show validation; stored names are not destructively truncated.
- [ ] Changes persist and update active UI immediately.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-025: Implement icon selection
**Description:** As a user, I want a recognizable icon for every Space.

**Acceptance Criteria:**
- [ ] Provide searchable curated SF Symbols and emoji fallback.
- [ ] Unsupported symbols migrate to a safe fallback.
- [ ] Selection is keyboard and VoiceOver accessible.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-026: Implement accessible color selection
**Description:** As a user, I want a color that remains understandable across appearance modes.

**Acceptance Criteria:**
- [ ] Provide semantic palette plus custom color.
- [ ] Preview light, dark, and increased-contrast appearance.
- [ ] Color is always paired with name or icon in functional UI.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-027: Build the Spaces settings list
**Description:** As a user, I want one place to inspect and configure all Spaces.

**Acceptance Criteria:**
- [ ] List groups Spaces by display and shows active, unmatched, archived, and unavailable states.
- [ ] Rows expose name, icon, color, shortcut, tracking, notes, and automation entry points.
- [ ] Reordering the view does not reorder native Spaces unless an explicit supported feature is later added.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-028: Build the menu-bar label modes
**Description:** As a user, I want control over how much menu-bar space Namespaces uses.

**Acceptance Criteria:**
- [ ] Implement icon-only, name-only, icon+name, color+name, and compact-number modes.
- [ ] Active-Space changes update without flicker.
- [ ] Long names truncate visually with full accessible value.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-029: Build the Space menu dropdown
**Description:** As a user, I want to switch and access Space actions from the menu bar.

**Acceptance Criteria:**
- [ ] Show current Space, grouped displays, active indicators, and all discovered Spaces.
- [ ] Space rows switch on selection and expose notes/automation subactions.
- [ ] Settings, Help, capability status, and Quit are present.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-030: Add launch-at-login preference
**Description:** As a user, I want Namespaces to start at login only when I choose.

**Acceptance Criteria:**
- [ ] Use `SMAppService.mainApp` registration/unregistration.
- [ ] UI reflects actual authorization status and links to Login Items settings when action is needed.
- [ ] Default is off.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-031: Build onboarding capability scan
**Description:** As a new user, I want setup tailored to what my Mac supports.

**Acceptance Criteria:**
- [ ] Scan provider, OS compatibility, displays, Accessibility, and shortcut availability.
- [ ] Scan performs no destructive operation and requests no permission automatically.
- [ ] Results drive subsequent onboarding steps.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-032: Build onboarding permission flow
**Description:** As a new user, I want to understand each permission before granting it.

**Acceptance Criteria:**
- [ ] Explain Accessibility purpose and features unlocked before invoking the system prompt.
- [ ] Allow Not Now and continue with degraded features.
- [ ] Rechecking status advances without relaunch.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-033: Build onboarding Space confirmation
**Description:** As a new user, I want to confirm discovered Spaces before metadata is trusted.

**Acceptance Criteria:**
- [ ] Show display, ordinal, type, and generated default for each observation.
- [ ] User can name/style now or defer.
- [ ] Completion saves confirmed mappings transactionally.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-034: Implement global hotkey registration
**Description:** As a user, I want system-wide shortcuts that work outside Namespaces.

**Acceptance Criteria:**
- [ ] HotkeyKit registers/unregisters combinations and exposes event callbacks.
- [ ] Failed registration returns a typed conflict/unavailable error.
- [ ] Registration is released on termination and updated immediately on preference change.
- [ ] Swift typecheck/build passes.

### REQ-035: Implement shortcut validation
**Description:** As a user, I want warnings before overriding common macOS/application shortcuts.

**Acceptance Criteria:**
- [ ] Reject modifier-free and Shift-only global shortcuts.
- [ ] Warn for reserved/common combinations with an explicit Keep Anyway action where technically allowed.
- [ ] Detect conflicts among all Namespaces shortcuts.
- [ ] Swift typecheck/build passes.

### REQ-036: Build shortcut settings
**Description:** As a user, I want all shortcuts discoverable and editable in one table.

**Acceptance Criteria:**
- [ ] Show feature, current shortcut, status, conflict, edit, and clear controls.
- [ ] Include per-Space shortcuts, reset defaults, and disable-all.
- [ ] Keyboard recorder does not activate the recorded action while editing.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-037: Implement fuzzy Space search
**Description:** As a user, I want fast and predictable matching by partial name.

**Acceptance Criteria:**
- [ ] Rank exact, prefix, token, substring, fuzzy, and recency signals deterministically.
- [ ] Normalize case/diacritics while preserving display text.
- [ ] Unit tests cover Unicode and ties.
- [ ] Swift typecheck/build passes.

### REQ-038: Build the Quick Switcher panel shell
**Description:** As a user, I want a fast non-activating Space picker.

**Acceptance Criteria:**
- [ ] AppKit panel opens on configured display and accepts keyboard input without opening Settings.
- [ ] Escape closes and returns focus to the prior app.
- [ ] Warm-open performance instrumentation exists.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-039: Build Quick Switcher results
**Description:** As a user, I want filtered Space results with clear status.

**Acceptance Criteria:**
- [ ] Results show icon, color, name, ordinal/display, active, previous, unmatched, and unavailable states.
- [ ] Arrow keys move selection and Return requests a switch.
- [ ] Failure leaves the panel open with an actionable error.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-040: Add Quick Switcher display filtering
**Description:** As a multi-display user, I want to filter Spaces by monitor.

**Acceptance Criteria:**
- [ ] All and per-display filters are keyboard reachable.
- [ ] Filter selection persists only if configured.
- [ ] Disconnecting the selected display safely resets to All.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-041: Add inline rename and action shortcuts
**Description:** As a user, I want common Space actions without leaving the switcher.

**Acceptance Criteria:**
- [ ] `⌘Return` edits selected name; Return commits and Escape cancels.
- [ ] Notes, new checklist, automation, and hide-notes commands use documented shortcuts.
- [ ] Conflicting commands are disabled with a reason.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-042: Implement navigation history
**Description:** As a user, I want only successful stable Space activations recorded.

**Acceptance Criteria:**
- [ ] Coalesce duplicate observations and ignore failed switches.
- [ ] Bound history and remove deleted/unmatched references.
- [ ] Tests cover rapid toggles and external switching.
- [ ] Swift typecheck/build passes.

### REQ-043: Implement Jump Back
**Description:** As a user, I want one shortcut to toggle between recent Spaces.

**Acceptance Criteria:**
- [ ] Dedicated shortcut switches to the most recent different valid Space.
- [ ] Successful repeated use toggles between two Spaces.
- [ ] Unavailable history gives nonintrusive feedback and does not switch.
- [ ] Swift typecheck/build passes.

### REQ-044: Add Quick Switcher double-press behavior
**Description:** As a user, I want an optional rapid double-press to Jump Back.

**Acceptance Criteria:**
- [ ] Feature is disabled by default and has configurable timing within safe bounds.
- [ ] A normal single press still opens the panel predictably.
- [ ] Tests cover slow press, double press, key repeat, and accessibility keyboard settings.
- [ ] Swift typecheck/build passes.

### REQ-045: Implement per-Space hotkeys
**Description:** As a user, I want direct shortcuts to important Spaces.

**Acceptance Criteria:**
- [ ] Each mapped Space can register one optional global shortcut.
- [ ] Conflicts and unavailable Spaces are represented in settings.
- [ ] Activation uses the same verified switch pipeline as all other UI.
- [ ] Swift typecheck/build passes.

### REQ-046: Define note and checklist persistence operations
**Description:** As a developer, I need transactional note APIs before building note windows.

**Acceptance Criteria:**
- [ ] Implement note CRUD/archive and ordered checklist item CRUD/toggle.
- [ ] Auto-save API supports debounced updates and final flush.
- [ ] Deleting a Space archives or reassigns notes according to an explicit policy.
- [ ] Swift typecheck/build passes.

### REQ-047: Build the Space note palette
**Description:** As a user, I want to find, open, and create notes belonging to the current Space.

**Acceptance Criteria:**
- [ ] Palette lists text notes/checklists for the current confidently mapped Space.
- [ ] Create, rename, duplicate, archive, and restore actions are present.
- [ ] Unmatched Space state blocks creation until user resolves or explicitly creates a mapping.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-048: Build floating text note windows
**Description:** As a user, I want an editable note that stays with its Space.

**Acceptance Criteria:**
- [ ] Floating panel edits title/body and auto-saves after debounce.
- [ ] Panel appears only for its associated active Space.
- [ ] Close/open state and visible geometry persist.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-049: Build checklist note windows
**Description:** As a user, I want ordered, completable tasks attached to a Space.

**Acceptance Criteria:**
- [ ] Add, edit, reorder, complete, uncomplete, and remove checklist items.
- [ ] Completion date persists and toggling is undoable in session.
- [ ] Full keyboard and VoiceOver operation is supported.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-050: Implement note docking
**Description:** As a user, I want notes docked to a safe screen edge.

**Acceptance Criteria:**
- [ ] Dock/undock works on all four edges without covering notch/menu-bar unsafe areas.
- [ ] Geometry stores display configuration and clamps on resolution changes.
- [ ] `⌘⇧W` toggles docking for the focused note.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-051: Implement global note visibility toggle
**Description:** As a user, I want to hide or restore all note windows quickly.

**Acceptance Criteria:**
- [ ] Toggle hides every Namespaces note without changing stored per-note open state.
- [ ] Restore shows only notes appropriate to active confidently mapped Spaces.
- [ ] Lock/sleep always hides panels until safe restoration.
- [ ] Swift typecheck/build passes.

### REQ-052: Add Markdown note export
**Description:** As a user, I want notes in a durable open format.

**Acceptance Criteria:**
- [ ] Export selected text notes as Markdown and checklists as task lists.
- [ ] Filenames are sanitized and collisions resolved predictably.
- [ ] Export requires a user-selected destination.
- [ ] Swift typecheck/build passes.

### REQ-053: Build Space Hover activation geometry
**Description:** As a user, I want a configurable hover target that respects every display.

**Acceptance Criteria:**
- [ ] Compute notch, menu-center, and edge activation regions per display.
- [ ] Dwell and cooldown are configurable and unit tested.
- [ ] Feature can be disabled globally or per display.
- [ ] Swift typecheck/build passes.

### REQ-054: Build the Space Hover overlay
**Description:** As a user, I want to reveal and click named Spaces by hovering.

**Acceptance Criteria:**
- [ ] Overlay shows relevant Spaces, active state, name, icon, and color.
- [ ] Click switches; Escape or pointer departure dismisses.
- [ ] Overlay never remains above lock screen or after display removal.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-055: Add Space Hover suppression rules
**Description:** As a user, I do not want accidental overlays during presentations or video.

**Acceptance Criteria:**
- [ ] Manual suppression toggle is immediately effective.
- [ ] Fullscreen/presentation heuristics suppress without capturing content.
- [ ] Status UI explains why hover is currently suppressed.
- [ ] Swift typecheck/build passes.

### REQ-056: Observe Mission Control lifecycle
**Description:** As a developer, I need a bounded experimental signal before drawing labels.

**Acceptance Criteria:**
- [ ] Enhanced provider emits presented/dismissed/unknown state where supported.
- [ ] Unknown confidence never triggers labels.
- [ ] Stream stops cleanly on provider disable or app termination.
- [ ] Swift typecheck/build passes.

### REQ-057: Compute Mission Control label layout
**Description:** As a user, I want labels aligned to Space thumbnails without modifying system UI.

**Acceptance Criteria:**
- [ ] Layout accounts for display frame, scale, Space count, expanded/collapsed state, and safe margins.
- [ ] Low geometry confidence yields no labels.
- [ ] Fixture tests cover common one/two/three-display arrangements.
- [ ] Swift typecheck/build passes.

### REQ-058: Render Mission Control label overlays
**Description:** As a user, I want readable names within the Mission Control experience.

**Acceptance Criteria:**
- [ ] Render non-activating labels with icon/name/color and no Dock/Mission Control injection.
- [ ] Labels hide immediately on dismissal, lock, display change, or confidence loss.
- [ ] Default mode does not intercept clicks.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-059: Add Mission Control compatibility controls
**Description:** As a user, I want experimental labels disabled safely after failures.

**Acceptance Criteria:**
- [ ] Settings show OS build compatibility, last error, and enable/disable/retry.
- [ ] Repeated layout/provider failures open a circuit breaker.
- [ ] Calibration view uses generated geometry and stores no screenshots.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-060: Identify a dragged standard window
**Description:** As a user, I want drag-to-move to act only on the intended standard window.

**Acceptance Criteria:**
- [ ] AccessibilityKit identifies a dragged AX standard window and owning process.
- [ ] Reject menus, sheets, popovers, desktop elements, minimized windows, and invalid frames.
- [ ] No window title or content is logged.
- [ ] Swift typecheck/build passes.

### REQ-061: Build the window-move target overlay
**Description:** As a user, I want visible Space targets while moving a window.

**Acceptance Criteria:**
- [ ] Configured modifier displays targets and highlights pointer selection.
- [ ] Escape cancels and releases the interaction.
- [ ] Overlay supports hold and click-to-pin modes.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-062: Move windows through the enhanced provider
**Description:** As a user, I want the selected standard window assigned to the target Space.

**Acceptance Criteria:**
- [ ] Provider accepts a validated window ID and target native Space ID.
- [ ] Operation times out and returns a typed error without crashing.
- [ ] Membership is verified when capability exists.
- [ ] Swift typecheck/build passes.

### REQ-063: Add move-and-follow and undo
**Description:** As a user, I want control over whether I follow a moved window and a way back.

**Acceptance Criteria:**
- [ ] Preference selects stay or follow behavior.
- [ ] Successful move exposes an undo action while source Space remains valid.
- [ ] Failed follow does not report the window move itself as failed if it succeeded.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-064: Define automation validation models
**Description:** As a developer, I need typed actions that cannot become arbitrary concatenated shell strings.

**Acceptance Criteria:**
- [ ] Define launch-app, open-resource, open-URL, Shortcut, and script actions with explicit arguments.
- [ ] Validate action-specific required fields and timeouts.
- [ ] Codable import rejects unknown unsafe fields by policy.
- [ ] Swift typecheck/build passes.

### REQ-065: Implement automation-group persistence
**Description:** As a user, I want ordered groups and actions saved per Space.

**Acceptance Criteria:**
- [ ] Implement group/action create, edit, reorder, toggle, duplicate, archive, and delete.
- [ ] Action order is stable and transactional.
- [ ] Changes update a modification marker used by preflight review.
- [ ] Swift typecheck/build passes.

### REQ-066: Build automation group editor
**Description:** As a user, I want to construct a routine and understand every action.

**Acceptance Criteria:**
- [ ] Edit group name/description and ordered enabled actions.
- [ ] Add menu exposes only supported action types.
- [ ] Each row summarizes executable, target, arguments, timeout, and failure policy.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-067: Implement application launch action
**Description:** As a user, I want an automation to launch a chosen application.

**Acceptance Criteria:**
- [ ] Store bundle identifier and a user-selected bookmark/reference where needed.
- [ ] Execution distinguishes launched, already running, missing, and denied.
- [ ] No process is terminated.
- [ ] Swift typecheck/build passes.

### REQ-068: Implement file/folder and URL actions
**Description:** As a user, I want an automation to open explicit local resources and URLs.

**Acceptance Criteria:**
- [ ] File/folder uses a security-scoped bookmark selected by the user.
- [ ] URL editor validates scheme and displays destination plainly.
- [ ] Missing bookmark permission produces a recoverable reselection flow.
- [ ] Swift typecheck/build passes.

### REQ-069: Implement Apple Shortcut action
**Description:** As a user, I want to reuse an existing Apple Shortcut deliberately.

**Acceptance Criteria:**
- [ ] Store selected Shortcut identity/name without importing its content.
- [ ] Execute with explicit process arguments and timeout.
- [ ] Missing/renamed Shortcut returns an actionable error.
- [ ] Swift typecheck/build passes.

### REQ-070: Implement safe script storage
**Description:** As a user, I want scripts inspectable and protected from silent modification.

**Acceptance Criteria:**
- [ ] Copy or create scripts under Application Support with restricted user permissions.
- [ ] Store interpreter, argument array, and cryptographic hash separately.
- [ ] Detect external modification and require review before the next run.
- [ ] Swift typecheck/build passes.

### REQ-071: Implement script execution
**Description:** As a user, I want a reviewed script to run without shell-injection behavior.

**Acceptance Criteria:**
- [ ] Use `Process` with explicit executable and argument array; never concatenate into `shell -c`.
- [ ] Apply timeout, cancellation between actions, and bounded output capture disabled by default.
- [ ] Never request administrator privileges.
- [ ] Swift typecheck/build passes.

### REQ-072: Build automation preflight review
**Description:** As a user, I want to see exactly what a routine will do before first or changed execution.

**Acceptance Criteria:**
- [ ] Review lists ordered actions, apps, paths, URLs, Shortcut names, script interpreter/hash, and failure policies.
- [ ] First run and changed group require explicit approval.
- [ ] Approval is invalidated by action or script modification.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-073: Implement AutomationRunner
**Description:** As a user, I want enabled actions executed in a predictable sequence.

**Acceptance Criteria:**
- [ ] Runner serializes actions, supports stop/continue failure policy, timeout, and cancellation between actions.
- [ ] It records sanitized outcome and duration per action/run.
- [ ] Concurrent invocation of the same group follows a documented reject or queue policy.
- [ ] Swift typecheck/build passes.

### REQ-074: Build automation progress UI
**Description:** As a user, I want visible progress and error recovery while a group runs.

**Acceptance Criteria:**
- [ ] UI shows current, completed, failed, skipped, and pending actions.
- [ ] Cancel prevents subsequent actions and explains whether the current process could be stopped.
- [ ] Retry begins from a clearly selected point rather than silently duplicating prior actions.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-075: Add automation launch points
**Description:** As a user, I want to run a Space routine from the menu and switcher.

**Acceptance Criteria:**
- [ ] Menu-bar Space row and Quick Switcher action list applicable groups.
- [ ] Starting a group is always a deliberate second action, not triggered by merely switching.
- [ ] Unavailable actions are explained before run.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-076: Add automation import/export
**Description:** As a user, I want portable routine definitions without hidden execution.

**Acceptance Criteria:**
- [ ] Export manifest and optional scripts to a versioned package.
- [ ] Import validates sizes, paths, schemas, and shows every action/script before confirmation.
- [ ] Import never executes an action.
- [ ] Swift typecheck/build passes.

### REQ-077: Define tracking state machine
**Description:** As a developer, I need formal tracking transitions before recording time.

**Acceptance Criteria:**
- [ ] States cover disabled, active, idle, paused, sleeping/locked, uncertain, and recovering.
- [ ] Events and allowed transitions are documented and unit tested.
- [ ] Impossible transitions fail safely without inventing time.
- [ ] Swift typecheck/build passes.

### REQ-078: Implement durable tracking segments
**Description:** As a user, I want each confident Space/application interval recorded atomically.

**Acceptance Criteria:**
- [ ] Start/close segments using monotonic and wall-clock timestamps.
- [ ] Space/application change atomically closes the prior segment and opens the next.
- [ ] Adjacent equivalent segments coalesce only within configured tolerance.
- [ ] Swift typecheck/build passes.

### REQ-079: Observe frontmost application
**Description:** As a user, I want per-application totals without capturing window or document content.

**Acceptance Criteria:**
- [ ] Record bundle identifier and localized app name when frontmost app changes.
- [ ] Never record window titles, document paths, URLs, or content.
- [ ] Missing bundle identity maps to an explicit Unknown Application.
- [ ] Swift typecheck/build passes.

### REQ-080: Implement idle detection
**Description:** As a user, I want away time excluded without losing auditability.

**Acceptance Criteria:**
- [ ] Idle threshold defaults to five minutes and is configurable.
- [ ] Active segment is split at the calculated start of idle time.
- [ ] Idle segment remains queryable but excluded from active totals by default.
- [ ] Unit tests cover activity just before/after threshold.
- [ ] Swift typecheck/build passes.

### REQ-081: Handle sleep, wake, lock, and clock changes
**Description:** As a user, I do not want sleep or wall-clock changes counted as work.

**Acceptance Criteria:**
- [ ] Sleep/lock closes active tracking at the last safe observation.
- [ ] Wake/unlock starts only after a confident active Space is observed.
- [ ] DST, timezone, and manual clock changes do not create negative or inflated durations.
- [ ] Swift typecheck/build passes.

### REQ-082: Implement crash recovery heartbeat
**Description:** As a user, I want a crash to lose at most a bounded amount of tracking accuracy.

**Acceptance Criteria:**
- [ ] Persist heartbeat no less often than every 30 seconds while active.
- [ ] On unclean startup, close open segment at last heartbeat and classify it uncertain/recovered.
- [ ] Recovery never backfills to relaunch time.
- [ ] Swift typecheck/build passes.

### REQ-083: Implement named sessions
**Description:** As a user, I want a named focus session that can span Spaces.

**Acceptance Criteria:**
- [ ] Start, pause, resume, rename, annotate, and end a session.
- [ ] New tracking segments link to active session without changing Space ownership.
- [ ] Only one session is active at a time.
- [ ] Swift typecheck/build passes.

### REQ-084: Build tracking controls
**Description:** As a user, I want clear global, per-Space, and session tracking state.

**Acceptance Criteria:**
- [ ] Menu and Settings show active/idle/paused/disabled/uncertain status.
- [ ] User can pause globally and enable/disable a Space.
- [ ] State changes explain how current segment was closed.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-085: Build tracking history list
**Description:** As a user, I want an auditable timeline of recorded segments.

**Acceptance Criteria:**
- [ ] Filter by date, Space, session, app, classification, and billable state.
- [ ] Show source/confidence and active versus idle duration.
- [ ] Empty/loading/error states are distinct.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-086: Add tracking edit operations
**Description:** As a user, I want to correct a record without losing the original history.

**Acceptance Criteria:**
- [ ] Edit times, split, merge compatible segments, reassign Space/session, change billable, and delete.
- [ ] Every mutation writes a local audit record with before/after values and timestamp.
- [ ] Invalid overlaps or negative durations are rejected.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-087: Build tracking summaries
**Description:** As a user, I want understandable totals by Space, app, session, and day.

**Acceptance Criteria:**
- [ ] Support today, week, month, and custom range.
- [ ] Separate active, idle, uncertain, billable, and nonbillable totals.
- [ ] Aggregates reconcile exactly with included source segments.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-088: Implement tracking CSV export
**Description:** As a user, I want portable records for spreadsheets or billing.

**Acceptance Criteria:**
- [ ] Detailed CSV uses UTF-8, RFC-compatible escaping, ISO 8601, duration seconds, and explicit columns.
- [ ] Summary CSV provides selected grouping and range.
- [ ] Locale does not alter machine-readable values.
- [ ] Swift typecheck/build passes.

### REQ-089: Observe display topology changes
**Description:** As a multi-display user, I want UI and mappings to react safely to hardware changes.

**Acceptance Criteria:**
- [ ] Observe connect/disconnect, frame, scale, rotation, sleep, and primary display changes.
- [ ] Refresh Space topology after display state settles with debouncing.
- [ ] Do not identify displays by array order or resolution alone.
- [ ] Swift typecheck/build passes.

### REQ-090: Restore panels after display changes
**Description:** As a user, I want overlays and notes to remain reachable after monitors change.

**Acceptance Criteria:**
- [ ] Move offscreen panels to a visible display with clamped geometry.
- [ ] Restore prior per-configuration geometry conservatively when a display returns.
- [ ] No overlay remains on a disconnected display.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-091: Implement backup package export
**Description:** As a user, I want a complete local backup in inspectable formats.

**Acceptance Criteria:**
- [ ] Export versioned manifest, JSON metadata, Markdown notes, automation files, and optional tracking data.
- [ ] User chooses destination and included data.
- [ ] Bookmark/path privacy warning is explicit and bookmarks are excluded by default.
- [ ] Swift typecheck/build passes.

### REQ-092: Implement backup validation and preview
**Description:** As a user, I want an imported backup inspected before it changes data.

**Acceptance Criteria:**
- [ ] Reject unsupported schema, oversized entries, invalid references, duplicate IDs, and path traversal.
- [ ] Preview additions, updates, conflicts, scripts, and skipped content.
- [ ] Preview performs no live-store mutation.
- [ ] Swift typecheck/build passes.

### REQ-093: Implement transactional restore
**Description:** As a user, I want restoration to complete fully or leave current data unchanged.

**Acceptance Criteria:**
- [ ] Restore runs in a transaction/staging store with rollback on failure.
- [ ] Conflict choices are explicit and recorded in a local restore summary.
- [ ] Round-trip fixture preserves supported content exactly.
- [ ] Swift typecheck/build passes.

### REQ-094: Add optional rolling local backups
**Description:** As a user, I want recoverable local snapshots without cloud transmission.

**Acceptance Criteria:**
- [ ] Feature defaults off and supports 7 or 30 retained copies.
- [ ] Backup location and last result are visible.
- [ ] Retention removes only app-created backups in the validated configured directory.
- [ ] Swift typecheck/build passes.

### REQ-095: Build factory reset flow
**Description:** As a user, I want to reset Namespaces without accidental data loss.

**Acceptance Criteria:**
- [ ] Flow enumerates data to be removed and offers backup first.
- [ ] Requires explicit final confirmation.
- [ ] Reset removes Namespaces data/settings only and relaunches onboarding safely.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-096: Implement privacy-safe OSLog categories
**Description:** As a user, I want useful logs without content leakage.

**Acceptance Criteria:**
- [ ] Add subsystem categories and privacy annotations.
- [ ] Automated tests/source checks cover prohibited logging of note text, titles, paths, script bodies, and window titles.
- [ ] Release logging excludes debug-only payloads.
- [ ] Swift typecheck/build passes.

### REQ-097: Build diagnostics snapshot
**Description:** As a user, I want local compatibility information when something breaks.

**Acceptance Criteria:**
- [ ] Snapshot includes versions, architecture, capabilities, permissions, redacted topology, errors, migration, and performance state.
- [ ] User content fields are excluded by default.
- [ ] Generation requires no network and does not mutate state.
- [ ] Swift typecheck/build passes.

### REQ-098: Build diagnostics export preview
**Description:** As a user, I want to see and redact diagnostics before sharing them.

**Acceptance Criteria:**
- [ ] Preview shows exact text/file payload.
- [ ] Optional names, app IDs, paths, and script identifiers are individually disabled by default.
- [ ] Copy/export happens only after explicit action.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-099: Add Settings search and shortcut reference
**Description:** As a user, I want features and commands discoverable.

**Acceptance Criteria:**
- [ ] Settings search indexes sections and controls without indexing note content.
- [ ] Shortcut reference lists current bindings and availability.
- [ ] Search results navigate directly to the relevant setting.
- [ ] Swift typecheck/build passes.
- [ ] Verify changes in the running macOS app.

### REQ-100: Complete accessibility audit
**Description:** As a VoiceOver/keyboard user, I want full access to Namespaces.

**Acceptance Criteria:**
- [ ] Every control has an accessibility label/value/action and logical focus order.
- [ ] Quick Switcher, menus, notes, automation editor, and tracking views are keyboard operable.
- [ ] Verify with VoiceOver, Full Keyboard Access, Increase Contrast, and Reduce Motion.
- [ ] Swift typecheck/build passes.

### REQ-101: Add performance signposts and budgets
**Description:** As a developer, I want regressions against product latency targets visible.

**Acceptance Criteria:**
- [ ] Add signposts for switcher/menu open, topology refresh, provider switch, tracking write, and note save.
- [ ] Performance tests assert practical budgets without flaky wall-clock assumptions.
- [ ] No signpost includes private user content.
- [ ] Swift typecheck/build passes.

### REQ-102: Add lifecycle hardening
**Description:** As a user, I want every transient UI and timer safe across system lifecycle events.

**Acceptance Criteria:**
- [ ] Lock, sleep, logout, Fast User Switching, termination, Dock restart, and display removal close overlays and finalize state.
- [ ] Wake/unlock rebuilds topology before restoring context UI.
- [ ] Automated state tests and manual checklist exist.
- [ ] Swift typecheck/build passes.

### REQ-103: Add compatibility fixtures and manual matrix
**Description:** As a developer, I want macOS/provider breakage detected before release.

**Acceptance Criteria:**
- [ ] Add recorded synthetic topology fixtures without personal data.
- [ ] Document the manual OS/hardware/display matrix from this PRD.
- [ ] Release cannot be marked compatible without a recorded matrix result.
- [ ] Swift typecheck/build passes.

### REQ-104: Add offline/network behavior tests
**Description:** As a privacy-sensitive user, I want core features verified without Internet connectivity.

**Acceptance Criteria:**
- [ ] Test plan exercises onboarding, naming, switching, notes, automation of local targets, tracking, backup, and diagnostics offline.
- [ ] Repository contains no analytics, crash-upload, remote-config, or advertising endpoints.
- [ ] Any future update endpoint is isolated and disabled in private v1 builds.
- [ ] Swift typecheck/build passes.

### REQ-105: Write user and troubleshooting documentation
**Description:** As a user, I want accurate guidance matching current behavior.

**Acceptance Criteria:**
- [ ] Document installation, permissions, features, shortcuts, data location, backup, limitations, and uninstall.
- [ ] Distinguish overlay labels from renaming Apple's system labels.
- [ ] Document per-OS capability matrix and fallback behavior.
- [ ] Documentation has a version/last-verified marker.
- [ ] Swift typecheck/build passes.

### REQ-106: Create signed private release pipeline
**Description:** As the owner, I want reproducible signed and notarized private builds.

**Acceptance Criteria:**
- [ ] Archive universal Release app with hardened runtime and least entitlements.
- [ ] Sign with Developer ID, notarize, staple, and verify Gatekeeper assessment.
- [ ] Produce checksummed DMG and release manifest without committing secrets.
- [ ] Swift typecheck/build passes.

### REQ-107: Add an opt-in update mechanism for distributed builds
**Description:** As a future distributed user, I want secure updates without coupling core use to the network.

**Acceptance Criteria:**
- [ ] Update framework/feed is compiled only into distributed builds and checks only on user-configured policy.
- [ ] Update signatures are verified and failures do not disable the installed app.
- [ ] Private/offline build has no update network request.
- [ ] Swift typecheck/build passes.

### REQ-108: Execute release-candidate verification
**Description:** As the owner, I want a documented decision that the complete product is safe for daily use.

**Acceptance Criteria:**
- [ ] All automated tests, migration fixtures, backup round trip, accessibility audit, performance budgets, and offline tests pass.
- [ ] Manual compatibility matrix is completed for every claimed configuration.
- [ ] Known limitations and disabled capabilities are documented in release notes.
- [ ] No critical/high-severity open defect remains.
- [ ] Swift typecheck/build passes.

## 14. Success Metrics for Private v1

- Seven consecutive days of normal use without a crash or incorrect high-confidence Space mapping.
- 1,000 automated simulated Space transitions without a leaked observer, unbounded history, or incorrect tracking transition.
- Quick Switcher warm-open p95 under 100 ms on the reference Mac.
- Idle CPU below 0.5% and stabilized memory below 80 MB on the reference Mac.
- Backup/restore round trip preserves all supported data in the golden fixture.
- Time-tracking golden timelines reconcile exactly, including sleep, idle, crash, DST, and manual edits.
- All critical workflows function with the network disabled.
- VoiceOver and keyboard-only verification completes without a blocking issue.

## 15. Future Opportunities Requiring Separate PRDs

- Opt-in iCloud/CloudKit synchronization with encryption, conflict handling, and local-first migration.
- Subscription, team, or major-version-upgrade licensing beyond the approved direct-download lifetime license.
- Optional previewed crash-report submission.
- Workspace/window-layout capture and restoration.
- Enter/leave-Space automation triggers with strict throttling and safety rules.
- Focus mode integration through supported Apple Shortcuts.
- User-authored plugins or automation action extensions.
- App Store-safe public-only build variant.
- Stage Manager group/context support if Apple exposes stable APIs.

The commercial direct-download launch requirements are specified in
`Docs/PUBLIC_RELEASE_PRD.md` and are part of this product specification.

## 16. Implementation Guidance for Codex

Use the delivery phases as integrated milestones and Section 13 as a traceability matrix. The requirement numbering communicates dependency and expected coverage, but Codex may complete multiple related requirements in one coherent change, work across several files or modules, and revisit earlier decisions as evidence accumulates.

The expected implementation rhythm is:

1. Inspect the current repository, toolchain, macOS environment, permissions, and available signing configuration.
2. Convert the relevant delivery phases into a live plan with measurable verification steps.
3. Establish a continuously buildable vertical foundation rather than generating every empty module up front.
4. Implement domain logic and mock-backed tests alongside each subsystem.
5. Integrate each subsystem into the running menu-bar application as soon as its foundation is reliable.
6. Exercise native behavior on the local Mac, compare observations with mocks, and record compatibility findings.
7. Harden lifecycle, permissions, privacy, persistence, accessibility, and failure degradation continuously—not as a final cleanup pass.
8. Run phase exit gates, update documentation and the implementation journal, then continue automatically to the next phase.
9. Finish with the complete release-candidate verification defined by REQ-108.

Keep enhanced/private integration behind feature flags until its probes, circuit breaker, and diagnostics exist. Use the MockSpaceProvider to make UI and domain development deterministic, but also verify supported features against live desktop topology. Do not ship time tracking until sleep/idle/crash-recovery tests pass. Do not ship script automations until preflight, hashing, and argument-safe execution are complete.

The agent should not stop merely because the project builds, the menu-bar item appears, a mock demo works, or one phase is complete. Those are intermediate milestones. The requested outcome is the full product described in this specification.
