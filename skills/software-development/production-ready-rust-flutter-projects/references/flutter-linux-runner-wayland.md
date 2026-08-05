# Flutter Linux Runner: Wayland/GTK Window Setup

## Problem

On Wayland compositors that are not GNOME (Hyprland, Sway, KDE, etc.), the default Flutter Linux runner enables a GTK header bar (`GtkHeaderBar`) unconditionally for Wayland. This causes:

1. **Double window decorations** — the compositor provides CSD/title bars AND GTK adds another header bar, wasting vertical space
2. **Content clipping** — the Flutter content area starts below the GTK header bar, but the compositor treats the header bar as part of the content, clipping the bottom of the app
3. **Visual inconsistency** — the header bar uses GTK styling which clashes with a custom Flutter UI theme

## Root Cause

In `linux/runner/my_application.cc`, the default Flutter template sets `use_header_bar = TRUE` on Wayland (the `#else` branch of `#ifdef GDK_WINDOWING_X11`), assuming Wayland == GNOME.

## Fix: Header Bar Detection

Check `XDG_CURRENT_DESKTOP` on Wayland to detect the desktop environment:

```c
gboolean use_header_bar = TRUE;
#ifdef GDK_WINDOWING_X11
  GdkScreen* screen = gtk_window_get_screen(window);
  if (GDK_IS_X11_SCREEN(screen)) {
    const gchar* wm_name = gdk_x11_screen_get_window_manager_name(screen);
    if (g_strcmp0(wm_name, "GNOME Shell") != 0) {
      use_header_bar = FALSE;
    }
  }
#else
  // On Wayland, only use header bar on GNOME.
  const gchar* xdg_desktop = g_getenv("XDG_CURRENT_DESKTOP");
  if (xdg_desktop == NULL || !g_str_has_prefix(xdg_desktop, "GNOME")) {
    use_header_bar = FALSE;
  }
#endif
```

## Window Size and Position

### Default Size

```c
gtk_window_set_default_size(window, 1280, 720);
gtk_window_set_resizable(window, TRUE);
```

1280x720 fits most 1920x1080 displays. Set smaller (1024x768) for low-res displays.

### Positioning: Do NOT Rely on GTK_WIN_POS_CENTER on Wayland

`GTK_WIN_POS_CENTER` is unreliable on Wayland compositors (Hyprland, Sway). The position hint is either ignored or applied before the compositor knows the window size. Use the `first_frame_cb` callback to explicitly center after the window is realized:

```c
// Called when first Flutter frame received.
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  gtk_widget_show(GTK_WIDGET(window));
  gtk_window_move(window, 0, 0);  // or compute center
}
```

For centering on the primary monitor:

```c
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  gtk_widget_show(GTK_WIDGET(window));

  GdkDisplay* display = gtk_widget_get_display(GTK_WIDGET(window));
  if (display) {
    GdkMonitor* monitor = gdk_display_get_monitor(display, 0);
    if (monitor) {
      GdkRectangle geo;
      gdk_monitor_get_geometry(monitor, &geo);
      int win_w, win_h;
      gtk_window_get_size(window, &win_w, &win_h);
      int cx = geo.x + (geo.width - win_w) / 2;
      int cy = geo.y + (geo.height - win_h) / 2;
      gtk_window_move(window, cx, cy);
    }
  }
}
```

### CRITICAL PITFALL: Do NOT Remove Window Decorations

**NEVER call `gtk_window_set_decorated(window, FALSE)`** to fix positioning issues. This causes:

- On Hyprland: the compositor still renders window shadows and thin borders around the undecorated window — a "thin purple glow" that looks like a rendering bug
- On GNOME/KDE: CSD decorations are completely removed, making the window immovable and unresizable without WM keybinds
- The content is correctly positioned but the window frame shadows create the illusion of offset/shifting

Also remove `gtk_window_set_position(window, GTK_WIN_POS_CENTER)` and handle positioning in the first_frame_cb instead.

DO NOT USE:
```c
// NEVER do this:
gtk_window_set_decorated(window, FALSE);  // <-- shadows bleed through on Hyprland
gtk_window_set_position(window, GTK_WIN_POS_CENTER);  // <-- unreliable on Wayland
```

USE INSTEAD:
```c
// Remove both position hint and decoration stripping.
// Handle centering in first_frame_cb after the window is realized.
gtk_window_set_default_size(window, 1280, 720);
gtk_window_set_resizable(window, TRUE);
// NO gtk_window_set_position()
// NO gtk_window_set_decorated()
```

Also remove:
```c
// Inactivate/remove:
gtk_window_set_keep_above(window, FALSE);   // not needed
gtk_window_set_accept_focus(window, TRUE);  // default
```

The window title should match `StartupWMClass` in the `.desktop` file for proper WM class matching:

```c
gtk_window_set_title(window, "Your App Name");
```

## Window Content Layout

Use a simple `Row` inside a `Container` for the sidebar + content layout. Do NOT use `Stack` with `Positioned.fill` — the Stack approach can interact badly with nested Scaffolds.

