# JRPG Turn-Based Conviction Architecture (Unity C#)

Canonical architecture for a **turn-based JRPG** in Unity with a **Conviction-style resource system** (mana-replacement), **Legacy/permadeath inheritance**, **hex-grid tactical combat**, and **allegorical mission structure**. Built for "Gospel of Steel" (Americanized Christian JRPG) but the engine-pattern is project-agnostic.

## When to Use This Reference

- User wants a JRPG-style turn-based combat system in Unity (turn queue, party management, skills)
- User wants a non-mana resource system — something earned through action (conviction/faith/honor)
- User wants a permadeath-with-legacy system where characters pass stats to successors
- User wants a hex-grid tactical layer on top of JRPG combat
- User wants mission/parable-style narrative progression
- User wants to build ALL C# code BEFORE opening Unity (code-first workflow)

## Architecture Overview

The game is built as a collection of singleton MonoBehaviours (manager pattern), pure C# data objects (CharacterBase, TestamentData, CombatCommand), and ScriptableObject data types. No ECS, no heavy frameworks. Standard Unity component-based with event-driven communication between systems.

| Metro Area | Lead Systems | Scripts |
|---|---|---|
| Combat | BattleManager, TurnManager, CombatCommand, DamageCalculator | 6 |
| Characters | CharacterBase, PartyMember, Enemy | 3 |
| Resources | ConvictionSystem, SkillUnlockSystem | 2 |
| Legacy | LegacySystem, SaveSystem | 2 |
| Party | PartyFormation, EquipmentManager, InventoryManager | 3 |
| Economy | ShopManager, LootTableSystem, CraftingSystem | 3 |
| Grid | HexCoord, HexGridManager, HexTile | 2 |
| Missions | ParableMission, MissionManager, CutsceneManager, ChapterManager | 4 |
| Effects | StatusEffectManager, DayNightCycle, BattleBackdropSystem | 4 |
| UI | PauseScreen, TitleScreen, GameOverScreen, OptionsScreen, SaveSlotUI, InventoryScreen, EquipmentScreen, SkillAssignmentScreen, TestamentViewScreen, CharacterDetailScreen, AchievementScreen, BestiaryScreen, BattleHUD, DialogueManager, BattleVictoryScreen, ObjectiveTracker, MenuManager | 17 |
| Feedback | BattleLog, VFXManager, BattleSpeedControl, StatusEffectVisuals, TutorialSystem | 5 |
| Systems | GameConfig, InputRebinding, AutoSaveSystem, NPCInteraction, WorldMapSystem, AchievementSystem, BestiarySystem, MinigameSystem, TargetSelectionUI, DayNightCycle, AudioManager, LocalizationManager | 12 |
| Data | CharacterDataSO, SkillDataSO, ItemDataSO, EnemyDataSO | 4 |

## Code-First Development Workflow

Build ALL C# code before opening Unity Editor. Every system is written as pure C# with `MonoBehaviour`/`ScriptableObject` base classes but NO Editor-wired prefab references (those get `public GameObject` fields assigned later). This means:

1. **Write code files** — scripts compile in Unity's assembly-csharp without errors
2. **Open Unity** — assign prefab references, drag MonoBehaviours onto GameObjects, wire button listeners in Inspector
3. **Test** — everything works first-run because the code was written expecting the Editor wiring

**Key pattern:** `public GameObject damageNumberPrefab;` defaults to null. All calling code checks `if (prefab != null)` before using it. The game runs without errors even when prefabs aren't assigned — it just logs instead of spawning VFX.

## Code Architecture

### Singleton Manager Pattern

Every major system follows this exact pattern:

```csharp
public class SomeManager : MonoBehaviour
{
    public static SomeManager Instance { get; private set; }

    void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject); // Only for persistent systems
    }
}
```

**When to use DontDestroyOnLoad:** GameManager, ConvictionSystem, LegacySystem, SaveSystem, AutoSaveSystem, GameConfig, AudioManager, AchievementSystem, BestiarySystem, DayNightCycle, WorldMapSystem, InputRebinding, LocalizationManager, TutorialSystem, ChapterManager.

