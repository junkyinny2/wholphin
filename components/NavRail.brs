sub init()
    m.itemStack = m.top.findNode("itemStack")
    m.icons = []
    m.highlights = []
    m.itemDefs = []
    m.currentIndex = 0
    m.scrollY = 0

    m.top.observeField("focusedChild", "onFocusChanged")
    m.hasFocus = false

    ' Match the official Wholphin drawer order: profile -> search -> home ->
    ' favorites -> discover (if enabled) -> libraries -> settings
    m.builtins = [
        { id: "profile", icon: "nav_user" }
        { id: "search", icon: "nav_search" }
        { id: "home", icon: "nav_home" }
        { id: "favorites", icon: "nav_favorites" }
    ]
    discoverEnabled = chainLookupReturn(m.global, "session.user.settings.discover.enabled", "false")
    if discoverEnabled = "true" then
        m.builtins.push({ id: "discover", icon: "nav_collection" })
    end if

    ' Library index shared with HomeScreen so nav selection can look up id -> name/type
    getGlobalAA().__navLibraries = {}

    m.libraries = []
    rebuildRail()
    loadLibraries()

    m.top.observeField("visible", "onVisibleChange")
    ? "[NavRail.init] OK, dynamic"
end sub

sub loadLibraries()
    userId = ""
    s = m.global.session
    if s <> invalid and s.user <> invalid then
        uid = chainLookupReturn(s.user, ["id"], "")
        if uid <> invalid then userId = uid
    end if
    if userId = "" then
        ? "[NavRail] loadLibraries: no userId yet"
        return
    end if
    m.loadTask = CreateObject("roSGNode", "LoadItemsTask")
    m.loadTask.itemsToLoad = "libraries"
    m.loadTask.userId = userId
    m.loadTask.observeField("loadStatus", "onLibrariesLoaded")
    m.top.appendChild(m.loadTask)
    m.loadTask.control = "RUN"
end sub

sub onLibrariesLoaded()
    task = m.loadTask
    if task = invalid then return
    status = task.loadStatus
    libs = task.loadedItems
    task.unobserveField("loadStatus")
    m.top.removeChild(task)
    m.loadTask = invalid

    if status <> "loaded" or libs = invalid then
        ? "[NavRail] loadLibraries failed: "; status
        return
    end if

    m.libraries = []
    libIndex = getGlobalAA().__navLibraries
    for each lib in libs
        libId = chainLookupReturn(lib, ["Id"], "")
        libName = chainLookupReturn(lib, ["Name"], "")
        libType = LCase(chainLookupReturn(lib, ["CollectionType"], ""))
        if libId <> "" then
            m.libraries.push({ id: libId, name: libName, collectionType: libType })
            if libIndex <> invalid then
                libIndex[libId] = { name: libName, collectionType: libType }
            end if
        end if
    end for
    rebuildRail()
    ? "[NavRail] libraries loaded="; m.libraries.Count()
end sub

function libToDef(lib as Object) as Object
    return {
        id: "lib:" + lib.id
        icon: iconForType(lib.collectionType)
        name: lib.name
        type: lib.collectionType
    }
end function

function iconForType(ct as String) as String
    if ct = "movies" then return "nav_movies"
    if ct = "tvshows" then return "nav_tv"
    if ct = "music" or ct = "musicvideos" then return "nav_playlist"
    if ct = "livetv" then return "nav_cast"
    if ct = "homevideos" or ct = "videos" then return "nav_library"
    if ct = "boxsets" then return "nav_collection"
    if ct = "playlists" then return "nav_playlist"
    return "nav_collection"
end function

