# Unity C# Conventions — synthclaw Standard

These are the conventions we use when writing Unity C# code. They're not rules — they're the patterns that keep the codebase sane when you're building big projects solo.

## MonoBehaviour Lifecycle

```csharp
// WRONG — no initialization
public class MySystem : MonoBehaviour { }

// RIGHT — proper lifecycle with initialization
public class MySystem : MonoBehaviour
{
    private string _internalState;

    private void Awake()
    {
        // Initialize state, find components, set up references
        // DO NOT depend on other Awake() calls completing
    }

    private void OnEnable()
    {
        // Subscribe to events, start coroutines, resume systems
    }

    private void OnDisable()
    {
        // Unsubscribe from events, stop coroutines, pause systems
    }

    private void Start()
    {
        // All Awake() calls are done. Safe to reference other GameObjects.
        // Initialize runtime state that depends on scene setup.
    }

    private void Update()
    {
        // Frame-dependent logic. NOT for physics — use FixedUpdate().
        // Keep it lean. If you're doing heavy computation, move it elsewhere.
    }

    private void FixedUpdate()
    {
        // Physics-dependent logic. Fixed timestep.
        // Use for character controller movement, force applications.
    }

    private void LateUpdate()
    {
        // Runs after all Update() calls. Good for camera follow, final positioning.
    }

    private void OnDestroy()
    {
        // Cleanup. Unsubscribe from static events. Destroy child objects.
        // This is NOT the place for heavy computation — it can be skipped.
    }
}
```

**Rule:** `Awake()` for setup, `Start()` for initialization that depends on scene setup, `Update()` for frame logic, `FixedUpdate()` for physics, `OnDestroy()` for cleanup.

## Namespace Conventions

Every subsystem gets its own namespace. No mixing:

```csharp
namespace Holylands.Core { /* Singleton, EventSystem, Bootstrapper */ }
namespace Holylands.Player { /* Movement, Combat, Inventory */ }
namespace Holylands.World { /* Time, Weather, WorldSystem */ }
namespace Holylands.NPCs { /* Manager, AI, Dialogue */ }
namespace Holylands.Combat { /* Attack data, Damage, Hitboxes */ }
namespace Holylands.Progressions { /* Skills, Reputation, Economy */ }
namespace Holylands.Quests { /* Manager, Objectives */ }
namespace Holylands.Buildings { /* Fortress, Construction */ }
namespace Holylands.UI { /* HUD, Menus, Dialogue UI */ }
namespace Holylands.Audio { /* Music, Ambient, SFX */ }
namespace Holylands.SaveLoad { /* Serialization */ }
namespace Holylands.Analytics { /* Event logging */ }
```

**Rule:** One namespace per folder. Sub-sub-namespaces are OK (`Holylands.Player.Combat`) if the folder is deep.

## ScriptableObject Patterns

```csharp
// RIGHT — ScriptableObject for data
[CreateAssetMenu(fileName = "WeaponData", menuName = "The Holy Lands/Data/Weapon Data")]
public class WeaponData : ScriptableObject
{
    [Header("Identity")]
    public string displayName;
    public Sprite icon;
    public WeaponTier tier;

    [Header("Combat Stats")]
    public float baseDamage;
    public float attackSpeed;
    public float weight;

    [Header("Requirements")]
    public int minimumStrength;
    public int minimumDexterity;
    public string requiredRank;

    [Serializable]
    public enum WeaponTier { Novice, Iron, Steel, Masterwork, Relic, Legendary }

    public bool CanEquip(int strength, int dexterity, string rank)
        => strength >= minimumStrength && dexterity >= minimumDexterity
        && (requiredRank == null || requiredRank == rank);
}
```

**Rule:** ScriptableObjects are data containers with methods. No Unity references. No `GetComponent()`. No `Instantiate()`. They're pure data.

## Event System Patterns

```csharp
// Define events as a struct with static instances
public struct GameEvent : IEquatable<GameEvent>
{
    public static readonly GameEvent PlayerMoved = new(1);
    public static readonly GameEvent CombatStarted = new(2);
    public static readonly GameEvent PlayerDamaged = new(3);

    public readonly int Id;
    private GameEvent(int id) => Id = id;
    public bool Equals(GameEvent other) => Id == other.Id;
    public override bool Equals(object obj) => obj is GameEvent o && Equals(o);
    public override int GetHashCode() => Id;
}

// Subscribe with weak references
EventSystemManager.Instance.Subscribe(GameEvent.PlayerMoved, OnPlayerMoved);
EventSystemManager.Instance.Subscribe(GameEvent.CombatStarted, OnCombatStarted);

// Unsubscribe in OnDestroy
private void OnDestroy()
{
    EventSystemManager.Instance.Unsubscribe(GameEvent.PlayerMoved, OnPlayerMoved);
    EventSystemManager.Instance.Unsubscribe(GameEvent.CombatStarted, OnCombatStarted);
}
```

**Rule:** Static events in a struct. Subscribe in `OnEnable()`, unsubscribe in `OnDisable()`. Never leave subscriptions dangling.

