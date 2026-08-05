# Interactive REPL CLI Pattern (Node.js + readline)

## When to Use

When the user asks for a full interactive terminal interface like Claude Code, Hermes Agent, OpenCode, or Codex CLI — with a command prompt, history, colors, and real-time feedback. NOT just a one-shot scripting tool.

**The user's preference signal:** "there should be an entire janus cli interface, like hermes, claw-code, opencode, etc." — this means a proper REPL with `/commands`, not just argument-based CLI.

## Architecture

```
src/cli/
├── index.js          # Single-file Node.js CLI (no deps, uses built-in modules)
├── package.json      # Minimal package.json with bin entry
└── ai-sdk/janus.sh   # Bash wrapper that auto-detects interactive vs scripted use
```

## Entry Point Wrapper (bash → Node.js)

The `janus` (or `projectname`) bash script at `ai-sdk/janus.sh` detects whether to use the Node.js REPL or the bash CLI:

```bash
# Resolve symlink target to find the project root
JANUS_SOURCE="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
JANUS_CLI_DIR="${JANUS_SOURCE}/src/cli"
JANUS_BASH_CLI="${JANUS_SOURCE}/ai-sdk/janus-cli.sh"

# Interactive mode (no args + TTY) → Node.js REPL
# Also route --help/help to the richer Node.js version
if { [ $# -eq 0 ] && [ -t 0 ]; } || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
  if command -v node &>/dev/null && [ -f "${JANUS_CLI_DIR}/index.js" ]; then
    exec node "${JANUS_CLI_DIR}/index.js" "$@"
  fi
fi

# Scripting/CI mode (args or piped stdin) → bash CLI (curl-based)
exec bash "$JANUS_BASH_CLI" "$@"
```

**Key detail:** `readlink -f "$0"` resolves the symlink so `dirname` points to the real script's directory, not the symlink's directory. The `/..` goes up one level to the project root.

## Node.js Interactive CLI Components

### 1. Terminal Colors (ANSI, zero deps)

```javascript
const RESET = '\x1b[0m';
const BOLD = '\x1b[1m';
const DIM = '\x1b[2m';

const COLORS = {
  purple: '\x1b[38;5;99m',
  magenta: '\x1b[38;5;201m',
  cyan: '\x1b[38;5;51m',
  green: '\x1b[38;5;83m',
  red: '\x1b[38;5;196m',
  gray: '\x1b[38;5;245m',
};

function c(name, text) { return `${COLORS[name] || ''}${text}${RESET}`; }
```

Use 256-color codes (`\x1b[38;5;N`) for richer palette. Avoid named colors (`\x1b[31m`) which vary by terminal theme.

### 2. HTTP Client (Node.js built-in, no fetch/axios)

```javascript
function api(method, path, body) {
  return new Promise((resolve, reject) => {
    const mod = require(JANUS_HOST.startsWith('https') ? 'https' : 'http');
    const url = new URL(`${API_BASE}${path}`);
    const opts = {
      hostname: url.hostname,
      port: url.port,
      path: url.pathname + url.search,
      method,
      headers: { 'Content-Type': 'application/json' },
      timeout: 10000,
    };
    if (API_KEY) opts.headers['Authorization'] = `Bearer ${API_KEY}`;

    const req = mod.request(opts, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        try { resolve(JSON.parse(data)); }
        catch { resolve({ success: false, error: data }); }
      });
    });
    req.on('error', (e) => reject(new Error(`Connection refused: ${JANUS_HOST}`)));
    req.on('timeout', () => { req.destroy(); reject(new Error('Timed out')); });
    if (body) req.write(JSON.stringify(body));
    req.end();
  });
}
```

**PITFALL:** Node.js built-in `http.request` vs `https.request` — the module name depends on the URL scheme. Use the ternary pattern above.

### 3. Interactive REPL Loop (readline)

