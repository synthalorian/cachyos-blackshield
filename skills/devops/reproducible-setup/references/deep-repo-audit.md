# Deep Repository Audit for Personal Config & Sensitive Data

A surgical, multi-phase audit that goes beyond basic secret scanning to find personal config leaks (`.claw/`, `.claude/`, IDE session data, Flutter/Android build artifacts), home paths, and other sensitive data that basic scanners miss.

## When to Use

- User says "check ALL my repos for sensitive data" or "audit everything"
- After discovering one leak, user wants a full sweep
- Before open-sourcing a previously private repo
- After switching IDEs or AI coding tools (Claude Code, OpenClaw, etc.) — session files often get committed accidentally

## The Three-Phase Audit

### Phase 1: Shallow Secret Scan (API keys, tokens, passwords)

Use the basic scanner from `scripts/scan-repo-secrets.py`:

```bash
python3 ~/.hermes/skills/devops/reproducible-setup/scripts/scan-repo-secrets.py --github-owner synthalorian --limit 100
```

This catches the obvious stuff: API keys, tokens, private keys, `.env` files.

### Phase 2: Deep Personal Config Scan

The shallow scan misses:
- IDE session logs (`.claw/`, `.claude/`, `.hermes/`)
- Flutter/Android build artifacts with home paths (`.gradle/`, `.cxx/`, `local.properties`)
- Generated config files (`flutter_export_environment.sh`, `Generated.xcconfig`)
- Personal email addresses in non-public contexts
- Home directory paths (`/home/synth/...`)
- Test identity keys in `tmp/` directories
- `.env.example` files (often contain real values)

Run the deep scanner:

```bash
python3 ~/.hermes/skills/devops/reproducible-setup/scripts/deep-audit-repos.py synthalorian
```

This produces a massive JSON report. The key is Phase 3.

### Phase 3: Surgical Filtering to Actionable Items

The deep scan generates thousands of false positives. Filter with this hierarchy:

**ALWAYS SKIP (noise):**
- Lock files: `Cargo.lock`, `Gemfile.lock`, `package-lock.json`, `yarn.lock`, `Podfile.lock`
- Generated manifests: `runner.exe.manifest` (standard Windows Flutter template)
- Binary files: `.png`, `.ico`, `.apk`, `.jpg`, `.jpeg` (email regex matches binary noise)
- Standard URLs: `github.com/rails/...`, `rubygems.org`, `fonts.googleapis.com`, `unpkg.com`, `tailwindcss.com`
- XML schemas: `schemas.android.com/apk/res/android`
- CSS build files: `tailwind.css`, `actiontext.css`
- Bible text: Any file under `assets/bible_data/` with "bearer" matches (biblical text, not tokens)
- Standard Rails files: `sessions_controller.rb`, `sessions/index.html.erb` ("session" is domain terminology)
- Kamal deploy hooks: `pre-deploy.sample`
- `.env.example` files (placeholders, not real secrets)
- `CMakeLists.txt` references to `github.com/flutter/flutter/issues/57146`
- `.github/workflows/` files
- `NEXT_SESSION.md`, `.hermes/plans/` (planning docs)

**ALWAYS KEEP (real issues):**
- `.claw/sessions/*.jsonl` — AI conversation history with workspace paths
- `.clawd-todos.json` — IDE todo data
- `.gradle/` directories in git — Gradle cache with home paths
- `.cxx/` directories in git — CMake build artifacts with absolute paths
- `local.properties` with `sdk.dir=/home/synth/...`
- `android/app/debug.keystore` — Standard debug keystore, not sensitive but shouldn't be committed
- Hardcoded `/home/synth/` paths in shell scripts
- Real API keys in scripts (not placeholders with `<...>`)
- `identity.key`, `*.pem`, `id_rsa` files anywhere

**CONTEXT-DEPENDENT (inspect manually):**
- `config/deploy.yml` with `ssh://docker@...` — Deployment config, usually fine
- `PKGBUILD` with maintainer email — Public package metadata, fine
- `STORE_LISTING.md` with contact email — Public contact, fine
- `harness_registry.rb` with `/home/synth/.local/bin/...` — Public tool paths, fine if tools are public

