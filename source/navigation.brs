' Wholphin Roku - Navigation State Management
' Tracks DPAD focus position and manages content loading

function createNavigator() as Object
    nav = {
        currentTab: 0
        currentRow: 0
        currentCol: 0
        focusZone: "rows"
        tabNames: ["home", "movies", "tvshows", "continuewatching", "settings"]
        rowData: {}
        history: []
    }

    nav.setTab = function(index as Integer) as Void
        if index >= 0 and index < nav.tabNames.Count() then
            nav.currentTab = index
            nav.currentRow = 0
            nav.currentCol = 0
            nav.rowData = {}
        end if
    end function

    nav.getCurrentTab = function() as String
        if nav.currentTab >= 0 and nav.currentTab < nav.tabNames.Count() then
            return nav.tabNames[nav.currentTab]
        end if
        return "home"
    end function

    nav.pushHistory = function(state as Object) as Void
        nav.history.Push({
            tab: nav.currentTab
            row: nav.currentRow
            col: nav.currentCol
            zone: nav.focusZone
            details: state
        })
    end function

    nav.popHistory = function() as Object
        if nav.history.Count() > 0 then
            return nav.history.Pop()
        end if
        return invalid
    end function

    nav.getTabQuery = function(tabName as String) as Object
        query = {}
        query.Limit = "20"
        query.Recursive = "true"
        query.Fields = "PrimaryImageAspectRatio,BasicSyncInfo"

        if tabName = "home" then
            query.SortBy = "SortName"
            query.SortOrder = "Ascending"
        else if tabName = "movies" then
            query.IncludeItemTypes = "Movie"
            query.SortBy = "SortName"
        else if tabName = "tvshows" then
            query.IncludeItemTypes = "Series"
            query.SortBy = "SortName"
        else if tabName = "continuewatching" then
            query.Filters = "IsResumable"
            query.SortBy = "DatePlayed"
            query.SortOrder = "Descending"
        else if tabName = "settings" then
            ' No query needed
        end if

        return query
    end function

    return nav
end function