## Attribute Conventions

```csharp
[RequireComponent(typeof(Rigidbody), typeof(CharacterController))]
[RequireComponent(typeof(Animator))]
public class PlayerController : MonoBehaviour
{
    [Header("Movement Settings")]
    [Tooltip("Base movement speed in units per second")]
    public float walkSpeed = 3f;

    [Header("Stamina")]
    [Tooltip("Seconds of stamina drain per second when sprinting")]
    public float staminaDrainRate = 10f;

    [Tooltip("Seconds of inactivity before stamina starts regenerating")]
    public float staminaRegenDelay = 1.5f;

    [Header("Combat")]
    [Range(0f, 1f)]
    [Tooltip("Chance to parry incoming attacks (0 = never, 1 = always)")]
    public float parryChance = 0.3f;
}
```

**Rule:** `[RequireComponent]` for mandatory dependencies. `[Header]` for section breaks. `[Tooltip]` for anything non-obvious. `[Range(min, max)]` for float values with natural bounds.

## Coroutine Patterns

```csharp
// RIGHT — named coroutines, proper cleanup
private IEnumerator CoWaitForPlayerRespawn()
{
    yield return new WaitForSeconds(3f);
    RespawnPlayer();
}

private void OnDestroy()
{
    StopAllCoroutines();
}

// RIGHT — inline coroutines for simple one-shots
private IEnumerator CoPlayAnimation()
{
    animator.SetTrigger("Attack");
    yield return new WaitForSeconds(0.5f); // Wait for animation
    animator.ResetTrigger("Attack");
}
```

**Rule:** Named coroutines for complex/long-running sequences. Inline for one-shots. Always `StopAllCoroutines()` in `OnDestroy()`.

## Physics Patterns

```csharp
// RIGHT — use FixedUpdate for physics
private void FixedUpdate()
{
    Vector3 move = direction * speed * Time.fixedDeltaTime;
    characterController.Move(move);
}

// RIGHT — use Raycast for ground check
private bool IsGrounded()
{
    return Physics.Raycast(transform.position, Vector3.down, 0.1f);
}

// WRONG — physics in Update
private void Update()
{
    rigidbody.AddForce(force); // DON'T do this
}
```

**Rule:** Physics in `FixedUpdate()`. Raycasts for ground checks. Never apply forces in `Update()`.

## Serialization Patterns

```csharp
// RIGHT — use [System.Serializable] for structs in inspector
[System.Serializable]
public struct SaveSlot
{
    public int SlotIndex;
    public DateTime SaveTimestamp;
    public string CharacterName;
    public float Faith;
    public int PlayerLevel;
    public int Gold;
}

// RIGHT — binary serialization for save files
private byte[] Serialize(SaveSlot slot)
{
    using var ms = new MemoryStream();
    using var bw = new BinaryWriter(ms);
    bw.Write(slot.SlotIndex);
    bw.Write(slot.SaveTimestamp.ToBinary());
    bw.Write(slot.CharacterName);
    bw.Write(slot.Faith);
    bw.Write(slot.PlayerLevel);
    bw.Write(slot.Gold);
    return ms.ToArray();
}

// WRONG — JSON for large game saves (slow, verbose)
private byte[] Serialize(SaveSlot slot)
{
    return System.Text.Json.JsonSerializer.SerializeToUtf8Bytes(slot);
}
```

**Rule:** Use `[System.Serializable]` for inspector-exposed data. Use binary serialization for save files. Avoid JSON for game saves — it's slow and verbose.

## Performance Tips

```csharp
// RIGHT — cache references in Awake
private Rigidbody _rigidbody;
private Animator _animator;

private void Awake()
{
    _rigidbody = GetComponent<Rigidbody>();
    _animator = GetComponent<Animator>();
}

private void Update()
{
    _rigidbody.position = newPosition; // Cached — fast
    _animator.SetFloat("Speed", _velocity.magnitude); // Cached — fast
}

// WRONG — GetComponent every frame
private void Update()
{
    GetComponent<Rigidbody>().position = newPosition; // SLOW
    GetComponent<Animator>().SetFloat("Speed", velocity.magnitude); // SLOW
}
```

**Rule:** Cache `GetComponent()` in `Awake()`. Never call it in `Update()`.

## Debug Logging

```csharp
// RIGHT — contextual logging
Debug.Log($"[FaithSystem] Faith changed: {currentFaith:F1} ({state})");
Debug.LogWarning($"[Combat] Low health: {health:F1} / {maxHealth:F1}");
Debug.LogError($"[SaveSystem] Failed to save slot {slotIndex}: {ex.Message}");

// WRONG — no context
Debug.Log("Faith changed");
Debug.LogWarning("Low health");
Debug.LogError("Failed to save");
```

**Rule:** Always include the namespace prefix `[Subsystem]` in logs. Include values, not just messages. Use `LogWarning` and `LogError` for things that need attention.

## Testing in Unity

