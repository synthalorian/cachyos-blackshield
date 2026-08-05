# Rails CLI Tools View Pattern

When a Rails webapp needs to expose CLI commands (doctor, backup, security audit, etc.) as clickable buttons that show output, use a generic `runCli()` JavaScript function.

## ERB View Structure

```erb
<% content_for :title, "CLI Tools — App" %>
<% content_for :header_title, "CLI Tools" %>

<div class="card">
  <div class="card-header">
    <span class="section-title">🩺 Diagnostics</span>
  </div>
  <div class="card-body" style="display:grid;grid-template-columns:repeat(auto-fill,minmax(220px,1fr));gap:8px">
    <button class="btn btn-outline btn-block" onclick="runCli('doctor')"><span class="text-sm">🩺 Run Doctor</span></button>
    <button class="btn btn-outline btn-block" onclick="runCli('backup')"><span class="text-sm">💾 Quick Backup</span></button>
  </div>
</div>

<div id="cli-output" class="card mt-4" style="display:none">
  <div class="card-header">
    <span class="section-title" id="cli-output-title">Output</span>
    <button class="btn btn-sm btn-ghost" onclick="document.getElementById('cli-output').style.display='none'">✕</button>
  </div>
  <div class="card-body">
    <pre id="cli-output-text" style="background:var(--bg-tertiary);padding:16px;border-radius:8px;font-size:11px;max-height:400px;overflow:auto;white-space:pre-wrap"></pre>
  </div>
</div>
```

## JavaScript

```javascript
async function runCli(cmd) {
  const out = document.getElementById('cli-output');
  const text = document.getElementById('cli-output-text');
  out.style.display = 'block';
  text.textContent = 'Working...';

  const endpoint = `/api/cli_${cmd}`;
  const opts = {};
  if (cmd === 'backup') opts.method = 'POST';

  try {
    const res = await fetch(endpoint, { ...opts, headers: { 'Accept': 'application/json' } });
    const data = await res.json();
    data.output || data.status || data.dump || data.webhooks
      || data.hooks || data.users || data.insights || data.chain?.join('\n')
      || data.stdout || JSON.stringify(data, null, 2)
    text.textContent = result;
  } catch(e) {
    text.textContent = `Error: ${e.message}`;
  }
}
```

## API Endpoint Pattern (Rails controller + routes)

```ruby
# app/controllers/api_controller.rb
def cli_doctor
  render json: HermesApiService.run_doctor
rescue HermesApiService::BackendError => e
  render json: { error: e.message }
end

def cli_backup
  render json: HermesApiService.create_backup
rescue HermesApiService::BackendError => e
  render json: { error: e.message }
end
```

```ruby
# config/routes.rb
namespace :api do
  get :cli_doctor
  post :cli_backup
  # ... one line per CLI command
end
```

## Key Points

- The `runCli(cmd)` function derives the endpoint from `cmd` — `runCli('doctor')` → fetches `/api/cli_doctor`
- Output is a generic `pre` tag — works for any text result
- The output panel shows/hides via `style.display`
- Method defaults to GET; override with `opts.method = 'POST'` for backup/creating endpoints
- The API controller action is one-liner with rescue — every endpoint follows the exact same pattern
- Multiple CLI endpoint categories (diagnostics, data management, integrations, analytics) are separated into named card groups
