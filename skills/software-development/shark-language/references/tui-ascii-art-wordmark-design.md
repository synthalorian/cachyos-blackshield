# TUI ASCII Art Wordmark Design

Session: 2026-05-31. Complete wordmark redesign after user frustration with garbled text.

## The Problem

The OpenShark splash screen wordmark rendered as gibberish ("OOFPHFAANYYI", "DOG PHANTOM") instead of "OPENSHARK". The root cause was **inconsistent spacing within the ASCII art** — single spaces were used both as internal letter gaps AND as letter separators, making it impossible to parse or center correctly.

## Root Cause Analysis

The original wordmark used variable spacing:
```
████   ████  ██████  ████  ██  ██ ██████  ████   ████  ██  ██ ████  ██  ██
```
- Some letters separated by 3 spaces
- Some by 2 spaces  
- Some by 1 space (internal letter gaps)
- Some letters had baked-in leading spaces

When `center()` tried to calculate padding, the inconsistent widths made every line compute differently. When ratatui's `Paragraph::alignment(Alignment::Center)` was applied on top of pre-padded text, the result was double-centering that pushed content right and garbled block characters.

## The Fix: Rigorous Fixed-Width Letter Design

### Step 1: Design Each Letter in Isolation

Every letter must be **exactly the same width** (we use 5 chars). No letter has internal spaces — only `█` and space characters that are part of the letter shape.

```
O =  ███      P = ████      E = █████     N = ██ ██
    ██ ██         ██ ██         ██            █████
    ██ ██         ████          ████          █████
    ██ ██         ██            ██            ██ ██
     ███          ██            █████         ██ ██

S =  ████     H = ██ ██     A =  ███      R = ████
    ██            ██ ██         ██ ██         ██ ██
     ███          █████         █████         ████
       ██         ██ ██         ██ ██         ██ ██
    ████          ██ ██         ██ ██         ██ ██

K = ██ ██
    ██ ██
    ███
    ██ ██
    ██ ██
```

### Step 2: Verify Each Letter Reads Correctly

Before assembling, verify each letter independently:
- **O** — round shape, closed loop
- **P** — vertical stem with top-right loop, open bottom
- **E** — three horizontal bars (top, middle, bottom)
- **N** — two verticals with diagonal/top connection
- **S** — two curves, top-right and bottom-left bulges
- **H** — two verticals with middle crossbar
- **A** — triangle top with middle crossbar
- **R** — P shape plus diagonal leg
- **K** — vertical stem with two diagonal arms

### Step 3: Assemble with Consistent Separators

Use **exactly 2 spaces** between every letter. No variation.

```
 ███   ████   █████  ██ ██   ████  ██ ██   ███   ████   ██ ██
██ ██  ██ ██  ██     █████  ██     ██ ██  ██ ██  ██ ██  ██ ██
██ ██  ████   ████   █████   ███   █████  █████  ████   ███
██ ██  ██     ██     ██ ██     ██  ██ ██  ██ ██  ██ ██  ██ ██
 ███   ██     █████  ██ ██  ████   ██ ██  ██ ██  ██ ██  ██ ██
```

### Step 4: Programmatic Verification

Before shipping, verify the wordmark spells correctly:

```python
# Verify letter count matches expected
word = "OPENSHARK"  # 9 letters
lines = wordmark.split('\n')
for line in lines:
    letters = line.split('  ')  # split by double-space
    letters = [l.strip() for l in letters if l.strip()]
    assert len(letters) == len(word), f"Expected {len(word)} letters, got {len(letters)}"

# Verify all lines have same width
widths = [len(line) for line in lines]
assert len(set(widths)) == 1, f"Inconsistent widths: {widths}"
```

## Critical Pitfalls

### Pitfall 1: Raw String Leading Newlines

`r#"\n...` raw strings with leading newlines require `.skip(1)` when iterating lines. After removing the newline, `.skip(1)` drops the first real line.

**Wrong:**
```rust
pub const WORDMARK: &str = r#"
 ███   ████  ..."#;  // Has leading newline

// Later:
for line in WORDMARK.lines().skip(1) { ... }  // Accidentally correct
```

**Then after fixing the raw string:**
```rust
pub const WORDMARK: &str = r#" ███   ████  ..."#;  // No leading newline

// But code still has:
for line in WORDMARK.lines().skip(1) { ... }  // NOW DROPS FIRST LINE!
```

**Rule:** When removing leading newlines from raw strings, also remove `.skip(1)` calls.

### Pitfall 2: Double-Centering

When `welcome_banner()` pre-computes centering padding AND the renderer uses `Paragraph::alignment(Alignment::Center)`, content gets centered twice and drifts right.

**Symptoms:** Content looks right-aligned. Block letters lose shape. Wordmark reads as gibberish.

**Fix:** Use `Alignment::Left` when text is already pre-padded by `center()`:
```rust
// ascii_art.rs — adds left padding
lines.push(center(line, frame_width));

// tui/mod.rs — trust the padding, don't re-center
let banner = Paragraph::new(Text::from(banner_lines))
    .alignment(Alignment::Left);  // NOT Center!
```

