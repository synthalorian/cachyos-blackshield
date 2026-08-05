---
name: ruby-on-rails
description: >-
  Ruby on Rails 8.1 development — scaffolding, MVC, routing, models,
  migrations, authentication, Tailwind CSS v4, Solid Queue, testing,
  deployment, and environment-specific pitfalls. Covers the full lifecycle
  from `rails new` to production deploy. Triggers: Rails, Ruby on Rails,
  scaffolding, migration, model, controller, view, route, Gemfile, Active
  Record, Action Cable, Hotwire, Turbo, Stimulus, importmap, Propshaft,
  Solid Queue, Kamal, credentials, database, SQLite, PostgreSQL, Tailwind,
  bootstrap, scaffold, generator, API mode, Rails engine, external API,
  service object, multi-theme, CSS custom properties theme, dual-platform,
  Net::HTTP, SSE streaming.
version: 1.2.0
tags: [rails, ruby, web, backend, fullstack]
---

# Ruby on Rails 8.1 Development

## Environment

| Tool | Version | Path |
|------|---------|------|
| Ruby | 4.0.4 | `~/.local/share/mise/installs/ruby/4.0.4/bin/ruby` |
| Rails | 8.1.3 | `gem install rails` |
| Bundler | latest | `~/.local/share/mise/installs/ruby/4.0.4/bin/bundle` |
| SQLite | 3.53.1 | System package |
| PostgreSQL | 18.3 | `sudo pacman -S postgresql` |
| Tailwind CSS | v4 | Managed via `tailwindcss-ruby` gem |

**CRITICAL:** `bundle` is NOT on the default PATH. Use the full path:
```bash
~/.local/share/mise/installs/ruby/4.0.4/bin/bundle install
# or use mise: mise exec ruby -- bundle install
```

Alternatively, activate mise's shims:
```bash
eval "$(mise activate bash)"  # add to ~/.bashrc for persistence
```

## Scaffolding a New Rails App

### With SQLite (default — fastest for prototyping)
```bash
rails new my_app
```

### With PostgreSQL
```bash
rails new my_app --database=postgresql
```

### API-only (no views, no assets)
```bash
rails new my_app --api
```

### Without Tailwind (use your own CSS/SCSS)
```bash
rails new my_app --skip-tailwind
```

### Key flags
- `--skip-test` — skip Minitest (if using RSpec)
- `--skip-action-mailer` — no email
- `--skip-action-mailbox` — no incoming email
- `--skip-active-storage` — no file uploads
- `--skip-action-text` — no rich text
- `--skip-jbuilder` — no JSON templates
- `--skip-hotwire` — no Turbo/Stimulus (API apps)
- `--skip-solid` — no Solid Queue/Cache/Errors (if using Redis)

## Project Structure (Rails 8 standard)

```
my_app/
├── app/
│   ├── assets/           # Images, fonts (precompiled)
│   │   └── tailwind/     # Tailwind CSS source (v4: application.css)
│   ├── channels/         # Action Cable WebSocket channels
│   ├── controllers/      # Controllers (app_controller.rb base)
│   │   └── concerns/     # Shared controller modules
│   ├── helpers/          # View helpers (deprecated in 8.1 — prefer partials/components)
│   ├── jobs/             # Background jobs (Solid Queue default)
│   ├── mailers/          # Action Mailer
│   ├── models/           # Active Record models
│   │   └── concerns/     # Shared model modules
│   └── views/            # ERB templates
│       └── layouts/      # Application layout
├── bin/                  # Rails scripts (rails, rake, setup, dev)
├── config/
│   ├── initializers/     # Boot-time config
│   ├── locales/          # I18n
│   ├── routes.rb         # Route definitions
│   ├── database.yml      # DB config
│   └── environments/     # Per-environment overrides
├── db/
│   ├── migrate/          # Schema migrations
│   ├── schema.rb         # Current schema snapshot
│   └── seeds.rb          # Seed data
├── lib/                  # Library code, tasks
├── log/                  # Logs (gitignored)
├── public/               # Static files (404, 500, favicon)
├── storage/              # Active Storage files (gitignored)
├── test/ or spec/        # Tests
├── tmp/                  # Temp files (gitignored)
├── vendor/               # Vendored gems
├── Gemfile
├── Gemfile.lock
├── Rakefile
├── config.ru
├── package.json          # Only if using Node-based assets
└── Dockerfile            # Kamal-ready
```

## Turbo Drive Pitfall: Form Session Updates

**PITFALL: Turbo intercepts form POST submissions and does an AJAX fetch instead of a full page reload.** When a form's purpose is to update the session (e.g., theme switching, locale switching), Turbo's interception prevents the session cookie from being properly updated because the redirect response's `Set-Cookie` header from a Turbo fetch doesn't apply the same way as a full navigation.

**The fix: Add `data-turbo=\"false\"` to the form tag.**

```erb
<%# BEFORE — Turbo intercepts, session doesn't update: %>
<form action=\"/theme/synthwave84\" method=\"post\">
  <%= token_tag %>
  <button type=\"submit\">Switch Theme</button>
</form>

<%# AFTER — Full page reload, session updates correctly: %>
<form action=\"/theme/synthwave84\" method=\"post\" data-turbo=\"false\">
  <%= token_tag %>
  <button type=\"submit\">Switch Theme</button>
</form>
```

**Why this happens:** Turbo Drive intercepts form submissions with `Accept: text/html` and converts them to `fetch()` requests. The response is a redirect (`302`), which Turbo follows. But the intermediate `Set-Cookie` from the controller action is applied to the fetch response, not the browser's document cookie jar. Subsequent Turbo page loads don't see the updated session cookie, so the session change is lost.

**Apply `data-turbo=\"false\"` to ANY form whose only purpose is to update `session[:key]` and redirect back.** This includes theme pickers, locale switchers, and any preference toggles that don't change database state.

## Key Conventions

### MVC Routing

```ruby
# config/routes.rb
Rails.application.routes.draw do
  # Root
  root "dashboard#show"

  # RESTful resources
  resources :articles
  resources :users do
    resources :posts, only: [:index, :show]  # Nested
    member do
      get :profile  # /users/:id/profile
    end
    collection do
      get :search  # /users/search
    end
  end

  # Custom routes
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  # Scope/namespace for APIs
  namespace :api do
    namespace :v1 do
      resources :posts, only: [:index, :show, :create]
    end
  end

  # Constraints
  constraints subdomain: "admin" do
    resources :admin_panel
  end

  # Health check (Rails 7+)
  get "up", to: "rails/health#show", as: :rails_health_check
end
```

### RESTful Resource — Standard Generator

```bash
# Creates model, migration, controller, views, routes, tests
rails generate scaffold Post title:string body:text published:boolean

# Model + migration only
rails generate model Comment post:references author:string body:text

# Controller only (with views)
rails generate controller articles index show new create edit update destroy
```

### Models

