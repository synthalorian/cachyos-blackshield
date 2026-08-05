# System-Wide File Explorer with Right-Click Context Menus

Building a Flutter desktop file explorer that browses the entire filesystem
with right-click context menus for file/folder operations.

## Backend: System-Wide Path Resolution

Replace path resolution that was locked to `~/.hermes` with one that supports:

- Absolute paths starting with `/`
- Home-relative paths starting with `~/`
- Relative paths resolved from `$HOME`
- The empty string (resolves to `$HOME`)

```rust
fn resolve_fs_path(state: &AppState, relative_path: &str) -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    if relative_path.starts_with('/') {
        PathBuf::from(relative_path)
    } else if relative_path.is_empty() || relative_path == "." {
        PathBuf::from(&home)
    } else if relative_path.starts_with("~/") {
        PathBuf::from(&home).join(&relative_path[2..])
    } else if relative_path.starts_with("./") {
        PathBuf::from(&home).join(&relative_path[2..])
    } else {
        PathBuf::from(&home).join(relative_path)
    }
}
```

## Backend: File Operation Endpoints

| Endpoint | Method | What it does |
|---|---|---|
| `GET /files/list?path=` | get | List directory contents |
| `GET /files/read?path=` | get | Read file content |
| `PUT /files/write` | put | Write file content |
| `GET /files/info?path=` | get | Size, permissions, modified time |
| `POST /files/delete` | post | Delete file or recursion-delete directory |
| `POST /files/rename` | post | Rename file/folder (same parent dir) |
| `POST /files/mkdir` | post | Create new subdirectory |

### files_info Response

```json
{
  "success": true,
  "name": "config.yaml",
  "path": ".hermes/config.yaml",
  "is_dir": false,
  "size": 4096,
  "modified": 1748123456,
  "permissions": "644"
}
```

Uses `std::fs::metadata()` with `std::os::unix::fs::PermissionsExt` for Unix mode.
Only works on POSIX systems — Windows needs different permission handling.

### files_delete

Uses `std::fs::remove_dir_all` for directories, `std::fs::remove_file` for files.

### files_rename

Uses `std::fs::rename` — works across the same filesystem. The new name is
relative to the current parent directory (not a full path).

### files_mkdir

Uses `std::fs::create_dir` — creates one level only (not `create_dir_all`).
The caller specifies the parent path + the new directory name.

## Flutter: Right-Click Context Menu

### Trigger Detection

```dart
GestureDetector(
  onTap: onTap,
  onSecondaryTapDown: (details) => onSecondaryTap?.call(details.globalPosition),
  child: /* file entry UI */,
)
```

`onSecondaryTapDown` is the Flutter desktop way to detect right-click.
Pass the `globalPosition` to position the popup menu.

### Context Menu Items (showMenu)

```dart
final result = await showMenu<String>(
  context: context,
  position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx + 1, pos.dy + 1),
  color: scheme.surface.withAlpha(235),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(8),
    side: BorderSide(color: scheme.borderDim.withAlpha(40)),
  ),
  items: [
    PopupMenuItem(value: 'open', child: /* icon + text */),
    PopupMenuItem(value: 'view', child: /* icon + text */),
    PopupMenuItem(value: 'xdg', child: /* Open w/ Default App */),
    PopupMenuItem(value: 'copy_path', child: /* Copy Path */),
    const PopupMenuDivider(),
    PopupMenuItem(value: 'rename', child: /* Rename */),
    PopupMenuItem(value: 'duplicate', child: /* Duplicate */),
    PopupMenuItem(value: 'delete', child: /* Delete… */),
  ],
);
```

### Menu Items per Entry Type

| Item | Directory | File |
|---|---|---|
| Open / View | ✅ Navigate into dir | ✅ View content |
| Open in Editor | — | ✅ View (same as read) |
| Open w/ Default App | — | ✅ `Process.run('xdg-open', [path])` |
| Copy Path | ✅ Clipboard | ✅ Clipboard |
| Rename | ✅ Dialog | ✅ Dialog |
| Duplicate | — | ✅ Read + write with `_copy` suffix |
| Delete | ✅ Confirm dialog | ✅ Confirm dialog |

### ⋮ Button (Three-Dot Menu Trigger)

Each file entry row has a small ⋮ button that also triggers the context menu.
This provides an alternative to right-click for users who prefer clicking:

```dart
GestureDetector(
  onTap: () => onSecondaryTap?.call(
    (context.findRenderObject() as RenderBox).localToGlobal(Offset.zero) +
    const Offset(40, 0)
  ),
  child: Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: scheme.textMuted.withAlpha(15),
      borderRadius: BorderRadius.circular(4),
    ),
    child: Icon(Icons.more_vert, size: 12, color: scheme.textMuted.withAlpha(150)),
  ),
)
```

### Breadcrumb Navigation

Two-level breadcrumb bar at the top:
- **Home** (`~`) — resolves to `$HOME`
- **Root** (`/`) — resolves to filesystem root
- **Breadcrumbs** — path segments, clickable to navigate back

### Flutter API Client Methods

```dart
Future<Map<String, dynamic>> getFileInfo(String path) async {
  return await _get('/files/info', {'path': path});
}
Future<Map<String, dynamic>> deleteFile(String path) async {
  return await _post('/files/delete', {'path': path});
}
Future<Map<String, dynamic>> renameFile(String path, String newName) async {
  return await _post('/files/rename', {'path': path, 'new_name': newName});
}
Future<Map<String, dynamic>> createDirectory(String path, String name) async {
  return await _post('/files/mkdir', {'path': path, 'name': name});
}
```

### New Folder Button

App bar action that shows a dialog to enter a folder name, then calls
`POST /files/mkdir` and refreshes the listing.

## Aesthetic: Keep It Crisp

- Font sizes: 9-12px for metadata/labels, 13-14px for headings
- Compact padding: 10-12px horizontal, 8-10px vertical
- Monospace font for file names and paths
- Subtle borders: `scheme.borderDim.withAlpha(40)`
- Minimal use of icons — one icon per entry, one action per item
- No redundant text: if the action is obvious from the icon, skip the label