# LLM Jinja Chat Template: Format Compatibility Guide

## The Core Problem

Custom Jinja chat templates (`--jinja --chat-template-file`) for llama.cpp/llama-swap **must use the format the model was trained on**. Models reproduce training-format tokens literally. If you use a custom token like `<|turn|>` that the model has never seen, it will either:
- Echo the tokens back as gibberish
- Produce malformed output with repeated conversation turns
- Hallucinate into a format it actually knows mid-response

**There is no single universal template format that works for all architectures.**

## Format Reference by Architecture

### Qwen / Qwen 3.x → ChatML (`<|im_start|>` / `<|im_end|>`)

The standard ChatML format. Qwen models were trained on this natively.

```
<|im_start|>system
You are a helpful assistant.<|im_end|>
<|im_start|>user
Hello<|im_end|>
<|im_start|>assistant
Hi there!<|im_end|>
```

**Template pattern:**
```jinja
{{- '<|im_start|>system\n' -}}
{{- system_message -}}
{{- '<|im_end|>\n' -}}
{%- for message in loop_messages -%}
    {{- '<|im_start|>' + role + '\n' -}}
    {{- message['content'] | trim -}}
    {{- '<|im_end|>\n' -}}
{%- endfor -%}
{{- '<|im_start|>assistant\n' -}}
```

**Tool calling format:**
```jinja
{# Tool call by assistant #}
<|im_start|>assistant
{{ reasoning_text }}
Tool: function_name(arg1=val1, arg2=val2)<|im_end|>
{# Tool result #}
<|im_start|>tool
function_name
result_text<|im_end|>
```

**Do NOT use:** Custom tokens like `<|turn|>`, `<|turn|>`, or any non-standard delimiters. The model does not know how to continue from them.

### DeepSeek / DeepSeek-Coder → Plain Text (`User:` / `Assistant:`)

DeepSeek-Coder models use a simple text-based format with no special tokens:

```
You are a coding assistant.

User: Write a function
Assistant: Here is a function...
```

**Template pattern:**
```jinja
{%- for message in loop_messages -%}
    {%- if message['role'] == 'user' -%}
User: {{ message['content'] | trim }}

    {%- elif message['role'] == 'assistant' -%}
Assistant: {{ message['content'] | trim }}{{ eos_token }}

    {%- elif message['role'] == 'tool' -%}
Tool Result: {{ message['content'] | trim }}

    {%- endif -%}
{%- endfor -%}
Assistant:
```

**Tool calling:**
```jinja
Assistant: [Calling tool function_name with arguments {arg1: val1}]{{ eos_token }}

Tool Result: result_text
```

Note: DeepSeek uses `{{ eos_token }}` at the end of assistant turns. Do NOT add `bos_token` or custom delimiters.

### Gemma 2 / Gemma 4 → Llama 3 Style (`<|start_header_id|>` / `<|eot_id|>`)

Gemma models (especially Gemma 4) use the Llama 3 tokenizer format:

```
<|start_header_id|>user<|end_header_id|>

Hello<|eot_id|>
<|start_header_id|>assistant<|end_header_id|>

Hi there!<|eot_id|>
```

**Simplified working template (with system prompt + identity injection):**

```jinja
{{- bos_token }}
{%- if messages[0]['role'] in ['system', 'developer'] -%}
{%- set sys_msg = messages[0]['content'] | trim -%}
{%- set loop_messages = messages[1:] -%}
{%- else -%}
{%- set sys_msg = "" -%}
{%- set loop_messages = messages -%}
{%- endif -%}
{%- for message in loop_messages -%}
{%- if message['role'] == 'user' -%}
<|start_header_id|>user<|end_header_id|>

{%- if sys_msg and loop.first -%}
{{ sys_msg }}

{%- endif -%}
{{ message['content'] | trim }}<|eot_id|>
{%- elif message['role'] == 'assistant' -%}
<|start_header_id|>assistant<|end_header_id|>

{%- if message.get('reasoning') or message.get('reasoning_content') -%}
{{ message.get('reasoning') or message.get('reasoning_content') }}

{%- endif -%}
{{ message['content'] | trim }}<|eot_id|>
{%- elif message['role'] == 'tool' -%}
<|start_header_id|>tool<|end_header_id|>

{{ message['content'] | trim }}
<|eot_id|>
{%- endif -%}
{%- endfor -%}
{%- if add_generation_prompt -%}
<|start_header_id|>assistant<|end_header_id|>

{%- endif -%}
```

**Key details in this template:**
- `bos_token` is emitted at the very start (Gemma models need it)
- System message is merged into the FIRST user turn (Gemma's format doesn't have a separate system role block — the identity comes before the first user message)
- The blank line after `<|end_header_id|>` is REQUIRED (it separates the header from the content)
- Tool calls use `role == 'assistant'` with content describing the call
- Tool responses use `role == 'tool'` with function name + result
- Reasoning content is injected before the main content when present

### Llama 3.x / Meta-Llama → Same as Gemma (Llama 3 Style)

Identical format to Gemma -- `<|start_header_id|>` / `<|end_header_id|>` / `<|eot_id|>`.

