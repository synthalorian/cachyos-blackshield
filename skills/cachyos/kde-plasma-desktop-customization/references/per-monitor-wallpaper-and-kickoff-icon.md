# Per-Monitor Wallpaper + Kickoff Icon Recipe (Plasma 6/Wayland)

## Screen mapping

Do not assume leftmost monitor is screen 0. Query KWin:

```bash
qdbus6 org.kde.KWin /KWin org.kde.KWin.supportInformation | awk '/Screen|Name:|Geometry/{print}' | head -40
```

Observed mapping on synth's setup:

```text
Screen 0:
Name: DP-3
Geometry: 1920,0,2560x1440   # primary 2K
Screen 1:
Name: HDMI-A-1
Geometry: 0,0,1920x1080      # secondary
```

Plasma desktop containments exposed the same indices via `desktops()[i].screen`.

## Set wallpapers by screen

```bash
qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript '
var primary = "file:///home/synth/Pictures/synthwave/primary-testarossa-wallpaper-2k.png";
var secondary = "file:///home/synth/Pictures/synthwave/secondary-delorean-wallpaper-2k.png";
var ds = desktops();
for (var i=0;i<ds.length;i++) {
  var d = ds[i];
  d.wallpaperPlugin = "org.kde.image";
  d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  if (d.screen === 0) d.writeConfig("Image", primary);
  else if (d.screen === 1) d.writeConfig("Image", secondary);
  d.writeConfig("FillMode", 2);
}
for (var j=0;j<ds.length;j++) {
  var c = ds[j];
  c.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
  print("screen="+c.screen+" image="+c.readConfig("Image")+" fill="+c.readConfig("FillMode"));
}'
```

`FillMode=2` is PreserveAspectCrop. `plasma-apply-wallpaperimage` was present but only accepts an image/fill mode — no per-screen selector — so it is the wrong tool for multi-monitor wallpaper assignment.

## Set Kickoff/Application Launcher icon

Find the applet:

```bash
grep -n "plugin=org.kde.plasma.kickoff" ~/.config/plasma-org.kde.plasma.desktop-appletsrc
```

Session applet was `[Containments][49][Applets][50]`. Back up and set the icon with nested `kwriteconfig6` groups:

```bash
cfg="$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc"
cp "$cfg" "$cfg.bak-$(date +%Y%m%d%H%M%S)"
kwriteconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
  --group Containments --group 49 --group Applets --group 50 --group Configuration --group General \
  --key icon /home/synth/Pictures/synthwave/taskbar-outrun-sunset-icon-256.png
```

Restart Plasma to load the panel icon:

```bash
systemctl --user restart plasma-plasmashell.service
```

**Do NOT use `plasmashell --replace` here (confirmed 2026-08-22):** from the agent background shell it exits cleanly while the OLD plasmashell keeps running (PID start time unchanged) — the icon change stays invisible and looks like a bad deploy. It no-oped twice in one session; only the systemctl restart actually swapped the shell. Also delete `~/.cache/icon-cache.kcache` when the icon file was overwritten in place.

Verify:

```bash
kreadconfig6 --file plasma-org.kde.plasma.desktop-appletsrc \
  --group Containments --group 49 --group Applets --group 50 --group Configuration --group General \
  --key icon
ps -o pid,lstart,cmd -C plasmashell   # lstart MUST post-date the restart
```
