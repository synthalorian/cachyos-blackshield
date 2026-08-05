# Visual Bug Report Protocol

When a user reports a visual issue with a screenshot but doesn't specify WHAT is wrong:

## Rule: Ask First, Investigate Second

1. **Ask for clarification in ONE turn.** "What specifically looks wrong?" is sufficient.
2. **Do NOT trace code paths before knowing the symptom.** Reading 20+ functions to "check if X works" when the user hasn't said X is the problem is wasted effort.
3. **The vision model may miss the issue.** It may report "no visible issues" when the user clearly sees something wrong. Trust the user's eyes over the vision model's analysis.
4. **If the user says "it's not looking good" after a feature push,** the most likely issue is the NEW feature displaying incorrectly — not pre-existing layout issues.

## Common Visual Issues to Check

| Symptom | What to Look For |
|---------|-----------------|
| Text overflow | Cut-off mid-word, not just "scrollable truncation" |
| Color contrast | Invisible text on background (especially dark themes) |
| Misalignment | Borders not matching, elements overlapping |
| Missing content | Something that SHOULD be there isn't |
| Wrong content | Raw tags showing, unrendered markdown, escaped HTML |
| Formatting | Broken code blocks, missing syntax highlighting |

## Session Example

User pushed thinking-text handling, then said "it's not looking good man" with a TUI screenshot. Vision model reported "no issues." Instead of asking "what looks wrong?", the agent traced 20+ code locations checking reasoning extraction logic. The actual issue was never identified because the agent never asked. **One clarifying question would have saved 15+ minutes of code archaeology.**

## Anti-Pattern

- ❌ "Let me check the code to see if reasoning is being extracted properly..."
- ❌ Tracing 15+ function definitions to verify a pipeline that may not even be the problem
- ❌ Asking the vision model to analyze the screenshot instead of asking the user

## Correct Response

- ✅ "What specifically looks wrong?"
- ✅ "Is it the thinking text, the colors, the layout, or something else?"
- ✅ Wait for user clarification before touching code