```ruby
# app/models/article.rb
class Article < ApplicationRecord
  # === Associations ===
  belongs_to :user
  has_many :comments, dependent: :destroy
  has_one :featured_image, class_name: "Image", as: :imageable

  # === Validations ===
  validates :title, presence: true, length: { minimum: 3, maximum: 200 }
  validates :body, presence: true
  validates :published, inclusion: { in: [true, false] }

  # === Scopes ===
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user_id) { where(user_id: user_id) }

  # === Callbacks ===
  before_save :slugify_title
  after_create :send_notification

  # === Instance Methods ===
  def to_param
    "#{id}-#{title.parameterize}"
  end

  private

  def slugify_title
    self.slug = title.parameterize
  end

  def send_notification
    ArticleNotificationJob.perform_later(id)
  end
end
```

### Controllers

```ruby
# app/controllers/articles_controller.rb
class ArticlesController < ApplicationController
  before_action :set_article, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:index, :show]

  # GET /articles
  def index
    @articles = Article.published.recent.page(params[:page])
  end

  # GET /articles/:id
  def show
  end

  # GET /articles/new
  def new
    @article = Article.new
  end

  # POST /articles
  def create
    @article = current_user.articles.build(article_params)
    if @article.save
      redirect_to @article, notice: "Article created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /articles/:id/edit
  def edit
  end

  # PATCH/PUT /articles/:id
  def update
    if @article.update(article_params)
      redirect_to @article, notice: "Article updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /articles/:id
  def destroy
    @article.destroy
    redirect_to articles_path, notice: "Article deleted."
  end

  private

  def set_article
    @article = Article.find(params[:id])
  end

  def article_params
    params.require(:article).permit(:title, :body, :published)
  end
end
```

**PITFALL: Concern callback/helper_method registration** — When using `ActiveSupport::Concern`, `helper_method` and `before_action` MUST be called inside the `included do ... end` block. Placing them at module level (outside `included`) raises `NoMethodError: undefined method 'helper_method' for module` or `ArgumentError: before_action callback :authenticate! has not been defined`.

```ruby
# WRONG — crashes:
module AuthConcern
  extend ActiveSupport::Concern
  helper_method :current_user   # NoMethodError!

  def authenticate!
    redirect_to login_path unless session[:user_id]
  end
  before_action :authenticate!  # ArgumentError — method not defined yet!
end

# CORRECT:
module AuthConcern
  extend ActiveSupport::Concern

  included do
    helper_method :current_user, :authenticated?, :current_theme
    before_action :authenticate!
  end

  def authenticate!
    redirect_to login_path unless session[:user_id]
  end

  def current_user
    session[:janus_user]
  end
end
```

## Migrations

```bash
# Create a migration
rails generate migration AddCategoryToArticles category:string

# Run pending migrations
rails db:migrate

# Rollback last migration
rails db:rollback

# Rollback N steps
rails db:rollback STEP=3

# Revert a specific migration
rails db:migrate:down VERSION=20250101000000

# Check migration status
rails db:migrate:status

# Reset database (drop + create + migrate + seed)
rails db:reset
```

### Common Migration Patterns

```ruby
class AddCategoryToArticles < ActiveRecord::Migration[8.1]
  def change
    add_column :articles, :category, :string, default: "general", null: false
    add_reference :articles, :author, foreign_key: { to_table: :users }
    add_index :articles, [:category, :published]
  end
end

class CreateComments < ActiveRecord::Migration[8.1]
  def change
    create_table :comments do |t|
      t.references :article, null: false, foreign_key: true
      t.string :author, null: false
      t.text :body, null: false
      t.timestamps
    end
  end
end
```

## Tailwind CSS v4 in Rails 8

Rails 8 ships with Tailwind CSS v4 via the `tailwindcss-ruby` gem. The CSS build pipeline is managed by the gem's bundled binary — **no Node.js required**.

### Key Files

| File | Purpose |
|------|---------|
| `app/assets/tailwind/application.css` | **Tailwind source** — `@import "tailwindcss"` + custom `@theme`, layer rules, and global styles |
| `app/assets/builds/tailwind.css` | Compiled output (auto-generated, gitignored) |
| `Procfile.dev` | Dev server: `rails server` + `bin/rails tailwindcss:watch` |

### Configuration

Tailwind v4 is **CSS-driven**, not config-driven. There's no `tailwind.config.js` — everything goes in your CSS:

```css
/* app/assets/tailwind/application.css */
@import "tailwindcss";

/* Custom theme variables */
@theme {
  --color-neon-purple: #8f00ff;
  --color-neon-pink: #ff00ff;
  --color-neon-cyan: #03edf9;
  --color-neon-yellow: #ffff66;
  --color-surface: #240037;
  --color-muted: #614d85;
  --color-deep-bg: #0d0221;
  --font-family-nerd: "3270 Nerd Font", monospace;
}

/* Custom component classes */
@layer components {
  .glass-card {
    background: color-mix(in srgb, var(--color-surface) 60%, transparent);
    backdrop-filter: blur(12px);
    border: 1px solid color-mix(in srgb, var(--color-neon-purple) 20%, transparent);
  }
}

/* Custom utilities */
@layer utilities {
  .text-glow-purple {
    text-shadow: 0 0 10px var(--color-neon-purple), 0 0 20px var(--color-neon-purple);
  }
}
```

### Building Tailwind Manually

When `bundle exec rails tailwindcss:build` fails (Rails::Command::UnrecognizedCommandError or no `bundle` on PATH):

```bash
# Find the tailwindcss binary
find ~/.local/share/gem -name "tailwindcss" -type f 2>/dev/null

# Build manually
/path/to/tailwindcss \
  --input app/assets/tailwind/application.css \
  --output app/assets/builds/tailwind.css
```

**PITFALL: `rails tailwindcss:build` not recognized** — Rails 8.1 + tailwindcss-rails 4.x may not register the rake task properly. The binary is always available at `~/.local/share/gem/ruby/<version>/gems/tailwindcss-ruby-*-x86_64-linux-gnu/exe/tailwindcss`. Find it with `find`. Running it directly with `-i` and `-o` flags compiles the CSS in ~25ms. Create the `app/assets/builds/` directory if it doesn't exist.

**PITFALL: `@apply` of custom component classes in same stylesheet** — In Tailwind v4, `@apply` can only reference utility classes defined by Tailwind itself. It cannot `@apply` a custom component class defined in the same stylesheet (e.g. `.janus-input { ... }` used via `@apply janus-input` in `.janus-textarea`). This produces: `Error: Cannot apply unknown utility class`. **Fix: inline the styles instead of using `@apply`.** If a class is reused across multiple selectors, duplicate the CSS properties directly or extract them to shared CSS custom properties (e.g. `--input-base: ...`).

**PITFALL: `@layer` portability** — Tailwind's `@layer base`, `@layer components`, and `@layer utilities` directives work inside the Tailwind build pipeline (`app/assets/tailwind/application.css`), but break when the same CSS is used standalone (e.g. in a Tauri webview or plain HTML page). The `@layer` wrappers cause all styles inside them to be silently ignored. **Fix: remove `@layer` wrappers** when porting Tailwind-built CSS to standalone contexts. Replace `@layer base { ... }` with just `/* Base Styles */` and the raw CSS selectors.

### Multi-Theme Architecture with CSS Custom Properties

For apps that need dynamic theming (30+ themes, synthwave84 aesthetic), use CSS custom properties on the `<html>` element with a `data-theme` attribute. **No Tailwind theme plugin needed.**

#### CSS Structure

Place the theme system in `app/assets/tailwind/application.css` after `@import "tailwindcss"`. Define a `:root` block with defaults, then a `[data-theme="name"]` block per theme:

