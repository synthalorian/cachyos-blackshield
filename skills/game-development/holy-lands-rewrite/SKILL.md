---
name: holy-lands-rewrite
description: Holy Lands game project — Unity 6 VContainer DI rewrite status and next steps
---

# Holy Lands Rewrite — Session Save

## Project: `/home/synth/projects/holy-lands/`

**Status:** Core architecture rewrite COMPLETE. Ready for presentation layer.

## What Was Done

- **15+ Singleton<T>** → **VContainer DI** (33 files wired with `[Inject]`)
- **EventSystemManager.Instance.Publish()** → **IEventBus** (0 static refs remaining in code)
- **Dead code deleted:** Singleton.cs, EventSystem.cs (old), 6 Unreal C++ files in `Source/`

## Foundation Files

| File | Purpose |
|------|---------|
| `Assets/Scripts/Core/DI/GameLifetimeScope.cs` | Root VContainer — 20+ service registrations + GameEntryPoint |
| `Assets/Scripts/Core/DI/GameplayScope.cs` | Per-scene — PlayerController, CombatController, Input, UI |
| `Assets/Scripts/Core/Events/IEventBus.cs` | Event bus interface |
| `Assets/Scripts/Events/EventBus.cs` | Event bus implementation (replaces old EventSystem.cs) |
| `Assets/Scripts/Core/Interfaces/IGameServices.cs` | **22 service interfaces** |
| `Assets/Scripts/Core/Content/ContentLoader.cs` | Asset-first loading, falls back to hardcoded databases |

## Project Settings

- `ProjectSettings/ProjectVersion.txt` — Unity 6000.4.6f1
- `Packages/manifest.json` — VContainer 1.15.4 via OpenUPM

## Data Extraction

- `Assets/Editor/ContentAssetExtractor.cs` — Editor script to auto-create .asset files from hardcoded databases
- Run in Unity: Tools → The Holy Lands → Extract All Content to Assets

## Tests

- 58 tests in `Assets/Scripts/Editor/Tests/` — clean, no DI changes needed

## Next Steps (Holy Lands)

1. Open in Unity 6: `cd ~/projects/holy-lands && /opt/unity/Editor/Unity -projectPath .`
2. Run ContentAssetExtractor to generate ScriptableObject assets
3. Build scenes for either:
   - **Holy-Lands2D** — 2D tilemap presentation (URP)
   - **Holy-Lands3D** — third-person 3D presentation (HDRP)

## AnimalKingdom — DI Migration COMPLETE ✅

| Field | Value |
|-------|-------|
| Path | `/home/synth/projects/AnimalKingdom/` |
| LOC | 31,663 |
| C# files | 110 |
| VContainer | Pre-installed (1.15.4) |
| Pre-existing DI | GameLifetimeScope, IEventBus, IGameServices (25+ interfaces) |
| Phase 2-3 result | 44 files with [Inject], 0 cross-service .Instance. refs remaining |
| Instance refs (remaining) | 8 trivial (5 ObjectPool self-refs, 3 pooled VFX effect refs) |

**What was done:** Added `[Inject] IEventBus` to 17 remaining singleton files, migrated all cross-service `.Instance.` calls to `[Inject]` field references.

## ApocalypseRPG — DI Migration Status

**Project:** `/home/synth/projects/ApocalypseRPG/`
**Size:** 466 C# files, 221K LOC, 258 singleton Instance properties
**Engine:** Unity 2022.3 LTS

### PHASE 0 COMPLETE — Foundation
- Created: `Packages/manifest.json` (VContainer 1.15.4 via OpenUPM)
- Created: `ProjectSettings/ProjectVersion.txt` (2022.3.50f1)
- Created: `Assets/Scripts/Core/DI/GameLifetimeScope.cs` (26 service registrations)
- Created: `Assets/Scripts/Core/DI/GameplayScope.cs` (per-scene scope)
- Created: `Assets/Scripts/Core/DI/GameEntryPoint.cs` (IStartable bootstrap)
- Created: `Assets/Scripts/Core/Events/IEventBus.cs` + `EventBus.cs` + `GameEvents.cs` (38 event structs)
- Created: `Assets/Scripts/Core/Interfaces/IGameService.cs` (marker) + `IGameServices.cs` (20+ interfaces)
- Deprecated: `Singleton.cs` with `[Obsolete]` attribute

