# Plan 001 — Initialize m.port in all SceneGraph components

**Commit:** `c7ef21b`  
**Category:** Correctness / Bugs  
**Impact:** CRITICAL — every `observeField(..., m.port)` silently drops events if `m.port` is `invalid`  
**Effort:** M  
**Risk of fix:** LOW — purely additive, no logic change  

---

## Why this matters

Roku's SceneGraph threading model requires each component to create its own `roMessagePort` for receiving field-change events. When `observeField(field, port)` is called with an `invalid` port, Roku silently discards the subscription — no error, no crash, just dead events.

Every component in this repo calls `observeField(..., m.port)` in its `Init()`, but **not a single component ever sets `m.port = CreateObject("roMessagePort")`**. This means:

- `VideoPlayerView` receives no video state changes, no position updates, no buffering events
- `Home` receives no row focus changes, no hero item focus events
- `MovieDetails` button presses are silently dropped
- `VisualLibraryScene` item selections never fire
- `AudioPlayerView` gets no state/position updates
- All library views, music views, and grids are non-interactive

This is the single highest-leverage fix in the codebase.

**Evidence:**
```brightscript
' components/video/VideoPlayerView.bs:3-31
sub Init()
    m.video = m.top.findNode("videoPlayer")
    ' ...
    m.top.observeField("videoItem", m.port)    ' m.port = invalid — event lost
    m.video.observeField("state", m.port)      ' m.port = invalid — event lost
    ' ...
end sub
```

`grep -r "m.port = CreateObject" components/` returns **zero results**.

---

## Affected files (complete list from audit)

All `.bs` files under `components/` that call `observeField(..., m.port)` without creating `m.port`:

| File | observeField calls using m.port |
|------|-------------------------------|
| `components/video/VideoPlayerView.bs` | 8 |
| `components/home/Home.bs` | 2 |
| `components/movies/MovieDetails.bs` | 9 |
| `components/Libraries/VisualLibraryScene.bs` | 8 |
| `components/Libraries/AudioBookLibraryView.bs` | 2 |
| `components/Libraries/LiveTVLibraryView.bs` | 5 |
| `components/Libraries/MusicLibraryView.bs` | 6 |
| `components/Libraries/OtherLibrary.bs` | 2 |
| `components/music/AudioPlayerView.bs` | 6 |
| `components/mediaPlayers/AudioPlayer.bs` | 5 |
| `components/config/JFServer.bs` | 5 |
| `components/ItemGrid/Alpha.bs` | 2 |
| `components/ItemGrid/LibraryFilterDialog.bs` | 3 |
| `components/ItemGrid/GridItem.bs` | 1 |
| `components/ItemGrid/GridItemMedium.bs` | 1 |
| `components/ItemGrid/GridItemSmall.bs` | 1 |
| `components/Libraries/EmbyFilterMenu.bs` | 3 |
| `components/Spinner.bs` | 1 |
| `components/WholphinSidebar.bs` | 3 |
| `components/login/UserSelect.bs` | 1 (line 99, inside a function) |
| `components/home/HeroBanner.bs` | needs verification |
| `components/home/HomeRows.bs` | needs verification |

---

## Implementation Steps

### Step 1 — Add `m.port` creation to the top of each `Init()` (or `sub Init()`)

The fix is identical for every file. At the **very first line** of `Init()`, before any `findNode` or `observeField` call, add:

```brightscript
m.port = CreateObject("roMessagePort")
```

Then add a `while` event loop that processes messages, **or** use the callback string form of `observeField` for render-thread components that don't have a message loop.

> **Important design decision:** SceneGraph components have two patterns for handling `observeField`:
>
> 1. **Callback string form** — `observeField("field", "callbackFunctionName")` — fires the callback on the render thread. No message port needed. Already used correctly in some places (e.g., `UserSelect.bs` uses this for most of its fields).
> 2. **Port form** — `observeField("field", m.port)` — requires the component to have its own event loop thread (`functionName`) and `wait()` on that port.
>
> **For render-thread components** (the majority here, which are `Group`/`Scene` extends): use the **callback string form** instead of the port form. This is the correct pattern.
>
> **For Task components** (those with `<component extends="Task">`): a message port + while loop is appropriate.

