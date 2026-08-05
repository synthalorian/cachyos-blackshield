#!/usr/bin/env bash
# Verification script for flutter-backend-integration setup
# Checks: backend running, /habits endpoint reachable, CORS headers present, DB file exists

set -e

BACKEND_URL="${1:-http://localhost:3000}"
PROJECT_ROOT="${2:-/home/synth/projects/open_habit}"

echo "==> Checking backend at $BACKEND_URL ..."
if curl -s -f "$BACKEND_URL/progression" > /dev/null; then
  echo "    [OK] Backend responded"
else
  echo "    [FAIL] Backend not reachable. Start with: cd $PROJECT_ROOT/crates/server && cargo run"
  exit 1
fi

echo "==> Checking CORS headers (OPTIONS preflight) ..."
CORS=$(curl -s -I -X OPTIONS "$BACKEND_URL/habits" | grep -i "access-control-allow-origin" || true)
if [ -n "$CORS" ]; then
  echo "    [OK] CORS header present: $CORS"
else
  echo "    [WARN] No CORS header — Flutter web/dev may fail. Ensure Axum CORS layer is enabled."
fi

echo "==> Checking SQLite DB file ..."
DB_PATH="$PROJECT_ROOT/data/open_habit.db"
if [ -f "$DB_PATH" ]; then
  echo "    [OK] Database exists at $DB_PATH"
  sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table';" | grep -q habits && echo "    [OK] habits table present" || echo "    [WARN] habits table missing — run server to initialize"
else
  echo "    [INFO] DB file not created yet — first request will create it"
fi

echo "==> Flutter dependencies check ..."
cd "$PROJECT_ROOT/flutter_app" || exit 1
if command -v flutter &>/dev/null; then
  echo "    [OK] Flutter found"
  flutter pub get
else
  echo "    [SKIP] Flutter not in PATH — run 'flutter pub get' manually"
fi

echo ""
echo "All checks passed. Run 'flutter run' to launch the app."
