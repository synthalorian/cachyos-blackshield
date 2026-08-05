# Swarm Persona Filter Pattern

## Problem

LLM agents in swarm mode emit self-convincing preamble like "I am the Architect. I will design the system..." before getting to actual work. This clutters the TUI output and wastes tokens on the provider.

## Solution

A dedicated `persona_filter.rs` module that strips persona-reasoning lines from agent responses.

## Implementation

### 1. Create the filter module (`src/swarm/persona_filter.rs`)

```rust
/// Strip persona-reasoning preamble from agent responses.
pub fn strip_persona_preamble(content: &str) -> String {
    let patterns = [
        "i am the architect", "i am the implementer", "i am the reviewer",
        "i am the tester", "i am the devops", "i am the security",
        "as the architect", "as the implementer", /* ... 500+ patterns ... */
        "my role is to", "my responsibility is to",
        "i will now", "i will start by", "i will begin by",
        "i will analyze", "i will design", "i will implement",
        /* ... extensive verb list ... */
    ];
    
    let lines: Vec<&str> = content.lines().collect();
    let mut first_real = 0usize;
    let mut last_real = lines.len();
    
    // Strip from start
    for (i, line) in lines.iter().enumerate() {
        let trimmed = line.trim().to_lowercase();
        if !trimmed.is_empty() && !patterns.iter().any(|p| trimmed.starts_with(*p)) {
            first_real = i;
            break;
        }
    }
    
    // Strip from end
    for i in (first_real..lines.len()).rev() {
        let trimmed = lines[i].trim().to_lowercase();
        if !trimmed.is_empty() && !patterns.iter().any(|p| trimmed.starts_with(*p)) {
            last_real = i + 1;
            break;
        }
    }
    
    lines[first_real..last_real].join("\n").trim().to_string()
}
```

### 2. Wire into AgentRunner

Apply filtering at **two points**:

**Per-chunk (streaming):**
```rust
for (i, chunk) in chunks.iter().enumerate() {
    full_content.push_str(chunk);
    let filtered = crate::swarm::persona_filter::strip_persona_preamble(chunk);
    if !filtered.is_empty() {
        let _ = self.event_tx.send(SwarmEvent::AgentChunk {
            agent_id: self.agent_id.clone(),
            agent_name: agent_name.clone(),
            role: agent_role.clone(),
            chunk: filtered,
            is_final: i == chunks.len() - 1,
        });
    }
}
```

**Final result:**
```rust
crate::swarm::persona_filter::strip_persona_preamble(&full_content)
```

### 3. Register module

Add `pub mod persona_filter;` to `src/swarm/mod.rs`.

## Pattern Coverage

The filter covers three categories:
1. **Role identity**: "I am the X", "As the Y"
2. **Role description**: "My role is to...", "My responsibility is to..."
3. **Intent declarations**: "I will Z..." (500+ verb patterns)

## Edge Cases

- Empty result after filtering → return original (don't lose content)
- Mixed persona + real content → strips only leading/trailing persona lines
- Code blocks containing "I will" → safe because we check line starts only

## Testing

Unit tests cover:
- Preamble stripping
- No-op when no persona present
- Trailing persona removal
- Empty input handling
