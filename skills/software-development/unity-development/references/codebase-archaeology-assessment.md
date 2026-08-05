# Codebase Archaeology — Assessing Whether to Keep or Rewrite Existing C#

When you encounter a Unity project with 50K–100K+ lines of existing C# code, the question isn't "does it compile" — it's "is this code worth keeping?"

## The Singleton Signal

The single most important indicator of architecture quality in a Unity project: **how many global singletons exist**.

### Clean (keep):
- No `public static Instance` pattern anywhere
- VContainer / Zenject / DI framework in manifest AND actually used in constructors
- Systems are injected, not found via `FindObjectOfType` or `Instance`
- Event bus is injected, not a static singleton

### Salvageable (refactor):
- 1-3 well-known singletons (GameManager, AudioManager, SaveManager)
- New code uses injection; old code references the few singletons
- Team has a migration plan to phase out remaining singletons

### Rewrite (scrap):
- `UnityEngine.Singleton<T>` base class exists (Utils/Singleton.cs)
- 10+ files with `public static X Instance { get; private set; }`
- EventBus is a `MonoBehaviour` with `Instance` pattern
- Every system calls `GameManager.Instance.X`, `EventBus.Instance.X`, etc.
- VContainer is in manifest.json but never actually injected anywhere — all wiring is via `Awake()` Find/Instance patterns
- 100+ `.cs` files with zero `.unity` / `.prefab` / `.asset` files (code-only export from another engine)

## The Code-Only Project Pattern

When a project migrated from another engine (Godot, UE5), the export typically produces:

```
Assets/Scripts/
├── Combat/         (30+ files, full systems)
├── Core/           (GameManager, EventBus, singletons)
├── Data/           (ScriptableObject class definitions, no .asset files)
├── Dialogue/       (full systems)
├── Entities/       (EnemyAI, NPCController, etc.)
├── Player/         (controller, inventory)
├── Systems/        (quest, crafting, skill, magic)
├── UI/             (50+ files, full panel implementations)
├── Utils/          (Singleton, SaveLoad, ObjectPool)
└── World/          (dungeon generation, weather, time)
```

These projects look impressive (80K+ lines!) but are architecturally the **exact same code as the original engine** — just ported API calls. The singletons, coupling, and load-order hell are preserved in translation.

## Triage Logic

```python
# If a Unity port has these signals, it's a rewrite candidate:
signals = {
    "Singleton base class exists":          find("Utils/Singleton.cs"),
    "Instance properties > 10":             grep_count("public static.*Instance"),
    "VContainer unused":                    manifest_has("vcontainer") AND NOT find("[Inject]"),
    "No .asset files":                      ls("Assets/**/*.asset") == 0,
    "No .prefab files":                     ls("Assets/**/*.prefab") == 0,
}

# 3+ signals true → scrap and rebuild per REWRITE_PLAN
```

## What to Preserve

Even when the C# code is scrapped, preserve:
- **Design docs** (docs/PHASE*_DESIGN.md, REWRITE_PLAN.md)
- **Art assets** (Assets/Art/, Assets/Sprites/, Assets/Audio/)
- **Scene structure** — even empty scenes tell you the intended flow (Boot → MainMenu → Game → GenerationTransition)
- **Data class definitions** — the ScriptableObject class hierarchy is design work (ItemData, WeaponData, EnemyData, etc.)
- **Package manifest** — VContainer, URP, Input System, Cinemachine deps are still correct

## Recommended Approach for Full Rewrite

When scrapping 80K lines of singleton code:

1. **Keep the project folder** — ProjectSettings/, Packages/manifest.json, scene files are reusable infrastructure
2. **Delete ALL Assets/Scripts/** — start with a clean `Assets/Scripts/Core/` and build up per the architecture plan
3. **Pin the REWRITE_PLAN.md to the project root** — it's the new truth
4. **First build target: Boot scene loads without errors** — DI container resolves, event bus fires, scene transitions work. Everything else comes after.
