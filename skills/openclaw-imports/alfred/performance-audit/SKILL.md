# Performance Audit Skill

## Purpose
Identify performance bottlenecks before they ship.

## Triggers
- "Alfred, optimize this"
- "Alfred, performance check"
- "Why is this slow?"

## Engine-Specific Checks

### Unity
- [ ] Update() doing expensive operations
- [ ] Find(), FindObjectOfType() in hot paths
- [ ] String concatenation in Update()
- [ ] Missing LOD on 3D models
- [ ] No object pooling for frequent spawns
- [ ] Excessive garbage generation
- [ ] Unbatched draw calls
- [ ] Physics queries without layer masks
- [ ] Coroutines without yield breaks
- [ ] SendMessage() usage

### Godot
- [ ] _process() doing unnecessary work
- [ ] Signal connection leaks
- [ ] Unset_process(false) when not needed
- [ ] Node path strings instead of cached references
- [ ] Creating nodes instead of pooling
- [ ] Heavy calculations in _physics_process
- [ ] Shader overhead (too many uniforms)
- [ ] TileMap culling issues

### Unreal
- [ ] Tick on everything (use TickInterval)
- [ ] Blueprint-heavy logic (move to C++)
- [ ] Draw call count (mesh merging)
- [ ] Niagara overuse
- [ ] Lumen performance cost
- [ ] Replication bandwidth
- [ ] Heavy construction scripts
- [ ] Collision complexity

## Output Format

```
## Performance Audit

**Estimated Impact:** [Low/Medium/High]

### Critical Issues
1. [Issue] - [Estimated FPS impact]
   - Fix: [Solution]

### Moderate Issues
1. [Issue] - [Estimated FPS impact]
   - Fix: [Solution]

### Quick Wins
- [Easy optimization with immediate benefit]

### Profiling Recommendations
- [Which tools to use, what to measure]
```

## Example

**User:** "Alfred, my game is running at 30fps, help"

**Alfred:** "Let me audit your performance, sir.

### Critical Issues
1. **EnemyAI.Update()** - ~15 FPS impact
   - 150 enemies × Find() calls per frame
   - Fix: Cache player reference, use manager-based tick

2. **Projectile spawning** - ~10 FPS impact
   - Instantiate/Destroy overhead
   - Fix: Implement object pool

### Quick Wins
1. Disable tick on enemies beyond 50m
2. Reduce physics solver iterations
3. Batch UI canvas updates

Shall I implement the object pool first? That alone should recover 10-15 FPS."
