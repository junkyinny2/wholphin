# Wholphin Roku - Fix Log & Agent Handoff

> Created: 2026-06-19  
> Purpose: Comprehensive analysis + actionable fix plan for Wholphin Roku app  
> Goal: Make Home screen display rows with content, fix sidebar, match Wholphin Android TV UX

---

## 1. Project Overview

### Stack
- **Runtime:** Roku SceneGraph (BrightScript/BrighterScript)
- **Entry:** `Main.bs` → creates `BaseScene` (Scene)
- **Scene Manager:** Custom `SceneManager.bs` — push/pop scenes via `content` Group
- **Data:** Fetches from Jellyfin API via async `Task` nodes (`LoadItemsTask.bs`)
- **Auth:** Token-based (`accessToken` saved in registry), passwordless public user optional
- **Build:** transpile.ps1 (`.bs`→`.brs`) → build.js (archiver zip) → curl deploy

### Key Architecture Points
- `BaseScene.xml` has pre-included children: `SetServerScreen`, `UserSelect`, `SigninScene`, `WholphinSidebar`, `JFOverhang`, `Spinner`
- `Home` extends `JFScreen` → `JFGroup` → `Group` (focusable)
- `HomeRows` extends `RowList` — renders `HomeRow` (Group with `MarkupGrid`) for each content row
- `HomeItem` is the grid item component (Poster + Label)

---

## 2. UI Component Hierarchy

```
BaseScene (Scene)
├── Poster imageBackground (logo backdrop)
├── Group content
│   ├── SetServerScreen (visible on first launch)
│   ├── UserSelect (user picker)
│   ├── SigninScene (password entry)
│   ├── Home (pushed after auth)
│   │   ├── Rectangle bgFill (dark blue bg)
│   │   ├── Poster backdrop (hero/focus backdrop)
│   │   ├── Poster backdropTransition (crossfade)
│   │   ├── HeroBanner
│   │   │   ├── Poster heroBg
│   │   │   ├── Rectangle heroOverlay
│   │   │   ├── Label heroTitle
│   │   │   └── Label heroOverview
│   │   ├── HomeRows (RowList)
│   │   │   └── HomeRow (Group) [per row, created by RowList]
│   │   │       ├── Label rowLabel
│   │   │       └── MarkupGrid rowGrid
│   │   │           └── HomeItem (Group) [per item, created by grid]
│   │   │               ├── Poster itemPoster
│   │   │               ├── Poster playedCheckmark
│   │   │               └── Label itemLabel
│   │   └── Group optionsSlider (UNUSED — remove or implement)
│   └── ... (other scenes)
├── WholphinSidebar (hidden, toggled by LEFT)
│   ├── Rectangle sidebarBg
│   ├── Group userSection
│   ├── LabelList sidebarDestinations
│   └── LabelList sidebarLibraryList
├── JFOverhang (always visible at top)
├── Group audioMiniPlayer (hidden)
├── Spinner (hidden)
└── Label statusLabel (hidden, for debug)
```

---

## 3. Current Issues & Root Causes

### 3.1 CRITICAL: LEFT Key Opens Sidebar from Anywhere

**Files:** `BaseScene.bs:66-71`

```brightscript
if key = "left" then
    if m.sidebar <> invalid then
        showSidebar()
        return true  ← ALWAYS returns true, steals LEFT from RowList
    end if
end if
```

**Root Cause:** RowList internally handles LEFT/RIGHT for horizontal scrolling, but the key event still propagates to parent onkeyEvent handlers. BaseScene intercepts ALL LEFT presses regardless of what is focused. This means:
- User presses LEFT to scroll left in rows → sidebar opens instead
- RowList receives the key action AND the event propagates

**Fix:** BaseScene must check if the focused component is a RowList or if a row-based screen is active before opening sidebar. Or better: let screens handle LEFT themselves, and only open sidebar from BaseScene if no child consumes the event.

### 3.2 HIGH: Home.onKeyEvent Doesn't Consume Direction Keys

**Files:** `Home.bs:207-211`

```brightscript
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then return true
    return false
end function
```

Only BACK is consumed. LEFT/RIGHT/UP/DOWN all pass through to BaseScene. The RowList (HomeRows) is a child of Home — keys propagate upward through Home to BaseScene.

### 3.3 HIGH: Sidebar Animations Missing

**Files:** `WholphinSidebar.xml`, `BaseScene.bs:36-53`

Sidebar visibility toggles instantly with no animation — `visible = false/true`. Should slide in from left with `translation` animation.

