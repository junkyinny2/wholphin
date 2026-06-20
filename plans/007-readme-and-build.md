# Plan 007 — Add README and unified build documentation

**Commit:** `c7ef21b`  
**Category:** DX / Tooling  
**Impact:** MEDIUM — no README means any new contributor (or future-you after a break) has no entry point  
**Effort:** S  
**Risk of fix:** ZERO  

---

## Why this matters

The repo has zero documentation. `package.json` has 4 scripts (`build`, `deploy`, `clean`, `check`) but:
- `npm run build` creates a zip but does NOT deploy
- `npm run deploy` runs `deploy_roku.ps1` which requires manual credential setup
- `npm run check` runs bsc but produces 900+ warnings that mask real errors
- No document explains which Roku IPs are in use, how to onboard, or how to read the debug output

There is also no explanation of the custom transpile-less build architecture (BrightScript namespaces emulated via BSC, deployed via `roku-deploy` to bypass BSC validation).

---

## Implementation

### New file: `README.md` (project root)

```markdown
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
| `npm run deploy` | Build + sideload to Living Room Roku (192.168.1.100) |
| `npm run clean` | Remove build/out directories |
| `npm run check` | Run BSC type checker (many warnings — known) |

## Roku Device IPs

| Device | IP Address |
|--------|-----------|
| Living Room | 192.168.1.100 |
| Bedroom | 192.168.1.200 |

**These IPs must never change.** See `AGENTS.md §4.3`.

## Debug Console

After deploying, attach to telnet debug console:
```powershell
powershell -File rokudebug.ps1 192.168.1.100
```

Or open `http://192.168.1.100` in a browser for the Roku developer interface.

## Architecture

```
Main.bs          — Entry point; event loop; auth flow
ShowScenes.bs    — Scene factory functions; navigation helpers
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
```

---

## Files to create/modify

| File | Change |
|------|--------|
| `README.md` | Create with full content above |
| `.gitignore` | Verify `bsconfig.deploy.local.json` and `*.local.json` are excluded |

---

## Verification

```powershell
# Confirm file exists and renders
Get-Content README.md | head -5
```

No deployment needed for this plan.
