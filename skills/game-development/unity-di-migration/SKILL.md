---
name: unity-di-migration
description: Migrate Unity projects from Singleton/Manager pattern to VContainer dependency injection — assessment, foundation, phased conversion, cleanup.
version: 1.0.0
author: synthclaw
category: game-development
tags: [unity, vcontainer, di, dependency-injection, refactoring, singleton, architecture]
related_skills: [game-architecture, scaffold-unity-project, writing-plans]
---

# Unity DI Migration — Singleton to VContainer

Load this skill when the user asks to **refactor a Unity project from Singleton/Manager pattern to VContainer dependency injection**. Covers the full lifecycle: assessment → foundation → phased conversion → cleanup.

## Trigger Conditions

- "rewrite this project with DI"
- "get rid of singletons"
- "migrate to VContainer"
- "convert this from Manager pattern"
- "clean up the singleton hell"
- Any Unity project where you find heavy `public static T Instance` usage

## Core Method

### Phase 0: Assessment

Before touching any code, measure the scope. Run `scripts/assess-singletons.sh` in the project root, then manually:

1. **Count Instance properties** — `grep -rn "public static.*Instance\b.*{ get; private set; }" Assets/ --include="*.cs" | wc -l`
2. **Count Instance references** — `grep -rn "\.Instance\b" Assets/ --include="*.cs" | grep -v "Debug\." | wc -l` (then subtract false positives)
3. **Check Unity version** — `cat ProjectSettings/ProjectVersion.txt`
4. **Check existing DI** — `grep -ri "vcontainer\|zenject\|extenject" Packages/manifest.json Assets/`
5. **Map directory structure** — `for dir in Assets/Scripts/*/; do count=$(find "$dir" -name '*.cs' | wc -l); echo "  $count  $dir"; done | sort -rn`
6. **Count total C# files and LOC** — `find Assets/Scripts -name '*.cs' -type f | wc -l` and `find Assets/Scripts -name '*.cs' -type f -exec cat {} + | wc -l`
7. **Check for existing scenes** — `find Assets -name '*.unity' -type f`
8. **Check existing tests** — `find Assets -name '*Test*' -o -name '*test*' | head -20`
9. **Check event system pattern** — `grep -rn "static.*class GameEvents\|static.*AddListener\|static.*Publish" Assets/ --include="*.cs"`
   - **Typed (struct-based):** Events as structs published via `Publish<T>(T event)` or static `event Action<EventStruct>` — migrate to IEventBus type-safe pattern (one IEvent per struct)
   - **String-based:** Events as string names in `AddListener("event_name", handler)` — needs two-phase migration (add typed events alongside during conversion, remove string events after all consumers migrated)
   - **Raw per-class events:** Each manager has its own `event Action<...>` — extract into typed event structs during migration, add to IEventBus
   - **Mixed:** Any combo of the above — handle each subsystem independently

**Scale classification:**
- **Small (<20 singletons):** Direct per-file replacement, 1-2 sessions (Holy Lands: 15)
- **Medium (20-80):** Batch by feature area, 3-5 sessions (AnimalKingdom: ~52)
- **Large (80+):** Phased multi-session campaign, prioritize core services first (ApocalypseRPG: 258)

**Pattern variant: Per-class singleton (no generic base class)**
Some projects don't have a `Singleton<T>` base — each manager declares `public static T Instance { get; private set; }` independently (GusRPG: 103 Instance props, zero Singleton<T> inheritance). This is **faster to migrate** (no base class to delete, no Awake() base calls to unwind) but requires **more individual edits** (no bulk replacement via the base class). Same assessment workflow, same phased approach — just skip the "delete Singleton.cs" step in Phase 3. Each file gets an interface extracted and `[Inject]` added in-place.

### Phase 1: Foundation

Install VContainer and create the DI infrastructure. Do NOT touch any existing code yet.

1. **Install VContainer** via UPM: `openupm add VContainer` or add to `Packages/manifest.json`
   - VContainer 1.15.4+ works on Unity 2022.3 LTS and Unity 6
   - Check compatibility if using older Unity versions
2. **Create directory structure:**
   ```
   Assets/Scripts/Core/DI/
   ├── GameLifetimeScope.cs      # Root container (20+ service registrations)
   └── GameplayScope.cs          # Per-scene container (player, combat, input, UI)
   Assets/Scripts/Core/Events/
   ├── IEventBus.cs              # Event bus interface
   └── EventBus.cs              # Event bus implementation
   Assets/Scripts/Core/Interfaces/
   └── IGameServices.cs         # All service interfaces (one file or one per service)
   ```
