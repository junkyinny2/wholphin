# Plan 005 — Remove Roku credentials from source-controlled bsconfig.deploy.json

**Commit:** `c7ef21b`  
**Category:** Security  
**Impact:** HIGH — Roku device password `&lt;PASSWORD&gt;` committed to git history in `bsconfig.deploy.json:5`  
**Effort:** S  
**Risk of fix:** LOW  

---

## Why this matters

`bsconfig.deploy.json:4-5`:
```json
"host": "192.168.1.100",
"username": "<USERNAME>",
"password": "<PASSWORD>",
```

This file is tracked by git (`c7ef21b`). The Roku device password is in version history. If this repo is ever pushed to GitHub (public or private with a leak), the credential is exposed.

Additionally, `deploy_roku.ps1` likely contains similar hardcoded values (confirmed in audit — `history.md` notes "Deploy creds in git (bsconfig.deploy.json:4-5, deploy_roku.ps1:6-7)").

The password also appears in what appears to be a user-defined password (`&lt;PASSWORD&gt;`), suggesting it's a personally chosen credential, not a randomly generated one.

---

## Implementation

### Step 1 — Create `bsconfig.deploy.local.json` (gitignored)

This file holds the real credentials and is excluded from git:

```json
{
  "extends": "bsconfig.deploy.json",
  "password": "YOUR_ROKU_PASSWORD_HERE"
}
```

### Step 2 — Remove password from `bsconfig.deploy.json`

**Current `bsconfig.deploy.json`:**
```json
{
  "extends": "bsconfig.json",
  "host": "192.168.1.100",
  "username": "<USERNAME>",
  "password": "<PASSWORD>",
  ...
}
```

**Replace with:**
```json
{
  "extends": "bsconfig.json",
  "host": "192.168.1.100",
  "username": "<USERNAME>",
  "password": "",
  ...
}
```

> Note: Leave `host` and `username` — those are not secrets. The password field is set to empty string as a placeholder.

### Step 3 — Update `.gitignore`

Add to `.gitignore`:
```
bsconfig.deploy.local.json
.env
*.local.json
```

### Step 4 — Update `deploy_roku.ps1` to read password from environment or prompt

Check `deploy_roku.ps1` lines 6-7. If password is hardcoded:

```powershell
# BEFORE (hardcoded):
$password = "<PASSWORD>"

# AFTER (reads from env var, prompts if missing):
$password = $env:ROKU_PASSWORD
if (-not $password) {
    $password = Read-Host "Enter Roku password" -AsSecureString | ConvertFrom-SecureString -AsPlainText
}
```

Alternatively, read from a local `.env` file that is gitignored.

### Step 5 — Rotate the credential

**After** removing the password from source control, change the Roku device password to a new value via the device's developer settings (`http://192.168.1.100`). The old password `&lt;PASSWORD&gt;` is in git history and cannot be un-committed without a full history rewrite.

Update `bsconfig.deploy.local.json` with the new password.

---

## Files modified

| File | Change |
|------|--------|
| `bsconfig.deploy.json` | Clear password field to empty string |
| `.gitignore` | Add `bsconfig.deploy.local.json` and `*.local.json` |
| `deploy_roku.ps1` | Read password from env var or prompt |

**New file:**
| File | Purpose |
|------|---------|
| `bsconfig.deploy.local.json` | Local-only credentials, gitignored |

---

## Verification

```powershell
# Confirm no password in tracked files
git grep "<PASSWORD>" -- "*.json" "*.ps1"
# Expected: no results
```

```powershell
# Confirm deploy still works
powershell -File deploy_roku.ps1
# Should prompt for password or read from ROKU_PASSWORD env var
```

---

## Maintenance note

Never commit credentials to source control. When deploying CI/CD in the future, inject `ROKU_PASSWORD` as a secret environment variable rather than storing in any file.

---

## Escape hatch

If a full history rewrite to remove the old password from git history is desired, use `git filter-repo --path bsconfig.deploy.json --invert-paths` or BFG Repo-Cleaner. This is optional but recommended if the repo will be made public.
