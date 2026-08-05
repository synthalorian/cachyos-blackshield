# Forge Hub — Rails 8 App

Part of the `synthalorian/forge` monorepo (Rust CLI + Rails Hub).

## Location

```
/home/synth/projects/forge/hub/
```

## Stack

| Component | Detail |
|-----------|--------|
| Ruby | 4.0.4 (mise-managed) |
| Rails | 8.1.3 |
| Database | SQLite 3.53.1 |
| CSS | Tailwind CSS v4 |
| Job backend | Solid Queue (default) |
| Auth | HTTP Basic Auth via middleware |

## Database

- **Dev:** `storage/development.sqlite3`
- **Test:** `storage/test.sqlite3`
- **Prod:** `storage/production.sqlite3` (plus `_cache`, `_queue`, `_cable`)

## Starting the Server

```bash
cd ~/projects/forge/hub
rm -f tmp/pids/server.pid   # if stale
bin/rails db:migrate          # if pending
bin/rails s -p 3000
```

Verify: `curl -s -o /dev/null -w "%{http_code}" http://localhost:3000/` → 200

## Key Config Files

| File | Purpose |
|------|---------|
| `config/database.yml` | SQLite adapter, dev/test/prod databases |
| `config/routes.rb` | Route definitions |
| `config/credentials.yml.enc` | Encrypted secrets (AES-256-GCM) |
| `Procfile.dev` | Dev: `rails server` + `tailwindcss:watch` |

## Common Tasks

```bash
# Run pending migrations
bin/rails db:migrate

# Check migration status
bin/rails db:migrate:status

# Open Rails console
bin/rails c
```