**When NOT to use DontDestroyOnLoad (scene-scoped):** BattleManager, TurnManager, BattleHUD, HexGridManager, OverworldController, NPCInteraction, RandomEncounterManager — these belong to specific scenes and get destroyed/rebuilt on scene transitions.

### Event-Driven Communication

Systems communicate through C# events (not UnityEvents, not direct coupling):

```csharp
// Event definition (on the emitting class)
public event Action<BattleOutcome> OnBattleComplete;

// Subscribe (in Start, on the receiving class)
var battleManager = FindFirstObjectByType<BattleManager>();
if (battleManager != null)
    battleManager.OnBattleComplete += HandleBattleComplete;

// Unsubscribe (in OnDestroy)
void OnDestroy()
{
    if (battleManager != null)
        battleManager.OnBattleComplete -= HandleBattleComplete;
}
```

**Always null-check the Find:** `FindFirstObjectByType` can return null. Always wrap in `if (manager != null)`.

### Pure C# Data Objects

These classes do NOT inherit from MonoBehaviour. They live in lists and are serialized with [System.Serializable]:

- `CharacterBase` — Abstract stat container (HP, STR, SPI, END, SPD, status effects)
- `PartyMember : CharacterBase` — XP, leveling, Conviction, inventory, equipment, Testament
- `Enemy : CharacterBase` — Simpler, no leveling/inventory
- `TestamentData` — Serializable snapshot of a fallen hero
- `CombatCommand` — Immutable action descriptor (source, target, skill)
- `StatusEffectInstance` — Runtime effect instance (def, remaining turns, magnitude)
- `TurnActor` — Wrapper that unifies PartyMember and Enemy in the turn queue
- `LogEntry` — Battle log entry
- `SaveGameData` / `PartySaveData` — Serializable save snapshots

## Complete Project Inventory (Final State)

After iterative development across ~8 sessions, the codebase reached **117 C# scripts, 16,494 lines** across these categories:

| Category | Scripts | Lines | Lead Systems |
|----------|---------|-------|-------------|
| Core | 9 | 1,589 | GameManager, TurnManager, BattleManager, OverworldController, RandomEncounterManager, GameConfig, ChapterManager, NPCInteraction, CutsceneManager |
| Characters | 3 | 400 | CharacterBase (abstract), PartyMember, Enemy |
| Combat | 7 | 1,082 | BattleHUD, BattleLog, CombatCommand, DamageCalculator, StatusEffectVisuals, TargetSelectionUI, EnemyTelegraphSystem |
| Systems | 59 | 9,089 | All managers and gameplay systems (see full list below) |
| Data | 4 | 185 | CharacterDataSO, SkillDataSO, ItemDataSO (updated with elements/rarity), EnemyDataSO |
| Grid | 2 | 274 | HexCoord, HexGridManager (flat-top axial) |
| Items | 1 | 72 | ItemBase, Equipment, Consumable |
| Missions | 2 | 213 | MissionManager, ParableMission |
| Audio | 1 | 143 | AudioManager (synthwave soundtrack, state-driven) |
| UI | 29 | 3,447 | 29 screens (all listed below) |

**59 Systems in detail:**

