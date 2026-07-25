sub Init()
    m.poster = m.top.findNode("itemPoster")
    m.episodeLabel = m.top.findNode("episodeLabel")
    m.focusBorder = m.top.findNode("focusBorder")

    m.top.observeField("itemContent", "onItemContentChange")
    m.top.observeField("focusedChild", "onFocusChange")

    m.baseScale = [1.0, 1.0]
    m.focusedScale = [1.05, 1.05]
end sub

sub onFocusChange()
    hasFocus = m.top.hasFocus()
    if m.focusBorder <> invalid then
        m.focusBorder.visible = hasFocus
    end if
    if hasFocus then
        m.top.scale = m.focusedScale
    else
        m.top.scale = m.baseScale
    end if
end sub

sub onItemContentChange()
    content = m.top.itemContent
    if content = invalid then return

    url = content.HDPosterUrl
    if url <> invalid and url <> "" then
        m.poster.uri = url
    end if

    title = content.title
    if title = invalid then title = ""
    m.top.itemTitle = title

    index = 0
    if content.hasField("indexNumber") and content.indexNumber <> invalid then
        index = content.indexNumber
    end if
    if index > 0 then
        m.top.episodeIndex = index
        m.episodeLabel.text = "E" + index.ToStr()
    else
        m.episodeLabel.text = ""
    end if
end sub
