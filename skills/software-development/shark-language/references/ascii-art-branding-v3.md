# ASCII Art Branding v3 — Hermes-Quality Fin Logo

## Design Principles (from Hermes Caduceus Analysis)

The Hermes caduceus achieves high quality through:
1. **Braille dots** for organic texture density — sparse points read as pattern
2. **Gradient shading** with block characters — varying density creates volume
3. **Negative space mastery** — form is defined by what surrounds it
4. **Dual reading** — classical symbol AND modern tech interpretation
5. **Dynamic symmetry** — implied center line with organic variation

## OpenShark Fin Logo

### Full Logo (`FIN_LOGO`)

```
              ▗▄▄
             ▗████▖
            ▗██▓▓██▖
           ▗██▓░░▓██▖
          ▗██▓░  ░▓██▖
         ▗██▓░    ░▓██▖
        ▗██▓░      ░▓██▖
       ▗██▓░        ░▓██▖
      ▗██▓░          ░▓██▖
     ▗██▓░            ░▓██▖
    ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
   ░░░░░░░░░░░░░░░░░░░░░░░░░░
  ░░⠑⠒⠐⠄⠆⠁░░░░░░░░░░░░░░░░░░░░░░░
 ░░⠁⠂⠄⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏░░░░░░░░░░░░░░░░░░░░░
```

- 34 chars wide, 14 lines tall
- Forward 15° tilt suggests motion through water
- Asymmetric trailing edge (longer behind)
- Internal highlight stripe down leading edge (`░` gradient)
- Braille dots (`⠑⠒⠐⠄⠆⠁`) for water spray texture
- Fade below waterline — only suggestion, not definition

### Compact Icon (`FIN_ICON`)

```
    ▗▄
   ▗██▖
  ▗█▓▓█▖
 ▗█▓░░▓█▖
▗█▓░  ░▓█▖
▄▄▄▄▄▄▄▄▄▄
```

- 10 chars wide, 6 lines tall
- Distilled essence for inline use (sidebar headers, etc.)

### Wordmark

```
 ░█████░  ██████  ██████  ██   ██ ███████  █████  ██████   ██ ██
░██  ░██ ██  ░██ ██  ░██ ██   ██ ██      ██   ██ ██   ██  ██ ██
░██  ░██ ██████  ██████  ███████ █████   ███████ ██████   ██ ██
░██  ░██ ██  ░░  ██   ██ ██   ██ ██      ██   ██ ██   ██  ██ ██
 ░█████░  ██████  ██████  ██   ██ ███████ ██   ██ ██   ██  ██ ██
```

- Geometric block letters with internal structure
- Fits in 66 columns
- Architectural cross-section style (like Hermes title)

## Implementation

```rust
// src/tui/ascii_art.rs
pub const FIN_LOGO: &str = r#"
              ▗▄▄
             ▗████▖
            ▗██▓▓██▖
           ▗██▓░░▓██▖
          ▗██▓░  ░▓██▖
         ▗██▓░    ░▓██▖
        ▗██▓░      ░▓██▖
       ▗██▓░        ░▓██▖
      ▗██▓░          ░▓██▖
     ▗██▓░            ░▓██▖
    ▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄▄
   ░░░░░░░░░░░░░░░░░░░░░░░░░░
  ░░⠑⠒⠐⠄⠆⠁░░░░░░░░░░░░░░░░░░░░░░░
 ░░⠁⠂⠄⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏░░░░░░░░░░░░░░░░░░░░░"#;

pub fn session_header(version: &str) -> String {
    format!(
        r#"
    ▗▄     openshark {}
   ▗██▖
  ▗█▓▓█▖   Fast. Precise. Hungry.
 ▗█▓░░▓█▖
▗█▓░  ░▓█▖
▄▄▄▄▄▄▄▄▄▄"#,
        version
    )
}
```

## Character Reference

| Purpose | Characters |
|---------|-----------|
| Fin edge/cutwater | ▗, ▄, ▖ |
| Fin body (dense) | █, ▓ |
| Fin body (medium) | ▒ |
| Highlight / water | ░ |
| Water spray | Braille: ⠁⠂⠄⠆⠇⠈⠉⠊⠋⠌⠍⠎⠏⠑⠒⠐ |

## Tagline

**"Fast. Precise. Hungry."**

- Short, punchy, shark-coded
- No generic AI-speak
- Matches the apex predator energy

## Emoji Identity

**🎹🦞** — synth (keyboard) + shark. The primary emoji pair for synthclaw.

- Sidebar header: `🎹🦞 openshark v1.0.0`
- Agent mode: `🎹🦞 Agent Mode:`
- Default `agent.emoji`: `🎹🦞`

## Migration from v2

v2 had blocky pixel text that got truncated by panel edges:
```
██████   █████   ██████  ██  ██   ████   ██  ██   ████   █████   ██  ██
```

v3 replaces with:
- Fin logo (organic, recognizable)
- Clean wordmark (fits in panel)
- Compact session header (fin icon + text)

## Files

- `src/tui/ascii_art.rs` — All art constants and header generators
- `src/tui/mod.rs` — Welcome screen uses `ascii_art::session_header()`
