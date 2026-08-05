# Rails Web Dashboard Bug Fixes — Session Recipe

Concrete bugs found and fixed during v1.0.0 web app production polish.

## Bug 1: Missing Controller File

**Error:** `ActionDispatch::MissingController (uninitialized constant GatewaySetupController)`
**Root cause:** Route existed in `config/routes.rb` but controller file was never created.

```ruby
# routes.rb — this route was present
resource :gateway_setup, only: [:show], controller: :gateway_setup, path: '/gateway_setup'
```

**Fix:** Create the missing controller + view.

```ruby
# app/controllers/gateway_setup_controller.rb
class GatewaySetupController < ApplicationController
  def show
    @platforms = HermesApiService.get_gateway_platforms rescue {}
    @status = HermesApiService.get_gateway_status rescue {}
  end
end
```

```erb
<!-- app/views/gateway_setup/show.html.erb -->
<div class="page-content">
  <div class="section-header">
    <h1 class="section-title">Gateway Setup</h1>
  </div>
  <div class="card-glass">
    <div class="card-body">
      <% if @platforms.present? %>
        <pre class="text-mono text-sm"><%= JSON.pretty_generate(@platforms) %></pre>
      <% else %>
        <div class="empty-state">...</div>
      <% end %>
    </div>
  </div>
</div>
```

**Prevention:** After adding routes, verify controllers exist:
```bash
bin/rails routes | grep gateway_setup
bin/rails runner "puts GatewaySetupController"  # confirms it loads
```

---

## Bug 2: Controller Action Shadowing Built-in Method

**Error:** `SystemStackError (stack level too deep)` — infinite recursion
**Stack trace loops:** `InspectorController#session → application.html.erb → InspectorController#session → ...`

**Root cause:** Naming a controller action `session` shadows `ActionController#session`, the hash accessor for session storage. The layout calls `session[:theme]` which hits the action instead of the hash, causing infinite recursion.

```ruby
# BEFORE — broken
class InspectorController < ApplicationController
  def session
    @session_id = params[:id]
    render :show
  end
end
```

```ruby
# AFTER — fixed
class InspectorController < ApplicationController
  def session_detail
    @session_id = params[:id]
    render :show
  end
end
```

Also update routes:
```ruby
# routes.rb
resources :inspector do
  collection do
    get :session_detail  # was :session
  end
end
```

**Rule:** Never name controller actions after built-in `ActionController` methods: `session`, `cookies`, `params`, `request`, `response`, `flash`, `headers`, `render`, `redirect_to`, etc.

---

## Bug 3: Raw `<img>` Bypassing Asset Pipeline

**Symptom:** Hermes Wingman PNG icon doesn't load (404 in browser console)
**Root cause:** Layout used raw HTML `<img src="/assets/hermes-wingman.png">` which bypasses Propshaft (Rails 8 asset pipeline). Propshaft fingerprints assets with digests in production.

```erb
<!-- BEFORE — broken in production -->
<img src="/assets/hermes-wingman.png" alt="HW" style="width:32px;height:32px;">

<!-- AFTER — works everywhere -->
<%= image_tag "hermes-wingman.png", alt: "HW", style: "width:32px;height:32px;border-radius:6px;object-fit:cover" %>
```

**Rule:** Always use Rails asset helpers (`image_tag`, `stylesheet_link_tag`, `javascript_importmap_tags`) instead of raw `<img>`, `<link>`, `<script>` tags for assets in `app/assets/`.

---

## Verification Commands

```bash
cd web

# Verify all routes have controllers
bin/rails routes | awk '{print $4}' | sort -u | while read c; do
  file="app/controllers/${c%#*}_controller.rb"
  [ -f "$file" ] || echo "MISSING: $file for route $c"
done

# Verify no controller action shadows built-in methods
# (manual review — grep for def session/cookies/params/response in controllers)
grep -rn "def \(session\|cookies\|params\|request\|response\|flash\|headers\)$" app/controllers/

# Start server and smoke-test
bin/rails server -b 127.0.0.1 -p 3000 &
curl -s http://127.0.0.1:3000/up
curl -s http://127.0.0.1:3000/gateway_setup
curl -s http://127.0.0.1:3000/inspector/session_detail
```