### Step 2 — Convert `observeField(..., m.port)` to `observeField(..., "callbackName")` for render-thread components

For each component that extends `Group`, `Scene`, or any non-Task node type, replace:

```brightscript
' BEFORE (broken — m.port is invalid on render thread)
m.video.observeField("state", m.port)
m.video.observeField("position", m.port)
```

With named callbacks:

```brightscript
' AFTER (correct for render-thread components)
m.video.observeField("state", "onVideoStateChange")
m.video.observeField("position", "onVideoPositionChange")
```

Then ensure the corresponding handler functions exist (most already do — check file for matching `function onVideoStateChange()`).

### Step 3 — For Task components, use the port + while loop pattern

Task components (`extends="Task"`) with a `functionName` sub should:

```brightscript
sub myTaskFunction()
    m.port = CreateObject("roMessagePort")
    m.top.observeField("someField", m.port)
    
    while true
        msg = wait(0, m.port)
        if type(msg) = "roSGNodeEvent" then
            field = msg.getField()
            if field = "someField" then
                ' handle
            end if
        end if
    end while
end sub
```

---

## File-by-file changes (render-thread components)

### `components/video/VideoPlayerView.bs`

**Current Init() lines 20-36:**
```brightscript
m.top.observeField("videoItem", m.port)
m.video.observeField("state", m.port)
m.video.observeField("position", m.port)
m.video.observeField("duration", m.port)
m.video.observeField("bufferingStatus", m.port)
m.video.observeField("streamUrl", m.port)
m.video.observeField("loadStatus", m.port)
' ...
m.playbackTimer.observeField("fire", m.port)
m.bufferCheckTimer.observeField("fire", m.port)
```

**Replace with:**
```brightscript
m.top.observeField("videoItem", "startPlayback")
m.video.observeField("state", "onVideoStateChange")
m.video.observeField("position", "onVideoPositionChange")
m.video.observeField("duration", "onVideoPositionChange")
m.video.observeField("bufferingStatus", "onBufferingStatusChange")
m.video.observeField("loadStatus", "onLoadVideoContent")
' streamUrl observer can be removed if not used
m.playbackTimer.observeField("fire", "onPlaybackTimer")
m.bufferCheckTimer.observeField("fire", "onBufferCheckTimer")
```

Add missing handler stubs if any don't exist. Verify each callback function name exists in the file.

### `components/home/Home.bs`

**Current Init() lines 26-27:**
```brightscript
m.homeRows.observeField("rowFocusChanged", m.port)
m.heroBanner.observeField("heroItemFocused", m.port)
```

**Replace with:**
```brightscript
m.homeRows.observeField("rowFocusChanged", "onRowFocusChanged")
m.heroBanner.observeField("heroItemFocused", "onHeroItemFocused")
```

Add handlers:
```brightscript
sub onRowFocusChanged()
    ' forward to updateBackdrop if needed
end sub

sub onHeroItemFocused()
    item = m.heroBanner.heroItemFocused
    updateBackdrop(item)
end sub
```

### All other render-thread components

Apply the same pattern: replace `observeField("field", m.port)` with `observeField("field", "handlerFunctionName")`, ensuring the handler function exists.

---

## Verification

After applying changes, deploy to Living Room Roku (`192.168.1.100`):

1. Navigate to the home screen — rows should be scrollable with focus
2. Select a movie — `MovieDetails` buttons should be pressable
3. Start video playback — OSD position should update, pause/resume should work
4. Navigate a library — item selection should navigate to detail screens

**Automated check (pre-deploy):**
```powershell
npx bsc --project bsconfig.json 2>&1 | Select-String "error"
```
Expected: zero new errors introduced.

---

## Maintenance note

Any new component added to this project that calls `observeField` must use the callback string form (not `m.port`) unless it is a `Task` component with its own event loop. Add a comment to `AGENTS.md` section 3 to enforce this pattern.

---

## Escape hatches

- If a component uses `m.port` with `wait()` in a task function AND extends `Task`, keep the port form — this is correct.
- If the callback function for a `observeField` doesn't exist, add a stub (`sub handlerName()` / `end sub`) before the deploy.
- Do NOT remove any existing callback-form `observeField` calls (e.g., `UserSelect.bs` lines 15-20) — those are already correct.
