sub Init()
    m.heroBackdrop = m.top.findNode("heroBackdrop")
    m.gradientOverlay = m.top.findNode("gradientOverlay")
    m.heroClock = m.top.findNode("heroClock")
    m.heroTitle = m.top.findNode("heroTitle")
    m.heroSubtitle = m.top.findNode("heroSubtitle")
    m.heroMetadata = m.top.findNode("heroMetadata")
    m.heroDescription = m.top.findNode("heroDescription")

    m.top.observeField("heroItem", "onHeroItemChange")
end sub

sub onHeroItemChange()
    item = m.top.heroItem
    if item = invalid then return

    backdropUrl = ""
    if item.backdropURL <> "" and item.backdropURL <> invalid then
        backdropUrl = item.backdropURL
    else if item.PosterUrl <> "" and item.PosterUrl <> invalid then
        backdropUrl = item.PosterUrl
    end if

    if backdropUrl <> "" then
        m.heroBackdrop.uri = backdropUrl
    end if

    title = ""
    if item.title <> "" and item.title <> invalid then
        title = item.title
    else if item.Name <> "" and item.Name <> invalid then
        title = item.Name
    end if
    m.heroTitle.text = title

    subtitle = ""
    if item.episodeTitle <> "" and item.episodeTitle <> invalid then
        subtitle = item.episodeTitle
    else if item.SeriesName <> "" and item.SeriesName <> invalid then
        subtitle = item.SeriesName
        if item.ParentIndexNumber <> invalid and item.IndexNumber <> invalid then
            subtitle = subtitle + " • S" + item.ParentIndexNumber.ToStr() + ":" + item.IndexNumber.ToStr()
        end if
    end if
    m.heroSubtitle.text = subtitle

    metadata = ""
    if item.type <> "" and item.type <> invalid then
        metadata = item.type
    end if
    if item.dateAdded <> invalid and item.dateAdded <> "" then
        if metadata <> "" then metadata = metadata + " • "
        metadata = metadata + item.dateAdded
    end if
    m.heroMetadata.text = metadata

    desc = ""
    if item.description <> "" and item.description <> invalid then
        desc = item.description
    else if item.Overview <> "" and item.Overview <> invalid then
        desc = item.Overview
    end if
    m.heroDescription.text = desc
end sub