### 3.4 HIGH: Focus Return After Sidebar Close

**Files:** `BaseScene.bs:42-53`

```brightscript
function hideSidebarAndRestoreFocus() as Void
    ...
    home = m.content.getChild(m.content.getChildCount() - 1)
    if home <> invalid and home.isSubType("Group") then
        home.setFocus(true)
```
This sets focus to the Home Group, not to HomeRows. RowList won't have focus until user presses a key. Should call `homeRows.setFocus(true)` or `home.findNode("homeRows").setFocus(true)`.

### 3.5 HIGH: HomeItem Has No Focus Highlight

**Files:** `HomeItem.xml`

No focus rectangle, no scale animation, no color change on focus. The MarkupGrid handles focus via `focusX`/`focusBitmap`, but the item itself doesn't respond.

### 3.6 MEDIUM: PosterRow.brs Is Dead Code (Observes m.port)

**Files:** `PosterRow.brs:10`

```brightscript
m.top.observeField("itemContent", m.port)
```

This is the OLD item component used by MainScene (which is never instantiated — BaseScene is used instead). It observes with `m.port` which doesn't exist in this component. BUT this file is irrelevant since Home uses HomeRow/HomeItem. Should clean up but not blocking.

### 3.7 MEDIUM: HomeRows.addRow() Is Dead Code

**Files:** `HomeRows.bs:12-49`

The `addRow()` function in HomeRows.bs uses `AppendChild` (wraps items in extra child node) and does direct field assignment (`child.type = ...`) without `AddFields()`. This function is never called — Home.bs bypasses it with `addRowToHomeRows()`. Should clean up.

### 3.8 MEDIUM: OptionsSlider Is Unused

**Files:** `Home.xml:67-72`

`optionsSlider` group is defined but never used. Remove or implement.

### 3.9 LOW: Backdrop Animation Over-Engineered

**Files:** `Home.bs:11-23, 213-236`

The cross-fade backdrop animation creates an `Animation` node with `FloatFieldInterpolator` to fade between backdrop images. This adds complexity and might flicker. Could simplify.

### 3.10 LOW: HomeRows Missing RowList Config

**Files:** `HomeRows.bs:3-9`

Missing config properties that RowList might need:
- `rowFocusAnimationStyle` not set
- `showRowLabel` defaults (RowList has its own row label handling, but HomeRow has its own label)
- `rowLabelOffset` not set
- `focusX` not set (controls horizontal focus position)

---

## 4. Wholphin Android TV Parity Checklist

| Feature | Android | Roku | Status |
|---|---|---|---|
| Home screen rows | ✓ | ✓ (HomeRows) | PARTIAL |
| Continue Watching row | ✓ | ✓ | NEEDS FIX |
| Next Up row | ✓ | ✓ | NEEDS FIX |
| Latest Media row | ✓ | ✓ | NEEDS FIX |
| Favorites row | ✓ | ✓ | NEEDS FIX |
| Hero banner auto-rotate | ✓ | ✓ (HeroBanner) | OK |
| Backdrop on focus | ✓ | ✓ (updateBackdrop) | OK |
| Side navigation drawer | ✓ | ✓ (WholphinSidebar) | NEEDS FIX |
| Sidebar slide animation | ✓ | ✗ | MISSING |
| Sidebar user section | ✓ | ✓ (userSection) | OK |
| Sidebar library list | ✓ | ✓ | OK |
| Item poster + title | ✓ | ✓ (HomeItem) | OK |
| Watched indicator | ✓ | ✓ (checkmark) | OK |
| Focus highlight | ✓ | ✗ | MISSING |
| Detail screen | ✓ | ✓ (MovieDetails etc.) | OK |
| Playback | ✓ | ✓ (videoPlayer) | OK |
| Search | ✓ | ✓ | OK |
| Settings | ✓ | ✓ (SettingsView) | OK |
| Discover (Seerr) | ✓ | ✓ (DiscoverPage) | OK |
| Audio player | ✓ | ✓ (audioPlayer) | OK |
| Item progress bar | ✓ | ✗ on HomeItem | MISSING |
| Favorites badge | ✓ | ✗ | MISSING |
| Loading states | ✓ | ✗ | MISSING |
| Error states | ✓ | ✗ | MISSING |

---

## 5. Required Changes

### 5.1 BaseScene - LEFT Key Handler

**File:** `components/BaseScene.bs`

Change `onKeyEvent` to only open sidebar when:
- LEFT pressed from row list (check if row is at column 0) OR
- Only when Home is the active scene with rows

