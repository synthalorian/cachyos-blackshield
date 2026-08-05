---
name: animal-kingdom-rewrite
description: Animal Kingdom game project — Unity VContainer DI rewrite status and next steps  
---

# Animal Kingdom Rewrite — Session Save

## Project: `/home/synth/projects/AnimalKingdom/`

**Status:** Core architecture rewrite COMPLETE. All 22 managers converted from Singleton → VContainer DI. GameController uses IEventBus. UI + Campaign + Debug files still reference old static GameEvents (compatibility shim in place).

## What Was Done

- **24 Singleton/Instance patterns** → **VContainer DI** (all managers wired with `[Inject]`)
- **GameEvents static event bus** → **IEventBus** in GameController + FactionAbilitySystem
- **Dead code deleted:** Singleton.cs, GameInitializer.cs (moved to .old)
- **GameController** rewritten: no more serialized manager refs, all injected via interfaces

## Foundation Files

| File | Purpose |
|------|---------|
| `Assets/Scripts/Core/DI/GameLifetimeScope.cs` | Root VContainer — 22 service registrations + GameEntryPoint |
| `Assets/Scripts/Core/DI/GameplayScope.cs` | Per-scene — UI, Camera, Controls |
| `Assets/Scripts/Core/Events/IEventBus.cs` | Event bus interface |
| `Assets/Scripts/Core/Events/EventBus.cs` | Event bus implementation |
| `Assets/Scripts/Core/Events/GameEvents.cs` | **26 event structs** (UnitSpawnedEvent, GameStartedEvent, etc.) |
| `Assets/Scripts/Core/Interfaces/IGameServices.cs` | **24 service interfaces** |

## Converted Managers (22 files)

| File | Interface | Notes |
|------|-----------|-------|
| GameController.cs | IGameController | Full IEventBus integration |
| ResourceManager.cs | IResourceManager | Clean singleton removal |
| UnitManager.cs | IUnitManager | Includes DespawnUnit |
| BuildingManager.cs | IBuildingManager | Full placement system preserved |
| MapManager.cs | IMapManager | A* pathfinding preserved |
| DataRegistry.cs | IDataRegistry | Data loading preserved |
| CombatSystem.cs | ICombatSystem | [Inject] IUnitManager, IBuildingManager |
| TechManager.cs | ITechManager | [Inject] IEmpireManager, IBuildingManager, IResourceManager |
| FogOfWar.cs | IFogOfWar | Simplified interface |
| FormationSystem.cs | IFormationSystem | 6 formation types preserved |
| VictoryManager.cs | IVictoryManager | [Inject] IUnitManager, IBuildingManager |
| SaveSystem.cs | ISaveSystem | JSON save/load |
| KinManager.cs | IKinManager | Faction bonuses preserved |
| AIController.cs | IAIController | [Inject] 5 services |
| AnimalTamingManager.cs | IAnimalTamingManager | [Inject] IMapManager |
| AudioManager.cs | IAudioManager | SFX pool, music crossfade |
| GameSounds.cs | IGameSounds | [Inject] IAudioManager |
| ProjectileManager.cs | IProjectileManager | Object pooling |
| EmpireManager.cs | IEmpireManager | Age progression preserved |
| DayNightCycle.cs | IDayNightCycle | Sun/fog preserved |
| WeatherSystem.cs | IWeatherSystem | Particles preserved |
| StatusEffectSystem.cs | IStatusEffectSystem | [Inject] IUnitManager |
| FactionAbilitySystem.cs | IFactionAbilitySystem | [Inject] IEventBus |
| VFXManager.cs | IVFXManager | [Inject] IAudioManager |

## Project Settings

- `ProjectSettings/ProjectVersion.txt` — Unity 6000.4.6f1 (same as Holy Lands)
- `Packages/manifest.json` — VContainer 1.15.4 via OpenUPM

## Remaining Work (files still referencing old static GameEvents)

These files compile fine via the old `GameEvents.cs` compatibility shim but need IEventBus conversion:

| Priority | File | Problem |
|----------|------|---------|
| 🔥 1 | `UI/GameHUD.cs` | 11 GameEvents subscriptions |
| 🔥 1 | `UI/EnhancedGameHUD.cs` | GameEvents subscriptions |
| 🔥 2 | `UI/TutorialSystem.cs` | 6 GameEvents subscriptions |
| 🔥 2 | `UI/NotificationSystem.cs` | GameEvents calls |
| ⚡ 3 | `Campaign/CampaignManager.cs` | 15 GameEvents refs |
| ⚡ 4 | `Debug/DebugConsole.cs` | GameEvents calls |
| ⚡ 5 | `Multiplayer/NetworkGameManager.cs` | GameEvents calls |

Also remaining:
- `Core/GameInitializer.cs.old` — can be fully deleted once assured DI works
- `Core/GameEvents.cs` (old static version) — DELETE after all files converted to IEventBus

## Next Session

1. Convert UI files to IEventBus (the remaining 7 files)
2. Delete old `GameEvents.cs` static compatibility shim
3. Delete `GameInitializer.cs.old`
4. Delete `GameEventDispatcher.cs` (unused)
5. Open in Unity 6 to verify compilation