```css
@import "tailwindcss";

/* Default theme */
:root {
  --bg-primary: #0D0221;
  --bg-secondary: #240037;
  --bg-surface: #240037;
  --text-primary: #FFFFFF;
  --text-secondary: #C0A0D0;
  --text-muted: #663388;
  --accent-primary: #8F00FF;
  --accent-secondary: #FF00FF;
  --accent-tertiary: #00FFFF;
  --border-color: #8F00FF;
  --border-light: #4A006880;
  --success: #00FF41;
  --warning: #FFFF66;
  --error: #FF0040;
  --gradient-primary: linear-gradient(135deg, #8F00FF, #FF00FF);
  --font-mono: "Courier New", monospace;
  --radius-md: 8px;
  --radius-lg: 12px;
  /* CRT effects */
  --crt-opacity: 0.03;
  --grid-opacity: 0.03;
}

[data-theme="light"] {
  --bg-primary: #FFFFFF;
  --bg-secondary: #F8F9FA;
  --text-primary: #1A1A2E;
  --text-muted: #9CA3AF;
  --accent-primary: #2563EB;
  --crt-opacity: 0;
}
```

#### Rails Controller for Theme Switching

```ruby
# app/controllers/theme_controller.rb
class ThemeController < ApplicationController
  VALID_THEMES = %w[synthwave84 light dark outrun cyberpunk].freeze

  # POST /theme/:name
  def switch
    if VALID_THEMES.include?(params[:name])
      session[:theme] = params[:name]
    end
    redirect_back fallback_location: "/"
  end
end
```

#### Layout Integration

In `app/views/layouts/application.html.erb`:

```erb
<html lang="en" data-theme="<%= session[:theme] || 'synthwave84' %>">
```

#### Theme Picker Dialog

Render a dialog with forms that POST to `/theme/:name`:

```erb
<dialog id="theme-picker" style="background: var(--bg-surface); border: 1px solid var(--accent-primary);">
  <div style="display: grid; grid-template-columns: repeat(auto-fill, minmax(120px, 1fr)); gap: 8px;">
    <% themes.each do |theme_id, icon, name| %>
      <%= form_tag "/theme/#{theme_id}", method: :post do %>
        <button type="submit" style="background: var(--bg-tertiary); border: 1px solid var(--border-light);">
          <span><%= icon %></span>
          <span><%= name %></span>
        </button>
      <% end %>
    <% end %>
  </div>
</dialog>
```

**PITFALL: Session not persisting across requests** — Rails session cookies work by default. If theme resets on every page load, check that `session` is being read in the layout (it is — `<html data-theme="<%= session[:theme] %>">`). No database or cache needed for session-backed preferences.

**PITFALL: CSS variable cascade** — CSS custom properties cascade. Setting them on `[data-theme="name"]` only works when that attribute is present. Make sure your layout sets the `data-theme` attribute on the `<html>` element itself, not a child div. Properties set on `<html>` cascade down to all descendants.

### External API Service Objects (Net::HTTP)

For Rails apps that talk to an external HTTP API (Rust backend, Python service, another Rails API), use a service class with class methods wrapping `Net::HTTP`. **No `faraday` or `httparty` gem needed** — Rails ships with everything required.

#### Service Object Template

```ruby
# app/services/my_api_service.rb
require "net/http"
require "json"
require "uri"

class MyApiService
  BASE_URL = ENV.fetch("API_BASE_URL", "http://127.0.0.1:9120")
  TIMEOUT = ENV.fetch("API_TIMEOUT", "10").to_i

  class BackendError < StandardError; end

  # ── Health ──────────────────────────────────────────────────
  def self.health
    get("/health")
  end

  # ── Resources ───────────────────────────────────────────────
  def self.list_resources
    get("/resources")
  end

  def self.create_resource(data)
    post("/resources", data)
  end

  private

  def self.get(path, params = {})
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?
    request = Net::HTTP::Get.new(uri)
    response = Net::HTTP.start(uri.hostname, uri.port,
      open_timeout: 5, read_timeout: TIMEOUT) do |http|
      http.request(request)
    end
    parse_response(response, path)
  end

  def self.post(path, body = {})
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json
    response = Net::HTTP.start(uri.hostname, uri.port,
      open_timeout: 5, read_timeout: TIMEOUT) do |http|
      http.request(request)
    end
    parse_response(response, path)
  end

  def self.build_http(uri)
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = TIMEOUT
    http.open_timeout = 5
    http
  end

  def self.parse_response(response, path)
    case response
    when Net::HTTPOK
      body = response.body
      body.present? ? JSON.parse(body) : { "status" => "ok" }
    when Net::HTTPNotFound
      raise BackendError, "Endpoint not found: #{path}"
    else
      raise BackendError, "API error (#{response.code}): #{response.body&.truncate(200)}"
    end
  rescue JSON::ParserError => e
    raise BackendError, "Invalid JSON from #{path}: #{e.message}"
  rescue Net::TimeoutError
    raise BackendError, "Timeout at #{path}"
  rescue Errno::ECONNREFUSED
    raise BackendError, "Cannot connect to #{BASE_URL}"
  end
end
```

#### Controller Integration

Every controller action that calls the service wraps it in a `begin/rescue`:

```ruby
class DashboardController < ApplicationController
  def show
    @data = MyApiService.health
    @resources = MyApiService.list_resources
  rescue MyApiService::BackendError => e
    @error = e.message
    @data = {}
    @resources = []
  end
end
```

In the view, check `@error` and display a styled banner:

```erb
<% if @error %>
  <div style="background: color-mix(in srgb, var(--accent-red) 10%, transparent);
              border: 1px solid color-mix(in srgb, var(--accent-red) 30%, transparent);
              border-radius: var(--radius-lg); padding: 12px 16px; margin-bottom: 16px;">
    <span style="color: var(--accent-red); font-size: 12px;">⚠ <%= @error %></span>
  </div>
<% end %>
```

For a complete example of a Rails app consuming a large external JSON API (60+ endpoints, session-based auth), see `references/janus-api-client.md`.

**PITFALL: `Net::HTTP` class methods vs instance** — `Net::HTTP.get_response(uri)` is a convenience class method but doesn't let you set timeouts. Always use `Net::HTTP.start` with a block — this properly manages the TCP connection lifecycle and prevents intermittent `EOFError: end of file reached` errors from stale connections. Never reuse `Net::HTTP` instances across requests without explicit `start`/`finish` blocks.

**PITFALL: CSRF token with Stimulus fetch** — Rails requires CSRF tokens for POST requests via fetch. Always read the token from `<meta name=\"csrf-token\">` and include as `X-CSRF-Token` header:

```javascript
fetch("/api/endpoint", {
  method: "POST",
  headers: {
    "Content-Type": "application/json",
    "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
  },
  body: JSON.stringify(data)
})
```

Without the CSRF token, Rails returns `422 Unprocessable Entity`.

### Dual-Platform Proxy Architecture

When a single Rust backend serves both a Flutter GUI and a Rails webapp simultaneously, see `references/dual-platform-proxy.md` for the full architecture pattern, SSE streaming path, and theme synchronization strategy.

### Synthwave84 Theme Integration

