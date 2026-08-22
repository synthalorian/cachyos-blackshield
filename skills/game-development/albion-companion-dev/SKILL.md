---
name: albion-companion-dev
description: Use for AlbionOnline-Companion app dev (Avalonia+Photon).
---

# AlbionOnline-Companion Development

Development playbook for `~/Projects/active/AlbionOnline-Companion` — a cross-platform fork of StatisticsAnalysisTool (Avalonia 12 / .NET 10) that sniffs Albion Online Photon UDP traffic and drives dashboards (fame, damage meter, chat display, loot, etc.). NOTE: the chat translator was REMOVED from this app 2026-08-11 (commit 40c52d4) — chat tab is display-only now (`ChatViewModel`/`ChatView`).

There is also `~/Projects/active/AlbionOnline-Translator` — a Tauri/Rust app (100% synth-owned code, not a fork). **PIVOTED 2026-08-17: now FREE and open source under Apache-2.0, repo PUBLIC.** The Lemon Squeezy paywall, trial clock, `license.rs` backend, and `LicenseGate.svelte` UI were all ripped out (`def1550`, released as v0.2.0 `d99c2d8`). The "Monetization split" section below is preserved as history — item 2's paid-product plan is SUPERSEDED.

## Monetization split (decided 2026-08-11; SUPERSEDED 2026-08-17 — Translator went free/Apache-2.0, paywall removed, see above)

Synth needs revenue; the decision, in order considered and settled:

