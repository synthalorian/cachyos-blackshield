# JACK Audio Backend Pattern for Tauri/Rust Apps

## Context

When building a Tauri desktop app that needs to function as a pro-audio application on Linux (guitar amp sim, DAW plugin host, audio workstation), CPAL's default ALSA backend won't show up in JACK patchbays like qpwgraph or Catia. You need a native JACK client.

## The jack Crate API (0.9)

### The Core Problem

`jack::ClosureProcessHandler::new()` takes a closure. If you try to capture `Port<AudioIn>` or `Port<AudioOut>` in that closure, the closure's type becomes unnameable. `AsyncClient<N, P>` requires `P: 'static + Send + ProcessHandler`, but `ClosureProcessHandler<{closure}>` has an anonymous type that can't be named for struct fields or type parameters.

**Attempt that fails:**
```rust
// This compiles but can't be stored in JackAudioIO
let process = jack::ClosureProcessHandler::new(
    move |_: &Client, ps: &ProcessScope| -> Control {
        let buf = in_l.as_slice(ps);  // in_l captured from outer scope
        // ...
    }
);
// Type of `process` is ClosureProcessHandler<{unique closure type}>
// Can't write: active_client: Option<AsyncClient<(), ClosureProcessHandler<...>>>
```

### The Working Pattern: Custom ProcessHandler Struct

```rust
use jack::{Client, Control, ProcessHandler, ProcessScope, Port, AudioIn, AudioOut};
use std::sync::{Arc, Mutex};

pub struct JackProcessHandler {
    engine: Arc<Mutex<MyEngine>>,
    cpu_load: Option<Arc<std::sync::atomic::AtomicU64>>,
    sample_rate: f64,
    in_l: Port<AudioIn>,
    in_r: Port<AudioIn>,
    out_l: Port<AudioOut>,
    out_r: Port<AudioOut>,
}

impl ProcessHandler for JackProcessHandler {
    fn process(&mut self, _client: &Client, ps: &ProcessScope) -> Control {
        let start = std::time::Instant::now();

        let in_l_buf = self.in_l.as_slice(ps);
        let in_r_buf = self.in_r.as_slice(ps);
        let out_l_buf = self.out_l.as_mut_slice(ps);
        let out_r_buf = self.out_r.as_mut_slice(ps);

        let n = ps.n_frames() as usize;

        // Mix stereo to mono for engine
        let mut mono_in = vec![0.0f32; n];
        for i in 0..n {
            mono_in[i] = (in_l_buf[i] + in_r_buf[i]) * 0.5;
        }

        let mut mono_out = vec![0.0f32; n];

        if let Ok(mut eng) = self.engine.try_lock() {
            let _ = eng.process(&mono_in, &mut mono_out);
        }

        // Copy mono output to stereo
        for i in 0..n {
            out_l_buf[i] = mono_out[i];
            out_r_buf[i] = mono_out[i];
        }

        // CPU load tracking
        let elapsed = start.elapsed().as_secs_f64();
        let budget = n as f64 / self.sample_rate;
        let pct = ((elapsed / budget) * 1000.0).min(100_000.0) as u64;
        if let Some(ref atomic) = self.cpu_load {
            atomic.store(pct, std::sync::atomic::Ordering::Relaxed);
        }

        Control::Continue
    }
}
```

### Activation Lifecycle

```rust
pub struct JackAudioIO {
    active_client: Option<jack::AsyncClient<(), JackProcessHandler>>,
    config: JackConfig,
    active: bool,
}