| System | Purpose | Key Feature |
|--------|---------|-------------|
| AchievementSystem | 15 milestones with Conviction rewards | Event-driven unlock, PlayerPrefs persistence |
| AffixSystem | Random prefixes/suffixes on equipment | 5 prefixes + 5 suffixes, per-category filtering |
| AutoManageSystem | Auto-sell/salvage common items | Configurable thresholds per rarity |
| AutoSaveSystem | Event-driven auto-save | Battle victory, campfire, chapter, 10-min periodic |
| BattleBackdropSystem | Region-based battle backgrounds | Camera tint + ambient audio per region |
| BattleSpeedControl | Fast-forward + auto-battle | Shift=3x, A=toggle auto |
| BattleTransitionSystem | Screen flash + fade transitions | Enter/exit battle with configurable timing |
| BenchSystem | Reserve party members get 50% XP | Promote/bench, max 6 active, auto-bench |
| BestiarySystem | Auto-discover enemies on defeat | Lore, stats, kill count, discovery % |
| BossAIPattern | Phase-based boss AI | HP threshold phases, per-phase patterns, self-buffs |
| BountySystem | Kill-target contracts | Auto-generated per chapter, gold/CV/item rewards |
| CampDialogueSystem | Party conversations at campfires | 6 scripted dialogues, chapter+CV gated |
| CampfireSystem | Rest/save/pray points | Full heal, Conviction gain, Testament reflection |
| CollectibleSystem | Hidden items in regions | 5 default, CV+gold+achievement rewards |
| CombatAISystem | 6-state enemy AI | Aggressive/Defensive/Coordinated/Corrupted/Zealot/Retreating |
| ComboSystem | Party chain actions | 9 combo types, +30%/chain, max +200% |
| CompanionAffinitySystem | Party member relationships | Strangers→Bonded→Devoted→Exalted tiers |
| ConvictionSystem | Core resource (earned-not-found) | 5 gain sources, conviction-bonused damage/crits |
| CraftingDiscoverySystem | Find recipes in the world | PlayerPrefs persistence, runtime generation |
| CraftingSystem | Material→item recipes | Gold cost discounted by Conviction |
| DayNightCycle | 24-hour overworld cycle | 4 phases, encounter rate changes, ambient shifts |
| DebugConsole | Developer command console | 17 commands, history, backtick toggle |
| ElementResistanceSystem | 8 damage elements | Physical/Spirit/Fire/Lightning/Light/Dark/Bleed/True |
| EnemyScalingSystem | Level-based stat scaling | AnimationCurve, 0.5x–3x range |
| EnemyVarietySystem | Random enemy modifiers | 6 types (Vicious/Armored/Fanatic/Cursed/Swift/Ancient) |
| EquipmentManager | Equip/unequip with stat calc | Weapon/Armor/Accessory, upgrade+set integration |
| FactionReputationSystem | 4 default factions | Hostile→Friendly→Honored tiers, shop price mods |
| InputRebinding | Per-action key customization | 8 default bindings, PlayerPrefs persistence |
| InventoryManager | Shared party item pool | Add/remove/has/use, gold management |
| ItemSetBonuses | Matching gear bonuses | Per-piece stat scaling, active tracking |
| ItemUpgradeSystem | +1 to +5 equipment upgrades | 15% stat/level, Conviction gold discount |
| LegacySystem | Permadeath inheritance | Testament recording, 50% stat inheritance, Vow of Steel |
| LoadoutSystem | Save/load party configurations | Equipment + skills, up to 5 slots |
| LocalizationManager | Key-value string table | 30+ defaults, CSV-ready, format() |
| LootTableSystem | Weighted rarity drops | 5 tiers, Conviction drop bonus |
| LoreSystem | Discoverable world lore | 8 entries, 5 categories, CV rewards |
| MapMarkerSystem | Objective waypoints | Nearest-marker tracking, clear on complete |
| MerchantRestockSystem | Shop refresh per chapter | Pool-based rarity scaling |
| MinigameSystem | Timing-based skill checks | Conviction makes easier, Perfect/Good/Fail |
| NewGamePlus | Multi-cycle endgame | 25% scaling/cycle, carries over Testaments/achievements |
| PartyFormation | Front/back row system | 3+3 slots, FR bonus/BR reductions, AI targeting |
| QuickItemUse | Hotkey healing/CV restore | Q=heal, E=CV, works in battle+overworld |
| RandomEventSystem | Exploration events | 5 types, weighted tables per region |
| RepairSystem | Equipment durability | 100 max, -5/battle, repair cost scales |
| SalvageSystem | Break items into components | Rarity-based return rate, preview |
| SaveFileManager | Multi-profile save management | 5 profiles, metadata (timestamp, file size) |
| SaveMetadataEnrichment | Richer save data | Chapter title, location, party level, play time |
| SaveSystem | Binary serialization | JSON+Base64+header integrity |
| ShopManager | Buy/sell with price multipliers | Category filtering, conviction discounts |
| SkillTierSystem | Tier I/II/III upgrades | +40% power, +30% cost per tier |
| SkillUnlockSystem | Conviction-based skill learning | 6 milestones (25-500 CV), auto-equip |
| StatBreakpointSystem | Stat threshold passives | 10 breakpoints, 4 effects (turn/crit/regen/reduction) |
| StatueMemorialSystem | Fallen hero statues | Scripture+CV on visit, Testament-based generation |
| StatusEffectManager | 12-type buff/debuff system | Stacking, DoT/HoT, stat multipliers, cleansing |
| TreasureChestSystem | Lootable overworld chests | Items/gold/CV, locked needs key, persisted |
| TutorialSystem | First-time contextual tips | 8 tips, PlayerPrefs persistence |
| VFXManager | Damage numbers, screen shake | 3 color types, curve-driven shake, skill VFX |
| WeatherSystem | 4 weather types | Clear/Rain/Storm/Fog, encounter rate mods |
| WorldMapSystem | Region discovery + fast travel | Campfire-based fast travel, gold cost |

