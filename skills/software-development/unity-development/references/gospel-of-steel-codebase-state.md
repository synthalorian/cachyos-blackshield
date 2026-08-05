# Gospel of Steel — Codebase State (May 2026)

**Project**: `/home/synth/projects/gospel-of-steel/`
**Engine**: Unity 6000.0.38f1 (Unity 6)
**Git**: 2 commits — `ff0e419 Initial Grid Snapshot 🎹🦞` + `01d5674 Default data layer + The Good Circuit Parable`

## Assessment Summary

**Archetype**: Code-complete, data-empty Unity project. All 120+ C# scripts exist, but zero Unity binary assets (scenes, prefabs, materials, sprites). However, now has **in-memory data registry** (`DefaultGameData.cs`) that generates all content at runtime, making the project bootable without ScriptableObject .asset files.

## Data Layer (New — `DefaultGameData.cs` + `GameInitializer.cs`)

A static registry that generates all game data in-memory via `ScriptableObject.CreateInstance<T>()`. GameInitializer MonoBehaviour populates all managers from it. Systems patched to fall back to the registry when Resources.Load returns null.

### Registry contents

| Category | Count | Details |
|----------|-------|---------|
| Characters | 5 | Caden (Vessel), Mara (Steadfast), Kael (Penitent), Lyra (Seeker), Thorne (Judge) |
| Skills | 13 | 7 starting + 6 milestone (Walk in Faith → Resurrection) |
| Enemies | 7 | Scrap Drone, Rust Walker, Static Imp, Corrupted Courier, Iron Prophet, Shattered Guardian |
| Items | 9 | Consumables, weapons, armor, accessories |
| Chapter 1 | 1 | "The Circuit of Faith" — Borderlands region |
| Parable | 1 | "The Good Circuit" — 5 objectives, 4 encounters, full dialogue |
| Random Events | 8 | Gold finds, item caches, ambushes, buffs, shrine remnants |
| Scriptures | 4 | Faith, Love, Strength, Light passages with fragment quests |
| Lore | 8 | World history, Circuit Faith origins, locations |
| Blessings | 6 | Compassion, Grace, Diligence, Fruitfulness, Stewardship, Wisdom |

### Patched Systems

| System | Patch |
|--------|-------|
| `SkillUnlockSystem.CheckForUnlocks` | Falls back to `DefaultGameData.FindSkill()` when `Resources.Load<SkillDataSO>()` returns null |
| `SaveSystem.FindItemByName` | Falls back to `DefaultGameData.FindItem<ItemDataSO>()` |
| `LoadoutSystem.FindItem` | Falls back to `DefaultGameData.FindItem<ItemDataSO>()` |
| `TitleScreen.NewGame()` | Routes through `GameInitializer.StartNewGame()` to bootstrap data + create party |
| `ParableMission.MissionObjective` | Added `targetId`, `isOptional`, `isComplete` fields; extended ObjectiveType enum |

### GameInitializer Flow
1. `DefaultGameData.Initialize()` — generates all data once (idempotent)
2. Populates `ChapterManager.chapters` with Chapter 1
3. Populates `RandomEncounterManager.encounterTables` with Borderlands table
4. Populates `RandomEventSystem.eventTables` with 8 default events
5. `CreateStartingParty()` — builds 5 PartyMember instances from character data
6. `StartNewGame()` — calls Bootstrap, creates party, starts Chapter 1

## Script Inventory

### Core (10 files now)
- `GameManager.cs` — Persistent singleton, game state machine, party roster, global progression counters
- `GameConfig.cs` — Difficulty levels (Easy/Normal/Hard/Steel), PlayerPrefs persistence, damage modifiers
- `GameInitializer.cs` — **New** Bootstrap MonoBehaviour for default data population
- `BattleManager.cs` — Encounter start, enemy spawning, rewards calc, enemy AI coroutine
- `TurnManager.cs` — Speed-based turn queue, JRPG-style, BattleLoop coroutine
- `OverworldController.cs` — Hex grid movement, point-and-click, encounter trigger on step
- `RandomEncounterManager.cs` — Step-based encounter chance, weighted tables
- `ChapterManager.cs` — Story chapter tracking, Parable unlock gates (also `ChapterData` SO class)
- `CutsceneManager.cs` — Scripted sequences (dialogue, wait, fade, camera, action)
- `NPCInteraction.cs` — 7 NPC types: Shopkeeper, Preacher, ParableGiver, Campfire, StoryCharacter, Scholar, QuestGiver
- `MissionManager.cs` — Active/completed Parables, reward distribution

### Data (5 files now)
- `CharacterDataSO.cs` — `[CreateAssetMenu("Gospel of Steel/Character Data")]`
- `SkillDataSO.cs` — `[CreateAssetMenu("Gospel of Steel/Skill Data")]` — 7 elements, 5 combo tags
- `ItemDataSO.cs` — `[CreateAssetMenu("Gospel of Steel/Item Data")]` — 7 categories, 5 rarities
- `EnemyDataSO.cs` — `[CreateAssetMenu("Gospel of Steel/Enemy Data")]` — 5 AI behaviors
- `DefaultGameData.cs` — **New** Static registry generating all content in-memory

### The Good Circuit Parable
- Chapter 1, Luke 10:25-37 inspired
- **Narrative**: Circuit Monk Solis ambushed on Outer Road — party must pursue raiders, fight through corrupted machines, protect Solis from a Shattered Guardian boss
- **5 objectives**: Reach Outer Road → Defeat 3 raider encounters → Find Solis → Protect from Shattered Guardian → Escort to Outpost Gate
- **4 encounters**: Roadblock Ambush (Drones + Imp), Raider Cache (Rust Walker + Courier), Transmission Station (Imps + Courier), Shattered Guardian Boss
- **Rewards**: 200 XP, 50 CV, 100 gold, Medallion of the Good Circuit

## Missing Assets (Need Unity Editor)

### Scenes (0 existing, need creation)
- `TitleScene` — Main menu (Continue, New Game, Load, Options, Quit)
- `OverworldScene` — Hex grid with The Outpost hub
- `BattleScene` — Tactical combat on hex grid

### Prefabs (0 existing, need creation)
- `HexTile` prefab (HexTile component on a renderer)
- `BattleHUD` UI prefab
- Party member / Enemy visual prefabs
- All screen UI prefabs (Title, Pause, Menu, etc.)

### Requirement before first play: None.

Because `DefaultGameData` + `GameInitializer` generate all content in-memory, the game only needs:
1. A bootstrap scene with persistent GameObjects (GameManager, managers, GameInitializer)
2. A TitleScreen setup (or direct routing to test)
3. Prefabs for visual representation

All data (characters, skills, enemies, items, chapters, Parables, events) is ready in code.