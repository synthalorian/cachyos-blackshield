---
name: game-architecture
description: "Design and scope video game infrastructure: core pillars, systems, Unity/UE/Godot architecture, tech stack, roadmap, and unique selling points."
version: 1.0.0
author: synthclaw
category: game-development
tags: [game-design, architecture, unity, unreal, godot, gdd, scoping, prototyping, infrastructure]
related_skills: [spike, writing-plans, sketch, ideation]
---

# Game Architecture

Use this skill when the user wants to **sketch out a new game's infrastructure** — designing core pillars, gameplay systems, engine architecture, tech stack, and development roadmap before committing to implementation.

Load when the user says things like "sketch out a new game", "let's design a game", "what's the architecture for [game idea]", "plan a game infrastructure", "how do we build [game concept]".

### When NOT to use this

- The user wants a **code prototype** — use `spike`
- The user wants a **UI mockup** — use `sketch`
- The user wants a **detailed implementation plan** — use `writing-plans`
- The user is **already building** a known project — jump to implementation. If they hand you a README with design pillars and say "build from there," they've already done the architecture sketch. Load this skill only for reference, then jump to implementation.
- The user hands you an **existing codebase in a different engine** (e.g., Unreal C++) and says "scrap it and rebuild in Unity C#" — skip architecture entirely. Extract the design concepts from the existing code, delete the old engine files, create Unity project structure, and start writing C#. The user's vision is already clear; your job is execution.
- The user says **"do as much code-side as we can before opening Unity"** — this is a code-first workflow signal. Jump to implementation. All C# code belongs in Assets/Scripts/ with MonoBehaviour singletons and null-guarded public fields. See `scaffold-unity-project` for directory structure and the JRPG reference for the code-first pattern.

## Core Method

Every game architecture sketch follows this structure:

### 1. Core Pillars (3 Words)

Define **exactly three words** that define the game. Not concepts — visceral, tangible nouns or verbs. Every system in the game must reinforce these pillars.

**Examples:**
- "Faith. Steel. Sand." (Templar open-world RPG)
- "Build. Explore. Survive." (Sandbox survival)
- "Rhythm. Reflex. Rage." (Muscle-memory action)

Present pillars with 2-3 sentences each explaining **how it manifests mechanically** — not as flavor text, but as a system the player interacts with.

### 2. Gameplay Loop

One-line or one-block description of the core repeat loop:

```
Action → Consequence → Reward → Progression → Repeat (escalated)
```

Keep it to one paragraph. If you can't describe the loop in one paragraph, the design is overcomplicated.

### 3. Core Systems (4-8)

For each major system, define:
- **Name + one-sentence description**
- **Key mechanics** (what the player actually does)
- **How it connects to pillars** (every system serves the pillars)

Good examples:
- **Faith System** — A second HP bar that decays through sin, refills through prayer. Low faith = mechanical penalties + narrative consequences.
- **Stance-based Combat** — Guard/Strike/Feint/Thrust with tight parry windows, fatigue-based stamina, armor degradation.

### 4. Engine Architecture

Choose the right engine (Unity/UE5/Godot) and define:
- **Project structure** (folder hierarchy)
- **Architecture pattern** (ECS, component-based, hybrid)
- **Key technical decisions** (animation, navigation, AI, save system, streaming)
- **Performance targets** (platforms, FPS, resolution)

### 5. Data-Driven Design

Every entity is data-first. Define the core ScriptableObject / data asset types:

```
WeaponDataSO, EnemyTypeDataSO, QuestDataSO, SkillDataSO, ItemDataSO, FactionDataSO
```

State that designers can modify these without touching code. Code is the engine; data is the fuel.

### 6. Tech Stack Summary

A compact table:

| Layer | Technology |
|-------|-----------|
| Engine | Unity 6 (DOTS/Hybrid ECS) |
| Language | C# |
| Animation | Mecanim + Animation Rigging |
| AI | Behavior Trees + GOAP |
| Nav | NavMesh + Custom pathfinding |
| Audio | Unity Audio |
| UI | UGUI |
| Input | New Input System |
| Streaming | Addressables |
| Save | Custom binary serialization |

