sub Init()
    m.homeRows = m.top.findNode("homeRows")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.pendingRows = []
    m.pendingSections = 0

    items = [
        { label: "Home",     id: "home" }
        { label: "Search",   id: "search" }
        { label: "Favorites",id: "favorites" }
        { label: "Movies",   id: "movies" }
        { label: "Shows",    id: "tvshows" }
        { label: "Continue", id: "continue" }
        { label: "Playlists",id: "playlists" }
        { label: "Settings", id: "settings" }
    ]
navGroup = m.top.findNode("navItemsGroup")
navGroup.focusable = true
for i = 0 to items.Count() - 1
    item = items[i]
    g = CreateObject("roSGNode", "Group")
    g.focusable = true
    g.translation = [0, i * 72]
    l = CreateObject("roSGNode", "Label")
    l.text = item.label
    l.font = "font:SmallSystemFont"
    l.color = "0x999999FF"
    l.width = 140
    l.height = 72
    l.horizAlign = "left"
    l.vertAlign = "center"
    l.translation = [12, 0]
    g.appendChild(l)
    navGroup.appendChild(g)
end for

    m.loadTimer = CreateObject("roSGNode", "Timer")
    m.loadTimer.duration = 0
    m.loadTimer.repeat = false
    m.loadTimer.observeField("fire", "onLoadTimer")
    m.top.appendChild(m.loadTimer)
    m.loadTimer.control = "start"
end sub

sub onLoadTimer()
    userId = session.user.GetId()
    if userId = "" then
        return
    end if

    m.userId = userId
    m.pendingSections = 5
    m.sectionTasks = []

    launchOneTask("hero",        userId, "onSectionLoaded")
    launchOneTask("resume",      userId, "onSectionLoaded")
    launchOneTask("nextup",      userId, "onSectionLoaded")
    launchOneTask("latestmedia", userId, "onSectionLoaded")
    launchOneTask("favorites",   userId, "onSectionLoaded")
end sub

sub launchOneTask(ftype as String, userId as String, cb as String)
    task = CreateObject("roSGNode", "LoadItemsTask")
    task.itemsToLoad = ftype
    task.userId = userId
    task.observeField("loadStatus", cb)
    m.top.appendChild(task)
    task.control = "RUN"
    m.sectionTasks.Push(task)
end sub

sub onSectionLoaded(event as Object)
    task = event.getRoSGNode()
    if task.loadStatus = "loaded" then
        items = task.loadedItems
        if items = invalid then items = []

        st = task.itemsToLoad
        if st = "hero" and items.Count() > 0 then
            m.top.heroItems = items
        else if st = "resume" and items.Count() > 0 then
            addRowToHomeRows("Continue Watching", items, "resume")
        else if st = "nextup" and items.Count() > 0 then
            addRowToHomeRows("Next Up", items, "nextup")
        else if st = "latestmedia" and items.Count() > 0 then
            addRowToHomeRows("Latest Media", items, "latestmedia")
        else if st = "favorites" and items.Count() > 0 then
            addRowToHomeRows("Favorites", items, "favorites")
        end if
    end if

    m.pendingSections = m.pendingSections - 1
    ? "[HomeScreen.onSectionLoaded] remaining="; m.pendingSections
    if m.pendingSections <= 0 then finishLoading()
end sub

sub finishLoading()
    ? "[HomeScreen.finishLoading] building content..."
    if m.loadingLabel <> invalid then m.loadingLabel.visible = false

    content = CreateObject("roSGNode", "ContentNode")
    ? "[HomeScreen.finishLoading] pendingRows="; m.pendingRows.Count()
    for each rowData in m.pendingRows
        ? "[HomeScreen.finishLoading] row="; rowData.title; " items="; rowData.items.Count()
        rowNode = content.CreateChild("ContentNode")
        rowNode.title = rowData.title
        rowNode.AddFields({ rowType: rowData.rowType })
        for each item in rowData.items
            child = rowNode.CreateChild("ContentNode")
            child.id = chainLookupReturn(item, ["Id"], "")
            child.title = chainLookupReturn(item, ["Name"], "")
            itemType = chainLookupReturn(item, ["Type"], "")
            child.AddFields({ type: itemType, json: item })
            img = PosterImage(child.id)
            if img <> invalid then
                child.HDPosterUrl = img.url
                child.SDPosterUrl = img.url
            end if
        end for
    end for

    ? "[HomeScreen.finishLoading] setting homeRows.content, rows="; content.GetChildCount()
    m.homeRows.content = content
    ? "[HomeScreen.finishLoading] homeRows.content set"
    m.homeRows.visible = true
    ? "[HomeScreen.finishLoading] setting focus"
    m.homeRows.setFocus(true)
    ? "[HomeScreen.finishLoading] done"
end sub

sub addRowToHomeRows(rowTitle as String, items as Object, rowType as String)
    if items = invalid or items.Count() = 0 then return
    m.pendingRows.Push({ title: rowTitle, rowType: rowType, items: items })
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    return false
end function