To theme a Rails 8 app with synthwave84 colors:

1. Define all palette colors in `@theme {}` in `application.css`
2. Use CSS custom properties on `<html data-theme="synthwave84">` for dynamic theming
3. Apply glass-morphism with purple borders and backdrop blur
4. Add CRT scanline, grid overlay, and horizon-glow effects:

```css
/* Scanline overlay */
body::after {
  content: "";
  position: fixed;
  inset: 0;
  background: repeating-linear-gradient(
    0deg,
    transparent,
    transparent 2px,
    rgba(0, 0, 0, 0.03) 2px,
    rgba(0, 0, 0, 0.03) 4px
  );
  pointer-events: none;
  z-index: 9999;
}
```

## Hotwire / Turbo / Stimulus

Rails 8 ships with Hotwire by default. No JavaScript bundler needed.

### Turbo Streams — Real-time DOM updates

```erb
<%# app/views/comments/_comment.html.erb %>
<%= turbo_stream_from @article %>

<div id="<%= dom_id(comment) %>">
  <p><%= comment.body %></p>
</div>
```

```ruby
# app/controllers/comments_controller.rb
def create
  @comment = @article.comments.build(comment_params)
  if @comment.save
    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.append("comments", partial: "comments/comment", locals: { comment: @comment }) }
      format.html { redirect_to @article }
    end
  end
end
```

### Stimulus Controllers

```javascript
// app/javascript/controllers/hello_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "output"]

  greet() {
    this.outputTarget.textContent = `Hello, ${this.nameTarget.value}!`
  }
}
```

```erb
<!-- In your view -->
<div data-controller="hello">
  <input type="text" data-hello-target="name">
  <button data-action="click->hello#greet">Greet</button>
  <p data-hello-target="output"></p>
</div>
```

### SSE Streaming with Stimulus (EventSource)

When the backend provides an SSE stream URL (e.g. a Rust or Python AI endpoint), the Rails controller returns the URL as JSON and the Stimulus controller connects directly via `EventSource`. This avoids proxying the stream through Rails.

**Controller pattern — returns stream URL:**

```ruby
# app/controllers/chat_controller.rb
class ChatController < ApplicationController
  # POST /chat/send_message — returns JSON with stream_url
  def send_message
    message = params[:message]
    session_id = params[:session_id]

    unless message.present?
      return render json: { error: "Message is required" }, status: :unprocessable_entity
    end

    # HermesApiService constructs: "http://backend:9120/chat/stream?message=..."
    stream_url = HermesApiService.chat_stream_url(message, session_id: session_id)
    render json: { stream_url: stream_url }
  rescue HermesApiService::BackendError => e
    render json: { error: e.message }, status: :service_unavailable
  end
end
```

**Stimulus controller — connects to SSE stream, accumulates text:**

```javascript
// app/javascript/controllers/chat_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "sendButton"]

  connect() {
    this.eventSource = null
    this.streaming = false
    this.accumulator = ""
    this.currentAiBubble = null
  }

  disconnect() {
    this._closeStream()
  }

  send(event) {
    event.preventDefault()
    const text = this.inputTarget.value.trim()
    if (!text || this.streaming) return

    this.appendMessage(text, true)
    this.inputTarget.value = ""
    this._startStreaming(text)
  }

  _startStreaming(text) {
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content

    fetch("/chat/send_message", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": csrfToken
      },
      body: JSON.stringify({ message: text, session_id: this.currentSessionId })
    })
      .then(r => r.json())
      .then(data => this.connectStream(data.stream_url))
      .catch(err => this.appendMessage(`Error: ${err.message}`, false))
  }

  connectStream(url) {
    this._closeStream()
    this.eventSource = new EventSource(url)
    this.streaming = true
    this.accumulator = ""
    this.currentAiBubble = this.appendMessage("", false)

    // Named "data" events — common SSE payload format
    this.eventSource.addEventListener("data", (event) => this.handleData(event.data))
    // "done" event indicates end of stream
    this.eventSource.addEventListener("done", () => this.handleDone())
    // Error handler — close if stream ended
    this.eventSource.addEventListener("error", () => {
      if (this.eventSource?.readyState === EventSource.CLOSED) this.handleDone()
    })
    // Safety timeout (e.g. 60s)
    setTimeout(() => { if (this.streaming) this.handleDone() }, 60000)
  }

  handleData(data) {
    if (!data || data === "[DONE]") { this.handleDone(); return }
    try {
      // Try JSON: { content: "..." } or { text: "..." } or { message: "..." }
      const parsed = JSON.parse(data)
      const content = parsed.content || parsed.text || parsed.message || ""
      if (content) {
        this.accumulator += content
        this._updateAiBubble(this.accumulator)
      }
    } catch {
      // Plain text fallback
      this.accumulator += data
      this._updateAiBubble(this.accumulator)
    }
  }

  handleDone() {
    if (!this.streaming) return
    this._closeStream()
    if (this.currentAiBubble) {
      this.currentAiBubble.style.borderRight = "none"  // Remove cursor
    }
    this.streaming = false
    this.currentAiBubble = null
    this.inputTarget.focus()
  }

  appendMessage(text, isUser) {
    const bubble = document.createElement("div")
    bubble.className = isUser ? "chat-bubble-user" : "chat-bubble-ai"

    const baseStyle = `max-width: 80%; padding: 10px 14px; border-radius: var(--radius-lg);
      font-size: 13px; line-height: 1.6; word-wrap: break-word; white-space: pre-wrap;
      animation: chatBubbleIn 0.2s ease-out;`

    if (isUser) {
      bubble.style.cssText = baseStyle + `align-self: flex-end;
        background: var(--accent-tertiary); color: var(--bg-primary);`
      bubble.textContent = text
    } else {
      bubble.style.cssText = baseStyle + `align-self: flex-start;
        background: var(--bg-surface); border: 1px solid var(--border-light); color: var(--text-primary);`
      // Empty AI bubble — show blinking cursor for streaming
      if (!text) {
        bubble.style.borderRight = "2px solid var(--accent-tertiary)"
        bubble.innerHTML = "&nbsp;"
      } else {
        bubble.textContent = text
      }
    }
    this.messagesTarget.appendChild(bubble)
    this.scrollToBottom()
    return bubble
  }

  scrollToBottom() {
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  _closeStream() {
    this.eventSource?.close()
    this.eventSource = null
  }

  _updateAiBubble(text) {
    if (!this.currentAiBubble) return
    const label = this.currentAiBubble.querySelector("div") // "AI" label
    this.currentAiBubble.innerHTML = ""
    if (label) this.currentAiBubble.appendChild(label)
    this.currentAiBubble.appendChild(document.createTextNode(text))
    this.currentAiBubble.style.borderRight = "2px solid var(--accent-tertiary)"
  }
}
```

**PITFALL: CSRF token with fetch** — Rails requires CSRF tokens for POST requests. Always read the token from `<meta name="csrf-token">` and include it as `X-CSRF-Token` in the header. Stimulus controllers must include this or Rails will reject the request with a `422 Unprocessable Entity`.

**PITFALL: SSE stream timeout** — EventSource has no built-in timeout. Always set a safety timeout (e.g. 60s) to close stalled streams. Without it, a misbehaving backend that opens the connection but never sends events will hold the connection indefinitely.

