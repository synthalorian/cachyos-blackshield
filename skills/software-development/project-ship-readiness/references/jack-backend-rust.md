# JACK Backend Implementation in Rust (jack crate 0.9)

Complete pattern for implementing a real JACK audio client that shows up in qpwgraph / Catia with named stereo ports.

## The `jack` crate API (0.9)

### Key types
- `jack::Client` — inactive client, used to register ports
- `jack::AsyncClient<N, P>` — activated client running a process callback
- `jack::ProcessHandler` — trait for the real-time audio callback
- `jack::Port<AudioIn>` / `jack::Port<AudioOut>` — audio ports
- `jack::ProcessScope` — provides buffer access during the callback
- `jack::AudioIn` / `jack::AudioOut` — port spec types (unit structs, no `default()`)

### Full implementation

```rust
use std::sync::{Arc, Mutex};
use anyhow::Result;

/// Custom ProcessHandler that holds the DSP engine and port references.
pub struct JackProcessHandler {
    engine: Arc<Mutex<MyEngine>>,
    cpu_load: Option<Arc<std::sync::atomic::AtomicU64>>,
    sample_rate: f64,
    in_l: jack::Port<jack::AudioIn>,
    in_r: jack::Port<jack::AudioIn>,
    out_l: jack::Port<jack::AudioOut>,
    out_r: jack::Port<jack::AudioOut>,
}

impl jack::ProcessHandler for JackProcessHandler {
    fn process(
        &mut self,
        _client: &jack::Client,
        ps: &jack::ProcessScope,
    ) -> jack::Control {
        let start = std::time::Instant::now();

        // Get port buffers
        let in_l_buf = self.in_l.as_slice(ps);
        let in_r_buf = self.in_r.as_slice(ps);
        let out_l_buf = self.out_l.as_mut_slice(ps);
        let out_r_buf = self.out_r.as_mut_slice(ps);

        let n = ps.n_frames() as usize;

        // Mix stereo input to mono for the engine
        let mut mono_in = vec![0.0f32; n];
        for i in 0..n {
            mono_in[i] = (in_l_buf[i] + in_r_buf[i]) * 0.5;
        }

        let mut mono_out = vec![0.0f32; n];

        // Run DSP (try_lock to avoid blocking the real-time thread)
        if let Ok(mut eng) = self.engine.try_lock() {
            let _ = eng.process(&mono_in, &mut mono_out);
        }

        // Copy mono output to both stereo channels
        out_l_buf[..n].copy_from_slice(&mono_out[..n]);
        out_r_buf[..n].copy_from_slice(&mono_out[..n]);

        // CPU load tracking
        let elapsed = start.elapsed().as_secs_f64();
        let budget = n as f64 / self.sample_rate;
        let pct = ((elapsed / budget) * 1000.0).min(100_000.0) as u64;
        if let Some(ref atomic) = self.cpu_load {
            atomic.store(pct, std::sync::atomic::Ordering::Relaxed);
        }

        jack::Control::Continue
    }
}

/// JACK audio I/O client.
pub struct JackAudioIO {
    active_client: Option<jack::AsyncClient<(), JackProcessHandler>>,
    config: JackConfig,
    active: bool,
}

#[derive(Debug, Clone)]
pub struct JackConfig {
    pub client_name: String,
}

impl JackAudioIO {
    pub fn new(config: JackConfig) -> Self {
        Self {
            active_client: None,
            config,
            active: false,
        }
    }

    pub fn start(
        &mut self,
        engine: Arc<Mutex<MyEngine>>,
        cpu_load: Option<Arc<std::sync::atomic::AtomicU64>>,
    ) -> Result<()> {
        self.stop();

        let (client, _status) = jack::Client::new(
            &self.config.client_name,
            jack::ClientOptions::NO_START_SERVER,
        )
        .map_err(|e| anyhow::anyhow!("Failed to create JACK client: {:?}", e))?;

        let sample_rate = client.sample_rate() as f64;
        let buffer_size = client.buffer_size();

        // Register stereo ports
        let in_l = client
            .register_port("in_l", jack::AudioIn)
            .context("Failed to register JACK input port in_l")?;
        let in_r = client
            .register_port("in_r", jack::AudioIn)
            .context("Failed to register JACK input port in_r")?;
        let out_l = client
            .register_port("out_l", jack::AudioOut)
            .context("Failed to register JACK output port out_l")?;
        let out_r = client
            .register_port("out_r", jack::AudioOut)
            .context("Failed to register JACK output port out_r")?;

        // Initialize engine at JACK's sample rate / buffer size
        {
            let mut eng = engine
                .lock()
                .map_err(|e| anyhow::anyhow!("{}", e))?;
            eng.init(sample_rate, buffer_size as u32)
                .map_err(|e| anyhow::anyhow!("Engine init failed: {}", e))?;
        }

        let handler = JackProcessHandler {
            engine: engine.clone(),
            cpu_load,
            sample_rate,
            in_l,
            in_r,
            out_l,
            out_r,
        };

        let active_client = client
            .activate_async((), handler)
            .map_err(|e| anyhow::anyhow!("Failed to activate JACK client: {:?}", e))?;

        self.active_client = Some(active_client);
        self.active = true;

        Ok(())
    }

    pub fn stop(&mut self) {
        if let Some(client) = self.active_client.take() {
            let _ = client.deactivate();
        }
        self.active = false;
    }

    pub fn is_active(&self) -> bool {
        self.active
    }
}
```

