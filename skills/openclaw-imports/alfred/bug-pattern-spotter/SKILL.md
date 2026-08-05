# Bug Pattern Spotter Skill

## Purpose
Identify common bug patterns and prevent recurrence.

## Triggers
- "Alfred, what's wrong with..."
- "Alfred, why does this crash"
- "Alfred, debug this"

## Common Patterns by Engine

### Unity
- **Null Reference in Awake/Start:** Initialization order issues
- **Missing SerializeField:** Inspector values not persisting
- **Animation Event Timing:** Events firing before references set
- **Coroutines Stopping:** GameObject disabled/destroyed
- **Physics Tunneling:** Fixed timestep too large
- **Memory Leaks:** Static references, events not unsubscribed

### Godot
- **Node Path Changes:** Moving nodes breaks @onready
- **Signal Connection Leaks:** Not disconnecting in _exit_tree
- **Resource Sharing:** Modifying shared resources unintentionally
- **Thread Safety:** Accessing nodes from threads
- **Call Deferred Issues:** Timing-dependent code

### Unreal
- **Soft vs Hard References:** Assets loading at wrong time
- **Blueprint Null Checks:** Missing IsValid checks
- **Replication Order:** Client/server timing
- **Garbage Collection:** Raw pointers vs smart pointers
- **Construction Script Loops:** Infinite recursion

## Diagnostic Questions

1. When does the bug occur? (Start, runtime, scene change)
2. What was recently changed?
3. Are there null references in the console?
4. Does it happen consistently or intermittently?
5. Single player or multiplayer?

## Output Format

```
## Bug Analysis

**Likely Cause:** [Primary suspect]
**Confidence:** [High/Medium/Low]

### Suspected Pattern
[Pattern name and description]

### Evidence
- [Observation 1]
- [Observation 2]

### Diagnostic Steps
1. [Step to verify cause]
2. [Step to isolate issue]

### Recommended Fix
```
[Code fix]
```

### Prevention
[How to avoid this pattern in future]
```

## Example

**User:** "Alfred, my enemy crashes when I swap weapons"

**Alfred:** "I've analyzed the pattern, sir.

**Likely Cause:** Animation event timing - weapon swap animation event fires before new weapon reference is assigned.
**Confidence:** High

### Evidence
- Crash happens during weapon swap
- Null reference in attack animation event
- Swap animation is 0.3s, event fires at 0.15s

### Diagnostic Steps
1. Add null check in animation event handler
2. Log weapon reference state during swap

### Recommended Fix
```csharp
// In animation event handler
public void OnAttackAnimationEvent()
{
    if (currentWeapon == null)
    {
        Debug.LogWarning("Weapon reference null during attack");
        return;
    }
    currentWeapon.Attack();
}
```

### Better Solution
Use animation events to set a flag, check in Update():
```csharp
private bool attackQueued;

public void OnAttackAnimationEvent() => attackQueued = true;

void Update()
{
    if (attackQueued && currentWeapon != null)
    {
        currentWeapon.Attack();
        attackQueued = false;
    }
}
```

Shall I implement the full fix?"