**PITFALL: Stream URL format** — SSE streams from external backends (e.g. Rust on port 9120) connect directly from the browser via EventSource. This works on localhost but requires CORS headers in production. To proxy through Rails, see the Action Cable SSE pattern instead.

### Socket.IO + Stimulus Real-Time Chat

When connecting a Rails frontend to an external Socket.IO backend (non-ActionCable), see `references/socketio-stimulus-realtime.md` for the full integration pattern — CDN setup, Stimulus controller, Turbo compatibility, dual-path message sending, and event mapping.

### Common Stimulus Patterns

**Auto-resizing textarea:**

```erb
<textarea data-chat-target="input"
          data-action="keydown->chat#handleKeydown"
          rows="1"
          onfocus="this.style.borderColor='var(--accent-tertiary)'"
          onblur="this.style.borderColor='var(--border-light)'">
</textarea>
```

```javascript
// In Stimulus controller
_autoResizeTextarea() {
  const el = this.inputTarget
  el.style.height = "auto"
  el.style.height = Math.min(el.scrollHeight, 120) + "px"
}
```

**Keyboard handling (Enter to send, Shift+Enter for newline):**

```javascript
handleKeydown(event) {
  if (event.key === "Enter" && !event.shiftKey) {
    event.preventDefault()
    this.send(event)  // Submit on Enter
  }
  // Shift+Enter falls through to default textarea behavior (newline)
}
```

**Inject custom keyframe animations from Stimulus:**

```javascript
// Place at bottom of Stimulus controller file — runs once
if (!document.getElementById("chat-animations")) {
  const style = document.createElement("style")
  style.id = "chat-animations"
  style.textContent = `
    @keyframes chatBubbleIn {
      from { opacity: 0; transform: translateY(8px); }
      to   { opacity: 1; transform: translateY(0); }
    }
  `
  document.head.appendChild(style)
}
```

### ERB View — Chat UI with Bubbles and Themed Colors

Use Rails' `var(--*)` CSS custom properties for consistent theming. Never hardcode colors in views:

```erb
<% content_for :title, "Chat — App" %>
<% content_for :header_title, "CHAT" %>

<div data-controller="chat"
     style="display: flex; flex-direction: column; height: calc(100vh - 130px); max-width: 1000px; margin: 0 auto;">

  <!-- Session Tabs -->
  <div data-chat-target="sessionTabs"
       style="display: flex; gap: 6px; overflow-x: auto; flex-shrink: 0;">
    <button data-action="click->chat#newSession"
            style="padding: 6px 14px; font-size: 10px; font-family: var(--font-mono);
                   background: var(--bg-tertiary); border: 1px dashed var(--border-light);
                   border-radius: var(--radius-md); color: var(--text-muted); cursor: pointer;">
      + NEW
    </button>
    <% @sessions.first(10).each do |session| %>
      <button data-action="click->chat#switchSession"
              data-session-id="<%= session['id'] %>"
              style="padding: 6px 14px; font-size: 10px; font-family: var(--font-mono);
                     background: var(--bg-tertiary); border: 1px solid var(--border-light);
                     border-radius: var(--radius-md); color: var(--text-secondary); cursor: pointer;
                     white-space: nowrap;">
        <%= (session['title'].presence || 'Untitled').truncate(22) %>
      </button>
    <% end %>
  </div>

  <!-- Messages Area -->
  <div data-chat-target="messages"
       style="flex: 1; overflow-y: auto; padding: 16px 8px;
              display: flex; flex-direction: column; gap: 12px; scroll-behavior: smooth;">
  </div>

  <!-- Input Bar -->
  <div style="flex-shrink: 0; padding-top: 12px; border-top: 1px solid var(--border-light);">
    <form data-action="submit->chat#send" style="display: flex; gap: 8px;">
      <textarea data-chat-target="input"
                placeholder="Message…"
                rows="1"
                data-action="keydown->chat#handleKeydown"
                style="flex: 1; background: var(--bg-tertiary); border: 1px solid var(--border-light);
                       border-radius: var(--radius-lg); padding: 10px 14px; color: var(--text-primary);
                       font-family: var(--font-body); font-size: 13px; resize: none;
                       outline: none; min-height: 40px; max-height: 120px; line-height: 1.5;">
      </textarea>
      <button type="submit"
              data-chat-target="sendButton"
              style="background: var(--accent-tertiary); color: var(--bg-primary);
                     border: none; border-radius: var(--radius-lg); padding: 10px 20px;
                     font-size: 13px; font-weight: 600; cursor: pointer; height: 40px;
                     font-family: var(--font-mono); letter-spacing: 0.5px;">
        SEND
      </button>
    </form>
    <div style="font-size: 9px; color: var(--text-muted); font-family: var(--font-mono); margin-top: 4px;">
      Enter to send · Shift+Enter for newline
    </div>
  </div>
</div>
```

**Key patterns in the view:**
- Use `height: calc(100vh - 130px)` to fill remaining viewport below the sticky header
- Messages area uses `flex: 1; overflow-y: auto` for scrollable chat
- Empty state is shown/hidden via `data-chat-target="emptyState"` + Stimulus toggle
- Input bar is pinned to bottom with `flex-shrink: 0`
- All colors reference `var(--*)` CSS custom properties — no hardcoded hex values

## Solid Queue (default background job system in Rails 8)

Solid Queue uses SQLite/PostgreSQL as the job backend — no Redis needed.

```ruby
# app/jobs/process_article_job.rb
class ProcessArticleJob < ApplicationJob
  queue_as :default

  def perform(article_id)
    article = Article.find(article_id)
    # ... processing logic
  end
end

# Enqueue
ProcessArticleJob.perform_later(@article.id)

# Schedule
ProcessArticleJob.set(wait: 5.minutes).perform_later(@article.id)
```

### Concurrency Configuration

```yaml
# config/queue.yml
default: 5
mailers: 2
low_priority: 1
```

### Running the worker
```bash
bin/jobs work
```

## Authentication

Rails 8 uses `has_secure_password` (bcrypt) as the standard approach. No Devise needed for simple auth.

```bash
rails generate authentication
```

This generator creates:
- `User` model with `has_secure_password`
- `SessionsController` with create/destroy
- `Current` object for `Current.user`
- `authenticate_user!` helper

### Manual setup

```bash
# Add to Gemfile
gem "bcrypt", "~> 3.1"

# Generate user model
rails generate model User email:string:uniq password_digest:string

# In the model
class User < ApplicationRecord
  has_secure_password
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
end
```

## Testing

### RSpec Setup
```bash
# Add to Gemfile
group :development, :test do
  gem "rspec-rails", "~> 7.0"
end

# Install
bundle install
rails generate rspec:install
```

### Model Tests
```ruby
# spec/models/article_spec.rb
RSpec.describe Article, type: :model do
  subject { build(:article) }

  it { should validate_presence_of(:title) }
  it { should belong_to(:user) }
  it { should have_many(:comments).dependent(:destroy) }
end
```

### Controller/Request Tests
```ruby
# spec/requests/articles_spec.rb
RSpec.describe "Articles", type: :request do
  describe "GET /articles" do
    it "returns a successful response" do
      create_list(:article, 3, published: true)
      get articles_path
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /articles" do
    it "creates a new article" do
      user = create(:user)
      sign_in user
      post articles_path, params: { article: attributes_for(:article) }
      expect(response).to redirect_to(article_path(Article.last))
    end
  end
end
```

