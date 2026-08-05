# Model Shorthand Resolution — Synthclaw Wrapper Patterns

## The Resolution Bug (Fixed)

The `synthclaw-resolve.sh` script in `synthclaw-ai-setup/configs/wrappers/` was missing model shorthand cases for the 9B and 27B IQ models. When a shorthand like `9b` or `35b` was passed, the `*` fallback echoed it back unchanged (`"9b"`), causing the CLI to request `openai/9b` — a non-existent model name — resulting in a 404 error from llama-swap.

**Root cause:** Incomplete `case` statement in `resolve_model()`.

## Current Model Namespace Split

Two separate wrapper commands map to two disjoint model namespaces:

### `claw` wrapper → claw-family / synthclaw-family models

| Shorthand | Resolved Model ID | Context |
|-----------|-------------------|---------|| `35b`     | `synthclaw-35b-128k` | 128K (MoE) |
| `35bmax`  | `synthclaw-35b-256k` | 256K |
| `35bultra`| `synthclaw-35b-512k` | 512K |
| `14b`     | `synthclaw-14b-128k` | 128K (dense) |
| `14bmax`  | `synthclaw-14b-256k` | 256K |
| `14bultra`| `synthclaw-14b-512k` | 512K |
| `9b`      | `synthclaw-9b-128k`  | 128K (dense) |
| `9bmax`   | `synthclaw-9b-256k`  | 256K |
| `9bultra` | `synthclaw-9b-512k`  | 512K |
| `35bkimi` | `synthclaw-35bkimi-128k` | 128K (Kimi-2.6 distilled) |
| `35bkimimax` | `synthclaw-35bkimi-256k` | 256K (Kimi-2.6 distilled) |
| `35bkimiultra` | `synthclaw-35bkimi-512k` | 512K (Kimi-2.6 distilled) |

### `hermes` wrapper → hermes-family models

| Shorthand | Resolved Model ID | Context |
|-----------|-------------------|---------|
| `9b`      | `hermes-9b`       | 128K |
| `9bmax`   | `hermes-9b-max`   | 256K |
| `9bultra` | `hermes-9b-ultra` | 512K |
| `35b`   | `hermes-35b`    | 128K |
| `35bmax`| `hermes-35b-max`| 256K |
| `35bultra`| `hermes-35b-ultra`| 512K |

**Implementation notes:**
- `hermes` wrapper auto-injects the `prompt` subcommand for non-interactive use; `claw` passes args raw (bare words become slash commands inside REPL).
- Both wrappers set `OPENAI_API_KEY=llama-swap-local` and `OPENAI_BASE_URL=http://127.0.0.1:8080/v1` when targeting local models.
- Model argument format: `--model openai/<resolved-id>`.

### `claw` wrapper — cloud routing (default since 2026-05)

The `claw` wrapper now defaults to **Z.AI GLM-5.1 cloud** instead of local llama-swap:

| Invocation | Route | Env Vars |
|------------|-------|----------|
| `claw` (no args) | Z.AI GLM-5.1 cloud | `OPENAI_API_KEY=<zai-key>`, `OPENAI_BASE_URL=https://api.z.ai/api/coding/paas/v4` |
| `claw glm` | Z.AI GLM-5.1 cloud (explicit) | Same as above |
| `claw local` | Local llama-swap default | `OPENAI_API_KEY=llama-swap-local`, `OPENAI_BASE_URL=http://127.0.0.1:8080/v1` |
| `claw 35b` etc | Local llama-swap (specific model) | Same as local |

**Critical:** Z.AI has two API tiers with different base URLs:
- Standard API: `https://api.z.ai/api/paas/v4` — requires account balance, returns 429 on coding plan keys
- **Coding plan**: `https://api.z.ai/api/coding/paas/v4` — works with coding subscription, same key

If `claw` returns 429 "Insufficient balance" despite having a coding plan, the base URL is wrong.

## Wrapper File Locations

```
~/.local/bin/claw        → symlink → ~/synthclaw-ai-setup/configs/wrappers/claw
~/.local/bin/hermes      → direct file (primary)
~/synthclaw-ai-setup/configs/wrappers/
├── claw                 # main wrapper for claw/synthclaw models
├── hermes               # hermes-family wrapper
└── synthclaw-resolve.sh # shared resolve_model function (updated)
```

The `synthclaw-resolve.sh` script is sourced by both wrappers. Keep the `case` statement synchronized across any new model families.

## Debugging Shorthand Mismatches

If `claw <shorthand>` or `hermes <shorthand>` reports 404:

1. **Check what model ID it's actually sending:**
   ```bash
   claw <short> --output-format json "test" 2>&1 | head -3
   # Look at the "Model:" banner line and the final "model" field in JSON
   ```

2. **Verify the model exists in llama-swap catalog:**
   ```bash
   curl -s http://127.0.0.1:8080/v1/models | jq '.data[].id'
   ```

3. **Confirm resolve_model returns correct ID:**
   ```bash
   source ~/synthclaw-ai-setup/configs/wrappers/synthclaw-resolve.sh
   resolve_model 9b      # prints "claw-9b"
   resolve_model 35b  # prints "synthclaw-35b-128k"
   ```

4. **Fix missing cases** by editing `synthclaw-resolve.sh` and adding the missing shorthand to the `case` statement, then re-source or restart shell.

## Updating Wrappers for New Model Families

When adding a new family:

1. **Same namespace?** If models share the `claw-*` or `synthclaw-*` prefix patterns, extend `synthclaw-resolve.sh` with new `case` arms. No new wrapper binary needed.
2. **Separate namespace?** Create a new wrapper (e.g., `~/.local/bin/gemma`) with its own `case` mapping, or extend `hermes` pattern if same identity.
3. **Update this reference** with the mapping table.
4. **Update wrapper help text** to document the new shorthands.

## Pitfalls

- **Wrong Z.AI base URL** — coding plan key hits standard API → 429 "Insufficient balance". Fix: use `https://api.z.ai/api/coding/paas/v4` not `https://api.z.ai/api/paas/v4`.
- **Missing case entry** → shorthand falls through to default model or literal pass-through, causing 404. Always verify `resolve_model <short>` returns the exact model ID from `curl http://127.0.0.1:8080/v1/models`.
- **Wrapper symlink broken** → `SCRIPT_DIR` points to `~/.local/bin` instead of real wrapper directory, causing `source` of `synthclaw-resolve.sh` to fail. Use the symlink-resolve loop (already in both wrappers).
- **API key corrupted to `***`** → wrapper edits that redact secrets break claw. Use sentinel `llama-swap-local` for local llama-swap.
- **`hermes` missing `prompt` subcommand** → bare args treated as REPL slash commands. Wrapper automatically adds `prompt` when extra args are present.