1. **Companion stays FREE and GPLv3.** It is a fork of Triky313's StatisticsAnalysisTool (GPLv3) — any binary distribution must offer source to recipients, and any paywall coded into it is legally bypassable by recompilation (a toll booth, not a vault). A full rewrite to escape GPL was estimated 4–8 weeks and REJECTED: retyping GPL logic stays legally derivative without a true clean-room (spec-writer ≠ implementer), and it delays revenue.
2. **Translator (Tauri/Rust, `~/Projects/active/AlbionOnline-Translator`) is the paid product** — $9.99 one-time, Lemon Squeezy license keys, repo PRIVATE as of 2026-08-11. 7-day full trial → hard lock. Backend licensing (`src-tauri/src/license.rs` — trial clock, activate/validate/deactivate, 7-day offline grace, 24h revalidation) AND frontend paywall UI (`src/lib/LicenseGate.svelte` — trial banner + lock overlay + key entry) are both DONE (commit 96de600); chat-message forwarding is gated backend-side. Remaining TODO: synth creates the Lemon Squeezy product and pastes the real checkout URL into `BUY_URL` (`REPLACE_ME` placeholder); full setup checklist in the app's `docs/MONETIZATION.md`.
3. **Translator features stripped from the free Companion** (DONE 2026-08-11, commit 40c52d4 — deleted TranslatorView/ViewModel + TranslationService; chat tab renamed to display-only ChatViewModel/ChatView) so the paid app has no free equivalent (synth's explicit reasoning: "why would you pay when the other is free"). Coupling lesson: TranslatorViewModel doubled as the chat CAPTURE/DISPLAY VM — stripping translation required recreating the chat UI under the new name (handlers, NetworkManager.RegisterViewModels, MainWindow DataTemplate, Converters all retargeted), not just deleting files. Repo grep for `translat` is zero; remaining `google` hits are unrelated Photon protocol enums (`InAppPurchaseConfirmedGooglePlay`) — keep those.
4. **Dependency license blocker → resolved by REPLACEMENT (decided 2026-08-11):** the Translator built on `beemerwt/albion-network-lib`, which has NO LICENSE file (license request posted as issue #1 regardless). synth chose to replace it with his own decode layer (`photon_net.rs`): the app imports only 6 symbols (`DecodedPacket, ExtractedPacket, HostFilter, PhotonParser, PhotonParserConfig, extract_udp_payload`) — UDP extract + host filter are trivial, the Photon envelope parser is the only real work (~400-600 lines), Protocol18/chat mapping was already synth's own `photon.rs`. Est. 2-4 days. Method: write from wire-probe ground truth (pitfall 16), use the third-party lib as a dev-time test ORACLE (both parsers on the same capture, diff chat output), then drop the dep entirely. Do not ship commercially until the dep is gone or MIT/Apache lands.
5. **Ads were considered and rejected** for this niche desktop tool (no legit desktop ad networks; ~$120/mo at 1k DAU vs 12 one-time sales). See the `desktop-app-monetization` skill for the full reasoning pattern.

## Build & Run (do this every time)

```bash
cd ~/Projects/active/AlbionOnline-Companion
dotnet build StatisticsAnalysisTool/StatisticsAnalysisTool.csproj -c Release
sudo setcap 'cap_net_raw,cap_net_admin=eip' StatisticsAnalysisTool/bin/Release/net10.0/AlbionOnlineCompanion  # MANDATORY after every build
```

**Rebuilds wipe file capabilities.** Without setcap, packet capture silently requires root. The launcher `~/.local/bin/AlbionOnlineCompanion` self-heals via pkexec getcap check — keep it that way.

Launch from Hermes shell (bash, not fish) with the user session env:

```bash
export WAYLAND_DISPLAY=wayland-0 DISPLAY=:0 XDG_RUNTIME_DIR=/run/user/1000 \
  DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus \
  XAUTHORITY=$(cat /proc/$(pgrep -u synth plasmashell | head -1)/environ | tr '\0' '\n' | grep ^XAUTHORITY= | cut -d= -f2)
~/.local/bin/AlbionOnlineCompanion
```

X11 backend needs XAUTHORITY; grab it from plasmashell's environ (filename is random per boot, e.g. `/run/user/1000/xauth_XXXXXX`). Logs: `~/.config/AlbionOnlineCompanion/logs/sat-YYYYMMDD.log`. Kill with `pkill -x AlbionOnlineCom` (comm name is truncated to 15 chars — NEVER `pkill -f AlbionOnlineCompanion`, it matches your own shell's cmdline and SIGTERMs you).

## Translator app build & run (Tauri/Rust)

```bash
cd ~/Projects/active/AlbionOnline-Translator
npm run tauri build -- --no-bundle   # NEVER plain cargo build --release: it embeds
                                     # ZERO frontend assets → webview shows
                                     # "Could not connect to localhost: Connection refused"
sudo setcap 'cap_net_raw,cap_net_admin=eip' src-tauri/target/release/albion-translator  # after EVERY build
WEBKIT_DISABLE_DMABUF_RENDERER=1 ./src-tauri/target/release/albion-translator
```

**Installing to `~/.local/bin/albion-translator` (learned 2026-08-17):**
- **Kill the running app FIRST** — overwriting a running binary fails with `cp: cannot create regular file ... Text file busy`.
- **`pkill -x albion-translator` does NOT work** — the name is 16 chars, over the 15-char comm limit, and pkill matches zero processes (same trap as the Companion). Kill by PID from `pgrep -f` output instead.
- **`cp` does NOT preserve file capabilities** — re-run `sudo setcap 'cap_net_raw,cap_net_admin=eip' ~/.local/bin/albion-translator` after every copy, or packet capture silently dies.
- **Stale-binary masquerade:** if the UI shows features already removed from source (e.g. the old trial banner after the paywall rip-out), check `ls -la ~/.local/bin/albion-translator` against `git log` BEFORE touching code — the running/installed copy may simply predate the change. Verify what the build actually embedded with `grep -ri trial dist/assets/*.js` (bundled frontend) rather than trusting the running window.

Headless end-to-end harness: `cargo build --release --example live_pipeline` (+ setcap the example binary) runs capture→decode→translate→print with no UI — use it to prove backend bugs before touching the frontend. `examples/mpsc_repro.rs` is the 30-line proof that a blocking `pcap next_packet()` loop inside `tokio::spawn` starves mpsc receivers — the capture loop MUST use `tokio::task::spawn_blocking` + `blocking_send` (see `tokio-blocking-loop-starvation` skill; this bug made translation silently dead from birth until 2026-08-15). Network calls in the translation worker need explicit timeouts (reqwest default = hang forever).

## Pitfalls (hard-won)

17. **Photon Event chat on UDP IS live-decodable (verified 2026-08-14); don't let the old "UDP has no chat" claim block debugging.** The Translator app's standalone `src-tauri/src/photon.rs` decodes Photon Events directly from UDP packets on ports 5055/5056/4535 — ChatMessage=73, ChatSay=74, ChatWhisper=75 — and was verified decoding live chat on Americas servers on 2026-08-14 (channel_ids 2, 18/Recruitment, 19/LFG all surfaced with `Event code: 73` logged; NOTE 2026-08-15: id 2's label is contested — type-enum table says Trade, in-game content says English language channel, see references/chat-channel-roster-protocol.md). The old companion-app claim that "UDP carries no chat" was a confusion: some library paths saw chat delivered as OperationResponse 43, and a library bug that dropped OperationResponses made it *look* like UDP had nothing. Two chat paths exist: (A) Photon Events on UDP (what `photon.rs` targets — VERIFIED WORKING), (B) Steam overlay WebSocket on TCP localhost:57343 (Steam IPC, separate from UDP game protocol). Before debugging "no chat" for more than 10 minutes, confirm which path your code targets and whether chat is actually happening in-game. If your Photon-Event UDP decoder shows zero `Event code: 73` lines while chat is visible in-game, the bug is in the decoder (event code extraction, param source, or channel_map) — not in the wire. See `references/albion-translator-debugging.md` for the updated two-path checklist.
   `builder.UseX11().With(new X11PlatformOptions { WmClass = "AlbionOnlineCompanion" })`
   KWin then matches window → desktop file → icon. Verify with `scripts/kwin-dump-windows.js` (see below). Icons + desktop file installed BOTH user-wide (`~/.local/share/...`) and system-wide (`/usr/share/icons/hicolor`, `/usr/share/pixmaps`, `/usr/share/applications`) so root/pkexec launches resolve too — but prefer setcap over root entirely.
2. **Photon deserializer materializes TYPED arrays** (`int[]`, `long[]`, `float[]`). `value is object[]` FAILS for value-type arrays (no covariance) and silently empties batch events — this killed the damage meter. Normalize via `System.Array` (see `HealthUpdatesEvent.AsObjectArray`).
3. **Duplicate damage**: every health tick arrives twice — single `HealthUpdate` (event 6) AND inside `HealthUpdates` batch (event 7). Dedupe by `causer:affected:timestamp:change` HashSet before counting.
4. **Late name resolution**: damage entries are created on first tick, but `NewCharacter` (name) may arrive after. Keep re-resolving placeholder names (`Unknown_*`/`Player_*`) on each update.
5. **Sort dropdowns need explicit refresh**: changing sort option must recompute every entry's display string AND re-rank — existing entries don't update themselves.
6. **[historical — translator removed from this app 2026-08-11, commit 40c52d4; applies to the Translator app now] Google Translate gtx endpoint: use `sl=auto`**, never local language heuristics — accent-free Spanish/Portuguese ("busco party soy healer") defeats accent detection. Use the free endpoint `https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl={target}&dt=t&q={encoded}` (no API key, no billing). Response is `[[[translated, original, null, null, offset], ...], null, "detected_lang", ...]` — concat ALL segments in `root[0]` (multi-sentence messages otherwise truncate) and read detected lang from `root[2]`. Set User-Agent header. Rate-limit ~200ms. Cache by `text:target`. Full details (git recovery technique, edge cases, Rust sketch) in `references/free-google-translate-endpoint.md`.
7. **Avalonia 12 clipboard**: `Avalonia.Input.Platform.ClipboardExtensions.SetTextAsync(clipboard, text)` — NOT `IClipboard.SetTextAsync` (doesn't exist) and NOT `Avalonia.Input.ClipboardExtensions` (wrong namespace).
8. **Gates that silently drop data**: `IsDamageMeterActive` defaulted false and both damage handlers silently returned — feature appeared dead. Default such feature gates ON and log first-N dropped/accepted events at Information level during bring-up.
9. **Synth's repro style: instrument + live repro.** Add Information-level logging of raw values, have synth perform one action in-game (game is usually already running), read the log, THEN fix from ground truth. This beat guessing every time this session (channel IDs, fame categories, damage duplicates).
10. **The two-ID-space trap**: `JoinedChatChannel` (207) param 0 is a channel-**TYPE enum** (2=Recruitment, 3=LFG, 5=Global, 8=Trade, 24=Guild, 25=Alliance); param 1 is the **runtime channel ID** that `ChatMessage` (73) actually addresses. `ChatChannelTracker.JoinChannel` keyed its dict by param 0, so joined channels NEVER matched message lookups — every non-hardcoded channel rendered `Unknown` (party chat included). Any ID-keyed tracker: verify which ID space the consumer reads before choosing the key. Party/guild/alliance runtime IDs are high dynamic per-session numbers (e.g. 34125) — resolvable ONLY via the join event, never hardcodable.
11. **Launching the app from Hermes**: `nohup ... &` wrappers are rejected by the terminal tool — use `background=true` + `exec ~/.local/bin/AlbionOnlineCompanion` instead.
12. **Protocol dump comments are NOT ground truth.** The albion-network-lib layouts pasted into `EventCodes.cs` comments were wrong twice in one session: `PartyPlayerJoined` param 0 is the PARTY id (constant across ALL members — every roster member reported the same id), NOT a member ObjectId, and `JoinedChatChannel` sends NO name param at all (raw dump: `[0:typeEnum] [1:runtimeId] [252:207]` only). Before wiring any handler to an assumed layout, add a first-N RAW full-param dump (pattern: `PartyEventParams.DumpOnce`) and verify against live capture.
13. **Never classify chat channels from message content alone.** "94 = Faction" was a false positive — typeEnum 27 is the zone-local channel and gets a FRESH runtime id per cluster (94, 436, 182, 307, 57, 471, 1479 all seen in one session; faction trash talk had simply happened in zone say). Classify by correlating `JoinedChatChannel` typeEnum→runtimeId joins; treat zone-local/party/guild/alliance runtime ids as dynamic. Static id tables are only safe for the stable server-wide channels (0,1,2,18,19,21). The old 1856–1868 per-city faction table was removed as unverified.
14. **[historical — translator removed from this app 2026-08-11; applies to the Translator app] No italics for body/translation text.** synth flagged the translator's translated line (`FontStyle="Italic"`, size 13) as hard to read; it's regular SemiBold 14 now. Italic at small sizes on dark neon themes is a legibility trap — use weight/size/color for emphasis instead.
15. **Theme defaults are a product decision, and lookup fallbacks must be case-insensitive.** Default theme changed synthwave84 → plain Dark (Mocha) after a friend's feedback (not everyone likes neon; synthwave stays opt-in in Settings). Latent bug found in passing: `ThemeCatalog.GetByName` was case-sensitive, so the legacy persisted `"Dark"` silently fell back to synthwave84. Any name-keyed catalog that reads persisted strings: compare case-insensitively.
16. **Wire-probe first when writing your own protocol parser.** Before writing any Photon/envelope decode code, capture and hex-dump the raw wire yourself (pattern: `src-tauri/src/bin/wire_probe.rs` in the Translator repo — pcap on ports 5055/5056/4535, parse Ethernet/SLL → IPv4 → UDP offsets manually, hex-dump first 96 bytes of payloads; `sudo setcap 'cap_net_raw,cap_net_admin=eip'` the probe binary so it runs unprivileged). Layout comments in ANY codebase — including your own earlier attempts — are suspect until matched against a live dump (pitfall 12). Then verify the new parser against the reference implementation as a test ORACLE: run both on the same live capture, diff decoded chat output; when they agree, drop the third-party dep. This gives legal cleanliness (implementing wire-format FACTS from your own captures, not porting expression) and empirical correctness in one move.

## Verified protocol facts

Live-verified 2026-08-11 (Americas server) — see `references/albion-protocol-verified.md` for the full table: chat channel IDs (18=Recruitment, 19=LFG, 2=Trade, 21=Global — hardcoded guesses 3/4 were WRONG), the JoinedChatChannel two-ID-space trap + verified type enum (27 = zone-local with per-cluster dynamic ids), party event layouts (corrected on 2nd pass), JoinResponse fields, cluster index → name via ao-bin-dumps world.json, island format `@ISLAND@guid`.

## Player names in the damage meter

Party events carry NAMES ONLY, not meter-usable ids (verified 2nd pass 2026-08-11): `PartyPlayerJoined` (233) fires once per member on join/re-zone with `0=PARTY id (constant!), 1=member GUID byte[16], 2=member NAME` — feed `PartyTracker`, NOT EntityTracker. `PartyJoined` (231)'s name array often arrives EMPTY — never clear the roster on an empty payload. `PartyPlayerLeft` (235)/PartyLeaderChanged param 0 is also the party id; the departing member is unidentifiable. Meter names therefore resolve via NewCharacter + the late-resolution retry (pitfall 4), which works. Implemented in `Network/Events/PartyEvents.cs`, `Network/Handlers/PartyEventHandler.cs`, `Network/PartyTracker.cs` (registered in NetworkManager). Event code numbers = enum ordinal in `EventCodes.cs` — compute programmatically, don't count lines by eye.

## Verifying window/app-id state with KWin

`scripts/kwin-dump-windows.js` dumps every window's caption/resourceClass/desktopFile to the kwin journal:

```bash
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.loadScript scripts/kwin-dump-windows.js dump
qdbus6 org.kde.KWin /Scripting org.kde.kwin.Scripting.start
journalctl -b _COMM=kwin_wayland --no-pager --since "-5s" | grep DUMPWIN
```

Correct state for this app: `resourceClass=AlbionOnlineCompanion desktopFile=albion-online-companion`. If resourceClass is empty, the icon chain is broken.

## Support files

- `references/albion-protocol-verified.md` — live-verified Albion protocol facts (channel IDs, JoinResponse params, cluster names, event duplication)
- `references/free-google-translate-endpoint.md` — the free Google Translate gtx endpoint (no API key), response parsing, edge cases, git recovery technique
- `references/albion-translator-debugging.md` — sniffer/packet capture debugging workflow (UDP ≠ chat, link types, library bugs, CIDR vs port filtering). **UPDATED 2026-08-14:** rewritten with two-path model (Photon Events on UDP = verified working; Steam WebSocket = separate path), log-driven verification technique, the two racing conditions that cause Unknown channels, tracing noise management, and verified findings from the 08-14 session (26+ chat messages decoded, channel_map populated too late, 114K Move events drowning signal).
- `references/chat-channel-roster-protocol.md` — NEW 2026-08-15. Event 206 roster wire format DECODED (param 0 = LE hex type-enum string, param 1 = runtime-id array; fires at login/zone-change/party-join), full verified 207 type-enum↔runtime-id set from a real login, outbound op layouts (189 SendChatMessage / 194 Say / 191 JoinChatChannel), own-messages echo as event 73 (no optimistic echo needed), 74 ChatSay structure incl. system localization-key variants, retransmit duplicate warning, and the OPEN runtime-2 = Trade-vs-English conflict.
- `references/reference-implementation-audit.md` — NEW 2026-08-14. Technique for auditing your decoder against a known-working reference implementation. Covers how to read the reference's channel mapping, filter, and event handling code; identify gaps (defaults, naming, missing infrastructure, timing); and port fixes. Includes the specific gaps found in this session: Unknown→Say default, "Say"→"Local" display name, missing CIDR filtering, channel_map timing.
- `scripts/kwin-dump-windows.js` — KWin script: dump all windows' app_id/class/desktopFile
