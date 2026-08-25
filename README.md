# Namespaces

Namespaces is a private, local-first macOS menu-bar application for naming,
switching, and augmenting native macOS Spaces.

## Current capabilities

- Discovers native Spaces and displays through an isolated enhanced provider.
- Assigns persistent names, SF Symbols, colors, tracking, and billing metadata.
- Shows the active Space in the menu bar and provides direct switching.
- Provides a searchable `⌥Space` Quick Switcher and `⌥⇧Space` Jump Back.
- Stores per-Space text notes and checklists locally.
- Runs explicit on-click automation groups for apps, paths, URLs, Apple
  Shortcuts, and reviewed local scripts.
- Tracks active Space and frontmost application time locally with idle
  classification and named sessions.
- Exports readable JSON backups and CSV tracking data.
- Reports provider and Accessibility capabilities without uploading data.
- Shows optional Mission Control/hover labels and a Shift-drag window target.
- Audits tracking corrections, creates readable backup packages with Markdown
  notes, and can retain 7 or 30 daily local recovery copies.

## Requirements

- macOS 14 Sonoma or newer
- Xcode 16 or newer (tested with Xcode 26.2 / Swift 6.2.3)
- Accessibility permission for window-focused features

## Build and run

```bash
./Scripts/run-app.sh
```

The script builds, ad-hoc signs, and opens:

```text
build/Namespaces.app
```

To build a release app without opening it:

```bash
./Scripts/build-app.sh release
```

Release builds contain both Apple Silicon and Intel slices. The private release
pipeline creates a checksummed DMG and defaults to ad-hoc signing:

```bash
./Scripts/release.sh
```

For Developer ID/notarization, set `NAMESPACES_SIGN_IDENTITY` to the signing
identity and `NAMESPACES_NOTARY_PROFILE` to an existing `notarytool` keychain
profile. No secret is stored in this repository.

You can also open `Package.swift` directly in Xcode or run:

```bash
swift test
swift run Namespaces
```

## First use

1. Start Namespaces. Its grid icon and current Space name appear in the menu
   bar.
2. Open **Settings → Spaces** and name each discovered desktop.
3. Press `⌥Space` to open the Quick Switcher.
4. Open **Capabilities** to grant Accessibility only if you want window-level
   features.
5. Configure notes, automations, and tracking as desired.

The app is ready to use directly from `build/Namespaces.app`. To keep it in your
user Applications folder, drag that app there in Finder and launch it once.

All content is stored at:

```text
~/Library/Application Support/Namespaces/Namespaces.json
```

Namespaces has no analytics, telemetry, accounts, advertising, or automatic
crash upload. Experimental integration is isolated and fails closed when the
current macOS build does not expose the required WindowServer capabilities.

## Specifications

See [PRD.md](PRD.md) for the complete product and engineering specification.
Implementation state and compatibility findings are tracked in
[progress.txt](progress.txt).

Additional operational documents are in `Docs/`: architecture, privacy policy,
SBOM, compatibility matrix, and release notes.