**29 UI Screens:**

| Screen | Trigger | Key UI Elements |
|--------|---------|-----------------|
| TitleScreen | Game boot | Continue, NewGame, Load, Options, Quit |
| PauseScreen | Escape | Party, Items, Equip, Skills, Testaments, Save, Options |
| GameOverScreen | Party wipe | Retry, Vow of Steel, Load, Title |
| OptionsScreen | Menu | BGM/SFX sliders, text speed, difficulty, screen shake |
| SaveSlotUI | Menu | 5 slots, load/save/delete |
| BattleHUD | Battle | Attack/Ability/Items/Defend/Testament, turn counter |
| BattleVictoryScreen | Battle win | XP/CV/loot, level-up, skill unlock, quote |
| BattleLogUI | Battle (L key) | Scrollable color-coded combat log |
| InventoryScreen | Menu | 7 categories, detail view, in-menu use |
| EquipmentScreen | Menu | Slot equip/unequip, stat diff comparison |
| SkillAssignmentScreen | Menu | 4-slot ability bar from learned skills |
| CharacterDetailScreen | Menu | Full buffed+equipped stats, effects, Testament |
| TestamentViewScreen | Menu | Fallen hero records, deeds, scripture |
| ObjectiveTracker | Parable active | HUD: ► active, ✓ complete, progress |
| DialogueManager | NPC/narrative | Typewriter, speaker attribution, advance |
| MenuManager | Overworld | Main menu panel stack |
| AchievementScreen | Menu | 15 milestones, lock/unlock display |
| BestiaryScreen | Menu | Enemy browser, lore, stats, kill count |
| CombatLogUI | Battle | In-battle log panel (separate from BattleLog data) |
| PartyManagementScreen | Menu | Swap active↔bench, roster view |
| PartyOverviewScreen | Menu | HP/CV bars, bench, conviction leaderboard |
| QuestJournal | Menu | Active/completed Parables, bounties, progress |
| GameStatisticsScreen | Menu | Play time, souls, bestiary, collectibles, lore % |
| ItemComparisonScreen | Equipment | Side-by-side stat comparison, green/red diffs |
| ItemTooltipSystem | Hover | Full item stats, rarity, set, affixes, durability |
| LevelUpPreviewSystem | Menu | Current vs next-level stats, XP progress |
| CreditsSystem | End game | Scrolling synthwave credits, scripture, title return |
| AudioOptionsScreen | Menu | BGM/SFX/Ambient sliders, mute toggles |
| AccessibilityOptions | Menu | Color blind, reduced flash, large font, contrast, subs |
| DialogueSpeedOptions | Menu | Slow/Normal/Fast/Instant preset buttons |
| AchievementPopup | Achievement fired | Slide-in toast, 3.5s display, auto-hide |

## Core Systems Detail

### 1. Turn Queue (Speed-Based)

```
TurnManager manages a List<TurnActor> sorted by speed descending.
TurnActor wraps EITHER PartyMember or Enemy (not both).
On each turn: actor executes action → advance index → check death/win → repeat.
```

**Key code structure:**
- `TurnManager.InitializeBattle()` builds queue from all alive actors
- `TurnActor.IsPlayer` distinguishes party from enemies
- `BattleLoop()` coroutine advances queue, fires events, waits for action completion
- Player turns block on `PartyMember.OnActionExecuted` callback
- Enemy turns use `BattleManager.ExecuteEnemyAI()` coroutine

