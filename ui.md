* \#DO NOT MODIFY THIS FILE

Roku SceneGraph Component Spec: Home Screen ("Hero + Shelves" Layout)

1\. Scene Overview



Scene name: HomeScene.xml (extends Scene)



A focus-driven home screen: a left navigation rail, a dynamic hero banner, and one or more horizontally-scrolling content shelves (RowList-style). Focusing an item in a shelf updates the hero banner above it. This is the classic Roku "featured content + rows" pattern, similar to RowListForCategoryContentShelf / PosterGrid type layouts channels commonly ship.



2\. Component Tree

HomeScene (Scene)

├── NavRail (Group)

│   └── NavRailItem\[] (Group, x9: Profile, Search, Home, Favorites, Movies, TV, Channels, MyList, Settings)

├── HeroBanner (Group)

│   ├── HeroBackgroundImage (Poster) — full-bleed art, changes on focus change

│   ├── HeroGradientOverlay (Rectangle or Poster with gradient PNG)

│   ├── HeroTextBlock (Group)

│   │   ├── HeroTitle (Label)

│   │   ├── HeroEpisodeTitle (Label)

│   │   ├── HeroMetaLine (Label)  -- "S1 E1 • Apr 3, 2016 • 25m"

│   │   └── HeroSynopsis (Label, wrap="true", maxLines=3, ellipsize)

│   └── SystemClock (Label, top-right)

└── ShelfContainer (Group, scrollable vertically if >2 rows)

&#x20;   ├── ShelfRow\[0]: "Next Up" (RowListItem -> MarkupGrid or RowList, 16:9 cards, episode badge overlay)

&#x20;   └── ShelfRow\[1]: "Recently added in <Category>" (RowListItem, mixed-ratio poster cards)



Use a single RowList node for ShelfContainer where each row is a ContentNode with children representing the cards — this gets you built-in vertical row navigation, focus management, and jump-to-item for free, rather than hand-rolling focus logic.



3\. Node Specs

3.1 NavRail

Field	Value

Type	Group containing 9 Poster/Label icon buttons stacked vertically

Position	Fixed, translation="\[40,40]", full height, always on top (z-order above shelves)

Width	\~80px

Icon spacing	\~64px vertical gap

Focus behavior	Only reachable via left from Hero/Shelf when an item is at the leftmost column, or via explicit remote "back"/menu button

States	default (muted gray icon), focused (accent blue fill/icon swap), active-section (Home icon stays blue-tinted even when NOT focused, to show current screen)

3.2 HeroBanner

Field	Value

Type	Group, height ≈ 55% of screen (Poster background + Rectangle gradient + Label stack)

HeroBackgroundImage	Poster, loadDisplayMode="scaleToZoom", uri bound to focusedItem.hdBackgroundImageUrl

HeroGradientOverlay	Horizontal gradient, opaque black (left) → transparent (\~60% across) → transparent (right). Implement as a 9-patch/segment PNG or Rectangle with blendColor gradient shader

HeroTitle	Label, font size \~48px bold, color="0xFFFFFFFF"

HeroEpisodeTitle	Label, font size \~28px medium

HeroMetaLine	Label, font size \~22px, color="0xCCCCCCFF", format: "S{season} E{episode} • {airDate} • {runtime}m"

HeroSynopsis	Label, wrap="true", max 3 visible lines, truncate with "…" appended when clipped (no native "maxLines+ellipsis" combo on Label — implement via TextEditBox-free measuring: truncate string server-side or measure with Label.numLines and trim)

SystemClock	Label, top-right corner, updates every 60s via Timer

Update trigger	Observe shelfRowList.itemFocused — on change, re-bind Hero fields from the newly focused ContentNode's metadata fields

3.3 Shelf Rows (RowList)

Field	Value

Type	RowList (single instance) or two stacked MarkupGrids inside a scrollable Group

Row 0 — "Next Up"	Card size 16:9 (\~350x200px), rounded corners optional, each card has an episodeBadge Label/Poster overlay top-right (e.g. "E1")

Row 1 — "Recently added in {category}"	Card size varies (poster 2:3 or landscape), title derived from ContentNode.title

Row header	Label above each row, e.g. "Next Up", bold, \~24px, left-aligned to row's left edge (aligns with Hero text block's left margin)

Card focus state	Focused card gets 2-3px cyan/accent border (0x00D4FFFF or channel accent color) drawn via a Rectangle border sibling or Poster's loadingBitmapUri/focus bitmap swap

Scrolling	Horizontal only, per-row independent; RowList handles this natively via rowListHasPreviewContent/standard row focus animation

Initial focus	First card of first row ("Next Up" item 0) is focused by default on scene load, matching the Hero content shown

4\. Data / Content Model



Each shelf item should be a ContentNode with (at minimum) these fields so Hero binding works generically:



ContentNode

├── title            (string)   -- "My Hero Academia"

├── episodeTitle      (string)   -- "Izuku Midoriya: Origin"

├── season            (int)

├── episode           (int)

├── releaseDate       (string)   -- "Apr 3, 2016"

├── runtimeMinutes     (int)

├── shortDescriptionLine (string) -- synopsis

