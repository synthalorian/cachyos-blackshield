# The Holy Lands — Architecture Blueprint

Session: 2026-05-06 — Game architecture sketch for "The Holy Lands"
Engine: Unity 6 (Hybrid ECS)
Genre: Open-world RPG sandbox, Crusades era, Templar protagonist

## Core Pillars

**Faith. Steel. Sand.**

- **Faith** — Spiritual strength is a core mechanic. Bar that decays through sin, refills through prayer/sacraments/relics. 4 spiritual states with mechanical AND narrative consequences.
- **Steel** — 12th-century melee combat: heavy, deliberate, weighty. Stance-based (Guard/Strike/Feint/Thrust), tight parry windows, fatigue-driven stamina.
- **Sand** — Real geography, real cities, real weather. The desert is a living mechanic. Heat drains stamina, sandstorms reduce visibility, water sources control exploration.

## Gameplay Loop

```
Accept Quest → Travel (caravan/horse/foot) → Engage (combat/diplomacy/stealth)
→ Earn (gold/relics/reputation/faith) → Return (temple/camp/chapter hub)
→ Progress (upgrades/narrative/faith restoration) → Repeat (escalated)
```

## Core Systems

### Combat — "The Weight of Steel"
- 12th-century weapon tree: longsword, mace, spear, crossbow, shield, falchion, battleaxe
- Stance system: Guard/Strike/Feint/Thrust — each with unique movesets
- Parry/riposte timing: tight windows, high reward
- Fatigue-based stamina: heavy attacks drain more, leave you winded
- Armor degradation: chainmail gets dented/pierced, affects protection
- Horse combat: mounted charges, lances
- Siege combat: trebuchets, siege towers, wall defense

### Faith System — "The Light Within"
- Faith bar (0-100): decays through sin, refills through prayer, fasting, relics, sacraments
- Spiritual states:
  - **Blessed** (>75): +15% damage to heretics, prayer answers, golden vignette
  - **Wavering** (40-75): normal state
  - **Doubting** (10-40): -50% faith regen, NPCs suspicious
  - **Apostate** (<10): combat penalties, stamina drain, NPCs hostile, screen desaturated
- Miracles: unlockable at high faith — healing light, smite enemy, bless weapon
- Relics: physical holy objects that boost faith, grant passive abilities

### Exploration — "The Pilgrim's Road"
- ~200km² map, scaled down but geographically accurate
- Key locations: Jerusalem, Acre, Antioch, Cairo, Damascus, Tyre, Edessa
- Travel modes: on foot, horse, caravan
- Day/night cycle: 24-hour real-time
- Weather: heat waves, sandstorms, rain, snow
- Points of interest: ruins, abandoned churches, hidden tombs, hermit caves, oases

### Faction System — "The Web of Power"
- Knights Templar, Knights Hospitaller, Saladin's forces, Turkish emirs
- Genoese/Venetian/Pisan merchants, Assassins (Nizari), Bedouin tribes
- Local Christians: Greeks, Armenians, Jacobites
- Pilgrims — moral weight, quest givers
- Cross-faction reputation tracking

### Progression — "Knight to Master"
- Rank system: Novice → Serf → Brother → Knight → Marshal → Grand Master
- Each rank unlocks new abilities, gear tiers, dialogue options, fortress slots
- Skill trees: 3 branches — Warrior (combat), Pilgrim (faith/spirit), Strategist (diplomacy/logistics)
- Reputation: each faction tracks you independently
- Wealth: gold for equipment, land grants, building fortresses

## Unity Architecture

### Project Structure
```
Assets/
├── Scripts/
│   ├── Core/              — Singleton, GameBootstrapper, EventSystem, data types
│   ├── Player/            — Movement, Combat, Inventory, PlayerController
│   ├── World/             — Time/Weather, POI, WorldSystem, FogOfWar
│   ├── Combat/            — Attack data, hitboxes, damage, AI combat
│   ├── NPCs/              — NPCManager, AI, Behavior Trees, GOAP, Dialogue
│   ├── Progression/       — Skills, reputation, faith, economy
│   ├── Quests/            — QuestManager, objectives, triggers, rewards
│   ├── Buildings/         — Fortress management, construction, upgrades
│   ├── UI/                — HUD, menus, dialogue UI, map, notifications
│   ├── Audio/             — Dynamic music, ambient, SFX, voice
│   ├── SaveLoad/          — Binary serialization, chunk-based saves
│   └── Analytics/         — Event logging, session tracking
├── Shaders/
├── Materials/
├── Models/
├── Animations/
├── Prefabs/
├── Editor/
├── Resources/
├── Scenes/
│   ├── Loading/
│   ├── Cities/
│   ├── Wilderness/
│   ├── Databases/
│   └── UI/
└── Audio/
```