```csharp
// RIGHT — use Editor tests
#if UNITY_EDITOR
using NUnit.Framework;
using UnityEditor;

public class CombatTests
{
    [Test]
    public void TestDamageCalculation()
    {
        var attack = ScriptableObject.CreateInstance<AttackData>();
        attack.baseDamage = 20f;
        attack.armorPenetration = 0.3f;

        var armor = ScriptableObject.CreateInstance<ArmorData>();
        armor.slashResistance = 0.5f;

        float damage = DamageCalculator.Calculate(attack, armor);
        Assert.AreEqual(14f, damage, 0.01f); // 20 * (1 - 0.5) * (1 - 0.3)
    }
}
#endif
```

**Rule:** Use NUnit for unit tests on ScriptableObjects and data types. Don't try to test MonoBehaviour directly — use DataObjects instead.

## Scaling Notes (When Patterns Differ)

### Namespaces vs Global Scope

The namespace-convention above applies to LARGE projects (80+ scripts, 10K+ lines, multiple contributors). For small-to-mid projects (under 70 scripts, ~10K lines), **no-namespace (global scope) is simpler and cleaner** — Unity's `Assembly-CSharp` handles declaration ordering automatically.

| Project Size | Recommended | Reason |
|-------------|-------------|--------|
| < 50 scripts, < 8K lines | Global namespace | Less boilerplate, faster to navigate |
| 50-120 scripts, 8K-20K lines | Namespaces | Prevents naming collisions |
| 120+ scripts, 20K+ lines | Namespaces + sub-namespace per folder | Required for maintainability |

**Pitfall — mixing patterns:** Don't start without namespaces and add them later — the refactor is painful. Decide at project start. If you're unsure, go global for JRPG/2D games (simpler) and namespaced for open-world/3D (more complex).

### Serialization: JsonUtility vs BinaryFormatter

The binary serialization rule above predates `BinaryFormatter`'s deprecation. For modern Unity projects:

```
JsonUtility.ToJson() + Base64 encode + header string = current standard
```

**Why JsonUtility over BinaryFormatter:**
- `BinaryFormatter` is deprecated in .NET 8+ and flagged as insecure
- `JsonUtility` is maintained by Unity, supports `[Serializable]` classes, and handles Unity types (Vector3, Quaternion)
- Base64 + header pattern gives integrity checking + human-readable fallback

```csharp
// Modern save pattern:
SaveGameData data = BuildSaveData();
string json = JsonUtility.ToJson(data, true);  // pretty-print for debug
string wrapped = $"GOSv1{Convert.ToBase64String(Encoding.UTF8.GetBytes(json))}";
File.WriteAllText(savePath, wrapped);

// Load:
string wrapped = File.ReadAllText(savePath);
if (!wrapped.StartsWith("GOSv1")) { /* corrupt */ }
string json = Encoding.UTF8.GetString(Convert.FromBase64String(wrapped[5..]));
var data = JsonUtility.FromJson<SaveGameData>(json);
```

**When binary serialization STILL wins:** Streaming assets, large binary data (texture caches), encrypted save files with performance requirements. For typical game saves (< 50KB), JsonUtility + Base64 is fast enough.

### Event Pattern Scale

| Project Size | Event Pattern | Example |
|-------------|--------------|---------|
| Small (< 30 scripts) | Direct C# events | `public event Action<X> OnX;` — subscribe in Start |
| Medium (30-100 scripts) | Event bus per manager | Each manager has its own event list |
| Large (100+ scripts) | Centralized EventSystemManager | Struct-based event IDs, weak references |

The Gospel of Steel JRPG (~68 scripts, ~10K lines) uses **direct C# events on each manager** — simpler, easier to debug, no global event bus overhead. This is the right call for most mid-size Unity games.

## Common Unity Gotchas

- `Awake()` doesn't guarantee other Awake() calls have completed
- `Start()` doesn't guarantee scene objects are fully initialized
- `OnDestroy()` can be skipped if the Editor stops
- `GetComponent()` is expensive — cache it
- `Update()` runs at variable frame rate — use `Time.deltaTime`
- Physics uses `Time.fixedDeltaTime` — not `Time.deltaTime`
- `Destroy()` doesn't immediately remove the object — it's queued
- `Instantiate()` is slow — use object pooling
- Static events in MonoBehaviours won't be cleaned up — use instance events
- `Application.persistentDataPath` is the right place for save files — not `Resources/` or `StreamingAssets/`
- **Manually setting `Time.timeScale = 0` for pause:** Any code using `Time.deltaTime` (not `Time.unscaledDeltaTime`) will freeze. Use `unscaledDeltaTime` for UI/timers during pause.
- **`FindFirstObjectByType` can return null:** Always wrap in `if (manager != null)` — especially when component is in a different scene or hasn't been instantiated yet.
- **Singleton Awake ordering:** If A's Awake references B's Instance and B hasn't Awoken yet, you get null. Keep cross-system wiring in `Start()`, not `Awake()`.
- **DontDestroyOnLoad duplicates:** When a scene re-instantiates a DontDestroyOnLoad singleton, the new instance must self-destruct in Awake. The original survives.