### Pitfall 3: Unicode Width vs Character Count

`≈` (U+2248) has display width 1 but some terminals may render it differently. When generating full-width waves, use `UnicodeWidthChar` to measure actual display width, not character count.

```rust
use unicode_width::{UnicodeWidthChar, UnicodeWidthStr};

fn wave_line(frame_width: usize) -> String {
    let wave_char = '≈';
    let mut result = String::new();
    let mut current_width = 0;
    while current_width < frame_width {
        result.push(wave_char);
        current_width += wave_char.width().unwrap_or(1);
    }
    result
}
```

### Pitfall 4: Fin Wave Merge Line

Including a wave line (`≈≈≈≈`) at the bottom of the fin creates a visual seam — a thin line under the fin, then a gap, then full-width waves.

**Fix:** Remove the wave line from `FIN_LOGO`. The fin's base (`██████████████`) sits directly on the first full-width wave line.

## Complete Working Example

```rust
// src/tui/ascii_art.rs

use unicode_width::{UnicodeWidthChar, UnicodeWidthStr};

fn center(line: &str, width: usize) -> String {
    let line_width = line.width();
    if line_width >= width {
        line.to_string()
    } else {
        let padding = (width - line_width) / 2;
        format!("{}{}", " ".repeat(padding), line)
    }
}

pub const WORDMARK: &str = r#" ███   ████   █████  ██ ██   ████  ██ ██   ███   ████   ██ ██
██ ██  ██ ██  ██     █████  ██     ██ ██  ██ ██  ██ ██  ██ ██
██ ██  ████   ████   █████   ███   █████  █████  ████   ███
██ ██  ██     ██     ██ ██     ██  ██ ██  ██ ██  ██ ██  ██ ██
 ███   ██     █████  ██ ██  ████   ██ ██  ██ ██  ██ ██  ██ ██"#;

pub const FIN_LOGO: &str = r#"              ██
             ████
            ██████
           ████████
          ██████████
         ████████████
        ██████████████
       ████████████████"#;

fn wave_line(frame_width: usize) -> String {
    let wave_char = '≈';
    let wave_unit = wave_char.to_string().repeat(40);
    let unit_width = wave_unit.width();
    if unit_width == 0 || frame_width <= unit_width {
        return wave_char.to_string().repeat(frame_width);
    }
    let repeats = (frame_width / unit_width) + 2;
    let full = wave_unit.repeat(repeats);
    let mut result = String::with_capacity(frame_width);
    let mut current_width = 0;
    for ch in full.chars() {
        let ch_width = ch.width().unwrap_or(1);
        if current_width + ch_width > frame_width { break; }
        result.push(ch);
        current_width += ch_width;
    }
    while result.width() < frame_width {
        result.push(wave_char);
    }
    result
}

pub fn welcome_banner(frame_width: usize) -> String {
    let mut lines = Vec::new();
    
    for line in WORDMARK.lines() {
        lines.push(center(line, frame_width));
    }
    
    lines.push(String::new());
    lines.push(center("Fast. Precise. Hungry.", frame_width));
    lines.push(String::new());
    
    for line in FIN_LOGO.lines() {
        lines.push(center(line, frame_width));
    }
    
    let full_wave = wave_line(frame_width);
    lines.push(full_wave.clone());
    lines.push(full_wave.clone());
    lines.push(full_wave);
    
    lines.join("\n")
}
```

```rust
// src/tui/mod.rs — renderer

fn draw_splash_screen(f: &mut Frame) {
    let area = f.area();
    
    let bg = Block::default().style(bg_style());
    f.render_widget(bg, area);
    
    let banner_text = ascii_art::welcome_banner(area.width as usize);
    let banner_lines: Vec<Line> = banner_text.lines().map(|line| {
        if line.contains('█') {
            Line::from(Span::styled(line,
                Style::default().fg(current_theme().accent_secondary).add_modifier(Modifier::BOLD)))
        } else {
            Line::from(Span::styled(line, text_style()))
        }
    }).collect();
    
    // CRITICAL: Alignment::Left because welcome_banner() already centered with padding
    let banner = Paragraph::new(Text::from(banner_lines))
        .alignment(Alignment::Left)
        .style(bg_style());
    
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

## Verification Checklist

- [ ] Each letter is exactly the same width (5 chars)
- [ ] Letters separated by exactly 2 spaces
- [ ] No leading newline in raw string
- [ ] No `.skip(1)` when iterating lines
- [ ] `Paragraph::alignment(Alignment::Left)` when using pre-padded centering
- [ ] Fin has NO wave merge line at base
- [ ] Waves generated dynamically to span full terminal width
- [ ] `UnicodeWidthChar` imported for wave generation
- [ ] Visual verification: wordmark clearly spells project name
- [ ] Visual verification: all elements centered horizontally
- [ ] Visual verification: waves span full width
- [ ] Visual verification: fin sits directly on top wave line
