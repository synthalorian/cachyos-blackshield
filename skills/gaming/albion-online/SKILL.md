---
name: albion-online
description: Use for Albion Online builds and item/ability questions.
tags: [albion, gaming, builds, game-data]
triggers:
  - Albion Online build requests or build reviews
  - Questions about Albion weapon/armor/item abilities, names, or stats
  - Checking what an Albion spell or item actually does on the current patch
workflow:
  - Never answer from model memory alone — Albion rebalances constantly and old names/effects linger. Pull live data from github.com/ao-data/ao-bin-dumps (raw.githubusercontent.com, no bot walls).
  - The three files that matter: items.xml (weapon/armor/item definitions + craftspell slot mapping), spells.json (spell mechanics under spells.activespell/passivespell/togglespell), localization.xml (TMX format, display names + EN-US descriptions).
  - Weapon ability mapping: find the weapon's <craftingspelllist> in items.xml. Base weapons reference lower-tier lists (e.g. T4_2H_DUALSWORD references T4_MAIN_SWORD with removespell/addspell overrides). slots="1"=Q, slots="2"=W, slots="3"=E. Armor/head T4+ reference T2 base lists for their actives.
  - Spell descriptions: localization.xml tuid="@SPELLS_<ID>" is the name; descriptions often hide under variant keys like @SPELLS_<ID>_V2_DESC / _REWORK2_DESC — grep for all tuids containing the spell ID.
  - Off-hands and capes have no spell list — their effects are passive attributes on the item (e.g. Facebreaker = pure damage bonuses) or a passive spell (e.g. Demon Cape = PASSIVE_CAPE_DEMON).
  - Give builds as concrete Q/W/E/passive picks + armor actives + food/pots, and say what each swap costs. synth wants tradeoffs named, not encyclopedias.
pitfalls:
  - wiki.albiononline.com is Cloudflare-walled to curl AND browser. albiondatabase.com loads but has sparse weapon coverage. Go straight to ao-bin-dumps.
  - items.json (formatted) has only names/descriptions — no spells. You need items.xml for spell slots.
  - Localization descriptions use $variable$ placeholders — describe the mechanic, don't invent numbers.
  - Spell display names change across patches (e.g. Hunter Jacket's steroid is "Haste", not "Retaliate" as often remembered). Trust the dump over recollection.
  - Build advice is context-flipped: establish solo / duo-with-healer / group / ZvZ FIRST. Solo = survivability (Thetford cape, Iron Will); healer/group = full greed (Demon cape, Facebreaker, Haste/Hamstring). synth will move the goalposts mid-conversation ("im not solo im in a group lol") — re-frame the whole build when context changes, don't just amend one slot.
---

## Client config surgery (Linux native Unity client)

- **PlayerPrefs:** `~/.config/unity3d/Sandbox Interactive GmbH/Albion Online Client/prefs` (XML-ish). Resolution keys: `Screenmanager Resolution Width/Height`, `Screenmanager Resolution Use Native` (1=use desktop res), `Screenmanager Fullscreen mode` (1=borderless). **Unity rewrites prefs on exit — only edit with the game fully closed** (`pgrep -af Albion-Online` first) or the edit is clobbered.
- **Launcher force-feeds resolution:** the Qt launcher passes `-screen-width/-screen-height` from the REAL desktop res every launch, overriding prefs and in-game settings. Counter: append `-screen-width W -screen-height H` to Steam launch options AFTER `%command%` — the launcher forwards extra args and Unity honors the last occurrence. Verify with `pgrep -af Albion-Online` on the running game.
- **Launcher settings:** `~/.config/Sandbox Interactive GmbH/Albion Online Launcher.conf` — graphicsapi/server only, no resolution keys.
- **Steam launch options:** edit via Steam UI while Steam runs; hand-editing `userdata/<id>/config/localconfig.vdf` under a live Steam gets overwritten on exit. Albion appid 761890.
- Permanent flags worth having: `-no-browser -no-launcher +server loginserver.live.albion.zone:5055 +serverenvironment live` — bypasses the QtWeb launcher entirely, killing the forced-resolution problem at the source (and its Chromium CPU bleed).

## Custom resolution / ultrawide FOV

NVIDIA driver on this box rejects ALL custom display modes on Wayland (see `kde-plasma-desktop-customization`). Gamescope recipe — nested res slightly LARGER than the panel in the same aspect, so `-S fit` downscales AND centers:

```
gamemoderun gamescope -w 2880 -h 900 -W 2560 -H 1440 -S fit -f -O HDMI-A-1 -- %command% -screen-width 2880 -screen-height 900
```

(`-w/-h` = what the game sees, `-W/-H` = real panel, `-S fit` = letterbox not stretch, `-f` = true fullscreen, `-O` = pin output — REQUIRED or gamescope grabs the wrong monitor.) **Centering quirk (verified 2026-08): at effective scale 1.0 (e.g. 2560x800 nested into 2560x1440) `-S fit` places the image TOP-LEFT, not centered. Oversizing the nested res (2880x900 → downscaled to a centered 2560x800 strip) engages centering with symmetric bars and gives free supersampling.** Sequence: close game → edit prefs → paste launch options → launch → verify cmdline.

**`-b` (borderless) is broken on KWin Wayland — verified 2026-08:** gamescope floated as an offset undecorated window anchored upper-left with the desktop wallpaper bleeding below it, game rendering fine inside. Use `-f`. Verify success in `Player.log`: `Display 0 'gamescope': 2560x800 (primary device)` + `Desktop is 2560 x 800`. (`Could not fetch DPI` warnings are benign.)

**Resolution veto (verified 2026-08) — the real final boss:** Albion's settings manager re-asserts a supported resolution ~3 seconds after boot, even when Unity was forced to the right mode. Player.log signature: `requesting fullscreen 2560 x 800` at boot, then a SECOND `requesting fullscreen 1280 x 800` lines later, and prefs get rewritten to the fallback. The dropdown is hardcoded-filtered (exotic aspects never listed), so config/args alone cannot win against the runtime veto. Countermeasures in order: wrapper script pinning prefs pre-launch (`~/bin/albion-native.sh`) → `chattr +i` on the prefs file (pinned at 2560x800 + Use Native=1; unlock with `sudo chattr -i` before any manual prefs edits; effectiveness still being evaluated — confirm with synth before relying on it) → beyond that is binary patching (NO — anti-cheat risk, don't go there).

**Current definitive state (2026-08):** the desktop itself runs 2560x800 via EDID override (`drm.edid_firmware=HDMI-A-1:edid/skg-2560x800.bin` in both limine.conf copies; recipe in `kde-plasma-desktop-customization` → `references/nvidia-wayland-custom-modes.md`). With "native" = 2560x800, Unity's native path gives the game the right mode — launch via `~/bin/albion-native.sh %command% -screen-width 2560 -screen-height 800`, no gamescope needed.

**Killing the game:** Unity ignores SIGTERM when hung — `kill -9 <pid>`. NEVER `pkill -f Albion` / `pkill -f game_x64` — the pattern matches the agent shell's own command line and SIGTERMs the agent session (verified). Find PIDs with the bracket trick (`pgrep -af "Albion.Onlin[e]"`, `pgrep -af "gamescop[e]"`) and kill by exact PID.

- Verified data banks
- `references/sword-line-and-bruiser-items.md` — sword Q/W/E spell IDs + current EN-US descriptions, and item IDs/effects for the common bruiser kit. Verified against ao-bin-dumps master, Aug 2026.
- `templates/albion-native-launcher.sh` — prefs-pinning Steam launch wrapper (copy to ~/bin, chmod +x).
