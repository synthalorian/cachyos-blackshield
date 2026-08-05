# Claw Code Version Checking

## Local Build Info
- Binary: `/home/synth/.local/bin/claw`
- Source clone: `/home/synth/claw-code`
- Remotes: `origin` → synthalorian/claw-code (fork), `upstream` → ultraworkers/claw-code

## Quick Version Check
```bash
claw --version                        # Current binary version + SHA + build date
cd ~/claw-code
git fetch upstream --quiet
git log --oneline HEAD..upstream/main | wc -l   # Commits behind
```

## Upstream Commit Noise Profile

~80% of upstream commits are process automation noise. Filter these patterns to find real changes:

**Skip (noise):**
- `omx(team): auto-checkpoint` — CI worker auto-commits
- `G00x` / `G0xx` ultragoal ledger entries — internal milestone tracking
- `docs(roadmap): add #NNN` — issue tracking in docs
- `evidence`, `gate`, `ledger`, `stabilize`, `record`, `keep`, `preserve` — release process bookkeeping
- `Merge commit` lines (merge commits)

**Care about (signal):**
- `feat:` — new features (e.g., Google Gemini support was `65b9153`)
- `fix:` — bug fixes
- `Deny`, `Reject`, `Prevent` — security hardening
- Provider/model support additions
- Changes to `rust/` Cargo.toml version

## Useful Filter Command
```bash
# Show meaningful commits only (excluding noise patterns)
git log --oneline HEAD..upstream/main --no-merges | \
  grep -viE "omx|checkpoint|evidence|gate|ledger|ultragoal|G01|roadmap|stabilize|record|keep|preserve|close|merge worker|auto-checkpoint|task:|prove|map |verify|harden|document|require|ensure|clarify|prevent|surface|restore|lock|route|start|make"
```

## Key Facts
- No official releases tagged on GitHub (as of May 2026) — still v0.1.0
- No prebuilt binary releases — must build from source with `cargo build --release`
- Build output goes to `rust/target/release/claw`
