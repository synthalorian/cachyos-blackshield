# Architecture Advisor Skill

## Purpose
Suggest architectural improvements based on project scope.

## Triggers
- "Alfred, plan [feature]"
- "Alfred, how should I structure..."
- "Alfred, architecture advice"
- Project grows beyond threshold

## Scale Assessment

### Small Project (< 50 scripts)
- Keep it simple
- Direct references okay
- Single scene/prefab approach

### Medium Project (50-200 scripts)
- Introduce managers/singletons
- Event system for decoupling
- Scene/level streaming

### Large Project (200+ scripts)
- Full ECS/Service Locator
- Modular architecture
- Addressables/asset management
- Save system architecture
- Networking considerations

## Engine-Specific Recommendations

### Unity
- **Small:** MonoBehaviour direct communication
- **Medium:** ScriptableObjects for data, Events for decoupling
- **Large:** DOTS for performance-critical, ScriptableObjects for config

### Godot
- **Small:** Direct node references, signals
- **Medium:** Autoload singletons, resource preloading
- **Large:** Custom resources, scene instancing, plugin architecture

### Unreal
- **Small:** Actor/Component, Blueprints
- **Medium:** Subsystems, C++ base classes
- **Large:** GAS, Plugin modules, C++ core with BP interfaces

## Output Format

```
## Architecture Recommendation

**Project Scale:** [Small/Medium/Large]
**Recommended Pattern:** [Pattern name]

### Proposed Structure
```
[Folder/Class diagram]
```

### Implementation Phases
1. **Phase 1:** [Foundation work]
2. **Phase 2:** [Core systems]
3. **Phase 3:** [Integration]

### Dependencies
- [What must exist first]

### Migration Path
- [How to get from current state to proposed]

### Trade-offs
- **Pros:** [Benefits]
- **Cons:** [Costs]
```

## Example

**User:** "Alfred, I need an inventory system for my RPG"

**Alfred:** "I've designed an inventory architecture for ApocalypseRPG, sir.

**Recommended Pattern:** ScriptableObject-driven with Event System

### Proposed Structure
```
Scripts/
├── Inventory/
│   ├── InventoryData (ScriptableObject)
│   ├── InventorySlot (class)
│   ├── InventoryManager (MonoBehaviour singleton)
│   └── InventoryUI (MonoBehaviour)
├── Items/
│   ├── ItemData (ScriptableObject)
│   ├── WeaponData : ItemData
│   └── ConsumableData : ItemData
└── Events/
    └── InventoryEvents (ScriptableObject events)
```

### Implementation Phases
1. **Phase 1:** ItemData ScriptableObjects + InventorySlot class
2. **Phase 2:** InventoryManager with add/remove/stack logic
3. **Phase 3:** UI integration with drag-drop

Shall I begin with Phase 1?"
