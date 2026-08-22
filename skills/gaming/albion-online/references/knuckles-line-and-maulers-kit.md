# Knuckles Line + Ursine Maulers — Verified Game Data (ao-bin-dumps master, Aug 2026)

Spell slot mapping for the knuckles weapon line and the Ursine Maulers E, plus the bruiser
kit built for synth's Caerleon open-world context. Re-pull from ao-bin-dumps after major patches.

## Weapon data

- **Ursine Maulers** = `T8_2H_KNUCKLES_KEEPER` (Keeper artifact, `T8_ARTEFACT_2H_KNUCKLES_KEEPER`).
  Destiny board node: `COMBAT_KNUCKLES_KEEPER` / `CRAFT_KNUCKLES_KEEPER`.
  Stats: melee, attackrange 1.5, attackspeed 2.5, two-handed, 3 active + 1 passive spell slots.
- Spell list resolution: T8 references T6 → references `T4_2H_KNUCKLES_SET1` with
  `<removespell uniquename="BLAZING_GEYSER"/>` and adds `PUMMELING_STRIKES` at slots="3" (the E).

## Spell list (T4_2H_KNUCKLES_SET1 base, Aug 2026)

### Q (slots="1")
- `CREATE_OPENING` = **Create Opening** — 2-part combo: (1) targeted physical damage, (2)
  **Exploit Opening** — damage + decreases target's damage resistances for a window. The shred
  that multiplies the E.
- `DASHKICK` = **Dragon Leap** — dash to ground target, kicks all enemies (2-part combo w/ uppercut).
- `CROSSSTEP_ROUNDHOUSE` = displays as **Fleet Footwork** (`@namelocatag` → `@SPELLS_CROSSSTEP_MULTI`) —
  2-part combo: (1) Roundhouse Kick cone damage, (2) Cross Step dash with +damage resistances
  while dashing and +auto-attack damage after.
- `SHOCKWAVE_PUNCH` = **Shockwave** — piercing line projectile (13 range), magical damage poke.

### W (slots="2")
- `TRIPLE_KICK` = **Triple Kick** — dash through enemies, up to 3 hits; **pulls up to 1 enemy
  PLAYER along with you**. The kidnap/catch tool.
- `BACKHAND_KNOCKBACK` = **Backhand Strike** (T3+) — directional knockback; wall collision =
  bonus damage + resistance shred.
- `KNUCKLE_COUNTER` = **Counter** (T4+) — channeled counter-stance (uninterruptible), +defense,
  reflects portion of damage as magic; on taking direct damage marks attacker → (2) Follow Through:
  dash to marked enemy, AoE damage, throws all hit into the air.
- `KNUCKLECOMBO` = **Devastating Combo** (T4+) — uninterruptible 2-punch channel: punch 1 stuns,
  punch 2 knocks back.

### E (slots="3") — Ursine Maulers
- `PUMMELING_STRIKES` = **Hundred Striking Fists** — channeled flurry in a cone (can't be
  interrupted), cone slowly follows cursor. Physical damage per tick (separate player/mob values);
  shortly after the LAST hit, target takes additional magic damage per hit received, stacking
  to a cap. Damage can't be interrupted = finish the channel even when CC'd.

### Passives
- `PASSIVE_KNUCKLE_BRAWLER` = displays as **Fatal Fury** (`@namelocatag` → `@SPELLS_PASSIVE_KNUCKLE_FURY`,
  desc `_BRAWLER_DESC`) — every auto-attack: +damage stacking buff (to a cap; at max stacks the
  buff can't refresh and runs out).
- `PASSIVE_KNUCKLE_RAGE` = **Rage** (T2+) — triggers on taking damage below a health % threshold:
  +damage and +lifesteal-style sustain.
- `PASSIVE_KNUCKLE_RUSHDOWN` = **Rushdown** (T4+) — every auto-attack: +move speed for a window.
- `PASSIVE_KNUCKLE_COMBOBREAKER` = **Hard to Catch** (T4+) — casting the weapon's second-slot (W)
  ability grants +damage resistances and +CC resistance. PvP pick.

## Kit built (multi-purpose, group Caerleon open-world PvP / healer duo)

Create Opening (Q, shred) / Triple Kick (W, kidnap drag) / Hundred Striking Fists (E) /
Hard to Catch (passive). Mercenary Hood (Howl or Cleanse), Mercenary Jacket (Bloodlust) or
Hunter Jacket (Haste, greed with healer), Soldier Boots (Wanderlust), Thetford cape PvP /
Demon greed. Snapper Roast or omelette; healing/resistance pots.
Swaps: Q→Fleet Footwork (lose shred, gain dash+AA steroid); W→Counter (outnumbered, lose
kidnap) or Devastating Combo (static frontline); passive→Rage (greedy duos).
