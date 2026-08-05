# Cursor Theme Overrides on Linux/Wayland/Hyprland

## The Problem

User wanted to customize specific cursors in the `phinger-cursors-dark` theme:
- Default cursor (pointer) → skull
- Hand cursor (pointing_hand) → middle_finger

## Why Naive Approaches Fail

### Approach 1: Flat-file override (wrong)
```
~/.local/share/icons/phinger-cursors-dark/cursors/pointer       (skull data)
~/.local/share/icons/phinger-cursors-dark/cursors/pointing_hand  (middle_finger data)
```
**Fails** because XCursor doesn't merge — it finds the first matching theme and uses its full cursors dir. Partial override doesn't work.

### Approach 2: Directory-based override (wrong)
```
~/.local/share/icons/phinger-cursors-dark/cursors/pointer/skull
```
**Fails** because this theme uses flat files (155488 bytes each), not `cursor_name/` directory structure.

### Approach 3: Missing index.theme (wrong)
Override dir without `index.theme` — XCursor won't recognize the directory as a valid theme.

## The Working Solution

### Step 1: Full theme copy to user dir
```bash
mkdir -p ~/.local/share/icons/phinger-cursors-dark/cursors
cp /usr/share/icons/phinger-cursors-dark/index.theme ~/.local/share/icons/phinger-cursors-dark/

# Copy all cursor files EXCEPT the ones to override
for f in /usr/share/icons/phinger-cursors-dark/cursors/*; do
    case "$(basename "$f")" in
        pointer|pointing_hand) ;;  # Skip these
        *) cp -f "$f" ~/.local/share/icons/phinger-cursors-dark/cursors/ ;;
    esac
done
```

### Step 2: Replace specific cursors
```bash
cp -f /usr/share/icons/phinger-cursors-dark/cursors/skull ~/.local/share/icons/phinger-cursors-dark/cursors/pointer
cp -f /usr/share/icons/phinger-cursors-dark/cursors/middle_finger ~/.local/share/icons/phinger-cursors-dark/cursors/pointing_hand
```

### Step 3: Apply
```bash
hyprctl setcursor phinger-cursors-dark 24
```

## Debugging Checklist

| Check | Command |
|-------|---------|
| File type | `file ~/.local/share/icons/<theme>/cursors/pointer` |
| Content matches | `md5sum ~/.local/share/icons/<theme>/cursors/pointer` |
| Theme recognized | `grep -l "Theme Name" ~/.local/share/icons/*/index.theme` |
| Cursor path | `echo $XCURSOR_PATH` (default: ~/.local/share/icons:/usr/share/icons) |

## Key Insights

1. **XCursor theme name vs directory name:** The `Name=` field in `index.theme` must match the theme name. Directory name is secondary.

2. **Flat files vs directory-based:** Check the base theme structure first — some themes use flat Xcursor binary files, others use `cursor_name/` subdirectories.

3. **Symlink trap:** Many themes use symlinks (e.g., `pointing_hand → pointer`). When copying with `cp`, symlinks are followed, creating full duplicates. Fine but means 100+ files.

4. **No merging:** XCursor uses the FIRST matching theme from `XCURSOR_PATH`. Partial overrides don't work — copy the entire theme.

5. **Hyprland software cursors:** With `no_hardware_cursors = 1`, Hyprland renders cursors via Cairo/Wayland. May or may not respect XCursor path resolution — verify in-session.

6. **Sandbox cp quirk:** The `execute_code` Python sandbox can produce unexpected results with `cp` commands due to path resolution quirks. When in doubt, use a `bash -c` heredoc block instead.
