# Holy Lands Migration — Small-Scale Case Study

**Project:** `/home/synth/projects/holy-lands/`
**Status:** Core architecture rewrite COMPLETE. Ready for presentation layer.
**Scale:** 15 singletons → 33 files wired

## Key Numbers

| Metric | Value |
|--------|-------|
| C# files | ~33 modified |
| Singletons removed | 15+ |
| Static refs eliminated | All |
| Tests | 58, unchanged |
| Session count | 1-2 |

## Architecture

| File | Purpose |
|------|---------|
| `Assets/Scripts/Core/DI/GameLifetimeScope.cs` | Root VContainer — 20+ service registrations + GameEntryPoint |
| `Assets/Scripts/Core/DI/GameplayScope.cs` | Per-scene — PlayerController, CombatController, Input, UI |
| `Assets/Scripts/Core/Events/IEventBus.cs` | Event bus interface |
| `Assets/Scripts/Events/EventBus.cs` | Event bus implementation (replaces old EventSystem.cs) |
| `Assets/Scripts/Core/Interfaces/IGameServices.cs` | 22 service interfaces |
| `Assets/Scripts/Core/Content/ContentLoader.cs` | Asset-first loading, falls back to hardcoded databases |

## Project Settings

- `ProjectSettings/ProjectVersion.txt` — Unity 6000.4.6f1
- `Packages/manifest.json` — VContainer 1.15.4 via OpenUPM

## Migration Pattern (per service)

1. Extract interface from existing Singleton class
2. Remove static Instance property
3. Add `[Inject]` for dependencies (constructor or method injection)
4. Register in `GameLifetimeScope`
5. Replace `FooManager.Instance.Bar()` → `_fooService.Bar()` in all callers
6. Delete old Singleton.cs base class (at end)

## Lessons Learned (small scale)

- Interface extraction is straightforward when <20 services
- Can do all services in one pass
- Tests pass without modification because they weren't using Instance anyway
- One `IGameServices.cs` file works for small projects; separate files per service for large ones
- Old EventSystem.cs had no real consumers — could delete safely
- 6 Unreal C++ files found in `Source/` directory — dead code, deleted

## Data Extraction Tool

- `Assets/Editor/ContentAssetExtractor.cs` — Editor script to auto-create .asset files from hardcoded databases
- Run in Unity: Tools → The Holy Lands → Extract All Content to Assets

## Next Steps (Holy Lands-specific)

1. Open in Unity 6: `cd ~/projects/holy-lands && /opt/unity/Editor/Unity -projectPath .`
2. Run ContentAssetExtractor to generate ScriptableObject assets
3. Build scenes for Holy-Lands2D (URP tilemap) or Holy-Lands3D (HDRP third-person)
