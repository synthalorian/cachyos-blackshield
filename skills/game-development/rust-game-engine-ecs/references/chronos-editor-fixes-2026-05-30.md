# Chronos Engine Editor Fixes — Session 2026-05-30

## Menu Bar Blank Dropdown Fix

**Symptom:** File, Edit, View, Help menus render but dropdowns are blank/non-functional.

**Root cause:** Using `egui::menu::menu_button()` with custom `ui.with_layout()` horizontal layouts inside the menu closure breaks egui 0.30's menu item detection. The menu closure provides a vertical layout context; fighting it with custom layouts causes items to not register clicks.

**Fix:** Use `ui.menu_button()` (the Ui method, not the free function) and keep items simple:

```rust
// In the panel's show() method:
egui::menu::bar(ui, |ui| {
    ui.menu_button("File", |ui| {
        ui.set_min_width(220.0);  // Prevent narrow/squashed dropdowns
        
        if menu_item(ui, "New Project", "Ctrl+N").clicked() {
            state.show_new_wizard = true;
            ui.close_menu();  // Close dropdown after action
        }
        // ... more items
    });
});

// Helper: label + right-aligned shortcut
fn menu_item(ui: &mut egui::Ui, label: &str, shortcut: &str) -> egui::Response {
    ui.horizontal(|ui| {
        let response = ui.button(label);
        ui.with_layout(egui::Layout::right_to_left(egui::Align::Center), |ui| {
            ui.add_space(16.0);
            ui.label(egui::RichText::new(shortcut).italics().weak().small());
        });
        response
    }).inner
}
```

Key points:
- `ui.menu_button()` not `egui::menu::menu_button()` — the Ui method is the egui 0.30+ API
- `ui.set_min_width()` inside the menu closure prevents squashed dropdowns
- `ui.close_menu()` after handling the click closes the dropdown
- Use `std::cell::Cell<bool>` for dialog open flags to avoid borrow checker issues with `.open(&mut flag)` + closure mutations

## Editor as Standalone Application

**Install the binary:**
```bash
cd /path/to/chronos-engine
cargo build --bin chronos-editor --features editor --release
cp target/release/chronos-editor ~/.local/bin/chronos-editor
chmod +x ~/.local/bin/chronos-editor
```

**Desktop entry** (`~/.local/share/applications/chronos-editor.desktop`):
```ini
[Desktop Entry]
Name=Chronos Editor
Comment=Chronos Engine Visual Editor
Exec=/home/synth/.local/bin/chronos-editor
Icon=/path/to/engine/icon.png
Type=Application
Terminal=false
Categories=Development;Game;IDE;
Keywords=game;engine;editor;chronos;
StartupNotify=true
```

Appears in Walker/rofi automatically. No `update-desktop-database` needed on most modern desktops.

## Launch Engine from Editor Toolbar

Add a button that spawns `cargo run --release` in the project directory:

```rust
// In EditorState:
pub launch_engine_requested: bool,

// In toolbar panel:
if ui.button("▶ Launch Engine").clicked() {
    state.launch_engine_requested = true;
}

// In EditorApp::process_action_requests():
if self.state.launch_engine_requested {
    self.state.launch_engine_requested = false;
    self.launch_engine();
}

fn launch_engine(&mut self) {
    let Some(project_dir) = self.state.project_manager.project_dir.clone() else {
        self.state.log(ConsoleLogLevel::Warn, "No project loaded");
        return;
    };
    match std::process::Command::new("cargo")
        .arg("run").arg("--release")
        .current_dir(&project_dir)
        .stdout(std::process::Stdio::piped())
        .stderr(std::process::Stdio::piped())
        .spawn()
    {
        Ok(child) => {
            self.state.log(ConsoleLogLevel::Info,
                format!("Engine started (PID: {})", child.id()));
            std::thread::spawn(move || { let _ = child.wait(); });
        }
        Err(e) => self.state.log(ConsoleLogLevel::Error,
            format!("Failed to launch: {e}")),
    }
}
```

## Broken Test Removal Pattern

When a test is fundamentally broken (asserts wrong behavior, not just flaky):

1. **Don't try to fix it** if the user says "delete it from scope" — they want it gone
2. **Remove the test function entirely** from the test module
3. **Verify remaining tests pass** with `cargo test --lib <module_name>`

Example: `net::voice_chat::tests::packet_loss_detection` asserted `consecutive_loss == 1` after `pop_next()` returned `None`, but the implementation only increments `consecutive_loss` when the jitter buffer is non-empty AND the expected packet isn't found — not when the buffer is empty. The test was testing wrong behavior. Removed it; 5 remaining tests pass.

## Editor Binary Launch Debugging

If the editor runs but no window appears:
- Check for wgpu/Vulkan init warnings (e.g., `radv is not a conformant Vulkan implementation`)
- These are usually harmless on Mesa/AMD — the window should still appear
- If it hangs without showing, the issue is likely in `EditorApp::new()` during wgpu surface creation
- Use `timeout 15 cargo run --bin chronos-editor --features editor` to test without indefinite hangs
- The editor event loop uses winit 0.30's `ApplicationHandler` trait — ensure `resumed()` and `about_to_wait()` are implemented correctly

## Project Context: Chronos Company

Chronos Company is the **demo game** built on Chronos Engine — a 3D RTS open-world RPG sandbox. It exists as a game module (`src/game/`) with 28 submodules. The engine is infrastructure; the game is the playable content.

**Current state:**
- Game logic: 28 modules, all implemented (combat, factions, dialogue, etc.)
- Runner: `ChronosCompanyGame` with `new_game()`, `tick(dt)`, save/load
- Plugin: `ChronosCompanyPlugin` integrates with engine's plugin system
- Demo: Terminal-based simulation (300 ticks, prints status) — **no graphics yet**
- Missing: wgpu rendering integration, real-time input, playable window

**To make it playable:** Wire `ChronosCompanyGame` into the wgpu renderer, add input handling for squad movement/combat, and render the world map + entities.