3. **Create IEventBus interface** with `Publish<T>`, `Subscribe<T>`, `Unsubscribe<T>` methods
4. **Create EventBus implementation** using `Dictionary<Type, List<Delegate>>` or `MessagePipe`
5. **Create GameLifetimeScope** (extends `LifetimeScope`), register all core services
6. **Create GameplayScope** (extends `LifetimeScope`), register per-scene systems

### Phase 2: Migration by Layer

#### Class declaration fix (batch step)

After creating all interface files, fix implementation classes in batch:

1. **Add `using` directive** for the interfaces namespace to every implementation file
2. **Append `, I[TypeName]`** to each `public class Xxx : MonoBehaviour` declaration
3. **Keep the original `Instance` property** — do NOT delete it. Add `public static X Instance { get; private set; }` if missing. This is a **compatibility shim** — all existing calling code uses `Xxx.Instance.SomeMethod()` and will break without it. Migration from `.Instance` calls to `[Inject]` is a SEPARATE phase.
4. **Keep DontDestroyOnLoad** in Awake — add `Instance = this;` after it

**Verification after batch step:** Run `grep -l "class .*: MonoBehaviour" | wc -l` vs `grep -l ", I[A-Z]" | wc -l` to find files that missed the interface inheritance. They should be nearly equal (difference is non-MonoBehaviour classes or nested types).

#### Interface file naming pitfall

When batch-creating interface files, scripts may create files WITHOUT the `I` prefix (e.g., `InventoryManager.cs` instead of `IInventoryManager.cs` inside the interfaces directory). This manifests as TWO problems:

- **DUPLICATE**: Both `ClassName.cs` AND `IClassName.cs` exist in the interfaces directory — delete the non-prefixed version
- **ORPHAN**: Only `ClassName.cs` (without `I`) exists — rename to `IClassName.cs` AND fix the content from `interface ClassName` to `interface IClassName`

**Fix:** Run a two-pass script:
```bash
# Pass 1: Delete duplicates (where I-prefixed sibling exists)
for f in $(find Assets/Scripts/Core/Interfaces -name "*.cs" ! -name "I*.cs"); do
  name=$(basename "$f" .cs)
  [ -f "Assets/Scripts/Core/Interfaces/I${name}.cs" ] && rm "$f"
done

# Pass 2: Rename orphans (no I-prefixed sibling)
for f in $(find Assets/Scripts/Core/Interfaces -name "*.cs" ! -name "I*.cs"); do
  name=$(basename "$f" .cs)
  sed -i "s/public interface ${name}/public interface I${name}/g" "$f"
  mv "$f" "Assets/Scripts/Core/Interfaces/I${name}.cs"
done
```

**Verify:** `find Assets/Scripts/Core/Interfaces -name "*.cs" ! -name "I*.cs"` should return 0.

#### Awake method — two broken patterns after automated patching

Automated sed scripts that add `DontDestroyOnLoad(gameObject)` and `Instance = this;` to Awake often produce broken code. Two distinct patterns:

**Pattern A (78% of files): DontDestroyOnLoad OUTSIDE the method body braces**
```csharp
// BROKEN
void Awake()
    DontDestroyOnLoad(gameObject);   // ← outside the { }
{
    if (Instance != null && Instance != this)
    {
        Destroy(gameObject);
        return;
    }
}
```
**Fix:** Replace with properly structured method using a regex:
```bash
# Pattern A replacement (perl for multi-line regex)
perl -i -0pe 's/void Awake\(\)\n\s+DontDestroyOnLoad\(gameObject\);\n\s+\{/void Awake()\n    {\n        if (Instance != null \&\& Instance != this)\n        {\n            Destroy(gameObject);\n            return;\n        }\n        DontDestroyOnLoad(gameObject);\n        Instance = this;\n    }/gs'
```
⚠️ **ALWAYS produces orphan leftover code** (see below).

**Pattern B (22% of files): DontDestroyOnLoad inside braces, no Instance = this**
```csharp
// BROKEN — missing Instance = this
void Awake()
{
    if (Instance != null && Instance != this)
    {
        Destroy(gameObject);
        return;
    }
    DontDestroyOnLoad(gameObject);  // ← present but no Instance = this
}
```
**Fix:** Add `Instance = this;` after `DontDestroyOnLoad(gameObject);`

