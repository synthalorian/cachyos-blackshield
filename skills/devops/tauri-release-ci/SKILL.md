---
name: tauri-release-ci
description: Use when cutting a Tauri app release via GitHub Actions.
tags:
  - tauri
  - github-actions
  - release
  - tauri-action
  - auto-updater
  - ci-cd
triggers:
  - "Tauri release"
  - "tauri-action"
  - "cut a release"
  - "update releases"
  - "TAURI_SIGNING_PRIVATE_KEY"
  - "tauri signer generate"
  - "latest.json updater"
  - "release.yml Tauri"
---

# Tauri Release CI (GitHub Actions + tauri-action)

Class: shipping Tauri desktop app releases through a tag-triggered GitHub Actions workflow using `tauri-apps/tauri-action@v0`.

A known-good 3-target workflow (Linux deb/rpm/AppImage, Windows NSIS, macOS dmg ARM) is in `templates/release.yml` — copy and adapt. It includes the duplicate-draft-race fix (create-release pre-job), explicit `--target`, and per-OS bundle args.

## First-release setup checklist

1. **Workflow token permissions — add `permissions: contents: write`.**
   **PITFALL:** Default `GITHUB_TOKEN` is read-only on many repos (especially freshly created or visibility-flipped ones). Matrix jobs compile fine, then fail at the release step with `Resource not accessible by integration` (create-a-release 403). If all prior releases were created manually, the workflow never exercised release creation and this only surfaces on the first CI run. Fix:
   ```yaml
   permissions:
     contents: write
   ```

2. **Windows + `pcap` crate → `LNK1181: cannot open input file 'wpcap.lib'`.**
   The `pcap` crate links the Npcap SDK import library, absent from runners. Add BEFORE the build step:
   ```yaml
   - name: Install Npcap SDK (Windows)
     if: runner.os == 'Windows'
     shell: pwsh
     run: |
       Invoke-WebRequest -Uri "https://npcap.com/dist/npcap-sdk-1.13.zip" -OutFile "npcap-sdk.zip"
       Expand-Archive npcap-sdk.zip -DestinationPath C:\npcap-sdk
       "LIB=C:\npcap-sdk\Lib\x64;$env:LIB" | Out-File -FilePath $env:GITHUB_ENV -Append
       "NPCAP_SDK_PATH=C:\npcap-sdk" | Out-File -FilePath $env:GITHUB_ENV -Append
   ```
   (End users also need the Npcap runtime for capture to work — README note for sniffer apps.)

3. **Updater signing — do this FIRST if `plugins.updater.active: true`:**
   ```bash
   npx tauri signer generate -w ~/.tauri/<app>.key --password ""
   gh secret set TAURI_SIGNING_PRIVATE_KEY < ~/.tauri/<app>.key
   ```
   Paste the `.key.pub` contents into `tauri.conf.json` → `plugins.updater.pubkey`.
   **PITFALL:** `updater.active: true` with empty `pubkey` and no signing secret = silently dead auto-updater. Builds succeed, releases publish, but no signed `latest.json` is ever generated, so in-app updates never work. Back up the private key — losing it permanently breaks update signing for the app.
   **PITFALL:** also required: `"createUpdaterArtifacts": true` in the `bundle` config (default false). Without it no `.sig` files are produced at all and tauri-action logs "Signature not found for the updater JSON. Skipping upload..."

4. **Per-OS bundle targets via matrix `args` — AND pass `--target` explicitly.**
   **PITFALL:** `bundle.targets: ["deb","rpm"]` in `tauri.conf.json` applies to EVERY runner in a matrix — Windows and macOS jobs then fail on invalid bundle targets. Override per matrix entry:
   - Linux: `args: --target ${{ matrix.target }} --bundles deb,rpm,appimage`
   - Windows: `args: --target ${{ matrix.target }} --bundles nsis`
   - macOS: `args: --target ${{ matrix.target }} --bundles app,dmg`
   **PITFALL:** installing the Rust target via dtolnay/rust-toolchain does NOT make tauri-action cross-compile. Without `--target`, a `x86_64-apple-darwin` job on an ARM mac runner silently builds **aarch64**, and both mac jobs upload the same-named dmg (one overwrites the other — the x64 asset just vanishes).
   **PITFALL:** macOS needs the `app` bundle (not `dmg`, not the `updater` pseudo-target) for updater artifacts — only `app`/`appimage`/`msi`/`nsis` are "updater-enabled". `dmg` alone → bundler warns "no updater-enabled targets were built", no `.app.tar.gz`/`.sig`, and `latest.json` gets no darwin entry.

