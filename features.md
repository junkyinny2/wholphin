# Wholphin Roku – Features

## Navigation
- **Side rail** with Home, Search, Favorites, Movies, Shows, Continue, Playlists, Settings
- Left/Right focus switching between nav rail and content rows
- Up/Down navigation within focused section

## Home Screen
- **Hero banner** (backdrop + overlay with title/metadata)
- **Content rows**: Continue Watching, Next Up, Latest Media, Favorites, Resumable items
- Row-based layout with RowList + MarkupGrid (PosterGrid per row)
- "Loading..." label while data loads, hidden when ready

## Auto-Login
- Separate registry keys (`wh_autologin_server/token/userid`) survive server URL resets
- Automatic authentication on launch without user interaction
- Token saved after first sign-in

## Server Connection
- **Set Server Screen** with Connect, Auto Discover, Manual Entry buttons
- Server discovery via broadcast (ServerDiscoveryTask)
- Manual URL entry via KeyboardDialog
- Basic authentication (username/password)

## Media Support
- **Movies** – details, options, version selection, streaming
- **TV Shows** – series details, seasons grid, episode list, episode items
- **Music** – artists, albums, audio player view
- **Audio Books** – library view
- **Live TV** – library view
- Video player with OSD (on-screen display)
- Trick play image preloading

## User Profiles
- User selection grid on sign-in
- Per-user settings and play state tracking
- Quick Connect disabled (blocks on this firmware)

## Internationalization
- Translation support via `translateText()`
- Keyboard dialog with localized buttons

## Settings
- Playback preferences (auto-play next, etc.)
- Server configuration
- User profile management

## Performance & Stability
- Timer-deferred data loading (0ms Timer for session availability)
- Error-tolerant `chainLookupReturn()` for safe nested access
- Singleton service nodes (SceneManager, QueueManager, AudioPlayer, PlaystateTask)
- Namespace-based script injection via transpile.ps1

## Build & Deploy
- Transpile BrightScript (`.bs` → `.brs`) with auto-injection of common scripts
- Build with Node.js archiver (forward-slash zip)
- Deploy via Dev Portal API (`curl --digest`)
- Debug telnet (port 8085)
- PowerShell scripts: `setup.ps1`, `deploy_roku.ps1`, `rokudebug.ps1`