#### Orphan cleanup after Pattern A fix

After fixing Pattern A, the replaced brace `{` left the ORIGINAL method body code as orphan garbage immediately after the new proper Awake closing brace:

```csharp
// Legit Awake closing brace      ← line N
        if (Instance != null && Instance != this)  // ← ORPHAN (line N+1)
        {
            Destroy(gameObject);
            return;
        }
        GenerateDefaultAffixes();  // ← ORPHAN (line N+5)
    }                              // ← ORPHAN closing brace (line N+6)
```

Two orphan variants (same problem, different formatting):
- **Multi-line:** Each statement on its own line with indentation
- **Single-line:** `if (Instance != null && Instance != this) { Destroy(gameObject); return; }` on one line

**Fix pass 1 — multi-line orphan:**
```python
content = re.sub(
    r'\n    }\n        if \(Instance != null && Instance != this\)\n'
    r'        \{\n            Destroy\(gameObject\);\n'
    r'            return;\n        \}\n    \}\n\n',
    r'\n    }\n\n',
    content
)
```

**Fix pass 2 — single-line orphan:**
```python
content = re.sub(
    r'\n    }\n        if \(Instance != null && Instance != this\) '
    r'\{ Destroy\(gameObject\); return; \}\n.*?\n    }',
    r'\n    }',
    content
)
```

**Edge case — orphan code includes next method's content:**
When the orphan block swallowed code like `GenerateRecipes();\n    }` or `GenerateDefaultSynergies();\n    }`, the closing brace of the NEXT method was also orphaned. Fix by checking what the orphan block absorbs — if it includes non-Instance-check code, manually restore it after removing the orphan Instance check.

**Edge case — next method starts with XML doc (not `void Start/Update`):**
When the method after Awake began with `/// <summary>` instead of `void Start()` or `void Update()`, the Awake closing brace restoration script missed it. Fix: `grep -n "Instance = this;" | grep -A 5` and verify the next non-blank line is `    }` (the Awake closing brace), not `/// <summary>`.

#### Secondary/nested class Instance checks — NOT orphan

Some files contain MULTIPLE MonoBehaviour classes (e.g., `AnimationQueueSystem.cs` contains both `AnimationQueueSystem` and `AutoResolveSystem`; `BattleHistorySystem.cs` contains both `BattleHistorySystem` and `BattleHistoryScreen`). These secondary classes have their OWN Awake and Instance check which are LEGITIMATE.

**Detect:** If `Instance != null` appears more than once in a file, check if multiple class declarations exist:
```bash
grep -c "class .*: MonoBehaviour" file.cs
```
If >1, the duplicates are likely legitimate nested types, not orphan code.

#### Layer 1: Core Services (highest priority, most referenced)

GameManager, SaveSystem, WorldManager, QuestManager, DialogueManager, AudioManager, FactionManager, etc.

**Pattern for each service:**

```csharp
// BEFORE
public class SaveSystem : MonoBehaviour
{
    public static SaveSystem Instance { get; private set; }
    
    private void Awake() { Instance = this; }
    public void SaveGame() { /* logic */ }
}

// AFTER  
public interface ISaveSystem
{
    void SaveGame();
}

public class SaveSystem : MonoBehaviour, ISaveSystem
{
    public static SaveSystem Instance { get; private set; }  // ← KEEP compatibility shim
    
    void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        DontDestroyOnLoad(gameObject);
        Instance = this;
    }
    
    public void SaveGame() { /* same logic, no static refs */ }
}
```

**Key rule:** Extract an interface for every service that other code calls. Prefer PER-FILE interfaces (`Assets/Scripts/Core/Interfaces/ISaveSystem.cs`) over a monolith `IGameServices.cs` — per-file keeps PRs readable and avoids merge conflicts. Use a monolith only for very small projects (<10 services).

**Registration in GameLifetimeScope:**
```csharp
builder.RegisterComponentOnNewGameObject<SaveSystem>(Lifetime.Singleton)
    .As<ISaveSystem>();
// Or for MonoBehaviours already in scenes:
// builder.RegisterComponentInHierarchy<SaveSystem>().As<ISaveSystem>();
```

#### Layer 2: Feature/Manager Services

Combat, Inventory, Building, Taming, Breeding, Vehicles, Environment, Economy, etc.

