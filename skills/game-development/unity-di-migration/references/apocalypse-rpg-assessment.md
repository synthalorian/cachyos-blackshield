# ApocalypseRPG Assessment — Large-Scale Case Study

**Project:** `/home/synth/projects/ApocalypseRPG/`
**Assessment date:** 2026-05-26 (this session)
**Scale:** 258 singleton files, 221K LOC, Unity 2022.3 LTS

## Key Numbers

| Metric | Value |
|--------|-------|
| C# files | 466 |
| Total LOC | 221,507 |
| Directories | 43 |
| Files with `public static T Instance` | 258 |
| `.Instance` references (approx) | 795 |
| Unity version | 2022.3 LTS (per README) |
| VContainer installed? | ❌ |
| Scenes (.unity files) | ❌ Zero — code-only project |
| Tests | ❓ Unknown (not checked) |
| Singleton base class? | Yes: `Assets/Scripts/Core/Singleton.cs` (both `Singleton<T>` and `LazySingleton<T>`) |

## Top Directories by File Count

| Count | Directory |
|-------|-----------|
| 48 | `Assets/Scripts/Core/` |
| 37 | `Assets/Scripts/Systems/` |
| 37 | `Assets/Scripts/Content/` |
| 26 | `Assets/Scripts/UI/` |
| 22 | `Assets/Scripts/Survival/` |
| 16 | `Assets/Scripts/Combat/` |
| 15 | `Assets/Scripts/World/` |
| 15 | `Assets/Scripts/Endgame/` |
| 14 | `Assets/Scripts/Procedural/` |
| 13 | `Assets/Scripts/Performance/` |
| 13 | `Assets/Scripts/Modding/` |
| 13 | `Assets/Scripts/AI/` |

## Full Directory List

43 subdirectories under Assets/Scripts/: AI, Architecture, Audio, Breeding, Building, Combat, Communication, Companions, Content, Core, Cosmetics, Dialogue, Drones, Economy, Ecosystem, Endgame, Enemies, Environment, Farming, Housing, Inventory, Items, Modding, Networking, Performance, Player, Procedural, QoL, Quests, SaveSystem, Social, Stats, Survival, Systems, Taming, Testing, Tutorial, UI, Utils, Vehicles, VFX, World, WorldEvents.

## Singleton Pattern Usage (dominant pattern)

Most classes use their own hand-rolled singleton, NOT inheriting from `Singleton<T>`:

```csharp
// Dominant pattern (258 files)
public class CombatManager : MonoBehaviour
{
    public static CombatManager Instance { get; private set; }
    
    private void Awake() { Instance = this; }
}
```

Only `GameManager` inherits from the `Singleton<GameManager>` base class directly. The rest are standalone.

## Event System

Raw C# `event Action<>` per class — no centralized event bus. Each manager defines its own events:

```csharp
public event Action<Achievement> OnAchievementUnlocked;
public event Action<Experiment, ExperimentVariant> OnUserAssignedToVariant;
// etc.
```

## Key Managers (core layer, highest priority for Phase 1)

- GameManager (243 LOC) — central hub, singleton of Singleton<T>
- SaveSystem (966 LOC) — JSON save/load
- SystemInitializationManager — ordered initialization
- InventoryManager (790 LOC) — 30-slot + weight system
- PlayerManager (133 LOC)
- CombatManager
- DialogueManager
- QuestManager
- WorldManager
- FactionManager
- AudioManager
- PerformanceManager

## Existing Architecture Plan

`Assets/Scripts/Architecture/RefactoringPlan.cs` exists but is a **style guide** with interfaces (IDamageable, IInteractable, ISaveable, IInitializable), naming conventions, and performance guidelines — not an actual migration plan. The interfaces can be reused in the DI migration.

## Content Expansion Docs

32 `CONTENT_EXPANSION_PHASE*.md` files in the project root — significant content exists but isn't wired into Unity scenes. Suggests the project is content-heavy but lacks presentation layer.

## Proposed Migration Plan (from assessment session)

### Phase 0: Foundation
- Install VContainer 1.15.4 via OpenUPM (Unity 2022.3 compatible)
- Create GameLifetimeScope.cs (root container, all core services)
- Create IEventBus.cs + EventBus.cs
- Create IGameServices.cs (all service interfaces)

### Phase 1: Core Layer (~30 services)
- GameManager, SaveSystem, WorldManager, QuestManager, DialogueManager
- SystemInitializationManager, PerformanceManager, AudioManager
- ContentInitializers, FactionManager, BountyManager, etc.

### Phase 2: Feature Layer (~100+ services)
- Combat, Inventory, Building, Taming, Breeding, Vehicles
- Ecosystem, Environment, Economy, Social, Networking
- Modding, Endgame, Farming, Housing, etc.

### Phase 3: UI Wiring & Cleanup
- Replace Instance calls in UI scripts
- Delete old Singleton.cs
- Remove dead code

## Status

Not started. Session concluded with project assessment and plan presentation.
