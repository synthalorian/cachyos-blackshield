# React Zero-Dependency Markdown Renderer

Full implementation for `components/Markdown.tsx`. Handles the common subset: code blocks, inline code, bold, italic, bold+italic, links, images, strikethrough, horizontal rules, line breaks.

## Component

```tsx
import React from 'react';

interface MarkdownProps { content: string; className?: string; }

function Markdown({ content, className = '' }: MarkdownProps) {
  const rendered = renderMarkdown(content);
  return <div className={`markdown-body ${className}`}>{rendered}</div>;
}
```

## Block-Level Renderer

```tsx
function renderMarkdown(text: string): React.ReactNode[] {
  const nodes: React.ReactNode[] = [];
  let remaining = text;
  let keyCounter = 0;

  while (remaining.length > 0) {
    // Code block (triple backticks) — must match before line-by-line
    const codeBlockMatch = remaining.match(/^```(\w*)\n([\s\S]*?)```\n?/);
    if (codeBlockMatch) {
      const [, lang, code] = codeBlockMatch;
      nodes.push(
        <div key={keyCounter++} className="md-code-block">
          {lang && <div className="md-code-lang">{lang}</div>}
          <pre><code>{code.trimEnd()}</code></pre>
        </div>
      );
      remaining = remaining.slice(codeBlockMatch[0].length);
      continue;
    }

    // Line-by-line processing
    const lineEnd = remaining.indexOf('\n');
    const line = lineEnd === -1 ? remaining : remaining.slice(0, lineEnd);
    remaining = lineEnd === -1 ? '' : remaining.slice(lineEnd + 1);

    if (line.trim() === '') { nodes.push(<br key={keyCounter++} />); continue; }

    // Horizontal rule
    if (/^(-{3,}|\*{3,}|_{3,})\s*$/.test(line.trim())) {
      nodes.push(<hr key={keyCounter++} />); continue;
    }

    nodes.push(<p key={keyCounter++}>{renderInline(line.trim())}</p>);
  }
  return nodes;
}
```

## Inline Renderer

```tsx
function renderInline(text: string): React.ReactNode[] {
  const nodes: React.ReactNode[] = [];
  let remaining = text;
  let key = 0;

  while (remaining.length > 0) {
    // ORDER MATTERS — most specific patterns first

    // Inline code
    const codeMatch = remaining.match(/^`([^`]+)`/);
    if (codeMatch) { nodes.push(<code key={key++} className="md-inline-code">{codeMatch[1]}</code>); remaining = remaining.slice(codeMatch[0].length); continue; }

    // Image ![alt](url)
    const imgMatch = remaining.match(/^!\[([^\]]*)\]\(([^)]+)\)/);
    if (imgMatch) { nodes.push(<img key={key++} src={imgMatch[2]} alt={imgMatch[1]} className="md-image" loading="lazy" />); remaining = remaining.slice(imgMatch[0].length); continue; }

    // Link [text](url)
    const linkMatch = remaining.match(/^\[([^\]]+)\]\(([^)]+)\)/);
    if (linkMatch) { nodes.push(<a key={key++} href={linkMatch[2]} target="_blank" rel="noopener noreferrer" className="md-link">{renderInline(linkMatch[1])}</a>); remaining = remaining.slice(linkMatch[0].length); continue; }

    // Bold + Italic ***text*** (check BEFORE bold **text**)
    const boldItalicMatch = remaining.match(/^\*\*\*([^*]+)\*\*\*/);
    if (boldItalicMatch) { nodes.push(<strong key={key++}><em>{boldItalicMatch[1]}</em></strong>); remaining = remaining.slice(boldItalicMatch[0].length); continue; }

    // Bold **text**
    const boldMatch = remaining.match(/^\*\*([^*]+)\*\*/);
    if (boldMatch) { nodes.push(<strong key={key++}>{boldMatch[1]}</strong>); remaining = remaining.slice(boldMatch[0].length); continue; }

    // Italic *text*
    const italicMatch = remaining.match(/^\*([^*]+)\*/);
    if (italicMatch) { nodes.push(<em key={key++}>{italicMatch[1]}</em>); remaining = remaining.slice(italicMatch[0].length); continue; }

    // Bold __text__
    const boldUnderscoreMatch = remaining.match(/^__([^_]+)__/);
    if (boldUnderscoreMatch) { nodes.push(<strong key={key++}>{boldUnderscoreMatch[1]}</strong>); remaining = remaining.slice(boldUnderscoreMatch[0].length); continue; }

    // Italic _text_
    const italicUnderscoreMatch = remaining.match(/^_([^_]+)_/);
    if (italicUnderscoreMatch) { nodes.push(<em key={key++}>{italicUnderscoreMatch[1]}</em>); remaining = remaining.slice(italicUnderscoreMatch[0].length); continue; }

    // Strikethrough ~~text~~
    const strikeMatch = remaining.match(/^~~([^~]+)~~/);
    if (strikeMatch) { nodes.push(<del key={key++} className="md-strike">{strikeMatch[1]}</del>); remaining = remaining.slice(strikeMatch[0].length); continue; }

    // Plain character
    nodes.push(remaining[0]);
    remaining = remaining.slice(1);
  }
  return nodes;
}
```

## CSS (theme-variable driven)

```css
.markdown-body p { margin: 0 0 6px; }
.markdown-body p:last-child { margin-bottom: 0; }
.markdown-body strong { color: var(--text-primary); font-weight: 600; }
.markdown-body em { font-style: italic; }

.md-link { color: var(--accent-cyan); text-decoration: none; border-bottom: 1px solid transparent; transition: border-color 0.15s; }
.md-link:hover { border-bottom-color: var(--accent-cyan); text-shadow: var(--glow-cyan); }

.md-inline-code {
  font-family: var(--font-mono); font-size: 0.85em;
  background: var(--bg-tertiary); padding: 1px 6px; border-radius: 4px;
  border: 1px solid var(--border-color); color: var(--accent-pink);
}

.md-code-block { margin: 8px 0; border-radius: var(--radius); overflow: hidden; border: 1px solid var(--border-color); }
.md-code-lang { font-size: 0.7rem; text-transform: uppercase; letter-spacing: 0.06em; padding: 4px 12px; background: var(--bg-tertiary); color: var(--text-muted); border-bottom: 1px solid var(--border-color); font-family: var(--font-mono); }
.md-code-block pre { margin: 0; padding: 12px 16px; background: var(--bg-primary); overflow-x: auto; font-size: 0.82rem; line-height: 1.45; }
.md-code-block code { font-family: var(--font-mono); color: var(--text-secondary); }

.md-image { max-width: 100%; border-radius: var(--radius); margin: 8px 0; border: 1px solid var(--border-color); }
.md-strike { text-decoration: line-through; color: var(--text-muted); }
.markdown-body hr { border: none; border-top: 1px solid var(--border-color); margin: 12px 0; }
```

## Usage

```tsx
import Markdown from './Markdown';

// In message display:
<div className="message-body">
  <Markdown content={message.content} />
</div>
```