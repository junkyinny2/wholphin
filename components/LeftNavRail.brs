sub Init()
    m.navBg = m.top.findNode("navBg")
    m.navItemsGroup = m.top.findNode("navItemsGroup")
    m.activeIndicator = m.top.findNode("activeIndicator")

    m.navData = [
        { label: "Home",     icon: "pkg:/images/icons/nav_home.png",     id: "home" }
        { label: "Search",   icon: "pkg:/images/icons/nav_search.png",   id: "search" }
        { label: "Library",  icon: "pkg:/images/icons/nav_library.png",  id: "library" }
        { label: "Favorites",icon: "pkg:/images/icons/nav_favorites.png",id: "favorites" }
        { label: "TV",       icon: "pkg:/images/icons/nav_tv.png",       id: "tv" }
        { label: "Movies",   icon: "pkg:/images/icons/nav_movies.png",  id: "movies" }
        { label: "Collection",icon: "pkg:/images/icons/nav_collection.png",id: "collection" }
        { label: "Playlist", icon: "pkg:/images/icons/nav_playlist.png", id: "playlist" }
        { label: "Cast",     icon: "pkg:/images/icons/nav_cast.png",     id: "cast" }
        { label: "Settings", icon: "pkg:/images/icons/nav_settings.png", id: "settings" }
    ]

    m.navButtons = []
    iconSize = 36
    itemHeight = 56
    yOffset = 0

    for i = 0 to m.navData.Count() - 1
        itemData = m.navData[i]

        btnGroup = CreateObject("roSGNode", "Group")
        btnGroup.translation = [22, yOffset]
        btnGroup.id = "navBtn_" + i.ToStr()

        iconPoster = CreateObject("roSGNode", "Poster")
        iconPoster.id = "iconPoster"
        iconPoster.uri = itemData.icon
        iconPoster.width = iconSize
        iconPoster.height = iconSize
        iconPoster.translation = [0, 0]
        iconPoster.loadDisplayMode = "scaleToFit"

        btnGroup.appendChild(iconPoster)

        m.navItemsGroup.appendChild(btnGroup)
        m.navButtons.Push(btnGroup)
        yOffset = yOffset + itemHeight
    end for

    m.top.selectedIndex = 0
    updateSelection()
    m.top.observeField("selectedIndex", "onSelectedIndexChange")
end sub

sub onSelectedIndexChange()
    updateSelection()
end sub

sub updateSelection()
    idx = m.top.selectedIndex
    if idx < 0 or idx >= m.navButtons.Count() then return

    targetY = 80 + idx * 56 + 10
    m.activeIndicator.translation = [77, targetY]
    m.activeIndicator.opacity = 1

    for i = 0 to m.navButtons.Count() - 1
        btn = m.navButtons[i]
        iconPoster = btn.findNode("iconPoster")
        if i = idx then
            iconPoster.blendColor = "0x22D3EEFF"
        else
            iconPoster.blendColor = "0xB0B8C4AA"
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    idx = m.top.selectedIndex

    if key = "up" then
        if idx > 0 then
            m.top.selectedIndex = idx - 1
        end if
        return true
    else if key = "down" then
        if idx < m.navButtons.Count() - 1 then
            m.top.selectedIndex = idx + 1
        end if
        return true
    else if key = "right" then
        return false
    else if key = "OK" then
        itemData = m.navData[idx]
        m.top.onItemSelected = itemData.id
        return true
    end if
    return false
end function
