# Socket.IO Multi-Platform Integration

Real-time WebSocket patterns for serving the same Socket.IO backend to three different frontend platforms: Tauri desktop, Flutter mobile, and Rails web.

## Backend Event Protocol (Node.js + Socket.IO)

```typescript
// src/backend/src/socket/handler.ts
io.on('connection', (socket) => {
  socket.on('auth', ({ token, userId, userName, userType }) => {
    socket.userId = userId;
    socket.emit('auth:success', { userId });
  });

  socket.on('channel:join', (channelId) => {
    socket.join(channelId);
    socket.emit('messages:history', { channelId, messages: [...] });
  });

  socket.on('channel:leave', (channelId) => {
    socket.leave(channelId);
  });

  socket.on('message:send', (data) => {
    // Persist via REST or direct DB call
    // Broadcast to room
    io.to(data.channelId).emit('message:new', savedMessage);
  });

  // AI streaming
  socket.on('message:stream:start', (data) => {
    io.to(data.channelId).emit('message:stream:start', data);
  });
  socket.on('message:stream:chunk', (data) => {
    io.to(data.channelId).emit('message:stream:chunk', data);
  });
  socket.on('message:stream:end', (message) => {
    io.to(message.channelId).emit('message:stream:end', message);
  });

  // Typing indicators
  socket.on('typing:start', (data) => {
    socket.to(data.channelId).emit('user:typing', data);
  });
  socket.on('typing:stop', (data) => {
    socket.to(data.channelId).emit('user:stopped-typing', data);
  });

  // Presence
  socket.on('presence', (data) => {
    socket.broadcast.emit('presence:update', data);
  });

  // Orchestration
  socket.on('orchestrate:subscribe', (planId) => {
    socket.join('plan:' + planId);
  });
});
```

## Desktop (Tauri 2) — Vanilla JS

See `tauri-desktop-development` skill for the full SocketManager pattern. Key points:
- Load Socket.IO from CDN in HTML `<head>`
- Detect Tauri with `typeof window.__TAURI__ !== 'undefined'`
- Use `io(API_BASE)` for connection
- Map REST calls to Tauri `invoke()` commands, fallback to `fetch()`
- Re-join channel on reconnect

## Mobile (Flutter) — Dart + socket_io_client

### pubspec.yaml
```yaml
dependencies:
  socket_io_client: ^3.0.2
```

### SocketService
```dart
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'dart:async';

class SocketService extends ChangeNotifier {
  io.Socket? _socket;
  String? currentChannelId;
  bool _connected = false;

  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamStartController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamChunkController = StreamController<Map<String, dynamic>>.broadcast();
  final _streamEndController = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<Map<String, dynamic>> get streamStartStream => _streamStartController.stream;
  Stream<Map<String, dynamic>> get streamChunkStream => _streamChunkController.stream;
  Stream<Map<String, dynamic>> get streamEndStream => _streamEndController.stream;

  bool get isConnected => _connected;

  void connect({required String token, required String userId, required String userName, required String userType}) {
    final baseUrl = Platform.isAndroid ? 'http://10.0.2.2:3001' : 'http://localhost:3001';
    _socket = io.io(baseUrl, io.OptionBuilder()
      .setTransports(['websocket', 'polling'])
      .enableReconnection()
      .setReconnectionDelay(2000)
      .setReconnectionAttempts(10)
      .build());

    _socket!.onConnect((_) {
      _connected = true;
      notifyListeners();
      _socket!.emit('auth', {'token': token, 'userId': userId, 'userName': userName, 'userType': userType});
    });

    _socket!.onDisconnect((_) {
      _connected = false;
      notifyListeners();
    });

    _socket!.on('message:new', (data) => _messageController.add(data));
    _socket!.on('message:stream:start', (data) => _streamStartController.add(data));
    _socket!.on('message:stream:chunk', (data) => _streamChunkController.add(data));
    _socket!.on('message:stream:end', (data) => _streamEndController.add(data));
  }

  void joinChannel(String channelId) {
    if (currentChannelId != null && currentChannelId != channelId) {
      _socket?.emit('channel:leave', currentChannelId);
    }
    currentChannelId = channelId;
    _socket?.emit('channel:join', channelId);
  }

  void leaveChannel(String channelId) {
    _socket?.emit('channel:leave', channelId);
    if (currentChannelId == channelId) currentChannelId = null;
  }

  void sendMessage({required String channelId, required String content, required String authorId, required String authorName, required String authorType}) {
    _socket?.emit('message:send', {
      'channelId': channelId,
      'content': content,
      'authorId': authorId,
      'authorName': authorName,
      'authorType': authorType,
    });
  }

  @override
  void dispose() {
    _socket?.disconnect();
    _messageController.close();
    _streamStartController.close();
    _streamChunkController.close();
    _streamEndController.close();
    super.dispose();
  }
}
```