### System Tests (Cypress-style with Cuprite)
```ruby
# spec/system/article_management_spec.rb
RSpec.describe "Article Management", type: :system do
  it "allows a user to create an article" do
    visit new_article_path
    fill_in "Title", with: "My First Article"
    fill_in "Body", with: "This is the body"
    click_button "Create Article"
    expect(page).to have_content("Article created")
  end
end
```

## Credentials

Rails 8 uses encrypted credentials (AES-256-GCM):

```bash
# Edit credentials
bin/rails credentials:edit

# Edit with specific editor
EDITOR="code --wait" bin/rails credentials:edit

# Edit environment-specific
bin/rails credentials:edit --environment production
```

```yaml
# config/credentials.yml.enc (decrypted view)
secret_key_base: ...
aws:
  access_key_id: ...
  secret_access_key: ...
api_keys:
  openai: sk-...
```

Access in code:
```ruby
Rails.application.credentials.aws.access_key_id
Rails.application.credentials.dig(:api_keys, :openai)
```

## Asset Pipeline (Propshaft)

Rails 8 uses **Propshaft** (replaces Sprockets). No manifest file — assets in `app/assets/` are served directly.

### Adding static assets
```bash
# Place files in app/assets/images/
# Use in views:
image_tag "logo.png"
```

### Precompilation
```bash
rails assets:precompile  # For production
```

## Deployment (Kamal)

Rails 8 ships with Kamal for Docker-based deployments:

```bash
rails generate kamal:install
```

Creates `config/deploy.yml`:
```yaml
service: my_app
image: my_registry/my_app
servers:
  web:
    hosts:
      - 123.123.123.123
registry:
  username: owner
  password:
    - KAMAL_REGISTRY_PASSWORD
env:
  secret:
    - RAILS_MASTER_KEY
```

```bash
kamal setup    # First-time setup
kamal deploy   # Deploy
kamal rollback # Rollback
```

## Starting the Development Server

A reliable sequence for booting a Rails dev server on this machine:

```bash
# 1. cd to project
cd ~/projects/forge/hub

# 2. Check Ruby version matches .ruby-version
ruby --version   # should match .ruby-version

# 3. Verify gems installed (runs fast — no download)
bundle check

# 4. Run pending migrations (will be silent if none pending)
bin/rails db:migrate

# 5. Clear stale PID from previous session (common on restarts)
rm -f tmp/pids/server.pid

# 6. Start server (background with pty output visible)
bin/rails s -p 3000

# 7. Verify it's up
curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/
# Expect: 200
```

Background the server via `terminal(background=true, watch_patterns=["Listening on"])`
so you can keep working while it boots. Always verify with curl before telling the
user the server is up.

## Common Pitfalls & Solutions

### 1. **Bundle not on PATH**
```bash
# Always use full path
~/.local/share/mise/installs/ruby/4.0.4/bin/bundle install
# Or add to .bashrc: alias bundle='~/.local/share/mise/installs/ruby/4.0.4/bin/bundle'
```

### 2. **Tailwind build fails in dev**
```bash
# Find the binary
find ~/.local/share/gem -name "tailwindcss" -type f 2>/dev/null
# Run directly
/path/to/tailwindcss --input app/assets/tailwind/application.css --output app/assets/builds/tailwind.css --watch
```

### 3. **PG gem fails to install**
```bash
# PostgreSQL 18 needs updated libpq
# Install via pacman first:
sudo pacman -S postgresql-libs
bundle config build.pg --with-pg-config=/usr/bin/pg_config
bundle install
```

### 4. **Migration name collisions**
Use timestamps (Rails auto-generates them). Never have two migrations with the same purpose.

### 5. **CSS custom properties not working in Tailwind v4**
In Tailwind v4, custom properties in `@theme {}` are accessed as `var(--color-name)` — not as Tailwind's old `theme()` function.

### 6. **Turbo Streams not updating**
Make sure `<%= turbo_stream_from %>` is in the parent view, and the controller responds with `format.turbo_stream`.

### 7. **Solid Queue jobs not processing**
Ensure `bin/jobs work` is running (separate process from `rails server`).

### 8. **Rails server won't start — port in use**
```bash
lsof -ti:3000 | xargs kill -9  # Kill whatever's on port 3000
bin/rails server -p 3001        # Use different port
```

### 9. **Migrations failing on production**
Run `rails db:migrate` in production via:
```bash
RAILS_ENV=production bin/rails db:migrate
```

### 10. **Credentials lost (RAILS_MASTER_KEY missing)**
Never commit `config/master.key`. Store it in a password manager or deploy secret. To regenerate:
```bash
# THIS WILL DECRYPT ALL EXISTING CREDENTIALS
rm config/credentials.yml.enc
bin/rails credentials:edit  # Creates new key + file
```

## Security Pitfalls

### 11. **`safe_command` / `sanitize` helpers are false security**

A helper that only gsub's double quotes from user input before passing it to a shell does NOT prevent injection. Shell metacharacters include: `` ; | & $ > < ` () {} \n \r `` — none of which are quotes.

```ruby
# WRONG — this "sanitizer" is useless:
def safe_command(input)
  input.gsub('"', '\"')
end
`#{safe_command(params[:id])}`  # still exploitable via $(...) or ; etc.

# CORRECT — bypass shell entirely with argv arrays:
require 'open3'
stdout, stderr, status = Open3.capture3("forge", "backup", "--name", params[:id])
```

**Rule:** Never use backtick interpolation, `%x{}`, or `system(string)` with user input. Always use `Open3.capture3` or `system` with separate argv elements.

### 12. **SQLite connection leaks in service objects**

When using `SQLite3::Database.new` directly (not through ActiveRecord), every `new` must have a matching `close`:

```ruby
# WRONG — leaked connection on every call:
def self.stats
  db = SQLite3::Database.new(db_path)
  db.execute("SELECT ...")
  # if execute raises, connection is leaked
end

# CORRECT — ensure block guarantees cleanup:
def self.stats
  db = SQLite3::Database.new(db_path)
  begin
    db.execute("SELECT ...")
  ensure
    db.close
  end
end
```

### 13. **Cross-ecosystem DB reading pattern (Rust writes, Rails reads SQLite)**

When a Rust CLI (rusqlite) writes a SQLite DB and a Rails app needs to read it (no ActiveRecord for that DB), use a service class:

```ruby
# hub/app/services/rift_db.rb
class RiftDb
  class << self
    def connection
      @connection ||= SQLite3::Database.new(db_path)
    end

    def asset_counts
      return default_counts unless connected?
      rows = query("SELECT status, COUNT(*) as count FROM assets GROUP BY status")
      counts = default_counts
      rows.each { |status, count| counts[status] = count if status }
      counts
    end

    def recent_runs(limit: 10)
      return [] unless connected?
      query("SELECT id, timestamp, status, converted, errors, summary FROM pipeline_runs ORDER BY timestamp DESC LIMIT ?", limit)
        .map { |row| { "id" => row[0], "timestamp" => row[1], "status" => row[2], "converted" => row[3], "errors" => row[4], "summary" => row[5] } }
    end

    private

    def query(sql, *params)
      connection.execute(sql, params)  # v2.x returns arrays, not hashes
    end

    def find_db_path
      return ENV["RIFT_DB_PATH"] if ENV["RIFT_DB_PATH"]
      dir = Rails.root
      5.times do
        candidate = dir.join(".rift", "state.db")
        return candidate.to_s if File.exist?(candidate)
        dir = dir.parent
      end
      File.join(Rails.root, ".rift", "state.db")
    end
  end
