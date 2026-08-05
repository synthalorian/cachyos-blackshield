# Forge Hub Stimulus Controller Patterns

## Visual Pipeline Builder (`pipeline_builder_controller.js`)

Pattern for building a visual step-based UI that serializes to a backend-compatible format.

**Structure:**
- Targets: `stepsContainer`, `hiddenToml`, `collapsedInfo`, `expandedBody`
- Actions: `loadPreset`, `toggleExpand`, `addStep`, `removeStep`, `moveUp`, `moveDown`, `updateField`, `submitPipeline`
- Data params: `index` on buttons for step CRUD, `step-field` on inputs for field updates, `step-index` on cards

**Key patterns:**
- Presets defined as a const object at module level, loaded via `loadPreset(e)` reading `e.target.value`
- Steps stored as a plain JS array on the controller instance
- Two render methods: `renderCollapsed()` (summary chips) and `renderExpanded()` (full card forms)
- Serialization via `#serializeToml(steps)` producing TOML `[[steps]]` entries
- Hidden field (`hiddenToml`) populated before form submit via `#submitPipeline(e)`
- Private methods use `#` syntax: `#escapeHtml`, `#escapeToml`, `#serializeToml`

**When to reuse this pattern:**
- Any multi-step UI that serializes to a config format (TOML, JSON, YAML)
- Wizard-style interfaces with add/remove/reorder steps
- Visual builder replacing raw textarea input

## Drag-and-Drop File Upload (`palette_upload_controller.js`)

Pattern for file upload with drag-and-drop, preview, and async Turbo Stream response.

**Structure:**
- Targets: `input`, `preview`, `submit`, `error`, `format`
- Actions: `drop`, `dragOver` (on drop zone), `fileSelected` (on hidden input change)

**Key patterns:**
- Drop zone with `dragover`/`drop` event handlers; suppress browser defaults at document level
- File type validation (PNG/JPG) and size validation (max 10MB)
- In-browser preview via `FileReader` → data URL → `<img>` tag
- Async upload via `fetch()` with `FormData` and `Accept: text/vnd.turbo-stream.html`
- Server response rendered via `Turbo.renderStreamMessage()`
- Loading state: disable button, show "Extracting..." text

**When to reuse this pattern:**
- Any image/file upload that should stay on the same page via Turbo Streams
- Drag-and-drop UX in synthwave-styled Hub pages

## Sidebar Collapse + Mobile Overlay (`sidebar_controller.js`)

Pattern for responsive sidebar with desktop collapse and mobile slide-out.

**Structure:**
- Targets: `sidebar`, `toggleIcon`, `overlay`
- Classes: `collapsed` (via `static classes = ["collapsed"]`)
- State persisted to `localStorage`

**Key patterns:**
- Desktop: sidebar collapses to minimal width via CSS class toggle
- Mobile (`max-sm:`): sidebar becomes fixed-position, slides off-screen via `-translate-x-full`
- Dark overlay appears when sidebar is open on mobile, click-to-dismiss via `data-action="click->sidebar#toggle"`
- Collapse state persisted in `localStorage("forge:sidebar:collapsed")`
- Topbar toggle button calls `toggle()` on the sidebar controller
