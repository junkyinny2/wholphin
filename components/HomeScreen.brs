sub Init()
    m.bgFill = m.top.findNode("bgFill")
    m.heroBackdrop = m.top.findNode("heroBackdrop")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroSubtitle = m.top.findNode("heroSubtitle")
    m.heroMeta = m.top.findNode("heroMeta")
    m.heroDescription = m.top.findNode("heroDescription")
    m.clockLabel = m.top.findNode("clockLabel")
    m.navRail = m.top.findNode("navRail")
    m.homeRows = m.top.findNode("homeRows")
    m.loadingLabel = m.top.findNode("loadingLabel")
    m.errorGroup = m.top.findNode("errorGroup")
    m.retryButton = m.top.findNode("retryButton")
    m.playBtnBg = m.top.findNode("playBtnBg")
    m.infoBtnBg = m.top.findNode("infoBtnBg")

    if m.bgFill <> invalid then m.bgFill.color = "0x0A0E14FF"

    m.pendingRows = []
    m.pendingSections = 0
    m.sectionTasks = []
    m.heroItems = []
    m.heroButtonFocused = false
    m.heroButtonIndex = 0

    m.navRail.observeField("itemSelected", "onNavItemSelected")

    if m.homeRows <> invalid then
        m.homeRows.observeField("rowItemSelected", "onRowItemSelected")
        m.homeRows.observeField("rowItemFocused", "onRowItemFocused")
    end if

    if m.playBtnBg <> invalid then
        m.playBtnBg.observeField("focusedChild", "onHeroButtonFocus")
    end if
    if m.infoBtnBg <> invalid then
        m.infoBtnBg.observeField("focusedChild", "onHeroButtonFocus")
    end if

    if m.clockLabel <> invalid then
        updateClock()
        m.clockTimer = CreateObject("roSGNode", "Timer")
        m.clockTimer.repeat = true
        m.clockTimer.duration = 60
        m.clockTimer.observeField("fire", "updateClock")
        m.top.appendChild(m.clockTimer)
        m.clockTimer.control = "start"
    end if

    showLoading()
    startLoading()
end sub

sub updateClock()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    h = dt.GetHours()
    mn = dt.GetMinutes()
    ap = "AM"
    if h >= 12 then ap = "PM"
    dh = h mod 12
    if dh = 0 then dh = 12
    ms = mn.ToStr()
    if mn < 10 then ms = "0" + ms
    m.clockLabel.text = dh.ToStr() + ":" + ms + " " + ap
end sub

sub showLoading()
    if m.loadingLabel <> invalid then
        m.loadingLabel.visible = true
        m.loadingLabel.text = "Loading..."
    end if
end sub

sub hideLoading()
    if m.loadingLabel <> invalid then m.loadingLabel.visible = false
end sub

sub startLoading()
    userId = session.user.GetId()
    if userId = "" then
        m.loadTimer = CreateObject("roSGNode", "Timer")
        m.loadTimer.duration = 0.5
        m.loadTimer.observeField("fire", "startLoading")
        m.top.appendChild(m.loadTimer)
        m.loadTimer.control = "start"
        return
    end if

    m.userId = userId
    m.pendingSections = 5

    launchOneTask("hero")
    launchOneTask("resume")
    launchOneTask("nextup")
    launchOneTask("latestmedia")
    launchOneTask("favorites")
end sub

sub launchOneTask(ftype as String)
    task = CreateObject("roSGNode", "LoadItemsTask")
    task.itemsToLoad = ftype
    task.userId = m.userId
    task.observeField("loadStatus", "onSectionLoaded")
    m.top.appendChild(task)
    task.control = "RUN"
    m.sectionTasks.Push(task)
end sub

