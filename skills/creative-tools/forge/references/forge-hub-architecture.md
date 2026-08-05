# Forge Hub Architecture — File Map

> **Note:** As of v0.2.0, Forge Hub lives at `~/projects/forge/hub/` (monorepo). The old `~/projects/forge-hub/` standalone repo is deleted.

## Key Directories

```
~/projects/forge/hub/
├── app/
│   ├── assets/
│   │   ├── tailwind/application.css    # Tailwind v4 source (themes, effects, custom utilities)
│   │   └── builds/tailwind.css         # Built output (serve this)
│   ├── controllers/
│   │   ├── dashboard_controller.rb     # GET /
│   │   ├── anvil_controller.rb         # /anvil namespace
│   │   ├── anvil/
│   │   │   ├── backups_controller.rb   # /anvil/backups (index, show, browse, trigger, chart_data)
│   │   │   └── schedules_controller.rb # /anvil/schedules (index, create, destroy)
│   │   ├── bellows_controller.rb       # /bellows (coming soon)
│   │   ├── flame_controller.rb         # /flame (coming soon)
│   │   ├── tongs_controller.rb         # /tongs (coming soon)
│   │   ├── crucible_controller.rb      # /crucible — index + chords/palette/diagram (forge melt bridge, controller written but sub-action views/partials pending)
│   │   ├── bridge_controller.rb        # /bridge (coming soon)
│   │   └── engines/
│   │       └── base_controller.rb      # shared coming_soon rendering
│   ├── helpers/
│   │   ├── anvil_helper.rb             # human_size, time_ago, human_time, backup_type_badge
│   │   └── components_helper.rb        # stat_card, card, badge, empty_state
│   ├── javascript/controllers/
│   │   ├── theme_controller.js         # theme switching (cookie persistence)
│   │   ├── sidebar_controller.js       # sidebar collapse (localStorage)
│   │   ├── backup_progress_controller.js  # real-time backup output via Action Cable
│   │   └── backup_chart_controller.js  # Chart.js backup history (30 days)
│   ├── jobs/
│   │   ├── backup_job.rb               # async forge backup via Solid Queue
│   │   └── restore_job.rb              # async forge restore
│   ├── services/forge/
│   │   ├── client.rb                   # shells out to `forge` binary
│   │   ├── database.rb                 # direct SQLite reads on ~/.forge/db/forge.db
│   │   └── statistics.rb               # aggregates backup/repo/schedule/disk stats
│   └── views/
│       ├── layouts/
│       │   ├── application.html.erb    # main layout (sidebar + topbar + main)
│       │   ├── _sidebar.html.erb       # pillar nav, theme picker, version
│       │   └── _topbar.html.erb        # breadcrumb, connection status
│       ├── dashboard/show.html.erb     # main dashboard (stats, top repos, latest backup, pillars)
│       ├── anvil/
│       │   ├── backups/
│       │   │   ├── index.html.erb      # backup list with chart + progress
│       │   │   ├── show.html.erb       # single backup detail
│       │   │   └── browse.html.erb     # browse backup file tree
│       │   └── schedules/index.html.erb # schedule management
│       ├── components/
│       │   ├── _stat_card.html.erb     # metric card (icon + value + label)
│       │   ├── _card.html.erb          # generic panel (icon + title + content)
│       │   ├── _badge.html.erb         # colored status badge
│       │   └── _empty_state.html.erb   # CTA for empty lists
│       └── engines/coming_soon.html.erb # standalone page with inline CSS
├── config/
│   ├── routes.rb                       # RESTful routes for all pillars
│   ├── importmap.rb                    # Stimulus/Turbo/ActionCable pins
│   └── initializers/forge.rb           # forge binary path config
└── lib/engines/                        # Rails engines for each pillar (future extraction)
    ├── anvil/
    ├── bellows/
    ├── flame/
    ├── tongs/
    ├── crucible/
    └── bridge/
```

## CSS Token Map

Tailwind utility classes → theme CSS variables:

| Utility class        | CSS variable                | Synthwave84 value  |
|---------------------|-----------------------------|-------------------|
| `bg-bg-dark`        | `--theme-bg-dark`           | `#0d0221`         |
| `bg-bg-panel`       | `--theme-bg-panel`          | `#180030`         |
| `bg-bg-surface`     | `--theme-bg-surface`        | `#240037`         |
| `bg-bg-card`        | `--theme-bg-card`           | `#12062e`         |
| `text-neon-purple`  | `--theme-primary`           | `#8f00ff`         |
| `text-neon-cyan`    | `--theme-success`           | `#03edf9`         |
| `text-neon-pink`    | `--theme-pink`              | `#ff7edb`         |
| `text-neon-hot-pink`| `--theme-accent`            | `#ff00ff`         |
| `text-neon-blue`    | `--theme-secondary`         | `#0080ff`         |
| `text-text-primary` | `--theme-text-primary`      | `#e0e0e0`         |
| `text-text-muted`   | `--theme-text-muted`        | `#614d85`         |
| `text-text-dim`     | `--theme-text-dim`          | `#555`            |
| `border-border-faint` | `--theme-border-faint`   | `rgba(143,0,255,0.15)` |
| `bg-sidebar-bg`     | `--theme-sidebar-bg`        | `#0d0221`         |
| `bg-sidebar-hover`  | `--theme-sidebar-hover`     | `#240037`         |
| `bg-sidebar-active` | `--theme-sidebar-active`    | `rgba(143,0,255,0.15)` |

Fixed colors (not theme-aware): `--color-neon-green: #00ff6a`, `--color-neon-red: #ff0040`, `--color-neon-yellow: #f3e70f`

> **Design rule:** Purple (`#8f00ff`) is the primary brand color. Cyan is for success/signal only. Never invert this hierarchy.

## Visual Effects (CSS)

- **Grid overlay** — `body::before` repeating linear gradient using `--theme-glow-a`
- **Horizon glow** — `.horizon-glow` radial gradient at bottom using `--theme-glow-b`
- **CRT scanlines** — `body::after` repeating gradient (2px lines, 3% opacity)
- **Neon glow on icons** — `drop-shadow-[0_0_8px_currentColor]`
- **Panel hover glow** — `hover:shadow-lg hover:shadow-neon-purple/5`
- **Backdrop blur** — `backdrop-blur-sm` on panels
- **Connection dot glow** — `shadow-[0_0_6px_rgba(0,255,106,0.6)]` on green dot
