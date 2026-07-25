# Wholphin Roku — Home Screen Skeleton

This is a starting skeleton for the Netflix/Jellyfin-style home screen
(hero banner + left nav rail + horizontal content rows), built with
Roku SceneGraph (XML + BrightScript).

## Files

| File | Purpose |
|---|---|
| `components/HomeScene.xml` | Root scene: node layout for backdrop, gradient, hero text, nav rail, content rows |
| `components/HomeScene.brs` | Data loading + hero banner updates driven by row focus |
| `components/HomeSceneFocus.brs` | Manual focus routing between nav rail and content rows |
| `components/NavRail.xml` / `.brs` | Left icon column, manual focus highlight per icon |
| `components/RowListItem.xml` / `.brs` | Individual card renderer used by `RowList` — handles both 16:9 episode thumbnails (with E# badge) and 2:3 posters |

## What's real vs. stubbed

**Real / functional patterns:**
- `RowList`-driven content rows with lazy image loading
- Hero banner updates on row focus change (`onRowItemFocused`)
- Manual nav-rail-vs-content focus zone switching
- Episode badge shown conditionally based on content fields

**Stubbed — you need to fill these in:**
- `loadHomeData()` in `HomeScene.brs` — currently hardcodes a few titles. Replace with your actual Jellyfin (or whatever backend Wholphin talks to) API calls, likely something like `GET /Users/{userId}/Items/Resume` for "Next Up" and `GET /Users/{userId}/Items/Latest` for the recently-added rows.
- `playItem()` / `showDetails()` — currently just `print` statements. Wire to your existing video player scene / details scene components (the Android app presumably already has this logic somewhere — it's the SceneGraph equivalent you need, not new logic).
- Image assets: `hero_gradient.png`, `focus_ring.9.png`, and the `icon_*.png` nav icons are referenced but not included — you'll need to export these (a 9-patch focus ring and a black-transparent gradient PNG are the two non-obvious ones).
- Clock currently uses local device time via `roDateTime`; adjust if you need a synced/server time instead.

## Known gaps / things to verify against current Roku SDK docs

- The exact field names RowList pushes to item components (`rowListHasFocus`, `rowFocusPercent`) have shifted slightly across firmware versions — double check against Roku's current `RowList` documentation before relying on them.
- `rowItemSize`, `rowHeights`, etc. on `<RowList>` are set for 4 rows as an example — adjust the array lengths to match however many rows `loadHomeData()` actually populates.
- Gradient overlay is done via a pre-rendered PNG poster layered over the backdrop, since SceneGraph has no native CSS-style gradient node. If you want it fully dynamic (color-matched per title, etc.) you'd generate the gradient PNG server-side or maintain a small fixed set of gradient assets.

## Suggested order of work

1. Drop in real image assets (gradient, focus ring, nav icons)
2. Replace `loadHomeData()` with real API calls
3. Test focus flow: nav rail ↔ rows, and up/down between rows
4. Wire `playItem()` / `showDetails()` to existing player/details scenes
5. Confirm RowList field names against SDK docs for your target Roku OS version
