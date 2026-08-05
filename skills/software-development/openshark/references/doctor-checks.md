# OpenShark doctor checks

`openshark doctor` inspects:
1. TOML parse success at `~/.config/openshark/config.toml`
2. Provider env files existence
3. Memory DB reachability
4. Cache entries
5. Skill entries count
6. Binary presence at `~/.cargo/bin/openshark`

`openshark doctor --fix` attempts auto-repair where possible. It does NOT create env files for inline keys — migrate those manually.

## Silencing the env-file warning

Move provider keys out of TOML and into env files:
```toml
[providers.kimi]
env_file = "kimi.env"
```

Place the actual key in `~/.config/openshark/kimi.env`:
```
KIMI_API_KEY=sk-...
```

Doctor treats inline keys as a warning, not an error. The harness still works with inline keys.
