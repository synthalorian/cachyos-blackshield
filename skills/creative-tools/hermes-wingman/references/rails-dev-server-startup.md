# Starting the Rails Dev Server (Background + Health Check)

The Rails server (`bin/rails server`) does not daemonize by default and blocks the terminal. For agent workflows that need the server running while performing other tasks, use a subprocess approach with readiness polling.

## Pattern

```python
import subprocess
import time

# Clean up any existing server
subprocess.run(['rm', '-f', 'tmp/pids/server.pid'], check=False)
subprocess.run("lsof -ti:3000 2>/dev/null | xargs kill -9 2>/dev/null", shell=True, check=False)
time.sleep(1)

# Start server in background, redirect output to log file
proc = subprocess.Popen(
    ['bin/rails', 'server', '-b', '0.0.0.0', '-p', '3000'],
    stdout=open('log/server.log', 'w'),
    stderr=subprocess.STDOUT,
)
print(f"Rails server started with PID: {proc.pid}")

# Poll for readiness
for i in range(15):
    time.sleep(1)
    result = subprocess.run(
        ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', 'http://localhost:3000'],
        capture_output=True, text=True
    )
    if result.stdout.strip() == '200':
        print("Server is ready!")
        break
else:
    print("Server did not become ready")
    # Show last 2000 chars of log for debugging
    with open('log/server.log') as f:
        print(f.read()[-2000:])
```

## Why Not `nohup` or `&`?

The `terminal` tool rejects shell-level backgrounding (`&`, `nohup`, `disown`). Using `execute_code` with `subprocess.Popen` is the correct approach because:
- The agent can track the PID
- Output is captured to a log file for debugging
- Health checks can run in the same script
- No shell backgrounding wrappers needed

## Cleanup

Always clean up before starting:
```bash
rm -f tmp/pids/server.pid
lsof -ti:3000 | xargs kill -9 2>/dev/null
```

## Port Conflicts

If Puma reports `A server is already running`, the PID file is stale. Delete `tmp/pids/server.pid` and kill any process on the port.
