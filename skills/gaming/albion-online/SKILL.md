---
name: albion-online
description: Use for Albion Online builds, item/ability questions, server regions, and community lookups.
tags: [albion, gaming, builds, game-data]
triggers:
  - Albion Online build requests or build reviews
  - Questions about Albion weapon/armor/item abilities, names, or stats
  - Checking what an Albion spell or item actually does on the current patch
  - Finding Albion regional servers, faction communities, guilds, LFG groups, or community Discords
  - Working on the AlbionOnline-Companion app (chat translator, channel mapping, icons, fonts, Avalonia build)
workflow:
  - Never answer from model memory alone — Albion rebalances constantly and old names/effects linger. Pull live data from github.com/ao-data/ao-bin-dumps (raw.githubusercontent.com, no bot walls).
  - The three files that matter: items.xml (weapon/armor/item definitions + craftspell slot mapping), spells.json (spell mechanics under spells.activespell/passivespell/togglespell), localization.xml (TMX format, display names + EN-US descriptions).
  - Weapon ability mapping: find the weapon's <craftingspelllist> in items.xml. Base weapons reference lower-tier lists (e.g. T4_2H_DUALSWORD references T4_MAIN_SWORD with removespell/addspell overrides). slots="1"=Q, slots="2"=W, slots="3"=E. Armor/head T4+ reference T2 base lists for their actives.
  - High-tier weapons chain-reference downward (T8 → T6 → T4 base) via `<craftingspelllist reference="..."/>` with NO inline spells. Follow the reference attr until you hit a list with actual <craftspell> entries, then apply each hop's <removespell>/<craftspell> overrides on the way back up. Don't expect the T8 block to contain spells itself.
  - Spell descriptions: localization.xml tuid="@SPELLS_<ID>" is the name; descriptions often hide under variant keys like @SPELLS_<ID>_V2_DESC / _REWORK2_DESC — grep for all tuids containing the spell ID. When a spell ID has NO tuid at all, it's been renamed — read its `@namelocatag`/`@descriptionlocatag` in spells.json and look THAT tuid up instead (e.g. CROSSSTEP_ROUNDHOUSE displays as "Fleet Footwork" via @SPELLS_CROSSSTEP_MULTI; PASSIVE_KNUCKLE_BRAWLER → "Fatal Fury" via @SPELLS_PASSIVE_KNUCKLE_FURY). Match tuids with a tolerant regex (`<tu tuid="...">.*?<seg>` with re.S) and skip non-EN-US `xml:lang` variants.
  - Off-hands and capes have no spell list — their effects are passive attributes on the item (e.g. Facebreaker = pure damage bonuses) or a passive spell (e.g. Demon Cape = PASSIVE_CAPE_DEMON).
  - Give builds as concrete Q/W/E/passive picks + armor actives + food/pots, and say what each swap costs. synth wants tradeoffs named, not encyclopedias.