**Recommended approach:** Remove sidebar logic from BaseScene entirely. Let Home (and other screens) handle showing/hiding sidebar themselves via `showSidebar()`/`hideSidebarAndRestoreFocus()`. BaseScene should only handle GLOBAL keys (BACK when sidebar is visible).

### 5.2 Home - Add onKeyEvent for Direction Keys

**File:** `components/home/Home.bs`

Add handler for LEFT at row column 0 → show sidebar. Add handler for LEFT>0 → let RowList handle. Add handler for RIGHT at end → maybe show options slider.

### 5.3 HomeRows - Add RowList Configuration

**File:** `components/home/HomeRows.bs`

Set `rowFocusAnimationStyle`, proper `numRows`, and remove dead `addRow()` function.

### 5.4 HomeRow - Fix Content Node Structure

**File:** `components/home/HomeRow.bs`

The `onRowContentChange` looks correct — it reads items from `content.getChildCount()`. But verify that RowList actually passes the row node as the `content` field.

### 5.5 HomeItem - Add Focus Highlight

**File:** `components/home/HomeItem.xml` + `HomeItem.bs`

Add a focus indicator rectangle that shows when item is focused. Roku MarkupGrid doesn't have built-in focus visuals — the item component must handle it.

### 5.6 WholphinSidebar - Add Open/Close Animation

**File:** `components/WholphinSidebar.xml` + `WholphinSidebar.bs`

Add `translation` animation for slide-in from left. Change visibility toggle to animate translation from `[-350, 0]` (hidden) to `[0, 0]` (visible).

### 5.7 BaseScene - Fix Focus Return

**File:** `components/BaseScene.bs`

After sidebar close, find `homeRows` specifically and set focus there, not just on the Home group.

---

## 6. File-by-File Modification Plan

### Phase 1: Core Fixes (Priority: CRITICAL)

#### File: `components/BaseScene.bs`

```brightscript
' Changes:
' 1. Remove LEFT key sidebar toggle from BaseScene (let screens handle it)
' 2. Only BACK key closes sidebar (already works)
' 3. Fix hideSidebarAndRestoreFocus to target HomeRows

' Before:
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        if m.sidebar <> invalid and m.sidebar.visible then
            hideSidebarAndRestoreFocus()
            return true
        end if
        return false
    end if
    if key = "left" then  ← REMOVE THIS BLOCK
        if m.sidebar <> invalid then
            showSidebar()
            return true
        end if
    end if
    return false
end function

' After:
function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        if m.sidebar <> invalid and m.sidebar.visible then
            hideSidebarAndRestoreFocus()
            return true
        end if
        return false
    end if
    return false
end function

' Fix hideSidebarAndRestoreFocus:
function hideSidebarAndRestoreFocus() as Void
    if m.sidebar <> invalid then
        m.sidebar.visible = false
    end if
    ' Find HomeRows specifically
    home = m.content.getChild(m.content.getChildCount() - 1)
    if home <> invalid then
        homeRows = home.findNode("homeRows")
        if homeRows <> invalid then
            homeRows.setFocus(true)
            return
        end if
        home.setFocus(true)
    else
        m.content.setFocus(true)
    end if
end function
```

#### File: `components/home/Home.bs`

```brightscript
' Changes:
' 1. Add onKeyEvent to handle LEFT for sidebar, consume direction keys

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    if key = "back" then
        ' Let BaseScene handle BACK
        return false
    end if
    if key = "left" then
        ' Check if at beginning of row
        if m.homeRows <> invalid then
            focused = m.homeRows.rowItemFocused
            if focused.Count() >= 2 and focused[1] = 0 then
                ' At column 0 — show sidebar
                scene = m.top.getScene()
                if scene <> invalid then
                    scene.showSidebar()
                end if
                return true
            end if
        end if
        return false
    end if
    ' Consume other direction keys to prevent BaseScene from intercepting
    if key = "up" or key = "down" or key = "right" then
        return false  ' RowList handles these internally
    end if
    return false
end function
```

### Phase 2: Visual Fixes (Priority: HIGH)

#### File: `components/home/HomeItem.xml`

Add focus indicator rectangle:

```xml
<Rectangle
  id="focusIndicator"
  translation="[-4, -4]"
  width="204"
  height="348"
  color="0x00A4DC00"
  blendColor="0x00A4DCFF" />
```

#### File: `components/home/HomeItem.bs`

