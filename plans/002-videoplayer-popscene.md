# Plan 002 — Fix VideoPlayerView.bs back-key using callFunc("popScene")

**Commit:** `c7ef21b`  
**Category:** Correctness / Critical bug (auto-enforce per AGENTS.md §4.1)  
**Impact:** HIGH — back key exits video player but may hang if callFunc hits a void sub  
**Effort:** S  
**Risk of fix:** LOW  

---

## Why this matters

`VideoPlayerView.bs:332`:
```brightscript
m.global.sceneManager.callFunc("popScene")
```

`SceneManager.bs:69`:
```brightscript
function popScene() as Void
```

This is exactly the **Dropdown OK Re-Open Bug / callFunc Void hang** pattern described in `AGENTS.md §4.1` and documented as the root cause of the sign-in hang in `history.md` (2026-06-13). `callFunc` on a function that transpiles to `sub` (returns `Void`) hangs indefinitely on this Roku firmware.

The fix already exists in the codebase: `PopCurrentScene()` in `source/ShowScenes.bs:21` is a `Boolean`-returning wrapper that bypasses the callFunc hang. It should be used here instead.

**Evidence:**
```brightscript
' components/video/VideoPlayerView.bs:332
m.global.sceneManager.callFunc("popScene")  ' HANGS on this firmware
```

```brightscript
' source/ShowScenes.bs:21-47 — the safe replacement
function PopCurrentScene() as Boolean
    sm = _sm()
    ...
    return true
end function
```

---

## Implementation

### File: `components/video/VideoPlayerView.bs`

**Location:** Line 332, inside `onBackPressed()`

**Current code:**
```brightscript
function onBackPressed() as Boolean
    if m.nextUpBox.visible then
        hideNextUp()
        return true
    end if

    if m.skipSegmentButton.visible then
        m.skipSegmentButton.visible = false
        return true
    end if

    if m.video.state = "playing" then
        m.video.control = "pause"
    end if

    reportPlaybackStopped()
    m.global.sceneManager.callFunc("popScene")   ' ← BUG: will hang
    return true
end function
```

**Replace with:**
```brightscript
function onBackPressed() as Boolean
    if m.nextUpBox.visible then
        hideNextUp()
        return true
    end if

    if m.skipSegmentButton.visible then
        m.skipSegmentButton.visible = false
        return true
    end if

    if m.video.state = "playing" then
        m.video.control = "pause"
    end if

    reportPlaybackStopped()
    PopCurrentScene()   ' ← safe Boolean-returning wrapper
    return true
end function
```

`PopCurrentScene()` is already available to `VideoPlayerView` because it is defined in `source/ShowScenes.bs`, which is loaded as a `Library` in `Main.bs`. No import changes needed.

---

## Verification

1. Deploy to `192.168.1.100`
2. Navigate to a movie → press Play
3. Press BACK while video is playing
4. **Expected:** video stops and home screen returns focus within ~1 second
5. **Failure indicator:** app freezes/hangs indefinitely on BACK press

---

## Grep audit — find other callFunc("popScene") or callFunc("clearScenes")

Before closing this plan, run:
```powershell
Select-String -Path "components/**/*.bs" -Pattern 'callFunc\("popScene"' -Recurse
Select-String -Path "components/**/*.bs" -Pattern 'callFunc\("clearScenes"' -Recurse
```

Any hits must be replaced with `PopCurrentScene()` or `ClearAllScenes()` respectively.

---

## Maintenance note

Per `AGENTS.md §4.1`: never call `sceneManager.callFunc("popScene")` or `sceneManager.callFunc("clearScenes")`. Always use `PopCurrentScene()` and `ClearAllScenes()` from `source/ShowScenes.bs`. If a new component is added, apply this rule automatically.