**Battle lifecycle:** `BattleManager.StartBattle()` → Calculate rewards → Show HUD → `TurnManager.InitializeBattle()` → `BattleLoop()` → `CheckBattleEnd()` after each turn → Victory/Defeat.

### 2. Conviction Resource System

Replaces MP/Mana. **Earned, not found.** Starts at 0, maxes at 100 (per character).

**Gain sources:**
| Deed | Conviction Gain |
|------|----------------|
| Defend an ally | 10 |
| Heal a party member | 15 |
| Rescue an NPC | 25 |
| Complete a Parable | 50 |
| Pray at campfire | 30 |
| Hear a preacher | 15 |

**Spend on:** Skills cost Conviction (varies per skill). Check via `PartyMember.ConsumeConviction()`.

**Mechanical hooks:**
- Critical hit rate scales with current conviction (bonus up to 25%)
- Damage multiplier from conviction: +0% to +50% based on ratio
- Defending while taking damage grants conviction (mechanical encouragement)
- Higher conviction = easier minigame skill checks

### 3. Legacy / Testament Inheritance

**Flow:**
1. Party member dies permanently (in a Parable) → `LegacySystem.RecordTestament()`
2. Testament captures: level, all 4 base stats, learned skills, total deeds
3. Successor inherits: 50% of fallen's stats, Testament-only skills
4. **Vow of Steel**: When last party member falls, consume strongest saved Testament to revive them

**Data object:**
```csharp
public class TestamentData {
    string inheritedName;
    int inheritedLevel;
    int inheritedStrength, inheritedSpirit, inheritedEndurance, inheritedSpeed;
    List<SkillDataSO> inheritedSkills;
    int totalDeeds;
}
```

### 4. Damage Calculation

**Physical:** `Strength * 2 - Endurance * 1.5`, ±15% variance, level ratio multiplier (0.5x–2x)

**Spiritual:** `Spirit * 2.5 - Spirit * 1.2`, ±10% variance. Bypasses physical defense.

**Healing:** `Spirit * 3`, ±10% variance, multiplied by skill modifier.

**Role multipliers:**
| Role | Physical | Spiritual |
|------|----------|-----------|
| Penitent | 1.3x | 1.1x |
| Judge | 1.2x | 1.2x |
| Vessel | 1.0x | 1.0x |
| Steadfast | 0.8x | 0.7x |
| Seeker | 0.7x | 1.4x |

**Formation modifiers:** Front row: +15% damage dealt, 100% damage taken. Back row: -30% damage taken, +20% spirit.

**Critical:** 5% base + (conviction ratio * 25%) + Penitent bonus (10%) = up to 40%. 1.5x damage.

**Difficulty modifiers:**
| Difficulty | Player DMG | Enemy DMG | XP | Conviction |
|------------|-----------|-----------|-----|------------|
| Easy | 0.75x | 0.75x | 1.5x | 1.25x |
| Normal | 1.0x | 1.0x | 1.0x | 1.0x |
| Hard | 1.0x | 1.15x | 0.8x | 0.85x |
| Steel | 1.0x | 1.4x | 0.6x | 0.7x |

### 5. Turn Queue Wrapping Pattern

```csharp
public class TurnActor {
    PartyMember PartyMember { get; }
    Enemy Enemy { get; }
    bool IsPlayer => PartyMember != null;
    int ActorSpeed => IsPlayer ? PartyMember.Speed : Enemy.Speed;
    bool IsDead => IsPlayer ? PartyMember.currentHP <= 0 : Enemy.currentHP <= 0;
}
```

### 6. CombatCommand Pattern

Commands decouple intent from execution. Static dispatch keeps all skill logic in one place.

```csharp
// Execute() handles all skill types:
switch (skill.skillType) {
    case SkillType.PhysicalAttack: // Strength-based, role multiplied, formation + conviction
    case SkillType.SpiritualAttack: // Spirit-based, bypasses physical defense
    case SkillType.Healing: // Spirit-based, Seeker role bonus
    case SkillType.Buff: // Apply status effect to target
    case SkillType.Debuff: // Apply harmful status effect
    case SkillType.Testament: // Heavy spiritual damage, costs 30% max HP
}
```