5. **Version bump touches 4 files** — miss one and artifacts ship mismatched:
   - `package.json`
   - `src-tauri/Cargo.toml`
   - `src-tauri/Cargo.lock` (the app's own `name`/`version` entry, not dependencies)
   - `src-tauri/tauri.conf.json`

6. **Push the tag explicitly.**
   **PITFALL:** `git push --follow-tags` only carries *annotated* tags (`git tag -a`). A lightweight `git tag v0.2.0` stays local — remote shows nothing, the workflow never triggers, and it fails silently (the push output looks successful). Either create annotated tags or `git push origin v0.2.0` explicitly, then verify with `gh run list` before walking away.

7. **tauri-action releases are DRAFTS** (`releaseDraft: true`). All matrix jobs append assets to the same draft release — including assets from earlier FAILED runs, which persist on the draft. Inspect before publishing (`gh release view <tag> --json isDraft,assets`). After all jobs succeed: write real release notes, then publish.

8. **Linux runner system deps:**
   ```bash
   sudo apt-get install -y libpcap-dev libwebkit2gtk-4.1-dev libappindicator3-dev librsvg2-dev patchelf
   ```
   (`libpcap-dev` only for packet-sniffing apps; `patchelf` required for AppImage.)

9. **Signing env in the workflow step:**
   ```yaml
   env:
     GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
     TAURI_SIGNING_PRIVATE_KEY: ${{ secrets.TAURI_SIGNING_PRIVATE_KEY }}
     TAURI_SIGNING_PRIVATE_KEY_PASSWORD: ""   # omit entirely if key has a password — use a secret
   ```

## Pre-flight checks before cutting a new release

- **Stale assets:** confirm existing GitHub release assets were built from the CURRENT code state. A release cut before a major pivot (license change, paywall removal, rebrand) ships stale binaries even when the tag looks recent. `gh release view <tag>` + compare tag commit against `git log`.
- **Untested workflow:** a workflow file committed AFTER the last tag has never run. Expect first-run failures; watch the run (`gh run watch <id> --exit-status`) rather than fire-and-forget.
- **Asset name collisions:** matrix jobs uploading to one release need distinct artifact names per OS/arch — tauri-action handles this via target triple naming by default.

## Run surveillance & re-tag recovery

- **`gh run watch <id> --exit-status` exits early when ANY matrix job fails**, even while other jobs still run. For full-run surveillance poll instead: `while [ "$(gh run view <id> --json status --jq .status)" != "completed" ]; do sleep 60; done`.
- **`gh run view --log-failed` is unavailable mid-run.** Pull one job's log while the run is live: `gh api /repos/<owner>/<repo>/actions/jobs/<jobId>/logs` (get jobId from `gh run view <id> --json jobs`).
- **Cancel a doomed run early** (`gh run cancel <id>`) once one job hits a failure the others will share (e.g. token permissions) — fix, re-tag, re-run instead of burning 20 min of matrix time.
- **Re-tag after a workflow fix (user rule — never force-push a tag):**
  ```bash
  git commit -am "ci: fix ..." && git push origin main
  git tag -d vX.Y.Z                      # delete local
  git push origin :refs/tags/vX.Y.Z      # delete remote
  git tag vX.Y.Z && git push origin vX.Y.Z
  ```
  Explicit delete + recreate as separate steps, never bundled into a force-push.
- **Cold-runner timing:** first run is 15–25 min wall clock (Rust release build dominates; Windows usually slowest). Add `swatinem/rust-cache@v2` to cut repeats to ~5 min.

## Duplicate-draft race (the nastiest one)

If matrix jobs each look for the draft release at start and none exists yet, **each job creates its OWN draft** — you end up with N draft releases sharing one tag. `gh release view <tag>` shows only one; assets uploaded to the sibling drafts look "missing". Diagnose: `gh api /repos/<owner>/<repo>/releases` and count drafts per tag. **Fix:** pre-create the draft in a setup job so every matrix job finds it:

```yaml
jobs:
  create-release:
    runs-on: ubuntu-latest
    steps:
      - env: { GH_TOKEN: ${{ secrets.GITHUB_TOKEN }} }
        run: gh release create "${{ github.ref_name }}" --draft --title "My App ${{ github.ref_name }}" --notes "..."
  build:
    needs: create-release
```

**Recovery without a full rebuild:** download assets by ID (`gh api -H "Accept: application/octet-stream" /repos/.../releases/assets/<assetId>`), merge `latest.json` by hand (union of `platforms` maps; signature field = base64 of the sig file's text), upload to the keeper draft via `POST https://uploads.github.com/.../releases/<id>/assets?name=...`, delete the stray drafts, then publish.

## Platform-specific build landmines

- **Windows + ct2rs (CTranslate2):** `LNK2038: mismatch detected for 'RuntimeLibrary'` (MT_StaticRelease vs MD_DynamicRelease) — ct2rs builds CTranslate2 with static CRT. Fix: `RUSTFLAGS: -Ctarget-feature=+crt-static` on the Windows matrix entry.
- **macOS x86_64 (Intel) + ct2rs:** CTranslate2's CMake injects `-mavx512f/-mavx512vl/...` flags that Apple clang rejects for `x86_64-apple-macosx`. No clean env fix — drop the Intel target (ship aarch64 only) or make ct2rs an optional cargo feature.
- **Re-running one matrix job** (`gh run rerun <runId> --job <jobId>`) creates a NEW job databaseId — fetching logs by the old id returns attempt-1 logs.
- **GitHub API 503s come in bursts** (esp. release/asset endpoints during partial outages) — wrap mutations in retry loops (30s backoff, 4-5 attempts). A transient 503 can even surface as "release not found".

## Verification

```bash
gh run list --limit 5                          # run triggered by the tag
gh run watch <run-id> --exit-status            # all matrix jobs green
gh release view v0.2.0                         # draft exists, all platform assets attached
# After publishing: updater feed reachable
curl -sI https://github.com/<owner>/<repo>/releases/latest/download/latest.json
```
