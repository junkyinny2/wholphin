# Wholphin Roku

A Jellyfin media client for Roku TV, built in BrighterScript.

## Features

- **Home Screen** — Navigation rail, hero banner with backdrop, content rows (Continue Watching, Next Up, Latest Media, Favorites)
- **Media Playback** — Video player with OSD, trick play, audio player, version selection
- **Library Views** — Movies, TV Shows (seasons/episodes), Music (artists/albums), Live TV, Audiobooks
- **Auto-Login** — Token-based authentication persists across launches
- **Server Discovery** — Auto-detect Jellyfin servers on your network or enter manually
- **Multiple Users** — User profile selection, per-user settings and play state

## Requirements

- Roku device in [Developer Mode](https://developer.roku.com/en-ca/docs/developer-program/getting-started/developer-setup.md)
- Node.js 18+
- Jellyfin server (10.8+) on your network

## Quick Start

```bash
# Clone and install dependencies
npm install

# Set your Roku credentials
$env:ROKU_IP = "192.168.1.100"
$env:ROKU_PASSWORD = "your_password"

# Build and deploy
npm run deploy
```

### First-time Setup

1. Enable Developer Mode on your Roku: `Home × 3, Up, Right, Left, Right, Left, Right`
2. Create `bsconfig.deploy.local.json` with your Roku password:

```json
{
  "extends": "bsconfig.deploy.json",
  "password": "your_roku_dev_password"
}
```

3. Run `npm run deploy` to build and sideload
4. On first launch, enter your Jellyfin server address and sign in

## Commands

| Command | Description |
|---------|-------------|
| `npm run build` | Create `out/Wholphin.zip` for sideloading |
| `npm run deploy` | Build + sideload to Roku |
| `npm run clean` | Remove build/out directories |
| `npm run check` | Run BSC type checker |
| `.\rokudebug.ps1` | Attach to Roku telnet debug console (port 8085) |

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `ROKU_IP` | Roku device IP address | (prompted) |
| `ROKU_USERNAME` | Roku dev username | `rokudev` |
| `ROKU_PASSWORD` | Roku dev password | (prompted if not set) |

## Architecture

```
source/
  Main.bs                Entry point, event loop, auth flow
  ShowScenes.bs          Scene factory functions, navigation helpers
  MainActions.bs         Action handlers (play, favorite, playlist)
  MainEventHandlers.bs   Event dispatch (selection, playback, dialogs)
  api/                   Jellyfin API SDK
  utils/                 Session, config, device capabilities, URL parsing

components/
  home/                  Home screen (Home, HomeRows, HeroBanner, LoadItemsTask)
  config/                Server setup, sign-in screens
  manager/               SceneManager, QueueManager, ViewCreator
  video/                 Video player
  music/                 Audio player
  Libraries/             Movie/TV/Music library views
  movies/                Movie details
  tvshows/               TV series/season details
  login/                 User select
```

## Build Pipeline

1. **Transpile** — `.bs` (BrighterScript) → `.brs` (BrightScript) with namespace-aware function prefixing
2. **Package** — Create `.zip` with Node.js archiver (forward-slash paths for Roku)
3. **Deploy** — Upload via Dev Portal API (`curl --digest`)

## Known Issues

- `sceneManager.callFunc("popScene")` hangs on this firmware — use `PopCurrentScene()` instead
- BSC type checker produces false positives — severity overrides applied in `bsconfig.json`
- Quick Connect disabled (firmware incompatibility)

## License

This project is derived from [JellyVibe](https://github.com/junkyinny2/JellyVibe) and is licensed under the GPL-3.0 License.
