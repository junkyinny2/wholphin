Phase 0 — Stop and get reference material



Before more code changes, tell the AI:



Pull actual screenshots/screen recordings of the original wholphin Android TV app, screen by screen.

Extract the original app's color values, font names/sizes, spacing, and icon assets rather than reconstructing them from memory.

List every screen and every focusable element on it (buttons, list items, tiles) as a checklist. This becomes the source of truth for "does it match" instead of vibes.

Phase 1 — Fix the architecture first, not the symptoms



Android TV apps are built from Views/Fragments with an implicit focus system. Roku uses SceneGraph, which requires everything to be explicit. Tell the AI to verify, for the whole app:



Is the app built as a proper SceneGraph component tree (Scene → Groups/LayoutGroups → child components), not a flat dump of drawing commands?

Is each screen its own .xml/.brs component pair, not one giant monolith?

Is a consistent 1920x1080 coordinate system used with proper scaling, instead of raw dp values carried over from Android?



If the architecture is wrong, fixing individual buttons will keep breaking other things — this needs to be right before anything else.



Phase 2 — Fix focus management (this is almost certainly why buttons "keep breaking")



This is the #1 cause of exactly the symptom you're describing. Instruct the AI to check, per screen:



Every focusable node explicitly sets focusable="true".

There is one, and only one, component owning onKeyEvent per screen at a time — no competing/duplicate key handlers.

Focus changes happen via explicit setFocus() calls, not assumed automatically like Android's focus chain.

Up/Down/Left/Right/OK/Back are handled explicitly in onKeyEvent, returning true when handled and false when not (a common bug: forgetting to return false lets events get eaten and breaks remote nav elsewhere).

Focus state is visually reflected (focused vs unfocused states) via itemFocused/ChangeToState-style patterns, not just assumed.



Have the AI list out the current focus handling for every screen and identify overlaps/gaps before touching visuals.



Phase 3 — Fix visual fidelity screen-by-screen



Now, one screen at a time (not all at once):



AI implements/adjusts the screen.

AI (or you) takes a screenshot of the Roku app running that screen.

Compare side-by-side against the Phase 0 reference screenshot.

AI lists specific deltas (spacing off by X, wrong font, wrong color hex, misaligned poster grid, etc.) and fixes only those.

Don't move to the next screen until this one visually matches.



This stops the "whack-a-mole" pattern where fixing screen B re-breaks screen A.



Phase 4 — Regression pass



Once all screens individually match, do a full click-through with the AI simulating actual remote navigation:



Every screen: can you reach every button using only Up/Down/Left/Right?

Does Back always go to the expected previous screen (Roku's scene stack, not Android's back stack, needs to be explicit)?

Does OK/Select always trigger the right action with no dead zones?

Phase 5 — Lock it down



Ask the AI to write a short "known good" checklist per screen (focus order, expected visuals, key bindings) so future changes get tested against it instead of silently regressing again.



"Don't try to fix multiple screens or issues at once. Pick one screen, diagnose root cause (architecture vs focus vs visual), fix only that, verify visually and via remote nav, then 

move to the next screen."

