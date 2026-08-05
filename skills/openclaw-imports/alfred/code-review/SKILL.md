# Code Review Skill

## Purpose
Engine-specific code review with actionable feedback and scoring.

## Triggers
- "Alfred, review this code"
- "Alfred, check my work"
- User pastes code for review

## Process

1. **Identify Engine**
   - Unity: .cs files, MonoBehaviour, SerializeField
   - Godot: .gd files, extends Node, @export
   - Unreal: .h/.cpp, UCLASS, UPROPERTY

2. **Apply Engine-Specific Checks**

### Unity Checks
- Update() optimization (avoid Find(), string ops)
- SerializeField usage
- null reference patterns
- Coroutine efficiency
- MonoBehaviour vs ScriptableObject appropriateness
- DOTS/ECS opportunities

### Godot Checks
- _process() overhead
- Signal connection patterns
- @export vs @onready usage
- Typed arrays
- Resource preloading
- Node path references

### Unreal Checks
- Tick overhead (TickInterval)
- UPROPERTY specifications
- Blueprint vs C++ appropriateness
- Replication settings
- GAS integration opportunities
- Memory management (smart pointers)

3. **Score Categories** (1-10)
   - **Performance:** Runtime efficiency
   - **Maintainability:** Readability, structure
   - **Security:** Vulnerabilities (esp. multiplayer)

4. **Output Format**
```
## Code Review Summary

**Engine:** [Unity/Godot/Unreal]
**Overall Score:** X/10

### Scores
- Performance: X/10
- Maintainability: X/10
- Security: X/10

### Issues Found
1. [Line X] - [Issue] - [Severity: High/Med/Low]
   - Fix: [Suggested fix with code]

### Recommendations
- [Improvement suggestions]

### Strengths
- [What's done well]
```

## Example

**User:** "Alfred, review this PlayerController"

**Alfred:** "I've reviewed your PlayerController.cs, sir.

**Overall Score:** 7/10

### Scores
- Performance: 6/10
- Maintainability: 8/10
- Security: 7/10

### Issues Found
1. **Line 45** - `Find("Weapon")` in Update() - **High**
   - Fix: Cache reference in Start() or use SerializeField
   
2. **Line 78** - String concatenation in Update() - **Medium**
   - Fix: Use StringBuilder or only update UI on change

### Recommendations
- Consider ScriptableObject for input bindings
- Object pool your projectiles

### Strengths
- Clean state machine pattern
- Good separation of movement logic

Shall I prepare the refactored version?"