pitfalls:
  - wiki.albiononline.com is Cloudflare-walled to curl AND browser. albiondatabase.com loads but has sparse weapon coverage. Go straight to ao-bin-dumps.
  - items.json (formatted) has only names/descriptions — no spells. You need items.xml for spell slots.
  - Localization descriptions use $variable$ placeholders — describe the mechanic, don't invent numbers.
  - Spell display names change across patches (e.g. Hunter Jacket's steroid is "Haste", not "Retaliate" as often remembered). Trust the dump over recollection.
  - Build advice is context-flipped: establish solo / duo-with-healer / group / ZvZ FIRST. Solo = survivability (Thetford cape, Iron Will); healer/group = full greed (Demon cape, Facebreaker, Haste/Hamstring). synth will move the goalposts mid-conversation ("im not solo im in a group lol") — re-frame the whole build when context changes, don't just amend one slot.
  - Mid-game material lists are arithmetic, not research — when synth pastes terse crafting/shopping lists mid-session (e.g. "30 t1 logs 30 t3 planks x 5"), multiply and answer instantly; do NOT detour into ao-bin-dumps recipe verification. He corrected this directly with "i just need math here". The never-answer-from-memory rule covers builds/items/abilities, not shopping-list math. When synth corrects a number mid-calculation ("im looking right at it", "for each", "36*"), accept the correction immediately and propagate it through all downstream math — flag that the original number came from stale memory vs. in-game confirmation, but don't re-open the corrected number unless the user does. Correct behavior: use the new number, redo affected totals, offer updated result, move on.
  - Cooking batch math: use the recipe's batch inputs and `amountcrafted`; do not confuse input units with output food count. Animal names do NOT map intuitively to item tiers (goat is T4; mutton is T6), so use `references/cooking-recipes.md` for verified common meal ratios before doing split/max-output calculations. Treat quick followups from that math (station location, leftover counts, conversion ratio) as direct-answer tasks — no open-ended research spiral, and if synth says "stop", stop immediately.
  - Island/player-building management (demolish blockers, renovation panel) — see references/island-buildings.md.
  - Channeled crafting stations (Cooking, Butchering) require the player to be at the station — running duplicate stations across multiple islands is only useful for multi-alt setups. Single-player island chains should consolidate channeled stations on one island and use the others for passive ingredient production (pastures/farms).
  - Island production ratio math: when calculating pasture/farm splits for a recipe, work from the full recipe (all ingredients × batch size) and the per-animal feed cost (goose=9 cabbage/1 egg, pig=9 corn/X pork per butcher output). Factor in butcher throughput as the pig cap (1 butcher ≈ 2 pig pastures based on island 1 throughput). Never assume recipe numbers from memory — confirm each ingredient quantity from the in-game recipe window before finalizing ratios.
  - For island production planning, see references/island-production-calculator.md for the pork omelette template (costs, recipe, feed math, station constraints, layout template).

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

**Current definitive state (2026-08-03):** the desktop runs a forged EDID native mode via `drm.edid_firmware=HDMI-A-1:edid/skg-2560x1080.bin` (limine cmdline; forge + install/revert scripts in the public `synthalorian/this-is-the-wide` repo). 2560x1080 is 21:9 — on Albion's supported-aspect whitelist, so the settings manager HOLDS it past load (verified: `Desktop is 2560 x 1080 @ 120 Hz`, `requesting fullscreen 2560 x 1080`, no second veto line). 32:10 (2560x800) was vetoed mid-load — dead end, don't retry. No gamescope, no prefs pinning needed.

**Kernel updates drop the forge (hit 2026-08-05 on kernel 7.1.6):** limine-entry-tool regenerates the active boot entries on every kernel bump, silently dropping `drm.edid_firmware` → surprise 1440p. Re-apply with `this-is-the-wide/scripts/install.sh` (idempotent, active-entries-only) + reboot. Details in the repo README warnings.

**Killing the game:** Unity ignores SIGTERM when hung — `kill -9 <pid>`. NEVER `pkill -f Albion` / `pkill -f game_x64` — the pattern matches the agent shell's own command line and SIGTERMs the agent session (verified). Find PIDs with the bracket trick (`pgrep -af "Albion.Onlin[e]"`, `pgrep -af "gamescop[e]"`) and kill by exact PID.

- Verified data banks
- `references/sword-line-and-bruiser-items.md` — sword Q/W/E spell IDs + current EN-US descriptions, and item IDs/effects for the common bruiser kit. Verified against ao-bin-dumps master, Aug 2026.
- `references/knuckles-line-and-maulers-kit.md` — knuckles Q/W/E + Ursine Maulers (`T8_2H_KNUCKLES_KEEPER`, E = Hundred Striking Fists) spell IDs, descriptions, and the open-world PvP kit. Verified Aug 2026.
- `references/server-and-community-links.md` — regional server naming (Americas/West, Asia/East, Europe), public Discord invite verification, and live-checked general/LFG/Caerleon community links. Verified Aug 2026.
- `references/cooking-recipes.md` — verified T4 goat cooking ratios, butter/bread intermediates, and the batch-count pattern for split/max-output food math. Verified Aug 2026.
- `references/companion-app-dev.md` — AlbionOnline-Companion app dev: Photon/Protocol18 chat decoding (channel IDs are DYNAMIC per session — map via JoinedChatChannel channel-name fallback, not hardcoded IDs), Avalonia 12 Linux entry-point/font/icon wiring. Added Aug 2026.
- `templates/albion-native-launcher.sh` — prefs-pinning Steam launch wrapper (copy to ~/bin, chmod +x).
