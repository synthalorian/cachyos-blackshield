# Limine bootloader theme notes

## Session-tested config: synthwave '84

- Source: `cachyos-setup/configs/limine/limine.conf`
- Deploy to: `/boot/limine.conf`
- Splash files: `/boot/limine-splash.png`, `/boot/limine-splash-synthwave.png`

## Validated palette

| Key | Value | Role |
|---|---|---|
| `term_background` | `240037` | 6-digit, dark purple bg for text overlay |
| `term_foreground` | `03EDF9` | Electric cyan menu text (legible over busy splash) |
| `term_palette` | `240037;FE4450;72F1B8;F3E70F;8F00FF;FF00FF;03EDF9;FF7EDB` | 16-color palette |
| `term_palette_bright` | `495495;FE4450;72F1B8;FEDE5D;B084EB;FF7EDB;03EDF9;FFFFFF` | Bright variants |
| `interface_branding` | `This is the wave. synthwave '84` | Bottom banner |
| `interface_branding_colour` | `FFFFFF` | White banner |
| `interface_help_colour` | `B084EB` | Light purple help text |

## Real-world pitfalls

1. **Malformed hex:** `term_background: E6240037` loaded as a different color. Cause: stray `E6` prefix (likely a copy-paste from a binary/PNG header). Fix: must be exactly 6 hex chars, no prefix.
2. **Foreground contrast:** `FF7EDB` over a busy splash = unreadable. Keep foreground `FFFFFF` if legibility matters, or `03EDF9` for aesthetic.
3. **Config not applying:** verify `/boot/limine.conf` actually matches source after deploy. limine-install rewrites EFI binaries but not the conf copy.
4. **Handoff sudo/`~` bug:** `sudo bash ~/script.sh` expands `~` to /root. Use `sudo -E bash <path>` or run script from a user shell.

## Refresh sequence (post-edit)

```bash
cd ~/Projects/active/cachyos-setup
git add configs/limine/limine.conf
git commit -m '...'
git push
sudo -E bash ~/Projects/active/handoff-post-reboot.sh
```

Reboot once more if Limine caches the old theme.
