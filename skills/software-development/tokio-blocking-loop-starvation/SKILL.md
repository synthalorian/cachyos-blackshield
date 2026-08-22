---
name: tokio-blocking-loop-starvation
description: Use when tokio mpsc send succeeds but recv never fires.
tags: [tokio, rust, async, mpsc, pcap, starvation, spawn_blocking, debugging]
triggers: ["tokio mpsc send succeeds but recv never fires", "pcap next_packet in tokio task", "async task never yields starvation", "worker task silent while producer logs healthy", "blocking sync call inside tokio::spawn"]
---

# Tokio Blocking-Loop Starvation

## Symptom

A pipeline like `producer task → tokio::mpsc → worker task` silently stalls:
- Producer logs look 100% healthy (sends succeed, no errors)
- The receiver task spawns fine, enters `recv().await` — and NEVER wakes
- No panics, no errors, no logs on the consumer side. Bounded channel may
  eventually fill and freeze the producer too (count freezes at capacity).

## Root cause

The producer task contains a **synchronous blocking call inside its loop**
(e.g. pcap's `cap.next_packet()`). The task's `poll()` never returns
`Pending` — it pins a runtime worker thread forever. When `send()` wakes the
receiver, the receiver task lands in the pinned worker's local queue and is
never polled. Runtime stays "healthy" (other tasks, heartbeats, timers all
fine — this is the misleading part), yet cross-task channel wakes starve.

Reproduced with tokio multi-thread on a 12-core machine, 2026-08
(AlbionOnline-Translator). A 30-line repro: one task loops
`thread::sleep + tx.send().await`, another `rx.recv().await` — recv never
fires.

## Diagnosis

1. Instrument BOTH sides: debug! at send site and as the FIRST statement of
   the consumer. Send fires, recv doesn't → starvation.
2. Heartbeat task (`loop { sleep(2s); log }`) still prints → runtime itself
   is alive, which rules out "whole runtime wedged" and points here.
3. If consumer is silent: count producer outputs — if the count freezes at
   exactly the channel capacity (e.g. 64), the queue filled and the producer
   is now blocked on send too.
4. Minimal repro in isolation before touching production code — 30 lines
   confirms/denies the runtime mechanics vs app-specific logic.

## Fix

Move the blocking loop off the async executor:

```rust
// BAD: blocks a runtime worker forever, starves mpsc receivers
tokio::spawn(async move {
    while running.load(Ordering::SeqCst) {
        match cap.next_packet() {           // sync blocking syscall
            Ok(packet) => { raw_tx.send(msg).await; }
        }
    }
});

// GOOD: blocking pool thread + blocking_send (natural backpressure)
tokio::task::spawn_blocking(move || {
    while running.load(Ordering::SeqCst) {
        match cap.next_packet() {
            Ok(packet) => { raw_tx.blocking_send(msg); }  // not .await
        }
    }
});
```

Notes:
- `blocking_send` panics if called from an async context — inside
  `spawn_blocking`'s sync closure it's correct.
- Lighter band-aid: `tokio::task::yield_now().await` after each send forces
  the poll to return so the runtime drains queues. Works but keeps an
  illegal blocking call on the executor — prefer spawn_blocking.
- Any sync blocking source behaves the same: pcap, serial ports, file reads
  in a tight loop, `std::net` sockets, gamepad/hid polling.

## Related pitfall

Network calls in a single-sequential-worker loop MUST have a timeout:
`reqwest::Client::builder().timeout(5s)`. One hung request silently kills
the worker forever — same "no logs, no errors" signature.