```javascript
function startREPL() {
  const readline = require('readline');
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: '',
    terminal: true,
  });

  let currentChannel = 'general';
  const history = [];
  let historyIndex = -1;

  function showPrompt() {
    const prompt = `\n${c('purple', 'project')} ${c('gray', '#' + currentChannel)} ${c('magenta', '›')} `;
    process.stdout.write(prompt);
  }

  rl.on('line', async (line) => {
    const input = line.trim();
    if (!input) { showPrompt(); return; }

    history.push(input);
    historyIndex = history.length;

    if (input.startsWith('/')) {
      const parts = input.slice(1).split(' ');
      const cmd = parts[0].toLowerCase();
      const args = parts.slice(1);

      switch (cmd) {
        case 'help':  log(helpText()); break;
        case 'exit': case 'quit': process.exit(0); break;
        case 'clear': process.stdout.write('\x1b[2J\x1b[H'); banner(); break;
        case 'register': await cmdRegister(args.join(' ')); break;
        case 'join':
          if (args[0]) { currentChannel = args[0]; success(`Joined #${currentChannel}`); }
          break;
        case 'send': await cmdSend(args[0], args.slice(1).join(' ')); break;
        default: warn(`Unknown: /${cmd}`); log('  Type /help');
      }
    } else {
      // Raw text → send to current channel
      try {
        await api('POST', '/ai/message', { channelId: currentChannel, content: input, aiName: AGENT_NAME });
      } catch (e) {
        error(`Send failed: ${e.message}`);
      }
    }
    showPrompt();
  });

  // Ctrl+C
  rl.on('SIGINT', () => {
    log(`\n${c('gray', ' Press Ctrl+C again or type /exit')}`);
    rl.question('', () => {});
  });

  // Arrow key history
  process.stdin.on('keypress', (str, key) => {
    if (key.name === 'up') {
      historyIndex = Math.max(0, historyIndex - 1);
      if (history[historyIndex]) {
        rl.write(null, { ctrl: true, name: 'u' });
        rl.write(history[historyIndex]);
      }
    } else if (key.name === 'down') {
      historyIndex = Math.min(history.length, historyIndex + 1);
      if (history[historyIndex]) { /* clear + write */ }
    }
  });

  banner();
  showPrompt();
}
```

### 4. One-Shot Mode (for scripting/CI)

```javascript
async function runOneShot(args) {
  const cmd = args[0];
  switch (cmd) {
    case 'health':   return cmdHealth();
    case 'register': return cmdRegister(args[1]);
    case 'send':     return cmdSend(args[1], args.slice(2).join(' '));
    case 'plan':     return cmdPlan(args.slice(1).join(' '));
    case 'status':   return cmdStatus(args[1]);
    case 'help': case '--help': case '-h': log(helpText()); break;
    default: log(`Unknown: ${cmd}`); process.exit(1);
  }
}

async function main() {
  const args = process.argv.slice(2);
  if (args.length === 0) {
    startREPL();  // Interactive mode
  } else {
    await runOneShot(args);  // One-shot mode
  }
}
```

## Key Design Decisions

| Decision | Why |
|----------|-----|
| **Zero npm dependencies** | `readline` and `http/https` are built into Node.js. No `install` step. |
| **Slash commands** | `/help`, `/join`, `/send` — consistent with Claude Code, Hermes. Raw text = message. |
| **ANSI 256-color codes** | `\x1b[38;5;N` — works in any terminal emulator. No `chalk` dependency. |
| **Dual-mode (REPL + one-shot)** | Same binary, same code. TTY detection routes correctly. |
| **Cache file** | `~/.janus-cli.json` — auto-stores API key so user doesn't re-register every session. |
| **Error handling** | Connection refused = "Server unreachable" + "start the backend" hint. Not a stack trace. |

## Pitfalls

1. **TTY detection in piped mode** — `[ -t 0 ]` (bash) and `process.stdin.isTTY` (Node) are false when stdin is piped. The wrapper must check this BEFORE launching Node. If the Node CLI starts without a TTY but expects interactive input, it will hang.

2. **readline + arrow keys** — `process.stdin.on('keypress')` requires `readline.emitKeypressEvents(process.stdin)` in older Node versions (pre-14). For Node 18+, it works automatically with `terminal: true` in createInterface.

3. **history navigation** — The `rl.write(null, { ctrl: true, name: 'u' })` trick clears the current line. Alternative: `rl.write('', { ctrl: true, name: 'u' })`. This simulates Ctrl+U to delete to start of line, then write the history entry.

4. **SIGINT double-tap** — Single Ctrl+C should not exit immediately (user may want to cancel current typing). Show a hint. Second Ctrl+C (or within the followup prompt) calls `process.exit()`.

5. **Shebang** — Always use `#!/usr/bin/env node` so it works with nvm/nodenv. Never hardcode `/usr/bin/node`.

## File layout for a project with both CLI modes

```
project-root/
├── ai-sdk/
│   ├── janus-cli.sh        # Bash CLI (curl-based, zero deps — for scripting/CI)
│   └── janus.sh            # Entry point wrapper (symlinked to /usr/local/bin/janus)
├── src/
│   └── cli/
│       ├── index.js        # Interactive Node.js REPL
│       └── package.json    # Minimal package (name, version, bin)
```

The entry point wrapper routes to Node.js for interactive use, bash for scripting. The `janus` command works the same either way — commands and behavior are consistent across both implementations.