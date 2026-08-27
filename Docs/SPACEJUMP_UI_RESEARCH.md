# Mission Control and UI Redesign

Last researched: 2026-08-27.

## Sources and method

- SpaceJump's current product page and 16-second demo video:
  <https://www.getspacejump.com/>
- SpaceJump's feature explanation:
  <https://www.getspacejump.com/how-it-works>
- Apple Human Interface Guidelines for [macOS](https://developer.apple.com/design/human-interface-guidelines/designing-for-macos/), [Settings](https://developer.apple.com/design/human-interface-guidelines/settings), [Menus](https://developer.apple.com/design/human-interface-guidelines/menus), [Popovers](https://developer.apple.com/design/human-interface-guidelines/popovers/), and [Sidebars](https://developer.apple.com/design/human-interface-guidelines/sidebars)
- Apple's accessibility API documentation for [`AXUIElementCopyAttributeValue`](https://developer.apple.com/documentation/applicationservices/1462085-axuielementcopyattributevalue) and [`NSWorkspace.activeSpaceDidChangeNotification`](https://developer.apple.com/documentation/appkit/nsworkspace/activespacedidchangenotification)

The SpaceJump demo was saved locally and sampled at two frames per second. The
full sample is in `Research/SpaceJump-contact-sheet.png`; the most useful close
views are frames 009, 013, 020, 026, and 027.

## What the SpaceJump demo does well

### Mission Control labels

- Each custom name is inside the actual desktop thumbnail, near its bottom edge.
- The name plate is inset approximately 6 points from both thumbnail edges and
  is therefore nearly full-width. Its center always equals the thumbnail center.
- The plate is about 22 points high, with a 5–6 point corner radius.
- White semibold text is approximately 12 points. The color fill is translucent
  enough to preserve thumbnail context; the border/shadow is extremely subtle.
- The custom name does not try to replace Apple's `Desktop N` text beneath the
  thumbnail and does not include a redundant icon.
- Labels appear only after Mission Control exposes expanded thumbnail geometry.

### Quick switcher

- The panel is narrow, centered, and dense rather than a large utility window.
- A compact display filter, search field, last-Space action, list, and keyboard
  help form one clear top-to-bottom path.
- Each row uses a small numbered color tile, primary custom name, secondary
  `Desktop N` label, and a tiny current indicator.
- Selection uses a low-opacity tint and fine stroke instead of a saturated block.
- Native material, system typography, short radii, and a restrained shadow make
  the panel feel like a macOS transient control.

### General product surface

- Information density is high but hierarchy remains obvious.
- Color is used for identity and state, not as decoration on every container.
- Advanced actions stay out of the primary switching flow.
- Labels and rows share the same number/color/name language, connecting Mission
  Control, the menu bar, and the switcher.

## Problems found in DeskOrbit 0.1.6

1. The AX candidate scorer deliberately preferred Apple's compact `Desktop N`
   text frame over the expanded thumbnail frame.
2. When AX did not resolve every Space, a guessed equal-slot fallback was drawn.
   Mission Control changes thumbnail width and spacing with Space count, screen
   dimensions, display orientation, and animation state, so that fallback could
   never remain aligned.
3. Text-width badges made short names float independently of thumbnail width,
   weakening the visual connection to their desktops.
4. Space settings used a large card per desktop and exposed every secondary
   option simultaneously. The switcher was also larger and more utility-like
   than the demonstrated transient panel.

## Implemented design contract

### Exact geometry or no overlay

The Dock AX hierarchy is traversed while Mission Control is active. A candidate
must satisfy all of these rules:

- It carries or contains a parseable `Desktop N` / `Space N` accessibility name.
- It is at least 70 × 50 points, excluding the compact native text control.
- It is contained in the upper Mission Control band of a real `NSScreen`.
- It is not a full-width Space-bar container or ordinary application window.

When the accessible name is on a compact child, its nearest thumbnail-shaped
ancestor is used. Candidates are scoped to their display and matched by native
ordinal first, then by left-to-right position to tolerate full-screen-index gaps.

The badge is derived only from the accepted thumbnail:

```
x      = thumbnail.minX + 6
y      = thumbnail.minY + 5
width  = thumbnail.width - 12
height = 22
```

The guessed fallback has been removed. While AX is unavailable or still
animating, the UI reports `waiting for exact thumbnail bounds` and draws nothing.
This makes failure temporary and unobtrusive instead of visibly wrong.

### Visual system

- Mission Control plates: 12-point rounded semibold text, 68–76% identity-color
  fill, 0.5-point highlight stroke, 1-point restrained shadow.
- Quick switcher: 380 × 410 point material panel, 38-point rows, 25-point number
  tiles, compact display filter, inline search, previous-Space action, and terse
  keyboard help.
- Spaces settings: stable native sidebar, smaller pane title, one inset list,
  compact primary rows, named color swatches, human-readable icon names, and
  disclosed advanced controls.

## Validation matrix

Automated geometry tests cover 1, 2, 4, 8, 13, and 16 thumbnails on 16:10,
16:9, portrait, ultrawide, negative-origin, and multi-display-style screen
frames. They assert that each badge stays inside its source thumbnail, inherits
its exact center, never overlaps a neighbor, and rejects compact labels and
full-width containers.

Manual release checks remain necessary on each supported macOS major version
because Mission Control's AX hierarchy is undocumented. The correct compatibility
behavior is fail-closed: a changed hierarchy may temporarily hide labels but can
never cause estimated labels to appear in the wrong positions.
