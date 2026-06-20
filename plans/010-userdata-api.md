# Plan 010 — Fix MarkPlayed / MarkFavorite call sites and missing UserData API

**Commit:** `c7ef21b`  
**Category:** Correctness  
**Impact:** MEDIUM — "Mark Played", "Add to Favorites", and "Remove from Favorites" buttons in MovieDetails and other detail screens do nothing because `api.users.MarkPlayed()` and `api.users.MarkFavorite()` exist in sdk.bs but the call sites pass wrong args  
**Effort:** S  
**Risk of fix:** LOW  

---

## Why this matters

`source/api/sdk.bs:849-863` — the correct API wrappers exist:
```brightscript
function MarkPlayed(itemId as String, userId = "" as String) as Object
    if userId = "" then userId = session.user.GetId()
    req = APIRequest("/Users/" + userId + "/PlayedItems/" + itemId)
    return postJson(req, {})
end function

function MarkFavorite(itemId as String, userId = "" as String) as Object
    if userId = "" then userId = session.user.GetId()
    req = APIRequest("/Users/" + userId + "/FavoriteItems/" + itemId)
    return postJson(req, {})
end function
```

However, searching the component files reveals that `MovieDetails.bs` and other detail screens use `observeField("buttonSelected", m.port)` for the favorite/played buttons — and because `m.port` is `invalid` (see Plan 001), those button presses never fire. After Plan 001 is applied, these callbacks will fire — but we need to verify the implementations are complete.

Additionally, the `UserSelect.bs` dialog at line 99 calls `dialog.observeField("buttonSelected", m.port)` — same port issue.

---

## Audit required before implementing

Before writing code, open `components/movies/MovieDetails.bs` and verify:
1. What function handles the `btnFavorite.buttonSelected` callback?
2. What does it call — does it call `api.users.MarkFavorite(itemId)` or is the body empty/stub?
3. Same for `btnPlay`, `btnResume`, `btnMyList` (MarkPlayed)

Run:
```powershell
Select-String -Path "components/**/*.bs" -Pattern "MarkFavorite|MarkPlayed|UnmarkFavorite|UnmarkPlayed" -Recurse
```

If results are empty or the call sites are stubs, implement them.

---

## Expected implementation (if stubs found)

### `components/movies/MovieDetails.bs` — button handlers

```brightscript
sub onFavoritePressed()
    itemId = m.top.movie.id
    if m.top.isFavorite then
        api.users.UnmarkFavorite(itemId)
        m.top.isFavorite = false
        m.btnFavorite.buttonText = translateText("Add to Favorites")
    else
        api.users.MarkFavorite(itemId)
        m.top.isFavorite = true
        m.btnFavorite.buttonText = translateText("Remove from Favorites")
    end if
end sub

sub onPlayedPressed()
    itemId = m.top.movie.id
    api.users.MarkPlayed(itemId)
    m.top.isPlayed = true
    ' Update UI indicator
    m.playedBadge.visible = true
end sub
```

Note: These functions make synchronous API calls on the render thread (same problem as Plan 003). Ideally they'd be moved to a task, but for a quick fire-and-forget (no returned data needed for UI update), synchronous is acceptable as long as the server is fast (<1s).

---

## Files to check / modify

| File | Check for |
|------|-----------|
| `components/movies/MovieDetails.bs` | Favorite/Played button handler implementations |
| `components/tvshows/TVSeriesDetails.bs` | Same — series details likely has same buttons |
| `components/tvshows/TVSeasonDetails.bs` | Episode played marking |

---

## Verification

1. Apply Plan 001 first (m.port fix)
2. Deploy, navigate to a movie
3. Press the Favorite button → movie should be favorited on Jellyfin server
4. Navigate to Home → Favorites row should show the movie
5. Press the Favorite button again → should unfavorite

---

## Dependency

This plan depends on **Plan 001** being applied first. Without the m.port fix, button observers never fire regardless of implementation.
