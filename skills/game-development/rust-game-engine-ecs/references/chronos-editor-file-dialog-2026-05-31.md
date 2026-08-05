# Native File Dialogs in egui Editor — Session 2026-05-31

## Context

The Chronos Engine editor uses egui for its UI. The "Open Project" flow was text-input only — users had to type or paste a full path. This reference covers adding native point-and-click directory picker dialogs.

## Platform Dialog Backend

The engine already has a cross-platform `platform` module at `src/platform/`:

- **Linux:** `zenity --file-selection --directory` or `kdialog --getexistingdirectory`
- **macOS/Windows:** `rfd` crate (`FileDialog::new().pick_folder()`)
- **WASM/headless:** Returns `None`
- **Fallback:** Returns `None` if no dialog tool available

```rust
// src/platform/mod.rs — public API
pub fn open_dir_dialog(title: &str) -> Option<PathBuf> {
    imp::open_dir_dialog(title)
}
```

The `dialogs` Cargo feature gates `rfd`:
```toml
# Cargo.toml
dialogs = ["rfd"]
```

## Wiring: Add dialogs to editor feature

The `editor` feature must include `dialogs` so rfd compiles when building the editor:

```toml
# Cargo.toml
editor = ["egui", "egui-wgpu", "egui-winit", "wgpu", "winit",
          "dep:pollster", "serde", "serde_json", "dialogs"]
```

Without this, `platform::open_dir_dialog()` returns `None` on all platforms (rfd not compiled in, zenity/kdialog fallback only works on Linux with those tools installed).

## Pattern 1: Browse Button in Welcome Screen

Add a 📁 Browse button next to the path text field in the Open Project dialog:

```rust
// src/editor_panels/welcome.rs
use crate::platform;

// In the Open Project dialog UI:
ui.horizontal(|ui| {
    ui.label("Path:");
    let response = ui.add(
        egui::TextEdit::singleline(&mut self.open_project_path)
            .hint_text("/home/user/projects/MyGame"),
    );
    if response.lost_focus() && ui.input(|i| i.key_pressed(egui::Key::Enter)) {
        try_open_project(self, state);
    }
    // Browse button opens native directory picker
    if ui.button("📁 Browse").clicked() {
        if let Some(dir) = platform::open_dir_dialog("Select Project Folder") {
            self.open_project_path = dir.to_string_lossy().to_string();
        }
    }
});
```

**Behavior:**
- User clicks Browse → native dialog opens
- User selects directory → path populates the text field
- User clicks Open → validation runs, project loads
- Dialog cancelled → nothing changes, user can still type manually

## Pattern 2: Direct Open from Menu Bar

File → Open Project should open the dialog directly instead of just showing the inline panel:

```rust
// src/editor_panels/menu_bar.rs
use crate::platform;

// In show_file_menu():
if menu_item(ui, "Open Project...", "Ctrl+O").clicked() {
    if let Some(dir) = platform::open_dir_dialog("Select Project Folder") {
        match crate::editor_project::ProjectManager::open_project(&dir) {
            Ok(mgr) => {
                // Load project, preserve recents, update state...
                let name = mgr.project_name().to_string();
                let template = mgr.current_project
                    .as_ref().map(|m| m.template)
                    .unwrap_or(crate::editor_project::ProjectTemplate::Empty);
                let old_recents =
                    std::mem::take(&mut state.project_manager.recent_projects);
                state.project_manager = mgr;
                state.project_manager.recent_projects = old_recents;
                state.project_manager.add_recent(
                    &name, &dir.to_string_lossy(), template);
                state.project_path = Some(dir);
                state.recent_dirty = true;
                state.log(ConsoleLogLevel::Info,
                    format!("Opened project '{}'", name));
            }
            Err(e) => {
                state.log(ConsoleLogLevel::Error,
                    format!("Failed to open project: {e}"));
                // Fall back to inline panel for manual entry
                state.project_manager.show_open_dialog = true;
            }
        }
    } else {
        // Dialog cancelled or unavailable — show inline panel
        state.project_manager.show_open_dialog = true;
        state.log(ConsoleLogLevel::Info, "Open project dialog opened");
    }
    ui.close_menu();
}
```

**Fallback chain:**
1. Try native dialog → user picks dir → load project → done
2. Dialog cancelled → show inline panel → user types path
3. Dialog unavailable (headless) → show inline panel
4. Dialog returns invalid dir → log error → show inline panel

## Linux-Specific: zenity vs kdialog

The Linux backend auto-detects which tool is available:

```rust
// src/platform/linux.rs
fn has_command(name: &str) -> bool {
    std::process::Command::new("which")
        .arg(name)
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

pub fn open_dir_dialog(title: &str) -> Option<PathBuf> {
    if !has_display() { return None; }
    if has_command("zenity") {
        zenity_file_dialog(title, &["--directory"])
    } else if has_command("kdialog") {
        kdialog_dir_dialog(title)
    } else {
        None
    }
}
```

**On Omarchy/Arch:** `zenity` is usually installed with GNOME/GTK apps. If missing:
```bash
sudo pacman -S zenity
# or
sudo pacman -S kdialog
```

## Verification

```bash
# Build editor with dialogs feature
cargo build --bin chronos-editor --features editor

# Run editor and test File → Open Project
./target/debug/chronos-editor
```

Expected: Native directory picker opens. Selected path loads project.

## Pitfalls

### Feature not enabled
If `dialogs` is not in the `editor` feature list, `platform::open_dir_dialog()` returns `None` on macOS/Windows (rfd not compiled) and falls back to zenity/kdialog on Linux only. The dialog appears to "not work" on non-Linux platforms.

**Fix:** Ensure `editor = [..., "dialogs"]` in Cargo.toml.

### Borrow checker with menu item closures
The menu bar pattern mutably borrows `state.project_manager` to replace it with the loaded manager, while also accessing `state.log()`. This is fine because `state.log()` borrows `state.console_log` (a different field). But if you try to borrow `state.project_manager` again inside the same scope for `.add_recent()`, you'll get a borrow conflict.

**Fix:** Use `std::mem::take()` to extract the old recents before replacing the manager:
```rust
let old_recents = std::mem::take(&mut state.project_manager.recent_projects);
state.project_manager = mgr;  // replaces the whole manager
state.project_manager.recent_projects = old_recents;  // restore recents
```

### Dialog blocks the event loop
Native file dialogs (zenity, kdialog, rfd) are synchronous — they block the winit event loop while open. This is acceptable for a directory picker but can cause the window to appear unresponsive during the dialog.

**Mitigation:** Keep dialogs short (directory pick, not file tree browsing). For heavy file operations, consider an async rfd integration or egui's built-in file browser widget.

## Summary

| Pattern | Where | Trigger | Fallback |
|---------|-------|---------|----------|
| Browse button | Welcome screen Open Project dialog | 📁 Browse click | Inline text field |
| Direct open | Menu bar File → Open Project | Ctrl+O / menu click | Inline panel |
| Backend | `src/platform/` | `open_dir_dialog()` | `None` → inline UI |
| Feature gate | Cargo.toml | `editor = [..., "dialogs"]` | No rfd on non-Linux |