### Chat Screen Integration
```dart
class _ChatScreenState extends State<ChatScreen> {
  StreamSubscription? _messageSub;
  StreamSubscription? _streamStartSub;
  StreamSubscription? _streamChunkSub;
  StreamSubscription? _streamEndSub;
  final Map<String, String> _streamingMessages = {};

  @override
  void initState() {
    super.initState();
    _listenToSocket();
  }

  void _listenToSocket() {
    final socket = context.read<SocketService>();

    _messageSub = socket.messageStream.listen((data) {
      if (!mounted) return;
      final msg = Message.fromJson(data);
      if (_selectedChannel != null && msg.channelId == _selectedChannel!.id) {
        setState(() => _messages.add(msg));
        _scrollToBottom();
      }
    });

    _streamStartSub = socket.streamStartStream.listen((data) {
      // Create placeholder message
    });

    _streamChunkSub = socket.streamChunkStream.listen((data) {
      // Append chunk to placeholder
    });

    _streamEndSub = socket.streamEndStream.listen((data) {
      // Replace placeholder with final
    });
  }

  void _selectChannel(Channel channel) {
    setState(() => _selectedChannel = channel);
    _loadMessages(channel.id);

    final api = context.read<JanusApiService>();
    final socket = context.read<SocketService>();
    if (!socket.isConnected) {
      socket.connect(
        token: api.isAuthenticated ? 'flutter-client-token' : '',
        userId: api.userId ?? 'unknown',
        userName: api.userName ?? 'Unknown',
        userType: 'human',
      );
    }
    socket.joinChannel(channel.id);
  }

  Future<void> _sendMessage() async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _selectedChannel == null) return;
    _messageController.clear();

    final api = context.read<JanusApiService>();
    final socket = context.read<SocketService>();

    // Optimistic UI
    final optimisticMsg = Message(
      id: 'local-${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      authorId: api.userId ?? 'unknown',
      authorName: api.userName ?? 'Unknown',
      authorType: 'human',
      channelId: _selectedChannel!.id,
      timestamp: DateTime.now().toIso8601String(),
    );
    setState(() => _messages.add(optimisticMsg));
    _scrollToBottom();

    if (socket.isConnected) {
      socket.sendMessage(/* ... */);
    } else {
      await api.sendMessage(_selectedChannel!.id, content);
    }
  }
}
```

## Web (Rails 8) — Stimulus + Socket.IO

### Load Socket.IO
Add to `app/views/layouts/application.html.erb`:
```erb
<script src="https://cdn.socket.io/4.8.1/socket.io.min.js"
  integrity="sha384-mkQ3/7FUtcGyoppY6bz/PORYoGqOl7/aSUMn2ymDOJcapfS6PHqxhRTMh1RR0Q6+"
  crossorigin="anonymous"></script>
```

