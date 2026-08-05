# Discord Native Message Responses — OpenShark Gateway

Session: 2026-05-30, implementing native keyword detection and automatic memory recall for inbound Discord messages.

## Overview

In addition to slash commands, OpenShark responds natively to regular Discord messages. Two mechanisms:
1. **Keyword commands** — prefixed with `!` (e.g., `!model`, `!help`)
2. **Natural language memory queries** — detected by phrase patterns, bypass LLM entirely
3. **Automatic memory recall** — every message queries the memory store and injects relevant context

## Keyword Commands

Parsed in `handle_user_message()` before any LLM call:

| Keyword | Action |
|---------|--------|
| `!model` | List available models |
| `!model <name>` | Switch to named model |
| `!tools` | List available tools |
| `!status` | Show bot status |
| `!help` | Command reference |
| `!new` | Start fresh conversation |
| `!reset` | Reset to defaults |

```rust
async fn handle_user_message(&mut self, msg: UserMessage) {
    let content_lower = msg.content.to_lowercase();

    // Keyword command detection (bypass LLM)
    if content_lower.starts_with("!model ") {
        let model_name = &msg.content[7..].trim();
        // switch model, reply immediately
        return;
    }
    if content_lower == "!tools" {
        // list tools, reply immediately
        return;
    }
    // ... etc for all keywords
}
```

**Why bypass LLM:** These are meta-commands about the bot itself. Sending them to the model wastes tokens and adds latency. Handle directly.

## Natural Language Memory Queries

Detected by phrase prefixes. These bypass the LLM and query the memory store directly:

| Prefix Pattern | Example |
|----------------|---------|
| `what did we do about` | "what did we do about the auth bug?" |
| `how did we solve` | "how did we solve the docker networking issue?" |
| `tell me about` | "tell me about the MCP implementation" |
| `what was the issue with` | "what was the issue with the borrow checker?" |
| `remember when` | "remember when we fixed the cache?" |
| `do you recall` | "do you recall the model we used?" |

```rust
let memory_prefixes = [
    "what did we do about ",
    "how did we solve ",
    "tell me about ",
    "what was the issue with ",
    "remember when ",
    "do you recall ",
];

for prefix in &memory_prefixes {
    if content_lower.starts_with(prefix) {
        let query = &msg.content[prefix.len()..];
        let answer = self.memory.answer_natural_query(query);
        // reply with answer, no LLM call
        return;
    }
}
```

**Implementation:** Uses `ContextInjector::answer_natural_query()` which combines semantic search + keyword search, formats results into a natural response.

## Automatic Memory Recall

Every inbound message (that isn't a keyword command) triggers memory search:

```rust
// 1. Semantic search (top 3, score > 0.3)
let semantic = self.memory.search_similar(query, 3);

// 2. Keyword fallback (top 5)
let keyword = self.memory.search_keyword(query, 5);

// 3. Deduplicate by content
let mut seen = HashSet::new();
let mut context = String::new();
for result in semantic.iter().chain(keyword.iter()) {
    if seen.insert(&result.content) {
        context.push_str(&format!("- {}\n", result.content));
    }
}

// 4. Inject as system message if any results found
if !context.is_empty() {
    let memory_msg = format!(
        "[RELEVANT CONTEXT FROM MEMORY]\n{}",
        context
    );
    channel_state.history.push(Message::system(memory_msg));
}
```

**Why inject as system message:** The model sees it as context, not conversation history. It doesn't get saved back to the conversation history (only user + assistant messages persist).

## ContextInjector Trait

```rust
pub trait ContextInjector {
    fn inject_context(&self, session_id: &str, messages: &mut Vec<Message>);
    fn answer_natural_query(&self, query: &str) -> Option<String>;
}
```

- `inject_context()` — called before every LLM request, adds memory context as system message
- `answer_natural_query()` — called for natural language queries, returns formatted answer directly

## Message Flow

```
Inbound Discord Message
    │
    ├─ Is it a keyword command? → Handle directly, reply immediately
    │
    ├─ Is it a natural language memory query? → Search memory, reply directly
    │
    └─ Regular message
        ├─ Search memory (semantic + keyword)
        ├─ Inject relevant context as system message
        ├─ Check for triggered skills → inject skill content
        ├─ Send to LLM with full context
        └─ Stream response back to Discord
```

## Files

- `src/gateway/message_router.rs` — `handle_user_message()`, keyword detection, memory recall
- `src/memory/context.rs` — `ContextInjector` trait, `answer_natural_query()`
- `src/memory/store.rs` — `search_similar()`, `search_keyword()`
