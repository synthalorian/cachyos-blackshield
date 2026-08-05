# Flutter Chat Session Persistence & Tabbed UI

**Pattern**: Managing multiple chat sessions that survive Flutter widget tree rebuilds (navigation, tab switches, etc.) using a ChangeNotifier service with JSON file persistence.

## Architecture

### Core Classes

```
ChatManager (ChangeNotifier)  ← app-level Provider
├── List<ChatSession>
├── int activeIndex
├── createSession()
├── deleteSession(idx)
├── switchTo(idx)
├── addMessage(sessionId, msg)
├── updateLastMessage(sessionId, msg)
└── _save() / _load()  ← JSON to ~/.hermes/wingman_chats.json

ChatSession
├── String id
├── String title
├── List<ChatMessage>
└── DateTime createdAt

ChatMessage
├── String text
├── bool isUser
├── DateTime timestamp
└── String? sessionId
```

### Key Insight: State Survival

Flutter's widget tree rebuilds when the parent switches `_screens[_selectedIndex]` — only one screen widget is in the tree at a time. **A StatefulWidget's state is destroyed when the widget is removed from the tree.** To keep chat state alive:

**WRONG:** Store messages in the StatefulWidget's state (`List<ChatMessage> _messages` in `_ChatScreenState`). When the user switches sidebar tabs and comes back, the widget is recreated with empty state.

**RIGHT:** Store messages in a ChangeNotifier (`ChatManager`) provided at the app level via `MultiProvider`. The chat screen watches the provider and reads `activeSession.messages`. State survives any number of widget rebuilds because the service lives in the provider tree, not the widget tree.

```dart
// main.dart — ChatManager provided at app root
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => ChatManager()),
    // ... other providers
  ],
)

// chat_screen.dart — reads from provider, never local state
final mgr = context.watch<ChatManager>();
final messages = mgr.activeMessages;
```

### JSON Persistence

Chat sessions survive app restarts by persisting to `~/.hermes/wingman_chats.json`:

```dart
class ChatManager extends ChangeNotifier {
  static const String _savePath = 'wingman_chats.json';

  String get _saveDir {
    final home = Platform.environment['HOME']
        ?? Platform.environment['USERPROFILE']
        ?? '/tmp';
    return '$home/.hermes';
  }

  void _save() {
    try {
      final file = File('$_saveDir/$_savePath');
      file.writeAsStringSync(
        jsonEncode(_sessions.map((s) => s.toJson()).toList())
      );
    } catch (e) {
      debugPrint('[ChatManager] Save failed: $e');
    }
  }

  void _load() {
    try {
      final file = File('$_saveDir/$_savePath');
      if (file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync()) as List;
        _sessions = data.map((s) =>
          ChatSession.fromJson(s as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      debugPrint('[ChatManager] Load failed: $e');
    }
  }
}
```

Each model class has `toJson()` / `fromJson()` for serialization:

```dart
class ChatMessage {
  Map<String, dynamic> toJson() => {
    'text': text,
    'isUser': isUser,
    'timestamp': timestamp.toIso8601String(),
    'sessionId': sessionId,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    text: json['text'] as String? ?? '',
    isUser: json['isUser'] as bool? ?? false,
    timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
    sessionId: json['sessionId'] as String?,
  );
}
```

### Tabbed Chat UI

The tab bar is a horizontal `ListView.builder` inside the AppBar's `title`:

```dart
AppBar(
  title: SizedBox(
    height: 36,
    child: Row(
      children: [
        Expanded(
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: sessions.length + 1,  // +1 for "+" button
            itemBuilder: (context, i) {
              if (i == sessions.length) return _buildAddTab();
              return _buildTab(i);
            },
          ),
        ),
      ],
    ),
  ),
)
```

Each tab shows:
- Session title (truncated with ellipsis, max 160px)
- Streaming indicator (when a message is being sent)
- Close button (×) — last session clears instead of deleting
- Active tab highlighted with bottom border in primary color

Long-press triggers rename dialog. The "+" button at the end creates a new session.

**Edge case: deleting the last session.** When there's only one session, the × button shows a "Clear Chat" confirmation instead of deleting. After clearing, the session title resets to "Chat 1":

```dart
void deleteSession(int index) {
  if (_sessions.length <= 1) {
    _sessions[0].messages.clear();
    _sessions[0].title = 'Chat 1';
    _activeIndex = 0;
    _save();
    notifyListeners();
    return;
  }
  _sessions.removeAt(index);
  if (_activeIndex >= _sessions.length) {
    _activeIndex = _sessions.length - 1;
  }
}
```

### SSE Streaming with Multi-Session

When streaming SSE responses, the ChatManager's `addMessage` and `updateLastMessage` methods let the stream handler work with any session:

