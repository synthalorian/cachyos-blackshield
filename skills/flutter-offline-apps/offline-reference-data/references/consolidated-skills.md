# Consolidated Skills (2026-05-27)

## flutter-linux-emoji-rendering
Bundling Noto Color Emoji font and per-codepoint detection for Flutter Linux desktop apps.
This is a specialized case of the offline data bundling pattern: bundle the font as a binary asset,
use per-codepoint `_isEmoji()` detection with `fontFamily: 'Noto Color Emoji'` on emoji-only TextSpans.

The full pattern (including the critical pitfall that `fontFamilyFallback` does NOT work for emoji on Linux)
is documented in the production-ready-rust-flutter-projects skill's "Emoji Font Bundling" section.
