' Wholphin Roku - Main Scene
' Handles top tabs, poster rows, action bar, focus navigation

sub Init()
    m.tabList = m.top.findNode("tabList")
    m.posterRowList = m.top.findNode("posterRowList")
    m.actionBar = m.top.findNode("actionBar")
    m.background = m.top.findNode("background")
    m.detailsGroup = m.top.findNode("detailsGroup")
    m.detailsPanel = m.top.findNode("detailsPanel")

    m.currentTab = "home"
    m.currentRow = 0
    m.currentCol = 0
    m.focusTarget = "rows"

    ' Set tab content
    tabData = [
        { text: "Home" }
        { text: "Movies" }
        { text: "TV Shows" }
        { text: "Continue Watching" }
        { text: "Settings" }
    ]

    content = CreateObject("roSGNode", "ContentNode")
    for each tabItem in tabData
        child = content.CreateChild("ContentNode")
        child.title = tabItem.text
    end for
    m.tabList.content = content

    ' Set action bar icons
    actionData = [
        { hdPosterUrl: "pkg:/images/sort.png" }
        { hdPosterUrl: "pkg:/images/filter.png" }
        { hdPosterUrl: "pkg:/images/view.png" }
    ]
    actionContent = CreateObject("roSGNode", "ContentNode")
    for each action in actionData
        child = actionContent.CreateChild("ContentNode")
        child.hdPosterUrl = action.hdPosterUrl
    end for
    m.actionBar.content = actionContent

    ' Observe field changes
    m.tabList.observeField("itemFocused", m.port)
    m.tabList.observeField("itemSelected", m.port)
    m.posterRowList.observeField("rowItemFocused", m.port)
    m.posterRowList.observeField("rowItemSelected", m.port)
    m.actionBar.observeField("itemFocused", m.port)
    m.actionBar.observeField("itemSelected", m.port)
    m.top.observeField("detailsVisible", m.port)

    ' Set RowList item component
    m.posterRowList.itemComponentName = "PosterRow"

    ' Load initial data
    loadTab("home")

    ' Set initial focus
    m.posterRowList.setFocus(true)
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if m.detailsGroup.visible then
        if key = "back" then
            m.detailsGroup.visible = false
            m.top.detailsVisible = false
            m.focusTarget = "rows"
            m.posterRowList.setFocus(true)
            return true
        end if
        if key = "OK" then
            handleDetailsAction()
            return true
        end if
        return false
    end if

    if key = "up" then
        if m.focusTarget = "rows" then
            if m.posterRowList.rowItemFocused[0] = 0 then
                m.focusTarget = "tabs"
                m.tabList.setFocus(true)
                return true
            end if
        end if
        return false
    end if

    if key = "down" then
        if m.focusTarget = "tabs" then
            m.focusTarget = "rows"
            m.posterRowList.setFocus(true)
            return true
        end if
        return false
    end if

    if key = "right" then
        if m.focusTarget = "rows" then
            if m.posterRowList.rowItemFocused[1] >= getCurrentRowItemCount() - 1 then
                m.focusTarget = "action"
                m.actionBar.setFocus(true)
                return true
            end if
        end if
        return false
    end if

    if key = "left" then
        if m.focusTarget = "action" then
            m.focusTarget = "rows"
            m.posterRowList.setFocus(true)
            return true
        end if
        return false
    end if

    if key = "back" then
        if m.focusTarget = "tabs" then
            m.focusTarget = "rows"
            m.posterRowList.setFocus(true)
            return true
        end if
        return false
    end if

    if key = "OK" then
        if m.focusTarget = "rows" then
            showDetailsForCurrentItem()
            return true
        end if
    end if

    return false
end function

sub onTabFocused()
    index = m.tabList.itemFocused
    tabs = ["home", "movies", "tvshows", "continuewatching", "settings"]
    if index >= 0 and index < tabs.Count() then
        m.currentTab = tabs[index]
        loadTab(m.currentTab)
    end if
end sub

sub onTabSelected()
    ' Tab selected — already loaded on focus
end sub

sub onRowItemFocused()
    row = m.posterRowList.rowItemFocused
    if row.Count() >= 2 then
        m.currentRow = row[0]
        m.currentCol = row[1]
    end if
