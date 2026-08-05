# The Holy Lands — Full Architecture Blueprint

**Session:** May 6, 2026
**User:** synth (synthalorian)
**Status:** Design phase only — no code written

## Core Vision

Three pillars: **Faith. Steel. Sand.**

## Gameplay Loop

```
Accept Quest (Church/Monarch)
  → Travel (caravan, horse, pilgrimage routes)
  → Engage (combat, diplomacy, stealth, investigation)
  → Earn (gold, relics, reputation, faith)
  → Return (temple, camp, chapter hub)
  → Progress (upgrades, narrative, faith restoration)
```

## Core Systems

### A. Combat — "The Weight of Steel"
- 12th-century weapon tree: longsword, mace, spear, crossbow, shield, falchion, battleaxe
- Stance system: Guard, Strike, Feint, Thrust
- Parry/riposte with tight windows
- Fatigue-based stamina (not fast regen)
- Armor degradation
- Horse combat (cavalry charges, lances)
- Siege combat (trebuchets, towers, walls)

### B. Faith System — "The Light Within"
- Faith bar (0-100) decays through sin, refills through prayer/sacraments/relics
- Spiritual states: Blessed (>75) → Wavering (40-75) → Doubting (10-40) → Apostate (<10)
- Each state has mechanical penalties and narrative consequences
- Relics: rare holy objects with passive bonuses
- Miracles: unlockable at high faith (heal, smite, blind, bless weapon)
- Visual feedback: golden vignette (blessed) → desaturated (apostate)

### C. Progression — "Knight to Master"
- Rank: Novice → Serf → Brother → Knight → Marshal → Grand Master
- 3 skill trees: Warrior, Pilgrim, Strategist
- Faction reputation tracking
- Wealth: gold, land grants, fortress building

### D. Exploration — "The Pilgrim's Road"
- ~200km² real Holy Land map, scaled
- Cities: Jerusalem, Acre, Antioch, Cairo, Damascus, Tyre, Edessa
- Travel: foot, horse, caravan
- Weather: heat waves, sandstorms, rain, snow
- POIs: ruins, tombs, hermit caves, Byzantine mosaics

