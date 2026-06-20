# Wholphin Roku

A Jellyfin media client for Roku TV, built in BrighterScript.

## Requirements

- Node.js 18+
- Roku device in Developer Mode
- Jellyfin server (10.8+) on your network

## Setup

1. Clone repo and install dependencies:
   ```
   npm install
   ```

2. Enable Developer Mode on your Roku:
   - Home × 3, Up, Right, Left, Right, Left, Right
   - Set a developer password

3. Create `bsconfig.deploy.local.json` with your Roku credentials:
   ```json
   {
     "extends": "bsconfig.deploy.json",
     "password": "your_roku_dev_password"
   }
   ```

## Building & Deploying

| Command | Description |
|---------|-------------|
| `npm run build` | Creates `out/Wholphin.zip` for sideloading |
| `npm run deploy` | Build + sideload to Roku (set `$env:ROKU_IP`) |
| `npm run clean` | Remove build/out directories |
| `npm run check` | Run BSC type checker (many warnings — known) |

## Environment Variables

| Variable | Description |
|----------|-------------|
| `ROKU_IP` | Roku device IP address |
| `ROKU_USERNAME` | Roku dev username (default: `rokudev`) |
| `ROKU_PASSWORD` | Roku dev password |

## Debug Console

After deploying, attach to telnet debug console:
```powershell
powershell -File rokudebug.ps1
```

## Architecture

```
Main.bs          — Entry point; event loop; auth flow
ShowScenes.bs    — Scene factory functions; navigation helpers
MainActions.bs   — Action handlers (play, favorite, playlist)
MainEventHandlers.bs — Event dispatch (selection, playback, dialogs)

source/api/      — Jellyfin API SDK (sdk.bs, baserequest.bs, etc.)
source/utils/    — Session, config, device capabilities, URL parsing

components/
  home/          — Home screen (Home.bs, HomeRows, HeroBanner, LoadItemsTask)
  config/        — Server setup, sign-in screens
  manager/       — SceneManager, QueueManager, ViewCreator
  video/         — Video player
  music/         — Audio player
  Libraries/     — Movie/TV/Music library views
  movies/        — MovieDetails
  tvshows/       — TV series/season details
  login/         — UserSelect
```

## Key Patterns

- **Scene navigation**: use `PopCurrentScene()` and `ClearAllScenes()` from `ShowScenes.bs`. Never use `sceneManager.callFunc("popScene")` — it hangs on this firmware.
- **Field observation**: use callback string form `observeField("field", "handlerName")` in render-thread components. Port form is for Task components only.
- **API calls**: always in Task nodes or `baserequest.bs` (which blocks until response). Never call `getJson()` from a render-thread Init() or event handler.

## History

See [`history/history.md`](history/history.md) for a full changelog.
