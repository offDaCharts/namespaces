# DeskOrbit

DeskOrbit is a local-first macOS menu-bar application for naming,
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
- Places persistent colored names over the matching Mission Control desktop
  thumbnails, including gesture and Hot Corner activation, and provides a
  separate optional hover strip and Shift-drag window target.
- Audits tracking corrections, creates readable backup packages with Markdown
  notes, and can retain 7 or 30 daily local recovery copies.

## Requirements

- macOS 14 Sonoma or newer
- Xcode 16 or newer (tested with Xcode 26.2 / Swift 6.2.3)
- Accessibility permission for thumbnail-aligned Mission Control labels and
  window-focused features

## Build and run

### Install without Xcode

For normal use, download the latest self-contained DMG or universal ZIP from
[GitHub Releases](https://github.com/offDaCharts/namespaces/releases/latest).
Open the DMG and drag `DeskOrbit.app` to Applications. Xcode, Swift, Homebrew,
and this source repository are not required on the destination Mac.

Public releases are signed with Kauibungalow LLC's Developer ID and notarized by
Apple. Grant Accessibility only if you want Mission Control thumbnail labels and
window movement.

### Build from source

```bash
./Scripts/run-app.sh
```

The script builds, ad-hoc signs, and opens:

```text
build/DeskOrbit.app
```

To build a release app without opening it:

```bash
./Scripts/build-app.sh release
```

Release builds contain both Apple Silicon and Intel slices. The release pipeline
creates a checksummed DMG and universal ZIP, notarizes both, and generates a
signed Sparkle appcast:

```bash
./Scripts/release.sh
```

For Developer ID/notarization, set `DESKORBIT_SIGN_IDENTITY` and either
`DESKORBIT_NOTARY_PROFILE` or the `DESKORBIT_NOTARY_KEY`,
`DESKORBIT_NOTARY_KEY_ID`, and `DESKORBIT_NOTARY_ISSUER` variables. Set
`DESKORBIT_SPARKLE_PRIVATE_KEY_FILE` for non-Keychain Sparkle signing. No secret
is stored in this repository.

You can also open `Package.swift` directly in Xcode or run:

```bash
swift test
swift run Namespaces
```

## First use

1. Start DeskOrbit. Its grid icon and current Space name appear in the menu
   bar.
2. Open **Settings → Spaces** and name each discovered desktop.
3. Press `⌥Space` to open the Quick Switcher.
4. Open **Capabilities** and grant Accessibility to show names on Mission
   Control thumbnails and use window-level features.
5. Configure notes, automations, and tracking as desired.

The app is ready to use directly from `build/DeskOrbit.app`. To keep it in your
user Applications folder, drag that app there in Finder and launch it once.

All content is stored at:

```text
~/Library/Application Support/Namespaces/Namespaces.json
```

DeskOrbit includes a 14-day full-feature trial and a $3.99 one-time license for
up to three Macs. License requests include only the key and a Mac instance label.
DeskOrbit has no analytics, advertising, or automatic crash upload. Experimental
integration is isolated and fails closed when the current macOS build does not
expose the required WindowServer capabilities.

### Mission Control names

DeskOrbit cannot modify Apple's native `Desktop 1`, `Desktop 2`, … strings.
With **Show names on Mission Control thumbnails** enabled, it detects Mission
Control through the Dock and adds click-through colored labels containing your
saved name. The compact text-only labels follow the desktop controls until Mission
Control closes. Keyboard shortcuts, trackpad gestures, Dock activation, and Hot
Corners use the same observer path.

If names do not appear, open **Settings → Capabilities** and check **Mission
Control status**. Grant Accessibility to the exact copy of `DeskOrbit.app`
that you run, then quit and reopen it. Rebuilding or moving an ad-hoc-signed app
can require removing the old Accessibility entry and granting it again.

## Specifications

See [PRD.md](PRD.md) for the complete product and engineering specification.
Implementation state and compatibility findings are tracked in
[progress.txt](progress.txt).

Additional operational documents are in `Docs/`: architecture, privacy policy,
SBOM, compatibility matrix, and release notes.
