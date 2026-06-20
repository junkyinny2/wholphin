# Wholphin Roku — Implementation Plans Index

**Commit written against:** `c7ef21b`  
**Audit date:** 2026-06-15  
**Effort level:** standard

---

## Recommended Execution Order

Dependencies must be respected. Fix in this order:

| # | Plan | Category | Impact | Effort | Status | Depends On |
|---|------|----------|--------|--------|--------|-----------|
| 001 | [m.port not initialized in components](001-mport-init.md) | Correctness | CRITICAL | M | DONE | — |
| 002 | [VideoPlayerView.bs uses popScene via callFunc](002-videoplayer-popscene.md) | Correctness | HIGH | S | DONE | — |
| 003 | [Home.bs loads all sections synchronously on render thread](003-home-async-loading.md) | Correctness/Perf | HIGH | M | DONE | — |
| 004 | [Password stored in registry in plain text](004-password-security.md) | Security | HIGH | S | DONE | — |
| 005 | [Credentials in source-controlled bsconfig.deploy.json](005-deploy-creds.md) | Security | HIGH | S | DONE | — |
| 006 | [inferServerUrl defaults break real-world self-hosted installs](006-server-url-inference.md) | Correctness | MEDIUM | S | DONE | — |
| 007 | [No README / no verification baseline](007-readme-and-build.md) | DX | MEDIUM | S | DONE | — |
| 008 | [printReg hardcoded true in Main.bs:44](008-printReg.md) | Correctness | MEDIUM | S | DONE | — |
| 009 | [Home data loaded synchronously — entire home screen blocks render thread](003-home-async-loading.md) | Perf | HIGH | M | DONE | 003 |
| 010 | [Missing API namespace: api.userdata — MarkPlayed/Favorite broken at call sites](010-userdata-api.md) | Correctness | MEDIUM | S | DONE | — |

## Dependency Graph

```
001 ──► (none — safe to execute first)
002 ──► (none)
003 ──► (none)
004 ──► (none)
005 ──► (none)
006 ──► (none)
007 ──► (none)
008 ──► (none)
010 ──► (none)
```

All plans are independent. Suggested batch: `001`, `002`, `008` first (lowest risk, highest impact on correctness). Then `004`, `005` (security). Then `003`, `006`, `010` (functional). Finally `007` (documentation).

## Considered and Rejected

- **transpile.ps1 regex fragility** — Already partially addressed in Phase 4 history. The correct fix is namespace-flattening (replacing the transpiler). Excluded because it's a large architectural change that would need its own dedicated refactor session and is out of scope for this audit's fix plans.
- **No test harness** — Noted as a direction finding below, not a fixable bug with a specific plan.
- **Roku registry size limit** — The registry is limited to 16KB per section. Current usage appears within limits. Flagged for monitoring, not a plan.

## Direction Findings (Features / What to Build Next)

1. **Delete transpile.ps1, compile natively with BrighterScript** — The transpiler is 323 lines of fragile regex. BSC already understands namespaces and handles the transpilation correctly. Porting the project fully to BSC-native compilation would eliminate the entire class of namespace/AA-method bugs and make the build reproducible. Effort: L. Risk: HIGH (must port carefully). Reward: eliminates the #1 root cause of past crashes.

2. **Playback resume prompt** — `HandleResumeDialogResult` in `MainEventHandlers.bs:246` has all three branches empty (`Play from beginning`, `Resume`, `Mark played`). This is a visible user-facing gap that can be completed in one session without touching the core. Effort: M.

3. **Quick Connect re-enable** — `quickConnectEnabled = false` is hardcoded in `ShowLoginScreen`. The API endpoint (`/QuickConnect/Initiate`) and the SDK wrapper (`api.quickConnect.Initiate()`) are both present. Effort: S. Very high user-visible value.

4. **Home screen sections driven by user settings** — `loadHomeRows()` hardcodes 4 sections. The settings JSON already has `homeScreenSection0-7` keys. Wiring these so users can reorder/hide sections would be a true differentiator vs other Jellyfin Roku clients. Effort: M.