## Critical details

### Port registration
- Use `jack::AudioIn` and `jack::AudioOut` (unit structs) — NOT `jack::AudioIn::default()`
- Clippy will flag `default()` on unit structs as `default_constructed_unit_structs`
- Port names appear in qpwgraph as `ClientName:port_name` (e.g., `Kicks:in_l`)

### ProcessHandler trait
- `process(&mut self, client: &Client, ps: &ProcessScope) -> Control`
- Must be real-time safe: no allocations, no mutex locks that could block
- Use `try_lock()` on the engine mutex, not `lock()`
- Return `jack::Control::Continue` to keep running, `Control::Quit` to stop

### Buffer access
- `port.as_slice(ps)` returns `&[f32]` for input ports
- `port.as_mut_slice(ps)` returns `&mut [f32]` for output ports
- Both assert the port belongs to the same client as the process scope
- Buffer length = `ps.n_frames() as usize`

### Activation lifecycle
1. `jack::Client::new(name, NO_START_SERVER)` — create inactive client
2. `client.register_port(name, spec)` — register ports
3. `client.activate_async(notification_handler, process_handler)` — start processing
4. `active_client.deactivate()` — stop processing (returns `Result<(Client, N, P), Error>`)

### Error handling
- `Client::new` returns `Result<(Client, ClientStatus), ClientError>`
- `register_port` returns `Result<Port<T>, Error>`
- `activate_async` returns `Result<AsyncClient<N, P>, Error>`
- All errors should be mapped to `anyhow::Error` with context

### Feature gating
When the `jack` dependency is optional:
```rust
#[cfg(feature = "jack-backend")]
pub struct JackAudioIO { /* real implementation */ }

#[cfg(not(feature = "jack-backend"))]
pub struct JackAudioIO { /* no-op stub */ }
```

## Common mistakes

1. **Forgetting to `use` `JackConfig`** — The `jack` crate exports `AsyncClient` and `ClosureProcessHandler` but NOT a config struct. You define your own.

2. **Moving ports into the handler** — Ports are moved into `JackProcessHandler` which is then consumed by `activate_async`. You cannot store them separately in `JackAudioIO` after activation.

3. **Using `lock()` instead of `try_lock()` in the process callback** — `lock()` can block the real-time thread, causing xruns. Always use `try_lock()` and handle the failure gracefully (e.g., output silence).

4. **Allocating in the process callback** — `vec![0.0f32; n]` allocates. Pre-allocate buffers in the handler struct and reuse them, or use stack arrays if buffer size is known at compile time.

5. **Wrong `AsyncClient` type parameters** — `AsyncClient<(), JackProcessHandler>` where `()` is the notification handler type. If you use `ClosureProcessHandler`, the type becomes `AsyncClient<(), ClosureProcessHandler<F>>` which is hard to store. Define a custom `ProcessHandler` struct instead.

## Testing

JACK requires a running JACK server (or PipeWire with JACK emulation). In CI:
- Install `libjack-jackd2-dev` (Ubuntu) or `jack` (Arch)
- The `jack` crate's doctests require a JACK server — mark them ````ignore` or run with `jackd` in the background
- Unit tests for the process callback can use mock buffers without a real JACK server

## Cargo.toml setup

```toml
[dependencies]
jack = { version = "0.9", optional = true }

[features]
default = ["jack-backend"]
jack-backend = ["dep:jack"]
```
