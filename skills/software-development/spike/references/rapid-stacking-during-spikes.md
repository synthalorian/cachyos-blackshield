# Rapid Stacking During Spikes

**User preference observed:** When the user explicitly chooses to "keep stacking" (e.g. answering "c" for continue, "go for it", "ok", "keep stacking with all of those"), they want **momentum over cleanliness**.

## Observed Behavior

In the GridOS desktop (Rust + egui) session:
- User was shown that the code had become messy from repeated patches
- User was offered options: clean up, test first, or continue stacking
- User chose **continue stacking**
- User then said "go for it" and "keep stacking with all of those"

## Rule for Future Sessions

During active spike / rapid prototyping phases:

1. When user signals "keep going", prioritize adding new features and UI elements.
2. Do not stop to refactor, fix indentation, or resolve structural issues unless:
   - Compilation completely fails, or
   - User explicitly asks for a cleanup pass
3. Embrace intermediate messy states as part of the exploration velocity.
4. After the stacking wave, the user may request a dedicated cleanup/refactor session.

This produces faster feedback loops on the actual feature surface the user cares about.