sub onSectionLoaded(event as Object)
    task = event.getRoSGNode()
    ? "[onSectionLoaded] loadStatus="; task.loadStatus; " itemsToLoad="; task.itemsToLoad
    if task.loadStatus = "loaded" and task.loadedItems <> invalid then
        items = task.loadedItems
        st = task.itemsToLoad

        if st = "hero" and items.Count() > 0 then
            m.heroItems = items
            setHeroItem(items[0])
        else if items.Count() > 0 then
            rowTitle = ""
            if st = "resume" then rowTitle = "Continue Watching"
            if st = "nextup" then rowTitle = "Next Up"
            if st = "latestmedia" then rowTitle = "Recently Added"
            if st = "favorites" then rowTitle = "Favorites"
            if rowTitle <> "" then m.pendingRows.Push({ title: rowTitle, rowType: st, items: items })
        end if
    end if

    m.pendingSections = m.pendingSections - 1
    ? "[onSectionLoaded] pendingSections="; m.pendingSections
    if m.pendingSections <= 0 then finishLoading()
end sub

sub setHeroItem(item as Object)
    if item = invalid then return

    backdrop = ""
    if item.backdropURL <> invalid and item.backdropURL <> "" then
        backdrop = item.backdropURL
    else if item.PosterUrl <> invalid and item.PosterUrl <> "" then
        backdrop = item.PosterUrl
    else if item.HDPosterUrl <> invalid and item.HDPosterUrl <> "" then
        backdrop = item.HDPosterUrl
    else if item.Id <> invalid and item.Id <> "" then
        backdrop = BackdropImageURL(item.Id)
    end if
    if backdrop <> "" and m.heroBackdrop <> invalid then m.heroBackdrop.uri = backdrop

    title = ""
    if item.title <> invalid and item.title <> "" then title = item.title
    if title = "" and item.Name <> invalid and item.Name <> "" then title = item.Name
    if m.heroTitle <> invalid then m.heroTitle.text = title

    subtitle = ""
    if item.SeriesName <> invalid and item.SeriesName <> "" then
        subtitle = item.SeriesName
        if item.ParentIndexNumber <> invalid then subtitle = subtitle + " S" + item.ParentIndexNumber.ToStr()
        if item.IndexNumber <> invalid then subtitle = subtitle + " E" + item.IndexNumber.ToStr()
    end if
    if m.heroSubtitle <> invalid then m.heroSubtitle.text = subtitle

    metaParts = []
    if item.type <> invalid and item.type <> "" then metaParts.Push(item.type)
    if item.Type <> invalid and item.Type <> "" then metaParts.Push(item.Type)
    if item.dateAdded <> invalid and item.dateAdded <> "" then metaParts.Push(item.dateAdded)
    metaStr = ""
    for each p in metaParts
        if metaStr <> "" then metaStr = metaStr + "  "
        metaStr = metaStr + p
    end for
    if m.heroMeta <> invalid then m.heroMeta.text = metaStr

    desc = ""
    if item.description <> invalid and item.description <> "" then desc = item.description
    if desc = "" and item.Overview <> invalid and item.Overview <> "" then desc = item.Overview
    if m.heroDescription <> invalid then m.heroDescription.text = desc
end sub

function getCurrentHeroItem() as Object
    if m.heroItems <> invalid and m.heroItems.Count() > 0 then
        item = m.heroItems[0]
        ' Normalize to lowercase fields for HandleItemSelection compatibility
        itemId = ""
        if item.hasField("Id") then itemId = item.Id
        if itemId = "" and item.hasField("id") then itemId = item.id
        itemType = ""
        if item.hasField("Type") then itemType = item.Type
        if itemType = "" and item.hasField("type") then itemType = item.type
        title = ""
        if item.hasField("Name") then title = item.Name
        if title = "" and item.hasField("title") then title = item.title
        overview = ""
        if item.hasField("Overview") then overview = item.Overview
        if overview = "" and item.hasField("description") then overview = item.description
        return {
            id: itemId
            type: itemType
            title: title
            Name: title
            Overview: overview
            json: item
        }
    end if
    if m.homeRows <> invalid then
        rc = m.homeRows.rowItemFocused
        if rc <> invalid and rc.Count() >= 2 then
            content = m.homeRows.content
            if content <> invalid then
                row = content.GetChild(rc[0])
                if row <> invalid then
                    item = row.GetChild(rc[1])
                    if item <> invalid then
                        itemJson = {}
                        if item.hasField("json") then itemJson = item.json
                        itemType = ""
                        if itemJson.DoesExist("Type") then itemType = itemJson.Type
                        overview = ""
                        if itemJson.DoesExist("Overview") then overview = itemJson.Overview
                        return {
                            id: item.id
                            title: item.title
                            Name: item.title
                            type: itemType
                            Overview: overview
                            json: itemJson
                        }
                    end if
                end if
            end if
        end if
    end if
    return invalid