### 7. Status Effect System (12 Types)

Full buff/debuff system with `StatusEffectManager` handling stat modifications, stacking, and tick behavior.

| Effect | Type | Harm/Buff | Effect |
|--------|------|-----------|--------|
| Fortify | Buff | Buff | +25% Endurance |
| Inspire | Buff | Buff | +25% Strength |
| Restore | Buff | Buff | +Spirit, 5% max HP/turn HoT |
| Absolve | Buff | Buff | 8% max HP/turn HoT, cleanses |
| Condemn | Debuff | Harm | 8% max HP/turn DoT |
| Weaken | Debuff | Harm | -25% Strength |
| Stagger | Debuff | Harm | -25% Speed |
| Silence | Debuff | Harm | -50% Spirit, prevents skills |
| Stun | Debuff | Harm | Prevents all actions, -50% Speed |
| Shelter | Buff | Buff | 40% damage reduction |
| Fury | Buff | Buff | +40% Strength, -20% Endurance |
| Faith | Buff | Buff | +Conviction gain |

**Stat modification system:** PartyMember stores `strengthMult`, `spiritMult`, etc. as floats. `StatusEffectManager.RecalculateStats()` updates them. `StrengthWithEquipment` = `(BaseStrength + equipment) * buffMultiplier`.

**Pitfall — old StatusEffect class:** The old `StatusEffect` class was replaced with `StatusEffectInstance`. Ensure CharacterBase uses `List<StatusEffectInstance>` not `List<StatusEffect>`.

## Data-Driven Design

4 ScriptableObject types power all content:

| SO Type | Key Fields |
|---------|-----------|
| `CharacterDataSO` | name, role, maxHP, maxConviction, stats, startingSkills, portrait |
| `SkillDataSO` | name, convictionCost, hpCost, basePower, targetType, skillType, buff effects |
| `ItemDataSO` | name, category, stat bonuses, heal amount, price, icon |
| `EnemyDataSO` | name, stats, xpReward, convictionReward, dropTable, behavior, sprite |

These load from `Resources.Load<Type>("Path/name")` or are assigned in the Inspector. When building code-first, use Resources.Load for lookup until Editor wiring is done.

## Expanded Systems

### Skill Unlock Milestones

Skills unlock at Conviction thresholds (total conviction from deeds, not current):

| Threshold | Skill Name | Effect |
|-----------|-----------|--------|
| 25 | Walk in Faith | Basic healing |
| 50 | Shield of Righteousness | Defense buff |
| 100 | Word of Judgment | AoE spiritual damage |
| 200 | Lay on Hands | Full party heal |
| 350 | Testament of Power | Massive single-target |
| 500 | Resurrection | Revive fallen ally |

### Enemy Scaling

Party average level vs base enemy stats through an AnimationCurve:
- `partyLevel / baseEnemyLevel` ratio → scale factor from curve
- Clamped to 0.5x – 3.0x
- Applied to HP, STR, SPI, END (full), SPD (50%), XP (70%)

### Day/Night Cycle

24-hour cycle, 60x speed (1 real second = 1 game minute).
| Phase | Hours | Encounter Rate | Ambient Color |
|-------|-------|----------------|---------------|
| Dawn | 5-7 | 0.7x | Lerp(night→day) |
| Day | 7-17 | 1.0x | White |
| Dusk | 17-19 | 1.2x | Orange |
| Night | 19-5 | 1.5x | Deep purple |

### Party Formation (Front/Back Row)

3 front slots + 3 back slots = 6 total party positions.
- Front row: normal damage taken, **+15% damage dealt**
- Back row: **-30% damage taken**, +20% spirit (healing/spiritual damage)
- AI targets front row by default, 30% chance to target back row
- Swapping positions via `PartyFormation.SetPosition()`

### Chapter System (ScriptableObject)

```
ChapterData {
    int chapterNumber;
    ParableMission[] parablesToUnlock;  // Made available when chapter starts
    string regionName;                   // Sets encounter table region
    EncounterTable regionEncounters;     // Overrides default encounters
    int startingGold;                    // Starting state
    ItemDataSO[] startingItems;
}
```