end
```

**Key points:**
- Connection is cached as a class-level instance variable (single connection, read-only usage)
- SQLite3 v2.x returns arrays from `execute()` — always map to hashes manually
- `find_db_path` walks up the directory tree to find the Rust CLI's `.rift/state.db`
- Controller catches `SQLite3::Exception` gracefully with fallback defaults

### 14. **Solid Cable overwrites `config/cable.yml` on install**

Running `rails solid_cable:install` regenerates `config/cable.yml` from scratch, **destroying any custom configuration** you had (custom hostnames, Redis URLs, adapter changes). Always re-apply your config after installing solid_cable:

```bash
rails solid_cable:install
# ^^^ this overwrites config/cable.yml

# Re-apply your custom config:
cat > config/cable.yml << 'EOF'
development:
  adapter: solid_cable
test:
  adapter: test
production:
  adapter: solid_cable
EOF
```

**Alternative:** Commit `config/cable.yml` to git before running the installer, then restore it with `git checkout config/cable.yml`.

### 15. **Importmap + Stimulus need explicit install when JS directory is missing**

If `app/javascript/` doesn't exist (e.g., app generated with `--skip-javascript` or manually deleted), Turbo/Hotwire features won't work even though the gems are in the Gemfile. The symptoms are: no `data-turbo-track` attributes, no Stimulus controllers loading, forms doing full page reloads instead of Turbo Streams.

**Fix — run the installers explicitly:**

```bash
rails importmap:install    # Creates app/javascript/application.js, config/importmap.rb
rails stimulus:install     # Creates app/javascript/controllers/, pins Stimulus
```

After running these, verify:
- `app/javascript/application.js` exists and imports controllers
- `config/importmap.rb` pins `@hotwired/stimulus` and `@hotwired/turbo`
- Layout includes `<%= javascript_importmap_tags %>`

### 16. **Service object adapter pattern — mock data fallback for external daemons**

When building Rails apps that connect to external daemons (rnsd, Redis, message queues), always implement a **mock data fallback** so the app remains functional for development, testing, and demos when the daemon isn't running. See `references/external-daemon-adapter.md` for the full pattern.

**Key principles:**
- Every public method has `return mock_data unless connected?` as first line
- Connection errors in `send_command` are caught and re-raised as `ConnectionError`
- The calling method rescues `ConnectionError` and returns mock data
- Mock data is realistic — enough fields for views to render properly
- Mock data uses real data types (Time objects, floats, integers) not strings

### 17. **Hash-vs-AR-model mismatch in controllers**

When a service adapter returns raw hashes (from JSON parsing or mock data), **do not** pass them to `Model.new(hash)` if the model has associations, custom validations, or methods the view calls. ActiveRecord will try to instantiate associated objects from nested hashes and fail with `AssociationTypeMismatch`.

**WRONG — crashes on associations:**
```ruby
# Controller
@nodes = rns.nodes.map { |n| Node.new(n) }  # FAILS if n[:services] is an array of hashes

# View
<% @nodes.each do |node| %>
  <%= node.services.first.service_type %>  # AssociationTypeMismatch!
<% end %>
```

**CORRECT — map to model instances safely, excluding nested hashes:**
```ruby
# Controller — use find_or_initialize_by + assign_attributes with except
@nodes = rns.nodes.map do |n|
  node = Node.find_or_initialize_by(destination_hash: n[:destination_hash])
  node.assign_attributes(n.except(:services))  # Skip nested association data
  node
end

# View — now safe to call AR methods
<% @nodes.each do |node| %>
  <%= node.services.first&.service_type %>
<% end %>
```

**Alternative — keep as hashes through the stack:**
```ruby
# Controller — just pass the hashes
@nodes = rns.nodes  # Array of hashes

# View — access hash keys directly
<% @nodes.each do |node| %>
  <%= node[:services]&.first&.[](:service_type) %>
<% end %>
```

**Alternative — use OpenStruct or a plain PORO:**
```ruby
# app/models/network_node.rb (not an AR model)
class NetworkNode
  attr_reader :name, :destination_hash, :hops, :services
  def initialize(attrs)
    @name = attrs[:name]
    @destination_hash = attrs[:destination_hash]
    @hops = attrs[:hops] || 0
    @services = (attrs[:services] || []).map { |s| OpenStruct.new(s) }
  end
end

# Controller
@nodes = rns.nodes.map { |n| NetworkNode.new(n) }
```

**Rule of thumb:** If the adapter returns hashes, either (1) keep them as hashes through the controller, (2) use `find_or_initialize_by` + `assign_attributes(n.except(:nested))` to safely convert to AR, or (3) use a PORO. Never `Model.new` with raw external data that has nested structures.

### 18. **RSpec request spec URL path pitfalls**

Request specs generated by `rails generate controller` or `rails generate scaffold` often use literal paths like `get "/articles/index"` which are wrong — Rails routes don't include the action name in the path for RESTful resources.

**WRONG — 404 errors:**
```ruby
# spec/requests/articles_spec.rb
get "/articles/index"   # 404 — should be /articles
get "/articles/show"    # 404 — should be /articles/:id
get "/articles/create"  # 404 — should be POST /articles
```

**CORRECT — use route helpers and proper HTTP verbs:**
```ruby
# spec/requests/articles_spec.rb
RSpec.describe "Articles", type: :request do
  describe "GET /index" do
    it "returns http success" do
      get articles_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /show" do
    it "returns http success" do
      article = create(:article)
      get article_path(article)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    it "creates an article and redirects" do
      post articles_path, params: { article: attributes_for(:article) }
      expect(response).to have_http_status(:redirect)
    end
  end
end
```

**Also required:** Include FactoryBot syntax methods in `rails_helper.rb`:
```ruby
RSpec.configure do |config|
  config.include FactoryBot::Syntax::Methods
end
```

Without this, `create(:article)` raises `NoMethodError: undefined method 'create'`.

### 19. **Factory defaults must be valid**

Factories generated by `rails generate factory` use placeholder values that fail model validations. Always replace them with realistic, valid data.

**WRONG — fails validation:**
```ruby
FactoryBot.define do
  factory :peer do
    destination_hash { "MyString" }
    name { "MyString" }
    link_quality { 1.5 }        # Fails 0..1 validation
    status { "MyString" }       # Fails inclusion validation
  end
end
```

**CORRECT — valid defaults:**
```ruby
FactoryBot.define do
  factory :peer do
    sequence(:destination_hash) { |n| "<peer#{n}>" }
    name { "Test Peer" }
    last_seen { 5.minutes.ago }
    link_quality { 0.85 }
    hops { 1 }
    status { "active" }
    metadata { {} }
  end
