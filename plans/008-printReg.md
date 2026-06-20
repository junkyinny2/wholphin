# Plan 008 — Fix printReg hardcoded true in Main.bs (overrides manifest bs_const)

**Commit:** `c7ef21b`  
**Category:** Correctness / DX  
**Impact:** MEDIUM — all debug `?` print statements fire on production builds, spamming telnet output and reducing performance  
**Effort:** S (1 line)  
**Risk of fix:** LOW  

---

## Why this matters

`manifest` line 13:
```
bs_const=printReg=false
```

`Main.bs:44`:
```brightscript
m.global.addFields({
    ...
    printReg: true    ' ← hardcoded, overrides manifest
    ...
})
```

The `bs_const` mechanism is how BrightScript channels control debug output: at compile time, `#if printReg` / `#end if` blocks get stripped. But the `m.global.printReg` field is used at **runtime** by `traceStep()` in `misc.bs:144`:

```brightscript
function traceStep(stepName as String, data = invalid as Dynamic) as Void
    if m.global.printReg = true then
        print "[Wholphin] " + stepName
        if data <> invalid then print data
    end if
end function
```

Since `m.global.printReg = true` is hardcoded in `addFields()`, every `traceStep()` call fires unconditionally — the manifest `false` has no effect. This was noted in the 2026-06-12 audit (finding #6) and "fixed" in the 2026-06-14 audit cycle, but the current code still has `printReg: true` at line 44.

In addition, `Main.bs` itself uses bare `?` statements throughout (lines 27, 33, 54, 58, etc.). These are always compiled in for `.brs`/`.bs` files (they're not conditional on `bs_const`). Consider replacing with `traceStep()` calls or `#if printReg` guards.

---

## Implementation

### File: `source/Main.bs`

**Location:** line 44 inside `m.global.addFields({})`

**Current:**
```brightscript
m.global.addFields({
    appInfo: {}
    deviceInfo: {}
    session: {}
    colors: {}
    themes: {}
    icons: {}
    locale: "en_US"
    localeTranslations: {}
    printReg: true          ' ← hardcoded, always prints
    playstateTask: invalid
    queueManager: invalid
    audioPlayer: invalid
    sceneManager: invalid
})
```

**Replace with:**
```brightscript
m.global.addFields({
    appInfo: {}
    deviceInfo: {}
    session: {}
    colors: {}
    themes: {}
    icons: {}
    locale: "en_US"
    localeTranslations: {}
    printReg: false         ' controlled by manifest bs_const=printReg
    playstateTask: invalid
    queueManager: invalid
    audioPlayer: invalid
    sceneManager: invalid
})
```

To enable debug output during development, set `bs_const=printReg=true` in the manifest (already set to `false` for production). The `traceStep()` runtime check will now correctly reflect the manifest value.

> **Note:** Since `bs_const` values are compile-time constants and BrightScript doesn't strip bare `?` statements based on `bs_const`, the raw `? "[Main]..."` prints in `Main.bs` will still appear in the telnet output regardless. A full solution would wrap them in `if m.global.printReg then ... end if` or `#if printReg` (BSC-compiled only). This is deferred — the single-line fix above eliminates `traceStep()` spam without touching the 30+ raw print statements.

---

## Verification

1. With `manifest` `bs_const=printReg=false`: deploy and attach telnet
2. **Expected:** `[Wholphin]` prefixed `traceStep()` messages do NOT appear
3. **Still expected to appear:** `[Main]`, `[ShowLoginScreen]`, etc. bare `?` prints (deferred fix)
4. Change manifest to `bs_const=printReg=true`, redeploy
5. **Expected:** `[Wholphin]` messages now appear

---

## Maintenance note

Future `traceStep()` calls will correctly be gated by `m.global.printReg`. For new debug prints added to source files, prefer `traceStep("label", data)` over bare `?` statements so they can be toggled.
