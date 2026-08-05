# SQLite3 Ruby Gem v2.x — API Breaking Changes

## The Core Difference

SQLite3 v2.x (gem version 2.x, bundled with Rails 8.1+) returns **arrays of arrays** from `execute()`, not **arrays of hashes** like v1.x.

```ruby
# v1.x (gem < 2.0):
db.execute("SELECT id, name FROM users")
# => [{"id" => 1, "name" => "Alice"}, {"id" => 2, "name" => "Bob"}]

# v2.x (gem >= 2.0):
db.execute("SELECT id, name FROM users")
# => [[1, "Alice"], [2, "Bob"]]
```

## Impact

Any code that accesses columns by name (`row["status"]`, `row["count"]`) silently breaks — returning `nil` instead of the actual value. The app appears to have "empty database" or "missing data" problems.

## Fix Pattern

When reading data from SQLite3 v2.x in a service or script, map array rows to hashes manually:

```ruby
# Pattern: map each row to a hash using column positions
def recent_runs(limit: 10)
  query("SELECT id, timestamp, status, converted, errors FROM pipeline_runs ORDER BY timestamp DESC LIMIT ?", limit).map do |row|
    {
      "id" => row[0],
      "timestamp" => row[1],
      "status" => row[2],
      "converted" => row[3],
      "errors" => row[4]
    }
  end
end

def total_assets
  row = query_one("SELECT COUNT(*) as count FROM assets")
  row ? row[0] : 0  # NOT row["count"]
end
```

## Version Check

```ruby
Gem::Specification.find_by_name("sqlite3").version
# => 2.9.4 (arrays)
# => 1.7.3 (hashes)
```

## Rails Integration

When using `SQLite3::Database` directly in a Rails app (not through ActiveRecord), the gem is available via `require "sqlite3"` — no additional Gemfile entry needed since Rails already depends on it.

## Diagnostic

If a Rails service that reads a SQLite3 file shows "0 results" or "no such table" errors when the table exists, suspect the v2 API. Test with:

```ruby
db = SQLite3::Database.new("/path/to/db")
result = db.execute("SELECT 1 AS test")
puts result.class  # Array — if v2.x
puts result.first  # [1] — if v2.x, {"test" => 1} if v1.x
```
