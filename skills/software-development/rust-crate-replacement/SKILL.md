---
name: rust-crate-replacement
description: Replace a blocked Rust crate with local code.
---

# Rust Crate Replacement

## When to Use

A Rust project depends on an upstream crate that is:
- License-blocked (upstream license unresolved, blocking monetization)
- Already implemented locally but not wired into the call path

And the project already has own code that could replace it.

## Pattern

1. **Identify the blocked dependency and what it provides.** Read Cargo.toml and grep for `use <crate>::` to find every import site.
2. **Find the own replacement code.** Look for modules that implement the same functionality — often a decoder or parser that exists but isn't connected to the hot path.
3. **Replace the call path, not just the import.** The key change is in the code that *calls* the library — swap the library's parser for the local one. Removing the `use` is a consequence, not the goal.
4. **Verify against a working reference.** If a sibling project uses the same protocol successfully, run both side by side and compare outputs.
5. **Drop the dependency and clean imports.** After the build passes, remove the crate line and all `use` imports. `cargo check` to confirm nothing is orphaned.

## Pitfalls

- Replacing the import without replacing the call path.
- Own code missing edge cases the library handled — audit every variant the caller touches.
- Verification drift — debug against the working reference, not in isolation.
- Stale fingerprint cache — `cargo clean && cargo build` if the binary doesn't reflect the change.

## Cross-Platform Capture

When replacing a platform-specific capture library, offer multiple backends: keep the existing library where it works, add a native backend where it's problematic, and keep a common decode path after capture.

## Pitfalls: Svelte Event Handlers

When wiring `onchange`, `oninput`, or similar handlers to state-mutating functions in Svelte, `onchange={saveSettings(settings)}` passes the **return value** of the call (usually `undefined`) as the handler, not a function. The handler never fires. The correct form is `onchange={() => saveSettings(settings)}` — an arrow that calls the function when the event fires. This bug is invisible at runtime (no error, just nothing saved) and shows up as settings that don't persist across reloads. Audit every `onchange=`/`oninput=` in the template after wiring new UI: if the handler isn't wrapped in `() =>`, it's broken.

## Verified Execution: Albion Translator (2026-08-12)

The translator's sniffer called through `albion_network_lib::PhotonParser` (beemerwt's crate, license unresolved — blocks monetization). The project's own `photon.rs` already implemented the same Protocol18 decode path but wasn't wired into the hot path.

**What changed:**
1. **Call-path swap, not import swap.** In `sniffer.rs`, replaced the `PhotonParser::receive_packet()` + `decoded_packets()` slice loop with a direct `PhotonDecoder::decode(&udp_payload)` call. The `extract_udp_payload` helper stayed (it's pcap-independent byte parsing). The `use albion_network_lib::{...}` imports all went away as a consequence.
2. **LooksLikePhoton fallback added** at the sniffer's packet-filter level: after the pcap BPF filter (ports 5055/5056/5058/4535), if neither endpoint is on a known Albion port, check `payload[0] is 0xF1 or 0xF2 or 0xFE` and pass to decoder anyway. Matches the companion's `LinuxSocketPacketProvider.LooksLikePhoton()`.
3. **Channel map expanded** from hardcoded Say/Guild/Faction IDs to the companion's verified `ChatChannelTracker` map: Recruitment (18), LFG (19), Trade (2), Global (21), Faction (1856-1868), Party (dynamic >10000). Added `Recruitment` variant to the `ChatChannel` enum + Display impl + frontend color + channel filter list.
4. **User translate command added** (`translate_user_text` Tauri command → `TranslationEngine::translate()` → CT2/Google/fallback). Frontend: text input + 19-language dropdown + translate button + inline result.
5. **Dependency dropped**: removed `albion-network-lib` line from `Cargo.toml`. All other deps stayed. `cargo check` clean, `npm run tauri build -- --no-bundle` produced a working binary.

**Key lesson:** When the own decoder already exists, the work is in the sniffer's packet loop, not in the decoder module. Read the sniffer's `while running` body first — that's where the library call lives.

## Support File

`references/<project>-crate-replacement.md` — which crate is blocked, what own code exists, current vs after call path, verified mappings from the working reference project, dependency impact.