## Save System

Binary serialization with integrity checks:
1. `SaveGameData` is built as a plain `[Serializable]` class with `JsonUtility.ToJson()`
2. Wrapped: `BASE64(JSON)` with `"GOSv1"` header prefix
3. Stored at `Application.persistentDataPath/slot_name.gos`
4. Load checks: file exists → starts with header → decode → deserialize → apply
5. Auto-save triggers: battle victory, campfire rest, chapter/Parable complete, 10-minute periodic

**Save data includes:**
- Party member states (HP, XP, Conviction, equipment refs, learned skills, inventory)
- Global progression (chapter, play time, total conviction, souls saved, parables)
- Shared inventory (item names + counts)
- Testament records (names + levels for restoration)

## UI Screen Inventory

| Screen | Triggered By | Key Features |
|--------|-------------|-------------|
| TitleScreen | Game start | Continue, New Game, Load, Options, Quit. Reveal animation. |
| PauseScreen | Escape | Party, Items, Equip, Skills, Testaments, Save, Options. Time.timeScale = 0. |
| GameOverScreen | Party wipe | Retry, Vow of Steel, Load, Title. Scripture quotes. |
| OptionsScreen | Menu | BGM/SFX sliders, text speed, screen shake, difficulty (4). |
| SaveSlotUI | Menu | 5 slots, load/save/delete, auto-scan *.gos files. |
| BattleHUD | Battle start | Command menu (Attack/Ability/Items/Defend/Testament). Turn counter. |
| BattleVictoryScreen | Battle win | XP/Conviction/loot display, level-up, skill unlock, quote. |
| InventoryScreen | Menu | 7-category browser, detail view, in-menu use. |
| EquipmentScreen | Menu | Slot equip/unequip, stat diff comparison. |
| SkillAssignmentScreen | Menu | 4-slot ability bar, learned skills list. |
| CharacterDetailScreen | Menu | Full stats (buffed+equipped), effects, Testament. |
| TestamentViewScreen | Menu | Fallen hero records, scripture, deeds total. |
| ObjectiveTracker | Parable start | HUD overlay: ► active, ✓ complete, progress count. |
| DialogueManager | NPC/Narrative | Typewriter text, speaker attribution, advance. |
| AchievementScreen | Menu | 15 milestones, lock/unlock display. |
| BestiaryScreen | Menu | Enemy browser, lore, stats, kill count. |

## AI Behavior (Enemy)

5 archetypes per `EnemyBehavior` enum:
| Behavior | Target | Notes |
|----------|--------|-------|
| Aggressive | Lowest HP | Focus fire squishy targets |
| Defensive | Highest END | Tries to disable tank |
| Pack | Lowest HP | All enemies focus same target |
| Corrupted | Random | Unpredictable, chaotic |
| Zealot | Slot 0 | Locks onto first party position |

60% basic attack / 40% skill use. Skills chosen randomly from enemy skill list.

## Parable (Mission) Structure

`ParableMission` (ScriptableObject) with:
- Scripture reference, description, objectives list
- Each objective: type (DefeatAll, Rescue, Reach, Collect, Defend, Dialogue, Survive, Protect), required count, progress
- Encounters: enemy lists with encounter style (Standard, Boss, Scripted)
- Rewards: XP, Conviction, gold, items
- Narrative: intro dialogue, completion dialogue

## Hex Grid (Axial Flat-Top)

```
x = hexSize * (3/2 * Q)
z = hexSize * √3 * (R + Q/2)
```

`HexCoord` API: `DistanceTo()`, `Neighbors()`, `HexesInRange(range)`, `WorldToHex()` with rounding.

Overworld movement: click-to-move, max 3 hexes per action, random encounter check on arrival.

## Game Over & Vow of Steel

When `GameManager.IsPartyDefeated()`:
1. `GameOverScreen.Show()` with a random scripture quote
2. If Testaments exist: **Vow of Steel** button consumes all to revive the strongest
3. If no Testaments: only Retry, Load, or Return to Title
4. Retry loads the auto-save (pre-battle state)

## Difficulty Levels

4 levels controlled by `GameConfig` singleton, persisted to PlayerPrefs:

