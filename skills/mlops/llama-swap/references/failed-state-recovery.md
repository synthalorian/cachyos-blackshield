# llama-swap Failed-State Recovery

## The Error

When a `llama-server` child process crashes on spawn, llama-swap marks the model as:

```
unable to start process: process is in a failed state and can not be restarted
```

The daemon returns this on **every subsequent request** to that model, even if the root cause has been fixed.

## Recovery

```bash
systemctl --user restart llama-swap
```

This clears the in-memory failure cache. The daemon does NOT have a per-model reset endpoint — full restart is the only recovery path.

## Root-Cause Diagnosis (before restarting)

1. Extract the exact `cmd` from config.yaml for the failed model
2. Run it directly in a terminal (or background process) to see the real error:
   ```bash
   /path/to/llama-server --model /path/to/model.gguf --port 8099 ...
   ```
3. Common crash causes:
   - **Corrupt GGUF** — `llama_model_loader: error loading model` — re-download
   - **GPU OOM** — `CUDA OOM` / `Vulkan: failed to allocate` — reduce `--n-gpu-layers` or `--ctx-size`
   - **Wrong binary** — binary compiled without GPU backend trying GPU layers — use the correct build
   - **Missing template** — `--chat-template-file` path doesn't exist — use absolute path

## Prevention

- Always test a new model's cmd directly before adding it to llama-swap config
- Start with small `--ctx-size` (4096) for testing, then scale up
- Keep `--n-gpu-layers` conservative for the GPU's VRAM budget
