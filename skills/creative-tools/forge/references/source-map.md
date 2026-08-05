# Forge Source Map

Quick reference for navigating the codebase. All paths relative to `~/projects/forge/src/`.

## Module Dependency Graph

```\nmain.rs\n├── cli.rs          (Cli, Commands, *Args structs — clap derive)\n├── config.rs       (Config, RetentionConfig — load/save TOML)\n├── models.rs       (BackupEntry, RepoSnapshot, ArchiveManifest, ChunkEntry, ScheduleConfig)\n├── error.rs        (ForgeError enum — thiserror)\n├── db.rs           (connect, CRUD fns, list_backups, show_status, schedule queries)\n├── backup.rs       (run, run_all, run_single, backup_repo, discover_repos)\n│   ├── calls: config, cli, models, db, archive, chunkstore, theme\n│   └── subprocess: git clone --bare, git branch/tag/stash commands\n├── archive.rs      (create_archive, verify_archive, extract_archive)\n│   └── subprocess: tar (create/list/extract), zstd (compress/decompress)\n├── restore.rs      (run — lookup backup, extract, optional checkout)\n│   └── calls: config, cli, db, archive, theme\n├── scheduler.rs    (run, validate_cron, regenerate_crontab)\n│   └── calls: cli, config, db, models, theme\n├── chunkstore.rs   (ChunkStore struct — store_chunk, read_chunk, has_chunk)\n│   └── uses: sha2, zstd, fs\n├── theme.rs        (Theme struct, 12 const themes, style_* helper fns)\n├── theme_cmd.rs    (run — list, preview, set)\n│   └── calls: cli, config, theme\n├── utils.rs        (shared helpers — path resolution, string formatting)\n├── spirit.rs       (Bible DB loading, daily verse, search, reference lookup)\n│   └── loads: ~/.forge/data/bible.db (bundled KJV)\n├── spirit_cmd.rs   (CLI dispatch for word, reflect, rest subcommands)\n│   └── calls: cli, config, db, spirit, reflect, theme\n├── reflect.rs      (prayer journal: create entry, history, search, AES-256-GCM)\n│   └── uses: aes-gcm, rand\n├── bin/\n│   └── generate_bible_db.rs  (build-time KJV -> SQLite generator)\n\n# Assets\nassets/forge-icon.png  — 1254×1254 PNG, synthwave blacksmith app icon\n```

## Key Function Signatures

```rust
// backup.rs
pub fn run(cfg: &Config, args: &BackupArgs) -> Result<()>
fn run_all(cfg: &Config, compression: u32) -> Result<()>
fn run_single(cfg: &Config, repo_path: &PathBuf, compression: u32) -> Result<()>
fn backup_repo(cfg: &Config, repo_path: &Path, compression: u32) -> Result<BackupInfo>
fn discover_repos(cfg: &Config) -> Result<Vec<PathBuf>>

// archive.rs
pub fn create_archive(cfg: &Config, bare_repo_path: &str, compression_level: u32) -> Result<(String, String)>
pub fn verify_archive(archive_path: &Path, expected_hash: &str) -> Result<bool>
pub fn extract_archive(archive_path: &Path, output_dir: &Path) -> Result<()>

// db.rs
pub fn connect(cfg: &Config) -> Result<Connection>
pub fn insert_backup(conn: &Connection, entry: &BackupEntry) -> Result<i64>
pub fn get_backup_by_id(conn: &Connection, id: &str) -> Result<Option<BackupEntry>>
pub fn list_backups(cfg: &Config, args: &ListArgs) -> Result<()>
pub fn show_status(cfg: &Config) -> Result<()>
// + schedule CRUD, chunk recording

// chunkstore.rs
impl ChunkStore {
    pub fn new(chunks_dir: PathBuf, compression_level: i32) -> Result<Self>
    pub fn store_chunk(&self, data: &[u8]) -> Result<ChunkInfo>
    pub fn read_chunk(&self, hash: &str) -> Result<Vec<u8>>
    pub fn has_chunk(&self, hash: &str) -> bool
}

// restore.rs
pub fn run(cfg: &Config, args: &RestoreArgs) -> Result<()>

// scheduler.rs
pub fn run(cfg: &Config, args: &ScheduleArgs) -> Result<()>
```

## SQLite Schema

```sql
backups (id, repo_path, repo_name, archive_path, sha256, size_bytes,
         branch_count, tag_count, commit_count, backup_type, created_at)
schedules (id, cron_expression, target_path, enabled, last_run, created_at)
chunks (hash PK, original_size, compressed_size, ref_count)
archive_chunks (backup_id FK, chunk_index, chunk_hash FK, PK(bid, idx))
-- indexes: idx_backups_repo_name, idx_backups_created_at
```
