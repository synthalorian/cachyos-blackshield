# oh-my-openagent (OmO) Architecture Reference

Retrieved from `AGENTS.md` on dev branch, v4.2.3 (2026-05-20).

## Stats

- 313K LOC, 2167 TypeScript files, 120 barrel `index.ts` files
- 6,609 commits, 84 branches, 201 tags
- 58.7K stars, 4.8K forks
- MIT licensed

## 11 Agents

| Agent | Role | Mode |
|-------|------|------|
| Sisyphus | Primary coding | primary |
| Hephaestus | Advanced coding | subagent |
| Oracle | Code review/analysis | primary |
| Librarian | Search/indexing | primary |
| Explore | Codebase exploration | primary |
| Atlas | Architecture planning | subagent |
| Prometheus | Documentation (MD-only enforced) | subagent |
| Metis | Task planning | subagent |
| Momus | Critic/reviewer | subagent |
| Multimodal-Looker | Vision/image analysis | subagent |
| Sisyphus-Junior | Lightweight subagent | subagent |

## Team Mode

OFF by default. Parallel multi-agent coordination (up to 8 members). Members get git worktrees for isolation. Storage at `~/.omo/teams/{name}/`. Eligible: sisyphus, atlas, sisyphus-junior. Others must use task/delegate.

Config:
```jsonc
{
  "team_mode": {
    "enabled": true,
    "max_parallel_members": 4,
    "max_members": 8,
    "max_messages_per_run": 10000,
    "max_wall_clock_minutes": 120,
    "max_member_turns": 500
  }
}
```

## 54-61 Lifecycle Hooks (5 Tiers)

1. **Session** (24) — lifecycle, compaction, auto-continue
2. **ToolGuard** (16) — pre/post tool guards, write-existing-file-guard, label-truncator
3. **Transform** (5) — context injection, thinking-block validation, keyword detection
4. **Continuation** (7) — runtime fallback, context recovery
5. **Skill** (2) — skill auto-loading

With Team Mode enabled: +1 ToolGuard, +2 Transform, +4 event handlers = 61 total.

## Tool Catalog (20-39, config-gated)

**Always on (20):** lsp_goto_definition, lsp_find_references, lsp_symbols, lsp_diagnostics, lsp_prepare_rename, lsp_rename, grep, glob, ast_grep_search, ast_grep_replace, session_list, session_read, session_search, session_info, background_output, background_cancel, call_omo_agent, task, skill, skill_mcp

**Conditional:** look_at (+1), interactive_bash (+1), task_create/get/list/update (+4), hashline edit (+1), team_* tools (+12)

## 3-Tier MCP System

| Tier | Source | Mechanism |
|------|--------|-----------|
| 1. Built-in | `src/mcp/` | 3 remote HTTP + 2 local stdio (lsp, ast_grep) |
| 2. Project | `.mcp.json` | Claude Code compat with `${VAR}` env expansion |
| 3. Skill-embedded | SKILL.md YAML | Per-session isolation, OAuth 2.0 + PKCE + DCR |

## Key Architecture Patterns

- **Hashline edit:** Every Read output tagged with LINE#ID content hashes. Edits reject on hash mismatch (stale read protection).
- **Prompt-async gate:** All internal message injection goes through shared gate with reservation + post-dispatch hold (2000ms). Prevents duplicate injection from concurrent hooks.
- **Dual fallback:** Model fallback (proactive, chat.params, hardcoded chains) vs runtime fallback (reactive, session.error). Independent systems.
- **Comment-checker:** Binary hook that blocks AI slop comment patterns. Bypass: `// @allow` or `// comment-checker-disable-file`.
- **IntentGate:** Keyword detector classifies intent (ultrawork/ulw, search, analyze, team) and injects mode-specific prompts.
- **Background tasks:** 5 concurrent per `${providerID}/${modelID}` key, FIFO queue when slots full.
- **Config:** Multi-level JSONC walk (project → user → defaults), Zod v4 validation, idempotent migration with timestamped backups.

## Init Flow

```
server(input, options)
  → installAgentSortShim()        # canonical agent ordering
  → initConfigContext()           # layout flag
  → detectExternalSkillPlugin()   # conflict warning
  → injectServerAuthIntoClient()  # auth headers
  → loadPluginConfig()            # JSONC → Zod → migrate
  → initializeOpenClaw()          # if configured
  → checkTeamModeDependencies()   # if enabled
  → createManagers()              # Tmux, Background, SkillMcp, ConfigHandler
  → createTools()                 # SkillContext + ToolRegistry
  → createHooks()                 # 5-tier composition
  → createPluginInterface()       # 11 hook handlers
```

## Caveats

- Active multi-harness refactor in progress — structure not stable yet
- Bun-only runtime (1.3.12 in CI)
- Windows builds run on windows-latest (not cross-compiled)
- PRs must target `dev`, never `master` directly
- omocache path is `~/.cache/oh-my-opencode/` (legacy name, not `oh-my-openagent`)
