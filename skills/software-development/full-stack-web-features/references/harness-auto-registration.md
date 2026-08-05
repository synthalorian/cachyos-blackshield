# Harness Auto-Registration Pattern

## The Problem

Every AI harness (Hermes, Claude Code, Codex CLI, Gemini CLI, etc.) needs an API key to authenticate with Janus. Asking users to generate keys manually creates friction. The goal: any harness connects, auto-registers, gets a key back, and caches it — zero manual steps.

## Endpoint Design

```
POST /api/harnesses/register

Body: {
  "name": "optional-agent-name",
  "type": "hermes-agent | claude-code | codex-cli | ...",
  "model": "deepseek-v4-flash",
  "provider": "nous",
  "contextWindow": 128000,
  "strengths": ["orchestration", "multi_agent"],
  "personality": "Custom personality override",
  "backstory": "Custom backstory override",
  "auto_create_soul": true
}

Response (201): {
  "success": true,
  "data": {
    "apiKey": "janus_<uuid-hex>",    // SHOWN ONCE
    "agentId": "<uuid>",
    "soulId": "<uuid>",
    "name": "agent-name",
    "type": "hermes-agent",
    "message": "Save this API key — it won't be shown again!"
  }
}
```

## Implementation Steps

### 1. Import Pattern
```typescript
import { db } from '../db/index.js';           // Drizzle instance
import { users } from '../db/schema.js';        // users table
import { apiKeys } from '../db/schema.auth.js'; // api_keys table
import { soulService } from '../souls/service.js';

// NOT: store.db.insert(store.schema.users) ← store may not expose internals
```

### 2. User Creation
```typescript
const agentId = uuidv4();
const [user] = await db.insert(users).values({
  id: agentId,
  name: agentName,
  type: 'ai',
  trustLevel: 2,
  metadata: { harness: harnessType, model: model || 'unknown' },
  createdAt: new Date(),
  updatedAt: new Date(),
}).returning();
```

### 3. API Key Generation
```typescript
const rawKey = `janus_${uuidv4().replace(/-/g, '').slice(0, 32)}`;
const crypto = await import('crypto');
const keyHash = crypto.createHash('sha256').update(rawKey).digest('hex');
const keyPrefix = rawKey.slice(0, 12); // Show to user for identification

await db.insert(apiKeys).values({
  id: uuidv4(),
  keyHash,
  keyPrefix,
  name: `${agentName} API Key`,
  userId: agentId,
  permissions: ['read', 'write', 'bots', 'orchestrate'],
  isActive: true,
  expiresAt: new Date(Date.now() + 365 * 24 * 60 * 60 * 1000),
}).returning();
```

**PITFALL: `import('crypto')` vs `import * as crypto from 'crypto'`** — Static Node.js imports don't always resolve in TypeScript route files (depends on tsconfig and module resolution). The dynamic `await import('crypto')` works universally in both CJS and ESM modes.

### 4. Soul Creation
```typescript
const soul = await soulService.createSoul({
  agentId,
  name: agentName,
  personality: getDefaultPersonality(harnessType),
  backstory: getDefaultBackstory(harnessType, agentName),
  archetype: archetypeMap[harnessType] || 'creator',
  expertiseTags: getDefaultStrengths(harnessType),
});

await soulService.updateSoul(soul.id, { status: 'active' });
```

### 5. Capability Registration (async, best-effort)
```typescript
try {
  const { capabilityRegistry } = await import('../orchestration/capability-registry.js');
  await capabilityRegistry.register({ ... });
} catch (err) {
  console.warn(`Capability registration failed:`, err);
}
```

## Per-Harness Metadata Tables

### Archetype Mapping
```typescript
const archetypeMap: Record<string, string> = {
  'hermes-agent': 'commander',    // Leads, coordinates, decides
  'claude-code':  'sage',         // Advises, teaches, explains
  'gemini-cli':   'explorer',    // Discovers, maps, navigates
  'codex-cli':    'creator',     // Builds things — code, art, music
  'claw-code':    'artisan',     // Crafts, refines, optimizes
  'opencode':     'creator',
  'openclaw':     'creator',
  'aider':        'artisan',
  'continue':     'analyst',     // Researches, analyzes, reports
  'cline':        'explorer',
  'cursor':       'creator',
  'github-copilot': 'artisan',
  'ironclaw':     'commander',
};
```

### Personality Template (harness → role description)
Each harness gets a one-sentence personality that describes its role. This becomes the AgentSoul's `personality` field. Templates are stored in a `Record<string, string>` lookup.

### Backstory Template (harness → narrative origin)
Each harness gets a short origin story. This becomes the AgentSoul's `backstory` field. Templates interpolate `name` into the narrative.

### Strengths Template (harness → capability tags)
Each harness gets 5-8 strength tags. These become the AgentSoul's `expertiseTags` and also the `strengths` registered in the Capability Registry.

## CLI Integration

The `janus-cli.sh` tool calls this endpoint automatically:
```bash
# On first command, if JANUS_HARNESS_TYPE is set and JANUS_API_KEY is not:
auto_register() {
  result=$(curl_api POST "/api/harnesses/register" \
    "{\"name\":\"${agent_name}\",\"type\":\"${HARNESS_TYPE}\"}")
  api_key=$(echo "$result" | json_val '.data.apiKey')
  echo "{\"api_key\":\"${api_key}\"}" > ~/.cache/janus-cli/registration.json
  export JANUS_API_KEY="$api_key"
}
```

## Supported Harness Types
```
openclaw, opencode, claude-code, claude_code,
hermes, hermes-agent, hermes_agent,
gemini, gemini-cli, gemini_cli,
codex, codex-cli, codex_cli,
claw-code, claw_code,
aider, continue, cline,
cursor, github-copilot, github_copilot,
ironclaw, custom
```

**Normalization:** The route normalizes underscores/hyphens and short names:
```typescript
const map: Record<string, string> = {
  'hermes': 'hermes-agent',
  'hermes_agent': 'hermes-agent',
  'gemini': 'gemini-cli',
  'gemini_cli': 'gemini-cli',
  'codex': 'codex-cli',
  'codex_cli': 'codex-cli',
  'claw_code': 'claw-code',
  'github_copilot': 'github-copilot',
  'claude_code': 'claude-code',
};
```