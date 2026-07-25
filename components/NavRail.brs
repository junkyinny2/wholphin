sub init()
    m.itemIds = ["profile", "search", "home", "favorites", "movies", "tv", "playlists", "settings"]
    m.currentIndex = 2

    m.top.observeField("focusedChild", "onFocusReceived")
    setHighlight(m.currentIndex, true)
end sub

sub onFocusReceived()
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
        if m.currentIndex < m.itemIds.count() - 1
            setHighlight(m.currentIndex, false)
            m.currentIndex++
            setHighlight(m.currentIndex, true)
        end if
        handled = true
    else if key = "OK"
        m.top.itemSelected = m.itemIds[m.currentIndex]
        handled = true
    end if

    return handled
end function

sub setHighlight(index as integer, on as boolean)
    id = "nav_" + m.itemIds[index]
    hl = m.top.findNode(id + "_hl")
    if hl <> invalid then hl.visible = on
end sub
