# Optional Multi-Model Comparison Pattern

OpenShark supports querying multiple models simultaneously and comparing their responses. This is **opt-in** and **off by default** to keep latency and cost low.

## Design Philosophy

- **Off by default:** Single-model responses are faster and cheaper
- **Opt-in per-channel:** Users enable it when they want model comparisons
- **Runtime toggle:** Can be enabled/disabled without restarting
- **Secondary models configurable:** Users choose which models to compare

## Config

```toml
[gateway.discord]
multi_model_enabled = false              # default: off
multi_model_secondary = []               # e.g., ["gpt-4o", "claude-sonnet-4"]
```

## Commands

### Slash Command
```
/multi                          # Show status
/multi action:on                # Enable
/multi action:off               # Disable
/multi action:toggle            # Toggle
/multi action:set models:gpt-4o,claude-sonnet-4   # Set secondary models
```

### Keyword Command
```
!multi                          # Toggle
!multi on                       # Enable
!multi off                      # Disable
!multi gpt-4o, claude-sonnet-4  # Set secondary models
```

## Response Format

When enabled, the response shows primary model first, then each secondary:

```
🤖 **Primary** (kimi-k2.6)
<primary response>

---

🤖 **gpt-4o**
<gpt-4o response>

🤖 **claude-sonnet-4**
<claude response>
```

## Implementation

In `message_router.rs::handle_user_message()`:

```rust
if state.multi_model_enabled && !state.multi_model_secondary.is_empty() {
    self.handle_multi_model_response(channel_id, &state, &messages, &reply_tx).await;
} else {
    // Standard single-model response
    let tool_result = match provider.chat_stream(req).await { ... }
}
```

`handle_multi_model_response()`:
1. Queries primary model (the channel's current model)
2. For each secondary model, creates a new Provider and queries in parallel
3. Formats all responses with model headers
4. Sends via `reply_tx`

## Use Cases

- **Model evaluation:** Compare outputs from different providers
- **Consensus building:** See if multiple models agree on a solution
- **Capability testing:** Test which model handles a specific task best
- **Cost optimization:** Compare quality vs. cost across providers

## Performance Considerations

- Latency = max(primary_latency, secondary_latencies)
- Cost = sum(primary_cost, secondary_costs)
- Token usage = sum(primary_tokens, secondary_tokens)
- For N secondary models, expect ~N+1x the cost and latency

## Future Enhancements

- Vote/merge mode: Let models vote on the best answer
- Confidence scoring: Show which model is most confident
- Auto-select secondary models based on task type
- Streaming comparison: Show responses as they arrive
