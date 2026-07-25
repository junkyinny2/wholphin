sub Init()
    m.heroBackdrop = m.top.findNode("heroBackdrop")
    m.heroClock = m.top.findNode("heroClock")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroEpisodeTitle = m.top.findNode("heroEpisodeTitle")
    m.heroMetadata = m.top.findNode("heroMetadata")
    m.heroDescription = m.top.findNode("heroDescription")

    m.top.observeField("heroItem", "onHeroItemChange")
    m.top.observeField("heroItems", "onHeroItemsChange")

    m.btnPlay = m.top.findNode("btnPlay")
    m.btnMoreInfo = m.top.findNode("btnMoreInfo")
    m.btnPlay.observeField("buttonSelected", "onPlaySelected")
    m.btnMoreInfo.observeField("buttonSelected", "onMoreInfoSelected")

    m.rotateIndex = 0
    m.rotateTimer = CreateObject("roSGNode", "Timer")
    m.rotateTimer.duration = 8
    m.rotateTimer.repeat = true
    m.rotateTimer.observeField("fire", "onRotateTimer")
    m.top.appendChild(m.rotateTimer)

    updateClock()
    m.clockTimer = CreateObject("roSGNode", "Timer")
    m.clockTimer.duration = 60
    m.clockTimer.repeat = true
    m.clockTimer.observeField("fire", "updateClock")
    m.top.appendChild(m.clockTimer)
    m.clockTimer.control = "start"
end sub

sub updateClock()
    now = CreateObject("roDateTime")
    hours = now.GetHours()
    minutes = now.GetMinutes()
    amPm = "AM"
    if hours >= 12 then
        amPm = "PM"
        if hours > 12 then hours = hours - 12
    end if
    if hours = 0 then hours = 12
    timeStr = hours.ToStr() + ":" + rightPad(minutes.ToStr(), 2, "0") + " " + amPm
    m.heroClock.text = timeStr
end sub

function rightPad(str as String, len as Integer, padChar as String) as String
    while Len(str) < len
        str = padChar + str
    end while
    return str
end function

sub onHeroItemsChange()
    items = m.top.heroItems
    if items = invalid or items.Count() = 0 then
        m.rotateTimer.control = "stop"
        return
    end if
    m.rotateIndex = 0
    m.rotateTimer.control = "start"
end sub

sub onRotateTimer()
    items = m.top.heroItems
    if items = invalid or items.Count() = 0 then return
    if items.Count() = 1 then
        m.rotateTimer.control = "stop"
        return
    end if
    m.rotateIndex = (m.rotateIndex + 1) Mod items.Count()
    m.top.heroItem = items[m.rotateIndex]
end sub

function getCurrentHeroItem() as Object
    items = m.top.heroItems
    if items <> invalid and items.Count() > 0 then
        idx = m.rotateIndex
        if idx >= 0 and idx < items.Count() then return items[idx]
    end if
    return m.top.heroItem
end function

sub onPlaySelected(event as Object)
    item = getCurrentHeroItem()
    if item = invalid then return
    HandleItemSelection(m.top.id, item)
end sub

sub onMoreInfoSelected(event as Object)
    item = getCurrentHeroItem()
    if item = invalid then return
    itemType = chainLookupReturn(item, ["type"], "")
    id = chainLookupReturn(item, ["id"], "")
    if id = "" then id = chainLookupReturn(item, ["Id"], "")
    if itemType = "Episode" or itemType = "Series" then
        CreateSeriesDetailsGroup(id)
    else
        CreateMovieDetailsGroup(item)
    end if
end sub

sub onHeroItemChange()
    item = m.top.heroItem
    if item = invalid then return

    backdropUrl = ""
    if item.backdropURL <> invalid and item.backdropURL <> "" then
        backdropUrl = item.backdropURL
    else if item.PosterUrl <> invalid and item.PosterUrl <> "" then
        backdropUrl = item.PosterUrl
    else if item.HDPosterUrl <> invalid and item.HDPosterUrl <> "" then
        backdropUrl = item.HDPosterUrl
    else if item.id <> invalid and item.id <> "" then
        backdropUrl = BackdropImageURL(item.id)
    end if

    if backdropUrl <> "" then
        m.heroBackdrop.uri = backdropUrl
    end if

    title = ""
    if item.title <> invalid and item.title <> "" then
        title = item.title
    else if item.Name <> invalid and item.Name <> "" then
        title = item.Name
    end if
    m.heroTitle.text = title

    episodeTitle = ""
    if item.episodeTitle <> invalid and item.episodeTitle <> "" then
        episodeTitle = item.episodeTitle
    else if item.SeriesName <> invalid and item.SeriesName <> "" then
        episodeTitle = item.SeriesName
        if item.ParentIndexNumber <> invalid and item.IndexNumber <> invalid then
            episodeTitle = episodeTitle + " • S" + item.ParentIndexNumber.ToStr() + " E" + item.IndexNumber.ToStr()
        end if
    end if
    m.heroEpisodeTitle.text = episodeTitle

    metadataParts = []
    if item.type <> invalid and item.type <> "" then
        metadataParts.Push(item.type)
    end if
    if item.dateAdded <> invalid and item.dateAdded <> "" then
        metadataParts.Push(item.dateAdded)
    end if
    metadataStr = ""
    for each part in metadataParts
        if metadataStr <> "" then metadataStr = metadataStr + " • "
        metadataStr = metadataStr + part
    end for
    m.heroMetadata.text = metadataStr

    desc = ""
    if item.description <> invalid and item.description <> "" then
        desc = item.description
    else if item.Overview <> invalid and item.Overview <> "" then
        desc = item.Overview
    end if
    m.heroDescription.text = desc
end sub
