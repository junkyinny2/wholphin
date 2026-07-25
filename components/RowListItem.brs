sub init()
    m.thumb            = m.top.findNode("thumb")
    m.episodeBadgeBg    = m.top.findNode("episodeBadgeBg")
    m.episodeBadgeLabel = m.top.findNode("episodeBadgeLabel")
    m.focusRing         = m.top.findNode("focusRing")
end sub

sub onContentSet()
    content = m.top.itemContent
    if content = invalid then return

    m.thumb.uri = content.HDPosterUrl

    if content.hasField("episodeNumber")
        m.episodeBadgeLabel.text = "E" + content.episodeNumber.ToStr()
        m.episodeBadgeBg.visible = true
        m.episodeBadgeLabel.visible = true
    else
        m.episodeBadgeBg.visible = false
        m.episodeBadgeLabel.visible = false
    end if
end sub

sub onSizeChanged()
    w = m.top.width
    h = m.top.height
    if w = invalid or h = invalid then return

    m.thumb.width = w
    m.thumb.height = h

    m.episodeBadgeBg.translation = [w - 40, 6]
    m.episodeBadgeLabel.translation = [w - 33, 10]

    m.focusRing.width = w
    m.focusRing.height = h
end sub

sub onFocusChanged()
    hasFocus = m.top.rowListHasFocus and m.top.rowFocusPercent > 0.5
    m.focusRing.visible = hasFocus
    if hasFocus
        m.top.setFields({ scale: [1.06, 1.06] })
    else
        m.top.setFields({ scale: [1.0, 1.0] })
    end if
end sub
