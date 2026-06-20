sub Init()
    m.navBg = m.top.findNode("navBg")
    m.navItemsGroup = m.top.findNode("navItemsGroup")
    
    m.navData = [
        { label: "Home",     id: "home" }
        { label: "Search",   id: "search" }
        { label: "Favorites",id: "favorites" }
        { label: "Movies",   id: "movies" }
        { label: "Shows",    id: "tvshows" }
        { label: "Continue", id: "continue" }
        { label: "Playlists",id: "playlists" }
        { label: "Settings", id: "settings" }
    ]
    
    buildNavItems()
    
    m.top.selectedIndex = 0
    updateSelection()
    
    m.top.observeField("selectedIndex", "onSelectedIndexChange")
end sub

sub buildNavItems()
    m.navButtons = []
    for i = 0 to m.navData.Count() - 1
        itemData = m.navData[i]
        
        btnGroup = m.navItemsGroup.appendChild(CreateObject("roSGNode", "Group"))
        btnGroup.translation = [0, i * 72]
        btnGroup.id = "navBtn_" + i.ToStr()
        
        label = btnGroup.appendChild(CreateObject("roSGNode", "Label"))
        label.id = "label"
        label.text = itemData.label
        label.font = "font:SmallSystemFont"
        label.color = "0x999999FF"
        label.width = 96
        label.height = 72
        label.translation = [0, 0]
        label.horizAlign = "center"
        label.vertAlign = "center"
        
        focusRing = btnGroup.appendChild(CreateObject("roSGNode", "Rectangle"))
        focusRing.id = "focusRing"
        focusRing.width = 80
        focusRing.height = 56
        focusRing.translation = [8, 8]
        focusRing.color = "0x00A4DC40"
        focusRing.visible = false
        
        btnGroup.navIndex = i
        btnGroup.navId = itemData.id
        m.navButtons.Push(btnGroup)
    end for
end sub

sub onSelectedIndexChange()
    updateSelection()
end sub

sub updateSelection()
    idx = m.top.selectedIndex
    if idx < 0 or idx >= m.navButtons.Count() then return
    
    activeBg = m.top.findNode("activeIndicator")
    targetY = 120 + idx * 72
    if activeBg <> invalid then
        activeBg.translation = [92, targetY]
        activeBg.opacity = 1.0
    end if
    
    for i = 0 to m.navButtons.Count() - 1
        btn = m.navButtons[i]
        label = btn.findNode("label")
        focusRing = btn.findNode("focusRing")
        
        if i = idx then
            label.color = "0xFFFFFFFF"
            if focusRing <> invalid then focusRing.visible = true
        else
            label.color = "0x999999FF"
            if focusRing <> invalid then focusRing.visible = false
        end if
    end for
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false
    
    idx = m.top.selectedIndex
    
    if key = "up" then
        if idx > 0 then
            m.top.selectedIndex = idx - 1
            return true
        end if
    else if key = "down" then
        if idx < m.navButtons.Count() - 1 then
            m.top.selectedIndex = idx + 1
            return true
        end if
    else if key = "right" then
        return false
    else if key = "OK" then
        return true
    end if
    
    return false
end function