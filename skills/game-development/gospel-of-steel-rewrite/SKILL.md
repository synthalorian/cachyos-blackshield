---
name: gospel-of-steel-rewrite
description: Gospel of Steel — Unity VContainer DI rewrite status. 134 interfaces, 130 DI registrations, Instance compatibility shims active.
---

# Gospel of Steel — DI Conversion Status

**Project:** `/home/synth/projects/gospel-of-steel/`
**Unity Version:** 6000.0.38f1

## Current State (May 2026)

| Metric | Count |
|--------|-------|
| Interface files (`Core/Interfaces/I*.cs`) | **134** |
| DI registrations in GameLifetimeScope | **130** |
| Files with `Instance { get; private set; }` compatibility shim | **121** |
| Remaining `.Instance` calls in calling code | **553** (need migration to `[Inject]`) |
| Scenes | **0** (need Boot scene) |

## Infrastructure (All In Place)

- `Core/DI/GameLifetimeScope.cs` — 130 service registrations, organized by Core/Systems/Combat/UI/Misc
- `Core/DI/GameEntryPoint.cs` — IStartable, logs initialization
- `Core/Events/IEventBus.cs` — Subscribe/Publish/Unsubscribe/Clear
- `Core/Events/EventBus.cs` — Dictionary&lt;Type, Delegate&gt; implementation
- `Core/Interfaces/` — 134 empty stub interfaces, all I-prefixed
- `Core/GameInitializer.cs.old` — archived (no longer used)

## Pattern Applied

1. ✅ Added `using GospelOfSteel.Core.Interfaces` to all implementation files
2. ✅ Added `, I[ClassName]` to class declarations
3. ✅ Added `public static X Instance { get; private set; }` as compatibility shim
4. ✅ Fixed all Awake methods: singleton guard + `DontDestroyOnLoad` + `Instance = this`
5. ✅ Registered all services in GameLifetimeScope
6. ✅ Created IBattleHUD, IItemBase for non-standard files
7. ⏳ `.Instance` calls NOT yet migrated to `[Inject]` — compatibility shim keeps them working

## Features Covered

Conviction, Legacy, Parables, Hex Grid, Turn-Based Combat, Equipment, Inventory, Crafting, Campfire, Blessings, Scripture Collection, Character Levels, Affixes, Elemental Reactions, Status Effects, Enemy Scaling, Boss AI, Party Synergy, Companion Affinity, Bounties, Missions, Achievements, Lore, Quest Journal, Bestiary, Save/Load, New Game+, and more.

## Next Steps

1. Open in Unity 6000.0.38f1
2. Create Boot scene → attach GameLifetimeScope
3. Migrate 553 `.Instance` calls to `[Inject] I[Service]` pattern
4. Wire IEventBus for cross-system communication
5. After all `.Instance` calls migrated → remove Instance compatibility shims