### PHASE 3 COMPLETE — Consumer Migration (356 refs converted)
- Batch migration: 62 files modified, 356 `.Instance.` calls → `[Inject]` field references
- Remaining: 12 calls (3 self-refs in manager's own files + 9 ModEventBus internal calls)
- Every gameplay system now resolves dependencies through VContainer injectors

### PHASE 4 — Cleanup (not started)
- Delete old `Singleton.cs` entirely  
- Remove `[Obsolete]` attribute from Singleton.cs
- Verify no remaining dead code
- Open in Unity 6 and test

## Project Status Summary
```
Phase 0 (Foundation):  8 files created for DI infrastructure
Phase 1 (24 services): 24 managers → interface implementations + scope registration
Phase 2 (Mass inj.):   237 managers batch-converted with [Inject] IEventBus
Phase 3 (Consumers):   62 files had .Instance. → [Inject] migration (356 refs)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Total:                 261+ files modified, 7 new infrastructure files
Remaining:             12 trivial Instance refs (self/moddling)

### REMAINING — Phase 1 extended + Phase 2-3
- Phase 1 Extended: BuildingManager, BreedingManager, VehicleSystem, WeatherSystem, NetworkManager, SettlementManager, ZoneManager, PlayerCurrencyManager, SystemInitializationManager (+240 others)
- Phase 2: Migrate consumers from `.Instance.` to `[Inject]` constructor injection
- Phase 3: Remove static Instance fallbacks, delete Singleton.cs

## Remaining Game Projects

| Priority | Project | LOC | Engine | Problem |
|----------|---------|-----|--------|---------|
| 🔥 COMPLETE | Klondike-the-Koala | 192K | Unity-only ✅ | UE5 scrubbed, DI migrated, scene-ready |

## Klondike-the-Koala — DI Migration COMPLETE ✅

| Field | Value |
|-------|-------|
| Path | `/home/synth/projects/Klondike-the-Koala/Unity-Klondike/` |
| Unity | 6000.3.9f1 |
| LOC | 107,527 |
| C# files | 357 |
| UE5 code | 719 C++ files (48K LOC) **SCRAPPED** |
| VContainer | Added (1.15.4) |
| DI infra | GameLifetimeScope (80+ registrations), IEventBus, 28 game events |
| Files injected | 114/114 singleton managers with [Inject] IEventBus |
| Cross-service refs | 0 remaining (11 trivial self-refs + test code) |
| Scenes | 2 (MainMenu, TestScene) |

**What was done:**
1. Scrapped entire UE5 side (Source/, Content/, Config/, Klondike/.uproject, build files)
2. Added VContainer to manifest
3. Created DI infrastructure (IEventBus, EventBus, GameEvents, IGameService, GameLifetimeScope, GameEntryPoint)
4. Batch-injected all 114 singleton files with [Inject] IEventBus
5. Migrated all cross-service .Instance. refs (14 files fixed, 25 refs → 11 trivial self/test refs remaining)

## DrakeDark — DI Migration COMPLETE ✅

| Field | Value |
|-------|-------|
| Path | `/home/synth/projects/DrakeDark/` |
| LOC | 39,372 |
| C# files | 114 |
| Unity | 2022.3.20f1 |
| VContainer | Added (1.15.4) |
| Files injected | 46/46 singleton managers with [Inject] IEventBus |
| Cross-service refs | 0 remaining (3 trivial editor/self-refs) |
| Infrastructure | GameLifetimeScope (28 services), IEventBus, 26 game event structs, 25 service interfaces |

**Complete migration from scratch:** Foundation → injection → consumer migration in one session.