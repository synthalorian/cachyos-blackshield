# Master Plan Cross-Reference — Pattern Example

This reference shows the methodology from Section 1 Phase A.5 applied to an actual Unity project audit. Use it as a template for any project with a `docs/MASTER_PLAN.md` or embedded bug list.

## Source: Holy Lands (Crusades RPG)

The master plan claimed these "Files That Need Fixing Immediately":

### 1. PlayerController — has two Update() methods

**Plan claim**: Two Update() methods (lines 71 and 210)

**Code reality**: ✅ **Already fixed**. Only one Update() at line 83. The duplicate was removed in a prior commit.

### 2. InputManager — E/East key collision

**Plan claim**: Five actions all bound to E/East: Interact, Talk, Trade, Craft, FastTravel

**Code reality**: 🔍 **Different than claimed**. On keyboard the keys are unique (E/T/X/C/F). The collision is on `<Gamepad>/West` — shared by UseItem, Talk, and Craft. Plan correctly identified the problem class but wrong button.

### 3. UIManager subscribes to nonexistent event

**Plan claim**: `GameEvent.PlayerHealthChanged` doesn't exist in the GameEvent struct

**Code reality**: ❓ **Already correct**. `PlayerHealthChanged = new(30)` exists at line 41 of GameEvent.cs. Event struct was updated.

### 4. CombatController.Riposte() typo

**Plan claim**: Variable `ripostDamage` is undefined (typo)

**Code reality**: ✅ **Already fixed** for a different reason: the variable is `riposteDamage` (line 249), which was always valid. The plan misidentified the typo location.

### 5. WorldSystem — HasTemple duplicate

**Plan claim**: `HasTemple` defined twice in Jerusalem and Acre region data

**Code reality**: ❓ **Pattern is fine**. Each RegionData defines `HasTemple` once per region. Jerusalem has `= true`, Acre has `= false`. No actual duplication — the plan confused "defined in multiple regions" with "defined twice in the same scope."

### 6. ProgressionManager — double closing brace

**Plan claim**: Double `}}` at end of file (line 312)

**Code reality**: ✅ **Valid C#**. The outer `}` closes the namespace, not the class. `[System.Serializable]` on line 292 is declarative outside the class body — valid C# syntax for struct definitions in namespaces.

## Additional Bugs Found (not in the plan)

| Bug | File | Details |
|-----|------|---------|
| Dual stamina management | PlayerController + MovementController + CombatController | Three systems track `_stamina` independently. None sync to the others. Values will drift every frame. |
| Damage computed, never applied | CombatController.Attack() | Computes `totalDamage` with stance, weapon, armor penetration — then `Debug.Log()` and returns. Never calls `TakeDamage()` on the target. |
| NRE on event subscription | EnemyController.OnPlayerMoved() | Accesses `target.position` in event handler, but `target` may not be set yet (set externally via `SetTarget()`). |
| Dead directory | root | `{Assets/` folder with braces in name, all empty stub directories. Won't import in Unity, should be deleted. |