end
```

**Key rules for factory data:**
- Use `sequence()` for unique fields (emails, hashes, usernames)
- Respect model validations (inclusion lists, numericality ranges, presence)
- Use realistic values, not placeholders ("Test Peer" not "MyString")
- Set associations explicitly with `association :alert_rule` not `alert_rule { nil }`
- Use proper types (Time objects, floats, integers) not strings for numeric/temporal fields

### 20. **Dashboard auto-refresh via meta tag**

For simple dashboards that poll for new data, use `<meta http-equiv="refresh">` instead of Turbo Streams or WebSockets:

```erb
<%# In the view template: %>
<% content_for :head do %>
  <meta http-equiv="refresh" content="15">
<% end %>

<%# In the layout's <head>: %>
<%= yield :head %>
```

This gives you 15-second auto-refresh with zero JavaScript, zero extra gems, zero WebSocket connections. Good for dashboards that display batch-processed data.

### 21. **Synthwave84 Theme CSS structure**

Inline synthwave84 CSS in the layout (no build step needed for dashboards):

```css
:root {
  --neon-pink: #ff2d95;
  --neon-cyan: #00f0ff;
  --neon-purple: #b829f0;
  --neon-yellow: #f0e829;
  --bg-dark: #0a0a1a;
  --bg-card: #12122a;
  --text-primary: #e0e0ff;
  --text-secondary: #8888bb;
  --border-color: #2a2a4a;
}

body::before {
  content: "";
  position: fixed; inset: 0;
  background: repeating-linear-gradient(
    0deg, transparent, transparent 2px,
    rgba(0, 240, 255, 0.015) 2px, rgba(0, 240, 255, 0.015) 4px
  );
  pointer-events: none;
  z-index: 9999;
  animation: scanline-scroll 8s linear infinite;
}
```

## Rails API Proxy: Bulk CLI Endpoint Pattern

When building a Rails app that proxies many CLI/REST endpoints from a backend service, use a **single API controller** with one action per endpoint. Register all routes in the `namespace :api` block. This keeps the service object as the sole integration point.

### Service Object — one method per endpoint

```ruby
class HermesApiService
  BASE_URL = ENV.fetch("HERMES_BACKEND_URL", "http://127.0.0.1:9120")

  # ── CLI Tools (bulk pattern) ────────────────────────────────────────
  def self.run_doctor;          get("/cli/doctor");         end
  def self.run_security_audit;  get("/cli/security");       end
  def self.get_dump;            get("/cli/dump");           end
  def self.create_backup;       post("/cli/backup", {});    end
  def self.get_checkpoints;     get("/cli/checkpoints");    end
  def self.get_proxy_status;    get("/cli/proxy");          end
  def self.get_insights;        get("/cli/insights");       end
  def self.list_webhooks;       get("/cli/webhooks");       end
  def self.list_hooks;          get("/cli/hooks");          end
  def self.list_mcp_servers;    get("/cli/mcp");            end
  def self.list_plugins;        get("/cli/plugins");        end
  def self.curator_status;      get("/cli/curator");        end
  def self.get_fallback_chain;  get("/cli/fallback");       end
  # ── Auth ────────────────────────────────────────────────────────────
  def self.auth_status;         get("/auth/status");        end
  # ── Gateway ─────────────────────────────────────────────────────────
  def self.get_gateway_platforms; get("/gateway/platforms"); end
end
```

### API Controller — one action per endpoint

```ruby
class ApiController < ApplicationController
  # ── CLI Tools ─────────────────────────────────────────────────────
  def cli_doctor
    render json: HermesApiService.run_doctor
  rescue HermesApiService::BackendError => e
    render json: { error: e.message }
  end

  def cli_backup
    render json: HermesApiService.create_backup
  rescue HermesApiService::BackendError => e
    render json: { error: e.message }
  end
  # ... repeat pattern for every endpoint
end
```

### Routes — register in bulk

```ruby
namespace :api do
  # ── CLI Tools ────────────────────────────────────────────────────
  get :cli_doctor
  post :cli_backup
  get :cli_security
  get :cli_dump
  get :cli_debug
  get :cli_checkpoints
  get :cli_proxy
  get :cli_secrets
  get :cli_pairing
  get :cli_insights
  get :cli_hooks
  get :cli_mcp
  get :cli_plugins
  get :cli_curator
  get :cli_fallback
  # ── Auth ─────────────────────────────────────────────────────────
  get :auth_status
  get :gateway_platforms
end
```

**PITFALL:** Each route creates a GET/POST endpoint matching the action name. The route helper creates `/api/cli_doctor` which maps to `ApiController#cli_doctor`. Keep names consistent between service method → controller action → route name.

### Stimulus CLI Runner Pattern

For UI that invokes CLI commands from the browser (doctor, backup, security check), use a generic Stimulus method that fetches the API endpoint and displays the result in a pre/code block:

```javascript
async function runCli(cmd) {
  const out = document.getElementById('cli-output');
  const text = document.getElementById('cli-output-text');
  out.style.display = 'block';
  text.textContent = 'Working...';

  const endpoint = `/api/cli_${cmd}`;
  const opts = cmd === 'backup' ? { method: 'POST' } : {};

  try {
    const res = await fetch(endpoint, { ...opts, headers: { 'Accept': 'application/json' } });
    const data = await res.json();
    text.textContent = data.output || data.status || data.dump || data.webhooks
      || data.hooks || data.users || data.insights || data.chain?.join('\n')
      || JSON.stringify(data, null, 2);
  } catch(e) {
    text.textContent = `Error: ${e.message}`;
  }
}
```

HTML buttons call `runCli('doctor')`, `runCli('backup')`, etc. The output panel shows/hides based on whether data is present. This works for all 15+ CLI endpoints with zero per-endpoint JavaScript.

### 22. **HTTP Basic Auth — timing-safe comparison**

When implementing HTTP basic auth manually, always use `ActiveSupport::SecurityUtils.secure_compare` instead of `==` to prevent timing attacks:

```ruby
# WRONG — timing attack vector:
if password == ENV['FORGE_HUB_PASSWORD']

# CORRECT — constant-time comparison:
if ActiveSupport::SecurityUtils.secure_compare(password, ENV['FORGE_HUB_PASSWORD'])
```

## Environment Detection on This Machine

```bash
# Current project examples
~/projects/yayo_studio/      # Rails 8.1.3 + PG + Tailwind v4
~/projects/forge/hub/        # Rails 8.1.3 + SQLite + Tailwind v4 (Rust CLI monorepo hub)
~/projects/blueprint/        # Rails 8.1.3

# Start a Rails dev server
cd ~/projects/yayo_studio && bin/rails server -p 3000

# Full path for bundle
~/.local/share/mise/installs/ruby/4.0.4/bin/bundle exec rails server
```

## Reference Files

- `references/external-daemon-adapter.md` — Service object adapter pattern for external daemons (TCP/Unix socket, mock fallback)
- `references/rspec-testing-patterns.md` — RSpec + FactoryBot setup, request spec pitfalls, factory validation rules, hash-to-model mapping
- `references/janus-api-client.md` — Full example: Rails app consuming 60+ endpoint external JSON API
- `references/dual-platform-proxy.md` — Rust backend serving both Flutter GUI and Rails webapp
- `references/socketio-stimulus-realtime.md` — Socket.IO + Stimulus integration (non-ActionCable)
