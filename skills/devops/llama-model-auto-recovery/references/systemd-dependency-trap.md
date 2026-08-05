# systemd Dependency Trap: The `BindsTo` Backdoor

## Scenario

User disables `llama-swap.service` to prevent auto-start, but it keeps coming back on every login.

## Root Cause

`llama-swap-prewarm.service` was enabled and bound to the main service:

```ini
[Unit]
BindsTo=llama-swap.service

[Install]
WantedBy=default.target
```

`BindsTo` is a stronger form of `Requires` — when the prewarm unit starts (at login via `default.target`), it **forces** `llama-swap.service` to start too. Disabling the main service alone is irrelevant.

## Diagnostic Commands

```bash
# Check which llama-related units exist
systemctl --user list-unit-files | grep llama

# Check if a service is actually enabled (not just loaded)
systemctl --user is-enabled llama-swap.service
systemctl --user is-enabled llama-swap-prewarm.service

# See the full dependency tree
systemctl --user list-dependencies llama-swap-prewarm.service

# Check what's actually running
ps aux | grep -E "llama-server|llama-swap" | grep -v grep
```

## The Fix

```bash
# Disable the companion unit (removes it from default.target.wants)
systemctl --user disable llama-swap-prewarm.service

# Stop both units
systemctl --user stop llama-swap-prewarm.service
systemctl --user stop llama-swap.service
```

## General Pattern

When a service keeps respawning despite being "disabled":

1. `systemctl --user list-unit-files | grep <service-name>` — find ALL related units
2. Check for `BindsTo=`, `Requires=`, `Wants=` in companion unit files
3. Check `After=` and `Before=` relationships
4. Look at `default.target.wants/`, `multi-user.target.wants/`, `graphical.target.wants/`
5. Remember: `disabled` on the main unit ≠ won't start. Dependencies can pull it up.

## Related: Socket Activation

For true on-demand start (start only when port is hit), use systemd socket activation instead of `BindsTo`:

```ini
# llama-swap.socket
[Socket]
ListenStream=127.0.0.1:8080
Accept=false

[Install]
WantedBy=sockets.target
```

Then `llama-swap.service` gets `Requires=llama-swap.socket` and starts on first connection. Not currently configured for llama-swap but is the correct systemd-native approach for on-demand services.
