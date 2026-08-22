# tauri-action Release Pipeline — Condensed Pitfall Bank

Session detail from shipping Albion Translator v0.2.0 (Tauri 2 + SvelteKit, tag-triggered `tauri-apps/tauri-action@v0` matrix: ubuntu-22.04 / windows-latest / macos-latest ×2 archs). Took 4 CI iterations; each error below is verbatim-verified and maps to a one-line fix.

## Iteration log

| # | Failure | Error (verbatim-ish) | Fix |
|---|---------|----------------------|-----|
| 1 | Release creation denied, all OSes | `Resource not accessible by integration` on create-a-release | Top-level `permissions: contents: write` in the workflow |
| 2 | Windows link | `LINK : fatal error LNK1181: cannot open input file 'wpcap.lib'` | Npcap SDK step (see below) |
| 3 | Windows link (after wpcap fixed) | `error LNK2038: mismatch detected for 'RuntimeLibrary': value 'MT_StaticRelease' doesn't match value 'MD_DynamicRelease'` from `libct2rs` objects | `RUSTFLAGS: -Ctarget-feature=+crt-static` on the Windows matrix entry only |
| 4 | macOS x64 asset missing despite green job | both macOS jobs uploaded `..._aarch64.dmg`; second overwrote the first | tauri-action ignores matrix `target` — must pass `args: --target ${{ matrix.target }} ...` |
| 4 | No `latest.json` on the draft | `Signature not found for the updater JSON. Skipping upload...` | `"createUpdaterArtifacts": true` in `bundle` (tauri.conf.json) + signing env wired |
| 4 | macOS x64 build | `clang++: error: unsupported option '-mavx512f' for target 'x86_64-apple-macosx'` (also `-mavx512vl/-cd/-bw/-dq`) from ct2rs/CTranslate2 CMake | No env fix. Drop Intel target, patch CTranslate2 CMake, or make ct2rs an optional feature. We dropped it — Apple Silicon covers 2020+. |
| 5 | No macOS updater artifacts even with `createUpdaterArtifacts: true` and `--bundles dmg,updater` | `Warn The bundler was configured to create updater artifacts but no updater-enabled targets were built. Please enable one of these targets: app, appimage, msi, nsis` | dmg is NOT updater-enabled and the `updater` pseudo-target does nothing on its own → `--bundles app,dmg` (produces `app.tar.gz` + `.sig`) |
| 6 | `latest.json` missing `darwin-aarch64` + mac `.app.tar.gz` assets gone from the release despite a green mac job | Matrix race: each job regenerates latest.json when IT finishes — last writer wins, and later-finishing jobs clobbered the mac updater assets | Re-run ONLY the mac job solo: `gh run rerun <run-id> --job <mac-job-id>`. Finishing alone, it merges the sigs already on the release into a complete manifest. Long-term: separate publish job with `needs: build` |

## Npcap SDK step (Windows, for `pcap` crate)

```yaml
- name: Install Npcap SDK (Windows)
  if: runner.os == 'Windows'
  shell: pwsh
  run: |
    Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-sdk-1.13.zip" -OutFile "npcap-sdk.zip"
    Expand-Archive npcap-sdk.zip -DestinationPath C:\npcap-sdk
    "LIB=C:\npcap-sdk\Lib\x64;$env:LIB" | Out-File -FilePath $env:GITHUB_ENV -Append
```

## Updater signing (one-time, per app)

```bash
npx tauri signer generate -w ~/.tauri/<app>.key --password ""
# .pub contents → plugins.updater.pubkey in tauri.conf.json
gh secret set TAURI_SIGNING_PRIVATE_KEY < ~/.tauri/<app>.key
```

Workflow env on the tauri-action step: `TAURI_SIGNING_PRIVATE_KEY` + `TAURI_SIGNING_PRIVATE_KEY_PASSWORD: ""`. Back up the private key outside the repo — losing it kills future signed updates.

## Operational gotchas

- **Lightweight tags don't ride `--follow-tags`** (annotated only). `git push origin vX` explicitly, else the tag workflow never fires.
- **Re-tagging:** user denies force-push on tags; do explicit `git tag -d vX` → `git push origin :refs/tags/vX` → `git tag vX` → `git push origin vX`.
- **Draft assets persist across re-runs** and tauri-action deletes/re-uploads same-named assets — after dropping/renaming a matrix entry, check the draft for stale assets.
- **Matrix jobs race on `latest.json`** — after the run, download it and verify every shipped platform is listed before publishing the draft.
- `gh run view <id> --log-failed` only works after the whole run completes; for a single job still running use `gh api repos/<o>/<r>/actions/jobs/<jobid>/logs`.
- GitHub's job-rerun endpoint 503s transiently (`No server is currently available`) — retry with ~45s backoff; it succeeded on the second attempt.
