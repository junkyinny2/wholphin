' Wholphin Roku - Details Panel
' Shows item metadata, description, and play/resume buttons

sub Init()
    m.detailPoster = m.top.findNode("detailPoster")
    m.detailTitle = m.top.findNode("detailTitle")
    m.detailYear = m.top.findNode("detailYear")
    m.detailRuntime = m.top.findNode("detailRuntime")
    m.detailDescription = m.top.findNode("detailDescription")
    m.progressBarFill = m.top.findNode("progressBarFill")
    m.progressBarBg = m.top.findNode("progressBarBg")
    m.playButton = m.top.findNode("playButton")
    m.resumeButton = m.top.findNode("resumeButton")

    m.top.observeField("itemData", m.port)

    m.buttonIndex = 0
    m.buttons = [m.playButton, m.resumeButton]
    m.top.focusedButton = 0
    updateButtonFocus()
end sub

sub onItemDataChanged()
    data = m.top.itemData
    if data = invalid then return

    m.detailTitle.text = data.title
    m.detailYear.text = data.year
    m.detailRuntime.text = data.runtime + " min"
    m.detailDescription.text = data.description

    if data.imageUrl <> "" then
        m.detailPoster.uri = data.imageUrl
    end if

    progress = data.progressPercent
    if progress <> invalid and progress > 0 then
        m.progressBarFill.width = Int(600 * progress)
        m.progressBarBg.visible = true
        m.progressBarFill.visible = true
    else
        m.progressBarBg.visible = false
        m.progressBarFill.visible = false
    end if

    m.buttonIndex = 0
    m.top.focusedButton = 0
    updateButtonFocus()
end sub

function onKeyEvent(key as String, press as Boolean) as Boolean
    if not press then return false

    if key = "right" then
        if m.buttonIndex < m.buttons.Count() - 1 then
            m.buttonIndex = m.buttonIndex + 1
            m.top.focusedButton = m.buttonIndex
            updateButtonFocus()
            return true
        end if
    end if

    if key = "left" then
        if m.buttonIndex > 0 then
            m.buttonIndex = m.buttonIndex - 1
            m.top.focusedButton = m.buttonIndex
            updateButtonFocus()
            return true
        end if
    end if

    if key = "OK" then
        m.top.focusedButton = m.buttonIndex
        return true
    end if

    return false
end function

sub updateButtonFocus()
    for i = 0 to m.buttons.Count() - 1
        btn = m.buttons[i]
        if btn <> invalid then
            bg = btn.findNode(btn.id + "Bg")
            if bg <> invalid then
                if i = m.buttonIndex then
                    bg.color = "0x00A4DCFF"
                else
                    bg.color = "0x444444FF"
                end if
            end if
        end if
    end for
end sub
