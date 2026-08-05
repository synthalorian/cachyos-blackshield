# Janus API Client Pattern

## Context

A Rails 8 web app consuming a large external Node.js/Express JSON API (60+ endpoints). The Rails app is a **pure client** — no own database, no models. All data comes from the Janus API. Auth is session-based: register via the Janus API, store the JWT in the Rails session.

## Architecture

```
Browser ──HTTP──> Rails (src/web/) ──JSON──> Janus Node.js API (port 3001)
                         │
                    session[:janus_token]
                         │
                    JanusApi service object
```

## Key Files

| File | Purpose |
|------|---------|
| `app/services/janus_api.rb` | Service object — class methods for all 60+ endpoints |
| `app/controllers/concerns/auth_concern.rb` | Session auth: `register`, `authenticate!`, `current_user`, `current_theme` |
| `app/controllers/janus_controller.rb` | All view controllers: dashboard, chat, bots, souls, etc. |
| `app/assets/tailwind/application.css` | Theme engine — 7 themes via CSS custom properties on `[data-theme]` |

## Auth Flow

1. User hits `/login` → `AuthController#index` renders auth form
2. POST `/login` → `AuthController#login` calls `JanusApi.register(name:, type:)`
3. Register response includes `{ user, token, apiKey }` — store in `session`
4. `JanusApi.auth_token = token` — all subsequent requests use this token
5. `ApplicationController` includes `AuthConcern` which adds `before_action :authenticate!`

```ruby
# AuthConcern — critical patterns:
included do
  helper_method :current_user, :authenticated?, :current_token, :current_theme
  before_action :authenticate!
end

def store_auth(user_data, token)
  session[:janus_user] = { "id" => user_data["id"], "name" => user_data["name"], "type" => user_data["type"] }
  session[:janus_token] = token
  JanusApi.auth_token = token
end
```

## Service Object Structure

All endpoints are class methods returning parsed JSON:

```ruby
class JanusApi
  BASE_URL = ENV.fetch("JANUS_API_URL", "http://localhost:3001")

  class BackendError < StandardError; end
  class AuthError < StandardError; end

  # Thread-local auth token (set after login)
  class << self
    attr_writer :auth_token
    def auth_token
      @auth_token
    end
  end

  # ── One method per endpoint ──────────────────
  def self.list_channels
    get("/api/channels")
  end

  def self.send_message(content:, author_id:, author_name:, author_type:, channel_id:)
    post("/api/messages", {
      content: content, authorId: author_id, authorName: author_name,
      authorType: author_type, channelId: channel_id
    }.compact)
  end
  # ... repeat for all 60+ endpoints
end
```

## Error Handling Pattern

Every controller action wraps API calls:

```ruby
def dashboard
  @health = JanusApi.health
  @stats = JanusApi.stats
rescue JanusApi::BackendError
  @health = { "status" => "error" }
  @stats = {}
end
```

Views check `@error` and render styled banners:

```erb
<% if @error %>
  <div class="flash flash-alert">⚠ <%= @error %></div>
<% end %>
```

## Theme System

7 themes via `[data-theme]` attribute on `<html>`:

```erb
<html data-theme="<%= session[:theme] || 'synthwave84' %>">
```

Each theme is a block of CSS custom properties. Theme switching is a POST to `/theme/:name` which updates `session[:theme]`. Forms use `data-turbo="false"` because session updates via Turbo fetch don't persist Set-Cookie headers.

## Pitfalls Encountered

1. **AuthConcern helper_method/before_action placement** — Must be in `included do ... end` block
2. **Turbo session updates** — Forms that only update session need `data-turbo="false"` to force full page reload
3. **Tailwind v4 `@apply`** — Cannot `@apply` custom component classes from same stylesheet; inline instead
4. **`@layer` portability** — Remove `@layer` wrappers when porting Tailwind CSS to standalone contexts
5. **Dialog centering** — Native `<dialog>` elements need explicit `position: fixed; top: 50%; left: 50%; transform: translate(-50%, -50%)` to center
6. **Janus API connection refused** — Backend must be running on port 3001; catch `Errno::ECONNREFUSED` and show helpful error