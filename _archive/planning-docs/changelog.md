# Changelog

## [0.1.17] – 2026-06-20
- Fixed side-rail navigation focus (each nav item now focusable, left/right focus switching)
- Added `onKeyEvent` handler in HomeScreen for Left/Right focus rail ↔ content rows
- Set initial focus to serverButtons group (fixes button selection on SetServerScreen)

## [0.1.16] – 2026-06-20
- Hard-coded Jellyfin server URL to skip SetServerScreen
- Updated `setup.ps1` script to automate all fixes, rebuild, and deploy

## [0.1.15] – 2026-06-20
- Fixed duplicate `finishLoading()` definition causing compile error (`&hb9`)
- Added null-safety checks in HomeRow (`HDPosterUrl`, `id` validation) and HomeItem (title/type null guard)
- Added debug `?` logging in finishLoading() and HomeRow/HomeItem

## [0.1.14] – 2026-06-19
- Home screen: added HomeRows (RowList), HomeRow (MarkupGrid), HomeItem components
- Timer-deferred data loading so `m.global.session` is available
- Auto-login via separate `wh_autologin_*` registry keys (survives server clear)
- LoginFlow returns `false` instead of `true` when showing login screen (prevents double PushScene)
- `set_setting("server", "")` at startup (prevents 30s ServerInfo timeout)
- Nav rail items (Home, Search, Favorites, Movies, Shows, Continue, Playlists, Settings)
- Created LeftNavRail, ContentRow, HeroBanner XML components

## [0.1.13] – 2026-06-18
- Fixed JFGroup freeze (observed focusedChild before render tree complete)
- HomeScreen extends Group directly (not JFScreen)
- Split `closeAllDropdowns` / `closeAllDropdownsAndReset` to fix dropdown re-open bug

## [0.1.12] – Initial scaffolding
- Base authentication flow (server setup → user select → sign-in)
- Jellyfin API integration (Items, SDK, user auth, image requests)
- Media playback (video, audio)
- SceneManager push/pop/clear scene stack
- Build pipeline with transpile.ps1 + node build.js
