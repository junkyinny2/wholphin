' Wholphin Roku - Poster Row Item
' Individual poster with progress bar and title label

sub Init()
    m.itemPoster = m.top.findNode("itemPoster")
    m.progressBarFill = m.top.findNode("progressBarFill")
    m.progressBarBg = m.top.findNode("progressBarBg")
    m.itemLabel = m.top.findNode("itemLabel")

    m.top.observeField("itemContent", m.port)
end sub

sub onItemContentChanged()
    content = m.top.itemContent
    if content = invalid then return

    m.itemPoster.uri = content.hdPosterUrl
    m.itemLabel.text = content.title

    progress = content.progressPercent
    if progress <> invalid and progress > 0 then
        fillWidth = Int(300 * progress)
        m.progressBarFill.width = fillWidth
        m.progressBarBg.visible = true
        m.progressBarFill.visible = true
    else
        m.progressBarBg.visible = false
        m.progressBarFill.visible = false
    end if
end sub