├── HDBackgroundImageUrl (string) -- hero art

├── HDPosterUrl        (string)   -- shelf card art

└── episodeBadge       (string, optional) -- "E1", "E2"...

5\. Focus Management (BrightScript)



Key behaviors to implement in HomeScene.brs:



onKeyEvent(key, press) — handle up/down/left/right/OK/back and route focus between NavRail, HeroBanner (not directly focusable — it's a display surface), and ShelfContainer rows.

Observer on row list's focused item (m.shelfRowList.observeField("rowItemFocused", "onRowItemFocused")) → in the callback, pull the focused ContentNode and update all Hero labels/background in one function (updateHeroContent(contentNode)), ideally with a short crossfade animation (m.heroBackground.setFields({... }); heroFadeAnim.control = "start").

Debounce rapid focus changes: if user holds direction key and flies across many cards quickly, debounce the Hero image swap (e.g. 150-200ms) so you're not thrashing image loads/network requests on every intermediate card.

Preserve NavRail active-state: Home icon keeps its "current section" highlight independent of literal focus, distinct from the transient focus highlight on whichever item currently has remote focus.

Back button: from Shelf/Hero, back should move focus to NavRail (or exit app if already there / show exit prompt).

6\. Visual Tokens (for consistent theming)

Token	Value (approx, from reference)

Background	

\#0B0E14 to 

\#1A1E2A (dark navy/black)

Accent (focus/active)	Cyan-blue, 

\#1FA9E0–

\#2FD0FF range

Primary text	

\#FFFFFF

Secondary text (metadata)	

\#B0B0B0–

\#CCCCCC

Title font weight	Bold / 700

Body font weight	Regular / 400

Card corner radius	4–8px (if supported by graphics; SceneGraph posters are often rectangular by default — use rounded-rect image assets if needed)

7\. Open Implementation Notes for the Building Agent

Roku Label does not support native multi-line ellipsis truncation — either pre-truncate the string in code based on measured character/line count, or use a fixed-height Label with wrap="true" and accept possible mid-word cutoff, appending "…" manually.

Gradient overlays are typically pre-baked into a PNG asset (transparent-to-black) rather than rendered procedurally, since SceneGraph has no native CSS-style gradient primitive.

For smooth Hero-image transitions, cross-fade two stacked Poster nodes (swap opacity 0→1 / 1→0 via Animation node) rather than swapping uri on a single node, which can cause a visible flash/pop-in.

If shelf count grows beyond 2, confirm whether ShelfContainer needs its own vertical scroll independent of Hero (Hero likely stays pinned/static while only shelves scroll — a common "sticky hero" pattern) or whether the whole scene scrolls as one column.



Here's a detailed breakdown you can hand off to describe both the visual design and behavior of this screen:



Overview



This is a streaming app home/detail screen (Roku-style TV interface) showing a hero banner for a selected show plus horizontal shelves of recommended content below it.



Layout Structure



Left sidebar (persistent nav rail):



Vertical icon column, dark/transparent background, always visible

Icons top to bottom: Profile/Account, Search, Home (highlighted blue = active state), Favorites/Wishlist (heart), Movies, TV/Live, Channels/Guide, My List, Settings (gear, bottom)

Icons are minimal, monochrome line-icons; the active section (Home) is highlighted in accent blue while others stay muted gray/white



Hero banner (top \~55% of screen):



Full-bleed background image/artwork of the currently focused title, with a gradient overlay (dark on left fading to transparent on right) so text stays readable over the art

Text block on left side, over the gradient:

Show title (large, bold) — "My Hero Academia"

Episode title (medium weight) — "Izuku Midoriya: Origin"

Metadata line: Season/Episode • air date • runtime — "S1 E1 • Apr 3, 2016 • 25m"

Synopsis paragraph, truncated with ellipsis after \~3 lines

Clock/time in top-right corner (system status)



Content shelves (rows below hero):



Row 1: "Next Up" — horizontal scrollable row of thumbnail cards (16:9), each with an episode badge (E1, E2, E3...) in top-right corner. First card has a highlighted/focused border (cyan outline) indicating current selection

Row 2: "Recently added in Anime Movies" — horizontal row of poster-style cards (mixed aspect ratios), scrollable, showing movie titles

Behavioral / Interaction Notes

D-pad/remote navigation: content is organized into a spatial grid — up/down moves between rows (nav rail, hero, Next Up shelf, Recently Added shelf), left/right moves between items within a row or nav icons

Focus state: the currently focused item gets a visible highlight (e.g., cyan border on the first "Next Up" card, blue fill on the Home nav icon) — this is critical for TV interfaces since there's no cursor/hover, only focus

Hero updates dynamically: as the user scrolls/focuses different thumbnails in a shelf, the hero banner above updates to reflect that title's artwork, title, synopsis, and metadata (this is the standard "focus-driven hero" pattern used by Netflix/Hulu/Roku-style apps)

Shelves scroll horizontally, independently, without moving the hero or other rows

Truncated text: synopsis clips at a fixed number of lines with an ellipsis rather than wrapping indefinitely

Persistent left rail: stays fixed/visible regardless of vertical scroll position in the main content area

