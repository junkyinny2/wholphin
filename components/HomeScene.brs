' ============================================================ 
' HomeScene.brs 
' Lifecycle + data wiring for the home screen. 
' Focus/key-handling lives in HomeSceneFocus.brs (kept separate 
' so this file stays readable as the data/layout logic grows). 
' ============================================================ 

sub init()
  m.heroBackdrop = m.top.findNode("heroBackdrop")
  m.heroTitle = m.top.findNode("heroTitle")
  m.heroSubtitle = m.top.findNode("heroSubtitle")
  m.heroMeta = m.top.findNode("heroMeta")
  m.heroDescription = m.top.findNode("heroDescription")
  m.clockLabel = m.top.findNode("clockLabel")
  m.navRail = m.top.findNode("navRail")
  
  ' Row Lists
  m.nextUpRow = m.top.findNode("nextUpRow")
  m.animeRow = m.top.findNode("animeRow")

  ' Track which zone owns focus: "nav" or "rows"
  m.focusZone = "rows"
  m.currentItemIndex = invalid ' [rowIndex, itemIndex]

  setupClock()
  loadHomeData()

  ' Observe both rows for hero updates and selection
  m.nextUpRow.observeField("rowItemFocused", "onNextUpRowItemFocused")
  m.nextUpRow.observeField("rowItemSelected", "onNextUpRowItemSelected")
  m.animeRow.observeField("rowItemFocused", "onAnimeRowItemFocused")
  m.animeRow.observeField("rowItemSelected", "onAnimeRowItemSelected")

  m.top.setFocus(true)
  m.nextUpRow.setFocus(true)

  ' Observe hero buttons
  m.playButton = m.top.findNode("playButton")
  if m.playButton <> invalid then m.playButton.observeField("itemSelected", "onPlayButtonClicked")
  
  m.moreInfoButton = m.top.findNode("moreInfoButton")
  if m.moreInfoButton <> invalid then m.moreInfoButton.observeField("itemSelected", "onMoreInfoClicked")
end sub

sub onPlayButtonClicked()
  ' Play the currently featured item (from hero)
  if m.currentItemIndex <> invalid
    rowIndex = m.currentItemIndex[0]
    itemIndex = m.currentItemIndex[1]
    
    targetRowItem = invalid
    if rowIndex = 0
      targetRowItem = m.nextUpRow.content.getChild(itemIndex)
    else if rowIndex = 1
      targetRowItem = m.animeRow.content.getChild(itemIndex)
    end if

    if targetRowItem <> invalid then playItem(targetRowItem)
  end if
end sub

sub onMoreInfoClicked()
  ' For now, just print. In a real app, this would navigate to details.
  print "More info clicked for item at index: "; m.currentItemIndex
end sub

' ------------------------------------------------------------ 
' Clock: update every 30s via roDateTime 
' ------------------------------------------------------------ 
sub setupClock()
  m.clockTimer = CreateObject("roSGNode", "Timer")
  m.clockTimer.repeat = true
  m.clockTimer.duration = 30
  m.clockTimer.observeField("fire", "updateClock")
  m.clockTimer.control = "start"
  updateClock()
end sub

sub updateClock()
  dt = CreateObject("roDateTime")
  dt.ToLocalTime()
  hour = dt.GetHours()
  ampm = "AM"
  if hour >= 12 then ampm = "PM"
  displayHour = hour mod 12
  if displayHour = 0 then displayHour = 12
  minute = dt.GetMinutes()
  minuteStr = minute.ToStr()
  if minute < 10 then minuteStr = "0" + minuteStr
  m.clockLabel.text = displayHour.ToStr() + ":" + minuteStr + " " + ampm
end sub