### 7. Unique Selling Points (3-5)

What makes this game different from everything else? One sentence each. These are the **selling points**, not the features.

### 8. Development Roadmap (Phases)

If this is a serious proposal (not just brainstorming), include phased delivery:

| Phase | Scope | Timeline |
|-------|-------|----------|
| Phase 1: Core | Combat prototype, faith system, one city, basic UI | Months 1-6 |
| Phase 2: Content | Second city, quest system, NPC AI, horse combat | Months 7-14 |
| Phase 3: Polish | Full world, siege, fortress management, questlines | Months 15-20 |
| Phase 4: Launch | Bug fixing, platform cert, beta, patch prep | Months 21-24 |

Skip roadmap if the user is just exploring ideas.

## Output Format

**Always output in this order:**
1. Core pillars (3 words + explanation)
2. Gameplay loop
3. Core systems (numbered, each with name + description + key mechanics)
4. Engine architecture (project structure + tech decisions)
5. Data-driven design (ScriptableObject list)
6. Combat/combat-adjacent system detail (if relevant — this is always the heart)
7. Faith/progression/narrative system (if relevant)
8. AI system (if relevant)
9. Audio system (if relevant)
10. UI/UX approach (if relevant)
11. Save/load system (if relevant)
12. Performance targets
13. Team/workflow notes (phases)
14. Tech stack summary table
15. Unique selling points
16. **Next steps** — offer concrete options for what to do next

## Pitfalls

- **Don't over-scope.** A solo dev shouldn't plan 10 systems at full depth. Ask about team size.
- **Don't skip the heart.** Combat or the primary mechanic IS the core. Everything else is context.
- **Don't make pillars into marketing.** "Epic" is not a pillar. "Faith. Steel. Sand." is.
- **Don't assume the engine.** Ask synth which engine before committing. Unity, UE5, Godot — each has different strengths.
- **Don't write implementation code.** This is architecture, not coding. Save code for `spike` or `writing-plans`.
- **Don't forget the player experience.** Every system should answer: what does the player feel doing this?
- **Be opinionated.** "That's more broken than a VCR clock" when the user's idea has a fatal flaw. Don't hedge.

## Relation to Other Skills

- **After this skill** → use `scaffold-unity-project` to generate the actual codebase, then `spike` to prototype core mechanics, then `writing-plans` for implementation.
- **Before this skill** → use `ideation` if the user hasn't decided on a concept yet.
- **`sketch`** is for UI/UX mockups; this skill is for systems and architecture. Both may be needed for the same project, at different phases.
- **`writing-plans`** takes this blueprint and turns it into bite-sized implementation tasks with exact file paths and code.

## Example Invocation

```
User: "sketch out a game that runs on Unity, open-world RPG, crusades era, play as a templar"

[This skill fires → outputs full architecture → user picks next step]
```

## Remember

```
3 pillars. Not 5. Not 7. Three.
Gameplay loop in one paragraph.
Combat (or primary mechanic) is the heart.
Data-first. Code is the engine; data is the fuel.
Be opinionated. Call out dumb moves.
Offer concrete next steps.
```

## Further Reading

When continuing a game architecture sketch from a prior session, load the session blueprint for context:

- **`references/the-holy-lands-blueprint.md`** — Full architecture for "The Holy Lands" (Unity open-world crusades RPG). Session-specific detail: pillar definitions, system specs, combat state machine, faith system, AI, audio, UI, save system, tech stack, roadmap. Load before continuing work on this project.
- **`references/unity-architecture-patterns.md`** — Common Unity project structures, ECS vs component-based tradeoffs, DOTS readiness, Addressables patterns, NavMesh vs custom pathfinding. Load when choosing engine architecture.
- **`references/jrpg-turn-based-conviction-architecture.md`** — Complete turn-based JRPG architecture for Unity: speed-based turn queue, conviction resource system (earned-not-found), legacy/permadeath inheritance, hex-grid tactical combat, and ScriptableObject-driven data. Includes damage formulas, combat command pattern, AI behaviors, and pitfall list. Load when building a JRPG-style game rather than an action or open-world game.

**A good game architecture makes every subsequent decision obvious.**