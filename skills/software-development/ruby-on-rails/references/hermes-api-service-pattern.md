# HermesApiService Pattern — Rails Proxy to External Rust Backend

Used in `synthalorian/hermes-wingman-web`. Rails app proxies all API calls to a Rust Axum backend on port 9120 via a single service class.

## Service Object Anatomy

```ruby
# app/services/hermes_api_service.rb
class HermesApiService
  BASE_URL = ENV.fetch("HERMES_BACKEND_URL", "http://127.0.0.1:9120")
  TIMEOUT = ENV.fetch("HERMES_TIMEOUT", "10").to_i

  class BackendError < StandardError; end

  def self.health
    get("/health")
  end

  # Each REST endpoint gets a class method:
  def self.chat(message, session_id: nil)
    body = { message: message }
    body[:session_id] = session_id if session_id
    post("/chat", body)
  end

  # SSE streaming requires returning the URL, not proxying
  def self.chat_stream_url(message, session_id: nil)
    params = { message: message }
    params[:session_id] = session_id if session_id
    "#{BASE_URL}/chat/stream?#{URI.encode_www_form(params)}"
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

  def self.put_request(path, body = {})
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Put.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json
    response = Net::HTTP.start(uri.hostname, uri.port,
      open_timeout: 5, read_timeout: TIMEOUT) do |http|
      http.request(request)
    end
    parse_response(response, path)
  end

  def self.delete_request(path)
    uri = URI("#{BASE_URL}#{path}")
    request = Net::HTTP::Delete.new(uri)
    response = Net::HTTP.start(uri.hostname, uri.port,
      open_timeout: 5, read_timeout: TIMEOUT) do |http|
      http.request(request)
    end
    parse_response(response, path)
  end

  ## EOFError Prevention

  All HTTP methods must use `Net::HTTP.start(...) { |http| ... }` block syntax — NOT `Net::HTTP.new` + `.request`.

  `Net::HTTP.new` + `.request` (the old build_http pattern) causes intermittent `EOFError: end of file reached` in long-running Rails servers due to stale TCP connections. The `start` block properly manages connection lifecycle — opens, uses, and closes within the block — preventing connection reuse issues.

  ## Pitfalls

  - **EOFError from stale connections**: If a controller crashes mid-request, `Net::HTTP.new` connections can leak and enter a broken state. The `start` block pattern prevents this entirely.
  - **`.hostname` vs `.host`**: Ruby's `URI` object provides both. `uri.hostname` is preferred for `Net::HTTP.start` — it's the same as `uri.host` but more explicit about DNS resolution.
  - **Timeout defaults**: Always set `open_timeout: 5, read_timeout: TIMEOUT`. Without them, the Rails process can block indefinitely if the backend hangs.

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
      raise BackendError, "Backend error (#{response.code}): #{response.body&.truncate(200)}"
    end
  rescue JSON::ParserError => e
    raise BackendError, "Invalid JSON from backend at #{path}: #{e.message}"
  rescue Net::TimeoutError
    raise BackendError, "Backend timeout at #{path} (backend may be down)"
  rescue Errno::ECONNREFUSED
    raise BackendError, "Cannot connect to backend at #{BASE_URL}. Is backend running?"
  end
end
```

## Key Patterns

- **Class methods** (not instances) — stateless, no initialization needed in controllers
- **All calls are synchronous** — Rails request cycle blocks; for async use ActiveJob + Solid Queue
- **Error propagation** — BackendError is rescued in each controller and shown as `@error` in views
- **SSE URLs are returned as strings** — the browser opens the EventSource directly against the backend; Rails never proxies the SSE stream itself

## SSE Streaming in Rails Views

```erb
<%# In the view — no Action Cable needed %>
<div data-controller="chat">
  <div data-chat-target="messages"></div>
  <input data-chat-target="input" data-action="keydown->chat#send">
</div>
```

```javascript
// Stimulus controller
connect() {
  // Browser JS opens EventSource directly against the Rust backend
}

send(event) {
  fetch('/chat/send_message', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': csrfToken },
    body: JSON.stringify({ message: this.inputTarget.value })
  })
  .then(r => r.json())
  .then(data => {
    if (data.stream_url) {
      this.connectStream(data.stream_url);
    }
  });
}

connectStream(url) {
  const source = new EventSource(url);
  source.addEventListener('message', (e) => {
    if (e.data === '[DONE]') { source.close(); return; }
    const json = JSON.parse(e.data);
    if (json.content) this.appendContent(json.content);
  });
}
```

## Multi-Theme CSS (30 themes in Tailwind v4)

The theme system uses `[data-theme="..."]` CSS attribute selectors — one per theme — each defining ~60 CSS custom properties for the entire palette. The layout HTML element gets `data-theme` set from a session cookie:

```ruby
# ThemeController
def switch
  session[:theme] = params[:name]
  redirect_back fallback_location: "/"
end
```

```erb
<%# In layout %>
<html lang="en" data-theme="<%= session[:theme] || 'synthwave84' %>">
```

```css
/* themes as CSS attribute selectors */
[data-theme="synthwave84"] {
  --bg-primary: #0D0221;
  --accent-primary: #8F00FF;
  /* ... 60+ variables */
}
[data-theme="outrun"] { /* ... */ }
/* One block per theme — ~29KB total for 30 themes */
```
