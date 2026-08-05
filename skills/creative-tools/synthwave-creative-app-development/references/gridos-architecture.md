# GridOS Architecture Notes

## Core Components
- **Rust Core**: Encrypted storage (Argon2id key derivation + AES-GCM), SynthesisEngine trait with scoring/insights/agent spawning
- **Desktop**: egui with aggressive CRT scanlines, neon glow, chrome reflections, 5 themes (Synthwave '84 default)
- **Mobile**: Flutter with matching CRT painter, theme switcher, bridge-ready
- **Bridge**: flutter_rust_bridge with sync functions for synthesis and agents

## Key Implementation Details
- `GridOS` struct holds both storage and synthesis engine
- `LocalSynthesisEngine` implements rich scoring based on engine type and keywords
- Custom painters for CRT effects in both platforms
- Production scripts and CI already in place

## User Preferences Embedded
- Wants production-ready infrastructure before deep testing
- Strong attachment to '84 synthwave aesthetic
- Direct technical feedback preferred
- Big, sellable creative tool vision