# Animal Kingdom — Scouting Report

## Project Metadata

| Field | Value |
|-------|-------|
| Path | `/home/synth/projects/AnimalKingdom/` |
| README | `Animal Kingdom` — hex-based RTS with anthropomorphic animal factions |
| Total C# files | 105 |
| Total LOC | 31,663 |
| Scenes | ❌ Zero (`.unity` files) |
| Tests | ❌ Zero |
| Unity version | TBD (check `ProjectSettings/ProjectVersion.txt`) |

## Directory Structure

```
Assets/
├── Editor/        (7 files)
├── Scripts/
│   ├── Abilities/     # Ability system + faction-specific content
│   ├── AI/            # AIController, AIStrategy, AIDifficulty/Personalities
│   ├── Animals/       # Animal taming & pet system (AnimalPen, TamingManager, etc.)
│   ├── Audio/         # AudioManager, GameSounds
│   ├── Buildings/     # BaseBuilding, BuildingManager
│   ├── Camera/        # RTSCameraController
│   ├── Campaign/      # CampaignData, CampaignManager, CampaignUI
│   ├── Combat/        # CombatSystem, Projectile, IDamageable
│   ├── Core/          # GameController, GameEvents, Singleton, SaveSystem, etc.
│   ├── Data/          # ScriptableObject definitions
│   ├── Debug/         # Debug utilities
│   ├── Effects/       # Status effects / VFX
│   ├── Empire/        # EmpireManager
│   ├── Environment/   # DayNightCycle, WeatherSystem
│   ├── Kin/           # KinFaction, KinManager
│   ├── Map/           # MapManager, TerritoryManager, MapScenarios
│   ├── Multiplayer/   # Multiplayer stubs
│   ├── Neutral/       # Neutral units / objectives
│   ├── Quests/        # Quest system
│   ├── Resources/     # ResourceManager
│   ├── UI/            # 15+ UI panels (GameHUD, Minimap, BuildMenu, TechTree, etc.)
│   ├── Units/         # BaseUnit, UnitManager, HeroUnits, etc.
│   └── VFX/           # Visual effects
```

## Singleton Pattern Analysis

### Core Infrastructure

**Core/Singleton.cs** — Abstract generic base class:
```csharp
public abstract class Singleton<T> : MonoBehaviour where T : MonoBehaviour
{
    public static T Instance { get; private set; }
    protected virtual void Awake() { /* destroy duplicates, set Instance */ }
    protected virtual void OnDestroy() { /* clear Instance */ }
}
```

**Core/GameController.cs** — Manual singleton (361 lines), DOES NOT extend Singleton<T>:
- `public static GameController Instance { get; private set; }`
- Serialized references to 13+ managers: ResourceManager, UnitManager, BuildingManager, MapManager, CombatSystem, TechManager, FormationSystem, FogOfWar, VictoryManager, SaveSystem, KinManager, AIController, AnimalTamingManager, AudioManager, ProjectileManager
- Public fields for PlayerFactionType, EnemyFactionType, PlayerKinFaction, EnemyKinFaction
- Lists: SelectedUnits, SelectedBuilding
- Events: OnSelectionChanged, OnGameStateChanged

**Core/GameEvents.cs** — Static event bus (169 lines):
- 30+ static `event Action<...>` declarations
- Static publish methods for every event
- `GameEventDispatcher` — singleton MonoBehaviour that clears all events on destroy

### Files Hitting Singleton/Static Patterns (52 total)

**Core/ (8):** FogOfWar, FormationSystem, GameController, GameEvents, GameInitializer, ObjectPool, SaveSystem, VictoryManager
**Resources/ (1):** ResourceManager
**UI/ (15):** AbilityBar, BuildMenuPanel, EnhancedGameHUD, EnhancedSelectionController, FactionSelectionPanel, FloatingHealthBar, GameHUD, GameOverPanel, MainMenu, Minimap, NotificationSystem, PauseMenu, PetPanel, SelectionController, SettingsPanel, StrategicMapView, TechTreePanel, TutorialSystem
**Map/ (3):** MapManager, MapScenarios, TerritoryManager
**Combat/ (4):** CombatSystem, Projectile, ProjectileManager, RangedAttack
**Units/ (5):** BaseUnit, HeroUnits, UnitControlGroups, UnitManager, UnitUpgrades
**Buildings/ (2):** BaseBuilding, BuildingManager
**Kin/ (2):** KinFaction, KinManager
**Environment/ (2):** DayNightCycle, WeatherSystem
**Empire/ (1):** EmpireManager
**AI/ (5):** AIController, AIDifficulty, AIPersonalities, AIStrategy, EnhancedAIController
**Audio/ (2):** AudioManager, GameSounds

## Migration Approach

Same as Holy Lands (see `pool-unity-di-migration` section 10 in the `unity-development` skill):

1. Add VContainer to `Packages/manifest.json` via OpenUPM
2. Create DI infrastructure: `GameLifetimeScope.cs`, `GameplayScope.cs`
3. Create `IEventBus` + `EventBus` implementation
4. Define service interfaces in `IGameServices.cs`
5. Wire all 52 files — remove Singleton<T>, add `[Inject]`
6. Delete `Singleton.cs`, `GameEvents.cs`, `GameEventDispatcher`, `GameInitializer`
7. Create scenes (minimally a bootstrap scene for testing)

### Key Differences from Holy Lands

- **Smaller scope**: 105 files vs larger codebase — can be done in one focused session
- **No tests to break**: Zero test files means less risk during migration
- **No scene dependencies**: Zero scenes means no prefab/scene reference cleanup needed
- **GameController is the hub**: 13+ serialized refs will all become injected
- **Static GameEvents is comprehensive**: 30+ events need IEventBus equivalents

## Editor Tools (7 files)

- `AbilityCreator.cs` — Create abilities
- `AnimalCreatorWindow.cs` — Animal templates
- `CompleteProjectSetup.cs` — Full project bootstrap
- `DataAssetCreator.cs` — ScriptableObject asset creation
- `DataBrowserWindow.cs` — Browse game data
- `MapEditorWindow.cs` — Map editing
- `SceneSetup.cs` — Scene initialization
- `TechnologyCreator.cs` — Technology tree creator
