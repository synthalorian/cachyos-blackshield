#!/usr/bin/env bash
# handoff-post-reboot.sh
# Use after reboot on a fresh/updated CachyOS grid to reassert tonight's polish.
# Run from: ~/Projects/active
# Usage: sudo bash ./handoff-post-reboot.sh
set -euo pipefail

echo "🎹🦞 POST-REBOOT POLISH — $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo "===================================================="
echo ""

# 0. sanity
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
  echo "[hint] some checks need root; re-run with: sudo bash $0"
fi
test -d ~/Projects/active/cachyos-setup || { echo 'missing ~/Projects/active/cachyos-setup'; exit 1; }
cd ~/Projects/active/cachyos-setup
echo "[env] OK — $(pwd)"
echo ""

# 1. CPU governor should already be performance; confirm + reapply if needed
echo "[tune] cpu governor..."
if [[ -f configs/system/tmpfiles.d-cpu-governor.conf ]]; then
  mkdir -p /etc/tmpfiles.d
  cp -f configs/system/tmpfiles.d-cpu-governor.conf /etc/tmpfiles.d/cpu-governor.conf
  systemd-tmpfiles --create /etc/tmpfiles.d/cpu-governor.conf >/dev/null 2>&1 || true
fi
if command -v cpupower >/dev/null 2>&1; then
  sudo cpupower frequency-set -g performance >/dev/null 2>&1 || true
fi
echo "$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo unknown) $(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor 2>/dev/null | sort -u | paste -sd',' -)"
echo ""

# 2. zram 2x swap
echo "[tune] zram..."
if [[ -f configs/system/zram-2x.conf ]]; then
  mkdir -p /etc/systemd/zram-generator.conf.d
  cp -f configs/system/zram-2x.conf /etc/systemd/zram-generator.conf.d/99-synthswap.conf
fi
if [[ -f /sys/block/zram0/disksize ]]; then
  echo "  zram size: $(cat /sys/block/zram0/disksize) bytes"
else
  echo "  zram not active yet — reboot may still be pending"
fi
echo ""

# 3. Limine: text + splash
echo "[boot] limine..."
if [[ -f configs/limine/limine.conf ]]; then
  branding=$(rg -n "^interface_branding:" configs/limine/limine.conf | head -1 || true)
  colour=$(rg -n "^interface_branding_colour:" configs/limine/limine.conf | head -1 || true)
  echo "  $branding"
  echo "  $colour"
  sudo cp -f configs/limine/limine.conf /boot/limine.conf
  sudo install -m 644 -o root -g root \
    configs/limine/limine-splash84-v2.png /boot/limine-splash84-v2.png
  sudo install -m 644 -o root -g root \
    configs/limine/limine-splash-synthwave.png /boot/limine-splash-synthwave.png
  sudo install -m 644 -o root -g root \
    configs/limine/limine-splash.png /boot/limine-splash.png
  limine-install >/dev/null 2>&1 || true
  echo "  limine config + splash applied; EFI install attempted"
else
  echo "  missing configs/limine/limine.conf"
fi
echo ""

# 4. Plymouth + login
echo "[boot] plymouth + plasmalogin..."
if [[ -d configs/plymouth/synthwave84 ]]; then
  sudo cp -r configs/plymouth/synthwave84 /usr/share/plymouth/themes/
fi
if [[ -f configs/system/plymouthd.conf ]]; then
  sudo cp -f configs/system/plymouthd.conf /etc/plymouth/plymouthd.conf
fi
sudo plymouth-set-default-theme synthwave84 >/dev/null 2>&1 || true
if [[ -f configs/system/plasmalogin.conf ]]; then
  sudo cp -f configs/system/plasmalogin.conf /etc/plasmalogin.conf
fi
if [[ -f configs/system/plasmalogin-greeter-kdeglobals ]]; then
  sudo install -d -m 700 -o plasmalogin -g plasmalogin /var/lib/plasmalogin/.config /var/lib/plasmalogin/wallpapers
  sudo install -m 644 -o plasmalogin -g plasmalogin \
    configs/system/plasmalogin-greeter-kdeglobals /var/lib/plasmalogin/.config/kdeglobals
fi
if [[ -f wallpapers/synthwave84-lock-login/synthwave84-v2-2560x1440.png ]]; then
  sudo install -m 644 -o plasmalogin -g plasmalogin \
    wallpapers/synthwave84-lock-login/synthwave84-v2-2560x1440.png \
    /var/lib/plasmalogin/wallpapers/synthwave84-v2-2560x1440.png
fi
sudo mkinitcpio -P >/dev/null 2>&1 || true
echo ""

# 5. Fish functions (single-file per function, no env-level pollution)
echo "[fish] functions..."
fish_functions_dir="$HOME/.config/fish/functions"
src_dir="$(cd ~/Projects/active/cachyos-setup/configs/fish/functions && pwd)"
for f in conflicts aliases activate ginit this-is-the-wave ls top yt tmux-launch zoxide llama-toggle; do
  if [[ -f "$src_dir/$f.fish" ]]; then
    install -m 644 "$src_dir/$f.fish" "$fish_functions_dir/$f.fish"
  fi
done
echo ""

# 6. Service prompts
echo "[services] user services..."
systemctl --user daemon-reload >/dev/null 2>&1 || true
for svc in llama-swap hermes-gateway openclaw-gateway; do
  if [[ -f ~/.config/systemd/user/$svc.service ]]; then
    systemctl --user is-enabled "$svc" >/dev/null 2>&1 || systemctl --user enable "$svc" >/dev/null 2>&1 || true
    echo "  $svc enabled=$(systemctl --user is-enabled "$svc" 2>/dev/null || echo unknown)"
  fi
done
echo ""

echo "✅ Post-reboot polish reapplied."
echo ""
echo "[next] optional after-login polish:"
cat <<'EOF'
  1. Log out/in for fish + KDE effects to fully apply.
  2. Start services: systemctl --user start llama-swap hermes-gateway openclaw-gateway
  3. Restart plasmashell if wallpaper/icons lag: plasmashell --replace
  4. Reboot once more if Plymouth/limine still cached an old theme.
EOF
echo ""
echo "🎹🦞 Handoff complete. This is the wave."
