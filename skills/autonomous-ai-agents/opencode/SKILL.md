---
name: opencode
description: "Delegate coding to OpenCode CLI (features, PR review)."
version: 1.3.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [Coding-Agent, OpenCode, Autonomous, Refactoring, Code-Review]
    related_skills: [claude-code, codex, hermes-agent]
---

# OpenCode CLI

Use [OpenCode](https://opencode.ai) as an autonomous coding worker orchestrated by Hermes terminal/process tools. OpenCode is a provider-agnostic, open-source AI coding agent with a TUI and CLI.

## When to Use

- User explicitly asks to use OpenCode
- You want an external coding agent to implement/refactor/review code
- You need long-running coding sessions with progress checks
- You want parallel task execution in isolated workdirs/worktrees

## Prerequisites

- OpenCode installed: `npm i -g opencode-ai@latest` or `brew install anomalyco/tap/opencode`
- Auth configured: `opencode auth login` or set provider env vars (OPENROUTER_API_KEY, etc.)
- Verify: `opencode auth list` should show at least one provider
- Git repository for code tasks (recommended)
- `pty=true` for interactive TUI sessions

## Binary Resolution (Important)

Shell environments may resolve different OpenCode binaries. If behavior differs between your terminal and Hermes, check:

```
terminal(command="which -a opencode")
terminal(command="opencode --version")
```

If needed, pin an explicit binary path:

```
terminal(command="$HOME/.opencode/bin/opencode run '...'", workdir="~/project", pty=true)
```

## One-Shot Tasks

Use `opencode run` for bounded, non-interactive tasks:

```
terminal(command="opencode run 'Add retry logic to API calls and update tests'", workdir="~/project")
```

Attach context files with `-f`:

```
terminal(command="opencode run 'Review this config for security issues' -f config.yaml -f .env.example", workdir="~/project")
```

Show model thinking with `--thinking`:

```
terminal(command="opencode run 'Debug why tests fail in CI' --thinking", workdir="~/project")
```

Force a specific model:

```
terminal(command="opencode run 'Refactor auth module' --model openrouter/anthropic/claude-sonnet-4", workdir="~/project")
```

## Interactive Sessions (Background)

For iterative work requiring multiple exchanges, start the TUI in background:

```
terminal(command="opencode", workdir="~/project", background=true, pty=true)
# Returns session_id

# Send a prompt
process(action="submit", session_id="<id>", data="Implement OAuth refresh flow and add tests")

# Monitor progress
process(action="poll", session_id="<id>")
process(action="log", session_id="<id>")

# Send follow-up input
process(action="submit", session_id="<id>", data="Now add error handling for token expiry")

# Exit cleanly — Ctrl+C
process(action="write", session_id="<id>", data="\x03")
# Or just kill the process
process(action="kill", session_id="<id>")
```

**Important:** Do NOT use `/exit` — it is not a valid OpenCode command and will open an agent selector dialog instead. Use Ctrl+C (`\x03`) or `process(action="kill")` to exit.

### TUI Keybindings

| Key | Action |
|-----|--------|
| `Enter` | Submit message (press twice if needed) |
| `Tab` | Switch between agents (build/plan) |
| `Ctrl+P` | Open command palette |
| `Ctrl+X L` | Switch session |
| `Ctrl+X M` | Switch model |
| `Ctrl+X N` | New session |
| `Ctrl+X E` | Open editor |
| `Ctrl+C` | Exit OpenCode |

### Resuming Sessions

After exiting, OpenCode prints a session ID. Resume with:

```
terminal(command="opencode -c", workdir="~/project", background=true, pty=true)  # Continue last session
terminal(command="opencode -s ses_abc123", workdir="~/project", background=true, pty=true)  # Specific session
```

## Common Flags

| Flag | Use |
|------|-----|
| `run 'prompt'` | One-shot execution and exit |
| `--continue` / `-c` | Continue the last OpenCode session |
| `--session <id>` / `-s` | Continue a specific session |
| `--agent <name>` | Choose OpenCode agent (build or plan) |
| `--model provider/model` | Force specific model |
| `--format json` | Machine-readable output/events |
| `--file <path>` / `-f` | Attach file(s) to the message |
| `--thinking` | Show model thinking blocks |
| `--variant <level>` | Reasoning effort (high, max, minimal) |
| `--title <name>` | Name the session |
| `--attach <url>` | Connect to a running opencode server |

## Procedure

1. Verify tool readiness:
   - `terminal(command="opencode --version")`
   - `terminal(command="opencode auth list")`
2. For bounded tasks, use `opencode run '...'` (no pty needed).
3. For iterative tasks, start `opencode` with `background=true, pty=true`.
4. Monitor long tasks with `process(action="poll"|"log")`.
5. If OpenCode asks for input, respond via `process(action="submit", ...)`.
6. Exit with `process(action="write", data="\x03")` or `process(action="kill")`.
7. Summarize file changes, test results, and next steps back to user.

## PR Review Workflow

OpenCode has a built-in PR command:

```
terminal(command="opencode pr 42", workdir="~/project", pty=true)
```

Or review in a temporary clone for isolation:

```
terminal(command="REVIEW=$(mktemp -d) && git clone https://github.com/user/repo.git $REVIEW && cd $REVIEW && opencode run 'Review this PR vs main. Report bugs, security risks, test gaps, and style issues.' -f $(git diff origin/main --name-only | head -20 | tr '\n' ' ')", pty=true)
```

## Parallel Work Pattern

Use separate workdirs/worktrees to avoid collisions:

```
terminal(command="opencode run 'Fix issue #101 and commit'", workdir="/tmp/issue-101", background=true, pty=true)
terminal(command="opencode run 'Add parser regression tests and commit'", workdir="/tmp/issue-102", background=true, pty=true)
process(action="list")
```

## Session & Cost Management

List past sessions:

```
terminal(command="opencode session list")
```

Check token usage and costs:

```
terminal(command="opencode stats")
terminal(command="opencode stats --days 7 --models anthropic/claude-sonnet-4")
```

## Plugin Auto-Discovery

OpenCode auto-discovers plugins from `~/.config/opencode/plugins/`. Any `.ts` file placed there is loaded automatically — you do NOT need to list it in `opencode.json`'s `plugin` array.

```bash
# Plugins go here, auto-discovered on launch:
~/.config/opencode/plugins/
├── peon-ping.ts         # Example: routes events through peon.sh for Starcraft sound packs
└── your-plugin.ts       # Any .ts file is loaded automatically
```

Confirmed via OpenCode startup logs:
```
INFO service=plugin path=file:///home/synth/.config/opencode/plugins/peon-ping.ts loading plugin
```

**Pitfall: .gitignore `plugins/` pattern.** The common `.gitignore` pattern `plugins/` matches ALL directories named `plugins` at any depth. If you're storing checked-in plugin source files under `configs/opencode/plugins/` in a backup repo, you need a negate rule:
```gitignore
plugins/
!configs/opencode/plugins/
```

## Oh-My-Openagent (OmO) Plugin

OpenCode is configured with the [oh-my-openagent](https://github.com/code-yeongyu/oh-my-openagent) multi-agent orchestration plugin.

### Key Files

```
~/.config/opencode/opencode.json            — Main config (model default, plugin list, MCP)
~/.config/opencode/oh-my-openagent.json     — OmO agent definitions, model assignments, system prompts
~/.config/opencode/.omo/rules/              — Rules injected into all agent contexts
```

### Installed Provider: zai-coding-plan (legacy, GLM agents only)

OmO registers a `zai-coding-plan` provider using the Z.AI coding plan endpoint (`https://api.z.ai/api/coding/paas/v4`). Available models: glm-4.5-air, glm-4.7, glm-5-turbo, glm-5.1, glm-5v-turbo. Now only used for `multimodal-looker` (glm-5v-turbo).

### Installed Provider: kimi (primary)

Custom provider in `opencode.json` using `@ai-sdk/openai-compatible` pointed at Kimi proxy (`http://127.0.0.1:8699/v1`). Model: `kimi-k2.6`. The proxy injects `User-Agent: claude-code/1.0` required by Kimi Coding Plan's agent gate. API key stored inline (chmod 600 config). This is the primary model for all heavy OmO agents.

For full Kimi provider config across all harnesses, see the claw-code skill: `references/kimi-coding-plan.md`.

Free opencode models (no auth): big-pickle, deepseek-v4-flash-free, minimax-m2.5-free, nemotron-3-super-free, qwen3.6-plus-free. Used for utility agents to conserve Kimi quota.

Connected providers: openai, zai-coding-plan, opencode (confirmed via `~/.cache/oh-my-opencode/connected-providers.json`).

### Telemetry

OmO telemetry is disabled via `OMO_SEND_ANONYMOUS_TELEMETRY=0` in `~/.bashrc`.

### OmO Agent Roster (v4.2.3)

11 agents with configurable model routing. Heavy agents on Kimi K2.6, multimodal on GLM-5V-Turbo, light agents on free models:

| Agent | Role | Your Model |
|-------|------|------------|
| sisyphus | Primary coding | kimi/kimi-k2.6 |
| oracle | Code review/analysis | kimi/kimi-k2.6 |
| prometheus | Documentation (MD-only, hook-enforced) | kimi/kimi-k2.6 |
| atlas | Architecture planning | kimi/kimi-k2.6 |
| metis | Task planning | kimi/kimi-k2.6 |
| momus | Critic/reviewer | kimi/kimi-k2.6 |
| hephaestus | Build/deploy | kimi/kimi-k2.6 |
| multimodal-looker | Vision/image | zai-coding-plan/glm-5v-turbo |
| librarian | Search/indexing | opencode/deepseek-v4-flash-free |
| explore | Codebase exploration | opencode/deepseek-v4-flash-free |
| sisyphus-junior | Lightweight subagent | opencode/deepseek-v4-flash-free |

Agent canonical order enforced by `installAgentSortShim()`: Sisyphus → Hephaestus → Prometheus → Atlas.

### Multi-Agent Commands

Inside the OpenCode TUI, `ultrawork` (or `ulw`) triggers parallel multi-agent execution. The OmO config assigns heavier reasoning agents (sisyphus, oracle, prometheus) to `glm-5.1` and lighter agents to free models.

### Updating OmO

OmO is an npm package referenced as `oh-my-openagent@latest` in `opencode.json`. To upgrade:

```bash
cd ~/.config/opencode && npm install oh-my-openagent@latest
# Verify
jq -r '.version' node_modules/oh-my-openagent/package.json
```

No binary release assets on GitHub — it's purely npm. The `@latest` tag in `opencode.json` means `npm install` always pulls the newest. OpenCode picks up the new version on next launch (no restart of a running session needed, just start a new one).

OmO releases are tagged at https://github.com/code-yeongyu/oh-my-openagent/releases — no downloadable assets, but release notes are there.

### Health Check

```
npx oh-my-openagent doctor    # Verify OmO installation and compatibility
```

## Custom / Local Providers

OpenCode supports any OpenAI-compatible provider via the `@ai-sdk/openai-compatible` package. This is how you connect local models (llama.cpp server, Ollama, LM Studio, etc.).

### Adding a Provider

Add a `provider` key to `~/.config/opencode/opencode.json`:

```json
{
  "$schema": "https://opencode.ai/config.json",
  "provider": {
    "local": {
      "npm": "@ai-sdk/openai-compatible",
      "name": "Local llama.cpp",
      "options": {
        "baseURL": "http://127.0.0.1:8080/v1"
      },
      "models": {
        "synthclaw-35bkimi-128k": {
          "name": "Kimi K2.6 35B (128k ctx)",
          "limit": { "context": 128000, "output": 65536 }
        },
        "synthclaw-14b-128k": {
          "name": "Qwen3 14B (128k)",
          "limit": { "context": 128000, "output": 65536 }
        },
        "synthclaw-9b-128k": {
          "name": "Qwen3.5 9B (128k)",
          "limit": { "context": 128000, "output": 65536 }
        }
      }
    }
  }
}
```

Key details:

- **`baseURL`** must end with `/v1` (the OpenAI-compatible endpoint suffix)
- **Provider name** (`"local"` above) becomes the prefix for model identifiers: `local/synthclaw-35bkimi-128k`
- **No `apiKey` needed** for local servers — omit the field entirely. If the SDK complains, add `"apiKey": "not-needed"`
- **`limit.context`** should match the model's max context window. Llama.cpp serves context-limited endpoints, so set this accurately
- **`limit.output`** caps max output tokens. 65536 is safe for most local models

### Using with llama-swap

> See `references/llama-swap-model-roster.md` for a full model roster and per-environment config if you're on synth's system.

Point `baseURL` to the llama-swap proxy (port 8080 by default) to access multiple models through one provider. Llama-swap auto-launches cold models on demand. List available models:

```bash
curl -s http://127.0.0.1:8080/v1/models | jq '.data[].id'
```

Each model ID from the response becomes a key under `models` in the provider config.

### Routing OmO Agents to Local Models

In `oh-my-openagent.json`, replace cloud model references with local ones using the `provider/model` format:

```json
{
  "agents": {
    "sisyphus": {
      "model": "local/synthclaw-35bkimi-128k",
      "system": "..."
    },
    "oracle": {
      "model": "local/synthclaw-35bkimi-128k"
    }
  }
}
```

Keep free models (`opencode/deepseek-v4-flash-free`, `opencode/minimax-m2.5-free`) for lightweight utility agents to conserve local GPU VRAM.

### Verification

After adding a provider, verify models are discoverable:

```bash
opencode models local   # List local provider's models
```

Then smoke test:

```bash
opencode run 'Respond with exactly: LOCAL_MODEL_OK' --model local/synthclaw-35bkimi-128k
```

### Pitfalls

- **apiKey field:** Some OpenAI-compatible SDKs require a non-empty `apiKey` even for local endpoints. If you get auth errors, add `"apiKey": "not-needed"` to `options`.
- **Provider not in `/connect`:** Custom providers don't show up in the TUI's `/connect` flow. They must be manually configured in `opencode.json`.
- **Model name must match server:** The model key under `models` must exactly match what the server returns in `model` field of completion responses. Mismatch causes 404 or fallback errors.
- **VRAM exhaustion with OmO:** OpenCode + OmO may fire multiple agents concurrently. For single-model local setups, ensure llama-server runs with `--parallel 1` and avoid `--cont-batching` on VRAM-constrained GPUs.

## Pitfalls

- Interactive `opencode` (TUI) sessions require `pty=true`. The `opencode run` command does NOT need pty.
- `/exit` is NOT a valid command — it opens an agent selector. Use Ctrl+C to exit the TUI.
- PATH mismatch can select the wrong OpenCode binary/model config.
- If OpenCode appears stuck, inspect logs before killing:
  - `process(action="log", session_id="<id>")`
- Avoid sharing one working directory across parallel OpenCode sessions.
- Enter may need to be pressed twice to submit in the TUI (once to finalize text, once to send).
- **Z.AI coding plan vs standard API.** Same key, different endpoints. Coding plan uses `/api/coding/paas/v4`; standard uses `/api/paas/v4`. Wrong endpoint returns 429 "Insufficient balance". Check `~/.hermes/auth.json` provider config for the correct URL.
- **OmO cache path is legacy-named.** Despite the rename to "oh-my-openagent", the cache directory is `~/.cache/oh-my-opencode/` (not `~/.cache/oh-my-openagent/`). The `ls` output shows the old name but the files are current. Provider models cache at `~/.cache/oh-my-opencode/provider-models.json`, model capabilities at `~/.cache/oh-my-opencode/model-capabilities.json`. Structure is `{ "models": { "<provider>": [...] }, "connected": [...], "updatedAt": "..." }`.
- **OmO is in active refactor.** The AGENTS.md literally warns "THIS ENTIRE GODDAMN CODEBASE IS BEING RIPPED APART AND REBUILT." Config format may change between versions. Keep `oh-my-openagent.json` backed up before upgrading.
- **Reasoning models need long timeouts for `opencode run`.** A local 35B with reasoning on (DeepSeek format, 4096 budget) can take 60-180s per response. Default 120s timeout WILL time out. Set `timeout=300` in the terminal() call for `opencode run` with reasoning models. For interactive TUI sessions, the model response time feels the same but doesn't hit a tool timeout.

## Verification

Basic smoke test (fast model):

```
terminal(command="opencode run 'Respond with exactly: OPENCODE_SMOKE_OK'")
```

Smoke test for local reasoning models (e.g. Kimi K2.6 with `--reasoning on`):

```
terminal(command="opencode run 'Respond with exactly: OPENCODE_SMOKE_OK' --model local/synthclaw-35bkimi-128k", timeout=300)
```

Wait for the reasoning pass to complete — can take 30-120s on a 35B local model.

Success criteria:
- Output includes `OPENCODE_SMOKE_OK` (or expected response)
- Command exits without provider/model errors
- For code tasks: expected files changed and tests pass

## Rules

1. Prefer `opencode run` for one-shot automation — it's simpler and doesn't need pty.
2. Use interactive background mode only when iteration is needed.
3. Always scope OpenCode sessions to a single repo/workdir.
4. For long tasks, provide progress updates from `process` logs.
5. Report concrete outcomes (files changed, tests, remaining risks).
6. Exit interactive sessions with Ctrl+C or kill, never `/exit`.
