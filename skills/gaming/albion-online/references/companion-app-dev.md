# AlbionOnline-Companion app dev (SAT fork, Avalonia/C#)

Project: `~/Projects/active/AlbionOnline-Companion` (fork of StatisticsAnalysisTool,
assembly name `AlbionOnlineCompanion`). Sibling Tauri experiment:
`~/Projects/active/AlbionOnline-Translator` (Rust/Svelte, packet-decoding playground —
the production translator lives INSIDE the Companion: `Network/ChatChannelTracker.cs`,
`Network/Handlers/ChatEventHandler.cs`, `ViewModels/TranslatorViewModel.cs`).

## Photon / Protocol18 event parsing pitfalls

- **Typed arrays break `is object[]` (the damage-meter killer, fixed 2026-08-11):**
  this fork's Protocol18Deserializer materializes TYPED arrays — `int[]`, `long[]`,
  `float[]` — for array type codes. C# array covariance only works for reference
  types, so `affectedIds is object[]` is FALSE for `int[]` and the whole
  HealthUpdates batch event (the main combat data source — event code 7) silently
  produced zero updates. Normalize any array via `System.Array`:
  `if (value is Array arr) { copy arr.GetValue(i) into a new object[] }`.
  Applies to ANY event parsing array params, not just health.
- **Damage meter default state:** DamageMeterViewModel.IsDamageMeterActive now
  defaults to true — it was false with a silent-drop guard in both health handlers,
  so the meter looked broken even before the array bug was found.
- Event dispatch + chat events (73/74/75) were verified working while the damage
  meter was dead — when one pipeline works and another doesn't, suspect the EVENT
  CLASS parsing (param types), not the transport.

## Photon / Protocol18 chat decoding

- Chat event codes: ChatMessage=73 (params: 0=channelId i64, 1=sender, 2=text),
  ChatSay=74, ChatWhisper=75. Channel-lifecycle: NewChatChannels=208,
  JoinedChatChannel=209 (params: 0=channelId, 1=chatIndex, 2=channelName),
  LeftChatChannel=210. (Codes are positional in SAT's EventCodes enum — count from
  `Unused = 0`; code comments in the codebase claiming "207" for JoinedChatChannel are stale.)
- **Channel IDs: VERIFIED static map from live capture (Americas server, 2026-08-11):**
  0=Say, 1=Global, 2=Trade, 18=Recruitment, 19=LFG. Faction cities 1856-1868
  (1856 Martlock, 1857 Bridgewatch, 1858 Lymhurst, 1859 Fort Sterling, 1860 Caerleon,
  1868 Thetford). Guild is dynamic (~3517, per session). Verification method: Spanish
  "busco party/team" spam always arrived on 19; "RECLUTA" guild-recruitment spam on 18;
  trade chatter on 2. **Earlier guesses 3=LFG / 4=Recruitment were WRONG** — that's why
  LFG showed "Unknown". These global-channel IDs appear stable (unlike guild), but
  keep the name fallback as belt-and-suspenders.
- **Name fallback (still keep it):** derive channel type from the JoinedChatChannel
  channel NAME when chatIndex is unrecognized — case-insensitive substring match on
  lfg/looking, recruit, trade, faction, guild, alliance, party/group,
  global/english/international, say/local, whisper (implemented as
  `MapChannelName` in ChatChannelTracker.cs). chatIndex numeric values (27-31 style
  maps) are unreliable guesses, and the JoinedChatChannel param parse itself looks
  shaky (observed channelId=27 repeated across different channels, index 405/327 —
  param structure assumption may be off; the verified static map is what saves you).
- Debugging channel mapping in-game: log every join at Information level
  (`Chat channel joined: {id} → {type} ({name}, index:{index})`) and let unknown chat
  messages log their raw channelId (`[{Channel}({ChannelId})] ...`). Have synth run the
  app alongside the game, join the offending channel, and read
  `~/.config/AlbionOnlineCompanion/logs/sat-*.log` — the raw triple (id, index, name)
  settles any remaining mapping question. Don't keep guessing IDs.

## Avalonia 12 on Linux (this fork's stack)

- **Entry point:** `AppBuilder.Start(lifetime)` does not exist — hand-rolling a
  `ClassicDesktopStyleApplicationLifetime` and calling `.Start(lifetime)` fails to
  compile (CS7036). Use `BuildAvaloniaApp().StartWithClassicDesktopLifetime(args,
  ShutdownMode.OnLastWindowClose)`. (This exact breakage blocked the app for a while —
  if "nothing changes when I fix things", BUILD FIRST before suspecting the fix.)
- **Embedded fonts:** put TTFs in `Assets/Fonts/`, included by
  `<AvaloniaResource Include="Assets\**" />`. Resource URI uses the ASSEMBLY NAME, not
  the csproj filename: `avares://AlbionOnlineCompanion/Assets/Fonts/Cinzel.ttf#Cinzel`.
  A whole font FAMILY (weight variants) loads via folder URI:
  `avares://AlbionOnlineCompanion/Assets/Fonts/#EB Garamond`.
  App-wide default font: set `FontFamily` on the `Window` style selector in App.axaml —
  it inherits down the visual tree; class selectors (.header/.title) override per-style.
  **Fonts: Cinzel (headers) + EB Garamond (body) — synth's pairing. He REJECTED Orbitron
  ("i really cant stand the orbitron font", 2026-08-11): for his medieval/fantasy UI,
  classical serif pairings win; don't re-propose geometric sci-fi sans as the body font.**
