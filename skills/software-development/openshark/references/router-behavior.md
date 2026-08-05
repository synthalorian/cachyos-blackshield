Source: `src/router/mod.rs` in the openshark repo.

## Resolution order

1. If the requested model name exists in `providers.*.models[].name` literally, return its provider.
2. If `default_model` is set and valid, use that provider.
3. Otherwise fall back to the `FALLBACK_PROVIDER`.

There is no alias expansion. No regex trimming. No suffix normalization.

## Capability routing

When `auto_route = true`, the harness classifies the task by keywords:
- `code` for refactor/rewrite/debug/fix/error/test
- `analysis` for architect/design/structure/explain/analyze
- `chat` otherwise

Then it picks a model with the matching capability. Cost is a secondary tie-breaker.

## Implication for local aliases

`synthclaw-fast:think` must exist as its own `name = "synthclaw-fast:think"` entry with `capabilities = ["code", "chat"]`, or route fallback happens. The same applies to every llama-swap alias you want to invoke by id.