impl JackAudioIO {
    pub fn start(&mut self, engine: Arc<Mutex<MyEngine>>, cpu_load: Option<Arc<AtomicU64>>) -> Result<()> {
        self.stop();

        let (client, _status) = jack::Client::new(
            &self.config.client_name,
            jack::ClientOptions::NO_START_SERVER,
        ).map_err(|e| anyhow::anyhow!("JACK client creation failed: {:?}", e))?;

        let sample_rate = client.sample_rate() as f64;
        let buffer_size = client.buffer_size() as u32;

        // Register ports BEFORE activation
        let in_l = client.register_port("in_l", jack::AudioIn::default())?;
        let in_r = client.register_port("in_r", jack::AudioIn::default())?;
        let out_l = client.register_port("out_l", jack::AudioOut::default())?;
        let out_r = client.register_port("out_r", jack::AudioOut::default())?;

        // Init engine at JACK's sample rate
        {
            let mut eng = engine.lock().map_err(|e| anyhow::anyhow!("{}", e))?;
            eng.init(sample_rate, buffer_size)
                .map_err(|e| anyhow::anyhow!("Engine init: {}", e))?;
        }

        // Move ports INTO the handler, then activate
        let process = JackProcessHandler {
            engine: engine.clone(),
            cpu_load,
            sample_rate,
            in_l, in_r, out_l, out_r,
        };

        let active_client = client
            .activate_async((), process)
            .map_err(|e| anyhow::anyhow!("JACK activation failed: {:?}", e))?;

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
}
```

### Critical Rules

1. **Register ports before activation** — `client.register_port()` only works on inactive clients
2. **Move ports into handler** — don't store them separately; `AsyncClient` owns the handler
3. **Port naming** — use `in_l`, `in_r`, `out_l`, `out_r` for clarity in patchbays
4. **Client name** — this is what appears in qpwgraph. Use a short, recognizable name like "Kicks"
5. **`NO_START_SERVER`** — don't auto-start jackd; let PipeWire/JACK handle it
6. **Error handling** — `Client::new()` returns `Result<(Client, ClientStatus), ClientError>`, not `Result<Client, Error>`

### Cargo.toml Feature Gating

```toml
[features]
default = ["jack-backend", "cpal-backend"]
jack-backend = ["dep:jack"]
cpal-backend = ["dep:cpal", "dep:ringbuf"]
```

The JACK code is wrapped in `#[cfg(feature = "jack-backend")]` so it compiles on macOS/Windows where JACK may not be available.

### System Dependencies (Arch Linux)

```bash
sudo pacman -S pipewire-jack pipewire-audio jack2
# For development/compilation:
sudo pacman -S jack2 libjack.so  # provides jack.h and libjack.so
```

On PipeWire systems, `pipewire-jack` provides the JACK API. No need to run `jackd` separately.

### Verification Commands

```bash
# List JACK clients
jack_lsp

# Look for your app
jack_lsp | grep -i kicks
# Kicks:in_l
# Kicks:in_r
# Kicks:out_l
# Kicks:out_r

# Check if client is active
jack_lsp -c | grep Kicks

# In qpwgraph: look for "Kicks" node, connect capture -> Kicks:in, Kicks:out -> playback
```

### Common Errors

| Error | Cause | Fix |
|-------|-------|-----|
| `cannot find type ActiveClient in crate jack` | Using wrong type name | It's `AsyncClient<N, P>`, not `ActiveClient` |
| `the trait bound Box<ClosureProcessHandler<...>>: ProcessHandler is not satisfied` | Boxing doesn't help | Use custom struct instead of closure |
| `use of moved value: in_l` | Trying to store port in struct AND handler | Move into handler only; don't keep separate copy |
| `? couldn't convert the error: String: StdError` | Using `.map_err(|e| e.to_string())?` with anyhow | Use `.map_err(|e| anyhow::anyhow!("{}", e))?` |
| `Failed to create JACK client` | JACK server not running | Start PipeWire or jack2 |
| `Failed to register JACK input port in_l` | Port name collision | Use unique client name or check existing ports |

## Related

- `jack` crate docs: https://docs.rs/jack/0.9.2/jack/
- PipeWire JACK compatibility: https://docs.pipewire.org/page_pipewire_jack.html
- qpwgraph: https://gitlab.freedesktop.org/rncbc/qpwgraph