```brightscript
sub Init()
    m.poster = m.top.findNode("itemPoster")
    m.checkmark = m.top.findNode("playedCheckmark")
    m.label = m.top.findNode("itemLabel")
    m.focusIndicator = m.top.findNode("focusIndicator")
    m.top.observeField("itemContent", "onItemContentChange")
    m.top.observeField("focusedChild", "onFocusChange")
end sub

function onFocusChange() as Void
    if m.focusIndicator <> invalid then
        m.focusIndicator.visible = m.top.hasFocus()
    end if
end function
```

#### File: `components/WholphinSidebar.xml`

Set initial translation to [-350, 0] to be off-screen:

```xml
<component name="WholphinSidebar" extends="Group">
  <interface>
    ...
    <field id="sidebarState" type="string" value="closed" />
  </interface>
```

#### File: `components/WholphinSidebar.bs`

Add slide animation:

```brightscript
sub Init()
    ...
    m.top.translation = [-350, 0]
    ' Create animation
    m.slideAnim = CreateObject("roSGNode", "Animation")
    m.slideAnim.duration = 0.2
    m.slideAnim.easeFunction = "out-quad"
    
    interp = CreateObject("roSGNode", "FloatFieldInterpolator")
    interp.key = [0.0, 1.0]
    interp.keyValue = [0.0, -350.0]  ' Will be set dynamically
    interp.fieldToInterp = "top.translation[0]"
    m.slideAnim.appendChild(interp)
    m.top.appendChild(m.slideAnim)
    ...
end sub

sub onVisibleChange()
    if m.top.visible then
        ' Slide in
        interp = m.slideAnim.getChild(0)
        if interp <> invalid then
            interp.keyValue = [-350.0, 0.0]
            m.slideAnim.control = "start"
        end if
        if m.destinations <> invalid then
            m.destinations.setFocus(true)
        end if
    else
        ' Slide out
        interp = m.slideAnim.getChild(0)
        if interp <> invalid then
            interp.keyValue = [0.0, -350.0]
            m.slideAnim.control = "start"
        end if
    end if
end sub
```

### Phase 3: Cleanup (Priority: MEDIUM)

#### File: `components/home/HomeRows.bs`

Remove dead `addRow()` function. Add missing RowList config:

```brightscript
sub Init()
    m.top.itemSize = [1720, 400]
    m.top.itemComponentName = "HomeRow"
    m.top.numRows = 0
    m.top.rowHeights = [400]
    m.top.rowSpacings = [30]
    m.top.rowFocusAnimationStyle = "floatingFocus"
end sub
```

#### File: `components/home/Home.xml`

Remove or simplify `optionsSlider`.

### Phase 4: Navigation Flow (Priority: HIGH)

1. Home.onKeyEvent for LEFT at column 0 → shows sidebar
2. Sidebar LEFT key → closes sidebar (already works)
3. Sidebar OK → navigates to selection, closes sidebar
4. BACK key → BaseScene closes sidebar, restores focus to HomeRows
5. UP/DOWN on sidebar → moves between destinations and library lists (partially works)

---

## 7. Navigation Flow Diagram

```
┌────────────────────────────────────────────────────────────────────────┐
│  BaseScene (Scene)                                                     │
│                                                                        │
│  ┌────────────────────────────────┐       ┌─────────────────────────┐  │
│  │  Home Screen                   │       │  WholphinSidebar        │  │
│  │                                │       │  (hidden initially)     │  │
│  │  ┌─────────────────────────┐   │  LEFT │                         │  │
│  │  │  HeroBanner             │   │  at   │  ┌───────────────────┐  │  │
│  │  │  (auto-cycle)           │   │  col0 │  │  sidebarDestina-  │  │  │
│  │  └─────────────────────────┘   │──────→│  │  tions            │  │  │
│  │                                │       │  │  (LabelList)      │  │  │
│  │  ┌─────────────────────────┐   │       │  └───────────────────┘  │  │
│  │  │  HomeRows (RowList)     │   │       │  ┌───────────────────┐  │  │
│  │  │  ┌───────────────────┐  │   │       │  │  sidebarLibrary-  │  │  │
│  │  │  │  HomeRow (row 0)  │  │   │       │  │  List (LabelList) │  │  │
│  │  │  │  ┌─ HomeItem ───┐ │  │   │       │  └───────────────────┘  │  │
│  │  │  │  │ Poster+Label │ │  │   │       │                         │  │
│  │  │  │  └──────────────┘ │  │   │  LEFT  │                         │  │
│  │  │  └───────────────────┘  │  │←───────│                         │  │
│  │  │  ┌───────────────────┐  │   │  BACK  │  BACK                   │  │
│  │  │  │  HomeRow (row 1)  │  │   │       │  (when visible)         │  │
│  │  │  └───────────────────┘  │   │       │                         │  │
│  │  └─────────────────────────┘   │       └─────────────────────────┘  │
│  │                                │                                    │
│  └────────────────────────────────┘                                    │
│                                                                        │
│  ┌─────────────────────────────────────────────────────────┐           │
│  │  JFOverhang (clock, title, user)                        │           │
│  └─────────────────────────────────────────────────────────┘           │
└────────────────────────────────────────────────────────────────────────┘

Key Routes:
  HomeRows ↔ Sidebar: LEFT at col0, LEFT/OK to close/navigate
  HeroBanner ← Focus: Not focusable (cosmetic only)
  RowList ← Focus: setFocus on finishLoading
  RowList ← Items: OK → HandleItemSelection → detail screen
  Sidebar ← Items: OK → destination/library → CreateHomeGroup/CreateVisualLibraryScene
  BACK → SceneManager popScene → return to previous screen
```

