' ============================================================
' HomeScene.brs
' Lifecycle + data wiring for the home screen.
' Focus/key-handling lives in HomeSceneFocus.brs (kept separate
' so this file stays readable as the data/layout logic grows).
' ============================================================

sub init()
    m.heroBackdrop    = m.top.findNode("heroBackdrop")
    m.heroTitle       = m.top.findNode("heroTitle")
    m.heroSubtitle    = m.top.findNode("heroSubtitle")
    m.heroMeta        = m.top.findNode("heroMeta")
    m.heroDescription = m.top.findNode("heroDescription")
    m.clockLabel      = m.top.findNode("clockLabel")
    m.navRail         = m.top.findNode("navRail")
    m.contentRows     = m.top.findNode("contentRows")

    ' Track which zone owns focus: "nav" or "rows"
    m.focusZone = "rows"

    setupClock()
    loadHomeData()

    ' Whenever the focused row/item changes, refresh the hero banner.
    m.contentRows.observeField("rowItemFocused", "onRowItemFocused")
    m.contentRows.observeField("rowItemSelected", "onRowItemSelected")

    m.top.setFocus(true)
    m.contentRows.setFocus(true)
end sub

' ------------------------------------------------------------
' Clock: update every 30s via roDateTime
' ------------------------------------------------------------
sub setupClock()
    m.clockTimer = CreateObject("roSGNode", "Timer")
    m.clockTimer.repeat = true
    m.clockTimer.duration = 30
    m.clockTimer.observeField("fire", "updateClock")
    m.clockTimer.control = "start"
    updateClock()
end sub

sub updateClock()
    dt = CreateObject("roDateTime")
    dt.ToLocalTime()
    hour = dt.GetHours()
    ampm = "AM"
    if hour >= 12 then ampm = "PM"
    displayHour = hour mod 12
    if displayHour = 0 then displayHour = 12
    minute = dt.GetMinutes()
    minuteStr = minute.ToStr()
    if minute < 10 then minuteStr = "0" + minuteStr
    m.clockLabel.text = displayHour.ToStr() + ":" + minuteStr + " " + ampm
end sub

' ------------------------------------------------------------
' Data loading — replace loadHomeData's guts with your real
' Jellyfin/backend API calls. This just wires the shape of the
' ContentNode tree RowList expects.
' ------------------------------------------------------------
sub loadHomeData()
    rowsContent = CreateObject("roSGNode", "ContentNode")

    ' Row 0: Next Up (episodes, 16:9, with E# badge)
    nextUpRow = rowsContent.CreateChild("ContentNode")
    nextUpRow.title = "Next Up"
    appendEpisodeItem(nextUpRow, "My Hero Academia", "pkg:/images/mha_thumb.jpg", 1)
    appendEpisodeItem(nextUpRow, "Teen Titans Go!", "pkg:/images/ttg_thumb.jpg", 2)
    appendEpisodeItem(nextUpRow, "Rascal Does Not Dream of Bunny Girl Senpai", "pkg:/images/rascal_thumb.jpg", 3)
    appendEpisodeItem(nextUpRow, "The Fragrant Flower Blooms With Dignity", "pkg:/images/flower_thumb.jpg", 1)

    ' Row 1: Recently added in Anime Movies (posters, 2:3)
    animeRow = rowsContent.CreateChild("ContentNode")
    animeRow.title = "Recently added in Anime Movies"
    appendPosterItem(animeRow, "My Hero Academia: Heroes Rising", "pkg:/images/poster1.jpg")
    appendPosterItem(animeRow, "One Piece Film: Red", "pkg:/images/poster2.jpg")
    appendPosterItem(animeRow, "Violet Evergarden", "pkg:/images/poster3.jpg")

    m.contentRows.content = rowsContent

    ' Seed the hero with the first item so it's not blank before focus fires
    if nextUpRow.getChildCount() > 0
        updateHeroFromItem(nextUpRow.getChild(0))
    end if
end sub

sub appendEpisodeItem(parentRow as object, title as string, thumbUri as string, episodeNum as integer)
    item = parentRow.CreateChild("ContentNode")
    item.title = title
    item.HDPosterUrl = thumbUri
    item.AddFields({ episodeNumber: episodeNum, aspect: "16x9" })
end sub

sub appendPosterItem(parentRow as object, title as string, posterUri as string)
    item = parentRow.CreateChild("ContentNode")
    item.title = title
    item.HDPosterUrl = posterUri
    item.AddFields({ aspect: "2x3" })
end sub

' ------------------------------------------------------------
' Hero banner updates when the focused row item changes.
' rowItemFocused is a 2-element array: [rowIndex, itemIndex]
' ------------------------------------------------------------
sub onRowItemFocused(event as object)
    indices = event.getData()
    rowIndex = indices[0]
    itemIndex = indices[1]

    row = m.contentRows.content.getChild(rowIndex)
    if row = invalid then return
    item = row.getChild(itemIndex)
    if item = invalid then return

    updateHeroFromItem(item)
end sub

sub updateHeroFromItem(item as object)
    m.heroTitle.text = item.title

    if item.hasField("episodeNumber")
        m.heroSubtitle.text = "Episode " + item.episodeNumber.ToStr()
        m.heroMeta.text = "" ' fill with season/date/runtime once your API supplies it
    else
        m.heroSubtitle.text = ""
        m.heroMeta.text = ""
    end if

    m.heroDescription.text = item.description
    ' Swap to a real backdrop/fanart field once available; falling back to poster for now
    m.heroBackdrop.uri = item.HDPosterUrl
end sub

sub onRowItemSelected(event as object)
    indices = event.getData()
    rowIndex = indices[0]
    itemIndex = indices[1]
    row = m.contentRows.content.getChild(rowIndex)
    item = row.getChild(itemIndex)

    if rowIndex = 0
        ' Next Up row -> play directly
        playItem(item)
    else
        ' Poster rows -> open details screen
        showDetails(item)
    end if
end sub

sub playItem(item as object)
    ' TODO: push a VideoScene / hand off to your player component
    print "Play requested: "; item.title
end sub

sub showDetails(item as object)
    ' TODO: push a DetailsScene component
    print "Details requested: "; item.title
end sub