| Setting | Easy | Normal | Hard | Steel |
|---------|------|--------|------|-------|
| Player damage taken | 75% | 100% | 125% | 150% |
| Enemy damage dealt | 75% | 100% | 115% | 140% |
| XP gain | 150% | 100% | 80% | 60% |
| Conviction gain | 125% | 100% | 85% | 70% |

## Code-First Workflow Pattern

This is the critical workflow lesson from the Gospel of Steel build:

1. **Read the README/vision document** — extract design pillars, mechanics, and systems
2. **Create project structure** — `Assets/Scripts/{Core,Characters,Systems,Combat,Grid,Items,Missions,Data,Audio,UI}/`
3. **Write ScriptableObjects first** — `CharacterDataSO`, `SkillDataSO`, `ItemDataSO`, `EnemyDataSO`. These define what data exists.
4. **Write base classes** — `CharacterBase`, system interfaces, utility classes
5. **Write core systems** — `GameManager`, `TurnManager`, `BattleManager` (the heartbeat)
6. **Write character types** — `PartyMember`, `Enemy` extending `CharacterBase`
7. **Write feature systems** — one at a time, in dependency order
8. **Write UI screens** — all MonoBehaviour with public fields (wired in Editor later)
9. **Write Systems** — managers, persistence, configuration
10. **Write supporting systems** — audio, VFX, tutorials, achievements
11. **Commit to git** — `.gitignore` for Unity (Library/, Temp/, obj/, *.csproj, *.sln)
12. **Open Unity** — assign prefabs, build scenes, wire UI references

**Total output rate:** ~8-12 C# scripts per session, ~1500-2500 lines per session, producing a codebase of ~10K lines across ~7 sessions.

## Pitfalls

- **Nested enum naming collisions:** `ParableEncounter.EncounterType` collides with global `BattleManager.EncounterType`. Rename nested enums to avoid ambiguity: `EncounterStyle { STANDARD, BOSS, SCRIPTED }`.
- **Case-sensitive enum references:** `GameState.PARABLE` vs `GameState.Parable` in different files will compile-fail. Always reference the exact spelling from the enum declaration.
- **Singleton Awake ordering:** If A's Awake references B's Instance and B hasn't Awoken yet, you get null. Use `Start()` or `FindFirstObjectByType` for cross-system wiring; keep `Awake()` for self-only setup.
- **DontDestroyOnLoad duplicates:** When loading a scene that has a DontDestroyOnLoad manager in it, the new instance hits Awake, detects the old one, and self-destructs. The `FindFirstObjectByType` calls in `Start()` must account for this — they may find the old one or the new one depending on frame timing.
- **Time.timeScale on pause:** PauseScreen sets `Time.timeScale = 0`. Any code that uses `Time.deltaTime` (not `Time.unscaledDeltaTime`) will freeze. Use `unscaledDeltaTime` for UI animations and timers during pause.
- **ScriptableObject load paths:** `Resources.Load<Type>("Path/name")` needs the exact path relative to `Assets/Resources/` without extension. `Resources.Load<ItemDataSO>("Items/Bandage")` loads `Assets/Resources/Items/Bandage.asset`.
- **Turn queue dead actors:** Remove dead actors from `turnQueue` each cycle. The `TurnActor.IsDead` check uses `currentHP <= 0`. An actor that dies mid-turn is removed at the end of that turn, not immediately.
- **Old StatusEffect vs StatusEffectInstance:** The old `StatusEffect` class was deprecated in favor of `StatusEffectInstance` which has a `StatusEffectDefinition` field. Ensure CharacterBase uses `List<StatusEffectInstance>`, not `List<StatusEffect>`. The old class had only `type`, `remainingTurns`, `magnitude` — the new one has a full definition object.
- **Buff multiplier floor:** `SetBuffMultipliers()` clamps to `Mathf.Max(0.1f, value)` so stats can't go below 10% of base. Without this floor, stacking debuffs could reduce strength to 0 or negative.
- **Grid gizmo position:** `OnDrawGizmosSelected()` calculates hex positions relative to `transform.position` during runtime but absolute during Editor mode. Check `Application.isPlaying` before deciding position offset.