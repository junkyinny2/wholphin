# Plan 004 — Remove plain-text password storage from Roku registry

**Commit:** `c7ef21b`  
**Category:** Security  
**Impact:** HIGH — user passwords persisted to Roku registry in cleartext; readable by any channel on the device  
**Effort:** S  
**Risk of fix:** LOW  

---

## Why this matters

`source/ShowScenes.bs:268`:
```brightscript
if password <> "" then
    set_user_setting(userId, "password", password)
end if
```

This stores the user's Jellyfin password in the Roku registry under section `Wholphin_<userId>`, key `"password"`. Roku's registry is a shared local key-value store — while it is per-channel, it is not encrypted and is readable by anyone with physical device access.

More critically, the password is only used in one place (`Main.bs:162`) to authenticate with a saved credential:
```brightscript
savedPw = get_user_setting(userId, "password", "")
useSaved = userId <> "" and savedPw <> "" and savedPw <> invalid
if useSaved then
    ok = AuthenticateUser(username, savedPw)
```

The access token (`accessToken`) is already saved separately (`set_user_setting(userId, "accessToken", accessToken)` at `ShowScenes.bs:266`). The access token is sufficient to re-authenticate on next launch via `AboutMe()` (as done in `LoginFlow()` at line 127). **Saving the password at all is unnecessary.**

---

## Implementation

### File: `source/ShowScenes.bs`

**Location:** `AuthenticateUser()` function, lines 265-270

**Current code:**
```brightscript
userId = chainLookupReturn(authResult, ["User", "Id"], "")
if userId <> "" then
    set_user_setting(userId, "accessToken", accessToken)
    if password <> "" then
        set_user_setting(userId, "password", password)   ' ← REMOVE THIS
    end if
    set_setting("last_userId", userId)
end if
```

**Replace with:**
```brightscript
userId = chainLookupReturn(authResult, ["User", "Id"], "")
if userId <> "" then
    set_user_setting(userId, "accessToken", accessToken)
    ' Note: password is NOT saved. Access token is used for re-auth.
    set_setting("last_userId", userId)
end if
```

### File: `source/Main.bs`

**Location:** `pendingServerAction = "login"` handler, lines 158-163

**Current code:**
```brightscript
savedPw = get_user_setting(userId, "password", "")
useSaved = userId <> "" and savedPw <> "" and savedPw <> invalid
if useSaved then
    ? "[Main] authenticating with saved password"
    ok = AuthenticateUser(username, savedPw)
```

**Replace with:**
```brightscript
' No saved password — always check for saved token first
savedToken = get_user_setting(userId, "accessToken", "")
if savedToken <> "" then
    ? "[Main] found saved token, validating"
    session.user.Populate({ AccessToken: savedToken, User: { Id: userId } })
    myInfo = AboutMe()
    if myInfo <> invalid then
        session.user.UpdateFromAboutMe(myInfo)
        ? "[Main] token valid, loading home"
        ok = true
    else
        ? "[Main] token expired, showing signin"
        session.user.Clear()
        ok = false
    end if
else
    ? "[Main] no saved token, showing signin"
    ok = false
end if
if ok then
    CreateHomeGroup()
else
    ShowSignInScreen(username)
end if
```

### Cleanup — delete existing saved passwords

Add a one-time migration to `Main.bs` after `session_Init()` that removes any previously saved passwords:

```brightscript
' One-time migration: remove saved passwords (security fix)
lastUserId = get_setting("last_userId", "")
if lastUserId <> "" then
    ' Delete stored password if it exists
    registry_delete_user_key(lastUserId, "password")
end if
```

Add `registry_delete_user_key()` to `config.bs`:
```brightscript
function registry_delete_user_key(userId as String, key as String) as Void
    sectionName = "Wholphin_" + userId
    sec = CreateObject("roRegistrySection", sectionName)
    if sec.Exists(key) then
        sec.Delete(key)
        sec.Flush()
    end if
end function
```

---

## Files modified

| File | Change |
|------|--------|
| `source/ShowScenes.bs` | Remove `set_user_setting(userId, "password", password)` |
| `source/Main.bs` | Replace saved-password auth with saved-token auth + migration |
| `source/utils/config.bs` | Add `registry_delete_user_key()` |

---

## Verification

1. Deploy to `192.168.1.100`
2. Log in with credentials
3. Restart channel
4. **Expected:** auto-login using saved token (no password re-entry)
5. Using a registry inspector or logs: confirm no `"password"` key exists in `Wholphin_<userId>` registry section

---

## Maintenance note

Never store cleartext credentials (passwords, API keys) in `registry_write`. Access tokens are acceptable (they can be revoked server-side). If the token flow is insufficient for some use case, implement token refresh rather than password storage.

---

## Escape hatches

- If token-based re-auth fails for users without saved tokens, the fallback `ShowSignInScreen(username)` will prompt for credentials — this is correct behavior.
- Do not store a hashed password — the correct solution is to use the token.
