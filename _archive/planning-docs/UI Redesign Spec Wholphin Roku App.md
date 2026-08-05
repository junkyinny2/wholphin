UI Redesign Spec: Wholphin Roku App (SceneGraph)
Context for the AI coding this
This is a Roku channel built with SceneGraph/BrightScript. It was ported from an Android TV app, and the port lost the original layout — it currently renders as a bare screen with a small icon column and plain text instead of the Android app's rich home screen (hero banner + horizontal content rows). The goal is to rebuild the home screen using Roku's native SceneGraph components to visually match the target layout.
Target layout, mapped to SceneGraph components
1. Root scene structure

Use a single Scene-extended component (e.g. HomeScene.xml) as the top-level container
Layer children in this z-order: background Poster/Image → gradient overlay Rectangle → text Labels → LayoutGroup/RowList for content rows → left nav MarkupGrid or custom LayoutGroup

2. Left sidebar navigation

Build as a LayoutGroup (vertical) or MarkupGrid with a single column, fixed width (~120px), positioned at translation="[0,0]", full height
Each nav item is a ButtonGroup or custom Group component containing an icon Poster
Give it a translucent dark Rectangle background so it reads as a rail over the backdrop
Implement focus handling manually via onKeyEvent — Roku doesn't auto-highlight custom components, so you need explicit focus state (swap icon image or draw a highlight Rectangle/border behind the focused icon)
This component should NOT be inside the same focus chain as the row content below it — use m.top.setFocus() and track a state var (e.g. m.currentFocusZone = "nav" | "rows") to move focus between sidebar and content

3. Hero banner

Full-bleed Poster component for the backdrop image, width = full scene width, anchored top
A gradient overlay: Roku doesn't do CSS gradients — use a pre-rendered PNG gradient asset (transparent-to-black, both horizontal and vertical) composited as a Poster on top of the backdrop image, OR use Rectangle nodes with blendColor and low opacity stacked to fake it
Title/subtitle/metadata/description as stacked Label nodes, left-aligned, positioned over the gradient
Clock: a Label bound to a Timer (repeat, 60s interval) that updates system time — Roku has CreateObject("roDateTime") for this
Play / More Info buttons: ButtonGroup or two custom Groups with Rectangle + Label, styled filled vs outlined

4. "Next Up" row

Use Roku's built-in RowList node — this is the standard SceneGraph component for horizontal scrolling content rows and handles focus/scroll/paging natively, so don't hand-roll this
Set itemComponentName to a custom RowListItem extending Group, containing a Poster (16:9 aspect) and an E# badge Label positioned top-right over the thumbnail
RowList has a built-in itemFocused field/event — bind that to update the hero banner (backdrop image + text fields) when focus moves to a new item. This is the core interaction: hero content is driven by RowList focus, not static

5. Additional content rows ("Recently added in X")

Also RowList, but with poster items in 2:3 aspect instead of 16:9
Feed data via ContentNode — build a root ContentNode per row with child ContentNodes for each title (fields: Title, HDPosterUrl, Description, etc.), assign to RowList.content
Roku's RowList handles lazy row rendering already; just make sure you're not eagerly fetching every image URL for offscreen rows — populate ContentNode metadata upfront but let posters load on-demand (Roku's Poster node lazy-loads by default when bound through RowList)

6. Focus/remote navigation

All key handling in SceneGraph is manual via onKeyEvent(key, press) returning true/false. You'll need:

Up/Down within a RowList → handled natively by RowList
Left from leftmost row item → hands focus to sidebar nav
Right from sidebar nav → hands focus back to last-focused row item
Down/Up between rows → either native RowList behavior (if using a RowList of RowLists, i.e. a "grid of rows") or manual focus transfer between separate RowList nodes



Practical recommendation
Roku actually ships a template for almost exactly this UI: the SceneGraph SDK's "Channel Store" / roku-blueprint sample apps, and more directly, look at RowList + Poster + MarkupGrid patterns in Roku's official roku-samples GitHub repo. If Wholphin's original Android app used Leanback's BrowseFragment, that's a near-exact conceptual match to RowList-of-RowLists in SceneGraph — reference "Roku RowList grid layout" and "Roku SceneGraph gradient overlay" patterns specifically, since those are well-documented solved problems.