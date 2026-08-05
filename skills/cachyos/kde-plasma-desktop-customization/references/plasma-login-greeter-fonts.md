# Plasma Login Manager — greeter fonts (session 2026-07-25)

How the 3270 Nerd Font was applied to the CachyOS login screen.

## Diagnosis path that worked

1. `systemctl status display-manager` → `plasmalogin.service` (Plasma Login Manager).
   SDDM is NOT installed (`pacman -Q sddm` empty) even though
   `/usr/share/sddm/themes/breeze` exists and even had a `theme.conf.user` with
   `font=3270 Nerd Font` — dead config from a previous assumption. Breeze's QML
   reads `Kirigami.Theme.defaultFont` and never reads the `font=` key anyway.
2. `pacman -Ql plasma-login-manager` shows the greeter is `/usr/lib/plasma-login-greeter`
   plus `startplasma-login-wayland` / `plasma-login-kwin_wayland.service` — i.e. a
   real mini Plasma session, not a QML theme.
3. Greeter user: `grep plasmalogin /etc/passwd` → home `/var/lib/plasmalogin`
   (perms 750; reading it requires sudo).

## The fix (as run)

```bash
sudo bash -c '
install -d -m 700 -o plasmalogin -g plasmalogin /var/lib/plasmalogin/.config
K=/var/lib/plasmalogin/.config/kdeglobals
touch "$K"
kwriteconfig6 --file "$K" --group General --key font                "3270 Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file "$K" --group General --key fixed               "3270 Nerd Font Mono,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file "$K" --group General --key menuFont            "3270 Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file "$K" --group General --key toolBarFont         "3270 Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file "$K" --group General --key activeFont          "3270 Nerd Font,10,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
kwriteconfig6 --file "$K" --group General --key smallestReadableFont "3270 Nerd Font,9,-1,5,400,0,0,0,0,0,0,0,0,0,0,1"
chown plasmalogin:plasmalogin "$K"
sudo -u plasmalogin fc-match "3270 Nerd Font"
'
```

Font-value format copied verbatim from the user's own `~/.config/kdeglobals`
(`family,size,-1,5,400,0,...,1`) — safest source of truth for the string shape.

## Verification

- `sudo -u plasmalogin fc-match "3270 Nerd Font"` must return a 3270 TTF (a
  Condensed variant is fine), NOT a fallback like Noto Sans.
- Real test is logout/reboot — the login screen renders in the new font.
- `kwriteconfig6 --file <abs path>` merges keys, so it is safe on a kdeglobals
  that already holds greeter/wallpaper settings.

## Pitfalls

- Fonts must be system-wide (`/usr/local/share/fonts` or `/usr/share/fonts`,
  world-readable). User fonts in `~/.local/share/fonts` are invisible to the
  greeter account.
- Files under `/var/lib/plasmalogin` must be owned `plasmalogin:plasmalogin`.
- **Pasted multi-line sudo blocks can mangle values.** When the user hand-pastes
  the `sudo bash -c '...'` block into a terminal, font values can end up with
  literal `\n` + padding baked in (`font=3270        \n     Nerd Font,10,...`).
  It still *looks* right on the login screen because fontconfig fuzzy-matches
  the mangled family name — so `fc-match` alone is not enough verification.
  Read back the actual values (`sudo grep '^font=' /var/lib/plasmalogin/.config/kdeglobals`)
  and expect clean `family,size,...` strings. Fix by rewriting the file with
  clean values (`sed -E 's/=3270\s*\\n\s*Nerd Font/=3270 Nerd Font/'`) and
  re-installing it. Prefer running the sudo commands agent-side over asking
  the user to paste them.
- GUI equivalent: System Settings → Login Screen (Plasma Login Manager) →
  "Apply Plasma Settings" — syncs the logged-in user's fonts/colors/wallpaper
  via the `kcm_plasmalogin` kauth helper. Manual kwriteconfig6 is more exact.

## Backup-repo integration (cachyos-setup)

The greeter kdeglobals, `/etc/plasmalogin.conf`, `/etc/plymouth/plymouthd.conf`,
and the Plymouth theme dir (`/usr/share/plymouth/themes/<theme>/`, world-readable)
were added to the backup repo. install.sh restores them with sudo, re-chowns to
`plasmalogin:plasmalogin`, and runs `mkinitcpio -P` after Plymouth theme install.
