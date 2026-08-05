---
name: scaffold-unity-project
description: "Turn a game architecture sketch into a fully scaffolded Unity project — directory structure, core scripts, data types, systems. Production-ready codebase structure with no missing pieces."
version: 1.0.0
author: synthclaw
category: game-development
tags: [unity, game-development, scaffolding, project-initialization, code-generation, csharp]
---

# Scaffold Unity Project

Use this skill when the user wants to **take a game architecture sketch and turn it into a scaffolded, working Unity project** — directory structure created, all core systems written, data types defined, systems wired together, project verified.

This is the bridge between `game-architecture` (the design phase) and `writing-plans` (bite-sized implementation). It's for when you have the blueprint and need the skeleton code NOW — not a plan, not a prototype, but a real codebase.

Load when the user says things like:
- "Put it in the projects folder"
- "Go ahead and scaffold it"
- "Write out the core systems"
- "Initialize the project structure"
- "Create the codebase for [project]"

## When NOT to use this

- **The user just wants a design document** — use `game-architecture`
- **The user wants bite-sized implementation steps** — use `writing-plans`
- **The user wants a quick prototype** — use `spike`
- **The project is not Unity** — adapt the pattern, but this skill is Unity-specific

## Core Method

### Step 1: Confirm Scope and Target

Before writing anything, confirm:
- **Project name** (folder name)
- **Target engine** (should be Unity — if not, adapt)
- **Scope** — how much to scaffold? Full core systems or just infrastructure?

```
User: "go ahead and put it in the projects folder titled 'holy-lands'"
→ Confirm: project name, directory, scope
→ Begin scaffolding
```

### Step 2: Create Directory Structure

Create the full Unity project folder hierarchy:

```
ProjectName/
├── Assets/
│   ├── Scripts/
│   │   ├── Core/              — Singleton, GameBootstrapper, EventSystem, data types
│   │   ├── Player/            — Movement, Combat, Inventory, PlayerController
│   │   ├── World/             — Time/Weather, POI, WorldSystem, FogOfWar
│   │   ├── Combat/            — Attack data, hitboxes, damage, AI combat
│   │   ├── NPCs/              — NPCManager, AI, Behavior Trees, GOAP, Dialogue
│   │   ├── Progression/       — Skills, reputation, faith, economy
│   │   ├── Quests/            — QuestManager, objectives, triggers, rewards
│   │   ├── Buildings/         — Fortress management, construction, upgrades
│   │   ├── UI/                — HUD, menus, dialogue UI, map, notifications
│   │   ├── Audio/             — Dynamic music, ambient, SFX, voice
│   │   ├── SaveLoad/          — Binary serialization, chunk-based saves
│   │   ├── Analytics/         — Event logging, session tracking
│   │   └── Shaders/           — Custom shaders (heat haze, sand, blood)
│   ├── Shaders/
│   ├── Materials/
│   ├── Models/
│   ├── Animations/
│   ├── Prefabs/
│   ├── Editor/
│   ├── Resources/
│   ├── Scenes/
│   │   ├── Loading/
│   │   ├── Cities/
│   │   ├── Wilderness/
│   │   ├── Databases/
│   │   └── UI/
│   └── Audio/
├── Scripts/                    — Build scripts, CI/CD
├── Packages/                   — Unity Package Manager
├── ProjectSettings/
├── .gitignore
└── README.md
```

