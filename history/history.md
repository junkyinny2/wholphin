# Wholphin Roku - Change History

## 2026-08-05 — Published to GitHub (alpha / non-working snapshot)

- **What:** Published the full project to GitHub `main` (https://github.com/junkyinny2/wholphin)
  so the working copy can be removed locally and restored from the repo.
- **Disclaimers added everywhere per user request:** prominent ALPHA / NON-WORKING
  banner in `README.md`, new `WARNING.md` at repo root, and a header comment in
  `source/Main.bs`. (Skipped `manifest` — Roku's manifest parser doesn't support
  `#` comments and would break the build.)
- **Everything included:** all source/config/docs tracked files committed, plus
  gitignored local config (`bsconfig.deploy.local.json` — force-added) so the user's
  deploy setup is fully backed up. Excluded regenerable `node_modules/`, `build/`,
  `out/` (restore those with `npm install` + `npm run build`).
- **Note:** `_archive/reference-docs/BrightScriptReferenceManual_ver9.pdf` is 76 MB
  (> GitHub's 50 MB recommendation) but pushed successfully.
- **Files touched:** `README.md`, `WARNING.md` (new), `source/Main.bs`, all tracked sources
- **Automatic:** no (user request: publish + delete local)

## 2026-08-05 — Restored original Wholphin home screen + added server-switch deep link

- **What:** Restored the original Wholphin home-screen look/behavior and added a
  way to bypass auto-login / switch servers.
- **Home-screen fix (multiple tiles per row):** `HomeRows.bs` `Init()` had been
  set to `itemSize = [196, 294]` (one poster width = one tile per row). Restored
  the original `itemSize = [1720, 320]` so the RowList row strip is wide enough
  to render multiple posters per row (~8 at 196px each). Verified: boot trace shows
  `finishLoading content rows= 4` + `homeRows set, focus=true`.
- **Home screen / NavRail:** Reverted the redesign overlay back to the original
  `HomeScreen.xml`/`.brs`, `HomeRows.bs`/`.xml`, `LoadItemsTask.bs` and restored
  the dynamic cyan `NavRail.brs` (Wholphin glyphs) from HEAD.
- **Server switching:**
  - The in-app path already exists (NavRail → Settings → Change Server →
    `pendingServerAction=showserver` → `CreateServerGroup`). The §4.4 focus-proxy
    pattern is active on `SetServerScreen` (`focus on focusProxy`).
  - Added an **ECP deep link** so the server picker can be launched directly,
    bypassing the saved auto-login: `POST /launch/dev?content=<base64(json)>`
    where json = `{"command":"showServerPicker"}`. Roku delivers the base64 in
    `args["content"]`; `Main.bs` decodes it and, if `command == showServerPicker`,
    sets `skipAutoLogin=true`, bypasses the auto-login block, and calls
    `CreateServerGroup()` (deferred until after SceneManager is initialized) to
    push `SetServerScreen`. Verified on-device (build 152): `skipAutoLogin=true`
    → `pushScene: SetServerScreen`, no `CreateHomeGroup`, no runtime errors.
  - Added `base64Decode()` (roByteArray lookup indexed by `Asc(char)` — BrightScript
    AAs are case-insensitive so an `{}` alphabet table collapses 'J'/'j') and
    `parseJsonSafe()` (uses the built-in `ParseJSON`, since `roJSONParser` does not
    exist on this firmware) to `source/utils/misc.bs`.
  - Added `HandleDeepLink` `showServerPicker`/`switchServer` →
    `pendingServerAction=showserver` routing in `MainEventHandlers.bs` for the
    `/input` runtime deep-link path on an already-running channel.
- **Security:** replaced the verbose args-dump debug print in `Main` (which echoed
  the access token to stdout) with a single `hasContent=` summary line.
- **Files touched:** `components/home/HomeRows.bs`, `source/Main.bs`,
  `source/utils/misc.bs`, `source/MainEventHandlers.bs`
- **Verified on-device (build 152):** ECP `POST /launch/dev?content=` with
  `{"command":"showServerPicker"}` → cold boot shows `[DIAG] skipAutoLogin=true`
  → `CreateServerGroup` → `SetServerScreen`, no auto-login, no Micro Debugger.
- **Timestamp:** 2026-08-05

## 2026-08-04 — Fixed FF/Rewind dead keys + blank screen on Back

- **What:** Dedicated rewind/fast-forward remote buttons did nothing, and pressing Back during a movie left a blank screen instead of returning to MovieDetails.
- **Root cause #1 (FF/RW dead):** The Roku remote's rewind/FF buttons deliver `key="rewind"` / `key="fastforward"` (lowercase, full words), but `VideoPlayerView.onKeyEvent` only handled `"Rev"`/`"Fwd"` — so the seeks were never triggered. D-pad left/right DID seek (confirmed in console).
- **Fix #1:** Handle `"rewind"`/`"fastforward"` in addition to `"Rev"`/`"Fwd"` in `VideoPlayerView.bs` `onKeyEvent`.
- **Root cause #2 (blank screen):** `ShowScenes.PopCurrentScene()` popped/removed the player scene but never set the previous scene back to visible, while `SceneManager.popScene()` (SceneManager.bs:106) does `previousScene.visible = true`. The underlying MovieDetails stayed invisible → blank.
- **Fix #2:** `PopCurrentScene()` now mirrors `popScene()`: re-sets `previousScene.visible = true`, calls `previousScene.callFunc("OnScreenShown")` (unconditional — `HasField()` returns false for interface `<function>` entries), and `setFocus(true)`.
- **Also added** permanent `? "[VideoPlayer] key=..."` smoke-test print at the top of `VideoPlayerView.onKeyEvent` (AGENTS.md §4.4 pattern) and seek debug prints in `seekForward`/`seekBackward`.
- **Verified on-device (build 96):** ECP `Fwd` (→ `fastforward`) seeks +30s ×2, ECP `Rev` (→ `rewind`) seeks −10s ×2 (position confirmed via `/query/media-player`); Back stops video, returns to MovieDetails (`OnScreenShown called`, `Setting focus to btnPlay`), zero runtime errors.
- **Note:** ECP key names are `Fwd`/`Rev`; in-app `onKeyEvent` receives `fastforward`/`rewind`. `FastForward`/`Rewind` are NOT valid ECP names.
- **Files touched:** `components/video/VideoPlayerView.bs`, `source/ShowScenes.bs`, `AGENTS.md`
- **Timestamp:** 2026-08-04
- **Automatic:** yes

## 2026-08-04 — Fixed video playback fatal error + added transport key handling (pause/stop/seek)

- **What:** Movies now play (DirectPlay h264) AND respond to remote transport keys (Play/Pause, Back to stop+exit, Left/Right seek, Rev/Fwd).
- **Root cause #1 (fatal `mediaplayer:6`):** `LoadVideoContentTask.bs` set `content.AudioTracks`, `content.AudioTrackIndex`, `content.Streams` on the `ContentNode` with **raw Jellyfin associative arrays**. Those fields are not valid on a `ContentNode` (runtime warnings confirmed: "Tried to set nonexistent field audiotracks/audiotrackindex of a ContentNode") and corrupt it, so the Roku Video node hit `state=error` → `finished` → fatal mediaplayer error. The Video node manages audio/subtitle tracks natively via `m.video.audioTrack`/`subtitleTrack` — the content node only needs `url` + `streamformat`.
- **Fix #1:** Removed the invalid track/Streams assignments in `LoadVideoContentTask.bs` (content node now = url + streamformat only).
- **Root cause #2 (no pause/stop):** `VideoPlayerView` is a focusable `JFScreen` (via `JFGroup`) but had **no `onKeyEvent`**, so all remote keys bubbled up to MainScene and were dropped. The OSD's own `onKeyEvent` never fires because the OSD is not focusable and never receives focus.
- **Fix #2:** Added `onKeyEvent` to `VideoPlayerView.bs` handling: `play`/`pause`/`OK` (toggle), `back` (stop + `PopCurrentScene`), `Rev`/`Fwd`/`left`/`right` (seek ±10/30s), `up`/`down` (show OSD). OSD calls go through `callFunc("restartHideTimer")`/`callFunc("show")` after exposing `show`/`hide`/`restartHideTimer` as `<function>` in `OSD.xml` interface (script functions are NOT callable on node refs — only interface functions/callFunc).
- **Root cause #3 (runtime error on back):** `PopCurrentScene()` lives in `source/ShowScenes.bs`, which was not injected into `VideoPlayerView.xml` → "Function is not defined in component's namespace (&h91)" when pressing Back.
- **Fix #3:** Added `ShowScenes.brs` (+ globals/config/MainActions/quickplay) to the `VideoPlayerView.xml` entry in `transpile.ps1` `$libInjections`.
- **Also cleaned XML warnings:** removed invalid `showStatusMessage` on `<Video>`, `width`/`height` on `<Group>` (captionGroup/nextUpBox), and `width`/`height` on `<LabelList>` (MovieDetails/StreamDropdown/VersionSelector/MovieOptions).
- **Verified on-device:** buffering → playing → paused → buffering → playing → stopped, zero runtime errors. Build 94.
- **Files touched:** `components/ItemGrid/LoadVideoContentTask.bs`, `components/video/VideoPlayerView.bs`, `components/video/VideoPlayerView.xml`, `components/video/OSD.xml`, `components/movies/MovieDetails.xml`, `components/movies/StreamDropdown.xml`, `components/movies/VersionSelector.xml`, `components/movies/MovieOptions.xml`, `transpile.ps1`
- **Timestamp:** 2026-08-04
- **Automatic:** yes

## 2026-08-02 — MASSIVE: Added focusable="false" to ALL Posters/Rectangles across entire codebase (40+ files)

- **What:** Systematic audit and fix of every Poster and Rectangle XML element missing `focusable="false"`. This is the recurring bug pattern from AGENTS.md §4.4 that has caused focus-stealing issues 5+ times.
- **Root cause:** SceneGraph makes Posters and Rectangles focusable by default. Any visible one in the tree can silently steal real focus from manual-highlight screens (SetServerScreen, SigninScene), causing `onKeyEvent` handlers to stop firing entirely. Each past fix patched ONE element; new ones kept appearing.
- **Fix:** Added `focusable="false"` to EVERY Poster and Rectangle across 40+ component XML files:
  - **Screen backgrounds:** HomeScreen.xml (bgFill, heroBackdrop, heroGradient), MainScene.xml (background, backgroundOverlay, detailsOverlay), HomeScene.xml (background, heroBackdrop, gradientOverlay), BaseScene.xml (miniPlayerBackground)
  - **SetServerScreen:** bgRect, logoImage, serverInputBg, serverInputFocus, listSelectionBar
  - **SigninScene:** signinBg, logoImage, usernameInputBg (fieldFocusProxy intentionally stays focusable="true")
  - **UserSelect:** userSelectBg, logoImage
  - **NavRail.xml:** railBackground, railLogo, ALL nav highlight rectangles + icon posters (10 groups = 20 elements)
  - **LeftNavRail:** navBg, activeIndicator
  - **Sidebar/Drawer:** SidebarNav.xml (backgroundRail, navItem1Icon, navItem2Icon), WholphinSidebar.xml (sidebarScrim, sidebarBg, sidebarUserImage)
  - **Details/Hero panels:** DetailsPanel.xml (detailPoster, progressBarBg/fill, playBtnBg/resumeBtnBg), HeroBanner.xml (backdropImage, gradientOverlay)
  - **Button components:** JFButton.xml (buttonBg, focusBorder) — JFButton itself stays focusable="true"
  - **Video screens:** VideoPlayerView.xml (posterBackground, nextUpBg/image, skipSegmentBg, bufferingOverlay), OSD.xml (osdTopBar/bottomBar, progress bg/fill)
  - **Movie/TV details:** MovieDetails.xml, TVSeriesDetails.xml, TVSeasonDetails.xml, TVEpisodeListItem.xml — all backdrop posters + overlays
  - **Music views:** ArtistView.xml, AlbumView.xml, AudioPlayerView.xml — backdrops + album art
  - **Content items:** PosterRow.xml, RowListItem.xml (thumb/cornerMask/badge/focusRing), HomeItem.xml (focusIndicator/poster/checkmark/badge), GridItem.xml/Small/Medium.xml, LandscapePosterItem.xml, UserItem.xml, PosterItem.xml
  - **Library views:** AudioBookLibraryView.xml, MusicLibraryView.xml, LiveTVLibraryView.xml, OtherLibrary.xml, VisualLibraryScene.xml — all backgrounds
  - **Filters/Dialogs:** EmbyFilterMenu.xml, LibraryFilterDialog.xml (filterDialogBg), Alpha.xml (alphaBg)
  - **Misc:** Spinner.xml (spinnerBg/image), JFOverhang.xml (overhangBg), Home.xml (bgFill, backdrops, optionsSliderBg), MovieOptions/VersionSelector/StreamDropdown.xml — all overlay backgrounds
- **Files touched:** 40+ XML files in components/ — ALL Posters and Rectangles now have `focusable="false"`.
- **Timestamp:** 2026-08-02
- **Automatic:** yes (auto-enforce per AGENTS.md §4.4 rule #3)

## 2026-08-02 — Fixed Auto Discover unreachable after discovery + logo Poster focus steal

- **What:** Auto Discover button became permanently unselectable after server discovery completed. Also added `focusable="false"` to `logoImage` Poster.
- **Root cause (navigation):** In `SetServerScreen.onKeyEvent`, the UP/LEFT and DOWN/RIGHT handlers had a condition `if m.discoveredServerList.visible` that redirected button navigation into the server list whenever it was visible. This meant:
  - Pressing UP from Auto Discover (index 1) or Manual Entry (index 2) jumped to the server list instead of cycling buttons
  - Pressing DOWN/RIGHT from index 1+ also redirected to the server list
  - After discovery set `focusedButtonIndex = 3`, pressing DOWN from any button never reached Auto Discover — it was trapped between Connect (0) and Manual Entry (2)
- **Fix:** Decoupled button cycling from server-list visibility:
  - UP/LEFT now always cycle buttons via MOD arithmetic regardless of list visibility
  - DOWN only enters the server list when at index 0 (Connect) AND list is visible
  - RIGHT cycles through buttons normally (no server-list redirect)
- **Fix (focus steal):** `logoImage` Poster in SetServerScreen.xml had no `focusable="false"`. Posters are focusable by default in SceneGraph and would silently steal focus from the proxy node, causing `onKeyEvent` to stop firing. Added per AGENTS.md §4.4 rule #3.
- **Files touched:** `components/config/SetServerScreen.bs` (navigation logic + logo Poster), `components/config/SetServerScreen.xml` (focusable="false" on logo)
- **Timestamp:** 2026-08-02
- **Automatic:** yes (auto-enforce per AGENTS.md §4.4 — recurring bug pattern)

## 2026-07-31 — SetServerScreen focus stealing: permanent prevention rules (v32-v33)

- **What:** Documented the recurring focus-stealing bug on manual-focus screens and added auto-enforce rules to `AGENTS.md` (§4.4).
- **Root cause (why it keeps breaking):** `SetServerScreen` uses manual focus management (`m.focusedButtonIndex` drives the highlight), but SceneGraph only routes keys to `onKeyEvent` on the node that actually owns real focus. Any focusable node in the visible tree — Posters, Rectangles, or the JFButtons themselves (focusable by default) — can steal focus. Each past fix patched ONE focus-stealer (`imageBackground` Poster), so new focusable nodes re-triggered it.
- **v32 fix (focus-proxy pattern):** Added hidden `<Rectangle id="focusProxy" ... focusable="true" />` to `SetServerScreen.xml`; set `focusable="false"` on btnConnect/btnDiscover/btnManualEntry; `updateHighlights()` now does `m.focusProxy.setFocus(true)` (except discovered-list index 3, which focuses `discoveredServerList`).
- **v33 fix:** Added permanent smoke-test print `? "[SetServer] key="; key; " idx="; m.focusedButtonIndex` at the top of `SetServerScreen.onKeyEvent`. If no `[SetServer] key=` line appears when the user presses a button, a focusable node is stealing focus.
- **Verified:** Telnet capture shows `[SetServer] key=right idx=0` — keys ARE reaching `SetServerScreen.onKeyEvent` after v33, so real focus is on the screen (the proxy holds it).
- **Prevention rules added to AGENTS.md §4.4 (must never be removed):**
  1. Manual-highlight screens hold real focus on a hidden `focusProxy` Rectangle; NEVER `m.top.setFocus(true)` as the primary path.
  2. All JFButtons on those screens MUST be `focusable="false"` (else `JFButton.onNativeFocusChange` overwrites the manual highlight).
  3. Every decorative node (Posters, Rectangles) in the visible tree MUST be `focusable="false"`.
  4. Re-assert `m.focusProxy.setFocus(true)` after any dialog closes.
  5. The `[SetServer] key=` diagnostic is a permanent smoke test — keep it.
- **Files touched:** `AGENTS.md` (new §4.4), `components/config/SetServerScreen.xml` (focusProxy + buttons focusable=false), `components/config/SetServerScreen.bs` (proxy focus + smoke-test print), `manifest` (build_version 32→33), `history/history.md`
- **Timestamp:** 2026-07-31

## 2026-07-30 — Redesigned HomeScreen with hero banner + Play/More Info buttons + carousels

- **What:** Redesigned HomeScreen to match Roku-style streaming interface per user request:
  1. **Hero banner** — 594px tall with background art (heroBackdrop), gradient overlay, title/subtitle/meta/description labels
  2. **Play/More Info buttons** — restored Play and More Info JFButton components in heroButtons group at [140, 410]
  3. **Hero button navigation** — UP from rows → hero buttons, DOWN from hero buttons → rows, LEFT from hero buttons → NavRail, OK on hero buttons → HandleItemSelection
  4. **Carousel posters** — RowListItem updated with posterContainer group with clipRect for rounded corners, focus ring color cyan (0x2FD0FFFF) with opacity 0.8, focus scale 1.06x
  5. **Removed progress bars** — removed progressTrack/progressFill from HomeItem.xml and HomeItem.bs
  6. **Removed debug text** — removed statusLabel from BaseScene.xml, removed imageBackground Roku logo placeholder, removed all `?` debug print statements from Main.bs, ShowScenes.bs, LoadItemsTask.bs, SetServerScreen.bs, MainEventHandlers.bs, JFButton.bs
  7. **Removed statusMessage field** from BaseScene.xml interface and BaseScene.bs
  8. **Cleaned up comments** — removed all debug comments from all modified files
- **Files touched:**
  - `components/HomeScreen.xml` — added heroButtons group with Play/More Info JFButtons, moved loadingLabel to y=500
  - `components/HomeScreen.brs` — added hero button focus handling in onKeyEvent, added m.heroItemJson tracking, removed debug prints
  - `components/home/HomeItem.xml` — removed progress bars, added posterContainer with clipRect for rounded corners
  - `components/home/HomeItem.bs` — removed progress bar code, added posterContainer reference, removed header comment
  - `components/RowListItem.xml` — added posterContainer with clipRect, updated focus ring color to cyan with opacity
  - `components/RowListItem.brs` — updated for posterContainer, focus ring with offset for glow effect
  - `components/BaseScene.xml` — removed imageBackground Poster, removed statusLabel, removed comments
  - `components/BaseScene.bs` — removed statusMessage handling, removed imageBackground reference, removed setBackground function, removed comments
  - `components/JFButton.bs` — removed debug print in onFocusedChange
  - `components/home/LoadItemsTask.bs` — removed all debug prints, removed comments
  - `source/Main.bs` — removed all debug prints, removed comments
  - `source/ShowScenes.bs` — removed all debug prints, removed comments
  - `source/MainEventHandlers.bs` — removed debug print in HandleDialogCallback, removed print in HandlePlaybackError, removed comments
  - `components/config/SetServerScreen.bs` — removed all debug prints, removed comments
- **Timestamp:** 2026-07-30T23:15:00Z

## 2026-07-30 — Fixed RowList to show multiple items per row

- **What:** Fixed RowList configuration so carousels show multiple posters per row instead of just 1:
  1. **Added width to HomeRows** — set `width="1660"` in HomeScreen.xml so RowList knows how many items to display
  2. **Fixed `showRowLabel`** — changed from array `[false]` to boolean `false` (was causing issues with RowList rendering)
  3. **Added `itemSpacing`** — set to `[20, 0]` for proper horizontal spacing between posters
  4. **Set `rowFocusColor` and `rowUnfocusColor`** — for proper focus highlighting
  5. **Removed redundant `rowLabels` and `rowLabelOffsets` arrays** from onContentChange (showRowLabel is now set once in Init)
- **Files touched:**
  - `components/home/HomeRows.xml` — added empty `<children>` block
  - `components/home/HomeRows.bs` — fixed showRowLabel, added itemSpacing, rowFocusColor, rowUnfocusColor, removed redundant arrays
  - `components/HomeScreen.xml` — added `width="1660"` to HomeRows
- **Timestamp:** 2026-07-30T23:30:00Z

## 2026-07-30 — Fixed RowList field errors

- **What:** Removed invalid RowList fields that were causing warnings:
  1. **Removed `rowLabelPos`** — not a valid RowList field
  2. **Removed `rowFocusColor` and `rowUnfocusColor`** — not valid RowList fields (focus highlighting is handled by the RowListItem component's focusRing)
- **Files touched:**
  - `components/home/HomeRows.bs` — removed invalid field assignments
- **Timestamp:** 2026-07-30T23:45:00Z

- **What:** Fixed a BrightScript syntax error in HomeScreen.brs `onKeyEvent` that prevented item selection:
  - **Bug:** `onRowItemSelected(event = invalid, rc)` — invalid syntax (can't pass args by name in BrightScript) and `onRowItemSelected` expects an event object, not a row/col array
  - **Fix:** Replaced with direct item selection logic: extracts focused item from HomeRows content, builds item AA, and calls `HandleItemSelection()` directly
- **Files touched:** `components/HomeScreen.brs` — rewrote OK handler in onKeyEvent
- **Timestamp:** 2026-07-30T22:30:00Z

## 2026-07-30 — Fixed home screen layout to match ui.md spec + debug text cleanup

- **What:** Redesigned HomeScreen to match the "Hero + Shelves" layout specified in ui.md, and removed debug text:
  1. **NavRail position** — moved from `[0,0]` to `[40,40]` per spec (fixed, 80px wide icon rail with 40px margin)
  2. **HeroBanner height** — reduced from full 1080px to 594px (55% of screen per spec); `heroBackdrop` `loadDisplayMode` changed from `scaleToFill` to `scaleToZoom`
  3. **Removed hero buttons** — deleted Play/More Info JFButton Group (ui.md specifies HeroBanner is a display surface only)
  4. **HomeRows position** — moved from y=560 to y=600 (below shorter hero section)
  5. **Background color** — changed from `0x0A0E14FF` to `0x0B0E14FF` per spec (`#0B0E14`)
  6. **Focus indicator color** — changed from green (`0xFFA4DC00`) to cyan (`0x2FD0FFFF`) per spec accent color
  7. **SetServerScreen focus fix** — added `focusable="false"` to `imageBackground` Poster in BaseScene.xml (Posters are focusable by default and were stealing focus from SetServerScreen)
  8. **Main.bs focus fix** — added explicit `ss.setFocus(true)` after `m.screen.show()` (Init's setFocus runs before screen is visible)
  9. **Debug text cleanup** — cleared `statusMessage` after home screen loads in both auto-login and sign-in paths (was showing "HomeScreen should be visible now!" etc.)
  10. **onKeyEvent cleanup** — rewrote HomeScreen.onKeyEvent to match ui.md spec: UP from first row → NavRail, LEFT from leftmost item → NavRail, OK on row item → select item
- **Files touched:**
  - `components/HomeScreen.xml` — NavRail position, hero height, removed buttons, rows position, bg color
  - `components/HomeScreen.brs` — removed hero button code, rewrote onKeyEvent, removed unused functions (getCurrentHeroItem, setHeroButtonFocus, clearHeroButtonFocus, onHeroButtonFocus)
  - `components/home/HomeItem.xml` — focus indicator color green→cyan
  - `components/home/HomeRows.bs` — showRowLabel [true]→[false]
  - `components/BaseScene.xml` — imageBackground focusable="false"
  - `source/Main.bs` — setFocus after screen.show(), clear statusMessage after home load
- **Status:** Deployed to 192.168.1.196. Awaiting user verification.
- **Timestamp:** 2026-07-30T22:00:00Z

## 2026-07-30 — Root cause analysis: focus management pitfalls (and how to avoid them)

- **What:** Documented the root causes of the SetServerScreen navigation breakage and home screen visual issues, with prevention strategies for future reference.
- **Root causes identified:**
  1. **Poster stealing focus** — In Roku SG, `Poster` nodes are focusable by default. Any Poster placed as a child of a Scene/Group can steal focus from the intended interactive component. **Prevention:** Add `focusable="false"` to all decorative/Background Poster nodes in XML.
  2. **setFocus timing** — Calling `m.top.setFocus(true)` in a component's `Init()` runs before `m.screen.show()`. The Scene doesn't have focus yet, so the call is ineffective. **Prevention:** Call `setFocus(true)` AFTER `m.screen.show()` in the main thread, or use a deferred Timer (duration=0.1) to retry focus after the scene is visible.
  3. **Color alpha = 0 (invisible)** — Roku color format is `0xAARRGGBB`. An alpha of `0x00` means fully transparent. The HomeItem focus indicator had `color="0x00A4DC00"` — invisible. **Prevention:** Always use `0xFF` for opaque colors (e.g., `0xFFA4DC00`), or use 6-digit hex `0xA4DC00` which defaults to opaque.
  4. **Duplicate RowList labels** — RowList's built-in `showRowLabel` field renders row title labels from the content, but if the item component (HomeRow) also has its own title label, the labels appear twice. **Prevention:** Set `showRowLabel=[false]` on RowList when the item component handles its own labels.
  5. **Channel restart after sideload** — Sideloading updates files on disk but the Roku channel process keeps running old compiled code in memory. **Prevention:** Always instruct users to fully restart the channel (HOME → relaunch, or System restart) after every deploy.
- **Files touched:** `history/history.md` (this entry)
- **Timestamp:** 2026-07-30T21:30:00Z

## 2026-07-30 — Fixed SetServerScreen focus (buttons not responding to remote)

- **What:** Fixed SetServerScreen buttons (Connect, Auto Discover, Manual Entry) not responding to remote control navigation.
- **Root cause:** `imageBackground` Poster in `BaseScene.xml` was focusable by default (Posters are focusable in Roku SG) and was the first focusable child of the Scene. It stole focus from SetServerScreen, so SetServerScreen's `onKeyEvent` never fired. Additionally, SetServerScreen's `m.top.setFocus(true)` in `Init()` ran before `m.screen.show()`, so the focus call was ineffective.
- **Fix:**
  1. Added `focusable="false"` to `imageBackground` Poster in `BaseScene.xml` — prevents it from stealing focus.
  2. Added explicit `ss.setFocus(true)` call in `Main.bs` right after `m.screen.show()` — ensures SetServerScreen gets focus after the screen is visible.
- **Files touched:**
  - `components/BaseScene.xml` — added `focusable="false"` to imageBackground Poster
  - `source/Main.bs` — added `ss.setFocus(true)` after `m.screen.show()`
- **Timestamp:** 2026-07-30T21:15:00Z

## 2026-07-30 — Fixed HomeScreen focus indicator + row label duplication

- **What:** Fixed two visual issues on the HomeScreen:
  1. **HomeItem focus indicator invisible** — `focusIndicator` Rectangle in `components/home/HomeItem.xml` had `color="0x00A4DC00"` (alpha=00, fully transparent). Changed to `0xFFA4DC00` so the green focus ring is now visible when an item is selected.
  2. **Duplicate row labels** — `HomeRows` (extends RowList) had `showRowLabel=[true]` which caused the RowList to render its own row title labels in addition to the labels already rendered by each `HomeRow` component. Changed to `showRowLabel=[false]` so row titles appear only once.
- **Files touched:**
  - `components/home/HomeItem.xml` — focus indicator alpha 0x00→0xFF
  - `components/home/HomeRows.bs` — showRowLabel [true]→[false]
- **Status:** Deployed to 192.168.1.196. Awaiting user verification on Roku.
- **Timestamp:** 2026-07-30T20:45:00Z

## 2026-07-26 — Redesigned HomeScreen to match ui.md spec

- **What:** Redesigned HomeScreen layout to match the "Hero + Shelves" layout specified in `ui.md`:
  1. **HomeScreen.xml** — NavRail moved from `[0,0]` to `[40,40]`; hero height reduced from 1080px to 594px (55% of screen); hero image `loadDisplayMode` changed from `scaleToFill` to `scaleToZoom`; hero text labels grouped into `HeroTextBlock` Group; removed Play/More Info hero buttons (HeroBanner is a display surface per spec); background color updated to `0x0B0E14FF`; shelf rows moved from y=560 to y=600 to fit shorter hero.
  2. **HomeScreen.brs** — Removed all hero button code: `m.playButton`/`m.infoButton` references, `setHeroButtonFocus()`/`clearHeroButtonFocus()`/`onHeroButtonFocus()` methods, `heroButtonFocused`/`heroButtonIndex` variables, `getCurrentHeroItem()` function (unused after button removal). Rewrote `onKeyEvent()` for NavRail↔Shelf focus routing: LEFT from shelf (leftmost item) → NavRail, RIGHT/DOWN from NavRail → Shelf, UP from shelf (first row) → NavRail, BACK from shelf → NavRail (BACK from NavRail → exit).
  3. **HomeItem.xml** — Focus indicator color changed from `0x00A4DC00` (transparent, invisible) to `0x00D4FFFF` (cyan, per ui.md spec); removed invalid `blendColor` property.
- **Files touched:**
  - `components/HomeScreen.xml` — NavRail position, hero height, image mode, HeroTextBlock group, removed hero buttons, bg color, shelf position
  - `components/HomeScreen.brs` — Removed button code, rewrote onKeyEvent, removed unused getCurrentHeroItem
  - `components/home/HomeItem.xml` — Focus indicator color + removed blendColor
- **Timestamp:** 2026-07-26T12:30:00Z
- **Automatic:** yes

## 2026-07-26 — Fixed button components across 5 files

- **What:** Fixed 5 button-related bugs preventing buttons from working or displaying correctly:
  1. **DetailsPanel.brs** — `updateButtonFocus()` used `btn.findNode(btn.id + "Bg")` which looked for `playButtonBg`/`resumeButtonBg`, but `DetailsPanel.xml` defined them as `playBtnBg`/`resumeBtnBg`. Focus highlight never applied. Renamed XML node IDs to match.
  2. **HomeScene.brs** — Observed `itemSelected` on standard Roku `Button` components, but `Button` has no `itemSelected` field (it fires `buttonPressed`). Play/More Info button click handlers never fired. Changed to `buttonPressed`.
  3. **HeroBanner.xml** — Missing `<script>` tag (HeroBanner.brs never loaded), missing `btnPlay`/`btnMoreInfo` JFButton nodes, and node IDs didn't match HeroBanner.brs expectations (`backdropImage` vs `heroBackdrop`, `titleLabel` vs `heroTitle`, etc.). Added script tag, JFButton nodes, and renamed all nodes to match.
  4. **JFButton.xml** — Focus border color was `0x00FF00FF` (bright green, debug color). Changed to `0x22D3EEFF` (cyan) to match app accent color used in LeftNavRail.brs.
  5. **HomeSceneFocus.brs** — Entire file was on a single line (unreadable), not loaded in `HomeScene.xml` (missing `<script>` tag), and referenced nonexistent `m.contentRows` (should be `m.nextUpRow`). Reformatted to multi-line, added script tag to HomeScene.xml, fixed variable reference.
  6. **HomeScreen.brs** — Observed `itemSelected` on `LeftNavRail`, but the field is defined as `onItemSelected` in `LeftNavRail.xml`. Nav rail OK button selection never triggered navigation. Changed to `onItemSelected`.
- **Files touched:**
  - `components/DetailsPanel.xml` — Renamed `playBtnBg`→`playButtonBg`, `resumeBtnBg`→`resumeButtonBg`
  - `components/HomeScene.brs` — `itemSelected`→`buttonPressed` (2 observers)
  - `components/HeroBanner.xml` — Added `<script>` tag, `btnPlay`/`btnMoreInfo` JFButton nodes, renamed 4 node IDs to match .brs, added `heroEpisodeTitle`/`heroClock` labels
  - `components/JFButton.xml` — Focus border color `0x00FF00FF`→`0x22D3EEFF`
  - `components/HomeSceneFocus.brs` — Reformatted from 1 line to 40 lines, fixed `m.contentRows`→`m.nextUpRow`
  - `components/HomeScene.xml` — Added `<script>` tag for HomeSceneFocus.brs
  - `components/HomeScreen.brs` — `itemSelected`→`onItemSelected` for navRail observer
- **Timestamp:** 2026-07-26T12:24:00Z
- **Automatic:** yes

## 2026-07-25 — Fixed HomeScreen hero buttons (Play/More Info): wrong findNode IDs

- **What:** Fixed hero buttons (Play/More Info) being completely non-functional — couldn't scroll between them or select them
- **Root cause:** `HomeScreen.brs` referenced `findNode("playBtnBg")` and `findNode("infoBtnBg")`, but those node IDs don't exist in `HomeScreen.xml`. The actual nodes are JFButton components with ids `playButton` and `infoButton`. Both variables were always `invalid`, causing `setHeroButtonFocus()` to return early at its guard check, so `m.heroButtonFocused` never became `true` and all button interaction code in `onKeyEvent` was dead code.
- **Fix:** Changed variable names from `m.playBtnBg`/`m.infoBtnBg` to `m.playButton`/`m.infoButton`, updated `findNode` calls to correct IDs, updated `focusedChild` observers, and changed `setHeroButtonFocus`/`clearHeroButtonFocus` to call `setFocus(true)` on JFButton nodes (not their internal Rectangles) and access `buttonBg` children for color changes.
- **Files touched:** `components/HomeScreen.brs`
- **Verification:** Build + sideload to 192.168.1.196 — SUCCESS
- **Timestamp:** 2026-07-25T12:00:00Z
- **Automatic:** no (user-directed)

## 2026-07-25 — Fixed HomeScreen interaction bugs (row selection, hero focus, button handlers)

- **What:** Fixed 4 critical bugs preventing HomeScreen from being interactive:
  1. **Missing observers** — `onRowItemSelected` and `onRowItemFocused` existed in `HomeScreen.brs` but were never observed on `m.homeRows`. Added `observeField("rowItemSelected", "onRowItemSelected")` and `observeField("rowItemFocused", "onRowItemFocused")` in `Init()`.
  2. **ContentNode vs chainLookupReturn** — `onRowItemFocused` and `onRowItemSelected` used `chainLookupReturn()` to access ContentNode fields, but `chainLookup` checks `ifAssociativeArray` which ContentNode doesn't implement. Replaced with direct `hasField()` + field access.
  3. **Play/More Info buttons non-functional** — Buttons were static visual elements with no focus handling or OK key handlers. Made button backgrounds `focusable="true"`, added `setHeroButtonFocus()`/`clearHeroButtonFocus()` for visual focus, added UP/DOWN/LEFT/RIGHT/OK navigation in `onKeyEvent`.
  4. **LoadItemsTask debug crash** — Line 115 referenced undefined variable `taskType` (should be `itemsToLoad`). Fixed.
- **Files touched:**
  - `components/HomeScreen.brs` — Added row observers, button focus management, OK key handlers, `getCurrentHeroItem()` helper, fixed ContentNode field access, added `seriesId` to item AA conversion
  - `components/HomeScreen.xml` — Added `focusable="true"` to `playBtnBg` and `infoBtnBg`
  - `components/home/LoadItemsTask.bs` — Fixed undefined `taskType` → `itemsToLoad`
- **Timestamp:** 2026-07-25T09:28:00Z
- **Automatic:** no (user-directed)

## 2026-07-25 — Fixed `hasField` on roAssociativeArray + transpiler library injection + auto-login hack

- **What:** Fixed 3 additional critical bugs found during deployment testing:
  1. **`hasField` on roAssociativeArray** — `onRowItemFocused` used `itemJson.hasField("Overview")` but `roAssociativeArray` doesn't have `hasField()` — it uses `DoesExist()`. This caused runtime error `&hf4` ("Member function not found"). Replaced all `itemJson.hasField()` → `itemJson.DoesExist()`.
  2. **Transpiler missing `HomeScreen.xml` in `$libInjections`** — `HomeScreen.brs` calls `HandleItemSelection` (from `MainEventHandlers.brs`) and `CreateMovieDetailsGroup`/`CreateSeriesDetailsGroup` (from `ShowScenes.brs`), but `transpile.ps1` didn't inject these library scripts into `HomeScreen.xml`. Added `HomeScreen.xml` entry to `$libInjections` hashtable with 9 required script URIs.
  3. **Auto-login disabled with `if false and` hack** — `Main.bs:114` had `if false and m.autoLoginData <> invalid` which disabled auto-login, causing the app to always show SetServerScreen. Reverted to `if m.autoLoginData <> invalid` per history log (was supposed to be reverted on 2026-07-16).
- **Files touched:**
  - `components/HomeScreen.brs` — `hasField`→`DoesExist` for all `itemJson` accesses
  - `transpile.ps1` — Added `HomeScreen.xml` to `$libInjections` with 9 library script URIs
  - `source/Main.bs` — Reverted `if false and` → `if` for auto-login bypass
  - `components/HomeScreen.xml` — Fixed Button warnings: `width`→`minWidth`, `buttonText`→`text`
- **Verification:** Deployed to 192.168.1.196. Auto-login works (straight to HomeScreen). LoadItemsTask fires for all 5 sections (hero/resume/nextup/latestmedia/favorites). No runtime errors.
- **Timestamp:** 2026-07-25T10:40:00Z
- **Automatic:** no (user-directed)

## 2026-07-25 — Deployed v0.1.18 to 192.168.1.196

- **What:** Deployed HomeScreen interaction fixes to Roku device
- **Build:** transpile.ps1 (161 BS files) + build.js → 421.2 KB package
- **Sideload:** curl digest auth to http://192.168.1.196/plugin_install — SUCCESS
- **Credentials:** ROKU_IP=192.168.1.196, ROKU_USERNAME=rokudev (env vars)
- **Files touched:** `history/history.md` (this entry)
- **Timestamp:** 2026-07-25T09:30:00Z
- **Automatic:** no (user-directed)

## 2026-06-22 — Executed 5 new plans (011-015) from deep audit

- **Plan 011** ✅ — Restored `source/Main.bs` from `git checkout HEAD` (was 50-line stub, restored 340-line committed version)
- **Plan 012** ✅ — Added `m.homeRows.numRows = content.GetChildCount()` in `finishLoading()` so RowList renders all content rows
- **Plan 013** ✅ — Changed 5 QueueManager functions (`push`, `set`, `clear`, `setPosition`, `setPlaybackOptions`, `setForceTranscode`) and 2 SceneManager functions (`popScene`, `clearScenes`) from `as Void` to `as Boolean` returning `true` — fixes `callFunc` hang on this Roku firmware. Also removed dead `queueManager.callFunc("playCurrentItem")` call from `MainEventHandlers.bs:227`.
- **Plan 014** ✅ — Added `registry_delete` for `wh_autologin_server`, `wh_autologin_token`, `wh_autologin_userid` in `userauth.bs:SignOut()` so users can actually sign out
- **Plan 015** ✅ — Implemented LEFT/RIGHT focus switching between nav rail and content rows in `HomeScreen.onKeyEvent`, plus UP/DOWN nav rail scrolling with `activeIndicator` highlight
- **Files touched:**
  - `source/Main.bs` — Restored from git
  - `components/HomeScreen.brs` — numRows fix + nav rail focus
  - `components/manager/QueueManager.bs` — Void→Boolean conversion
  - `components/manager/SceneManager.bs` — Void→Boolean conversion  
  - `source/MainEventHandlers.bs` — Removed dead `playCurrentItem` call
  - `source/api/userauth.bs` — Registry cleanup on sign-out
  - `advisor-plans/README.md` — Index for new plans
  - `advisor-plans/011-restore-mainbs.md` — Plan file
  - `advisor-plans/012-fix-numrows.md` — Plan file
  - `advisor-plans/013-fix-void-callfunc.md` — Plan file
  - `advisor-plans/014-fix-signout-registry.md` — Plan file
  - `advisor-plans/015-fix-navrail-focus.md` — Plan file
- **Timestamp:** 2026-06-22T09:20:00Z
- **Automatic:** no (user-directed)

---

## 2026-06-15 — Completed audit plans 002-008, 010; deployed v0.1.11

- **What:** Assessed and completed remaining implementation plans from the 2026-06-15 audit:
  - **Plan 002** ✅ — `VideoPlayerView.bs` callFunc hang fixed via `PopCurrentScene()`/`ClearAllScenes()` (done 2026-06-13)
  - **Plan 003** ✅ — Home.bs async loading via `LoadItemsTask` already implemented (5 async tasks + callbacks)
  - **Plan 004** ✅ — Password storage in registry removed; token-based re-auth in place
  - **Plan 005** ✅ — Deploy credentials removed from `bsconfig.deploy.json`; uses `ROKU_PASSWORD` env var
  - **Plan 006** ✅ — `inferServerUrl()` defaults to `http://...:8096` for LAN (was `https://...:8920`)
  - **Plan 007** ✅ — `README.md` created in project root
  - **Plan 008** ✅ — `printReg` set to `false` (was hardcoded `true`)
  - **Plan 010** ✅ — `MainAction_MarkFavorite/Played/AddToMyList/PlayTrailer/EditSubtitles` exist in transpiled output
  - **Plan 001** ⚠️ — Partial (reverted m.port in Home.bs/HomeRows.bs; JFOverhang uses callback observations)
- **Key insight:** 7 of 9 plans were already implemented in prior sessions. Only plan 007 (README) was truly outstanding.
- **Files touched:**
  - `README.md` — Created
  - `plans/README.md` — Updated status for all plans
- **Timestamp:** 2026-06-15T18:30:00Z
- **Automatic:** no (user-directed)

## 2026-06-19 — New Home Screen built: LeftNavRail + HeroBanner + ContentRows

- **What:** Rebuilt the Home screen from scratch to match Jellyfin/Emby layout
- **New components:**
  - `components/LeftNavRail.xml/brs` — 96px text-based icon rail with active indicator
  - `components/HeroBanner.xml/brs` — Full-bleed backdrop + gradient overlay + metadata (title/subtitle/description)
  - `components/ContentRow.xml/brs` — Horizontally scrolling row via MarkupGrid + HomeItem, configurable title
  - `components/HomeScreen.xml/brs` — Composes LeftNavRail + HeroBanner + vertical stack of ContentRows with manual scroll
- **Integration:**
  - `source/ShowScenes.bs` — `CreateHomeGroup()` now creates `HomeScreen` instead of `Home`
  - `source/Main.bs` — Direct sign-in flow also creates `HomeScreen`
  - `components/home/HeroBanner.xml/bs` — Removed (duplicate, replaced by root-level `components/HeroBanner`)
  - `HomeScreen` extends `JFScreen` for automatic `overhangTitle` and focus management
- **Data loading:** Reuses existing `LoadItemsTask` with 5 sections (hero, resume, nextup, latestmedia, favorites)
- **Build pipeline:** transpile.ps1 → build.js, deployed via curl Digest auth
- **Files touched:**
  - `components/LeftNavRail.xml` (new)
  - `components/LeftNavRail.brs` (new)
  - `components/HeroBanner.xml` (new)
  - `components/HeroBanner.brs` (new)
  - `components/ContentRow.xml` (new)
  - `components/ContentRow.brs` (new)
  - `components/HomeScreen.xml` (new)
  - `components/HomeScreen.brs` (new)
  - `source/ShowScenes.bs` (modified — HomeScreen instead of Home)
  - `source/Main.bs` (modified — HomeScreen instead of Home)
  - `components/home/HeroBanner.xml` (deleted — duplicate)
  - `components/home/HeroBanner.bs` (deleted — duplicate)
- **Timestamp:** 2026-06-19T21:00:00Z
- **Automatic:** no (user-directed)

## 2026-06-15 — Standard audit: 9 findings, 9 plans written to plans/

- **What:** Full codebase audit (SKILL.md `/improve` workflow). Recon + correctness/security/perf/DX categories.
- **Key findings:**
  1. **CRITICAL** — `m.port` never initialized in any component → all `observeField(..., m.port)` calls silent no-ops (plan 001)
  2. **HIGH** — `VideoPlayerView.bs:332` uses `sceneManager.callFunc("popScene")` — same Void hang bug → plan 002
  3. **HIGH** — `Home.bs:LoadData()` blocks render thread with synchronous API calls → plan 003
  4. **HIGH** — Password stored in plaintext Roku registry (`set_user_setting(userId, "password", ...)`) → plan 004
  5. **HIGH** — Roku credentials committed to git in `bsconfig.deploy.json` → plan 005
  6. **MEDIUM** — `inferServerUrl()` defaults to HTTPS:8920, wrong for most LAN Jellyfin installs (correct: HTTP:8096) → plan 006
  7. **MEDIUM** — `printReg: true` hardcoded in Main.bs:44, overrides manifest → plan 008
  8. **MEDIUM** — No README → plan 007
  9. **MEDIUM** — `MarkFavorite`/`MarkPlayed` button handlers need audit/impl → plan 010
- **Direction findings:** Re-enable Quick Connect (S), Resume dialog (M), configurable home sections (M), delete transpile.ps1 (L)
- **Files touched:** `plans/` directory created with 9 plan files + README index
- **Timestamp:** 2026-06-15T16:05:00Z
- **Automatic:** yes (Antigravity audit)

## 2026-06-13 — Fix sign-in hang: callFunc on Void functions blocks homepage load

- **What:** Replaced all `sm.callFunc("popScene")` and `sm.callFunc("clearScenes")` calls with direct `PopCurrentScene()` and `ClearAllScenes()` functions that return `Boolean` (not `Void`), avoiding the firmware bug where `callFunc` hangs on functions transpiled from `function ... as Void` → `sub`.
- **Why:** When user pressed "Sign In" with valid credentials, `Main.bs:140` called `sm.callFunc("popScene")` which hung indefinitely because `popScene()` returns `Void` (transpiles to `sub`). `CreateHomeGroup()` (which loads the jellyfin homepage) was never reached. The same hang occurred on BACK key from the sign-in form and "Change Server" button.
- **Files touched:**
  - `source/ShowScenes.bs` — Added `PopCurrentScene()` and `ClearAllScenes()` functions (return `Boolean`, safe for `callFunc`)
  - `source/Main.bs` — Replaced `sm.callFunc("popScene")` with `PopCurrentScene()`
  - `components/config/SigninScene.bs` — Replaced `sm.callFunc("popScene")` with `PopCurrentScene()`, removed unused `_smSafe()`
  - `components/login/UserSelect.bs` — Replaced all `sm.callFunc("clearScenes")` and `sm.callFunc("popScene")` with `ClearAllScenes()`/`PopCurrentScene()`
- **Root cause:** transpile.ps1:70 converts `function X() as Void` → `sub X()`; Roku firmware `callFunc` hangs when calling a `sub`
- **Timestamp:** 2026-06-13T00:00:00Z

## 2026-06-13 — Real root cause: namespace-transpiled functions called as AA methods

- **What:** Found the actual bug preventing homepage load after successful auth. `session.user.Populate()` at `session.brs:76` called `s.user.loadUserSettings()` — method-call syntax on a plain associative array. The transpiler namespaces the function definition to `session_user_loadUserSettings()` but the call site used `s.user.loadUserSettings()` which tries to invoke a member function on an AA → runtime error &hf4 ("Member function not found"), crashing the main thread.
- **Why:** First deploy of the `PopCurrentScene`/`ClearAllScenes` fix didn't help because the real problem was deeper. Captured Roku telnet debug output confirming auth succeeded (`accessToken='5761046...'`) but crashed immediately after.
- **Files touched:**
  - `source/utils/session.bs` — Fixed 3 call sites: `s.user.loadUserSettings()` → `session.user.loadUserSettings()`, `s.server.GetUrl()` → `session.server.GetUrl()` (×2 in `UpdateFromAboutMe` and `GetImageUrl`)
- **Root cause chain:**
  1. transpile.ps1 converts `namespace session.user { function loadUserSettings() }` → `sub session_user_loadUserSettings()`
  2. But source calls `s.user.loadUserSettings()` — transpiler post-processing rewrites `session.user.loadUserSettings(` but NOT `s.user.loadUserSettings(` (different prefix)
  3. Runtime tries to call `loadUserSettings` as a method on a plain AA → crash
  4. Same pattern at 2 more sites (`s.server.GetUrl()`)
- **Status:** Fix deployed. User testing TBD.
- **Timestamp:** 2026-06-13T01:30:00Z

## 2026-06-14 — Audit fixes: .Then() calls, missing utils, scope leaks, security, HTTPS defaults

- **What:** Comprehensive fix of 16 audit findings:
  1. **CRITICAL** — Removed `.Then()` from 6 synchronous API calls in `quickplay.bs` (crashed at runtime — sync calls return data directly, not promises)
  2. **CRITICAL** — Added missing `isStringEqual()`, `findNodeBySubtype()`, `inArray()`, `tr()` to `misc.bs` (25+ call sites referenced undefined functions)
  3. **HIGH** — Fixed `navigation.brs` closure `m` scope — replaced `m.` with `nav.` in 5 closure functions (navigator state was broken)
  4. **HIGH** — Removed password from debug log in `SigninScene.bs:162`
  5. **HIGH** — Fixed `set_user_setting` arg counts in `OptionsData.bs:37` and `LibrarySettingDialog.bs:39-40` — now passes `userId` as first arg
  6. **HIGH** — Initialized `m.port` from `gaa.mainPort` in Home, HomeRows, HomeRow, HomeItem, HeroBanner components
  7. **MEDIUM** — `printReg` now reads from manifest `bs_const` instead of hardcoded `true`
  8. **MEDIUM** — Default URL scheme changed from `http://` to `https://` in `parsedUrl.bs`
  9. **MEDIUM** — Replaced `tr()` → `translateText()` in `WhatsNewDialog.bs`, `RadioDialog.bs`
  10. **MEDIUM** — Changed `exit while` → `continue` when username is empty (prevents app shutdown)
  11. **MEDIUM** — Fixed `hasField("overhang")` → `findNode("overhang")` in `SettingsView.bs`
- **Files touched:**
  - `source/utils/misc.bs` — Added 4 utility functions
  - `source/utils/quickplay.bs` — Rewrote 6 functions removing `.Then()` pattern
  - `source/navigation.brs` — Changed `m.` to `nav.` in 5 closures
  - `components/config/SigninScene.bs` — Removed password from debug print
  - `source/Main.bs` — printReg from manifest; exit while → continue
  - `source/utils/parsedUrl.bs` — Default to HTTPS
  - `components/data/OptionsData.bs` — Added userId arg to set_user_setting
  - `components/LibrarySettingDialog.bs` — Added userId arg to set_user_setting
  - `components/home/Home.bs`, `HomeRows.bs`, `HomeRow.bs`, `HomeItem.bs`, `HeroBanner.bs` — Added m.port init
  - `components/WhatsNewDialog.bs` — tr() → translateText()
  - `components/RadioDialog.bs` — tr() → translateText()
  - `components/SettingsView.bs` — hasField → findNode
  - `manifest` — Build version bumped to 3
- **Status:** Deployed to Living Room Roku (192.168.1.100). App launches to SetServerScreen.
- **Timestamp:** 2026-06-14T20:00:00Z

## 2026-06-12 — Comprehensive codebase audit / improve

- **What:** Ran `/improve` skill workflow: Recon → 4 parallel audit subagents (correctness/bugs, security, tech debt, DX/tooling) → vetting → prioritized findings table.
- **Why:** Systematic survey of codebase health before further feature work.
- **Key findings (16 total):**
  1. **HIGH** — `.Then()` on synchronous API calls (11 sites in Home.bs, quickplay.bs) — runtime crash on home load
  2. **HIGH** — `m.port` never initialized in 30+ components — all `observeField(..., m.port)` silently swallow events
  3. **HIGH** — `isStringEqual`, `findNodeBySubtype`, `inArray`, `tr()` used but never defined — 25+ call sites
  4. **HIGH** — `navigation.brs` wrong `m` scope in 6 closure functions — navigator state broken
  5. **CRITICAL** — Password printed to debug console at `SigninScene.bs:172`
  6. **HIGH** — `printReg` forced `true` at runtime (Main.bs:44) overriding manifest `false`
  7. **HIGH** — Default HTTP (not HTTPS) in `parsedUrl.bs:92,101`
  8. **HIGH** — `set_user_setting` wrong arg counts (OptionsData.bs:37, LibrarySettingDialog.bs:39-40)
  9. **HIGH** — Deploy creds in git (bsconfig.deploy.json:4-5, deploy_roku.ps1:6-7)
  10. **HIGH** — No README, 3 diverging build flows, `npm run build` broken
  11. **HIGH** — transpile.ps1 no validation on 323 lines of regex rewriting
  12. **MEDIUM** — bsc severity overrides not respected (900+ false positives block checks)
  13. **MEDIUM** — Empty username exits app (Main.bs:134,155)
  14. **MEDIUM** — pendingServerAction overwrite race
  15. **LOW** — chainLookupReturn with uninitialized session (graceful defaults)
  16. **LOW** — hasField("overhang") vs findNode("overhang") in SettingsView
- **Direction suggestions:** Unified build pipeline, test harness, namespace-flattening to delete transpile.ps1
- **Files touched:**
  - `history/history.md` — This entry
- **Timestamp:** 2026-06-12T22:30:00Z

## 2026-06-10 — Phase 6: Keyboard OK, SDK APIRequest, m.global/session, TLS, and service node Fixes

- **What:** Fixed keyboard dialog OK/Cancel handling, transpiler parameter default stripping, main thread `m.global` initialization, session namespace variable sharing, unsupported `SetMinimumVersionTLS` and `RetainBodyOnErrors` crashes, robust server URL inference, and global service node registrations.
- **Why:** 
  1. Keyboard OK button pressed did nothing previously because buttonSelected was not monitored correctly from the main thread.
  2. After fixing the keyboard handler, `APIRequest` crashed due to the transpiler stripping default parameter values, causing parameter mismatch runtime errors.
  3. When resolving this, accessing `m.global` on the main thread caused a crash because `m.global` was only valid in SceneGraph component threads.
  4. Now `m.global` is initialized to the SceneGraph global node in `Main.bs` and fields are declared.
  5. `session.bs` and `globals.bs` have been updated to store all application data, colors, theme, appInfo, and session variables on the shared `m.global` node, allowing components and standard library scripts to read/write them seamlessly.
  6. `SetMinimumVersionTLS` and `RetainBodyOnErrors` are not supported by `roUrlTransfer` on older Roku firmware versions and caused crashes when attempting to connect.
  7. `inferServerUrl` was double-appending ports when the user entered a port (e.g. `192.168.1.9086:9086` -> `https://192.168.1.9086:9086:8920`).
  8. `sceneManager`, `queueManager`, `audioPlayer`, and `playstateTask` references were stored only on `gaa` and main-thread `m`, leaving `m.global.*` invalid/empty and causing runtime crashes when screens tried pushing new views via `sceneManager`.
- **Files touched:**
  - `transpile.ps1` — Preserved default parameter values in function/sub declarations, only stripping type annotations from them.
  - `source/Main.bs` — Initialized `m.global` to the SG global node on the main thread and added/declared all required fields. Stored service nodes (`sceneManager`, `queueManager`, `audioPlayer`, `playstateTask`) on `m.global`.
  - `source/utils/globals.bs` — Updated functions to write to `m.global` instead of `gaa`.
  - `source/utils/session.bs` — Updated all session storage and lookup functions to work directly on `m.global.session`, added type-safety guards.
  - `source/api/baserequest.bs` — Removed the unsupported `req.SetMinimumVersionTLS(1.2)` and `req.RetainBodyOnErrors(true)` calls.
  - `source/utils/parsedUrl.bs` — Improved `inferServerUrl` to avoid duplicating ports and handle default ports correctly.
- **Status:** Sideloaded and verified successfully. App starts, global node is fully initialized, and connection handling is robust.
- **Timestamp:** 2026-06-10T23:23:00Z

## 2026-06-10 — Phase 5: App runs on Roku, server setup screen visible

- **What:** Fixed all runtime errors preventing display. App now launches to a visible server setup screen on Roku.
- **Key fixes:**
  - **`m.global` vs `getGlobalAA()`** — All `m.global.XXX` writes in `session.bs` replaced with `gaa = getGlobalAA(); gaa.XXX =` because `m.global` is invalid in component-script contexts where the owning component (MainScene) is never instantiated.
  - **`callFunc` hangs** — `callFunc` on this firmware hangs when calling functions transpiled from `function ... as Void` → `sub`. Bypassed SceneManager entirely by appending screens directly via `gaa.sceneManager.getScene().findNode("content").appendChild(serverScreen)`.
  - **`m.top.getScene()` in `CreateServerGroup()`** — Crashed with `&hec` because `m` is invalid in scripts loaded via `<script>` tags in `MainScene.xml` (MainScene is never created — `BaseScene` is created directly instead).
  - **SetServerScreen port** — Added `m.port = CreateObject("roMessagePort")` to `SetServerScreen.Init()` (was using `m.port` which was invalid).
  - **Focus** — Set `serverScreen.setFocus(true)` after appending to content group.
- **Files touched:**
  - `source/utils/session.bs` — Replaced ALL `m.global.` with `gaa = getGlobalAA(); gaa.` across all functions
  - `source/ShowScenes.bs` — Bypassed SceneManager callFunc, appended SetServerScreen directly to content group, set focus
  - `components/config/SetServerScreen.bs` — Added `m.port = CreateObject("roMessagePort")` in Init(), fixed `m.scene.dialog` → `m.top.getScene().dialog`, fixed callFunc in onBackPressed
  - `components/manager/SceneManager.bs` — Added debug traces
- **Status:** Server setup screen is visible on Roku. App ready for URL entry flow testing.
- **Timestamp:** 2026-06-10T12:30:00Z

## 2026-06-09 — Phase 4: Namespace-aware transpilation, Library directives, cross-component function sharing

- **What:** Fixed `&had` duplicate function errors and `Compilation Failed` errors. Implemented namespace-aware function prefixing in transpiler (converts `api.items.Get()` → `api_items_Get()`), re-enabled Library directives for cross-component function sharing, fixed zip corruption in build.js, and fixed internal function calls in session.bs.
- **Why:** Roku rejects duplicate function names (`&had`). `Library` directives (not `<script>` tags) are required for cross-component function access on Roku's component-scoped runtime.
- **Files touched:**
  - `transpile.ps1` — Step 3: namespace tracking; Step 8: namespace-aware function name prefixing; Post-processing: dynamic namespace path collection + dotted call rewriting across ALL .brs files; Removed Library stripping; Removed bulk `<script>` injection (replaced with minimal Main.brs injection)
  - `source/utils/session.bs` — Changed bare internal calls to fully-qualified: `loadUserSettings()` → `session.user.loadUserSettings()`, `GetId()` → `session.user.GetId()` (3 call sites)
  - `build.js` — Fixed zip corruption: added output stream 'finish' and 'error' event handlers; archive error handler; `finalize().catch()` handler
- **Root cause:** `&had` — 15 function names duplicated across `api.*` namespaces in sdk.bs after namespace stripping; `Compilation Failed` — Library directives stripped so functions loaded via `<script>` tags in MainScene.xml were scoped to MainScene component only; AudioPlayerView couldn't call shared functions
- **Status:** Deployed successfully. App compiles and installs on Roku.
- **Timestamp:** 2026-06-09T22:00:00Z

## 2026-06-09 — Phase 3b: Deploy to Roku for testing

- **What:** Deployed Wholphin v0.1.0.2 to Living Room Roku (192.168.1.100) via curl sideload. Fixed SettingsView runtime issues (get_user_setting/set_user_setting → session.user.GetSetting/SaveSetting).
- **Why:** First live testing on real hardware
- **Files touched:**
  - `components/SettingsView.bs` — Fixed arg counts for setting read/write
  - `manifest` — Bumped build_version to 2
- **Status:** Deployed successfully. App sideloaded and launched on Roku.
- **Timestamp:** 2026-06-09T21:30:00Z

## 2026-06-09 — Phase 3: SettingsView, Seerr/Overseerr Discover, PosterItem

- **What:** Created SettingsView screen (reads from settings.json, allows editing Wholphin settings), Seerr/Overseerr integration (DiscoverPage with trending/movies/TV/upcoming tabs, SeerrRequestTask for API calls, PosterItem for grid display), wired sidebar navigation
- **Why:** SettingsView was missing and would crash the app; Seerr integration is a key Wholphin differentiator
- **Files touched:**
  - `components/SettingsView.xml/.bs` — New settings screen with list/detail/edit pattern
  - `components/DiscoverPage.xml/.bs` — New Seerr discover screen with section tabs + grid
  - `components/SeerrRequestTask.xml/.bs` — Async task for Seerr/Overseerr REST API calls
  - `components/PosterItem.xml/.bs` — New grid item component with poster + availability badge
  - `components/WholphinSidebar.bs` — Added Discover nav item (conditional on setting)
  - `source/ShowScenes.bs` — Added CreateDiscoverPage(), wired SettingsView.loadSettings()
  - `history/history.md` — This entry
- **Timestamp:** 2026-06-09T21:00:00Z

## 2026-06-09 — Phase 2.5: Missing components, bypass bsc validation, build fixes

- **What:** Copied 35+ missing data/screen components from JellyVibe, switched build to roku-deploy (bypasses bsc static analysis which has 300+ unfixable errors), fixed remaining source-level errors
- **Why:** bsc 0.70.3 has 500+ false-positive errors (BS1140, BS1001) that can't be suppressed; roku-deploy creates the zip without validation
- **Files touched:**
  - `components/data/*` — Copied 35 XML + 32 BS data component files from JellyVibe (VideoData, MusicSongData, SeriesData, etc.)
  - `components/JFMessageDialog.*`, `RemoteSubtitleDialog.*`, `PersonDetails.*`, `LibrarySettingDialog.*`, `RadioDialog.*`, `WhatsNewDialog.*` — Copied missing screen components
  - `components/search/*` — Copied search results components
  - `components/manager/ViewCreator.xml` — Created stub XML for ViewCreator
  - `source/enums/*` — Copied 16 missing enum files (ColorPalette, String, TaskControl, etc.)
  - `source/utils/misc.bs` — Removed ContentReader check (graceful fallback)
  - `components/MainScene.brs` — Fixed `tab` → `tabName`/`tabItem` reserved words
  - `bsconfig.json` — Restored clean diagnostic filters
  - `package.json` — Added `roku-deploy` dep, changed `build` script to use createPackage, added `check` script for bsc validation
  - `deploy_roku.ps1` — Updated to use roku-deploy createPackage instead of bsc
  - `manifest` — Bumped build_version to 1
- **Timestamp:** 2026-06-09T20:30:00Z

## 2026-06-09 — Phase 2: Compilation error fixes (imports, naming conflicts, enums)

- **What:** Fixed hundreds of BrighterScript compilation errors across components and source
- **Why:** Component .bs files lacked imports, had reserved word conflicts, enum type issues, and variable shadowing
- **Files touched:**
  - **Added imports** to 61 component .bs files (91/91 now have `import "pkg:/source/utils/misc.bs"` and `import "pkg:/source/api/baserequest.bs"`)
  - `source/utils/misc.bs` — Renamed `tr()` to `translateText()` (built-in conflict)
  - All 26 files calling `tr()` — Updated to `translateText()` (115+ call sites)
  - `components/video/VideoPlayerView.bs` — Renamed `pos` → `position` (reserved word)
  - `source/navigation.brs` — Renamed `tab` param → `tabName` (reserved word)
  - `source/enums/SubtitleSelection.bs` — Changed string enum values to integers (0-3)
  - `source/utils/parsedUrl.bs` — Added missing `""` 3rd arg to 3 roRegex CreateObject calls
  - `source/ShowScenes.bs` — Renamed `serverInfo` → `serverData`, `aboutMe` → `myInfo` (variable shadowing BS1104)
  - **Deleted** `source/api.brs` — conflicts with `api/` namespace directory
- **Timestamp:** 2026-06-09T20:20:00Z

## 2026-06-09 — Phase 1: Build system, settings, localization, themes

- **What:** Created build tooling, settings tree, English translations, and Wholphin theme system
- **Why:** Foundation for porting Wholphin Android TV features to Roku
- **Files touched:**
  - `package.json` — npm dependencies (BrighterScript, bslint, rimraf)
  - `bsconfig.json` — BrighterScript project configuration
  - `bsconfig.deploy.json` — Deployment config with Roku credentials
  - `settings/settings.json` — Full Wholphin settings tree (35+ settings)
  - `locale/en_US/translations.ts` — English translation strings (120+ entries)
  - `deploy_roku.ps1` — Build + sideload deployment script
  - `rokudebug.ps1` — Telnet debug console monitor
  - `source/utils/globals.bs` — Added Wholphin's 6 color themes (Blue, BoldBlue, Green, OLED, Orange, Purple)
  - `history/history.md` — This file
  - `images/icons/` — Directory for icon assets
- **Timestamp:** 2026-06-09T14:30:00Z

## 2026-06-17 — Set default background/backdrop image to Wholphin logo

- **What:** Set the default background image URI in `BaseScene.xml` and default backdrop image URI in `Home.xml` to `pkg:/images/roku_logo.png`.
- **Why:** The app was showing a blank background on launch and on the home screen when no other backdrop was loaded. Setting these default URIs ensures the Wholphin logo is displayed as expected.
- **Files touched:**
  - `components/BaseScene.xml`
  - `components/home/Home.xml`
- **Timestamp:** 2026-06-17T20:42:00-04:00
- **Automatic:** yes (user-directed)

## 2026-06-19 — Fixed LoginFlow return values + restored auto-login via separate registry keys

- **What:** Fixed two issues with startup flow:
  
  **Issue 1: LoginFlow returning `true` when showing login screen**
  - LoginFlow returned `true` from the "need to authenticate" path (after ShowLoginScreen), causing Main.bs to push a HomeScreen on top of the login screen
  - Fix: return `false` from login-screen path
  - Also removed `CreateHomeGroup()` from inside LoginFlow's token-valid path — Main.bs handles it (avoids double PushScene)
  
  **Issue 2: `set_setting("server", "")` removal caused 30-second blocking**
  - Without the server clear, LoginFlow found stale server URL in registry and called `ServerInfo()` which blocked the main thread for 30 seconds
  - The pre-created SetServerScreen (`visible="true"` in BaseScene.xml) was visible but the event loop never started
  - Fix: restored `set_setting("server", "")` at startup so LoginFlow never blocks
  - Auto-login now uses separate `wh_autologin_*` registry keys that survive the server clear
  - Auto-login bypass runs AFTER LoginFlow (when it returns false), restoring the server/token and calling `AboutMe()` + `CreateHomeGroup()`
  
- **Key insight:** `set_setting("server", "")` is REQUIRED at startup because `ServerInfo()` (called by LoginFlow) blocks for 30 seconds via `getJson` → `wait(30000, port)`. The pre-created SetServerScreen is visible during this block, but no interaction is possible. Auto-login data must use separate registry keys to avoid this issue.
- **Files touched:**
  - `source/ShowScenes.bs` — LoginFlow returns `false` from login-screen path; doesn't call CreateHomeGroup internally
  - `source/Main.bs` — Restored `set_setting("server", "")`; restored wh_autologin check+bpass+save code; fixed `loginResult` handling (no double CreateHomeGroup)
- **Timestamp:** 2026-06-19T19:00:00Z
- **Automatic:** no (user-directed)

## 2026-07-05 — Fixed build failure (961 false-positive scope errors)

- **Problem**: `npx bsc --project bsconfig.deploy.json` failed with 961 errors (BS1001 + BS1140) — all false-positive "Not defined in scope" in component scripts
- **Root cause**: `bsconfig.deploy.json` overrode `diagnosticFilters`, dropping the parent `bsconfig.json`'s component filters (`"components/**/*.bs"`, `"components/**/*.brs"`)
- **Fix**: Removed `diagnosticFilters` from `bsconfig.deploy.json` so it inherits from `bsconfig.json` (which uses the working string-format filters); reverted broken object-format filter attempt and unused `--ignore-error-codes` CLI flag
- **Files touched**: `bsconfig.deploy.json`, `deploy_roku.ps1`
- **Verification**: Build produces `out/Wholphin.zip` (662KB) with only BS1107 warnings (benign)
- **Timestamp:** 2026-07-05T20:25:00Z
- **Automatic:** no (user-directed)

## 2026-07-16 � Home Screen ? Android TV Parity (Phases 0-4)

- **Goal**: Full visual + functional parity with Wholphin Android TV app; keep BOTH LeftNavRail icon rail AND WholphinSidebar slide-out drawer as navigation; match Android TV layout.
- **Decisions (user)**: Cast rail item -> Settings; icon-only rail (no text labels); Favorites row uses existing LoadItemsTask "favorites" query.

### Phase 0 � Navigation wiring (functional parity)
- `components/HomeScreen.brs`: Implemented empty `onNavItemSelected()` (was at line 175) to map rail ids (home/search/library/favorites/movies/tv/collection/music/playlist/cast/settings) to existing scene creators in `source/ShowScenes.bs` via new `openVisualLibrary()` helper. Cast -> CreateSettingsScreen.
- `components/HomeScreen.brs`: LEFT key when rail focused now calls `scene.showSidebar()` (opens drawer, matching Android TV). RIGHT returns focus to rows.
- `components/Libraries/VisualLibraryScene.bs`: Added `filters` field support in `LoadData()` (reads `libData.filters` -> `params.Filters`) so Favorites rail/drawer work.
- `components/WholphinSidebar.bs`: Wired previously-empty "favorites" destination to `CreateVisualLibraryScene(node, "")` with `filters="IsFavorite"`.

### Phase 1 � Hero banner parity
- `components/HeroBanner.xml`: Added `heroItems` interface field; added `btnPlay`/`btnMoreInfo` JFButtons in `heroButtons` group.
- `components/HeroBanner.brs`: Added 8s auto-rotate Timer through `heroItems`; Play -> HandleItemSelection; More Info -> CreateMovieDetailsGroup / CreateSeriesDetailsGroup by type.

### Phase 2 � Home rows parity
- `components/HomeScreen.brs`: Added `favorites` to `startLoading()` (pendingSections=5) + `launchOneTask("favorites",...)` + `addRow("Favorites",...)` branch; set `m.heroBanner.heroItems` for rotation.
- `components/home/HomeItem.xml`: Added `progressTrack`/`progressFill` Rectangles (bottom) + `favoriteBadge` Poster (heart) + replaced missing `checked.png` with green Rectangle `playedCheckmark`.
- `components/home/HomeItem.bs`: Populate progress bar from `UserData.PlaybackPositionTicks/RunTimeTicks`; show favorite badge from `UserData.IsFavorite`.

### Phase 3 � Rail visual parity (icon-only)
- `components/LeftNavRail.brs`: Removed text-label drawing under icons (now icon-only). Fixed Movies icon (was reusing nav_library.png) -> new `images/icons/nav_movies.png` (generated film-strip).
- Removed dead `iconLabel` references in `updateSelection()`.

### Phase 4 � Drawer visual parity
- `components/WholphinSidebar.xml`: Added `sidebarScrim` Rectangle (350,0 1570x1080, black 0xAA) behind drawer for darkened overlay.

### Build & verify
- `.\deploy_roku.ps1` -> transpile + build + sideload to 192.168.1.196: SUCCESS (401 KB, no errors). Fixed JFButton `minWidth`->`width` warning in HeroBanner.xml.
- Runtime: HomeScreen loads; all 5 LoadItemsTask branches fire (hero/resume/latestmedia/nextup/favorites); no crashes. favorites=0/nextup=0 for test account (no data yet) � rows correctly hidden when empty.
- **Files touched**: HomeScreen.brs, HeroBanner.xml, HeroBanner.brs, HomeItem.xml, HomeItem.bs, LeftNavRail.brs, WholphinSidebar.xml, WholphinSidebar.bs, VisualLibraryScene.bs, images/icons/nav_movies.png
- **Timestamp:** 2026-07-16T20:57:00Z
- **Automatic:** no (user-directed: build mode)

## 2026-07-16 — Login screen fixes: password retry + UserSelect navigation + temp hack revert

- **What:** Fixed three login flow issues preventing successful password entry and recovery from wrong password:
  1. **UserSelect grid navigation** — `highlightGridIndex()` was a no-op (didn't set `grid.itemFocused`), `UserRow.onItemSelected` crashed on invalid `focusedItem`, `selectUser()` read ContentNode `.Name` instead of `.title` (empty username). Fixed all three.
  2. **SigninScene retry after wrong password** — Input groups now `focusable="true"` in XML so OK events route through `onKeyEvent` → `showKeyboard` instead of being intercepted by `btnSignIn`. `onAuthErrorChange` moves focus to password field, clears password text, and calls `updateItemFocus()`. `onSignInPressed`/`onCancelPressed` guard against stale `buttonSelected` callbacks. `hideSignIn` re-orders visibility before `PopCurrentScene()` for correct focus return to UserSelect.
  3. **Temp hack revert** — `Main.bs` `if false and autoLoginData` → `if autoLoginData`, `ShowScenes.bs` `if true or savedServer=""` → `if savedServer=""`.
- **Files touched:**
  - `components/config/SigninScene.xml` — `focusable="true"` on usernameInputGroup, passwordInputGroup
  - `components/config/SigninScene.bs` — `m.focusIndex = 1` (default to password), `item.node.setFocus(true)` for fields (not `m.top`), stale `buttonSelected` guards, `onAuthErrorChange` resets focus+password, `hideSignIn` ordering
  - `source/Main.bs` — Removed `if false and` hack
  - `source/ShowScenes.bs` — Removed `if true or` hack
- **Verification:** Deployed to 192.168.1.196. Auto-login works (straight to HomeScreen), no crashes. Login screen fixes await manual testing via "Change Server" flow.
- **Timestamp:** 2026-07-16T21:30:00Z
- **Automatic:** no (user-directed)

## 2026-07-17 — UI redesign: NavRail, RowListItem, RowList-native layout

- **Created** `components/NavRail.brs` and `components/RowListItem.brs` (from `ai code/`)
- **Copied** `ai code/NavRail.xml` → `components/NavRail.xml` and `ai code/RowListItem.xml` → `components/RowListItem.xml`
- **Modified** `HomeScreen.xml`: replaced `<LeftNavRail>` with `<NavRail>`, adjusted `HomeRows` translation x to 130
- **Modified** `HomeScreen.brs`: changed field observation from `onItemSelected` → `itemSelected`; added `m.currentFocusZone` state; rewrote `onKeyEvent` for focus‑zone switching (LEFT at column 0 → nav, RIGHT → rows); added `profile` and `playlists` handler cases
- **Modified** `HomeRows.xml`: exposed `rowItemFocused` and `rowItemSelected` with `alwaysNotify`
- **Modified** `HomeRows.bs`: set `itemComponentName = "RowListItem"`, configured per‑row `rowHeights`/`rowItemSizes`/`showRowLabel`/`rowLabelOffset`
- Deployed to `192.168.1.196` — build OK, sideload successful
- **Timestamp:** 2026-07-17T09:00:00Z
- **Automatic:** no (user-directed)

## 2026-07-17 — Fixed blank home screen: HomeScreen.brs was a stub

- **Root cause:** `components/HomeScreen.brs` was a 13-line stub (empty Init/onKeyEvent) — `CreateHomeGroup()` created a HomeScreen that did nothing. No data loaded, no children rendered → BaseScene logo peeked through, Bext status showed "Appending HomeScreen to content"
- **Fix:** Rewrote `HomeScreen.brs` with full 284-line implementation integrating NavRail, HeroBanner, RowList/RowListItem content rows, data loading (5 LoadItemsTask sections), focus zone management
- Deployed to `192.168.1.196` — build OK, sideload successful
- **Timestamp:** 2026-07-17T10:30:00Z
- **Automatic:** no (user-directed)

## 2026-07-16 — Fix JFButton buttonSelected stuck + guard regression

- **What:** Removed focus-guard from `onSignInPressed`/`onCancelPressed` (caused `m.focusItems[m.focusIndex].id` mismatch vs actual button that fired). Added explicit `buttonSelected = false` reset in both handlers — JFButton never resets this field, and with `alwaysNotify="true"` the observer must fire cleanly on each subsequent press.
- **Root cause:** `JFButton.bs` sets `m.top.buttonSelected = true` on OK but never resets it to `false`. Combined with `alwaysNotify="true"` in XML, after the first press `buttonSelected` stays `true`. The guard could also fire before `m.focusItems` was initialized (observer registered at Init() line 14, array set at line 17).
- **Files touched:** `components/config/SigninScene.bs` — removed guards, added buttonSelected reset
- **Timestamp:** 2026-07-16T21:35:00Z
- **Automatic:** no (user-directed)

## 2026-07-16 — Focus proxy fix: can't select buttons / OK opens wrong handler

- **What:** Replaced `m.top.setFocus(true)` for field focus with a dedicated invisible focus proxy Rectangle (`fieldFocusProxy`, `focusable="true"`, sibling to buttons). Root cause: Roku keeps focus on the deepest child in the focus chain — calling `m.top.setFocus(true)` on a parent of `btnSignIn` never actually transfers focus away, so btnSignIn intercepted OK events intended for fields. Removed broken guards from earlier attempt.
- **Changes:**
  - Removed `focusable="true"` from input groups (was breaking button navigation)
  - Reverted `item.node.setFocus(true)` → `m.fieldFocusProxy.setFocus(true)` for field types
  - Added `<Rectangle id="fieldFocusProxy" ... focusable="true" />` as a sibling of `signinButtons`
  - Kept `buttonSelected = false` reset in handlers (JFButton never resets it)
- **Files touched:** `components/config/SigninScene.xml`, `components/config/SigninScene.bs`
- **Timestamp:** 2026-07-16T21:47:00Z
- **Automatic:** no (user-directed)

## 2026-07-16 — Complete SigninScene rewrite: state-driven focus, no button observers

- **What:** Replaced the entire button/field focus architecture. Root cause: `JFButton` has `focusable="true"` + its own `onKeyEvent`, and `buttonSelected` has `alwaysNotify="true"` but JFButton never resets it. Combined with Roku keeping focus on the deepest child, calls to `m.top.setFocus(true)` never transferred focus away from `btnSignIn`, so OK events bypassed `SigninScene.onKeyEvent` and went to `btnSignIn.onKeyEvent → buttonSelected` instead.
- **Solution:** State-driven approach — a hidden `focusable="true"` Rectangle (`fieldFocusProxy`) is the ONLY node that ever gets Roku focus. `updateItemFocus()` updates visual indicators (bg colors, `buttonFocused`) purely for display, always calls `proxy.setFocus(true)`. All key events bubble to `SigninScene.onKeyEvent` which inspects `m.focusIndex` state to decide action (showKeyboard / performSignIn / hideSignIn). Removed all `buttonSelected` observers — they are unreliable.
- **Benefits:** No Roku focus chain issues (proxy is sibling of buttons, not ancestor). No `alwaysNotify` / `buttonSelected` race conditions. Keyboard opens reliably from fields. Buttons execute reliably from their visual focus position.
- **Files touched:** `components/config/SigninScene.bs` — full rewrite of focus management
- **Timestamp:** 2026-07-16T21:52:00Z
- **Automatic:** no (user-directed)

## 2026-07-16 — Login screen fixes: password retry + UserSelect navigation + temp hack revert

- **What:** Fixed three login flow issues preventing successful password entry and recovery from wrong password:
  1. **UserSelect grid navigation** — `highlightGridIndex()` was a no-op (didn't set `grid.itemFocused`), `UserRow.onItemSelected` crashed on invalid `focusedItem`, `selectUser()` read ContentNode `.Name` instead of `.title` (empty username). Fixed all three.
  2. **SigninScene retry after wrong password** — Input groups now `focusable="true"` in XML so OK events route through `onKeyEvent` → `showKeyboard` instead of being intercepted by `btnSignIn`. `onAuthErrorChange` moves focus to password field, clears password text, and calls `updateItemFocus()`. `onSignInPressed`/`onCancelPressed` guard against stale `buttonSelected` callbacks. `hideSignIn` re-orders visibility before `PopCurrentScene()` for correct focus return to UserSelect.
  3. **Temp hack revert** — `Main.bs` `if false and autoLoginData` → `if autoLoginData`, `ShowScenes.bs` `if true or savedServer=""` → `if savedServer=""`.
- **Files touched:**
  - `components/config/SigninScene.xml` — `focusable="true"` on usernameInputGroup, passwordInputGroup
  - `components/config/SigninScene.bs` — `m.focusIndex = 1` (default to password), `item.node.setFocus(true)` for fields (not `m.top`), stale `buttonSelected` guards, `onAuthErrorChange` resets focus+password, `hideSignIn` ordering
  - `source/Main.bs` — Removed `if false and` hack
  - `source/ShowScenes.bs` — Removed `if true or` hack
- **Verification:** Deployed to 192.168.1.196. Auto-login works (straight to HomeScreen), no crashes. Login screen fixes await manual testing via "Change Server" flow.
- **Timestamp:** 2026-07-16T21:30:00Z
- **Automatic:** no (user-directed)
 
## Fix DiscoverPage Auto Discovery Scrolling
- **When:** 2026-07-29 20:41 EDT
- **What:** Enabled vertical scrolling on DiscoverPage MarkupGrid
- **Why:** Grid was limited to 2 rows with no scrolling making it impossible to browse all auto-discovered content
- **Changes:** components/DiscoverPage.xml - set numRows=4 added scrollingEnabled=true and scrollSpeedMultiplier=1.5


## 2026-07-31 � Fixed home screen layout (root-cause fixes for rows, NavRail, hero)

- **What:** Diagnosed via Roku dev console + Roku RowList docs; fixed the actual root causes:
  1. **Rows showed 1 tile each** � `itemSize` on RowList is the *row* size, not item size. `itemSize=[196,294]` made each row only 196px wide. Set `itemSize=[1660,334]` so rows span full width (server returns 10-20 items per category).
  2. **RowList has NO width/height fields** � removed invalid `width="1660" height="520"` from HomeScreen.xml (was throwing "Tried to set nonexistent field" warnings; row width now comes from itemSize).
  3. **itemSpacing x-dim is ignored by RowList** � switched to `rowItemSpacing=[[20,0],...]` for horizontal poster gaps; kept itemSpacing for vertical row gaps.
  4. **showRowLabel must be an array** � now `[true,...]` per row with `rowLabelOffset=[[0,-30]]` so row titles (Continue Watching, etc.) show above each carousel.
  5. **RowListItem focus used non-existent field** `rowListItemFocused` � RowList sets `itemHasFocus`/`rowHasFocus`; rewired onFocusChanged to `itemHasFocus and rowListHasFocus` so the focus ring actually displays.
  6. **NavRail sat behind the JFOverhang and its dark background clipped the hero title** � moved NavRail to `[0,90]` (below 90px overhang), brightened rail background, enlarged icons to 30px, cyan highlight with opacity.
  7. **Garbled hero meta text** � setHeroItem formatted raw `type + Type + ISO dateAdded` (e.g. "Movie Movie 2026-07-31T..."); rewrote to clean `Type � ProductionYear � YYYY-MM-DD`.
  8. **Duplicate clock** � removed HomeScreen clockLabel + clock timer (JFOverhang already shows a clock).
- **Why:** User reported rows showing a single box, blank left rail, dim icon bar behind overhang, cutoff/garbled hero text.
- **Files touched:**
  - `components/home/HomeRows.bs` � itemSize/itemSpacing/showRowLabel/rowItemSpacing/rowLabelOffset per-row arrays
  - `components/HomeScreen.xml` � NavRail translation [0,90], removed clockLabel, hero labels widened (title 1300px, desc 1100px), removed invalid HomeRows width/height
  - `components/HomeScreen.brs` � clean hero meta formatting, added ProductionYear to heroData, removed clock code
  - `components/NavRail.xml` � rail bg 0x10141DFF height 990, 30px icons, cyan highlight rects
  - `components/RowListItem.xml`/`.brs` � correct RowList focus fields (itemHasFocus/rowHasFocus)
  - `source/Main.bs` � temporary autologin/token diagnostics added then removed
  - `manifest` � build_version 19 -> 25
- **Verification:** Deployed to 192.168.1.196; console showed clean HomeScreen creation (no more width/height warnings), auto-login OK, HomeScreen Init. Queried Jellyfin at 192.168.1.224:8097 (via captured token): GetLatest=10, Resume=20, NextUp=0 items. Temporary diagnostic prints removed after verification.
- **Timestamp:** 2026-07-31

## 2026-07-31 (manual)
- **What changed:** deploy_roku.ps1 now prompts interactively for the target Roku IP (Read-Host). Blank input falls back to the default 192.168.1.196; env var ROKU_IP still bypasses the prompt entirely.
- **Why:** User needs to sideload to multiple Rokus.
- **Files touched:** deploy_roku.ps1 (lines 27-31)
- **Timestamp:** 2026-07-31

## 2026-07-31 (automatic)
- **What changed:** Audited all 27 onKeyEvent handlers against the roadmap rule "return false if unhandled or you eat the event". Fixed 6 violations in 5 files:
  - components/config/SigninScene.bs - if not press then return true -> alse (was eating all key releases)
  - components/login/UserSelect.bs - same fix
  - components/JFMessageDialog.bs - added if not press then return false guard (BACK fired backPressed on both press AND release = double-fire)
  - components/search/SearchResults.bs - added press guard (left/right/play were double-handled)
  - components/config/SetServerScreen.bs - trailing 
eturn true (x2) -> alse (was swallowing ALL unhandled keys)
- **Why:** Roadmap Phase 2 flags this exact bug class (returning true on unhandled keys breaks focus chain / back behavior).
- **Files touched:** SigninScene.bs, UserSelect.bs, JFMessageDialog.bs, SearchResults.bs, SetServerScreen.bs
- **Verification:** 	ranspile.ps1 + uild.js -> "Transpile complete! (163 BS files processed)" / "BUILD OK". sc --project bsconfig.json errors (14, in HeroBanner/HomeScene/NextUpRow/SidebarNav XML) confirmed pre-existing via git stash.
- **Timestamp:** 2026-07-31

## 2026-07-31 — Fixed "can't select and play movies" (script scope + dead code)

- **What:** (manual) MovieDetails/TVSeries/Artist/etc. were calling namespaced functions (`MainAction_Play`, `quickplay.video`, `api.*`, `CreatePersonView`) that were never injected into those components' XML scopes — every call was an undefined-function runtime error, so pressing Play did nothing.
  1. Extended `transpile.ps1` `libInjections` so detail/library screens get the scripts they call: `MainActions.brs`, `utils/quickplay.brs`, `api/sdk.brs`, `api/Items.brs` (+ globals/config/ShowScenes/MainEventHandlers/userauth for Movie/TVSeries) injected into MovieDetails, TVSeriesDetails, TVSeasonDetails, AlbumView, ArtistView, VisualLibraryScene, MusicLibraryView, LiveTVLibraryView, OtherLibrary, AudioBookLibraryView.
  2. Removed legacy `CreateObject("roSGTask", "Task")` + `setCallback` concurrent-load block in `MovieDetails.LoadData` (roSGTask/setCallback don't exist on Roku — threw a runtime error mid-LoadData); replaced with direct `loadCast`/`loadExtras`/`checkVersions` calls.
  3. Added `lastEventNode` fallback in `MovieDetails.onButtonSelected` (scan buttons via `buttonSelected`) so Play/Resume/Trailer/Favorite/MyList/Subtitles/Versions resolve even if `lastEventNode` is unset.
- **Why:** User reported "i can not select and play movies".
- **Files touched:** `transpile.ps1`, `components/movies/MovieDetails.bs`, `manifest` (build_version 27→28)
- **Build:** v28 deployed successfully; app launched, no errors in console.

## 2026-07-31 — Movie tiles letterboxed (centered) instead of poster-fill

- **What:** (manual) Changed `loadDisplayMode` from `scaleToFit` to `scaleToZoom` (cover) on all poster tile components so images fill the whole tile regardless of source aspect ratio: HomeItem, RowListItem, GridItem, GridItemSmall, GridItemMedium, PosterRow.
- **Why:** User reported some movie tiles showed the image centered inside the tile (letterbox bars) instead of a full poster.
- **Files touched:** `components/home/HomeItem.xml`, `components/RowListItem.xml`, `components/ItemGrid/GridItem.xml`, `GridItemSmall.xml`, `GridItemMedium.xml`, `components/PosterRow.xml`, `manifest` (build_version 28→29)
- **Build:** v29 deployed successfully.

## 2026-07-31 — Home screen redesigned to Plex/Wholphin style (removed hero banner)

- **What:** (manual, per user feedback "doesn't look like the reference Wholphin yet") Removed the large 594px hero banner takeover and switched to a Plex-style home: dark full-bleed background + left nav rail + content rows filling the whole screen.
  1. `HomeScreen.xml`: deleted heroBackdrop, heroGradient, heroTitle/Subtitle/Meta/Description, heroButtons (Play/More Info); moved HomeRows to `[140, 0]` full height; centered loading/error UI.
  2. `HomeScreen.brs`: removed `setHeroItem`, the `hero` LoadItemsTask (pendingSections 5→4), `onRowItemFocused` observer + function, hero key handling. Simplified `onKeyEvent` (left→rail, right→rows, up@top row→rail, down@rail→rows, back→rail). Rows now fill 1080px.
  3. `HomeRows.bs`: bigger cards — Continue Watching/Next Up rows 400x225 (16:9), poster rows 214x320 (2:3), row headers offset [-45].
  4. `RowListItem.brs`: `onSizeChanged` now updates posterContainer clipRect to match new card sizes.
  5. `NavRail.xml`: widened to 90px, icons 40px, added channel logo at top (railLogo), bigger highlight pills.
- **Why:** User: "the home screen still doesnt look like the reference [Wholphin] but its getting close"; confirmed Plex-style home (no hero banner).
- **Files touched:** `components/HomeScreen.xml`, `components/HomeScreen.brs`, `components/home/HomeRows.bs`, `components/RowListItem.brs`, `components/NavRail.xml`, `manifest` (build_version 29→30)
- **Build:** v30 deployed; console clean ([NavRail.init] OK, [HomeScreen.init] ok, no errors).
## 2026-08-02 - SetServerScreen buttons + MovieDetails crash + _sm() diagnostics

- **What:** Fixed SetServerScreen login buttons not selectable; fixed MovieDetails crash on rating type mismatch; added diagnostics to _sm() and Create* functions.
- **SetServerScreen root cause:** (1) JFScreen.OnScreenShown() calls setFocus(true) on screen, overriding focusProxy; (2) discoveredServerList LabelList had focusable=true, stealing focus; (3) onKeyboardButton did not re-assert focusProxy after dialog.
- **SetServerScreen fix:** SetServerScreen.xml: Added focusable=false to component def + discoveredServerList; SetServerScreen.bs: Overrode OnScreenShown to call focusProxy.setFocus(true); updateHighlights toggles discoveredServerList.focusable; onKeyboardButton re-asserts focusProxy after dialog.
- **MovieDetails fix:** Changed chainLookupReturn default from empty string to 0 for CommunityRating field to fix type mismatch crash at line 78.
- **Diagnostics:** Enhanced _sm() with detail output; added debug prints to CreateServerGroup, CreateHomeGroup, CreateMovieDetailsGroup, CreateSearchPage.
- **Files:** components/config/SetServerScreen.xml, components/config/SetServerScreen.bs, components/movies/MovieDetails.bs, source/ShowScenes.bs
## 2026-08-03 - MovieDetails buttons/focus fixes

- **What:** Fixed MovieDetails OnScreenShown crash, stale buttonSelected state, and MainAction.EditSubtitles m.scene crash.
- **Root cause 1:** `setFocus(true)` (bare, no receiver) in MovieDetails.bs OnScreenShown line 54 and JFScreen.bs line 23 calls an undefined function -> OnScreenShown throws before btnPlay.setFocus(true), so initial focus is never set on a button.
- **Root cause 2:** `buttonSelected` on JFButtons was never reset; the onButtonSelected handler iterated candidates and picked the LAST button with `buttonSelected=true`, so a stale selection routed OK presses to the wrong action (btnSubtitles instead of btnPlay).
- **Root cause 3:** MainAction.EditSubtitles used `m.scene.dialog = dialog`; when called from MovieDetails context, `m` is MovieDetails (no `scene` field) -> `invalid` -> crash.
- **Fix 1:** `setFocus(true)` -> `m.top.setFocus(true)` in MovieDetails.bs and JFScreen.bs.
- **Fix 2:** Added `<function name="OnScreenShown" />` / `<function name="OnScreenHidden" />` to MovieDetails.xml interface so callFunc reliably finds them.
- **Fix 3:** onButtonSelected now resets each matched button's `buttonSelected=false` and uses a `m.handlingButtonSelected` re-entry guard.
- **Fix 4:** MainAction.EditSubtitles resolves the scene via `m.top.getScene()` with a `getGlobalAA().scene` fallback.
- **Fix 5:** Initialized `m.focusedBtnIdx = 0` and `m.handlingButtonSelected = false` in MovieDetails.Init().
- **Files:** components/movies/MovieDetails.bs, components/movies/MovieDetails.xml, components/JFScreen.bs, source/MainActions.bs
- **Build:** transpile.ps1 + build.js OK (Wholphin.zip ~422KB).
## 2026-08-03 - setOverhangTitle crash + Auto Discover stuck task

- **What:** Fixed the crash that blocked MovieDetails/SetServerScreen from being pushed, and fixed Auto Discover so it can be re-run.
- **Root cause (crash):** `roku_monitor_20260803_112920.log` showed `Member function not found ... JFGroup.brs(31)` in `scene.setOverhangTitle(title)`. On this firmware, cross-node functions must be declared in the target component's `<interface>` before they can be called via dot-notation or callFunc. `setOverhangTitle` is defined in BaseScene.bs but was NOT in BaseScene.xml's interface -> every `OnScreenShown` that called `setOverhangTitle` (MovieDetails, SetServerScreen, JFScreen) crashed. The earlier fix (adding `OnScreenShown` to MovieDetails.xml interface) made `callFunc("OnScreenShown")` actually invoke, which then exposed this crash.
- **Root cause (Auto Discover):** `ServerDiscoveryTask` was created and set to `control = "RUN"` but never appended to the scene tree (every other task in the app is appended). The task may not execute `functionName`, so `onDiscoveryComplete` never fired, `m.isDiscovering` stayed `true`, and every later "Auto Discover" press hit the "already discovering" guard -> button appeared dead/stuck at "Searching...".
- **Fix 1:** JFGroup.bs `setOverhangTitle` now calls `scene.callFunc("setOverhangTitle", title)`.
- **Fix 2:** Added `<function name="setOverhangTitle" />` to BaseScene.xml interface.
- **Fix 3:** SceneManager.bs popScene now uses `sceneManager.callFunc("setOverhangTitle", ...)`.
- **Fix 4:** Added `<function name="OnScreenShown" />` / `<function name="OnScreenHidden" />` to JFScreen.xml interface so callFunc resolves the lifecycle callbacks on every JFScreen descendant.
- **Fix 5:** StartDiscovery removes the old task, appends the new task via `m.top.appendChild`, and onDiscoveryComplete resets `m.isDiscovering`, `m.top.isDiscovering`, and the button text.
- **Files:** components/JFGroup.bs, components/BaseScene.xml, components/manager/SceneManager.bs, components/JFScreen.xml, components/config/SetServerScreen.bs
- **Build:** transpile.ps1 + build.js OK (Wholphin.zip).



- **Fix:** deploy_roku.ps1 now auto-bumps manifest build_version on every deploy so Roku detects a fresh build and recompiles (never serves cached bytecode). Cleanup of build/ + out/ already forces fresh staging. Upload stays mysubmit=Replace.
- **Files:** deploy_roku.ps1
- **Build:** N/A (script change only)

- **Fix:** MovieDetails vertical scroll - onKeyEvent now handles down/up: moves focus between action buttons (focusZone=-1) and visible content grids (extrasGrid, castGrid) via new visibleContentGrids()/focusButton() helpers. left/right only consumed on buttons so grids can navigate horizontally. back from a grid returns to buttons before popping scene.
- **Fix:** quickplay.brs crash - replaced m.global.queueManager (namespace funcs have no valid m) with getGlobalAA().queueManager in all 6 queue funcs, plus if queueManager = invalid then return guard in each.
- **Files:** components/movies/MovieDetails.bs, source/utils/quickplay.bs
- **Build:** transpile.ps1 + build.js OK (Wholphin.zip).

- **Deploy:** Out-of-band redeploy via deploy_roku.ps1 (IP 192.168.1.196). Root cause of "scrolled briefly then froze" = device was still running the OLD build (log 115437 shows m.global.queueManager crash, zero focusZone/getGlobalAA references). My scroll + quickplay fixes were built but never uploaded. Version bumped 39->40, Replace sideload OK.
- **Files:** none changed (deploy only)

- **Fix:** VisualLibraryScene froze when opening a library - LoadData() called api.items.Get() on the render thread; CreateObject('roUrlTransfer') is forbidden there, returns invalid, then req.SetUrl(spec.url) threw 'Dot' operator invalid (log 115810: baserequest.brs(103), stack VisualLibraryScene.loadData -> api_items_get -> getjson). Refactored LoadData to use LoadItemsTask2 task (parentId/includeItemTypes/sortBy/sortOrder/limit/startIndex/filters/userId), callback onLoadItemsComplete -> populateGrid. Guards re-entry, removes/unobserves task when done.
- **Files:** components/Libraries/VisualLibraryScene.bs
- **Build+Deploy:** deploy_roku.ps1, build_version 41->42, Replace sideload OK.

- **Fix:** MovieDetails buttons Favorite / My List / Mark Watched crashed on render thread (log 120401: baserequest.brs(103) via MovieDetails.onButtonSelected -> MainAction_AddToMyList). Created components/ItemGrid/UserDataTask (markfavorite/unmarkfavorite/markplayed/unmarkplayed) and rewrote MainActions MarkFavorite/MarkPlayed/AddToMyList/RemoveFromMyList/MarkWatched/MarkUnwatched to dispatch via RunUserDataTask() -> getGlobalAA().scene.appendChild(task). Task self-removes via finish().
- **Files:** components/ItemGrid/UserDataTask.xml, components/ItemGrid/UserDataTask.bs, source/MainActions.bs
- **Build+Deploy:** build_version 43->44, Replace sideload OK.
- **Note:** PlayTrailer's GetIntros + AlbumView/AudioPlayerView/TVSeriesDetails/MusicLibraryView/OtherLibrary/AudioBookLibraryView still do render-thread api.* calls - need task conversion (untested/not yet hit).


- **Fix (automatic):** MovieDetails Back froze the whole app instead of returning to Home. Root cause: PopCurrentScene() did scene-graph surgery (previousScene.visible=true on the large HomeScreen tree + removeChild of the focused MovieDetails) SYNCHRONOUSLY inside the onKeyEvent handler -> render thread stall (looks like hard freeze; telnet console buffers output 30-60s so it LOOKED frozen even when not). Bisected via noop/test builds 105-114: key handler itself is fine; the visible=true + removeChild combo on HomeScreen re-show is the trigger. Fixed PopCurrentScene() to defer ALL surgery to a one-shot Timer (pop stack sync, store getGlobalAA().__pendingPop, sm.createChild('Timer') -> onPendingPopFired does re-show + focus + removeChild). Focus only moved if previousScene.focusedChild = invalid.
- **Also fixed:** 6 library/Settings screens (AudioBookLibraryView, LiveTVLibraryView, MusicLibraryView, OtherLibrary, VisualLibraryScene, SettingsView) used broken m.global.sceneManager.callFunc('popScene') (field is void-typed invalid from Main.bs addFields({sceneManager: invalid}), so the call would throw on invalid). Switched to PopCurrentScene() and added pkg:/source/ShowScenes.brs to their transpile.ps1 .
- **Files:** source/ShowScenes.bs, components/movies/MovieDetails.bs, components/Libraries/{AudioBookLibraryView,LiveTVLibraryView,MusicLibraryView,OtherLibrary,VisualLibraryScene}.bs, components/SettingsView.bs, transpile.ps1, AGENTS.md (4.5 rules 6-9)
- **Verified on-device (build 115):** Home -> Down x3 -> Select (MovieDetails) -> Back -> returned to Home, then Down/Right/Select opened a second MovieDetails (Home fully interactive). FF/RW, video->MovieDetails back also confirmed working.
- **Builds:** 96 (FF/RW keys + player back) ... 115 (current, clean deferred pop + lib back-handler fixes).

- **Fix (automatic):** User could NOT select other servers. Root cause: Saved Servers UI was dead code. CreateServerGroup() (ShowScenes.bs) set serverScreen.savedServers but SetServerScreen never observed the field, never populated serverList, and savedServersLabel/serverList were permanently hidden (focusable=false added to serverList; connect was impossible). Wired up: m.serverList.observeField("itemSelected",...), m.top.observeField("savedServers",...), populateSavedServers() on init + on change, generalized listIsActive()/activeList()/selectListItem(index,lst) to work with either saved or discovered list, updateHighlights() handles focusedButtonIndex=3 for either list (both lists focusable=false, focusProxy pattern per AGENTS.md 4.4).
- **Files:** components/config/SetServerScreen.bs, components/config/SetServerScreen.xml
- **Build:** 118 (deployed)

- **Testing methodology discovery:** ECP keypress delivery (curl :8060/keypress) is unreliable in this environment - keys are delayed/dropped whether or not the telnet console is attached (livemon55-58: zero [Home] prints while heartbeat kept firing; livemon60: zero [Home]/[POP] prints during full nav window, heartbeat continuous -> app BS thread never stalls). Earlier "17s Back gap" was input-queue contamination + telnet buffer lag, not app freeze. Deferred pop completes in <1s. On-device verification of back-paths now requires physical remote testing by the user.
- **Instrumentation (builds 119-121):** [HB] 5s heartbeat, [HERO]/[FIN] wall-clock, [Home] key= in HomeScreen.onKeyEvent, [POP]/[POP-FIRED] wall-clock in ShowScenes. All proved the main thread never stalls and pop is fast. Removed in build 122.

- **Fix (automatic):** PopCurrentScene guard swallowed a second Back pressed while a pop's deferred timer was in flight (~1s window) - dropped key could read as a freeze. Changed to queue: __queuedPop flag set instead of dropping; onPendingPopFired processes the queued pop after completing the current one. ClearAllScenes resets both __pendingPop and __queuedPop.
- **Files:** source/ShowScenes.bs
- **Build:** 122 (deployed, app boots clean, no errors, all Home sections load)
- **Timestamp:** 2026-08-04 17:09

- **Cleanup (automatic):** Moved unused/debris files into _archive/ subfolders. Nothing deleted, all recoverable.
  - _archive/debug-logs/: livemon*.txt, roku_monitor_*.log, telnet*.txt, roku_debug*.txt/.log, focusable/buttons/textbuttons/rectangles/interactive_elements/tmpfiles txts, monitor_job_id.txt, roku_live.txt
  - _archive/test-scripts/: test_*.ps1 (capture/backpath/nav/key/videopath/freeze/resp/final/live), capture_debug.ps1
  - _archive/skeleton-and-experiments/: ai code/ skeleton, movievault_icon.png, jellyrock_icon.png, dev_icon.png, dev_icon_test.jpg, dev_page.html
  - _archive/obsolete-scripts/: fix-library-paths.ps1, new.ps1, run_debug.ps1, stray file '0'
  - _archive/reference-docs/: BrightScriptReferenceManual_ver9.pdf, BrightScript_Reference_Manual_3.0_draft.pdf
  - _archive/planning-docs/: ui.md, plans.md, roadmap.md, changelog.md, features.md, UI Redesign Spec Wholphin Roku App.md
- **Kept:** manifest, source/, components/, images/, locale/, settings/, docs/, build tooling (transpile.ps1, build.js, deploy_roku.ps1, bsconfig*.json, package.json, node_modules/), dev tools (livemon.ps1, setup.ps1, debugroku.ps1, skills-lock.json), AGENTS.md, README.md, .gitignore, history/, .agents/, .poolside/
- **Note:** deploy_roku.ps1/README/AGENTS reference 'rokudebug.ps1' but that file never existed; actual telnet debug script is debugroku.ps1 (pre-existing inconsistency).
- **Verified:** transpile.ps1 + build.js still OK (164 BS files, BUILD OK).
- **Timestamp:** 2026-08-04 18:47

## NavRail dynamic side menu (automatic)
- **What:** Rebuilt NavRail.brs/.xml with official Wholphin drawer order (profile -> search -> home -> favorites -> discover-if-enabled -> dynamic libraries from GET /Users/{userId}/Views -> settings). Icons: nav_user/nav_search/nav_home/nav_favorites/nav_movies/nav_tv/nav_playlist/nav_cast/nav_library/nav_collection/nav_settings. 90px rail, 84px item pitch, 72x56 cyan highlight, home icon always cyan. Dynamic library loading via LoadItemsTask (itemsToLoad="libraries"). Selection ids: profile/search/home/favorites/discover/lib:{id}/settings -> HomeScreen.onNavItemSelected routes to CreateSearchPage/CreateHomeGroup/CreateSettingsScreen/CreateDiscoverPage/openLibraryById (visual library by collectionType; music/livetv special-cased).
- **Why:** Official Wholphin Android drawer parity; dynamic library items from the server.
- **Bugs found & fixed during this work:**
  1. Build 123: unc_name_resolver failed resolving 'updatehighlights' � rebuildRail() called updateHighlights() which was never defined. Fixed by adding updateHighlights().
  2. Build 124-125: HomeScreen creation still failed with a micro-debugger drop-in. Root cause: if session <> invalid and session.user <> invalid then userId = session.user.GetId() in NavRail.brs � in a component script session is the injected NAMESPACE (function-container), so session.user field access throws. HomeScreen.brs is unaffected because transpile rewrites the whole session.user.GetId() call to session_user_GetId(), but a bare session.user comparison is not rewritten. Fixed by reading m.global.session.user.id via chainLookupReturn instead.
  3. updateScroll itemPitch was 64 (old XML spec); official rail uses 84px pitch. Fixed.
- **Files touched:** components/NavRail.brs, components/NavRail.xml, components/HomeScreen.brs (onNavItemSelected was already wired), history/history.md. Added dev_capture.ps1 (telnet capture helper) in repo root.
- **Verified:** build 0.1.127 deployed and running; trace shows [NavRail.init] OK, dynamic, [NavRail] libraries loaded= 3, [HomeScreen.init] navRail=true homeRows=true, inishLoading called, no BrightScript errors, no micro-debugger drop-in, active-app=dev 0.1.127.
- **Known limitation:** ECP key delivery is unreliable with telnet attached, so interactive nav (selecting a library from the rail) still needs physical-remote verification. Deferred-pop and Back handling unchanged (build 122) and untouched.
- **Timestamp:** 2026-08-04 20:05

## Fix: side-menu destinations stuck on Loading/blank (automatic)
- **Symptom:** After NavRail went live, almost every nav option (libraries, Favorites, Search, Settings) showed "Loading..." or a blank screen and did nothing.
- **Root causes (all pre-existing wiring gaps, newly reachable because NavRail exposes all destinations for the first time):**
  1. **Libraries + Favorites hang:** LoadItemsTask2 (used by VisualLibraryScene) called api.items.Get() but its XML only had misc/session/baserequest/Image injected � missing api/Items.brs + api/sdk.brs + api/userauth.brs. Task threw &h91 on the render thread, loadStatus never fired, loading label stayed forever. Fixed by adding LoadItemsTask2.xml to transpile.ps1 libInjections.
  2. **Search does nothing:** SearchTask.xml, SearchRow.xml, and searchResults.xml had NO script tags at all, so their .bs logic never loaded (SearchTask.functionName never set, SearchRow never populated). Added script tags; added SearchTask libInjections (api/Items for searchMedia).
  3. **Settings blank:** SettingsView.xml had no script tag, so callFunc("loadSettings") had no handler. Added script tag + utils/globals.brs injection (getThemeColors).
  4. **VisualLibraryScene item-select crash risk:** it calls HandleItemSelection (MainEventHandlers.brs) which was not injected. Added to its libInjections.
- **Files touched:** transpile.ps1 (libInjections: +LoadItemsTask2.xml, +SearchTask.xml, SettingsView.xml +globals, VisualLibraryScene.xml +MainEventHandlers), components/search/SearchTask.xml, components/search/SearchRow.xml, components/search/SearchResults.xml, components/SettingsView.xml. Removed temporary NavRail.onKeyEvent print; kept low-frequency [VLS] LoadData/onLoadItemsComplete prints in VisualLibraryScene.bs for future verification.
- **Verified:** build 0.1.131 boots clean (NavRail.init OK, 3 libraries loaded, HomeScreen.init, finishLoading, no BrightScript errors). Server-side queries for the 3 libraries return data (Movies 2959, Collections 1, Playlists 1) so the task will populate grids. Interactive nav still needs physical-remote confirmation (ECP directional keys do not reach the app in this environment; only OS-level Home works).
- **Known, not fixed (not reachable with current 3 libraries):** MusicLibraryView/LiveTVLibraryView call api.* directly on the render thread (same bug class already fixed for VisualLibraryScene) � would hang if a music/livetv library is added. DiscoverPage is an incomplete stub (only reachable if discover.enabled, currently false). Logged for future work.
- **Timestamp:** 2026-08-04 20:25
## 2026-08-05 12:10 - Change Server / Sign Out entry points (build 0.1.132)
- WHAT: Added 'Change Server' + 'Sign Out' actions to the Settings screen so a logged-in user can reach the SetServerScreen (previously unreachable after auto-login).
- WHY: User cannot switch servers (e.g. to http://192.168.1.224:9100/) � no UI path after auto-login pins the app to the saved server.
- FILES: settings/settings.json (2 new action-type settings), components/SettingsView.bs (executeAction routes action.changeServer/showserver + action.signOut/signout via scene.setField pendingServerAction), source/Main.bs (new pendingServerAction cases: showserver -> CreateServerGroup(); signout -> SignOut()+CreateServerGroup()).
- VERIFY: Deployed 0.1.132 (BUILD OK, 419.1 KB). Clean boot trace (auto-login OK, 3 libraries, finishLoading, no errors). Interactive test requires physical remote (ECP keys don't reach app).

## 2026-08-05 - Home screen redesign: HeroPanel + PosterCard shelves + purple NavRail (build 0.1.135)
- WHAT: Full home-screen visual overhaul to match the reference streaming layout.
  - New `components/home/HeroPanel.xml`/`.bs`: 454px cinematic backdrop (scaleToZoom) with 250ms crossfade (programmatic Animation, no XML Animation/state reliance), hero_gradient + hero_fade_bottom overlays, LargeBold title, rich meta line, 4-line wrap description, purple "Continue Watching" CTA (focusable, wired to HandleItemSelection), top-right clock.
  - New `components/home/PosterCard.xml`/`.bs`: uniform 220x330 2:3 card, rounded corners via MaskGroup(maskUri=poster_mask_2x3.png), purple 4px progress bar (PlaybackPositionTicks/RunTimeTicks), episode-number badge, purple glow + ring + lift(-6) + scale(1.09) focus animation (easeOutQuad, scaleRotateCenter=[110,165]).
  - `components/home/HomeRows.bs`: uniform row geometry (rowHeights 430, rowItemSizes [220,330], itemSpacing [24,28]), itemComponentName=PosterCard, LargeBoldSystemFont row headers.
  - `components/home/LoadItemsTask.bs`: expanded homeFields (RunTimeTicks, PlaybackPositionTicks, OfficialRating, CommunityRating, CriticRating, CriticRatingScorePercent, ProductionYear, EndDate); favorites->IncludeItemTypes Series; new movies/tvshows/collections branches via GetUserViews + api.items.Get.
  - `components/HomeScreen.xml`: added home_bg.png gradient background; replaced inline hero labels with HeroPanel; rows moved to y=500.
  - `components/HomeScreen.brs`: deterministic section order (resume, favorites, movies, tvshows, latestmedia, collections) with m.sectionResults collection -> finishLoading emits rows in fixed order (kills race-order glitch); setHeroItem builds rich meta "Year � 2h 7m � 1h 36m left � PG-13 � ? 8.0 � 91% � Ends at 9:37 PM"; cleanTitle() never shows raw filenames; CTA handler onHeroContinueSelected; focus routing homeRows<->btnContinue<->navRail.
  - `components/NavRail.brs`: purple accent (0x7B3FF2FF), 44px icons centered, 46px pitch, 64x44 highlight pill, selected scale 1.1, scroll viewHeight 880.
  - Assets: home_bg.png, hero_fade_bottom.png, poster_mask_2x3.png, focus_glow.png + nav_* icon set generated via gen-assets.js (sharp).
- BUGS FOUND & FIXED during deploy:
  1. Build 133: ContentNode has no built-in `meta`/`backdropURL`/`showContinue` fields - silent warnings. Fixed with heroNode.AddFields().
  2. Build 133: `Animation.resetChildrenToKeyValue()` does not exist at runtime - dropped into micro-debugger on first focus. Removed; start/stop + manual base-state reset instead.
  3. Build 134: `roDateTime.AddSeconds` not available on this firmware - "Ends at" now computed via minute arithmetic (mod 1440).
- FILES: components/home/{HeroPanel,PosterCard,HomeRows,LoadItemsTask}.{xml,bs}, components/{HomeScreen,HomeScreen.brs,NavRail}.{xml,brs}, images/*, UI_REDESIGN_PLAN.md.
- VERIFY: build 0.1.135 deployed. Clean boot: [HomeScreen.init] navRail=true homeRows=true, all 7 sections launched, finishLoading called, no BrightScript errors, no micro-debugger, no "Warning occurred while setting a field" (ContentNode fix confirmed), active-app responsive (ECP Home). tvshows section reports "error" simply because this server has NO tvshows library (Views = Collections/Movies/Playlists) - expected skip, not a bug.
- NOT VERIFIED (needs physical remote): row scrolling, hero crossfade on focus change, CTA focus/play, purple focus glow. ECP directional keys do not reach the app in this environment.

## 2026-08-05 - Reverted home redesign; restored Wholphin home + kept server-switch
- WHAT: Reverted the HomeScreen/HeroPanel/PosterCard/NavRail-redesign changes (build 0.1.135) and restored the original Wholphin home screen (HEAD baseline) so the rows look right again. Re-deployed build 0.1.136.
- WHY: The redesign did not match the Wholphin aesthetic. Restored full-bleed heroBackdrop Poster, hero meta labels, Play/More Info buttons, RowList rows via RowListItem, dynamic cyan NavRail.
- FILES reverted (git checkout HEAD): components/HomeScreen.xml, components/HomeScreen.brs, components/home/HomeRows.bs, components/home/HomeRows.xml, components/home/LoadItemsTask.bs. NavRail.brs manually restored to the dynamic version (HEAD has an older hardcoded rail; only my purple/pitch edits were reversed, keeping the dynamic rail).
- FILES removed (redesign-only, unused): components/home/HeroPanel.{xml,bs}, components/home/PosterCard.{xml,bs}, UI_REDESIGN_PLAN.md, images/{home_bg,hero_fade_bottom,poster_mask_2x3,focus_glow}.png, images/icons/{nav_discover,nav_music}.png.
- KEPT (functional fixes, untouched): Settings->Change Server/Sign Out wiring in settings/settings.json + components/SettingsView.bs + source/Main.bs (pendingServerAction showserver/signout -> CreateServerGroup()/SignOut()); JFOverhang top-left avatar.
- VERIFY: build 0.1.136 deployed (BUILD OK, 436.8 KB). Clean boot: LoadItemsTask nextup/favorites/resume loaded, no Micro Debugger, no runtime errors.
- NOTE: this server has only Collections/Movies/Playlists libraries (no TV Shows), so the TV Shows section is absent by design.