**DO use simple Row layout:**
```dart
Container(
  color: scheme.scaffoldBackground,
  child: Row(
    children: [
      Container(width: 68, child: Column(/* sidebar */)),
      Expanded(child: _screens[_selectedIndex]),
    ],
  ),
)
```

**AVOID:**
```dart
// Stack + Positioned.fill — unnecessary complexity, can cause rendering issues
Stack(
  children: [
    Positioned.fill(left: 68, child: content),
    Positioned(left: 0, top: 0, bottom: 0, width: 68, child: sidebar),
  ],
)
```

## WM Class Matching for Hyprland Rules

The GTK program name (set via `g_set_prgname`) and the window title determine the WM class. For Hyprland `windowrulev2` rules:

```ini
windowrulev2 = float, class:(app_name)
windowrulev2 = size 1280 720, class:(app_name)
windowrulev2 = center, class:(app_name)
```

The `class:` regex matches against the WM_CLASS property, which is derived from `g_set_prgname(APPLICATION_ID)` in `my_application_new()`. Ensure `StartupWMClass=app_name` in the `.desktop` file matches.

## Debugging Window Positioning Issues

When a Flutter app has visual offset (content too far right/bottom, blank bars at top/left):

### Step 1: Isolate the Cause

Temporarily replace complex screens with solid-colored Containers:

```dart
_screens = [
  Container(color: Colors.red),     // test screen 1
  Container(color: Colors.green),   // test screen 2
  Container(color: Colors.blue),    // test screen 3
];
```

If the color fills the correct area (flush against sidebar and top edge), the issue is in the screen layout (Scaffold, AppBar). If there's still blank space, the issue is in the window/GTK layer.

### Step 2: Screenshot Analysis

Take a full-screen screenshot and analyze with image tools to find actual pixel bounds:

```bash
python3 -c "
from PIL import Image
img = Image.open('screenshot.png')
w, h = img.size
pixels = img.load()
first_col, last_col, first_row, last_row = w, 0, h, 0
for x in range(0, w, 2):
    for y in range(0, h, 2):
        r, g, b = pixels[x, y][:3]
        if r + g + b > 30:
            if x < first_col: first_col = x
            if x > last_col: last_col = x
            if y < first_row: first_row = y
            if y > last_row: last_row = y
print(f'App bounds: left={first_col}, top={first_row}, right={last_col}, bottom={last_row}')
print(f'Size: {last_col-first_col}x{last_row-first_row}')
print(f'Left margin: {first_col}px, Top margin: {first_row}px')
"
```

If the content starts at (0,0) with no margins, the Flutter layout is correct and the window is correctly positioned. Any perceived offset is from window decorations (title bar, shadows) rendered by the WM around the window.

### Step 3: Common Root Causes

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Content starts at (0,0) in screenshot but looks shifted | Window decorations (WM title bar + shadows) | Accept standard decorations or handle in first_frame_cb positioning |
| Content has blank space at top | Inner Scaffold with AppBar adding system padding | Remove outer Scaffold, use Container + Row instead |
| Content has blank space at left | Sidebar rendering issue or ExtraContainer margin/padding | Use Row layout, not Stack |
| Content extends past right edge | Window too wide or Row overflow | Set default size to fit display, use `Expanded` properly |
| Same issue on different builds | Runner/C++ code not being rebuilt | Check binary timestamps, `flutter clean` before rebuild |

## Testing

After rebuilding (`flutter build linux --release`), verify:

- [ ] No double title bars on Hyprland/Sway/KDE
- [ ] Window resizes correctly without clipping
- [ ] Flutter content fills the available area (accounting for WM title bar)
- [ ] Content starts flush against the sidebar (no left margin)
- [ ] Content starts below the title bar (no top margin beyond WM decorations)
- [ ] `StartupWMClass` matches (check with `hyprctl clients` on Hyprland)
- [ ] Screenshot analysis confirms content bounds are correct

## Complete Working Runner Configuration

```c
static void first_frame_cb(MyApplication* self, FlView* view) {
  GtkWindow* window = GTK_WINDOW(gtk_widget_get_toplevel(GTK_WIDGET(view)));
  gtk_widget_show(GTK_WIDGET(window));
}

static void my_application_activate(GApplication* application) {
  // ... window creation ...

  if (use_header_bar) {
    GtkHeaderBar* header_bar = GTK_HEADER_BAR(gtk_header_bar_new());
    gtk_widget_show(GTK_WIDGET(header_bar));
    gtk_header_bar_set_title(header_bar, "App Name");
    gtk_header_bar_set_show_close_button(header_bar, TRUE);
    gtk_window_set_titlebar(window, GTK_WIDGET(header_bar));
  } else {
    gtk_window_set_title(window, "App Name");
  }

  gtk_window_set_default_size(window, 1280, 720);
  gtk_window_set_resizable(window, TRUE);
  // NO gtk_window_set_position() — handled by WM or first_frame_cb

  // ... rest of setup ...
}
```

This gives a standard window with WM decorations on every platform. The content starts at the correct position (below the title bar, no extra offset). No decoration hacks, no position hints that get ignored.