**Key rules:**
- Every subsystem gets its own namespace (`Holylands.Core`, `Holylands.Player`, etc.)
- Every subsystem gets its own folder under `Assets/Scripts/`
- Core infrastructure (Singleton, EventSystem, GameBootstrapper) goes in `Core/`
- ScriptableObject data types go in `Core/` (they're shared by all systems)
- Scene folders are organized by purpose, not by name

### Step 3: Write Core Foundation (Always First)

These four files are the backbone of EVERY Unity game. Write them before anything else:

#### 3a. Singleton
- Generic `Singleton<T>` for MonoBehaviour-based singletons
- `StaticSingleton<T>` for data-only singletons
- Thread-safe lazy initialization
- Auto-destroy duplicate instances
- `DontDestroyOnLoad` for persistence

#### 3b. EventSystem
- Centralized event bus via `EventSystemManager`
- `GameEvent` struct with type-safe event IDs
- `Subscribe/Unsubscribe/Publish` with thread safety
- Weak reference cleanup
- Extension methods for easy subscription

#### 3c. GameBootstrapper
- System initialization coordinator
- Priority-ordered startup steps
- `IBootstrappable` interface for all subsystems
- Default initialization chain: EventSystem → Save → Input → Player → Faith → Combat → Time → World → NPCs → Quests → Economy → Buildings → Audio → UI
- `SystemInitializationStep` with name, type, priority

#### 3d. Project Config
- `.gitignore` (Unity-generated folders, compiled output)
- `README.md` with core pillars, tech stack, architecture summary

### Step 4: Write Core Data Types (ScriptableObject Types)

These define the data-driven architecture. Write in this order:

1. **AttackData** — Attack type, stance, damage type, timing, stamina, hitbox, effects
2. **WeaponData** — Name, tier, stats, durability, requirements, modifiers, special props
3. **ArmorData** — Slot, resistances per damage type, weight, movement/stamina modifiers
4. **ItemData** — Consumable, tool, material, relic, quest properties
5. **FactionData** — Stance, reputation ranks, relations, economy, spawn data, combat behavior
6. **EnemyData** — Combat stats, AI preset, equipment, loot table, abilities, sound
7. **QuestData** — Type, category, narrative, triggers, objectives, rewards, world effects
8. **SkillData** — Branch, tier, effect type, requirements, visual effects

**All data types follow these rules:**
- `namespace Holylands.Core`
- `[CreateAssetMenu]` for Unity editor creation
- `[Serializable]` inner structs where appropriate
- Methods for validation (`CanEquip`, `CanUse`, etc.)
- Enums for typed fields

### Step 5: Write Player Systems

These four files form the player backbone:

1. **MovementController** — CharacterController-based movement, sprint, jump, horse riding, stamina drain/regen, slope handling, state machine
2. **CombatController** — Stance-based combat, parry/riposte, block, stamina management, damage calculation, armor penetration
3. **Inventory** — Grid-based, stackable items, equipment slots, buy/sell, use items
4. **PlayerController** — Central hub, subscribes to all subsystem events, manages global state, auto-save on death/interval

**Key patterns:**
- `public event Action<T>` for all state changes
- Subscribe to events in `Start()`, unsubscribe in `OnDestroy()`
- PlayerController is the coordinator — it doesn't implement systems, it connects them

### Step 6: Write Core Game Systems

Write in dependency order (systems that depend on other systems come later):

1. **FaithSystem** — Decay, spiritual states (Blessed/Wavering/Doubting/Apostate), prayer, sacraments, relics, miracles
2. **TimeWeatherSystem** — Day/night cycle, weather (Clear/Cloudy/Rain/Sandstorm/HeatWave/Snow/Fog), seasons, heat/cold effects
3. **WorldSystem** — Regions, POIs, fog of war, fast travel, navigation
4. **NPCManager** — NPC spawning, Behavior Trees, GOAP, faction reputation, dialogue triggers
5. **QuestManager** — Quest lifecycle (NotStarted → Active → Completed/Failed), objectives, rewards, timeouts
6. **ProgressionManager** — Rank system (Novice→Serf→Brother→Knight→Marshal→Grand Master), XP, skills, faction rep
7. **BuildingSystem** — Fortress construction, upgrades, resource costs, income generation
8. **UIManager** — HUD, dialogue box, notifications, menu toggles, event-driven updates
9. **AudioSystem** — Music layers, ambient layers, SFX pool, voice, reverb, event-driven audio switching
10. **AnalyticsSystem** — Event logging, session tracking, configurable logging intervals

### Step 7: Write Supporting Systems

1. **InputManager** — New Input System integration, action mappings, event dispatch
2. **SaveLoad System** — Binary serialization, chunk-based saves, AES-256 encryption, auto-save timer
3. **AnalyticsSystem** — Event logging, session data, configurable output

### Step 8: Verify Project Structure

After writing all files, verify:
- All files exist at correct paths
- All namespaces are consistent (`Holylands.<Subsystem>`)
- All `MonoBehaviour` classes have proper Unity attributes (`[RequireComponent]`, `[Tooltip]`, `[Header]`)
- No circular dependencies (core → player → world → NPCs → quests → economy → buildings → UI → audio)
- Event system has subscribers for all published events
- README.md references all major systems

### Step 9: Report Results

Provide a summary:
- **Total files created**
- **Total lines of code**
- **File count per subsystem**
- **Namespace breakdown**
- **What's ready to test**
- **What needs Unity editor setup** (scenes, prefabs, audio clips, shaders — things that can't be pure code)

## Output Format

After scaffolding, always provide:

```
=== THE HOLY LANDS — Project Summary ===

[Subsystem] (N files)
  Assets/Scripts/Subsystem/File.cs          X,XXX bytes (XXX lines)
  Assets/Scripts/Subsystem/Other.cs          X,XXX bytes (XXX lines)

TOTAL: N files, X,XXX lines of code

=== Namespace Breakdown ===
  Holylands.Core: N files
  Holylands.Player: N files
  ...

=== Next Steps ===
1. Open in Unity 6.x
2. Create scenes: Loading, Jerusalem, Desert
3. Create prefabs: Player, Horse, NPCs, buildings
4. Import audio: music tracks, SFX, voice clips
5. Wire up GameBootstrapper in editor
6. Test core loop: movement → combat → quest → save
```

## Pitfalls

- **Don't write Unity-specific code without `[RequireComponent]` attributes.** Every MonoBehaviour that needs a component should declare it.
- **Don't mix namespaces.** `Holylands.Core` stays in `Core/`, `Holylands.Player` stays in `Player/`. Cross-namespace imports should be minimal.
- **Don't create circular dependencies.** Core → Player → World → NPCs → Quests → Economy → Buildings → UI → Audio. Nothing imports backward.
- **Don't forget the bootstrap chain.** Every system must implement `IBootstrappable` and be in the `GameBootstrapper` initialization steps.
- **Don't skip the event wiring.** Every system that produces events must have corresponding subscriptions in the coordinating system (usually PlayerController or a manager).
- **Don't assume Unity editor setup is done.** This skill writes CODE. Scenes, prefabs, audio clips, shaders, materials — these are Unity editor tasks. State this clearly in the report.
- **Don't over-engineer data types.** ScriptableObjects should be simple structs with methods. Don't embed complex logic — that goes in the system that USES the data.
- **Always create `.gitignore` and `README.md`.** Even for a scaffold. Synth will commit immediately.

## Relation to Other Skills

- **After `game-architecture`** → this skill takes the blueprint and produces the actual codebase.
- **Before `writing-plans`** → this produces the scaffold; `writing-plans` produces bite-sized implementation tasks for filling in the gaps.
- **Before `spike`** — if you want to prototype a specific mechanic first, use `spike` instead of scaffolding everything.
- **Complements `test-driven-development`** — write TDD tests after scaffolding each system.

## Example Invocation

```
User: "sketch out a game that runs on Unity, open-world RPG, crusades era, play as a templar"
→ game-architecture fires → outputs full architecture

User: "go ahead and put it in the projects folder titled 'holy-lands'"
→ scaffold-unity-project fires → creates /home/synth/projects/holy-lands/
  → writes all core scripts → verifies → reports results
```

## Remember

```
Directory structure first. Core foundation second.
Data types before systems. Player systems before world systems.
Event-driven. Namespace-isolated. Bootstrap chain complete.
Always verify. Always report.
Unity editor tasks (scenes, prefabs, audio) are NOT part of this skill.
```

## Further Reading

- **`references/unity-architecture-patterns.md`** — ECS vs component-based, DOTS readiness, Addressables, NavMesh patterns. Load when designing Unity architecture.
- **`references/unity-csharp-conventions.md`** — Unity C# conventions: [Header], [Tooltip], [RequireComponent], ScriptableObject patterns, coroutine best practices, MonoBehaviour lifecycle. Load when writing Unity C# code.
- **`references/vcontainer-di-architecture.md`** — VContainer-based DI architecture as an alternative to singleton patterns. Three-scope hierarchy, EventBus, FSM, ScriptableObject data layer, anti-patterns checklist. Load when starting a new project that should have clean DI from day one, or when assessing whether a singleton-heavy project is salvageable.
- **`references/the-holy-lands-blueprint.md`** — Full architecture for "The Holy Lands" (crusades open-world RPG). Session-specific reference for continuing this project. Load before continuing work.

**A good scaffold makes implementation obvious.** Every file has a home. Every system has a namespace. Every event has a subscriber.