### E. Factions
- Knights Templar, Hospitaller, Muslim armies (Saladin's), local Christians, merchants, Assassins, Bedouin, Pilgrims
- Each tracks reputation independently

### F. Crafting & Logistics
- Equipment crafting, siege equipment, supplies, horse breeding, fortress management

## Unity Project Structure

```
TheHolylands/
├── Assets/
│   ├── Scripts/
│   │   ├── Core/ (Singleton, GameBootstrapper, Persistence, EventSystem, Diagnostics)
│   │   ├── Player/ (Movement, Combat, Stamina, Interaction)
│   │   ├── NPCs/ (AI, Dialogue, Reputation, Pathfinding)
│   │   ├── World/ (TimeWeather, Environment, POIs, Transportation, FloraFauna)
│   │   ├── Combat/ (AttackData, AI, WeaponSystems, Damage, Siege, HorseCombat)
│   │   ├── Progression/ (Quests, Skills, Faith, Reputation, Economy)
│   │   ├── Buildings/
│   │   ├── UI/ (HUD, Menus, DialogueUI, Notifications)
│   │   ├── Audio/ (Music, SFX, Voice)
│   │   ├── SaveLoad/
│   │   ├── Analytics/
│   │   └── Shaders/
│   ├── Shaders/
│   ├── Prefabs/
│   ├── Scenes/ (Loading, Cities, Wilderness, Databases, UI)
│   └── Editor/
└── Packages/
```

## Key Technical Decisions

- **Architecture:** Hybrid ECS + Component-based (DOTS for combat/world, GameObject for narrative/UI)
- **Animation:** Mecanim + Animation Rigging + IK
- **AI:** Behavior Trees (combat) + GOAP (NPC behavior)
- **Navigation:** NavMesh + Custom desert pathfinding
- **Streaming:** Unity Addressables
- **Save:** Custom binary serialization, chunk-based, versioned
- **Input:** Unity New Input System
- **World gen:** Handcrafted base + procedural variation (seeded POIs)
- **Fog of War:** Per-player 2D overlay, revealed through exploration

## Combat System Detail

### AttackDataSO
```
type: Melee/Ranged/Siege
stance: Guard/Strike/Feint/Thrust
damageType: Slash/Pierce/Crush/Fire
damageRange: Vector2 (min/max)
speed: float
windup/active/recovery: float
staminaCost: float
hitbox: HitboxDefinition
armorPenetration: float (0-1)
```

### Combat State Machine
```
Idle → Guard (default)
Guard → Strike / Feint
Strike → Recovery
Recovery → Strike (combo) / Guard
Any → Parry → Riposte
LowStamina → Stagger
```

### Damage Calculation
```
damage = attack.damage * weapon.modifier * stance.modifier * (1 - armor.armorRating * 0.5)
* criticalMultiplier (weak point)
* stanceModifier (crush beats guard, pierce beats heavy, slash beats light)
```

## Faith System Detail

### FaithManager (Singleton)
```
currentFaith: float (0-100)
spiritualState: Blessed | Wavering | Doubting | Apostate
decayRate: float (per minute)
actions: Prayer(), Fasting(), RelicUsage(), SinAction(), Miracle()
```

## AI System Detail

### Combat AI (Behavior Tree)
```
Perception: Sight, Hearing, AlertLevel
BehaviorTree:
  Selector
    → Action: AttackTarget()
    → Action: FleeIfLowHealth()
    → Action: SeekCover()
    → Action: CallReinforcements()
Memory: LastKnownPlayerPos, PlayerHistory, FactionRelation
```

### NPC AI (GOAP)
```
Goals: [Eat, Sleep, Work, Rest, Socialize, Flee, Fight, Trade]
Actions: [WalkTo, PickUp, Eat, Talk, Trade, DrawWeapon]
WorldState: Time, Hunger, Fatigue, ThreatLevel, SocialNeeds
Planner: Generates action sequence for highest-priority goal
```

## Audio System

- **Dynamic music layers:** Pilgrimage (safe), Combat (tension), Siege (epic), Temple (faith)
- **Ambient soundscapes:** Per-zone, dynamic reverb, footstep surface detection
- **Voice:** Dialogue system, NPC ambient chatter, prayer call scheduling

## UI/UX Approach

Diegetic-first:
- Health/Faith/Stamina shown on character body/armor where possible
- Map: hand-drawn parchment style
- Dialogue: diegetic text box with NPC portraits and branching choices
- Inventory: grid-based, equipment visible on character model
- Quest log: journal book, not a list

## Save/Load System

- Binary, chunk-based, versioned format
- Auto-save every 5 min + checkpoint triggers
- Manual save at temples/fortresses/camps only
- Cloud sync optional (Steam, PS, Xbox)

## Performance Targets

| Platform | FPS | Resolution |
|----------|-----|------------|
| PC (high) | 60 | 4K ultra |
| PC (medium) | 30 | 1440p high |
| PS5/Xbox | 30 | 4K dynamic |

## Optimization Strategy

- 4-level LOD for all models
- Baked occlusion culling (hand-tuned)
- Addressables asset streaming
- Simplified physics for NPCs, full for player/combat
- Instancing for repeated assets (columns, arches, NPCs)

## Recommended Phases (Solo Dev)

| Phase | Scope | Timeline |
|-------|-------|----------|
| 1: Core | Combat prototype, faith system, one city, basic UI, save/load | Months 1-6 |
| 2: Content | Second city, quest system, NPC AI, horse combat, crafting | Months 7-14 |
| 3: Polish | Full world, siege, fortress management, questlines, audio polish | Months 15-20 |
| 4: Launch | Bug fixing, platform cert, beta, patch prep | Months 21-24 |

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Engine | Unity 6 (DOTS/Hybrid ECS) |
| Language | C# |
| Animation | Mecanim + Animation Rigging + IK |
| AI | Behavior Trees + GOAP |
| Nav | NavMesh + Custom desert pathfinding |
| Audio | Unity Audio |
| UI | UGUI |
| Input | New Input System |
| Streaming | Addressables |
| Save | Custom binary serialization |
| Version Control | Git + Git LFS |

## Unique Selling Points

1. **Faith as a core mechanic** — not decoration, the spiritual dimension IS the heart
2. **Real 12th-century combat** — heavy, deliberate, historically grounded
3. **Living, breathing Holy Land** — real cities, real routes, real weather
4. **Faction reputation that actually matters** — actions ripple across the world
5. **Siege + open world** — castle engineering, not just field battles
6. **Pilgrimage narrative** — the journey IS the story

## Related Sessions

- **.env cleanup:** May 6, 2026 — Cleaned 2 redundant `.env.example` files across projects
- **The Holy Lands blueprint:** This session (May 6, 2026)
