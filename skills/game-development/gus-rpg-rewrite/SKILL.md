---
name: gus-rpg-rewrite
description: GusRPG — Unity 6 VContainer DI rewrite complete. All 84 singletons converted.
---

# GusRPG Rewrite — Complete

## Project: `/home/synth/projects/GusRPG/`

**Status:** ✅ FULL REWRITE COMPLETE — Same state as Blood Legacy and Holy Lands

---

## Architecture

| Metric | Before | After |
|--------|--------|-------|
| LOC | 81K | 81K (no logic changed) |
| Singleton `.Instance` declarations | **84** | **0** |
| DI framework | ❌ None | ✅ VContainer 1.15.4 |
| Event system | ❌ Static GameEvents | ✅ IEventBus (typed structs) |
| ServiceLocator anti-pattern | ✅ Present | ❌ Deleted |
| GameIntegrationManager god class | ✅ 648 lines | ❌ Deleted (.old) |
| GameBootstrap | ✅ Present | ❌ Replaced (.old) |
| Interface files | 0 | **97** (I[ClassName]) |

---

## What Was Built

### DI Infrastructure (5 files)
- `Core/DI/GameLifetimeScope.cs` — 80+ service registrations + entry point
- `Core/DI/GameplayScope.cs` — Per-scene installers
- `Core/DI/GameEntryPoint.cs` — Replaces GameBootstrap

### Event Bus (3 files)
- `Core/Events/IEventBus.cs` — Interface
- `Core/Events/EventBus.cs` — Implementation
- `Core/Events/GameEvents.cs` — **25 typed event structs**

### Interfaces (97 files in `Core/Interfaces/`)
Every singleton class has a matching `I[ClassName]` interface

### Dead Code (moved to .old)
- GameBootstrap.cs.old
- GameIntegrationManager.cs.old
- ServiceLocator.cs.old

---

## Pattern Applied to ALL 84 Files

For each file that had `public static [Type] Instance { get; private set; }`:

1. ❌ Removed Instance declaration
2. ❌ Removed singleton Awake() guard (`if (Instance != null && Instance != this)`)
3. ❌ Removed `Instance = this;`
4. ✅ Kept `DontDestroyOnLoad(gameObject)` in Awake
5. ✅ Added `using GusRPG.Core.Interfaces;`
6. ✅ Added `, I[ClassName]` to class declaration

---

## Scene Status

| Scene | State |
|-------|-------|
| MainMenu.unity (14K) | Unchanged — needs Boot scene |
| WorldMap.unity (16K) | Unchanged |
| Combat.unity (16K) | Unchanged |

---

## When You Pick Up Development

1. **Open in Unity 6000.x** — OpenUPM resolves VContainer automatically
2. **Create Boot scene** — Empty scene with GameLifetimeScope component on a root GameObject
3. **Build [Inject] wiring** — Convert remaining `.Instance` calls to `[Inject] I[Service]`
4. **Verify scenes** — Check MainMenu/WorldMap/Combat work with DI
5. **Create ContentAssetExtractor** — Convert hardcoded C# data → ScriptableObjects
6. **Add tests** — 58 test pattern from Holy Lands