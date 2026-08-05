# Socket.IO + Stimulus Real-Time Integration

When a Rails app needs real-time updates from an external backend using Socket.IO (not ActionCable), use a Stimulus controller that connects directly from the browser via the Socket.IO client library.

## Architecture

```
Browser (Stimulus controller)
       │ Socket.IO client (CDN)
       ▼
External Backend (Socket.IO server, e.g. Node.js on port 3001)
       │ WebSocket events: message:new, channel:join, user:typing, etc.
       ▼
Real-time UI updates (Turbo Streams or DOM manipulation)
```

## Setup

### 1. Add Socket.IO CDN to Layout

```erb
<%# app/views/layouts/application.html.erb %>
<script src="https://cdn.socket.io/4.8.1/socket.io.min.js"
        integrity="sha384-..."
        crossorigin="anonymous"></script>
```

### 2. Create a Stimulus Controller

```javascript
// app/javascript/controllers/chat_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "empty"]

  connect() {
    this.socket = null
    this.currentChannelId = null
    this.connected = false
    this.token = document.querySelector('meta[name="csrf-token"]')?.content
  }

  disconnect() {
    this.disconnectSocket()
  }

  connectSocket() {
    if (this.connected || typeof io === 'undefined') return

    try {
      this.socket = io('http://localhost:3001', {
        transports: ['websocket', 'polling'],
        reconnection: true,
        reconnectionDelay: 2000,
      })

      this.socket.on('connect', () => {
        this.connected = true
        this.updateConnectionStatus(true)
      })

      this.socket.on('message:new', (message) => {
        this.appendMessage(message)
      })

      this.socket.on('disconnect', () => {
        this.connected = false
        this.updateConnectionStatus(false)
      })
    } catch (e) {
      console.warn('Socket.IO unavailable')
    }
  }

  joinChannel(channelId) {
    if (this.currentChannelId) {
      this.socket?.emit('channel:leave', this.currentChannelId)
    }
    this.currentChannelId = channelId
    this.socket?.emit('channel:join', channelId)
  }

  appendMessage(message) {
    if (!this.hasMessagesTarget || message.channelId !== this.currentChannelId) return
    // Create and append message bubble
    const bubble = document.createElement('div')
    bubble.className = `chat-message ${message.authorType === 'human' ? 'user' : 'ai'}`
    bubble.textContent = message.content
    this.messagesTarget.appendChild(bubble)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
  }

  updateConnectionStatus(connected) {
    const el = document.getElementById('connection-indicator')
    if (el) {
      el.innerHTML = connected
        ? '<span class="dot connected"></span><span>Connected</span>'
        : '<span class="dot disconnected"></span><span>Disconnected</span>'
    }
  }
}
```

### 3. Wire It in the View

```erb
<div data-controller="chat"
     data-chat-user-id="<%= current_user_id %>"
     data-chat-user-name="<%= current_user_name %>">
  <div class="chat-messages" data-chat-target="messages">
    <% @messages.each do |msg| %>
      <%= render "message", message: msg %>
    <% end %>
  </div>
  <%= form_tag send_message_path, method: :post, data: { action: "submit->chat#send" } do %>
    <textarea data-chat-target="input" data-action="keydown->chat#handleKeydown"></textarea>
    <button type="submit" data-chat-target="sendBtn">SEND</button>
  <% end %>
</div>

<script>
document.addEventListener('turbo:load', () => {
  const el = document.querySelector('[data-controller="chat"]')
  if (el) {
    const ctrl = el.__stimulus_controller
    if (ctrl?.connectSocket) ctrl.connectSocket()
  }
})
</script>
```

## How Frontend and Backend Events Map

| Frontend (Rails) | Backend (Socket.IO) | Description |
|-----------------|-------------------|-------------|
| `socket.emit('channel:join', id)` | Listens `channel:join` | User joins a channel room |
| `socket.emit('channel:leave', id)` | Listens `channel:leave` | User leaves a channel room |
| `socket.emit('message:send', data)` | Listens `message:send` → broadcasts `message:new` | Send message via WebSocket |
| — | Emits `message:new` to room | Incoming message broadcast |
| — | Emits `message:stream:start/chunk/end` | AI streaming response |
| — | Emits `user:typing` | Typing indicator |

## Dual-Path Message Sending

For reliability, send messages via BOTH the HTTP API (reliable, always works) AND WebSocket (real-time):

```javascript
send(event) {
  event.preventDefault()
  // Always POST via HTTP for reliability
  fetch('/messages', { method: 'POST', body: formData })

  // Also emit via WebSocket for real-time broadcast
  if (this.connected) {
    this.socket.emit('message:send', { content, channelId, authorId, authorName })
  }
}
```

## Pitfalls

**PITFALL: `turbo:load` event must be used** — Stimulus `connect()` fires once per page load. Turbo Drive replaces the body without re-triggering `connect()`. Always use `document.addEventListener('turbo:load', ...)` to initialize Socket.IO after Turbo navigation.

**PITFALL: CDN CORS** — The Socket.IO server must allow the Rails origin (or `*` in development). Without CORS headers, the browser blocks the WebSocket connection. Socket.IO server config: `cors: { origin: "*" }`.

**PITFALL: `io` global not available before Turbo loads** — If Socket.IO CDN is in the `<head>` and Turbo replaces `<body>`, the `io` global persists. But if you navigate to a page without the CDN script, `io` is undefined. Ensure the CDN script is in the layout (not a specific view).

**PITFALL: Connection indicator on page change** — The `data-chat-target` elements are recreated on each Turbo visit. Store the connection status in a persistent element outside the chat view (e.g. in the main layout header) and update it via the Stimulus controller.

## When to Use This vs ActionCable

- **Use Socket.IO + Stimulus** when the real-time backend is a non-Rails service (Node.js, Python, Rust) that already has Socket.IO running
- **Use ActionCable** when the Rails app IS the real-time backend and you control both the broadcasting and receiving sides
- **Use SSE (EventSource)** for one-way streaming from backend to frontend (e.g. AI response streaming) — simpler than WebSocket, no client library needed