sub rebuildRail()
    items = []
    for each b in m.builtins
        items.push(b)
    end for
    for each lib in m.libraries
        items.push(libToDef(lib))
    end for
    items.push({ id: "settings", icon: "nav_settings" })
    m.itemDefs = items

    populateStack()
    if m.currentIndex >= m.itemDefs.Count() then m.currentIndex = m.itemDefs.Count() - 1
    if m.currentIndex < 0 then m.currentIndex = 0

    ' Start highlighted on Home (index 2 in the builtin order)
    if m.itemDefs.Count() > 2 and m.itemDefs[2].id = "home" then m.currentIndex = 2

    updateHighlights()
    updateIconColors()
    updateScroll()
end sub

sub updateHighlights()
    for i = 0 to m.highlights.Count() - 1
        hl = m.highlights[i]
        if hl <> invalid then hl.visible = (i = m.currentIndex)
    end for
end sub

sub populateStack()
    m.icons = []
    m.highlights = []
    while m.itemStack.getChildCount() > 0
        m.itemStack.removeChild(m.itemStack.getChild(0))
    end while
    index = 0
    for each def in m.itemDefs
        grp = CreateObject("roSGNode", "Group")
        grp.focusable = false
        grp.translation = [0, index * 84]
        hl = CreateObject("roSGNode", "Rectangle")
        hl.width = 72
        hl.height = 56
        hl.translation = [-36, -8]
        hl.color = "0x2FD0FFFF"
        hl.opacity = 0.30
        hl.visible = false
        hl.focusable = false
        grp.appendChild(hl)
        icon = CreateObject("roSGNode", "Poster")
        icon.uri = "pkg:/images/icons/" + def.icon + ".png"
        icon.width = 40
        icon.height = 40
        icon.focusable = false
        grp.appendChild(icon)
        m.itemStack.appendChild(grp)
        m.icons.push(icon)
        m.highlights.push(hl)
        index = index + 1
    end for
end sub

sub onFocusChanged()
    m.hasFocus = m.top.hasFocus()
    updateIconColors()
end sub

sub onVisibleChange()
    updateIconColors()
end sub

function onKeyEvent(key as string, press as boolean) as boolean
    if not press then return false
    handled = false

    if key = "up"
        if m.currentIndex > 0
            setHighlight(m.currentIndex, false)
            m.currentIndex--
            setHighlight(m.currentIndex, true)
        end if
        handled = true
    else if key = "down"
        if m.currentIndex < m.itemDefs.Count() - 1
            setHighlight(m.currentIndex, false)
            m.currentIndex++
            setHighlight(m.currentIndex, true)
        end if
        handled = true
    else if key = "OK"
        def = m.itemDefs[m.currentIndex]
        if def <> invalid then m.top.itemSelected = def.id
        handled = true
    end if

    updateIconColors()
    updateScroll()
    return handled
end function

sub setHighlight(index as integer, on as boolean)
    hl = m.highlights[index]
    if hl <> invalid then hl.visible = on
end sub

sub updateIconColors()
    for i = 0 to m.icons.Count() - 1
        icon = m.icons[i]
        if icon = invalid then continue for
        def = m.itemDefs[i]
        id = ""
        if def <> invalid and def.id <> invalid then id = def.id
        if id = "home"
            icon.blendColor = "0x2FD0FFFF"
        else if m.hasFocus and i = m.currentIndex
            icon.blendColor = "0x2FD0FFFF"
        else
            icon.blendColor = "0x8A93A6FF"
        end if
    end for
end sub

sub updateScroll()
    itemPitch = 84
    viewHeight = 868
    count = m.itemDefs.Count()
    if count = 0 then return
    maxScroll = count * itemPitch - viewHeight
    if maxScroll < 0 then maxScroll = 0
    itemTop = m.currentIndex * itemPitch
    itemBottom = itemTop + itemPitch
    if itemTop < m.scrollY then m.scrollY = itemTop
    if itemBottom > m.scrollY + viewHeight then m.scrollY = itemBottom - viewHeight
    if m.scrollY < 0 then m.scrollY = 0
    if m.scrollY > maxScroll then m.scrollY = maxScroll
    m.itemStack.translation = [0, 112 - m.scrollY]
end sub
