Core references (all phases)
Official dev docs hub: https://developer.roku.com/dev/docs — the canonical source; everything below links off this.
Machine-readable index for AI agents: https://developer.roku.com/dev/llms.txt This gives an index of all documentation pages formatted in Markdown with endpoints in OpenAPI — worth feeding directly to the AI so it can navigate the docs itself instead of guessing. 
Roku
Docs source repo (searchable/greppable): https://github.com/rokudev/dev-doc — the official GitHub repository for Roku developer documentation, the primary technical resource for building, publishing, and monetizing apps on Roku. 
GitHub
SceneGraph BrightScript reference: https://developer.roku.com/dev/docs/scenegraph-brightscript — covers the roSGScreen and roSGNode objects that let SceneGraph technology be used from BrightScript, including the ordering required to create a screen and set up its Scene node. 
Roku
BrightScript restrictions inside SceneGraph: https://developer.roku.com/dev/docs/brightscript-support — documents which BrightScript functions/components can't be used in SceneGraph component scripts (often because a SceneGraph node already does that job), and which ones only work inside a Task node. Good to check during Phase 1 architecture review. 
Roku
Phase 1 — Architecture (SceneGraph structure)
Developing SceneGraph applications: https://developer.roku.com/docs/developer-program/core-concepts/developing-scenegraph-applications.md — explains the components directory structure, where each XML component file must have a matching .brs file, and each XML component contains a single <component> element defining a specific SceneGraph node tree. Also shows the pattern for creating and switching between scenes via roSGScreen — directly relevant to verifying each screen is its own component pair rather than a monolith. 
Roku
Roku
Phase 2 — Focus management (the likely root cause)
onKeyEvent() reference: https://developer.roku.com/dev/docs/onkeyevent — explains that onKeyEvent() fires when the XML component or its children hold key focus and an unhandled key event bubbles up the focus chain, and notes that some node classes like PosterGrid automatically handle Up/Down/Left/Right internally — relevant when auditing for duplicate/competing key handlers. 
Roku
Roku
Handling application events: https://developer.roku.com/dev/docs/handling-application-events — shows the setFocus(true)/findNode/ObserveField pattern in init(), and confirms onKeyEvent() must return true if handled or false if not — false lets the event keep bubbling up the focus chain so ancestors can handle it. That "must return false or you eat the event" detail is exactly the bug class your roadmap flags. 
Roku
Community thread on setFocus pitfalls: https://community.roku.com/t5/Roku-Developer-Program/setFocus-question/td-p/502465 — real-world discussion of focus disappearing into the scene when setFocus(false) is called directly on a component, and the workaround pattern of losing focus on the child before returning focus to the parent. Useful concrete example of the "who owns focus" bug. 
Roku Community
Phase 3–4 — Visual fidelity, coordinate system, navigation
Search the dev-doc repo or developer.roku.com for LayoutGroup, render-tracking, and 1920x1080 — the docs site's search works well once the AI has the llms.txt index loaded.
Tooling (useful across all phases)
BrighterScript (typed superset + tooling): https://github.com/rokucommunity — org hosting brighterscript, vscode-brightscript-language, bslint, rooibos (test framework), and ropm (package manager). bslint is a linter for BrightScript and BrighterScript; rooibos is a flexible test framework for Roku SceneGraph apps; ropm is a package manager for the Roku platform — worth having the AI lint against bslint during Phase 2/3 to catch missing return false and similar bugs mechanically instead of by eye. 
github

One practical suggestion for your Phase 0: point the AI at developer.roku.com/dev/llms.txt explicitly and tell it to fetch and index that before starting Phase 1 — it's built specifically so an AI agent can pull the whole doc set programmatically instead of relying on training-data memory of BrightScript, which is where a lot of "compiles but doesn't behave right" code comes from in the first place.