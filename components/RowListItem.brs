sub init()
    m.posterContainer = m.top.findNode("posterContainer")
    m.thumb            = m.top.findNode("thumb")
    m.episodeBadgeBg    = m.top.findNode("episodeBadgeBg")
    m.episodeBadgeLabel = m.top.findNode("episodeBadgeLabel")
    m.focusRing         = m.top.findNode("focusRing")
end sub

sub onContentSet()
    content = m.top.itemContent
    if content = invalid then return

    m.thumb.uri = content.HDPosterUrl

    epNum = invalid
    if content.hasField("json") and content.json <> invalid and content.json.DoesExist("EpisodeNumber") then
        epNum = content.json.EpisodeNumber
    end if
    if epNum = invalid and content.hasField("episodeNumber") then
        epNum = content.episodeNumber
    end if

    showBadge = (epNum <> invalid and epNum.ToStr() <> "")
    if showBadge then
        m.episodeBadgeLabel.text = "E" + epNum.ToStr()
    end if
    m.episodeBadgeBg.visible = showBadge
    m.episodeBadgeLabel.visible = showBadge
end sub

sub onSizeChanged()
    w = m.top.width
    h = m.top.height
    if w = invalid or h = invalid then return

    m.thumb.width = w
    m.thumb.height = h

    if m.posterContainer <> invalid then
        if m.posterContainer.hasField("width") then m.posterContainer.width = w
        if m.posterContainer.hasField("height") then m.posterContainer.height = h
        if m.posterContainer.hasField("clipRect") then m.posterContainer.clipRect = [0, 0, w, h]
    end if

    m.episodeBadgeBg.translation = [w - 40, 6]
    m.episodeBadgeLabel.translation = [w - 33, 10]

    m.focusRing.width = w + 4
    m.focusRing.height = h + 4
    m.focusRing.translation = [-2, -2]
end sub

sub onFocusChanged()
    hasFocus = m.top.itemHasFocus and m.top.rowListHasFocus
    m.focusRing.visible = hasFocus
    if hasFocus
        m.top.setFields({ scale: [1.06, 1.06] })
    else
        m.top.setFields({ scale: [1.0, 1.0] })
    end if
end sub
