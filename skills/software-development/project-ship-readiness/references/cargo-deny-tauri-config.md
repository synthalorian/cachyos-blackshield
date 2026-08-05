# cargo-deny Configuration for Tauri + Rust Projects

This is a known-good `deny.toml` for Rust projects using Tauri 2.x on Linux, which pulls in gtk3, webkit2gtk, and other C FFI bindings that generate many `cargo-deny` warnings.

## Usage

Copy this into your project root as `deny.toml` (or merge with existing config).

```toml
# cargo-deny configuration
# Docs: https://embarkstudios.github.io/cargo-deny/checks/cfg.html

[graph]
all-features = true

[advisories]
version = 2
yanked = "warn"
ignore = [
    # gtk-rs GTK3 bindings are unmaintained but still widely used by Tauri on Linux
    "RUSTSEC-2024-0411", "RUSTSEC-2024-0412", "RUSTSEC-2024-0413",
    "RUSTSEC-2024-0414", "RUSTSEC-2024-0415", "RUSTSEC-2024-0416",
    "RUSTSEC-2024-0417", "RUSTSEC-2024-0418", "RUSTSEC-2024-0419",
    "RUSTSEC-2024-0420",
    # proc-macro-error is unmaintained but pulled in by gtk3-macros
    "RUSTSEC-2024-0370",
    # dlopen_derive is unmaintained but pulled in by midir (MIDI library)
    "RUSTSEC-2023-0051",
    # unic-* crates are unmaintained but pulled in by urlpattern (Tauri dependency)
    "RUSTSEC-2025-0080", "RUSTSEC-2025-0081", "RUSTSEC-2025-0098",
]

[licenses]
version = 2
# Allow common open-source licenses used in the Rust ecosystem
allow = [
    "MIT",
    "Apache-2.0",
    "Apache-2.0 WITH LLVM-exception",
    "BSD-3-Clause",
    "ISC",
    "Unicode-DFS-2016",
    "Unicode-3.0",
    "MPL-2.0",
    "OpenSSL",
    "Zlib",
    "BSL-1.0",
    "GPL-3.0",
    "GPL-3.0-or-later",
    "CDLA-Permissive-2.0",
]
confidence-threshold = 0.8

[sources]
unknown-registry = "warn"
unknown-git = "warn"

[bans]
# Warn when multiple versions of the same crate are pulled in
multiple-versions = "warn"
```

## How to discover your project's advisory IDs

```bash
cd your-project
cargo audit 2>&1 | grep "^ID:" | sort | uniq
```

Add each `RUSTSEC-YYYY-NNNN` to the `ignore` list. Remove any that `cargo-deny` reports as "no crate matched advisory criteria" — those are stale.

## How to discover your project's license gaps

```bash
cargo deny check 2>&1 | grep "error\[rejected\]" -A 6 | grep "license ="
```

Add each rejected license identifier to the `allow` list.

**Note:** `cargo deny check` may also emit `warning[license-not-encountered]` for licenses you allowed but no dependency uses. These are harmless — no action needed.

## Maintenance

Re-run `cargo audit` before every release. New advisories appear regularly. If a new one is actionable (affects code you directly depend on, not a transitive Tauri/gtk3 crate), fix it. If it's transitive and unactionable, add it to the ignore list with a comment.
