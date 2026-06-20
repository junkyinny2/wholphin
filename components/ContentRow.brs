sub Init()
    m.rowLabel = m.top.findNode("rowLabel")
    m.rowGrid = m.top.findNode("rowGrid")

    m.top.observeField("rowTitle", "onRowTitleChange")
    m.top.observeField("content", "onRowContentChange")
    m.top.observeField("focusedChild", "onFocusedChildChange")
end sub

sub onRowTitleChange()
    if m.rowLabel <> invalid then
        m.rowLabel.text = m.top.rowTitle
    end if
end sub

sub onRowContentChange()
    content = m.top.content
    if content = invalid then return

    items = content.getChildCount()
    if items = 0 then
        m.top.visible = false
        return
    end if

    m.top.rowTitle = content.title

    gridContent = CreateObject("roSGNode", "ContentNode")
    for i = 0 to items - 1
        child = content.getChild(i)
        if child <> invalid then
            node = gridContent.CreateChild("ContentNode")
            node.id = child.id
            node.title = child.title
            node.AddFields({ type: "", json: invalid })
            if child.hasField("type") then node.type = child.type
            if child.hasField("json") then node.json = child.json
            if child.HDPosterUrl <> invalid then
                node.HDPosterUrl = child.HDPosterUrl
                node.SDPosterUrl = child.SDPosterUrl
            else
                img = PosterImage(child.id)
                if img <> invalid then
                    node.HDPosterUrl = img.url
                    node.SDPosterUrl = img.url
                end if
            end if
        end if
    end for

    m.rowGrid.content = gridContent
    m.top.visible = true
end sub

sub onFocusedChildChange()
    if m.top.isInFocusChain() and m.rowGrid <> invalid then
        m.rowGrid.setFocus(true)
    end if
end sub