## Common Leak Categories Discovered

### 1. IDE Session Data (`.claw/`, `.claude/`)

**How it happens:** Claude Code, OpenClaw, and similar tools write session logs to `.claw/sessions/` or `.claude/projects/`. If the repo root is your workspace, these directories get created inside the repo and committed accidentally.

**Content at risk:** Full AI conversation history, tool calls, file reads, workspace paths (`/home/synth/projects/...`), model names, and sometimes API keys in tool arguments.

**Fix:**
```bash
git rm -r .claw .clawd-todos.json
echo -e "\n# Claw IDE session data\n.claw/\n.clawd-todos.json" >> .gitignore
git add .gitignore
git commit -m "security: remove claw session files and add to .gitignore"
```

If already pushed, use `git-filter-repo` to purge from history (see [git-history-purge.md](git-history-purge.md)).

### 2. Android/Flutter Build Artifacts

**How it happens:** Flutter's Android build creates `.gradle/` and `.cxx/` directories inside `android/app/`. If `.gitignore` is missing or incomplete, these get committed.

**Content at risk:** Absolute paths to Android SDK (`/home/synth/Android/Sdk/...`), NDK paths, Gradle cache paths (`/home/synth/.gradle/...`), local Java paths.

**Fix:**
```bash
git rm -r android/.gradle android/app/.cxx
echo -e "\n# Android build artifacts\n.gradle/\n.cxx/\nlocal.properties" >> .gitignore
git add .gitignore
git commit -m "security: remove Android build artifacts with local paths"
```

**C++ NDK projects (OpenAmp-style):** The `.cxx/` directory is generated by CMake/NDK build and contains absolute paths to the Android SDK, NDK, and CMake toolchain. It also contains `compile_commands.json` with full host paths. Always exclude `.cxx/` and `build/` from git in native Android projects.

```bash
# For C++ Android projects with NDK/CMake
echo -e "\n# NDK/CMake build artifacts\n.cxx/\nbuild/\n*.o\n*.so\n!src/main/jniLibs/**/*.so" >> android/.gitignore
```

### 3. Flutter Generated Files

**How it happens:** `flutter build` generates `flutter_export_environment.sh` and `Generated.xcconfig` with the Flutter SDK path (`/home/synth/.local/share/mise/installs/flutter/...`).

**Fix:** Standard Flutter `.gitignore` should already exclude `ios/Flutter/flutter_export_environment.sh` and `macos/Flutter/flutter_export_environment.sh`. If not:

```bash
echo "ios/Flutter/flutter_export_environment.sh" >> .gitignore
echo "macos/Flutter/flutter_export_environment.sh" >> .gitignore
echo "ios/Flutter/Generated.xcconfig" >> .gitignore
echo "macos/Flutter/Flutter-Generated.xcconfig" >> .gitignore
```

### 4. Hardcoded Home Paths in Scripts

**How it happens:** Convenience scripts for uploading APKs, building, or deploying that hardcode the developer's home directory.

**Example:**
```bash
# BAD
APK_DIR="/home/synth/projects/open-bible/build/app/outputs/flutter-apk"

# GOOD
APK_DIR="./build/app/outputs/flutter-apk"
```

### 5. Test Keys in `tmp/` Directories

**How it happens:** Unit tests generate temporary key files in `tmp/` or `.tmp/` for testing crypto operations. If not cleaned up and not in `.gitignore`, they get committed.

**Fix:** Add `tmp/` to `.gitignore` and remove existing test keys.

## Verification After Cleanup

Always verify with a fresh shallow clone:

```bash
rm -rf /tmp/verify-repo
git clone --depth 1 https://github.com/OWNER/REPO.git /tmp/verify-repo
grep -r "synthalorian@gmail.com\|/home/synth\|sk-.*[a-zA-Z0-9]{20}\|AKIA" /tmp/verify-repo/ 2>/dev/null || echo "CLEAN"
```

## Post-Audit Checklist

1. Rotate any exposed API keys or tokens
2. Check for forks that may retain old history
3. Add `.gitignore` entries for all discovered leak categories
4. Consider installing `gitleaks` or `git-secrets` pre-commit hooks
5. Document the leak category in the repo's security notes
