' ============================================================
' NavRail.brs
' Icons in order top-to-bottom. Roku doesn't auto-highlight
' custom Group nodes on focus, so we track index ourselves and
' toggle each item's "_hl" Rectangle's visible field by hand.
' ============================================================

sub init()
    m.itemIds = [
        "nav_profile", "nav_search", "nav_home", "nav_favorites",
        "nav_movies", "nav_tv", "nav_playlists", "nav_settings"
    ]
    m.currentIndex = 2 ' default focus = Home, matches screenshot's active state

    m.top.observeField("focusedChild", "onFocusReceived")
    setHighlight(m.currentIndex, true)
end sub

sub onFocusReceived()
    ' no-op placeholder; kept in case you want an entry animation
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
    id = m.itemIds[index]
    hl = m.top.findNode(id + "_hl")
    if hl <> invalid then hl.visible = on
end sub
