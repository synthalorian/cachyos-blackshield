#!/usr/bin/env bash
# ═══════════════════════════════════════════════════════════════════
#  cachyos-blackshield — synth's full-system bootstrap
#  Fresh CachyOS install -> fully working grid in one script.
#  Theme: BLACKSHIELD MERCENARY — black steel, blood-red cross potent.
#  Made by synth with synthclaw 🎹🦞
#
#  Usage (after gh auth login):
#    gh repo clone synthalorian/cachyos-blackshield && cd cachyos-blackshield && ./install.sh
#
#  Phases can be run individually: ./install.sh packages|configs|browsers|system|projects|ai|services|nvim
# ═══════════════════════════════════════════════════════════════════
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOME_DIR="$HOME"

c_blood='\033[38;2;193;18;31m'        # BLOOD     #C1121F
c_parchment='\033[38;2;216;211;200m'  # PARCHMENT #D8D3C8
c_brass='\033[38;2;201;162;39m'       # BRASS     #C9A227
c_reset='\033[0m'

say()  { echo -e "${c_blood}▸ ${c_reset}$1"; }
ok()   { echo -e "${c_parchment}  ✓ ${c_reset}$1"; }
warn() { echo -e "${c_brass}  ! ${c_reset}$1"; }

# ─────────────────────────────────────────────────────────────────
phase_packages() {
  say "Phase 1: system packages (pacman)"
  sudo pacman -Syu --noconfirm
  # Install explicit packages from the manifest; skip any that no longer exist
  local failed=()
  while read -r pkg; do
    [[ -z "$pkg" ]] && continue
    if pacman -Si "$pkg" &>/dev/null; then
      sudo pacman -S --needed --noconfirm "$pkg" || failed+=("$pkg")
    else
      warn "not in repos (skipping): $pkg"
    fi
  done < "$REPO_DIR/manifest/packages.txt"
  ((${#failed[@]})) && warn "failed to install: ${failed[*]}" || true
  ok "packages done"
}

# ─────────────────────────────────────────────────────────────────
phase_configs() {
  say "Phase 2: user configs"

  mkdir -p "$HOME_DIR/.config" "$HOME_DIR/.local/share"

  # shell / terminal / fetch
  mkdir -p "$HOME_DIR/.config/fish" "$HOME_DIR/.config/alacritty" \
           "$HOME_DIR/.config/kitty" "$HOME_DIR/.config/fastfetch" \
           "$HOME_DIR/.config/ghostty"
  cp -r "$REPO_DIR/configs/fish/"*      "$HOME_DIR/.config/fish/"
  cp -r "$REPO_DIR/configs/alacritty/"* "$HOME_DIR/.config/alacritty/" 2>/dev/null || true
  cp -r "$REPO_DIR/configs/kitty/"*     "$HOME_DIR/.config/kitty/" 2>/dev/null || true
  cp -r "$REPO_DIR/configs/ghostty/"*   "$HOME_DIR/.config/ghostty/" 2>/dev/null || true
  # fastfetch only parses ghostty/config (upstream path); Arch ghostty reads config.ghostty
  ln -sf config.ghostty "$HOME_DIR/.config/ghostty/config"
  cp -r "$REPO_DIR/configs/fastfetch/"* "$HOME_DIR/.config/fastfetch/"

  # nvim
  rm -rf "$HOME_DIR/.config/nvim"
  cp -r "$REPO_DIR/configs/nvim" "$HOME_DIR/.config/nvim"

  # KDE
  for f in kdeglobals kwinrc kwinrulesrc plasmarc kglobalshortcutsrc dolphinrc \
           kcminputrc plasma-org.kde.plasma.desktop-appletsrc kactivitymanagerdrc \
           baloofilerc gtkrc gtkrc-2.0; do
    [[ -f "$REPO_DIR/configs/kde/$f" ]] && cp "$REPO_DIR/configs/kde/$f" "$HOME_DIR/.config/$f"
  done
  mkdir -p "$HOME_DIR/.config/gtk-3.0" "$HOME_DIR/.config/gtk-4.0"
  cp "$REPO_DIR/configs/kde/gtk-3.0-settings.ini" "$HOME_DIR/.config/gtk-3.0/settings.ini" 2>/dev/null || true
  cp "$REPO_DIR/configs/kde/gtk-4.0-settings.ini" "$HOME_DIR/.config/gtk-4.0/settings.ini" 2>/dev/null || true
  cp "$REPO_DIR/configs/kde/gtkrc-2.0-home" "$HOME_DIR/.gtkrc-2.0" 2>/dev/null || true
  mkdir -p "$HOME_DIR/.local/share/color-schemes" "$HOME_DIR/.local/share/plasma/desktoptheme"
  cp -r "$REPO_DIR/configs/kde/color-schemes/"* "$HOME_DIR/.local/share/color-schemes/" 2>/dev/null || true
  cp -r "$REPO_DIR/configs/kde/desktoptheme/"*  "$HOME_DIR/.local/share/plasma/desktoptheme/" 2>/dev/null || true

  # icons (Obsidian-Red icon theme + Vimix-cursors), fonts, plasmoids, wallpapers
  mkdir -p "$HOME_DIR/.local/share/icons" "$HOME_DIR/.local/share/fonts" \
           "$HOME_DIR/.local/share/plasma/plasmoids" "$HOME_DIR/Pictures"
  cp -r "$REPO_DIR/configs/icons/"*     "$HOME_DIR/.local/share/icons/"
  cp -r "$REPO_DIR/configs/fonts/"*     "$HOME_DIR/.local/share/fonts/"
  cp -r "$REPO_DIR/configs/plasmoids/"* "$HOME_DIR/.local/share/plasma/plasmoids/"
  cp -r "$REPO_DIR/wallpapers/blackshield" "$HOME_DIR/Pictures/blackshield"
  cp -r "$REPO_DIR/wallpapers/blackshield-lock-login" "$HOME_DIR/Pictures/blackshield-lock-login"
  fc-cache -f &>/dev/null && ok "font cache rebuilt (EB Garamond + nerd fonts)"

  # git
  cp "$REPO_DIR/configs/git/gitconfig" "$HOME_DIR/.gitconfig"

  # default shell -> fish
  if [[ "$SHELL" != */fish ]]; then
    command -v fish &>/dev/null && chsh -s "$(command -v fish)" || warn "fish not installed yet — re-run after packages phase"
  fi

  ok "configs restored (log out/in for shell + KDE to fully apply)"
}

# ─────────────────────────────────────────────────────────────────
phase_browsers() {
  say "Phase 2a: browser themes (firefox + chromium) — BLACKSHIELD"

  # ── Firefox: userChrome.css / userContent.css / user.js per profile ──
  if command -v firefox &>/dev/null; then
    local ff_root="$HOME_DIR/.mozilla/firefox"
    # Firefox 150+ headless runs on a throwaway profile and never creates the
    # install-default one — but a headless run with an explicit -profile DOES
    # materialize installs.ini + the install-default profile dir.
    if [[ ! -f "$ff_root/installs.ini" ]]; then
      say "no firefox profile yet — seeding one headlessly"
      mkdir -p "$ff_root"
      local seedprof="$ff_root/.seed-blackshield"
      timeout 25 firefox --headless -profile "$seedprof" about:blank &>/dev/null || true
      rm -rf "$seedprof"
    fi
    # resolve targets: installs.ini Default first, then every *.default* dir
    local ff_profiles=()
    local ini_default
    ini_default=$(awk -F= '/^Default=/{print $2; exit}' "$ff_root/installs.ini" 2>/dev/null)
    [[ -n "$ini_default" && -d "$ff_root/$ini_default" ]] && ff_profiles+=("$ff_root/$ini_default")
    while IFS= read -r -d '' prof; do
      [[ " ${ff_profiles[*]:-} " == *" $prof "* ]] || ff_profiles+=("$prof")
    done < <(find "$ff_root" -maxdepth 1 -type d -name '*.default*' ! -name '.seed-*' -print0 2>/dev/null)
    if [[ ${#ff_profiles[@]} -eq 0 ]]; then
      warn "still no firefox profile — launch Firefox once, then re-run: ./install.sh browsers"
    else
      for prof in "${ff_profiles[@]}"; do
        mkdir -p "$prof/chrome"
        cp -r "$REPO_DIR/configs/browsers/firefox/chrome/"* "$prof/chrome/"
        if ! grep -q "blackshield" "$prof/user.js" 2>/dev/null; then
          cat "$REPO_DIR/configs/browsers/firefox/user.js" >> "$prof/user.js"
        fi
        ok "firefox BLACKSHIELD deployed -> $(basename "$prof") (restart Firefox to apply)"
      done
    fi
  else
    warn "firefox not installed — skipping firefox theme"
  fi

  # ── Chromium: unpacked theme (developer-mode load) ──
  if command -v chromium &>/dev/null || command -v chromium-browser &>/dev/null; then
    mkdir -p "$HOME_DIR/.config/chromium-themes"
    rm -rf "$HOME_DIR/.config/chromium-themes/blackshield"
    cp -r "$REPO_DIR/configs/browsers/chromium/blackshield" "$HOME_DIR/.config/chromium-themes/blackshield"
    ok "chromium theme staged at ~/.config/chromium-themes/blackshield"
    warn "chromium blocks CLI theme installs — one-time manual step:"
    echo  "       chrome://extensions -> enable Developer mode -> Load unpacked -> ~/.config/chromium-themes/blackshield"
  else
    warn "chromium not installed — skipping chromium theme"
  fi
}

# ─────────────────────────────────────────────────────────────────
phase_system() {
  say "Phase 2b: system boot/login (sudo) — plymouth + plasmalogin"

  # Plymouth boot splash (blackshield)
  sudo cp -r "$REPO_DIR/configs/plymouth/blackshield" /usr/share/plymouth/themes/
  sudo cp "$REPO_DIR/configs/system/plymouthd.conf" /etc/plymouth/plymouthd.conf
  sudo plymouth-set-default-theme blackshield 2>/dev/null || true
  sudo mkinitcpio -P && ok "plymouth theme blackshield installed + initramfs rebuilt"

  # Plasma Login Manager: config + greeter font (EB Garamond) + wallpaper
  sudo cp "$REPO_DIR/configs/system/plasmalogin.conf" /etc/plasmalogin.conf
  sudo install -d -m 700 -o plasmalogin -g plasmalogin /var/lib/plasmalogin/.config /var/lib/plasmalogin/wallpapers
  sudo install -m 644 -o plasmalogin -g plasmalogin \
    "$REPO_DIR/configs/system/plasmalogin-greeter-kdeglobals" /var/lib/plasmalogin/.config/kdeglobals
  sudo install -m 644 -o plasmalogin -g plasmalogin \
    "$REPO_DIR/wallpapers/blackshield-lock-login/blackshield-2560x1440.png" \
    /var/lib/plasmalogin/wallpapers/blackshield-2560x1440.png
  ok "plasmalogin: config + EB Garamond greeter + BLACKSHIELD login wallpaper"

  # Limine persistent kernel cmdline (pcie_aspm=off AER prophylaxis + EDID
  # override) — survives limine-entry-tool regeneration on kernel updates
  sudo cp "$REPO_DIR/configs/limine/default-limine" /etc/default/limine

  # Kill 802.11 power save system-wide (rtw88 AER storm trigger)
  sudo mkdir -p /etc/NetworkManager/conf.d
  sudo cp "$REPO_DIR/configs/system/99-wifi-powersave-off.conf" /etc/NetworkManager/conf.d/99-wifi-powersave-off.conf
  ok "limine default cmdline + wifi powersave-off deployed"
}

# ─────────────────────────────────────────────────────────────────
phase_projects() {
  say "Phase 3: project library (~/Projects)"
  mkdir -p "$HOME_DIR/Projects"/{active,archived,backburner,finished,forks,faith}

  clone_one() {
    local line="$1"
    local cat name remote
    IFS=$'\t' read -r cat name remote <<< "$line"
    local dest="$HOME/Projects/$cat/$name"
    if [[ -d "$dest/.git" ]]; then
      echo "  = exists: $cat/$name"
    else
      git clone --quiet "$remote" "$dest" && echo "  + cloned: $cat/$name" || echo "  ! FAILED: $cat/$name"
    fi
  }
  export -f clone_one

  grep -v '^$' "$REPO_DIR/manifest/projects.tsv" | xargs -d '\n' -P 8 -I {} bash -c 'clone_one "$@"' _ {}
  ok "projects cloned"
}

# ─────────────────────────────────────────────────────────────────
phase_ai() {
  say "Phase 4: AI stack (hermes, llama-swap, opencode)"

  # ── Hermes Agent ──
  if ! command -v hermes &>/dev/null; then
    say "installing Hermes Agent"
    curl -fsSL https://raw.githubusercontent.com/NousResearch/hermes-agent/main/scripts/install.sh | bash
  fi
  mkdir -p "$HOME_DIR/.hermes"
  cp "$REPO_DIR/configs/hermes/SOUL.md" "$HOME_DIR/.hermes/SOUL.md"
  cp -r "$REPO_DIR/configs/hermes/memories" "$HOME_DIR/.hermes/memories"
  cp -r "$REPO_DIR/configs/hermes/scripts" "$HOME_DIR/.hermes/scripts" 2>/dev/null || true
  rm -rf "$HOME_DIR/.hermes/skills"
  cp -r "$REPO_DIR/skills" "$HOME_DIR/.hermes/skills"
  mkdir -p "$HOME_DIR/.hermes/cron"
  cp "$REPO_DIR/configs/hermes/cron-jobs.json" "$HOME_DIR/.hermes/cron/jobs.json" 2>/dev/null || true
  if [[ ! -f "$HOME_DIR/.hermes/config.yaml" ]]; then
    cp "$REPO_DIR/configs/hermes/config.example.yaml" "$HOME_DIR/.hermes/config.yaml"
    warn "hermes config.yaml seeded from template — fill in <FILL_IN> values (see docs/SECRETS.md)"
  else
    warn "existing hermes config.yaml kept — template at configs/hermes/config.example.yaml"
  fi

  # ── llama.cpp + llama-swap ──
  say "llama.cpp + llama-swap"
  mkdir -p "$HOME_DIR/llama.cpp" "$HOME_DIR/models" "$HOME_DIR/.config/llama-swap"
  cp "$REPO_DIR/configs/llama-swap/"*.yaml "$REPO_DIR/configs/llama-swap/"*.jinja "$HOME_DIR/.config/llama-swap/" 2>/dev/null || true

  if [[ ! -x "$HOME_DIR/.local/bin/llama-swap" ]]; then
    say "downloading llama-swap binary"
    local ls_url
    ls_url=$(curl -fsSL https://api.github.com/repos/mostlygeek/llama-swap/releases/latest \
      | grep -o '"browser_download_url": *"[^"]*linux_amd64\.tar\.gz"' | cut -d'"' -f4 | head -1)
    if [[ -n "$ls_url" ]]; then
      curl -fsSL "$ls_url" | tar -xz -C "$HOME_DIR/.local/bin" llama-swap
      chmod +x "$HOME_DIR/.local/bin/llama-swap"
    else
      warn "could not resolve llama-swap release — install manually from github.com/mostlygeek/llama-swap"
    fi
  fi

  if [[ ! -d "$HOME_DIR/llama.cpp/llama-b10092" ]]; then
    warn "llama.cpp b10092 binaries not present — see docs/MODELS.md for download instructions"
  fi
  warn "GGUF models NOT auto-downloaded (~19GB) — see docs/MODELS.md, then start llama-swap"

  # ── OpenCode ──
  mkdir -p "$HOME_DIR/.config/opencode"
  for f in opencode.jsonc tui.json oh-my-openagent.json AGENTS.md package.json; do
    [[ -f "$REPO_DIR/configs/opencode/$f" ]] && cp "$REPO_DIR/configs/opencode/$f" "$HOME_DIR/.config/opencode/$f"
  done
  cp -r "$REPO_DIR/configs/opencode/themes" "$HOME_DIR/.config/opencode/themes" 2>/dev/null || true

  ok "AI stack restored (secrets still needed — docs/SECRETS.md)"
}

# ─────────────────────────────────────────────────────────────────
phase_services() {
  say "Phase 5: systemd user services"
  mkdir -p "$HOME_DIR/.config/systemd/user"
  cp "$REPO_DIR/configs/systemd/user/"*.service "$HOME_DIR/.config/systemd/user/"
  systemctl --user daemon-reload
  for svc in llama-swap hermes-gateway openclaw-gateway; do
    [[ -f "$HOME_DIR/.config/systemd/user/$svc.service" ]] || continue
    systemctl --user enable "$svc" && ok "enabled $svc" || warn "could not enable $svc"
  done
  warn "services enabled but not started — start after secrets are filled in"
}

# ─────────────────────────────────────────────────────────────────
phase_nvim() {
  say "Phase 6: nvim plugins"
  if command -v nvim &>/dev/null; then
    nvim --headless "+Lazy! sync" +qa && ok "plugins synced"
  else
    warn "nvim not installed — skipping"
  fi
}

# ─────────────────────────────────────────────────────────────────
finale() {
  echo
  echo -e "${c_parchment}═══════════════════════════════════════════════════${c_reset}"
  echo -e "${c_blood}  Shield raised. Remaining manual steps:${c_reset}"
  echo    "  1. Fill in secrets — see docs/SECRETS.md"
  echo    "  2. Download GGUF models — see docs/MODELS.md"
  echo    "  3. gh auth login (if not done)"
  echo    "  4. Log out/in (fish shell + KDE config)"
  echo    "  5. systemctl --user start llama-swap hermes-gateway openclaw-gateway"
  echo -e "${c_parchment}  The shield holds. 🎹🦞${c_reset}"
  echo -e "${c_parchment}═══════════════════════════════════════════════════${c_reset}"
}

# ─────────────────────────────────────────────────────────────────
main() {
  local phases=("${@:-all}")
  if [[ "${1:-all}" == "all" ]]; then
    phases=(packages configs browsers system projects ai services nvim)
  fi
  for p in "${phases[@]}"; do
    "phase_$p"
  done
  finale
}

main "$@"
