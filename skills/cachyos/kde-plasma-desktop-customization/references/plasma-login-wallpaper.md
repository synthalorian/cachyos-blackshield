# Plasma Login Manager Wallpaper Notes

Session-derived notes for KDE Plasma Login Manager (`plasmalogin`) wallpaper configuration on CachyOS / Plasma 6.7.

## Detect the actual login manager first

Do not assume SDDM on modern Plasma:

```bash
systemctl status display-manager --no-pager
```

A CachyOS Plasma 6.7 system may show `plasmalogin.service` even when SDDM theme files exist under `/usr/share/sddm/themes/` (those files can be owned by `plasma-desktop`).

## User lock screen config

KDE lock screen wallpaper lives in `~/.config/kscreenlockerrc`:

```bash
kwriteconfig6 --file kscreenlockerrc \
  --group Greeter --group Wallpaper --group org.kde.image --group General \
  --key Image 'file:///absolute/path/to/wallpaper.png'
kwriteconfig6 --file kscreenlockerrc \
  --group Greeter --group Wallpaper --group org.kde.image --group General \
  --key FillMode 2
```

Verify with `kreadconfig6`; do not trigger a lock just to test unless the user explicitly asks.

## Plasma Login Manager config

Main config: `/etc/plasmalogin.conf`.

Image-wallpaper shape derived from the Plasma Login KCM source:

```ini
[Greeter]
WallpaperPluginId=org.kde.image

[Greeter][Wallpaper][org.kde.image][General]
FillMode=2
Image=file:///var/lib/plasmalogin/wallpapers/wallpaper.png
```

The greeter runs as the `plasmalogin` user, whose home is `/var/lib/plasmalogin`. Copy wallpapers there and make them readable:

```bash
sudo install -d -o plasmalogin -g plasmalogin -m 0755 /var/lib/plasmalogin/wallpapers
sudo install -o plasmalogin -g plasmalogin -m 0644 wallpaper.png \
  /var/lib/plasmalogin/wallpapers/wallpaper.png
```

Back up `/etc/plasmalogin.conf` before replacing it. Preserve unrelated existing entries such as `[Autologin] Session=...`.

## Binary pitfall

`/usr/bin/plasma-login-wallpaper` is the login wallpaper process launched by `plasma-wallpaper.service`, not a conventional CLI settings helper. Running it with `--help` can start the wallpaper UI and hang instead of printing help. Configure via `/etc/plasmalogin.conf` or System Settings, not by probing that binary.