- **Clipboard (Avalonia 12):** `IClipboard` has NO instance `SetTextAsync` — the
  extension moved to `Avalonia.Input.Platform.ClipboardExtensions.SetTextAsync(clipboard,
  text)` (it was `Avalonia.Input` in v11 — stale samples fail to compile). Get the
  clipboard from `desktop.MainWindow?.Clipboard`.
- **Linux desktop icon:** a `.desktop` file's `Icon=<name>` resolves ONLY from the
  hicolor theme — install PNGs to `~/.local/share/icons/hicolor/<N>x<N>/apps/<name>.png`
  (all sizes: 16/32/48/64/128/256/512), copy the .desktop to
  `~/.local/share/applications/`, then `kbuildsycoca6 --noincremental`. `Exec=` needs a
  real launcher on PATH (wrapper script in `~/.local/bin` pointing at the built binary
  under `bin/Release/net10.0/`).
- **Window/taskbar icon — AVALONIA_APP_ID is a PLACEBO (disproven 2026-08-11):**
  Avalonia 12's Wayland backend NEVER calls `xdg_toplevel.set_app_id` (verified by
  greping the 12.1.1 source — zero occurrences; live KWin dump showed
  `resourceClass=` EMPTY). With no app_id, KWin cannot match any .desktop file and
  the window gets the generic "W" tile forever — no icon install fixes it.
  **Fix: use the X11 backend (Xwayland)** — it sets WM_CLASS from
  `X11PlatformOptions.WmClass` (default: entry assembly name), which KWin matches via
  the .desktop file's `StartupWMClass=`. Program.cs: `builder.UseX11().With(new
  Avalonia.X11PlatformOptions { WmClass = "AlbionOnlineCompanion" })`.
  Verified via KWin script: `resourceClass=AlbionOnlineCompanion,
  desktopFile=albion-online-companion` → custom icon in titlebar AND taskbar.
  `<ApplicationIcon>` (.ico) in the csproj is Windows-only — dead weight on Linux.
- **X11 backend from the Hermes terminal needs XAUTHORITY:** `XOpenDisplay failed`
  crash on launch without it. Export from the user session:
  `export XAUTHORITY=$(cat /proc/$(pgrep -u synth plasmashell | head -1)/environ | tr '\0' '\n' | grep ^XAUTHORITY= | cut -d= -f2)`
  (typically `/run/user/1000/xauth_*`; DISPLAY=:0 comes from Xwayland).
- Build: `dotnet build StatisticsAnalysisTool/StatisticsAnalysisTool.csproj -c Release`
  (dotnet 10 installed, target net10.0).
- **Killing the app:** `pkill -f AlbionOnlineCompanion` matches the agent shell's own
  command line and kills YOUR session (hit 2026-08-11). Use `pkill -x AlbionOnlineCom`
  (comm name truncated to 15 chars) or exact PIDs.
- **Auto-start tracking:** tracking only starts on manual "Start Tracking" click unless
  the VM honors `SettingsService.Instance.Settings.AutoStartTracking` in its ctor —
  without it the Translator looks "broken" when it's really just not capturing.

## Translation pipeline (Common/TranslationService.cs)

- Google free gtx endpoint: `translate.googleapis.com/translate_a/single?client=gtx`.
  **Always `sl=auto`** and read Google's detected source lang from response `root[2]`
  to decide "already in target language". Do NOT detect locally by accented chars —
  most Spanish/Portuguese game chat has no diacritics ("busco party soy healer") and a
  diacritic heuristic classifies it as English and skips it (this was the
  "translator doesn't translate everything" bug).
- gtx response format `[[["seg1","orig",...],["seg2",...]],null,"src_lang"]` —
  **concatenate ALL `root[0]` segments**; taking only `root[0][0]` silently drops
  everything after the first sentence (second silent-translation-loss bug).
- Keep the 200ms rate limiter + `text:target` cache; LFG/Recruitment spam bursts are
  heavy and repeat constantly.
- Type-to-translate compose box (user types a reply, picks target lang, Translate +
  Copy-to-clipboard) is implemented in TranslatorViewModel/TranslatorView — service
  exposes `TranslateAsync(text, explicitTarget)` overload for it.

## Packet capture privileges (Linux)

- **setcap beats root:** `sudo setcap 'cap_net_raw,cap_net_admin=eip' <apphost binary>`
  lets libpcap run as the normal user — no pkexec, no root GUI.
- **Rebuilds WIPE capabilities** (new binary inode). The `~/.local/bin/AlbionOnlineCompanion`
  launcher self-heals: `getcap` check → `pkexec setcap` if missing → exec. Keep that
  pattern; remember to re-apply manually after any out-of-band rebuild.
- **pkexec root GUI on Wayland is a trap:** "Authorization required, but no authorization
  protocol specified" noise, and the window icon reverts to the default Wayland tile
  because root can't see `~/.local/share/icons`. If root launches must work: install
  icons to `/usr/share/icons/hicolor/{48x48,256x256}/apps/` + `/usr/share/pixmaps/` and
  the .desktop to `/usr/share/applications/` so the app-id → desktop-file → icon match
  resolves system-wide.
