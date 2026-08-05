# HermesApiService — Reference Implementation

A complete Rails service object that wraps all communication to an external Rust HTTP backend (Axum on port 9120). Demonstrates: Net::HTTP with timeouts, JSON parsing, error handling, GET/POST/DELETE patterns, and 20+ endpoint mappings.

## Key Design Decisions

- **Class methods** (not instances) — stateless HTTP, no initialization needed
- **`Net::HTTP`** stdlib — no Faraday/HTTParty dependency
- **`HermesApiService::BackendError`** — single exception class for all API errors
- **`rescue` in controller** — every controller action catches `BackendError` and sets `@error`
- **Environment-configurable** — `HERMES_BACKEND_URL` and `HERMES_TIMEOUT` env vars

## File Location

`app/services/hermes_api_service.rb`

## Complete Implementation

```ruby
# frozen_string_literal: true

require "net/http"
require "json"
require "uri"

class HermesApiService
  BASE_URL = ENV.fetch("HERMES_BACKEND_URL", "http://127.0.0.1:9120")
  TIMEOUT = ENV.fetch("HERMES_TIMEOUT", "10").to_i

  class BackendError < StandardError; end

  # ── Health & Status ──────────────────────────────────────────
  def self.health;        get("/health"); end
  def self.status;        health; end
  def self.hermes_version; get("/hermes/version"); end

  # ── Chat ─────────────────────────────────────────────────────
  def self.chat(message, session_id: nil)
    body = { message: message }
    body[:session_id] = session_id if session_id
    post("/chat", body)
  end

  def self.chat_stream_url(message, session_id: nil)
    params = { message: message }
    params[:session_id] = session_id if session_id
    "#{BASE_URL}/chat/stream?#{URI.encode_www_form(params)}"
  end

  # ── Sessions ─────────────────────────────────────────────────
  def self.list_sessions(limit: 20)
    get("/sessions", limit: limit)
  end

  def self.get_session(id)
    get("/sessions/#{id}")
  end

  def self.delete_session(id)
    delete_request("/sessions/#{id}")
  end

  # ── Models ───────────────────────────────────────────────────
  def self.list_models;          get("/models"); end
  def self.switch_model(name);   post("/models/switch", { model: name }); end
  def self.probe_model(name);    post("/models/probe", { model: name }); end

  # ── Config ───────────────────────────────────────────────────
  def self.get_config;           get("/config"); end
  def self.write_config(content); post("/config/write", { content: content }); end
  def self.update_config(updates); post("/config/update", { updates: updates }); end

  # ── Logs ─────────────────────────────────────────────────────
  def self.get_logs(lines: 50, level: "all")
    get("/logs", lines: lines, level: level)
  end

  # ── Cron ─────────────────────────────────────────────────────
  def self.list_cron_jobs;       get("/cron"); end

  # ── Gateway ──────────────────────────────────────────────────
  def self.get_gateway_status;   get("/gateway"); end
  def self.toggle_gateway(action); post("/gateway/toggle", { action: action }); end

  # ── Providers ────────────────────────────────────────────────
  def self.list_providers;       get("/providers"); end
  def self.probe_provider(name, api_key: nil, base_url: nil)
    body = { name: name }
    body[:api_key] = api_key if api_key
    body[:base_url] = base_url if base_url
    post("/setup/probe-provider", body)
  end

  # ── Setup ────────────────────────────────────────────────────
  def self.detect_setup;         get("/setup/detect"); end
  def self.install_hermes(method: "pip"); post("/setup/install", { method: method }); end
  def self.auto_configure;       post("/setup/auto-configure", {}); end

  # ── Hermes Management ────────────────────────────────────────
  def self.hermes_update;        post("/hermes/update", {}); end
  def self.list_skills;          get("/hermes/skills"); end
  def self.run_hermes_command(args); post("/hermes/command", { args: args }); end

  private

  def self.get(path, params = {})
    uri = URI("#{BASE_URL}#{path}")
    uri.query = URI.encode_www_form(params) if params.any?
    http = build_http(uri)
    request = Net::HTTP::Get.new(uri)
    parse_response(http.request(request), path)
  end

  def self.post(path, body = {})
    uri = URI("#{BASE_URL}#{path}")
    http = build_http(uri)
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = body.to_json
    parse_response(http.request(request), path)
  end

  def self.delete_request(path)
    uri = URI("#{BASE_URL}#{path}")
    http = build_http(uri)
    request = Net::HTTP::Delete.new(uri)
    parse_response(http.request(request), path)
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
      raise BackendError, "Backend error (#{response.code}): #{response.body&.truncate(200)}"
    end
  rescue JSON::ParserError => e
    raise BackendError, "Invalid JSON from backend at #{path}: #{e.message}"
  rescue Net::TimeoutError
    raise BackendError, "Backend timeout at #{path}"
  rescue Errno::ECONNREFUSED
    raise BackendError, "Cannot connect to backend at #{BASE_URL}"
  end
end
```

## Controller Pattern for Every Screen

Every controller follows the same pattern:

```ruby
class SomeController < ApplicationController
  def index
    @data = HermesApiService.some_endpoint
  rescue HermesApiService::BackendError => e
    @error = e.message
    @data = []
  end
end
```

## View Pattern for Error Display

```erb
<% if @error %>
  <div style="background: color-mix(in srgb, var(--accent-red) 10%, transparent);
              border: 1px solid color-mix(in srgb, var(--accent-red) 30%, transparent);
              border-radius: var(--radius-lg); padding: 12px 16px; margin-bottom: 16px;">
    <span style="color: var(--accent-red); font-size: 12px;">⚠ <%= @error %></span>
  </div>
<% end %>
```

## Routes Pattern (18+ Screens)

An app with this many resources needs organized routes. Group by domain, keep RESTful:

```ruby
Rails.application.routes.draw do
  root "dashboard#show"

  resource :chat, only: [:show, :create] do
    post :send_message
    get :stream, defaults: { format: :json }
  end

  resources :sessions, only: [:index, :show, :destroy] do
    post :resume, on: :member
  end

  resources :models, only: [:index] do
    post :switch, :probe, on: :member
    get :providers, on: :collection
  end

  resource :config, only: [:show, :update]
  resource :logs, only: [:show] do
    get :tail, on: :collection
  end

  resources :cron_jobs, only: [:index], controller: :cron do
    post :toggle, :run, on: :member
  end

  resource :gateway, only: [:show] do
    post :toggle
  end

  resources :providers, only: [:index] do
    post :probe, on: :member
  end

  resources :skills, only: [:index] do
    post :toggle, on: :member
  end

  resources :memory, only: [:index, :show, :update, :destroy] do
    post :search, on: :collection
  end

  resource :files, only: [:show] do
    get :browse, :read
    put :write
  end

  resources :inspector, only: [:show]
  resources :missions do
    post :run, :cancel, on: :member
  end

  resource :orchestration, only: [:show] do
    post :create_run
    get :status, on: :collection
  end

  resources :profiles do
    post :apply, on: :member
  end

  resources :webhooks
  resource :usage, only: [:show]
  resource :setup, only: [:show] do
    post :install, :configure, on: :collection
  end

  # API JSON endpoints for Stimulus controllers
  namespace :api do
    get :health, :status, :models, :sessions, :logs, :cron,
        :gateway, :providers, :skills, :memory, :missions,
        :profiles, :webhooks, :usage
  end

  # Theme switcher
  post "theme/:name", to: "theme#switch", as: :switch_theme
end
```
