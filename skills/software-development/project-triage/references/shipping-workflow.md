# Shipping Workflow — Taking a Project to Release

The sequence demonstrated when shipping open-psalm v0.2.0 (C++ TUI app, untracked source, no README, no LICENSE, no release).

## Pre-flight Assessment

Before shipping, confirm:
- [ ] Compiles clean (`cargo check` / `make` / `dotnet build`)
- [ ] Tests pass (`cargo test` / `ctest` / `flutter test`)
- [ ] Core features are real, not stubs
- [ ] No obvious security issues (command injection, hardcoded paths)

## The 7-Step Ship Sequence

### 1. `.gitignore`
Add one before touching any other file. Exclude:
- Build artifacts (`build/`, `target/`, `dist/`)
- Generated data (`*.db`, `*.db-shm`, `*.db-wal`)
- Large source data if the build process can regenerate it (`*.json`, `*.csv`)
- IDE/OS clutter (`.vscode/`, `.idea/`, `.DS_Store`)

### 2. `README.md`
Full rewrite. Must include:
- Project description and tagline
- Feature list with all capabilities
- Installation instructions (dependencies + build commands)
- CLI options / keybindings if applicable
- Development section (test suite, building data files)
- License mention
- Credits

### 3. `LICENSE`
MIT is the default unless the user specifies otherwise. Standard MIT template with copyright year and the user's handle.

### 4. Stage source files
```bash
git add .gitignore LICENSE README.md <source files>
```
Be precise about what's tracked vs ignored. Use `git status` to verify no unwanted files leaked through.

### 5. Commit with a rich message
The commit subject is the feature headline. The body is a bullet-list changelog of everything in the release. This serves as the release note foundation.

### 6. Push
```bash
git push -u origin <branch>
```
If the remote doesn't exist, create the repo first:
```bash
gh repo create <user>/<repo> --public --source=. --remote=origin --push
```

### 7. GitHub Release
```bash
gh release create v<version> --title "<title>" --notes-file - <<'EOF'
<release notes>
EOF
```
Release notes are the commit body expanded — organized by category, with copy-pasteable build commands and quick-start examples.

## Pitfalls
- **Check for existing remote before creating one** — `gh repo create` with `--remote=origin` fails if a remote already exists
- **Don't track large generated data files** — if Python scripts can regenerate the DBs, track the scripts, not the outputs
- **The commit message IS the first draft of the release notes** — write it well and reuse it
- **For C++/Rust CLI apps, don't attach prebuilt binaries** unless the user asks — source-based install is the standard