# llama-swap + Ollama Co-Existence — Live Test Data

## Test Setup (2026-05-24)

**Hardware:** AMD Ryzen 7 9800X3D + RX 9070 XT (16 GB VRAM, ROCm RADV gfx1201)  
**Host OS:** Arch Linux + Hyprland (Omarchy)  
**Process layout:**

| Engine | Port | Model | Layers offloaded | Context |
|--------|------|-------|-----------------|---------|
| llama-swap | :8082 | synthclaw 35B MoE IQ3 | 28 | 256K |
| ollama | random | gemma3:4b | 100% GPU | 32K |
| ollama | random | gemma3:12b | 100% GPU | 128K |

**Pre-test VRAM:** `MemAvailable: ~12 GB` (out of 30 GB system)  
**Post-all-loaded:** `MemAvailable: 0 GB` (both processes fully occupy VRAM + system RAM for KV cache)  
**Peak llama-swap memory:** 17.2 GB (resolved from 6.9 GB current)

## Benchmark Results (co-loaded)

Models tested sequentially while both were running; queries to any model completed in ≤16 s.

| Model | Engine | Query | Response Time | Generous verdict |
|-------|--------|-------|--------------|-----------------|
| synthclaw 35B | llama-swap | "Who wrote 1984?" | **0.5 s** | Correct (George Orwell) |
| gemma3:4b | ollama | "Who wrote 1984?" | **2.1 s** | Correct (George Orwell) |
| gemma3:12b | ollama | "Who wrote 1984?" | **12.3 s** | Correct (George Orwell, fuller detail) |

**Math precision:** `142 × 89 = 12,638`

| Model | Answer | Error |
|-------|--------|-------|
| synthclaw 35B (IQ3_S) | 12,638 | 0% |
| gemma3:12b (Q4_K_M) | 12,698 | +0.5% |
| gemma3:4b (Q4_K_M) | 12,778 | +1.1% |

No model is precision-grade for money math. Use cloud for calculation-heavy tasks.

## VRAM Budget Math on 16 GB Card

```
Model weights on card (all layers offloaded) + KV cache ≈ total VRAM consumption

35B MoE @ IQ3_S: 13 GB disk → ~3–5 GB VRAM for active layers only (MoE = sparse)
Gemma3:4b @ Q4:   3.3 GB disk → ~3.3–4 GB VRAM
Gemma3:12b @ Q4:  8.1 GB disk → ~8.1–9 GB VRAM peak (KV cache at 128K context adds ~4 GB)

Combined llama-swap 35B + ollama gemma3:12b = ~12–14 GB effective → leaves 2–4 GB headroom
```

## Prevailing Myth vs. Live Finding

**Myth (old auto-eviction skill opening line):** "Multiple local models can't coexist on 16GB VRAM."  
**Finding:** This is wrong Within a SINGLE orchestrator (llama-swap), requesting model B while A is loaded can OOM — the wrapper is still needed. Across SEPARATE orchestrators (llama-swap + ollama), coexistence works fine. The AMD driver handles the arbitration.

**What changed:** The premise was that `pkill llama-server` was killing ALL llama-server processes across both orchestrators. It does — but that's NOT needed for safe co-existence. The driver reuses VRAM. The wrapper is only useful within llama-swap's own pool to serialize model loads.
