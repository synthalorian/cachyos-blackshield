# Dual-Platform Proxy Architecture (Rust Backend → Flutter + Rails)

Architecture pattern where a single Rust HTTP backend (Axum) serves two independent UI clients simultaneously: a Flutter mobile/desktop GUI and a Rails webapp. The Rails app acts as a UI layer, never calling `hermes` CLI directly — all CLI interaction goes through the Rust backend.

## Architecture Diagram

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│   Flutter    │    │  Rails Web   │    │  Browser     │
│   (APK/GUI)  │    │  (Port 3000) │    │  (SSE via    │
│              │    │              │    │   EventSrc)  │
└──────┬───────┘    └──────┬───────┘    └──────┬───────┘
       │                   │                   │
       │ HTTP              │ HTTP              │ SSE
       ▼                   ▼                   ▼
┌──────────────────────────────────────────────────────┐
│           Rust Backend (Axum, Port 9120)              │
│                                                        │
│  ┌──────────────────────────────────────────────────┐  │
│  │  31 HTTP endpoints                               │  │
│  │  /health, /config, /models, /chat/stream,         │  │
│  │  /sessions, /logs, /gateway, /cron, /providers,   │  │
│  │  /skills, /memory, /files, /hermes/*, /setup/*    │  │
│  └──────────────────────┬───────────────────────────┘  │
│                         │                               │
│                         ▼                               │
│              ┌──────────────────────┐                   │
│              │  hermes CLI binary   │                   │
│              │  (/home/synth/.local/│                   │
│              │   bin/hermes)        │                   │
│              └──────────────────────┘                   │
└──────────────────────────────────────────────────────┘
```

## Why This Pattern

- **Single source of truth** — CLI interaction is centralized in the Rust backend. Both UIs get identical data.
- **Flutter can work offline** — the APK connects directly to the Rust backend locally or remotely.
- **Rails is stateless** — no process management, no binary discovery, no PATH issues. Rails just makes HTTP calls.
- **Remote access** — mobile Flutter app connects to a backend running on a desktop machine via configurable host:port.
- **Zero duplication** — no CLI argument parsing, no output parsing, no config file parsing in Rails. All that lives in Rust.

## Rails HermesApiService Pattern

The Rails service object wraps all 31 Rust endpoints as class methods. Every controller uses the same pattern:

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

See `references/hermes-api-service.md` for the complete service implementation.

## Theme Synchronization

Themes are defined once in the Flutter app (`app_theme.dart`) and replicated as CSS custom properties in the Rails webapp (`app/assets/tailwind/application.css`). Both use the same 30+ theme palette with the same hex values. Theme switching is:

- **Flutter**: ChangeNotifier + Provider → rebuilds widget tree
- **Rails**: `data-theme` attribute on `<html>` → CSS custom properties cascade → instant re-theming
- **Persistence**: Flutter saves to local storage, Rails stores in session cookie

## SSE Streaming Path

Chat (the most latency-sensitive feature) uses SSE streaming:

1. **Flutter**: POSTs to Rust backend `/chat/stream?message=...` → receives SSE events → renders in real-time
2. **Rails**: Controller returns `{ stream_url: "http://backend:9120/chat/stream?message=..." }` → Stimulus JS connects via `EventSource` directly (no Rails proxy) → renders in real-time

The Rails app never proxies the SSE stream — it just returns the backend URL. The browser connects directly. This avoids double-streaming through Rails.

## Benefits for the Webapp

- **Works without Flutter** — the Rails app is fully standalone. Start the Rust backend and the Rails server, open the browser.
- **Works without GUI** — the Rails app alone gives you a web interface to the full Hermes Agent functionality.
- **Windows support** — when Hermes CLI supports Windows, only the Rust backend needs adjustment. The Rails UI is already cross-platform (browser).

## Key Files in the Hermes Wingman Project

| Layer | Key Files |
|-------|-----------|
| Rust backend | `backend/src/main.rs` (31 routes, 2000+ lines) |
| Flutter GUI | `lib/` (10 screens, 30 themes) |
| Rails webapp | `app/` (18 controllers, 20+ views, HermesApiService) |
| HermesApiService | `app/services/hermes_api_service.rb` |
| Layout | `app/views/layouts/application.html.erb` (sidebar + header) |
| Theme CSS | `app/assets/tailwind/application.css` (30 themes as CSS vars) |
| Chat Stimulus | `app/javascript/controllers/chat_controller.js` (SSE streaming) |