end sub

sub onRowItemSelected()
    showDetailsForCurrentItem()
end sub

sub onActionFocused()
    ' Action bar item focused - no action needed
end sub

sub onActionSelected()
    index = m.actionBar.itemSelected
    if index = 0 then
        ' Sort
    else if index = 1 then
        ' Filter
    else if index = 2 then
        ' View toggle
    end if
end sub

sub showDetailsForCurrentItem()
    row = m.posterRowList.rowItemSelected
    if row.Count() < 2 then return
    rowIndex = row[0]
    colIndex = row[1]

    content = m.posterRowList.content
    if content = invalid then return
    rowNode = content.GetChild(rowIndex)
    if rowNode = invalid then return
    items = rowNode.GetChild(0)
    if items = invalid then return
    item = items.GetChild(colIndex)
    if item = invalid then return

    details = {
        title: item.title
        year: item.year
        runtime: item.runtime
        description: item.description
        imageUrl: item.hdPosterUrl
        progressPercent: item.progressPercent
        mediaId: item.mediaId
    }
    m.detailsPanel.itemData = details
    m.detailsGroup.visible = true
    m.top.detailsVisible = true
    m.top.currentItem = item
end sub

sub handleDetailsAction()
    buttonId = m.detailsPanel.focusedButton
    if buttonId = 0 then
        ' Play
        item = m.top.currentItem
        if item <> invalid then
            m.top.showPlayback = item
        end if
    else if buttonId = 1 then
        ' Resume
        item = m.top.currentItem
        if item <> invalid then
            item.playbackPosition = item.progressPercent
            m.top.showPlayback = item
        end if
    end if
end sub

function getCurrentRowItemCount() as Integer
    content = m.posterRowList.content
    if content = invalid then return 0
    row = content.GetChild(m.posterRowList.rowItemFocused[0])
    if row = invalid then return 0
    items = row.GetChild(0)
    if items = invalid then return 0
    return items.GetChildCount()
end function

sub loadTab(tabName as String)
    ' Jellyfin API calls would go here
    ' For now, load sample data
    rowsContent = CreateObject("roSGNode", "ContentNode")

    if tabName = "home" then
        rowsContent.appendChild(createRow("Continue Watching", false, 0))
        rowsContent.appendChild(createRow("Latest Movies", true, 0))
        rowsContent.appendChild(createRow("TV Shows", true, 0))
        rowsContent.appendChild(createRow("Recently Added", true, 0))
    else if tabName = "movies" then
        rowsContent.appendChild(createRow("All Movies", true, 0))
        rowsContent.appendChild(createRow("Action", true, 0))
        rowsContent.appendChild(createRow("Comedy", true, 0))
        rowsContent.appendChild(createRow("Drama", true, 0))
    else if tabName = "tvshows" then
        rowsContent.appendChild(createRow("All TV Shows", true, 0))
        rowsContent.appendChild(createRow("Continuing", true, 0))
        rowsContent.appendChild(createRow("New Episodes", true, 0))
    else if tabName = "continuewatching" then
        rowsContent.appendChild(createRow("Continue Watching", false, 0.3))
        rowsContent.appendChild(createRow("Next Up", true, 0))
    else if tabName = "settings" then
        rowsContent.appendChild(createRow("Settings", false, 0))
    end if

    m.posterRowList.content = rowsContent
    m.posterRowList.numRows = rowsContent.GetChildCount()
end sub

function createRow(title as String, hasFullItems as Boolean, progress as Float) as Object
    row = CreateObject("roSGNode", "ContentNode")
    row.title = title
    items = row.CreateChild("ContentNode")

    count = 8
    if not hasFullItems then count = 4

    for i = 1 to count
        item = items.CreateChild("ContentNode")
        item.title = title + " Item " + i.ToStr()
        item.year = (2020 + (i Mod 5)).ToStr()
        item.runtime = (90 + i * 5).ToStr()
        item.description = "Description for " + title.ToStr() + " Item " + i.ToStr() + ". This is a sample description for display purposes."
        item.hdPosterUrl = "pkg:/images/default_poster.png"
        item.progressPercent = progress
        item.mediaId = "media_" + title + "_" + i.ToStr()
    end for

    return row
end function
