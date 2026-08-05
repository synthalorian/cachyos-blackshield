# VContainer DI Architecture for Unity 6

**Pattern:** Dependency Injection via VContainer instead of MonoBehaviour singletons.
**Use when:** Building a new Unity project from scratch, or rewriting a project with singleton hell.
**Origin:** Legacy of Blood Unity 6 rewrite (May 2026) — 39 files, 4,231 lines, zero singletons.

## Why Not Singletons

Singletons (the `public static X Instance` pattern) create:
- **Load order dependency hell** — 36 autoloads that must init in sequence
- **Coupling explosion** — every script calls `GameManager.Instance.X`, `EventBus.Instance.Y`
- **Untestable** — can't mock or substitute a singleton in tests
- **Memory bloat** — everything loaded always

## VContainer Approach

### Three-Scope Hierarchy

```
GameLifetimeScope (Root)     ← Lives for whole app lifetime
├── Registers: EventBus, SaveManager, SceneLoader, AudioManager
├── GameplayScope (Child)    ← Spawned on game start, destroyed on exit
│   ├── WorldSystems, CombatSystems, Economy, Factions, etc.
│   ├── Player (Controller, Input, Combat)
│   └── WorldGen (Tilemap, Biome, Dungeon)
└── UIScope (Child)          ← Spawned with UI layer
    └── UIManager, Panels, Menus, Elements
```

### Key Rules

1. **NO `public static X Instance`**. Ever.
2. **Everything injected via constructor**. `public MySystem(EventBus eventBus, SaveManager save)`
3. **Systems communicate through events**, not direct references. `_eventBus.Publish(new PlayerDiedEvent(...))`
4. **EventBus is a plain C# class** registered as `Lifetime.Singleton`, NOT a MonoBehaviour
5. **Events are `readonly struct` implementing `IEvent`** — lightweight, value-type, no allocation per publish

### The EventBus

```csharp
public class EventBus
{
    private readonly Dictionary<Type, Delegate> _handlers = new();

    public void Subscribe<T>(Action<T> handler) where T : IEvent { ... }
    public void Unsubscribe<T>(Action<T> handler) where T : IEvent { ... }
    public void Publish<T>(T eventData) where T : IEvent { ... }
}
```

### The FSM

```csharp
public interface IState
{
    string Name { get; }
    void Enter();
    void Update(float deltaTime);
    void Exit();
}

public class StateMachine
{
    public void Initialize(IState initialState) { ... }
    public void AddTransition(IState from, IState to, Func<bool> condition) { ... }
    public void AddAnyTransition(IState to, Func<bool> condition) { ... }
    public void Update(float deltaTime) { ... }
}
```

### ScriptableObject Data Layer

All game data is ScriptableObjects with `[CreateAssetMenu]` attributes:
- Items, Weapons, Armor, Consumables, Enemies, Gods, Biomes, Quests, Skills, Factions, Recipes
- Structs for stat blocks, loot tables, quest objectives
- All under `Assets/Scripts/Data/` with proper namespacing (`LegacyOfBlood.Data.Items`, etc.)

### Architecture Anti-Patterns Checklist

| Pattern | DON'T | DO |
|---------|-------|----|
| System access | `GameManager.Instance.X` | Inject via constructor |
| System communication | `EconomySys.UpdatePrices()` | Publish `MarketUpdateEvent` |
| Data storage | Global variables | ScriptableObjects + SaveData |
| Entity behavior | God class with all logic | Focused components |
| State management | Switch on enum | Proper FSM with state objects |
| UI updates | Poll every frame | Subscribe to events |
| Scene loading | Load everything at start | Additive scene loading |
| Mod support | Hardcoded data | JSON-driven + ScriptableObject |

## When to Use This Pattern

**For new projects:** Always start with VContainer. Setting up DI at the beginning costs ~1 hour and pays back in every subsequent session.

**For rewrites:** If the existing project has 36+ singletons and 80K+ lines of coupled code, rewriting with VContainer is faster than untangling. The question isn't "can we salvage this" but "how quickly can we rebuild with clean architecture."

**For small prototypes:** VContainer is still worth it. Even a 10-file prototype with DI + EventBus is easier to extend than one with singletons.

## File Structure

```
Assets/Scripts/
├── Core/
│   ├── DI/              ← GameLifetimeScope, GameplayScope, UIScope
│   ├── Events/          ← IEvent.cs, EventBus.cs, all event structs
│   ├── StateMachine/    ← IState.cs, StateMachine.cs, Transition.cs
│   ├── Data/            ← SaveManager.cs, SaveData.cs, JsonSerialization.cs
│   ├── Scene/           ← SceneLoader.cs (additive scene management)
│   └── Utils/           ← MathUtils.cs, RandomUtils.cs, AudioManager.cs, ObjectPool.cs
├── Game/
│   ├── Entities/        ← Player, Enemy, NPC, Shared components
│   ├── Systems/         ← Combat, World, Economy, Social, Progression, Generation
│   ├── AI/              ← FSM states, Behavior Tree nodes
│   ├── World/           ← Generators (Tilemap, Biome, Dungeon)
│   └── Dialogue/        ← Keyword dialogue system
├── Data/                ← ScriptableObject definitions
├── UI/                  ← UIManager, Panels, Menus, Elements
└── Modding/             ← ModLoader, ModValidator, ModAPI
```

## Pitfalls

- **Don't try to retrofit VContainer into singleton code.** You'll end up with a hybrid that's worse than either approach. If the code has 36 singletons, the singleton disease has metastasized — rewrite.
- **Don't make EventBus a MonoBehaviour.** Plain C# class, registered in DI. No `Awake()`, no `Update()`, no scene dependency.
- **Don't inject too many things into one constructor.** If a class needs 8+ injected services, it's doing too much. Split into focused systems.
- **Don't forget to register everything.** Unregistered services fail silently at runtime. Always check DI container resolution in your bootstrap test.
- **Don't use VContainer's `RegisterComponent` for systems** — that's for pre-existing MonoBehaviours in the scene. For new code, use `Register<T>(Lifetime.Scoped).AsSelf()`.