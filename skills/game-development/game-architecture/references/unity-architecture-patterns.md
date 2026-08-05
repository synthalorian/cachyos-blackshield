# Unity Architecture Patterns for Large Games

## Architecture Patterns

### Component-Based (Traditional)
**Best for:** Narrative, UI, progression, dialogue, single-player systems
- Each system is a `MonoBehaviour` or `ScriptableObject` attached to GameObjects
- Fast iteration, easy to debug, straightforward for designers
- **Limit:** Performance degrades past ~1000 active entities

### Entity Component System (ECS)
**Best for:** Combat, world simulation, AI, thousands of entities
- Data-driven, cache-friendly, parallelizable
- Unity DOTS (Job System + Burst + ECS)
- **Limit:** Steep learning curve, harder to iterate on narrative/gameplay logic

### Hybrid ECS (Recommended for most open-world games)
**Best for:** Games with both heavy simulation AND narrative
- Combat/world = ECS (thousands of NPCs, horses, projectiles)
- Player/narrative/UI = Traditional GameObject-based (developer needs fast iteration)
- Unity Hybrid ECS bridges both worlds

## Project Structure Patterns

### Flat Script Organization (simple projects)
```
Scripts/
├── Core/
├── Player/
├── Combat/
└── UI/
```

### Namespace + Subfolder (recommended for medium/large projects)
```
Scripts/
├── TheHolylands.Core/
│   ├── Persistence/
│   ├── EventSystem/
│   └── Diagnostics/
├── TheHolylands.Player/
│   ├── Movement/
│   ├── Combat/
│   └── Interaction/
├── TheHolylands.World/
│   ├── TimeWeather/
│   ├── Environment/
│   └── PointsOfInterest/
└── TheHolylands.UI/
```

## Data-Driven Design with ScriptableObjects

### Pattern: SO as Game Data
```csharp
[CreateAssetMenu(fileName = "NewWeapon", menuName = "Data/Weapon")]
public class WeaponDataSO : ScriptableObject {
    public string displayName;
    public DamageType damageType;
    public Vector2 damageRange;
    public float speed;
    public float windup;
    public float staminaCost;
    public HitboxDefinition hitbox;
}
```

**Pros:** Designer-friendly, no code changes needed for new content, serializable, asset-based
**Cons:** Not great for complex behavior (use ScriptableObject + C# handler instead)

### Pattern: Data + Handler Split
```csharp
// WeaponDataSO defines: damage, speed, stamina cost
// WeaponHandler implements: hit detection, animation triggers, effects
```
This separates **what** (data) from **how** (code).

## Streaming Patterns

### Unity Addressables
- Load/unload assets by string key
- Supports bundles, packages, async loading
- **Best for:** City scenes, character models, audio, textures
- **Caveat:** Debugging broken keys is hard — use `AddressableAssetSettings.CreateGroup`

### AsyncSceneLoading
- For seamless travel between zones
- Load next zone in background, swap when ready
- **Best for:** Open world, no loading screens

### Level-of-Detail (LOD)
- Unity `LODGroup` component on meshes
- 4 levels: Combat (highest) → Near → Far → Billboard
- Auto-switches based on camera distance
- **Critical for performance on open worlds**

## Navigation Patterns

### NavMesh for Cities
- Standard Unity NavMesh for stone/cobble terrain
- Works well for structured environments

### Custom NavMesh for Desert
- Sand has different movement costs, different AI behavior
- Options:
  1. **NavMesh with area cost** — bake separate NavMesh layers, weight sand higher
  2. **Graph-based pathfinding** — A* on a grid graph (A* Pathfinding Project package)
  3. **Hybrid** — NavMesh for cities, A* for wilderness

## Animation Patterns

### Layered Animator Controller
```
Layer 0: Base Movement (walk, run, sprint)
Layer 1: Combat (attack, block, parry)
Layer 2: Interaction (pick up, use, talk)
Layer 3: Overlay (death, hurt, fatigue)
```

### Blend Trees
- For stance transitions (Guard → Strike)
- Blend by float parameter (stance blend value)

### Animation Rigging Package
- Procedural sword pointing (IK on hand)
- Shield blocking (IK on shield arm)
- Horse rearing (procedural leg positioning)

## Save/Load Patterns

### Binary Serialization
- Custom binary format (not JSON)
- Faster serialization, smaller file size
- **Caveat:** Version management is critical

### Chunk-Based Saves
- Save only changed chunks (player state, quest state, world state)
- Don't serialize the whole world
- **Best for:** Open-world games where the world is mostly static

### Versioned Save Format
```csharp
public struct SaveChunk {
    public int version; // Increment when format changes
    public int checksum;
    public byte[] data;
}
```
Forward compatibility: always read latest, convert old versions on load.

## Performance Patterns

### Object Pooling
- Pre-allocate bullets, effects, particles
- **Critical for combat systems with thousands of active objects**

### Instancing
- GPU instancing for repeated assets (columns, arches, trees)
- Unity's `MeshRenderer` + `MaterialPropertyBlock` for varied instances

### Async Initialization
- Don't block the main thread on startup
- Load addressables asynchronously
- Show loading screen while world streams in

## Debugging Patterns

### Event Logger
- Central event bus that logs all game events
- Useful for tracing bugs without debug UI

### In-Game Profiler
- Custom overlay showing FPS, entity count, memory, draw calls
- Toggle with debug key (e.g., `Ctrl+P`)

### State Snapshot
- Save/load full game state snapshot for debugging
- Useful for reproducing bugs: "I was at the Jerusalem market when..."
