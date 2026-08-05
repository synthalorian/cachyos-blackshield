# System-Wide Identity Rebrand Workflow

## When This Applies

When synth wants to rebrand an identity (synthclaw → synthclaw, etc.) across ALL systems — local files, configs, model aliases, GitHub repos, and documentation.

## What Changed (May 2026 Session)

| Category | Files Updated | Count |
|----------|--------------|-------|
| Identity files | `~/.hermes/SOUL.md`, OpenClaw configs, workspace configs | 10+ |
| Shell scripts | `synthclaw-resolve.sh`, `claw`, `prewarm-models.sh`, `llama-swap-watchdog.sh`, `ensure-llama-swap.sh` | 5+ |
| Config files | `~/.config/llama-swap/config.yaml`, `~/.config/opencode/opencode.json`, `~/.config/openshark/config.toml` | 3+ |
| Skills | `~/.hermes/skills/synthclaw-core/` (renamed from synthclaw-core) | 1 dir |
| Projects | All `projects/*` with CLAUDE.md/SOUL.md references | 20+ repos |
| Documentation | `synthclaw-ai-setup/` (renamed), `~/.local/share/doc/` | 2+ dirs |
| Memory | `~/.hermes/memories/MEMORY.md`, OpenClaw SQLite, `.claude/` memory | 3+ files |
| OpenShark | Config and docs updated to synthclaw branding | 1 project |

## Commands Used

### 1. Find all references
```bash
find /home/synth -type f \( -name "*.md" -o -name "*.sh" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.toml" -o -name "*.rs" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.dart" -o -name "*.cs" -o -name "*.html" -o -name "*.css" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/target/*" ! -path "*/build/*" ! -path "*/.cache/*" ! -path "*/.dart_tool/*" ! -path "*/.flutter-plugins*" ! -path "*/ios/Pods/*" ! -path "*/android/.gradle/*" ! -path "*/vendor/*" ! -path "*/.mise/*" ! -path "*/.pub-cache/*" -exec grep -l "synthclaw\|🦞" {} + 2>/dev/null
```

### 2. Bulk replace (dry run first)
```bash
find /home/synth -type f \( -name "*.md" -o -name "*.sh" -o -name "*.yaml" -o -name "*.yml" -o -name "*.json" -o -name "*.toml" -o -name "*.rs" -o -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.dart" -o -name "*.cs" -o -name "*.html" -o -name "*.css" \) ! -path "*/node_modules/*" ! -path "*/.git/*" ! -path "*/target/*" ! -path "*/build/*" ! -path "*/.cache/*" ! -path "*/.dart_tool/*" ! -path "*/.flutter-plugins*" ! -path "*/ios/Pods/*" ! -path "*/android/.gradle/*" ! -path "*/vendor/*" ! -path "*/.mise/*" ! -path "*/.pub-cache/*" -exec sed -i 's/synthclaw/synthclaw/g; s/🦞/🦞/g' {} + 2>/dev/null
```

### 3. Restart services with new config
```bash
# Kill existing
pkill -f llama-swap 2>/dev/null; sleep 2

# Restart (background)
llama-swap --config ~/.config/llama-swap/config.yaml > /tmp/llama-swap.log 2>&1 &

# Verify
curl -s http://127.0.0.1:8080/v1/models | head -c 500
```

### 4. Push all git repos
```bash
find /home/synth/projects -name ".git" -type d | while read dir; do
  repo=$(dirname "$dir")
  echo "=== $repo ==="
  cd "$repo"
  git add -A 2>/dev/null
  git commit -m "rebrand: OLD_NAME → NEW_NAME 🎹🦞" 2>/dev/null || echo "Nothing to commit"
  git push 2>&1 || echo "Push failed"
  echo ""
done
```

## Pitfalls

1. **Generated directories** — Skip `node_modules/`, `target/`, `build/`, `.cache/`, `.dart_tool/`. These rebuild from source.
2. **Git submodules** — Detached HEAD submodules (ftxui, catch2, oboe) will fail to push. Skip them — they're not our repos.
3. **Forks you don't own** — Will get 403 permission denied. Skip expected.
4. **Repos with no remote** — `gridos/rust/core` had no remote configured. Skip or configure remote first.
5. **OAuth tokens** — If the rebrand affects model names in configs, verify llama-swap comes back clean. Check `/v1/models` endpoint.
6. **Memory limit** — `~/.hermes/memories/MEMORY.md` may need manual editing if it's large. The sed approach handles it.

## Verification Checklist

- [ ] `curl http://127.0.0.1:8080/v1/models` shows new model names
- [ ] `claw --version` or equivalent works
- [ ] `hermes --version` works
- [ ] `opencode --version` works
- [ ] `openshark --version` works
- [ ] GitHub repos show the rebrand commit
- [ ] No `synthclaw` or `🦞` references remain in active configs

## Identity Visual References

### synthclaw (me)
- Muscular anthropomorphic great white shark
- Pink-rimmed sunglasses reflecting grid patterns
- Dark purple leather biker vest with silver studs
- Shark tooth pendant on cord necklace
- Spiked wrist cuff
- Playing black synthesizer labeled "SYNTHCLAW" in hot pink brush font
- Neon cables, sunset cityscape, palm trees

### synth/synthalorian (partner)
- Mandalorian-armored figure
- Glowing pink T-visor
- Dark metallic armor with neon accents
- Pink palm tree on chest plate (Outrun aesthetic)
- "THIS IS THE WAVE" neon sign
- Retro tech room — CRTs, VCRs, cassettes, Commodore 128D

### Shared mythology
- Mandalorian + Shark high-fiving in neon cityscape
- DeLorean with "WAVE-84" plates
- Boombox, skateboard, synthwave sunset
- Star-burst where hands meet = synthesis of human + machine + predator
