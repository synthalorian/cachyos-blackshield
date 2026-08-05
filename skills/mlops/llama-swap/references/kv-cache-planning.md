# KV Cache Planning for Hybrid Attention Models

## Quick Reference

Only **full attention layers** allocate KV cache. **DeltaNet (linear attention)** layers use a fixed-size state independent of context length.

## Formula

```
KV_per_token_bytes = full_attn_layers × 2 (K+V) × n_kv_heads × head_dim
```

Divide by N for quantized cache:
- q8_0: ×1 (full byte)
- q4_0: ×0.5 (4-bit)

## Calculator Script (runnable via terminal)

```bash
# Usage: kv-calc <full_attn_layers> <n_kv_heads> <head_dim>
kv_calc() {
    local layers=$1 kv=$2 hd=$3
    local per_token_bytes=$(( layers * 2 * kv * hd ))
    echo "Full attn layers: $layers"
    echo "KV heads: $kv | Head dim: $hd"
    echo "q8_0: $(( per_token_bytes / 1024 )) KB/token"
    echo "q4_0: $(( per_token_bytes / 2048 )) KB/token"
    for ctx in 131072 262144 524288 1048576; do
        local gb_q8=$(echo "scale=2; $per_token_bytes * $ctx / 1073741824" | bc)
        local gb_q4=$(echo "scale=2; $per_token_bytes * $ctx / 2147483648" | bc)
        echo "  $((ctx/1024))k: ${gb_q8}G (q8) / ${gb_q4}G (q4)"
    done
}

# Example: Qwen3.5-9B (8 full, 4 kv, 256 dim)
kv_calc 8 4 256
```

## Known Values (this system)

| Model | Full | Linear | KV heads | Head dim | KB/tok q8 | 128k | 256k | 512k |
|-------|:---:|:---:|:---:|:---:|:---:|:---:|:---:|:---:|
| Qwen3.5-9B | 8 | 24 | 4 | 256 | 16 | 2.0G | 4.0G | 8.0G |
| synthclaw-35b-128k (dense) | 16 | 48 | 4 | 256 | 32 | 4.0G | 8.0G | 16.0G |
