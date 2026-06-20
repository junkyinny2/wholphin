# Plan 003 — Move home screen data loading off the render thread (async LoadItemsTask)

**Commit:** `c7ef21b`  
**Category:** Correctness / Performance  
**Impact:** HIGH — home screen currently blocks render thread during all API calls; UI is frozen for the full duration of 4+ network requests  
**Effort:** M  
**Risk of fix:** MEDIUM (threading change)  

---

## Why this matters

`Home.bs:LoadData()` calls `loadLibraries()`, `loadHeroItems()`, `loadHomeRows()` — each makes one or more synchronous API calls via `getJson()` in `baserequest.bs`. Each `getJson()` call does `wait(30000, port)` — that 30-second timeout **blocks the render thread**. With 4 home sections + hero items + libraries, the render thread is blocked for up to 5× 30 seconds = 2.5 minutes worst-case if any server is slow.

Roku's render thread is the UI thread. Blocking it freezes animations, input handling, and remote control. The correct pattern is to offload work to a `Task` node.

`LoadItemsTask` (in `components/home/LoadItemsTask.bs`) already exists and already handles all the home section types. It just isn't being used from `Home.bs`. Instead, `Home.bs` duplicates all the API calls inline.

**Evidence:**
```brightscript
' components/home/Home.bs:69-83 (LoadData blocks render thread)
function LoadData() as Void
    m.top.loadingData = true
    loadLibraries()      ' blocking getJson call
    loadHeroItems()      ' blocking getJson calls
    loadHomeRows()       ' blocking getJson calls × 4 sections
    m.top.loadingData = false
    m.top.dataLoaded = true
end function
```

```brightscript
' components/home/LoadItemsTask.bs — already exists but unused from Home.bs
sub loadItems()
    itemsToLoad = m.top.itemsToLoad
    ' ...correct async task implementation...
end sub
```

---

## Implementation

### File: `components/home/Home.bs`

Replace the synchronous `LoadData()`, `loadHeroItems()`, `loadHomeRows()`, `loadSection()` functions with async task dispatch using `LoadItemsTask`.

#### Step 1 — Rewrite `LoadData()` to launch tasks

```brightscript
' Replace LoadData() in Home.bs
function LoadData() as Void
    m.top.loadingData = true
    userId = session.user.GetId()
    
    ' Launch libraries load
    loadLibrariesAsync()
    
    ' Launch hero items task
    launchItemTask("hero", userId)
    
    ' Launch each home section task
    launchItemTask("resume", userId)
    launchItemTask("nextup", userId)
    launchItemTask("latestmedia", userId)
    launchItemTask("favorites", userId)
end function
```

#### Step 2 — Add `launchItemTask()` helper

```brightscript
function launchItemTask(sectionType as String, userId as String) as Void
    task = CreateObject("roSGNode", "LoadItemsTask")
    task.itemsToLoad = sectionType
    task.userId = userId
    task.observeField("loadStatus", "onItemsLoaded")
    task.control = "RUN"
    ' Store reference to prevent GC
    if m.loadTasks = invalid then m.loadTasks = []
    m.loadTasks.Push(task)
end function
```

#### Step 3 — Add `onItemsLoaded()` callback

```brightscript
sub onItemsLoaded()
    ' Find which task fired — iterate all tasks
    if m.loadTasks = invalid then return
    for each task in m.loadTasks
        if task.loadStatus = "loaded" then
            items = task.loadedItems
            sectionType = task.itemsToLoad
            if items = invalid then items = []
            if sectionType = "hero" then
                if items.Count() > 0 then
                    m.top.heroItems = items
                    m.heroBanner.items = items
                end if
            else if sectionType = "resume" then
                if items.Count() > 0 then
                    m.homeRows.callFunc("addRow", translateText("Continue Watching"), items, "resume")
                end if
            else if sectionType = "nextup" then
                if items.Count() > 0 then
                    m.homeRows.callFunc("addRow", translateText("Next Up"), items, "nextup")
                end if
            else if sectionType = "latestmedia" then
                if items.Count() > 0 then
                    m.homeRows.callFunc("addRow", translateText("Latest Media"), items, "latestmedia")
                end if
            else if sectionType = "favorites" then
                if items.Count() > 0 then
                    m.homeRows.callFunc("addRow", translateText("Favorites"), items, "favorites")
                end if
            end if
        end if
    end for
    
    ' Check if all tasks done
    allDone = true
    for each task in m.loadTasks
        if task.loadStatus <> "loaded" and task.loadStatus <> "error" then
            allDone = false
        end if
    end for
    if allDone then
        m.top.loadingData = false
        m.top.dataLoaded = true
    end if
end sub
```

#### Step 4 — Add `loadLibrariesAsync()` 

Libraries loading (`GetUserViews`) can also use a task, but is simpler to keep synchronous since it's a single fast call that's needed before rows render. Alternatively, inline it with a callback. The simplest safe approach:

```brightscript
function loadLibrariesAsync() as Void
    ' GetUserViews is a single lightweight call; acceptable to keep synchronous
    ' but move off render thread by queuing via Task
    task = CreateObject("roSGNode", "LoadItemsTask")
    task.itemsToLoad = "libraries"
    task.userId = session.user.GetId()
    task.observeField("loadStatus", "onLibrariesLoaded")
    task.control = "RUN"
    if m.loadTasks = invalid then m.loadTasks = []
    m.loadTasks.Push(task)
end function
```

Add `"libraries"` case to `LoadItemsTask.bs`:
```brightscript
else if itemsToLoad = "libraries" then
    result = GetUserViews(userId)
    if result <> invalid then result = result.Items
```

And add `onLibrariesLoaded()` handler in `Home.bs` to populate sidebar.

#### Step 5 — Remove old synchronous functions

Delete (or comment out) the now-unused `loadLibraries()`, `loadHeroItems()`, `loadHomeRows()`, `loadSection()` functions from `Home.bs` to avoid confusion.

---

## Files modified

| File | Change |
|------|--------|
| `components/home/Home.bs` | Replace synchronous LoadData + sub-functions with async task dispatch |
| `components/home/LoadItemsTask.bs` | Add "libraries" case |
| `components/home/Home.xml` | No XML changes needed |

---

## Files NOT to touch

- `source/ShowScenes.bs` — CreateHomeGroup is unchanged
- `baserequest.bs` — sync getJson stays as-is (used inside Task threads, which is correct)
- Other home components (HomeRow, HomeRows, HeroBanner) — unchanged

---

## Verification

1. Deploy to `192.168.1.100`
2. Log in and navigate to home screen
3. **Expected:** spinner shows briefly, then rows appear one by one as each task completes — UI is responsive throughout
4. **Failure indicator:** home screen is frozen/unresponsive while loading, or rows never appear

---

## Maintenance note

Any new home section added to `loadHomeRows()` in the future must use `launchItemTask()` + callback — never a synchronous API call from `Home.bs`.

---

## Escape hatches

- If `HomeRows.callFunc("addRow")` crashes when called from a render-thread callback, fall back to setting a field on `m.top` and observing it instead of calling `addRow` directly via callFunc.
- If tasks are GC'd before firing, increase the `m.loadTasks` array lifetime by storing it on `m.top` as a field of type `array`.