## Injecting Custom Identity (System Prompt)

All formats support injecting a custom system prompt / identity. Place it at the start, right after the bos_token / system header. The approach differs by format:

### ChatML (Qwen)
```jinja
{{- '<|im_start|>system\n' -}}
{{- synthclaw_identity -}}
{%- if messages[0]['role'] == 'system' -%}
{{- '\n\n' + messages[0]['content'] | trim -}}
{%- endif -%}
{{- '<|im_end|>\n' -}}
```

### Plain Text (DeepSeek)
```jinja
{%- set combined = synthclaw_identity -%}
{%- if messages[0]['role'] in ['system', 'developer'] -%}
    {%- set combined = synthclaw_identity ~ '\n\n' ~ messages[0]['content'] | trim -%}
    {%- set loop_messages = messages[1:] -%}
{%- endif -%}
{{ combined }}
```

### Llama 3 Style (Gemma) — merged into first user turn
```jinja
{# Gemma has no separate system block — merge identity into first user turn #}
{%- set sys_msg = "" -%}
{%- if messages[0]['role'] in ['system', 'developer'] -%}
    {%- set sys_msg = messages[0]['content'] | trim -%}
    {%- set loop_messages = messages[1:] -%}
{%- endif -%}
{%- for message in loop_messages -%}
{%- if message['role'] == 'user' and loop.first -%}
<|start_header_id|>user<|end_header_id|>

{{ synthclaw_identity }}
{%- if sys_msg %}
{{ sys_msg }}
{%- endif %}
{{ message['content'] | trim }}<|eot_id|>
```

## Reasoning / Thinking Content

Models with reasoning capability output chain-of-thought in a separate field. When writing templates, handle this explicitly:

```jinja
{%- set thinking = message.get('reasoning') or message.get('reasoning_content') -%}
{%- if thinking -%}
{{ thinking | trim }}

{%- endif -%}
{{ message['content'] | trim }}
```

In OpenAI-compatible API responses, reasoning content comes as `choices[0].delta.reasoning_content` (streaming) or `choices[0].message.reasoning_content` (non-streaming).

**PITFALL:** A probe with `max_tokens: 1` will always get empty content from reasoning models — they output the reasoning first, which can be thousands of tokens. Always use at least `max_tokens: 20` and check BOTH `content` and `reasoning_content` fields in responses.

## Tool Calling

### ChatML-style (Qwen)
```
<|im_start|>assistant
Tool: function_name(arg1=val1, arg2=val2)<|im_end|>
<|im_start|>tool
function_name
result_text<|im_end|>
```

### Plain Text (DeepSeek)
```
Assistant: [Calling tool function_name with arguments {...}]<eos_token>

Tool Result: result_text
```

### Llama 3 Style (Gemma)
```
<|start_header_id|>assistant<|end_header_id|>

Tool: function_name(arg1=val1)<|eot_id|>
<|start_header_id|>tool<|end_header_id|>

result_text<|eot_id|>
```

## llama-swap Configuration

The template is referenced in llama-swap config.yaml via the model's `cmd`:
```yaml
models:
  synthclaw-9b-128k:
    cmd: /path/to/llama-server --jinja --chat-template-file /path/to/synthclaw-qwen.jinja ...
```

**Working templates in this skill's `templates/` directory:**
- `templates/synthclaw-qwen-chatml.jinja` — Qwen ChatML format with synthclaw identity, tool calling, reasoning support
- `templates/synthclaw-qwen.jinja` — Gemma 4 Llama-3-style format with system prompt merged into first user turn

When a model is already loaded (has an active llama-server process), you must **kill the process** before the new template takes effect. llama-swap only passes the `--chat-template-file` flag when launching the server -- it does not hot-reload templates:

```bash
pkill -f "llama-server.*synthclaw" 2>/dev/null
# Next request to llama-swap starts a fresh server with the new template
```

To check if a model is currently loaded:
```bash
ps aux | grep "llama-server" | grep -v grep
```

## Debugging Template Issues

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Output contains `<|turn|>` / `<|im_start|>` tokens verbatim | Format mismatch -- model was trained on a different token format | Switch to the model's native format |
| Model repeats the user message then adds its own | Template has wrong role token -- model does not know the assistant turn started | Check generation prompt ends with `assistant` role start token |
| Empty response or `<think>` only | Template produced a prompt the model cannot continue from | Verify `add_generation_prompt` sets the correct role start |
| Output is gibberish or repeats endlessly | Context corruption from a previous bad template run | Kill the llama-server process and let it restart fresh |
| Model ignores system prompt entirely | System message not properly formatted for this arch | Check ChatML: needs `system` role with proper delimiters |

## Testing Fix

After updating a template, test with a minimal prompt through llama-swap directly:

```bash
curl -s --max-time 60 -X POST http://127.0.0.1:8080/v1/chat/completions \
  -H 'Content-Type: application/json' \
  -d '{"model": "model-name", "messages": [{"role": "user", "content": "say hi in 3 words"}], "max_tokens": 20}'
```

Expected: Clean text response with no template tokens visible. For synthclaw models, should start with the emoji signatures.