```dart
// Add placeholder at start
mgr.addMessage(session.id, ChatMessage(text: '…', isUser: false));

// Update placeholder on each SSE chunk
mgr.updateLastMessage(sessionId, ChatMessage(
  text: buffer.toString().trim(),
  isUser: false,
));

// Finalize on [DONE]
mgr.updateLastMessage(sessionId, ChatMessage(
  text: buffer.toString().trim(),
  isUser: false,
));
```

The placeholder message is the last message in the session's list. `updateLastMessage` replaces it in-place by index (`_sessions[idx].messages.last`). This avoids adding duplicate entries or needing to track placeholder references.

### Provider Wiring

```dart
// In main():
runApp(
  MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ChatManager()),
      // Other providers...
    ],
    child: const App(),
  ),
);
```

The ChatManager is also passed `context.watch<ChatManager>()` in the widget, meaning any screen can observe session state changes and rebuild automatically.

## When to Use This Pattern

Use when your Flutter app has:
- Multiple conversations/users/sessions that users switch between
- Navigation that destroys widgets (sidebar tabs, bottom nav, stacked pages)
- Need for state to survive app restarts (persistence)
- Real-time streaming (SSE or WebSocket) that must update the correct session

Don't use when: single-session chat, state doesn't need to survive navigation, or you're using a state management solution that already handles persistence (Riverpod, Bloc with storage).

## Session Resume Pattern

When the chat app wraps a CLI tool that manages its own sessions (Hermes, etc.), add a **session resume** feature that lets users pick from recent CLI sessions and continue the conversation.

### Architecture

1. **Backend accepts `session_id`** in the stream endpoint:
   ```rust
   struct ChatStreamQuery {
       message: String,
       session_id: Option<String>,
   }
   ```
   When `session_id` is provided, pass `--resume <session_id>` to the CLI command:
   ```rust
   let mut args = if let Some(sid) = &session_id {
       vec!["--resume", sid, "-z", &message]
   } else {
       vec!["-z", &message]
   };
   ```

2. **ChatManager holds resume context** — the resumed session ID is separate from the Wingman's internal chat sessions:
   ```dart
   class ChatManager extends ChangeNotifier {
     String? _resumeSessionId;
     String? _resumeSessionTitle;

     String? get resumeSessionId => _resumeSessionId;
     String? get resumeSessionTitle => _resumeSessionTitle;

     void setResumeSession(String? id, {String? title}) {
       _resumeSessionId = id;
       _resumeSessionTitle = title;
       notifyListeners();
     }

     void clearResumeSession() {
       _resumeSessionId = null;
       _resumeSessionTitle = null;
       notifyListeners();
     }
   }
   ```

3. **Chat screen forwards session_id** to the SSE stream:
   ```dart
   Future<void> _streamChat(String message, String sessionId, {String? resumeSessionId}) async {
     final queryParams = <String, String>{'message': message};
     if (resumeSessionId != null && resumeSessionId.isNotEmpty) {
       queryParams['session_id'] = resumeSessionId;
     }
     final uri = Uri.parse('http://127.0.0.1:9120/chat/stream')
         .replace(queryParameters: queryParams);
     // ... rest of SSE handling
   }
   ```

4. **Session picker UI** — a bottom sheet that lists recent sessions from the CLI:
   ```dart
   void _showSessionPicker() {
     _loadRecentSessions();  // fetches from backend GET /sessions
     showModalBottomSheet(
       context: context,
       builder: (ctx) => DraggableScrollableSheet(
         initialChildSize: 0.6,
         builder: (ctx, scrollController) {
           // List of sessions with title, truncated ID, message count
           // Selected session shows checkmark and applies via ChatManager.setResumeSession()
         },
       ),
     );
   }
   ```

5. **Session badge in AppBar** — when a session is resumed, show a small badge in the AppBar actions that's clickable to open the picker again:
   ```dart
   if (_resumedSessionId != null)
     GestureDetector(
       onTap: _showSessionPicker,
       child: Container(
         padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
         decoration: BoxDecoration(
           color: scheme.secondary.withOpacity(0.12),
           borderRadius: BorderRadius.circular(4),
         ),
         child: Row(
           children: [
             Icon(Icons.replay, size: 10, color: scheme.secondary),
             Text(_resumedSessionTitle ?? 'Session', style: ...),
           ],
         ),
       ),
     ),
   IconButton(
     icon: Icon(Icons.history, size: 15),
     onPressed: _showSessionPicker,
     tooltip: 'Resume Session',
   ),
   ```

### Key Insights

- **Global state for resume**: The resume session context is in ChatManager (not local widget state) so it survives navigation. The Sessions screen's "Resume" button also uses ChatManager.setResumeSession() to set the context, then navigates to the Chat tab.
- **Backend handles the CLI mapping**: The backend translates `session_id` to `--resume <id>` CLI flags. The Flutter app just passes the string.
- **Visual indicator always visible**: The resume badge shows even when typing, so users always know they're continuing a CLI session. The history icon changes color when a session is active."