---

## 8. Testing Checklist

### Home Screen
- [ ] App launches, shows server URL entry
- [ ] Server URL entered, connects to Jellyfin
- [ ] User list appears, user selected
- [ ] Password entered OR public user without password
- [ ] Home screen appears after auth
- [ ] Hero banner shows items, auto-cycles every 8s
- [ ] Continue Watching row appears with items
- [ ] Next Up row appears with items
- [ ] Latest Media row appears with items
- [ ] Favorites row appears with items
- [ ] Each row shows poster images and titles
- [ ] Rows scroll horizontally with LEFT/RIGHT
- [ ] Vertical UP/DOWN navigates between rows
- [ ] Focus highlight visible on focused item
- [ ] Backdrop changes on item focus
- [ ] OK on item opens movie/show details

### Sidebar
- [ ] LEFT at beginning of row opens sidebar
- [ ] Sidebar slides in smoothly
- [ ] Destinations list is focused on open
- [ ] UP/DOWN navigates within destinations
- [ ] DOWN at end of destinations → library list
- [ ] UP at top of library list → destinations
- [ ] OK on destination navigates to it
- [ ] OK on library navigates to library view
- [ ] LEFT on sidebar closes it
- [ ] BACK on sidebar closes it
- [ ] Focus returns to HomeRows after sidebar close
- [ ] "Home" destination returns to home

### Navigation
- [ ] LEFT/RIGHT on rows scrolls correctly
- [ ] No sidebar opens when scrolling LEFT if not at column 0
- [ ] BACK from detail returns to home
- [ ] Scene stack navigation works correctly
- [ ] No focus loops

### Visual
- [ ] Focus highlight on items
- [ ] Checkmark for watched items
- [ ] Row titles visible
- [ ] Poster images load
- [ ] Backdrop transitions work
- [ ] No visual glitches

---

## 9. Remaining Questions

1. **Does RowList properly set `content` field on HomeRow instances?** This is critical — if RowList doesn't set `m.top.content` on HomeRow, `onRowContentChange` never fires. Check by adding diagnostic: `? "[HomeRow.Init] started, content="; m.top.content` at init.

2. **Does MarkupGrid need `numColumns` to be set before content?** Some Roku firmware requires `numColumns` and `numRows` to be set before setting content. Currently `numColumns="8"` is set in XML but not in BS code.

3. **Is PosterImage() returning valid URLs?** Items are created with `PosterImage(child.id)` which returns an associative array with `.url`. Need to verify this returns absolute HTTP URLs.

4. **What Roku firmware version is running?** Some RowList behaviors differ between firmware versions (e.g., LEFT key propagation).

5. **Is `m.global.session` populated with proper auth before home loads?** The data loading tasks run after auth, but they need the access token in the request headers.

---

## 10. Implementation Status

- [ ] Phase 1: BaseScene LEFT key fix
- [ ] Phase 1: Home onKeyEvent with sidebar trigger
- [ ] Phase 1: hideSidebarAndRestoreFocus targeting HomeRows
- [ ] Phase 2: HomeItem focus indicator
- [ ] Phase 2: WholphinSidebar slide animation
- [ ] Phase 3: HomeRows cleanup (remove dead code, add config)
- [ ] Phase 3: Home.xml optionsSlider cleanup
- [ ] Phase 4: Full navigation flow test
- [ ] Phase 5: Deploy + validate on Roku