' ------------------------------------------------------------ 
' Data loading — replace loadHomeData's guts with your real 
' Jellyfin/backend API calls. This just wires the shape of the 
' ContentNode tree RowList expects. 
' ------------------------------------------------------------ 
sub loadHomeData()
  ' Row 0: Next Up (episodes, 16:9, with E# badge)
  nextUpContent = CreateObject("roSGNode", "ContentNode")
  appendEpisodeItem(nextUpContent, "My Hero Academia", "pkg:/images/mha_thumb.jpg", 1)
  appendEpisodeItem(nextUpContent, "Teen Titans Go!", "pkg:/images/ttg_thumb.jpg", 2)
  appendEpisodeItem(nextUpContent, "Rascal Does Not Dream of Bunny Girl Senpai", "pkg:/images/rascal_thumb.jpg", 3)
  appendEpisodeItem(nextUpContent, "The Fragrant Flower Blooms With Dignity", "pkg:/images/flower_thumb.jpg", 1)
  m.nextUpRow.content = nextUpContent

  ' Row 1: Recently added in Anime Movies (posters, 2:3)
  animeContent = CreateObject("roSGNode", "ContentNode")
  appendPosterItem(animeContent, "My Hero Academia: Heroes Rising", "pkg:/images/poster1.jpg")
  appendPosterItem(animeContent, "One Piece Film: Red", "pkg:/images/poster2.jpg")
  appendPosterItem(animeContent, "Violet Evergarden", "pkg:/images/poster3.jpg")
  m.animeRow.content = animeContent

  ' Seed the hero with the first item so it's not blank before focus fires if nextUpRow.getChildCount() > 0
  if m.nextUpRow.getChildCount() > 0
    updateHeroFromItem(m.nextUpRow.getChild(0))
  end if
end sub

sub appendEpisodeItem(parentRow as object, title as string, thumbUri as string, episodeNum as integer)
  item = parentRow.CreateChild("ContentNode")
  item.title = title
  item.HDPosterUrl = thumbUri
  item.AddFields({ episodeNumber: episodeNum, aspect: "16x9" })
end sub

sub appendPosterItem(parentRow as object, title as string, posterUri as string)
  item = parentRow.CreateChild("ContentNode")
  item.title = title
  item.HDPosterUrl = posterUri
  item.AddFields({ aspect: "2x3" })
end sub

' ------------------------------------------------------------ 
' Hero banner updates when the focused row item changes. 
' RowList 'rowItemFocused' event returns the index of the item in that row.
' ------------------------------------------------------------ 
sub onNextUpRowItemFocused(event as object)
  itemIndex = event.getData()
  m.currentItemIndex = [0, itemIndex]
  item = m.nextUpRow.content.getChild(itemIndex)
  if item <> invalid then updateHeroFromItem(item)
end sub

sub onAnimeRowItemFocused(event as object)
  itemIndex = event.getData()
  m.currentItemIndex = [1, itemIndex]
  item = m.animeRow.content.getChild(itemIndex)
  if item <> invalid then updateHeroFromItem(item)
end sub

sub onNextUpRowItemSelected(event as object)
  itemIndex = event.getData()
  item = m.nextUpRow.content.getChild(itemIndex)
  playItem(item)
end sub

sub onAnimeRowItemSelected(event as object)
  itemIndex = event.getData()
  item = m.animeRow.content.getChild(itemIndex)
  showDetails(item)
end sub

sub updateHeroFromItem(item as object)
  m.heroTitle.text = item.title
  if item.hasField("episodeNumber")
    m.heroSubtitle.text = "Episode " + item.episodeNumber.ToStr()
    m.heroMeta.text = "" ' fill with season/date/runtime once your API supplies it
  else
    m.heroSubtitle.text = ""
    m.heroMeta.text = ""
  end if
  m.heroDescription.text = item.description
  ' Swap to a real backdrop/fanart field once available; falling back to poster for now
  m.heroBackdrop.uri = item.HDPosterUrl
end sub

sub playItem(item as object)
  ' TODO: push a VideoScene / hand off to your player component
  print "Play requested: "; item.title
end sub

sub showDetails(item as object)
  ' TODO: push a DetailsScene component
  print "Details requested: "; item.title
end sub