end function

sub finishLoading()
    ? "[finishLoading] ENTER, pendingRows="; m.pendingRows.Count()
    hideLoading()

    if m.pendingRows.Count() = 0 then
        ? "[finishLoading] no pending rows, showing error"
        if m.errorGroup <> invalid then m.errorGroup.visible = true
        return
    end if

    content = CreateObject("roSGNode", "ContentNode")
    for each rowData in m.pendingRows
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
            if img <> invalid and img.url <> "" then
                child.HDPosterUrl = img.url
                child.SDPosterUrl = img.url
            end if
        end for
    end for

    ? "[finishLoading] content rows="; content.GetChildCount()
    if m.homeRows <> invalid then
        m.homeRows.content = content
        m.homeRows.numRows = content.GetChildCount()
        m.homeRows.setFocus(true)
        ? "[finishLoading] homeRows set, focus=true"
    end if
end sub

sub setHeroButtonFocus(index as Integer)
    if m.playBtnBg = invalid or m.infoBtnBg = invalid then return
    m.heroButtonIndex = index
    m.heroButtonFocused = true
    if index = 0 then
        m.playBtnBg.color = "0x14B4E8FF"
        m.infoBtnBg.color = "0x33333380"
        m.playBtnBg.setFocus(true)
    else
        m.playBtnBg.color = "0x33333380"
        m.infoBtnBg.color = "0x14B4E8FF"
        m.infoBtnBg.setFocus(true)
    end if
end sub

sub clearHeroButtonFocus()
    if m.playBtnBg = invalid or m.infoBtnBg = invalid then return
    m.heroButtonFocused = false
    m.playBtnBg.color = "0x14B4E8FF"
    m.infoBtnBg.color = "0x33333380"
end sub

sub onHeroButtonFocus()
    ' Visual focus is handled by setHeroButtonFocus via color change
end sub

sub onNavItemSelected(event as Object)
    id = event.getData()
    if id = invalid or id = "" then return
    if id = "home" then ClearAllScenes() : CreateHomeGroup()
    if id = "search" then CreateSearchPage()
    if id = "settings" or id = "profile" then CreateSettingsScreen()
    if id = "favorites" then openVisualLibrary("", "Favorites", "IsFavorite")
    if id = "movies" then openVisualLibrary("", "Movies", "", "Movies")
    if id = "tv" then openVisualLibrary("", "TV Shows", "", "Series")
    if id = "playlists" then openVisualLibrary("", "Playlists", "", "Playlists")
    if id = "library" then openVisualLibrary("", "Library", "")
end sub

sub openVisualLibrary(libId as String, title as String, filters as String, mediaType = "" as String)
    n = CreateObject("roSGNode", "ContentNode")
    n.id = libId
    n.title = title
    if filters <> "" then n.AddFields({ filters: filters })
    CreateVisualLibraryScene(n, mediaType)
end sub

