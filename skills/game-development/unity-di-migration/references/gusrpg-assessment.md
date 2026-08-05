# GusRPG Assessment — Medium-Scale Case Study

**Project:** `/home/synth/projects/GusRPG/`
**Assessment date:** 2026-05-26
**Scale:** 103 Instance properties, 81K LOC, 188 C# files

## Key Numbers

| Metric | Value |
|--------|-------|
| C# files | 188 |
| Total LOC | 81,246 |
| `public static T Instance` declarations | 103 |
| Singleton\<T\> base class? | ❌ None — each class has its own per-class Instance property |
| Unity version | Unknown (no ProjectVersion.txt) |
| VContainer installed? | ❌ |
| Scenes (.unity files) | 3 (Combat, MainMenu, WorldMap) |
| Tests | ❌ Unknown |
| Event system | String-based `GameEvents.AddListener("event_name", handler)` |

## Top Domains by Instance Count

| Count | Domain |
|-------|--------|
| 13 | Combat — TurnBasedCombatSystem, CombatManager, AbilitySystem, ComboSystem, FormationSystem, TacticalPositioning, TerrainSystem, ThreatSystem, CriticalHitSystem, EncounterManager, CombatInitializer, AdvancedComboSystem, AdvancedEnemyAI |
| 11 | Core — GameManager, InputManager, GameBootstrap, SceneLoader, SceneManagerEx, SaveLoadSystem, SettingsManager, GameConfiguration, GameAnalytics, RuntimePrefabFactory, GameIntegrationManager |
| 5 | VFX — FloatingTextSpawner, various effect managers |
| 5 | UI — various HUD/panel singletons |
| 5 | Base — BaseManager, BaseBuildingSystem, BaseDefense, BaseStaff, SupplyManager |

## Game Profile

Turn-based mercenary company RPG. Features across 44+ domains:
- Company management (MercenaryCompany, CompanyManagementSystem, RelationshipSystem)
- Combat (turn-based, tactical positioning, combos, formations, threat system, critical hits)
- Base building (construction, defense, staffing, supplies)
- Camping, companions, breeding, bounty hunts
- Dialogue, quests, trading, dungeons, crafting, minigames
- Vehicles, rivals, factions, reputation, world events
- Progression, skills, equipment, inventory, economy

## Event System

String-based dictionary event bus:

```csharp
public static class GameEvents
{
    private static Dictionary<string, Delegate> eventTable = new();

    // Register by string name
    public static void AddListener(string eventName, Action handler);
    public static void AddListener<T>(string eventName, Action<T> handler);
    public static void AddListener<T1, T2>(string eventName, Action<T1, T2> handler);
    public static void RemoveListener(string eventName, Action handler);
    public static void TriggerEvent(string eventName);  // via EncounterSystem
}
```

## Key Differences From Holy Lands / Animal Kingdom

1. **No Singleton\<T\> base** — each class declares `Instance` independently. Means no base class to delete in Phase 3, but 103 individual files to touch.
2. **String-based events** — typed IEventBus migration needs a bridging phase where typed events coexist with string events during conversion.
3. **3 scenes exist** — scene-bound MonoBehaviours need `RegisterComponentInHierarchy` instead of `RegisterComponentOnNewGameObject` in VContainer scopes.
4. **81K LOC / 44 domains** — medium-large scale. Core managers first (Company, Combat, GameManager), then feature domains in batches.

## Per-Class Singleton Pattern (representative)

```csharp
// Every manager follows this exact pattern — no inheritance needed
public class MercenaryCompany : MonoBehaviour
{
    public static MercenaryCompany Instance { get; private set; }

    private void Awake() { Instance = this; }
    private void OnDestroy() { if (Instance == this) Instance = null; }
}
```

## Migration Approach

Same as unity-di-migration core method, with these adjustments:

### Phase 0: Assessment (done)

### Phase 1: Foundation
- Install VContainer 1.15.4 via OpenUPM (or direct manifest edit)
- Create `GameLifetimeScope.cs` — register core 20+ services
- Create `GameplayScope.cs` — per-scene for Combat/MainMenu/WorldMap
- Create `IEventBus.cs` + `EventBus.cs`
- Create `IGameServices.cs` — all interfaces

### Phase 2: Migration by Layer

**Layer 1: Core Services** (~11 managers)
GameManager, MercenaryCompany, CompanyManagementSystem, SaveLoadSystem, InputManager, SceneLoader, SceneManagerEx, GameConfiguration, SettingsManager

**Layer 2: Feature Systems** (~40 managers)
Combat systems (13), Base systems (5), Camp/Companions/Bounty/Achievements, Quest/Progression/Economy, Dialogue/Trading/Crafting/Dungeons, UI/VFX/Audio

**Layer 3: Cross-Cutting**
Convert all `GameEvents.AddListener("name", handler)` to `_eventBus.Subscribe<TypedEvent>()`

### Phase 3: Cleanup
- Delete old `GameEvents.cs` (static string-based) — AFTER all consumers migrated
- No Singleton.cs to delete (never existed)
- Build scenes: verify Combat/MainMenu/WorldMap wire up correctly

## Status

Not started. Ready for Phase 1 (VContainer install + DI infrastructure).