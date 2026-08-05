# Web Code Patterns — Hermes Wingman

Applied during v1.0.0 polish (May 2026). These are the DRY patterns that took the Rails web dashboard from "works" to "crafted."

## DRY HTTP Service Dispatcher

**Before (413 lines, duplicate HTTP setup 3x):**
```ruby
def self.post(path, body = {})
  uri = URI("#{BASE_URL}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 5
  http.read_timeout = TIMEOUT
  http.continue_timeout = nil
  request = Net::HTTP::Post.new(uri.request_uri)
  request["Content-Type"] = "application/json"
  request["Accept"] = "application/json"
  request.body = body.to_json
  response = http.start { |conn| conn.request(request) }
  parse_response(response, path)
end

def self.delete_request(path)  # ... identical pattern ...
def self.put_request(path, body = {})  # ... identical pattern ...
```

**After (one dispatcher, ~50 lines net reduction):**
```ruby
def self.request(method, path, body = nil)
  uri = URI("#{BASE_URL}#{path}")
  http = Net::HTTP.new(uri.host, uri.port)
  http.open_timeout = 5
  http.read_timeout = TIMEOUT
  http.continue_timeout = nil

  case method
  when :get
    uri.query = URI.encode_www_form(body) if body&.any?
    response = Net::HTTP.get_response(uri)
  when :post
    req = Net::HTTP::Post.new(uri.request_uri)
    req["Content-Type"] = "application/json"
    req["Accept"] = "application/json"
    req.body = (body || {}).to_json
    response = http.start { |conn| conn.request(req) }
  when :put
    # ... same pattern ...
  when :delete
    # ... same pattern ...
  end
  parse_response(response, path)
rescue EOFError, Errno::ECONNRESET, Errno::EPIPE, Timeout::Error, Net::OpenTimeout, Net::ReadTimeout => e
  raise BackendError, "Connection error to backend at #{path}: #{e.class}"
end

# Public wrappers delegate to the dispatcher
def self.get(path, params = {})    = request(:get, path, params)
def self.post(path, body = {})     = request(:post, path, body)
def self.put_request(path, body = {}) = request(:put, path, body)
def self.delete_request(path)      = request(:delete, path)
```

## Centralized Error Handling

**Before (243 lines, 30+ identical rescue blocks):**
```ruby
class ApiController < ApplicationController
  def health
    render json: HermesApiService.health
  rescue HermesApiService::BackendError => e
    render json: { error: e.message }
  end

  def status
    render json: HermesApiService.health
  rescue HermesApiService::BackendError => e
    render json: { error: e.message }
  end
  # ... 30+ more identical methods ...
end
```

**After (53 lines, no rescue blocks):**
```ruby
# application_controller.rb
class ApplicationController < ActionController::Base
  rescue_from HermesApiService::BackendError do |e|
    respond_to do |format|
      format.html { @error = e.message; render "shared/backend_error", status: :service_unavailable }
      format.json { render json: { error: e.message }, status: :service_unavailable }
    end
  end
end

# api_controller.rb — one-liners using Ruby 3.1 endless method syntax
class ApiController < ApplicationController
  def health  = render(json: HermesApiService.health)
  def status  = render(json: HermesApiService.health)
  def models  = render(json: HermesApiService.list_models)
  # ... 30 clean one-liners ...
end
```

## Numbers

| Metric | Before | After |
|--------|--------|-------|
| ApiController lines | 243 | 53 |
| Service duplicated HTTP setup | 3 copies | 1 dispatcher |
| Rescue blocks | 30+ per-controller | 1 global |
| Net reduction | — | **-191 lines** |