sub onRowItemSelected(event as Object)
    rowCol = event.getData()
    content = m.homeRows.content
    if content = invalid then return
    row = content.GetChild(rowCol[0])
    if row = invalid then return
    item = row.GetChild(rowCol[1])
    if item = invalid then return

    ' Convert ContentNode to AA for HandleItemSelection (chainLookup doesn't work on ContentNode)
    itemJson = {}
    if item.hasField("json") then itemJson = item.json
    itemType = ""
    if item.hasField("type") then itemType = item.type
    itemId = ""
    if item.hasField("id") then itemId = item.id
    seriesId = ""
    if itemJson.DoesExist("SeriesId") then seriesId = itemJson.SeriesId

    itemAA = {
        id: itemId
        type: itemType
        title: item.title
        Name: item.title
        json: itemJson
        seriesId: seriesId
    }
    HandleItemSelection(m.homeRows.id, itemAA)
end sub

sub onRowItemFocused(event as Object)
    rowCol = event.getData()
    content = m.homeRows.content
    if content = invalid then return
    row = content.GetChild(rowCol[0])
    if row = invalid then return
    item = row.GetChild(rowCol[1])
    if item = invalid then return

    ' Direct field access (chainLookupReturn doesn't work on ContentNode)
    itemJson = {}
    if item.hasField("json") then itemJson = item.json

    overview = ""
    if itemJson.DoesExist("Overview") then overview = itemJson.Overview
    itemType = ""
    if itemJson.DoesExist("Type") then itemType = itemJson.Type
    seriesName = ""
    if itemJson.DoesExist("SeriesName") then seriesName = itemJson.SeriesName
    episodeTitle = ""
    if itemJson.DoesExist("Name") then episodeTitle = itemJson.Name
    parentIndex = invalid
    if itemJson.DoesExist("ParentIndexNumber") then parentIndex = itemJson.ParentIndexNumber
    indexNumber = invalid
    if itemJson.DoesExist("IndexNumber") then indexNumber = itemJson.IndexNumber
    dateAdded = ""
    if itemJson.DoesExist("DateAdded") then dateAdded = itemJson.DateAdded

    heroData = {
        id: item.id
        title: item.title
        Name: item.title
        description: overview
        Overview: overview
        type: itemType
        SeriesName: seriesName
        episodeTitle: episodeTitle
        ParentIndexNumber: parentIndex
        IndexNumber: indexNumber
        dateAdded: dateAdded
        backdropURL: BackdropImageURL(item.id)
        HDPosterUrl: item.HDPosterUrl
    }
    setHeroItem(heroData)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "back" then return false

    if m.heroButtonFocused then
        if key = "down" then
            clearHeroButtonFocus()
            if m.homeRows <> invalid then m.homeRows.setFocus(true)
            return true
        end if
        if key = "left" then
            if m.heroButtonIndex = 1 then
                setHeroButtonFocus(0)
                return true
            end if
        end if
        if key = "right" then
            if m.heroButtonIndex = 0 then
                setHeroButtonFocus(1)
                return true
            end if
        end if
        if key = "OK" then
            item = getCurrentHeroItem()
            if item <> invalid then
                if m.heroButtonIndex = 0 then
                    HandleItemSelection(m.top.id, item)
                else
                    itemType = chainLookupReturn(item, ["type"], "")
                    itemId = chainLookupReturn(item, ["id"], "")
                    if itemType = "Episode" or itemType = "Series" then
                        CreateSeriesDetailsGroup(itemId)
                    else
                        CreateMovieDetailsGroup(item)
                    end if
                end if
            end if
            return true
        end if
        return false
    end if

    if key = "left" then
        rc = m.homeRows.rowItemFocused
        if rc <> invalid and rc.Count() >= 2 and rc[1] = 0 then
            m.navRail.setFocus(true)
            return true
        end if
    end if
    if key = "right" then
        m.homeRows.setFocus(true)
        return true
    end if
    if key = "up" then
        rc = m.homeRows.rowItemFocused
        if rc <> invalid and rc.Count() >= 2 and rc[0] = 0 then
            setHeroButtonFocus(0)
            return true
        end if
    end if
    return false
end function