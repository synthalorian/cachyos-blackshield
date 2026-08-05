# License Consistency Audit

## The Problem

A project's license can be specified in multiple places, and they can silently disagree:

1. **LICENSE file** at repo root — the actual legal text
2. **Build config** — `Cargo.toml` `license`, `package.json` `license`, `pubspec.yaml` `license`
3. **README badge** — e.g., `[![License: MIT](...)](LICENSE)`
4. **Individual source files** — some projects put SPDX headers in every file

When these disagree, it's a legal contradiction that can block adoption, create liability, or confuse contributors.

## Real Example

Kicks Guitar Workstation had:
- `LICENSE` file: MIT License (correct, intended)
- `Cargo.toml`: `license = "GPL-3.0-or-later"` (wrong — leftover from initial scaffold)
- README badge: `License: MIT` (matched LICENSE, contradicted Cargo.toml)

This would have shipped a binary built from GPL-licensed metadata while claiming MIT in the README. Fix: change Cargo.toml to `license = "MIT"`.

## Audit Checklist

```bash
# 1. Check LICENSE file
cat LICENSE | head -5

# 2. Check build config
grep -n "^license" Cargo.toml package.json pubspec.yaml 2>/dev/null

# 3. Check README badge
grep -n "License" README.md

# 4. Check source file headers (if your project uses SPDX)
grep -rn "SPDX-License-Identifier" src/ --include='*.rs' | head -5
```

## Common Mismatches

| Location A | Location B | Impact |
|---|---|---|
| LICENSE = MIT | Cargo.toml = GPL | Binary claims GPL, repo claims MIT |
| LICENSE = GPL | README badge = MIT | Users think it's MIT, actually GPL |
| Cargo.toml = MIT | Source headers = Apache-2.0 | Mixed licensing, unclear for contributors |
| No LICENSE file | Cargo.toml = MIT | No actual license text, just a label |

## Fix Priority

1. **Decide the intended license** — this is a product/business decision, not technical
2. **Update all locations to match** — LICENSE file, build config, README badge, source headers
3. **Verify with grep** — run the audit commands above after fixing
4. **Commit as part of ship-readiness** — don't leave license fixes for later

## When to Check

- Before first public release
- When adding a new platform/build target (each may have its own config file)
- When receiving a PR that touches `Cargo.toml`, `package.json`, or `LICENSE`
- When the project was scaffolded from a template with a different default license

## Related

- ChooseALicense.com: https://choosealicense.com/
- SPDX license list: https://spdx.org/licenses/
- GitHub license detection: https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/licensing-a-repository
