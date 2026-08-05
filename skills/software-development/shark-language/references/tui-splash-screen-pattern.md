# TUI Splash Screen Pattern

Full-screen title screen on app launch, dismissed by keypress — DOS game aesthetic.

## Problem

Injecting welcome banner as a chat message causes:
- Truncation when banner width > chat frame width
- Block character overlap/garbage (`OPENSHARK` → `OPPNSRRKR`)
- Styling conflicts with chat message rendering
- Wasted scrollback space

## Solution: Dedicated Splash Mode

### 1. Add Splash to AppMode

```rust
#[derive(Debug, Clone, PartialEq)]
enum AppMode {
    Splash,      // ← NEW
    Normal,
    Agent,
    ToolApproval,
}
```

### 2. Set Initial Mode to Splash

```rust
// App::new()
mode: AppMode::Splash,
```

### 3. Draw Splash Screen

```rust
fn draw_ui(f: &mut Frame, app: &App) {
    if app.mode == AppMode::Splash {
        draw_splash_screen(f);
        return;
    }
    // ... normal chat UI
}

fn draw_splash_screen(f: &mut Frame) {
    let area = f.area();
    
    // Solid background
    let bg = Block::default().style(bg_style());
    f.render_widget(bg, area);
    
    // Build banner with theme-aware colors
    let banner_text = ascii_art::welcome_banner(area.width as usize);
    let banner_lines: Vec<Line> = banner_text.lines().map(|line| {
        if line.contains('█') {
            Line::from(Span::styled(line, 
                Style::default().fg(current_theme().accent_secondary).add_modifier(Modifier::BOLD)))
        } else if line.contains('▓') || line.contains('▒') || line.contains('░') {
            Line::from(Span::styled(line, 
                Style::default().fg(current_theme().accent)))
        } else {
            Line::from(Span::styled(line, text_style()))
        }
    }).collect();
    
    let banner = Paragraph::new(Text::from(banner_lines))
        .alignment(Alignment::Center);
    
    // Center vertically
    let banner_height = banner_text.lines().count() as u16;
    let vertical_offset = (area.height.saturating_sub(banner_height)) / 2;
    let banner_area = Rect {
        x: area.x, y: area.y + vertical_offset,
        width: area.width, height: banner_height.min(area.height),
    };
    f.render_widget(banner, banner_area);
    
    // "Press any key" prompt
    let prompt = Paragraph::new("Press any key to start")
        .alignment(Alignment::Center)
        .style(Style::default().fg(current_theme().muted).add_modifier(Modifier::ITALIC));
    let prompt_area = Rect {
        x: area.x, y: area.y + area.height.saturating_sub(3),
        width: area.width, height: 1,
    };
    f.render_widget(prompt, prompt_area);
}
```

### 4. Handle Keypress to Dismiss

```rust
async fn handle_input(app: &mut App, key: KeyEvent) -> Result<bool> {
    // Splash mode: any key dismisses
    if app.mode == AppMode::Splash {
        app.mode = AppMode::Normal;
        return Ok(false); // Don't exit
    }
    // ... normal input handling
}
```

### 5. Don't Inject Welcome into Chat

```rust
// REMOVED — splash screen handles welcome
// let welcome = ascii_art::welcome_banner(80);
// app.add_system_message(welcome);
```

## ASCII Art Sizing Rules

| Frame Type | Typical Width | Max Art Width |
|-----------|---------------|---------------|
| Full terminal (splash) | 80-120 | 80 |
| Chat area with sidebar | 60-80 | 50 |
| Chat area, sidebar hidden | 80-100 | 70 |
| Sidebar only | 20-30 | 18 |

**Rule:** Measure `frame.width` at render time. Never hardcode width assumptions.

**Rule:** Block character art (`█`) is 1 column wide but visually heavy. Test at minimum expected terminal size (80×24).

## Color Coding by Element

| Element | Theme Color | Why |
|---------|-------------|-----|
| Wordmark/fin | `accent_secondary` (pink/magenta) | High contrast on dark purple bg |
| Waves | `accent` (cyan) | Water association, distinct from art |
| Tagline | `accent_secondary` + BOLD | Readable, branded |
| Prompt | `muted` + ITALIC | Subtle, doesn't compete |

## Splash Layout Pitfalls

### Pitfall 1: Content Not Centered Despite `Alignment::Center`

`Paragraph::alignment(Alignment::Center)` only centers text **within the paragraph's own width**. If the ASCII art string has baked-in leading whitespace or asymmetric padding, the paragraph can't fix it.

**Wrong — raw string with leading newline and asymmetric spaces:**
```rust
pub const WORDMARK: &str = r#"
 ████   ████  ██████  ████  ██  ██ ██████  ████   ████  ██  ██ ████  ██  ██
██  ██ ██  ██ ██     ██  ██ ██  ██ ██     ██  ██ ██  ██ ██  ██ ██ ██ ██ ██"#;
// ^ leading newline + first line starts with space, second doesn't
// Result: wordmark drifts right, looks right-aligned
```

**Right — clean raw string, no leading newline, consistent left edge:**
```rust
pub const WORDMARK: &str = r#"████   ████  ██████  ████  ██  ██ ██████  ████   ████  ██  ██ ████  ██  ██
██  ██ ██  ██ ██     ██  ██ ██  ██ ██     ██  ██ ██  ██ ██  ██ ██ ██ ██ ██"#;
// ^ no leading newline, every line starts at column 0
// Result: center() function can properly calculate and add equal padding
```

