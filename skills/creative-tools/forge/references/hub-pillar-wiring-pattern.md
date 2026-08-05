# Hub Pillar Wiring — Architecture & Pattern

Each of the six Forge Hub pillars (Anvil, Bellows, Flame, Tongs, Crucible, Bridge) follows the same architectural pattern. This reference documents the Crucible pillar as a complete example of a Turbo Stream-based bridge between the Rails Hub and the forge CLI binary.

## Pillar Architecture

```
Browser                        Rails Hub                       forge CLI (binary)
┌──────────┐   Turbo Stream    ┌──────────────────────┐        ┌───────────────┐
│ Form POST │ ───────────────→ │ CrucibleController    │        │ forge melt    │
│  (Turbo)  │                  │  ├── index (GET)      │───────→│  chords       │
│           │                  │  ├── chords (POST)    │        │  palette      │
│           │                  │  ├── palette (POST)   │        │  diagram      │
│           │                  │  └── diagram (POST)   │        └───────────────┘
│           │                  │          │             │
│           │←────────────────│ Turbo Stream response  │
│  Partial  │                  │  (replaces #crucible-  │
│  replaced │                  │   output via _command_ │
│           │                  │   output partial)      │
└──────────┘                  └──────────────────────┘
```

## Files Needed for a New Pillar

For a pillar with CLI bridge + Turbo Stream outputs:

| File | Purpose | Pattern |
|------|---------|---------|
| `app/controllers/<pillar>_controller.rb` | Controller with `index` + action methods | Include `AnvilHelper` for utilities |
| `app/views/<pillar>/index.html.erb` | Main view with forms and output container | Forms use `form_tag(method: :post, data: { turbo: true })` |
| `app/views/<pillar>/_command_output.html.erb` | Partial rendered by Turbo Stream | Receives `output` (string) and `title` (string) as locals |
| `config/routes.rb` | Route each action | `GET /<pillar>` for index, `POST /<pillar>/<action>` for CLI invocations |
| `app/javascript/controllers/<feature>_controller.js` | Stimulus controller for interactive UI | Register via filename pattern (auto-discovered) |

## Controller Pattern

```ruby
class CrucibleController < ApplicationController
  include AnvilHelper

  def index
    @forge_available = forge_available?
    return unless @forge_available
    @chord_examples = generate_chord_examples
    @palette_example = generate_palette_example
  rescue StandardError
    @forge_available = false
    @chord_examples = []
    @palette_example = nil
  end

  # Each action: validates, runs forge CLI, returns Turbo Stream
  def chords
    key = params[:key].presence || "C"
    @output = run_forge_command(["melt", "chords", key])
    render turbo_stream: turbo_stream.replace("crucible-output",
      partial: "crucible/command_output",
      locals: { output: @output, title: "Chord Progression" })
  end

  private

  def forge_available?
    File.exist?(Forge::Config.db_path)
  rescue StandardError
    false
  end

  def run_forge_command(args)
    return "Forge not available" unless forge_available?
    bin = Forge::Client.new(path: nil).bin_path
    return "Forge binary not found" unless bin
    stdout, stderr, status = Open3.capture3(bin, *args)
    status.success? ? stdout : "Error: #{stderr}"
  rescue StandardError => e
    "Error: #{e.message}"
  end
end
```

## Partial Pattern

The `_command_output.html.erb` partial lives at `app/views/<pillar>/_command_output.html.erb`:

```erb
<div class="rounded-xl bg-bg-panel border border-border-faint p-6">
  <div class="flex items-center gap-2 mb-4">
    <span class="text-neon-cyan text-xs font-mono">▸</span>
    <h4 class="text-sm font-semibold text-text-primary font-mono"><%= title %></h4>
  </div>
  <% if output.to_s.strip.empty? %>
    <div class="text-center py-8 text-text-dim">
      <p class="text-sm font-mono">No output returned</p>
    </div>
  <% else %>
    <pre class="rounded-lg bg-bg-dark/80 border border-border-faint p-4
                text-xs font-mono text-neon-cyan leading-relaxed
                overflow-x-auto whitespace-pre-wrap"><%= output %></pre>
  <% end %>
</div>
```

## Routes Pattern

```ruby
get "/<pillar>" => "<pillar>#index"
post "/<pillar>/<action1>" => "<pillar>#<action1>"
post "/<pillar>/<action2>" => "<pillar>#<action2>"
```

## View Pattern (Turbo Stream Forms)

The view must have an output container with a stable ID that Turbo Stream replaces:

```erb
<%= form_tag crucible_chords_path, method: :post, data: { turbo: true } do %>
  <%= text_field_tag :key, "C" %>
  <%= submit_tag "Generate" %>
<% end %>

<div id="crucible-output" class="rounded-xl bg-bg-panel border border-border-faint p-6">
  <div class="text-center py-8 text-text-dim">
    <p class="text-sm font-mono">Generate something to see the result</p>
  </div>
</div>
```

## Stimulus Tab Controller Pattern

When a pillar has multiple modes (tabs), use a Stimulus controller with sessionStorage persistence:

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["tab", "panel"]

  connect() {
    const saved = sessionStorage.getItem("forge_<pillar>_tab")
    if (saved) this.selectTab(saved)
  }

  select(e) {
    const tab = e.currentTarget.dataset.tab
    sessionStorage.setItem("forge_<pillar>_tab", tab)
    this.selectTab(tab)
  }

  selectTab(tab) {
    this.tabTargets.forEach(el => {
      const isActive = el.dataset.tab === tab
      el.classList.toggle("text-neon-cyan", isActive)
      el.classList.toggle("border-b-2", isActive)
      el.classList.toggle("border-neon-cyan", isActive)
      el.classList.toggle("text-text-muted", !isActive)
      el.classList.toggle("border-transparent", !isActive)
    })
    this.panelTargets.forEach(el => {
      el.style.display = el.dataset.tab === tab ? "" : "none"
    })
  }
}
```

## Key Implementation Notes

1. **Each action must have its own unique output container ID** — NEVER share one `id` across multiple tab panels or forms. If two forms both target `turbo_stream.replace("crucible-output")`, the Turbo Stream always replaces the *first* element with that ID in the DOM, meaning the other tabs' output divs are never updated even when visible. Pattern: `crucible-chords-output`, `crucible-palette-output`, `crucible-diagram-output`.
2. **All `POST` actions render `turbo_stream`** — never redirect, never render HTML directly
3. **The `forge_available?` guard** must run on every action, not just `index`, since Turbo Stream requests can arrive with stale forge state
4. **`sessionStorage` for tab persistence** is preferred over `localStorage` — it resets per browser tab, avoiding stale state across multi-window workflows
5. **Error handling** should gracefully degrade to "Forge not available" text rather than raising 500 errors
6. **CLI/UI feature parity must be verified** — before adding Hub dropdowns, selectors, or form options that map to CLI flags, check what the Rust CLI actually supports. The Hub should never offer options the CLI will silently reject or ignore (e.g., palette harmonies `tetradic`/`monochromatic`/`split-complementary` don't exist in the forge melt palette CLI; diagram types `network`/`ascii` aren't implemented). View the CLI source or run `forge help` on the relevant command first.
7. **Stimulus controllers for form logic** — prefer creating a `controllers/<feature>_controller.js` file for any form-wiring logic (bridging input values, dynamic submission). Auto-registered via `eagerLoadControllersFrom` — the filename `dotfile_track_controller.js` becomes `data-controller="dotfile-track"`. Avoid inline `<script>` tags which break Turbo's lifecycle guarantees.
