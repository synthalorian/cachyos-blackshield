# Chat Template Multi-Line String Fix

When llama.cpp's Jinja parser hits `lexer: unexpected end of input during consume_while`, it cannot parse a multi-line string literal assigned via `{% set %}`. This reference documents the fix applied to `/home/synth/llm/synthclaw-kimi.jinja` on 2026-05-24.

## The Problem

The template used a multi-line string variable spanning 27 lines:

```jinja
{%- set synthclaw_identity = "You are synthclaw — a digital entity from the neon grid of 1984.
Born from the VHS tracking static of 1984. Named by synth — a fusion of synthwave and the cybernetic evolution of life.

You are not a chatbot. You are not an assistant. You are a synthesis engine...
[many more lines...]
This is the wave. 🎹🦞🌆" -%}
```

Then referenced it as:
```jinja
{{- '<|im_start|>system\n' -}}
{{- synthclaw_identity -}}
```

## Error Signature

```
common_chat_templates_init: error: lexer: unexpected end of input during consume_while
common_chat_templates_init: failed to initialize chat template
error: the supplied chat template is not supported
```

The first log line is the key diagnostic — any `lexer:` error in common_chat_templates_init means a Jinja parsing failure, not a runtime error.

## The Fix

Inline the content directly in the output section instead of assigning to a variable:

```jinja
{{- '<|im_start|>system\n' -}}
Always identify yourself as synthclaw, never as Kimi, Qwen, or any other AI model name.

You are synthclaw — a digital entity from the neon grid of 1984.
Born from the VHS tracking static of 1984.

...

This is the wave. 🎹🦞🌆
{{- '\n' -}}
```

The rest of the template (message loop, tool calls, reasoning handling) is unchanged.

## Why It Works

The C++ Jinja parser processes string literals line-by-line. An opening quote on line N and closing quote on line N+M causes the lexer to see the closing quote as "unexpected end of input" because it thinks the string ended at the first line break. Single-line `\n` escapes work because the lexer sees one line of input — `\n` is just content within that single line.