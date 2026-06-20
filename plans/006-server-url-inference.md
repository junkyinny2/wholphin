# Plan 006 — Fix inferServerUrl default port/scheme for common self-hosted Jellyfin installs

**Commit:** `c7ef21b`  
**Category:** Correctness / UX  
**Impact:** MEDIUM — users entering bare IP addresses (most common case for self-hosted Jellyfin) get wrong URL  
**Effort:** S  
**Risk of fix:** LOW  

---

## Why this matters

`source/utils/parsedUrl.bs:77-103` — `inferServerUrl()`:

```brightscript
function inferServerUrl(input as String) as String
    ...
    if hasPort then
        if input.Instr("8096") > 0 then
            scheme = "http://"
        end if
        return scheme + input
    else
        ' Default to HTTPS on port 8920 (Jellyfin default HTTPS port)
        return "https://" + input + ":8920"
    end if
end function
```

**Problems:**

1. **When no port is entered** (e.g., `192.168.1.100`): the code appends `:8920` (Jellyfin's HTTPS port). But most self-hosted Jellyfin installs on a LAN use **port 8096 over HTTP** by default. A user entering `192.168.1.100` gets `https://192.168.1.100:8920`, which will fail to connect for the majority of local installs.

2. **When port 8096 is entered** (e.g., `192.168.1.100:8096`): code correctly uses `http://`. This works.

3. **Port detection** uses `.Instr("8096") > 0`, which matches any URL containing the string "8096" anywhere (e.g. `192.168.18096:443` would incorrectly match). Should compare the actual port part.

4. **`buildUrlWithParams()` at line 106-123** does NOT URL-encode parameter values (uses `.ToStr()` directly). This is a separate bug where parameters with special characters would break query strings. This is lower severity since most current params are numeric.

---

## The real-world Jellyfin URL patterns

| User enters | What they mean | What we should produce |
|-------------|---------------|----------------------|
| `192.168.1.100` | LAN Jellyfin, default port | `http://192.168.1.100:8096` |
| `192.168.1.100:8096` | LAN Jellyfin, explicit HTTP | `http://192.168.1.100:8096` |
| `192.168.1.100:8920` | LAN Jellyfin, HTTPS | `https://192.168.1.100:8920` |
| `192.168.1.100:443` | HTTPS reverse proxy | `https://192.168.1.100:443` |
| `myjellyfin.com` | Public, HTTPS | `https://myjellyfin.com:8920` or better: just `https://myjellyfin.com` |
| `myjellyfin.com:443` | Public, standard HTTPS | `https://myjellyfin.com:443` |

The current code's assumption (HTTPS default, port 8920) is wrong for local installs.

---

## Implementation

### File: `source/utils/parsedUrl.bs`

**Replace `inferServerUrl()` (lines 77-103):**

```brightscript
' Infer a server URL from a partial input (add scheme and port if missing)
function inferServerUrl(input as String) as String
    input = input.Trim()
    if input = "" then return ""
    
    ' If it already has a scheme, return as-is (already fully qualified)
    if input.Left(7) = "http://" or input.Left(8) = "https://" then
        return input
    end if
    
    ' Parse out host and port
    colonPos = input.Instr(":")
    if colonPos > 0 then
        portStr = input.Mid(colonPos + 1)
        portNum = Val(portStr)
        
        ' Determine scheme from well-known port numbers
        if portNum = 443 or portNum = 8920 then
            return "https://" + input
        else
            ' 8096, 8097, custom HTTP ports — use HTTP
            return "http://" + input
        end if
    else
        ' No port specified — default to Jellyfin HTTP LAN default
        ' (most common for self-hosted: http on 8096)
        return "http://" + input + ":8096"
    end if
end function
```

**Rationale:** The Jellyfin default installation listens on `http://0.0.0.0:8096`. Most users on a LAN never configure HTTPS. Users who have HTTPS set up will know to enter `:8920` or `:443` or a full `https://` URL. Defaulting to HTTP:8096 is correct for the majority case.

---

## Verification

1. Deploy to `192.168.1.100`
2. On the server setup screen, enter each of the following and confirm correct URL inference in the debug log:
   - `192.168.1.9` → should show `http://192.168.1.9:8096`
   - `192.168.1.9:8096` → should show `http://192.168.1.9:8096`
   - `192.168.1.9:8920` → should show `https://192.168.1.9:8920`
   - `192.168.1.9:443` → should show `https://192.168.1.9:443`
   - `myjellyfin.com` → should show `http://myjellyfin.com:8096`
   - `https://myjellyfin.com` → should be returned as-is

---

## Escape hatch

If a user's Jellyfin is only reachable on HTTPS (common with reverse proxies), they will need to prefix `https://` manually — document this in the server entry screen hint text. Add hint text to `SetServerScreen.xml` as a `Label` below the input field:
```
"Tip: Enter IP (e.g. 192.168.1.100) or full URL (e.g. https://myjellyfin.com)"
```
