# Blackshield Boot/Login Art — Full Deployment Map

Session-proven 2026-08-22. When regenerating or replacing the blackshield shield art,
EVERY path below must receive the new file or the chain shows stale art somewhere.
Master is 2560×1440; one 1920×1080 derivative covers the rest.

## Discovery sweep (run BEFORE deploying — consumers drift over time)

```bash
grep -iE 'image|wallpaper' ~/.config/kscreenlockerrc          # lock screen source path
cat ~/.local/share/plasma/look-and-feel/*/contents/lockscreen/lock_background.image
grep -i wallpaper /etc/plasmalogin.conf                        # greeter wallpaper path
sudo grep -i wallpaper /boot/limine.conf                       # which /boot file Limine loads
ls /usr/share/plymouth/themes/blackshield/                     # plymouth theme assets
```

**Easy-to-miss consumers (burned once):**
- `~/Pictures/blackshield-lock-login/blackshield-2560x1440.png` — kscreenlockerrc `Image=` points HERE, not into the repo or LNF dir. Original deployment missed it.
- `lock_background.image` (in the LNF theme's `contents/lockscreen/`) is a 147-byte INI pointing at `contents/splash/images/splash.png` — updating that splash.png covers the lock background too.

## 2560×1440 copies (master)

| Target | sudo? |
|---|---|
| repo: `~/Projects/active/cachyos-blackshield/assets/splash/blackshield-splash.png` | no |
| repo: `.../configs/limine/limine-splash-blackshield-1440.png` | no |
| repo: `.../wallpapers/blackshield-lock-login/blackshield-2560x1440.png` | no |
| `~/Pictures/blackshield-lock-login/blackshield-2560x1440.png` | no |
| `/usr/share/plymouth/themes/blackshield/background.png` | YES |
| `~/.local/share/plasma/look-and-feel/Sweet-Blackshield/contents/splash/images/splash.png` | no |
| `.../Sweet-Blackshield/contents/splash/blackshield-splash/contents/ui/splash.png` | no |
| `/var/lib/plasmalogin/wallpapers/blackshield-2560x1440.png` | YES + `chown plasmalogin:plasmalogin` |
| `/boot/limine-splash-blackshield-1440.png` | YES |

## 1920×1080 copies (derivative)

| Target | sudo? |
|---|---|
| repo: `.../configs/limine/limine-splash-blackshield.png` | no |
| repo: `.../wallpapers/blackshield-lock-login/blackshield-1920x1080.png` | no |
| `~/Pictures/blackshield-lock-login/blackshield-1920x1080.png` | no |
| `.../Sweet-Blackshield/contents/splash/images/splash-1080.png` | no |
| `/boot/limine-splash-blackshield.png` ← **the file limine.conf actually loads** | YES |

## Post-deploy steps (order matters)

1. `sudo plymouth-set-default-theme -R blackshield` — rebuilds initramfs for ALL kernels
   (cachyos + cachyos-lts) with the new background baked in. Skipping this = old art at boot.
2. Verify: `md5sum` every copy against the master — one command, catches missed targets.
3. Confirm `/boot/limine.conf` wallpaper line survived (limine-snapper-sync rewrites it
   during the initramfs deploy — check, don't assume).
4. Boot-menu legibility: sample center pixels (PIL mean RGB of a 300px center crop);
   keep it dark — Limine draws menu text dead-center.

## Generation notes

- Krea 2 Large landscape returns ~1376×768 → lanczos cover-crop upscale to 2560×1440
  (scale to cover, then center-crop the few extra px; 1376×768 is 1.7917:1 vs 16:9's 1.7778).
- Heraldic-art pitfall: "Jerusalem cross" = 1 large + 4 small quadrant crosses. Confirm the
  exact charge layout with the user BEFORE mass deployment — regenerating one master is
  cheap, but 16 stale copies are annoying. Negative prompts that worked:
  `exactly ONE cross only, no small crosses, no crosses in the corners, no quadrant crosses`.
- Vision-verify the generated master for stray charges/text BEFORE deploying anywhere.
