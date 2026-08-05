# Rust HashMap Borrow Scoping Pattern

Session: 2026-05-30, building OpenShark Discord gateway.

## The Problem

You have a struct with a `HashMap` field and need to:
1. Get a mutable reference to a HashMap entry
2. Do some work with that entry
3. Call another method on `self` that doesn't touch the HashMap
4. Continue working with the HashMap entry

This fails because `HashMap::entry()` holds a mutable borrow on the entire HashMap (which is part of `self`), preventing any other `self` method calls:

```rust
pub struct Router {
    channel_history: HashMap<u64, Vec<Message>>,
}

impl Router {
    async fn handle_message(&mut self, channel_id: u64) {
        let history = self.channel_history.entry(channel_id).or_default();
        history.push(msg);
        
        // ERROR: cannot borrow `*self` as immutable because 
        // `self.channel_history` is borrowed as mutable
        let result = self.try_execute_tools("...").await;
        
        history.push(result); // needs the mutable borrow again
    }
}
```

## The Solution: Explicit Borrow Scoping

End the mutable borrow explicitly before calling the `self` method, then re-borrow afterward:

```rust
impl Router {
    async fn handle_message(&mut self, channel_id: u64) {
        // Phase 1: Mutable borrow to set up
        let history = self.channel_history.entry(channel_id).or_default();
        history.push(msg);
        let history_clone = history.clone(); // if needed for the self call
        
        // End the mutable borrow
        let _ = history; // or: drop(history);
        
        // Phase 2: Call self method (no borrow conflict)
        let result = self.try_execute_tools("...").await;
        
        // Phase 3: Re-borrow to continue
        let history = self.channel_history.entry(channel_id).or_default();
        history.push(result);
    }
}
```

## Alternative: Clone-and-Replace

If you need to do significant work without the HashMap:

```rust
// Take ownership of the value temporarily
let mut history = self.channel_history.remove(&channel_id).unwrap_or_default();
history.push(msg);

// Work without any borrow on self.channel_history
let result = self.try_execute_tools("...").await;

history.push(result);

// Put it back
self.channel_history.insert(channel_id, history);
```

## Alternative: RefCell (Runtime Borrow Checking)

If the borrow pattern is too complex for compile-time checking:

```rust
pub struct Router {
    channel_history: RefCell<HashMap<u64, Vec<Message>>>,
}

impl Router {
    async fn handle_message(&self, channel_id: u64) {
        let mut history = self.channel_history.borrow_mut();
        history.entry(channel_id).or_default().push(msg);
        drop(history); // explicit drop
        
        let result = self.try_execute_tools("...").await;
        
        let mut history = self.channel_history.borrow_mut();
        history.entry(channel_id).or_default().push(result);
    }
}
```

**Trade-off:** `RefCell` moves borrow checking to runtime (panics on double-borrow instead of compile errors). Use only when compile-time borrows are intractable.

## When Each Pattern Applies

| Pattern | Use When |
|---------|----------|
| **Explicit scoping** (`let _ = history;`) | Simple case: borrow, release, re-borrow same key |
| **Clone-and-replace** | Need to pass data to `self` method by value |
| **RefCell** | Complex interleaved borrows, recursive structures |

## Key Insight

`HashMap::entry()` borrows the **entire HashMap** mutably, not just the entry. This is because `entry()` may need to reallocate or rehash. Any `&self` or `&mut self` method call while the entry is held will conflict.

The compiler error `E0502` (cannot borrow as immutable because borrowed as mutable) often means you need to restructure borrows, not that your logic is wrong.
