# Creative Identity Workflow — Reference

## Context
User (synth) has strong opinions about creative identity (taglines, emojis, ASCII art).
This reference captures the workflow pattern that works.

## Pattern: Ask Before Full-Sending Creative Decisions

**What happened:** I was about to commit a tagline ("The harness that learns...") without asking.
**User reaction:** "dont full send the tagline please" — wants approval on identity decisions.
**Correct workflow:**
1. Present 3-5 options with clear categories
2. Let user pick or riff
3. Only commit after explicit "FULL SEND" or equivalent

## Emoji Identity Separation

**Rule learned:** Global brand emoji ≠ personal agent emoji.

| Context | Uses |
|---------|------|
| Global OpenShark brand | 🦞 (default `agent.emoji`) |
| Sidebar header | 🦞 (global branding) |
| Help text | No emoji (clean) |
| Agent mode message | 🦞 (global) |
| Assistant message prefix | `app.config.agent.emoji` (user's personal choice) |
| User's personal identity | 🎹🦞 (synthclaw) |

**Implementation:** The TUI renders assistant messages with `app.config.agent.emoji`,
so setting `emoji = "🎹🦞"` in config personalizes the assistant responses while
global branding stays 🦞.

## Tagline Quality Bar

**Rejected:** "The harness that learns. The agent that decides." — generic AI-speak.
**Accepted:** "Fast. Precise. Hungry." — punchy, shark-coded, no fluff.

**Principle:** Taglines should sound like they could be on a Testarossa bumper sticker.