Same pattern as Core. For medium/large projects, batch by feature area and do one area per session.

#### Layer 3: Cross-Cutting (Events, UI)

Replace direct `Instance` calls with event bus:

```csharp
// BEFORE
CombatManager.Instance.DealDamage(this, target, damageInfo);

// AFTER
[Inject] private IEventBus _eventBus;
_eventBus.Publish(new DealDamageCommand(this, target, damageInfo));
```

For UI classes, inject services directly rather than reaching through event bus for every call. Use events for cross-system communication (player died → quest system, UI, audio all react).

### Phase 3: Cleanup

1. **Delete Singleton.cs** (if it existed) — verify no remaining references first
2. **Delete old EventSystem.cs / GameEvents.cs** (if replaced by IEventBus)
3. **Remove unused SceneManager / static helper classes** that were workarounds for Singleton access
4. **Remove dead code paths** that were only reachable through static Instance access
5. **Run all tests** — they should pass with minimal changes (tests typically construct services directly)
6. **Open in Unity, verify no compile errors**

**String-based GameEvents cleanup (special case):**
For projects using `GameEvents.AddListener("event_name", Action)` with string-keyed event tables:
1. Leave the old string-based GameEvents class in place during conversion (compatibility shim)
2. As each subsystem converts: add typed IEventBus structs AND keep the string subscription until all consumers in that subsystem are migrated
3. After ALL subsystems are converted: grep for `GameEvents.AddListener\|GameEvents.RemoveListener\|GameEvents.TriggerEvent` — if zero hits remain, delete the old GameEvents.cs
4. If any script in a non-converted subsystem (third-party plugin, deprecated code) still references string events, tag the old GameEvents.cs with `[Obsolete("Use IEventBus")]` instead of deleting

**Raw per-class event cleanup:**
For projects where each manager defines its own `event Action<X>` without any centralized event system:
1. Extract each event into a typed struct in `Core/Events/GameEvents.cs` during that manager's conversion
2. Replace `manager.OnFoo += handler` with `_eventBus.Subscribe<FooEvent>(handler)`
3. After all managers converted: grep for `\.On[A-Z]` event subscriptions — delete any remaining raw event declarations that have no subscribers left

## Pitfalls

- **Don't try to migrate everything in one session** for projects >80 singletons. Core services first, then feature modules.
- **Unity 2022.3 has different project format** than Unity 6. VContainer versions may differ — verify openupm for the target version.
- **Don't delete Singleton.cs until all references are gone.** Tag it with `[Obsolete]` during migration to catch stragglers.
- **Scenes matter.** If the project has no .unity files (code-only), you don't need to worry about scene-bound MonoBehaviours. If it does, use `RegisterComponentInHierarchy` instead of `RegisterComponentOnNewGameObject`.
- **Tests shouldn't change.** Unit tests typically mock interfaces or construct classes directly. The interface extraction means tests need FEWER changes, not more.
- **Beware of nested MonoBehaviours** that register themselves in Awake/Start. Those need explicit `[Inject]` methods.
- **Don't add IEventBus until there are consumers ready.** Add the interface first, then wire it into managers one at a time during their conversion.
- **For very large projects (200+ singletons),** keep a spreadsheet or text file tracking which files are done, in progress, and pending. Reference files in this skill's `references/` dir serve this purpose.

## Verification

After each migration layer:
1. `grep -rn "\.Instance\b" Assets/Scripts/ --include="*.cs" | grep -v "Debug\."` — count remaining static refs
2. Build project in Unity to catch compile errors
3. Run tests
4. If scenes exist, verify runtime behavior

## References

- `references/holy-lands-migration.md` — Small-scale case (15 singletons, Unity 6, completed)
- `references/apocalypse-rpg-assessment.md` — Large-scale case (258 singletons, 221K LOC, Unity 2022.3, assessment data)
- `scripts/assess-singletons.sh` — Reusable script for measuring migration scope

## Example Invocation

```
User: "Let's move on to ApocalypseRPG — rewrite it with VContainer"
Agent: Loads this skill. Runs assessment script. Reports: 258 singletons, 221K LOC, Unity 2022.3. 
       Presents phased plan. Begins Phase 0: install VContainer, create scopes.
```

```
User: "Clean up the singleton hell in Holy Lands"
Agent: Loads this skill. Runs assessment. Finds 15 singletons (small scale). 
       Proceeds directly to Phase 1: foundation setup.
```
