# Rails + Rust Backend Architecture (Hermes Wingman)

## Architecture Overview

```
Browser ──HTTP──> Rails (port 9121) ──Net::HTTP──> Rust Backend (port 9120)
```

The Rails app is a **thin proxy** — it never calls `hermes` directly. Every controller action delegates to `HermesApiService` which communicates with the Rust backend via `Net::HTTP`.

## Controller Patterns

### API Controller (JSON endpoints for JavaScript)

Every API controller action follows the exact same pattern:

```ruby
class ApiController < ApplicationController
  def cli_doctor
    render json: HermesApiService.run_doctor
  rescue HermesApiService::BackendError => e
    render json: { error: e.message }
  end
end
```

All routes registered in `namespace :api` block in `routes.rb`.

### View Controller (HTML pages)

View controllers render ERB templates that include JavaScript to fetch from `/api/*` endpoints:

```ruby
class CliToolsController < ApplicationController
  def index
  end
end
```

```erb
<%# views/cli_tools/index.html.erb %>
<button onclick="runCli('doctor')">Run Doctor</button>
<div id="cli-output"></div>
```

Keep controllers thin — they're just route handlers.

## Route Registration Pattern

```ruby
Rails.application.routes.draw do
  root "dashboard#show"

  # View pages (one line each)
  resources :sessions, only: [:index, :show]
  resource :cli_tools, only: [:show], controller: :cli_tools, path: '/cli_tools'

  # JSON API endpoints (namespaced)
  namespace :api do
    get :health
    get :sessions
    get :cli_doctor
    post :cli_backup
    # ... one line per endpoint
  end

  # Form POST handlers (theme, gateway toggle, etc.)
  post "theme/:name", to: "theme#switch", as: :switch_theme
end
```

## Theme Switching with Turbo

**PITFALL:** Theme forms must have `data-turbo="false"` because Turbo Drive intercepts POST submissions and prevents session cookie updates:

```erb
<form action="/theme/<%= id %>" method="post" data-turbo="false">
  <%= token_tag %>
  <button type="submit">Switch Theme</button>
</form>
```

Without this, the session `:theme` is never persisted and themes appear to do nothing.

## Layout with Sidebar

The sidebar is rendered in `application.html.erb` as an HTML nav element with emoji-based icons. No JavaScript framework needed:

```erb
<nav class="sidebar">
  <a href="/" class="sidebar-logo"><img src="/assets/hermes-wingman.png" alt="HW" width="32"></a>
  <% nav_items.each do |path, icon, label| %>
    <a href="<%= path %>" class="sidebar-item <%= 'active' if current_page?(path) %>"
       title="<%= label %>"><%= icon %></a>
  <% end %>
</nav>
```

The `current_page?` helper highlights the active nav item. Define `nav_items` as a local array in the layout.

## File Explorer View

For system-wide file browsing, use the `/api/files?path=` endpoint that the Rust backend provides. The JS view calls `fetch('/api/files?path=' + encodeURIComponent(path))` and renders the result.

## Key Differences from Desktop App

| Aspect | Desktop (Flutter) | Web (Rails) |
|--------|------------------|-------------|
| Rendering | CustomPaint, widgets | HTML+CSS, var(--) themes |
| API calls | `HttpClient` from Dart | `Net::HTTP` from Ruby |
| Chat | SSE streaming via EventSource | SSE via EventSource from JS |
| State | ChangeNotifier per screen | Session + fetch from JS |
| Real-time | WebSocket/SSE | meta refresh + fetch polling |

Both share the same Rust backend on port 9120.