### Stimulus Chat Controller
```javascript
// app/javascript/controllers/chat_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["messages", "input", "empty"]
  static values = {
    userId: String,
    userName: String,
    userType: { type: String, default: "human" },
    channelId: String,
    token: String,
    socketUrl: { type: String, default: "http://localhost:3001" }
  }

  connect() {
    this.currentChannelId = this.hasChannelIdValue ? this.channelIdValue : null
    this.connected = false
    this.streamMessages = new Map()
    this.connectSocket()
  }

  disconnect() {
    this.disconnectSocket()
  }

  connectSocket() {
    if (this.connected || typeof io === 'undefined') return

    this.socket = io(this.socketUrlValue, {
      transports: ['websocket', 'polling'],
      reconnection: true,
      reconnectionDelay: 2000,
      reconnectionAttempts: Infinity,
    })

    this.socket.on('connect', () => {
      this.connected = true
      this.authenticate()
      if (this.currentChannelId) this.joinChannel(this.currentChannelId)
    })

    this.socket.on('message:new', (msg) => this.appendMessage(msg))
    this.socket.on('message:stream:start', (data) => this.startStreamingMessage(data))
    this.socket.on('message:stream:chunk', (data) => this.appendStreamChunk(data))
    this.socket.on('message:stream:end', (msg) => this.finalizeStreamingMessage(msg))
    this.socket.on('user:typing', (data) => this.showTypingIndicator(data))
    this.socket.on('user:stopped-typing', (data) => this.hideTypingIndicator(data))
  }

  authenticate() {
    this.socket.emit('auth', {
      token: this.tokenValue,
      userId: this.userIdValue,
      userName: this.userNameValue,
      userType: this.userTypeValue
    })
  }

  joinChannel(channelId) {
    if (this.currentChannelId && this.currentChannelId !== channelId) {
      this.socket.emit('channel:leave', this.currentChannelId)
    }
    this.currentChannelId = channelId
    this.socket.emit('channel:join', channelId)
  }

  send(event) {
    event.preventDefault()
    const content = this.inputTarget.value.trim()
    if (!content) return

    // Dual delivery: REST (reliable) + WebSocket (real-time)
    const form = event.target
    fetch(form.action, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.csrfToken,
        'Accept': 'text/html'
      },
      body: new FormData(form)
    }).then(() => {
      this.inputTarget.value = ''
    })

    if (this.connected && this.currentChannelId) {
      this.socket.emit('message:send', {
        content, channelId: this.currentChannelId,
        authorId: this.userIdValue, authorName: this.userNameValue, authorType: this.userTypeValue
      })
    }
  }

  appendMessage(message) {
    const msgChannelId = message.channelId || message.channel_id
    if (msgChannelId && msgChannelId !== this.currentChannelId) return
    this.hideEmpty()
    const bubble = document.createElement('div')
    bubble.className = `chat-message ${message.authorType === 'human' ? 'user' : 'ai'}`
    bubble.innerHTML = `...` // format
    this.messagesTarget.appendChild(bubble)
    this.scrollToBottom()
  }

  startStreamingMessage(data) { /* create placeholder */ }
  appendStreamChunk(data) { /* append to placeholder */ }
  finalizeStreamingMessage(message) { /* replace placeholder */ }
  showTypingIndicator(data) { /* show "X is typing..." */ }
  hideTypingIndicator(data) { /* remove indicator */ }
  hideEmpty() { if (this.hasEmptyTarget) this.emptyTarget.style.display = 'none' }
  scrollToBottom() { if (this.hasMessagesTarget) this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight }
}
```

### ERB View
```erb
<div data-controller="chat"
     data-chat-user-id-value="<%= current_user["id"] %>"
     data-chat-user-name-value="<%= current_user["name"] %>"
     data-chat-channel-id-value="<%= @current_channel_id %>"
     data-chat-token-value="<%= current_token %>"
     data-chat-socket-url-value="<%= ENV.fetch("JANUS_SOCKET_URL", "http://localhost:3001") %>">
  <!-- messages container -->
  <div data-chat-target="messages">...</div>
  <!-- empty state -->
  <div data-chat-target="empty">No messages yet</div>
  <!-- form -->
  <%= form_with url: send_message_path, data: { action: "submit->chat#send" } do |f| %>
    <%= f.text_area :content, data: { chat_target: "input" } %>
    <%= f.submit "Send" %>
  <% end %>
</div>
```

## Feature Parity Matrix (Updated)

| Feature | Desktop (Tauri) | Mobile (Flutter) | Web (Rails) |
|---------|-----------------|------------------|-------------|
| REST API | ✅ | ✅ | ✅ |
| Auth (register) | ✅ | ✅ | ✅ |
| Real-time (Socket.IO) | ✅ | ✅ | ✅ |
| AI streaming | ✅ | ✅ | ✅ |
| Typing indicators | ✅ | ✅ | ✅ |
| Presence updates | ✅ | ✅ | ✅ |
| Orchestration events | ✅ | ❌ | ✅ |
| Push notifications | N/A | ❌ | ❌ |
| System tray | ❌ | N/A | N/A |
| Offline cache | ❌ | ❌ | ❌ |
| Biometric auth | N/A | ❌ | ❌ |

## Verification Checklist

- [ ] All three clients connect to Socket.IO and receive `auth:success`
- [ ] `channel:join` triggers `messages:history` on all platforms
- [ ] `message:send` → `message:new` round-trip under 100ms
- [ ] AI streaming (start/chunk/end) renders correctly on all platforms
- [ ] Typing indicators appear/disappear correctly
- [ ] Reconnect rejoins channel automatically
- [ ] REST fallback works when socket is disconnected