### Key Technical Decisions
- **Architecture:** Hybrid ECS + Component-based (heavy systems use ECS, narrative/UI stay component-based)
- **Animation:** Mecanim + Animation Rigging + IK for procedural adjustments
- **Navigation:** NavMesh + Custom desert pathfinding
- **World Streaming:** Addressables + AsyncSceneLoading
- **Save System:** Binary serialization, chunk-based, AES-256 encryption
- **Input:** New Input System
- **Data:** ScriptableObject-first, designers configure without code

### Data Types (ScriptableObjects)
- `AttackData` — Attack type, stance, damage, timing, hitbox, effects
- `WeaponData` — Tier, stats, durability, requirements, modifiers
- `ArmorData` — Slot, resistances, weight, movement modifiers
- `ItemData` — Consumable, tool, material, relic, quest properties
- `FactionData` — Stance, reputation, relations, economy, spawn data
- `EnemyData` — Combat stats, AI preset, equipment, loot table, abilities
- `QuestData` — Type, category, narrative, triggers, objectives, rewards
- `SkillData` — Branch, tier, effect, requirements, visual effects

## AI System
- **Combat AI:** Behavior Trees — fast, debuggable, state-based
- **NPC Daily Life:** GOAP (Goal-Oriented Action Planning) — flexible, dynamic
- **Perception:** Sight, hearing, alert level
- **Memory:** Last known player position, faction history, reputation

## Audio System
- **Dynamic music:** Layers switch based on context (pilgrimage/combat/siege/temple)
- **Ambient:** Per-zone audio with dynamic reverb
- **Footsteps:** Surface detection (stone, sand, dirt, cobble, wood)
- **Voice:** Dialogue with text-to-speech placeholder, real voice for main characters
- **Prayer calls:** Scheduled across cities, triggers audio events

## UI/UX
- **Diegetic-first:** UI feels like part of the world
- **Health/Faith/Stamina:** On-body display where possible, minimal HUD
- **Compass:** Physical compass in inventory
- **Map:** Hand-drawn parchment, reveals as explored
- **Dialogue:** Diegetic text box, NPC portraits, branching choices
- **Combat UI:** Minimal — stamina bar, weapon indicator, hit feedback

## Save System
- Chunk-based binary serialization, versioned
- Auto-save every 5 minutes + manual save at checkpoints (temples, fortresses, camps)
- AES-256 encrypted
- Cloud sync optional (Steam Cloud, PlayStation, Xbox)
- Data: PlayerState, WorldState, QuestState, EconomyState, ReputationState

## Performance Targets
| Platform | Target | Resolution |
|----------|--------|------------|
| PC (high) | 60fps | 4K, ultra |
| PC (medium) | 30fps | 1440p, high |
| PS5/Xbox | 30fps | 4K, dynamic |

- LOD system: 4 levels of detail for all models
- Occlusion culling: baked, hand-tuned
- Addressables: stream assets on demand
- Physics: simplified for NPCs, full for player/combat
- Shaders: custom, minimal alpha testing

## Development Phases
| Phase | Scope | Timeline |
|-------|-------|----------|
| 1: Core | Combat prototype, faith system, one city, basic UI | Months 1-6 |
| 2: Content | Second city, quest system, NPC AI, horse combat | Months 7-14 |
| 3: Polish | Full world, siege, fortress management, questlines | Months 15-20 |
| 4: Launch | Bug fixing, platform cert, beta, patch prep | Months 21-24 |

## Unique Selling Points
1. **Faith as a core mechanic** — not decoration, not a side quest. The spiritual dimension is the heart.
2. **Real 12th-century combat** — no anime sword swings. Heavy, deliberate, historically grounded.
3. **Living, breathing Holy Land** — not a generic fantasy map. Real cities, real routes, real weather.
4. **Faction reputation that actually matters** — your actions ripple across the world.
5. **Siege + open world** — not just field battles. Actual castle sieges with engineering.

---

Built by synth. Faith. Steel. Sand. 🎹🦞