**Rule:** Remove leading newlines from `r#"` raw strings. Strip baked-in whitespace so `center()` has full control.

### Pitfall 2: Waves Cut Short (Not Full Width)

Hardcoding wave width to match the fin (e.g., 40 chars) leaves empty space on both sides. The waves should span the entire terminal.

**Wrong — fixed-width waves centered like the fin:**
```rust
pub const WAVE_BACK: &str = "≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈"; // 40 chars
lines.push(center(WAVE_BACK, frame_width)); // Tiny block in middle
```

**Right — generate full-width waves dynamically:**
```rust
fn wave_line(frame_width: usize) -> String {
    let wave_char = '≈';
    let wave_unit = wave_char.to_string().repeat(40);
    let unit_width = wave_unit.width();
    let repeats = (frame_width / unit_width) + 2;
    let full = wave_unit.repeat(repeats);
    // Trim to exact display width
    let mut result = String::with_capacity(frame_width);
    let mut current_width = 0;
    for ch in full.chars() {
        let ch_width = ch.width().unwrap_or(1);
        if current_width + ch_width > frame_width { break; }
        result.push(ch);
        current_width += ch_width;
    }
    result
}

// In welcome_banner():
let full_wave = wave_line(frame_width);
lines.push(full_wave.clone()); // back
lines.push(full_wave.clone()); // mid
lines.push(full_wave);         // front
```

**Rule:** Waves (and any background element) should span `frame_width`. Only the fin/wordmark should be centered with padding.

### Pitfall 3: Double-Centering (The Silent Right-Drift Bug)

When `welcome_banner()` pre-computes left padding to center each line (via a `center()` helper), and then the renderer ALSO sets `Paragraph::alignment(Alignment::Center)`, the text gets centered **twice** — once by the padding, once by ratatui. This pushes everything to the right and can garble block-character art.

**Wrong — pre-padded text + `Alignment::Center`:**
```rust
// ascii_art.rs: welcome_banner() adds left padding
lines.push(center(line, frame_width)); // "   ████..." (padded)

// tui/mod.rs: renderer re-centers
let banner = Paragraph::new(Text::from(banner_lines))
    .alignment(Alignment::Center); // DOUBLE-CENTER — drifts right!
```

**Right — pre-padded text + `Alignment::Left`:**
```rust
// ascii_art.rs: welcome_banner() adds left padding
lines.push(center(line, frame_width)); // "   ████..." (padded)

// tui/mod.rs: trust the pre-computed padding
let banner = Paragraph::new(Text::from(banner_lines))
    .alignment(Alignment::Left); // Single center — correct!
```

**Symptoms:** Content looks right-aligned or garbled. Block letters lose their shape. User screenshots show "DOPHNHANNYI" instead of "OPENSHARK".

**Rule:** If your banner generator pre-computes centering padding, use `Alignment::Left` in the Paragraph. If your generator outputs raw left-aligned text, use `Alignment::Center`. Never both.

### Pitfall 4: Fin Sits on Its Own Wave Line Instead of the Full-Width Waves

If the fin's ASCII art includes a wave merge line (`≈≈≈≈`) at its base, it creates a visual seam — a thin wave line under the fin, then a gap, then the full-width waves.

**Wrong — fin includes wave merge line:**
```rust
pub const FIN_LOGO: &str = r#"              ██
            ...
       ████████████████
≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈≈"#;
// ^ This creates a separate 40-char wave under the fin
```

**Right — fin ends at its base, waves generated separately:**
```rust
pub const FIN_LOGO: &str = r#"              ██
            ...
       ████████████████"#; // No wave line — base is the last row of █

// In welcome_banner(), after the fin:
let full_wave = wave_line(frame_width);
lines.push(full_wave.clone()); // back — fin sits ON this
lines.push(full_wave.clone()); // mid
lines.push(full_wave);         // front
```

**Rule:** The fin's last line should be its wide base (`██████████████`). The first full-width wave line becomes the water surface the fin sits on. No separate merge line.

### Pitfall 5: `.lines().skip(1)` Hiding Leading Newlines

When a raw string has a leading newline (from `r#"\n...`), code that does `.lines().skip(1)` accidentally "works" but masks the real problem. After removing the leading newline, `.skip(1)` drops the first real line.

**Wrong — after fixing raw string, still skipping:**
```rust
for line in WORDMARK.lines().skip(1) { // Drops first line of wordmark!
    lines.push(center(line, frame_width));
}
```

**Right — iterate all lines:**
```rust
for line in WORDMARK.lines() { // All lines, no skip
    lines.push(center(line, frame_width));
}
```

**Rule:** After removing leading newlines from raw strings, remove `.skip(1)` calls. Verify with visual output.

## Verification Checklist

- [ ] Splash renders full-screen on 80×24 terminal
- [ ] Any key dismisses splash → chat UI appears
- [ ] No welcome message in chat history
- [ ] Art doesn't overflow or wrap weirdly
- [ ] Colors match current theme
- [ ] "Press any key" prompt visible at bottom
- [ ] **Wordmark is horizontally centered** (equal space left and right)
- [ ] **Fin is centered under wordmark**
- [ ] **Waves span full terminal width** (not a tiny centered block)
- [ ] **All 3 wave rows are full-width** (back, mid, front)
- [ ] **No elements drift right** (check with narrow terminal ~60 cols)
- [ ] **Wordmark actually spells the project name** (not garbled — verify visually)
- [ ] **Fin sits directly on the top wave line** (no separate thin wave line under it)
- [ ] **Paragraph alignment matches centering strategy** (`Left` if pre-padded, `Center` if raw)
