# Better Hunt - Asymmetric Auto-Battler RPG

> 📖 **[Architecture Guide](Docs/INSTRUCTOR.md)** • 📚 **[All Docs](Docs/)**

**Genre**: Asymmetric PvE Auto-Battler with Strategic Setup  
**Engine**: Godot 4.7 (GDScript, Mobile renderer, portrait 720x1280)  
**Inspiration**: Evolve (4v1 asymmetric); UnderGuild's collection screen (the "Jungle Guild" look), Underdark: Defense and Lucky Defense (readability)  
**Development Status**: Prototype v0.2, the "Jungle Guild" overhaul (pre-alpha with production goals)  
**Platform**: Mobile first (Android / iOS, portrait), PC for development

This README is the design spec. Its tables are the shipped data:
`test/test_readme_spec.gd` checks the hero, monster, ability, mob, reward and
skill-tree tables against the `.tres` files and scenes, and that every file
named here exists. Work in progress, open decisions and the changelog live in
[`PROGRESS.md`](PROGRESS.md); how the code is built is in
[`Docs/INSTRUCTOR.md`](Docs/INSTRUCTOR.md).

---

## 🎮 Core Concept

**Better Hunt** is a strategic auto-battler where you command either a team of 4 heroes or a single powerful monster. Before each round, you configure your team's strategy, then watch the battle unfold in real-time. Success depends on your pre-round decisions: hero composition, skill tree investments, and tactical priorities.

**The Core Loop**: Setup → Watch → Learn → Upgrade → Repeat

**The look ("Jungle Guild")**: a cosy-grim jungle guild hall. Flat warm
charcoal screens, chunky hand-drawn chibis with thick ink outlines on
copper-outlined cards, bold white lettering (Lilita One) outlined in ink,
carved-wood nav plaques around a mossy-stone HUNT arch. The hero side reads
warm (copper, amber, moss), the monster side dangerous (crimson, purple). The
same SVG rigs stand in the lobby, on the cards and fight in the match, on the
pixel jungle tiles under a muted grade. See "Visual Systems".

**The screens**: Lobby (the campfire and the lair: tap a side to choose it)
→ Rosters and character pages with ranked skill trees (Heroes / Growth /
HUNT / Codex / Monsters on the nav bar) → Pre-round (quarry or monster,
strategy, Opponent Threat) → the match with its HUD → the match result
(rewards count up, XP bars, upgrades ready) → back to the lobby.

---

## 🎯 Game Loop

### Round Structure (Best of 1)

**Pre-Round Phase** (Strategic Setup):

1. **Choose Side**: Heroes or Monster. The Heroes side hunts tonight's
   quarry (a random monster they have met, see Opponent Choice and Monster
   Unlocks); the Monster side plays the player's own monster.
2. **Configure Strategy** (the pre-round screen, `PreRoundScreen`):
    - Hero team: tonight's quarry (free Change picker), the aggression /
      farming / exploration dials, the formation, and a plain-words forecast
    - Monster: which owned monster to play, its evolution path and the
      Opponent Threat; instincts (evolution strategy, engagement timing) are
      designed but hidden until their presets are balanced
3. **Spend Resources**: Allocate Steel/Leaves/Gold on permanent upgrades
4. **Start Round**: AI executes your strategy

**Round Phase** (Auto-Battle):

1. **Heroes spawn** at full strength (Level 1) in safe zone
2. **Monster spawns** weak (Stage 1) at a random reachable point of Zone 3
3. **AI Executes**: Both sides follow pre-configured behavior
4. **Confrontation**: Teams clash based on strategy
5. **Victory**: One side is eliminated, or the 10-minute clock runs out

**Post-Round Phase** (Rewards & Upgrade):

1. View battle summary (the match result screen: duration, the played side's
   kills, survivors or the stage reached, rewards counting up, each
   character's XP bar)
2. Earn currencies:
    - **Steel** (Hero-specific) - Earned when playing as Heroes
    - **Leaves** (Monster-specific) - Earned when playing as Monster
    - **Gold** (Universal) - Earned by both sides
    - **Permanent XP** - Each hero/monster gains individual XP
3. **Upgrade Skill Trees**: Invest in permanent progression
4. **Next Round**: Choose side and repeat

### Win Conditions

- **Heroes Win**: Kill the monster at any stage
- **Monster Wins**: Kill all 4 heroes, or survive until the 10-minute match
  clock runs out (a timeout is a monster win; the clock counts unpaused game
  time, `GameManager`)
- **No draws**

### Opponent Choice and Monster Unlocks

- **Heroes side: tonight's quarry.** The pool is every roster monster the
  save has played enough matches (either side) to meet:
  `PersistedData.get_total_matches() >= CharacterDef.opponent_after_matches`
  (Grount 0, Nyxa 3, Gorrak 6). It does not depend on what the Monster side
  owns, so a heroes-only player still meets every monster.
  `GameManager.quarry_pool()`, `hunts_until_quarry(def)` (the Change picker's
  "appears after N hunts").
    - The pick (`next_quarry()`) is random among the pool, never the last
      quarry again while the pool has two or more (`roll_quarry(pool, last,
      rng)`). It is drawn with GameManager's PRIVATE RandomNumberGenerator
      (the global RNG drives gameplay and the determinism trace), rolled once
      and kept until a hunt starts, so reopening the pre-round shows the same
      monster.
    - `lock_quarry(id)` is the pre-round's Change picker: it fixes a monster
      of the pool for every hunt, repeats allowed, until `lock_quarry(&"")`
      (Random). `locked_quarry()` ignores a lock outside the pool.
    - `is_new_quarry(id)`: true until the heroes have hunted it once: the
      NEW QUARRY banner on the pre-round's quarry card.
    - `begin_hunt(quarry_id = &"")` runs right before a menu loads World (the
      pre-round's START HUNT / UNLEASH and the result screen's PLAY AGAIN): on
      the Heroes side it spawns
      `quarry_id` when it is in the pool, else `next_quarry()`
      (`MatchConfig.quarry_id` carries the pre-round's pick), records it as the
      last quarry and adds its Codex entry (`[codex] monsters`, a first
      sighting). The Monster side plays the player's own monster
      (`played_monster_id()`). The sim tools never call it: they pick with
      `select_monster(id, false)` (`monster=<id>`, or the saved default), so
      every trace is unchanged.
- **Monster side: owned monsters.** Grount is owned from the start
  (`unlocked_by_default`). Nyxa (2,500 Leaves) and Gorrak (3,000 Leaves) are
  bought once ANY owned monster has reached Lv 3 (`unlock_requires_level`;
  a level on a monster not owned yet does not count, hero levels never do).
  The lobby's lair and the monster roster show them padlocked with their
  price and, while unmet, the rule ("Needs a Lv 3 monster"); the card's red
  dot and the nav bar's Monsters dot light once one can be bought now. A tap
  opens the `UnlockSheet` (rule, price, UNLOCK), and the purchase
  (`CharacterProgress.unlock`) spends the Leaves, adds the monster to
  `[monsters] owned`, saves, and makes it the player's own monster
  (`GameManager.choose_monster`; the pre-round's picker switches between
  owned ones the same way).
- **Save** (`PersistedData`, no migration: a save without the sections owns no
  bought monster and has met no quarry): `[monsters] owned` (the bought ids;
  default-owned ones are not listed), `last_quarry`, `locked_quarry`, and
  `[codex] monsters` (the quarries met). Reset Progress clears them; damaged
  entries are skipped on read.
- `test/test_quarry_pick.gd`: the defs' rules, pool membership by matches
  played, no repeat over 300 draws, the global RNG untouched by 25 picks and
  hunts, the pick kept until a hunt, the lock, the Codex entry and NEW flag,
  the pre-round's quarry card (NEW banner, Lv.(T+1), its moves, the config's
  quarry) and Change sheet (pool cards, "Appears after 3 hunts" silhouettes,
  the lock, Random, `ui_cancel`), the Lv 3 gate before the price, any owned
  monster opening the gate, the exact prices, the save, the Monster side's
  own monster, junk-proof lists.

---

## ⚔️ Gameplay Mechanics

### Power Curve - The Strategic Core

```
Power Level
    │
    │                                    ╱ Stage 3 Monster (God Mode)
    │                               ╱───╱
    │                          ╱───╱
    │                     ╱───╱ Stage 2 Monster
    │   Heroes ────────────────────── (Slow growth)
    │              ╱───╱
    │         ╱───╱ Stage 1 Monster (Weak)
    │    ╱───╱
    └────────────────────────────────────► Time
    0min      3min      6min      9min

    HERO ADVANTAGE ←→ MONSTER ADVANTAGE
```

**Player Strategy Decisions**:

**As Heroes**:

- **Aggressive Comp**: Rush early, skip farming → 70% win rate if found in 3 min
- **Balanced Comp**: Clear 1-2 camps, then hunt → 50% win rate
- **Greedy Comp**: Heavy farming for levels → High risk (Monster may reach Stage 3)

**As Monster**:

- **Hide & Farm**: Avoid heroes, rush to Stage 2/3 → 65% win rate if successful
- **Ambush Strategy**: Farm to Stage 2, then hunt heroes → Balanced
- **Desperation**: Fight at Stage 1 if found early → 30% win rate

---

## 👥 Heroes (Team of 4)

### Current Roster (4 Heroes)

| Hero       | Class          | HP  | DPS  | Range | Role                            |
| ---------- | -------------- | --- | ---- | ----- | ------------------------------- |
| **River**  | Support/Scout  | 100 | 10.9 | 300   | Long-range DPS, Healing, Vision |
| **Vlad**   | DPS/Berserker  | 110 | 10.0 | 50    | High melee DPS, execution       |
| **Ted**    | DPS/Pet Master | 105 | 15.0 | 55    | Sustained DPS with pet          |
| **Irelia** | Tank/Support   | 160 | 3.3  | 120   | Tank, shields, monster taunt    |

**Combined Level 1 Team DPS**: ~39 DPS (basic attacks only; Ted's 15.0
includes his fox). HP is `HeroStats.base_max_health`, range the hero's
`base_attack_range` (the Fight gate), DPS the basic attack's damage over its
cooldown.

### Hero Details

#### River (Support/Scout)

- **Base Stats**: 100 HP, 85 speed, 300 vision
- **Passive**: Adaptive Movement (after taking damage, +50% move speed for 3 s)
- **Active**: Weapon Swap (switches between the sniper rifle and the heal
  staff; 1 s cooldown; the AI swaps to the staff when an ally within 350 px
  drops below 60% HP and back above 85%)
- **Basic Attack**: Adaptive Weapon
    - Sniper Mode: 12 dmg at 300 range / 1.1s
    - Healer Mode: 9 heal at 150 range / 1.4s
- **Ultimate**: Emergency Supply Drop (a MediKit that heals every hero who
  walks over it 30 HP once, then vanishes; 25 s cooldown)
- **Scaling**: +5 HP, +1.8 dmg per level
- The design's first kit (Snare Trap, Arrow Barrage) never shipped; trap and
  barrage slows stay an open idea (PROGRESS backlog).
- **Capstones** (one equipped): Deadeye (every 4th sniper shot x2.5), Chain
  Heal (staff heals also heal the most hurt ally within 160 px), Pathfinder
  (every hero +12% move speed while River lives)

#### Vlad (DPS/Berserker)

- **Base Stats**: 110 HP, 80 speed, 250 vision
- **Passive**: Bloodlust (Below 30% HP: +50% dmg, +100% attack speed)
- **Active**: Land Mine (18 dmg explosion when an enemy steps on it; 8 s cooldown)
- **Basic Attack**: Blood Strike, 10 dmg at 50 range / 1.0s
- **Ultimate**: Blood Bomb (50 dmg, 150 AoE; 20 s cooldown)
- **Scaling**: +6 HP, +1.7 dmg per level
- **Capstones** (one equipped): Executioner's Mark (Blood Strike x2 below 25%
  HP), Sanguine Feast (Blood Strike heals 20% of its damage), Cluster Mines
  (3 mines per Land Mine)

#### Ted (DPS/Pet Master)

- **Base Stats**: 105 HP, 85 speed, 220 vision
- **Pet Stats**: 50 HP, 9 dmg, 60 range, 1.2s cooldown
- **Passive**: Loyal Companion (the fox fights beside him and respawns after 10s)
- **Active**: Rally Cry (Ted and his pet +50% attack speed for 5s; 10 s cooldown)
- **Basic Attack**: Claw Swipe, 9 dmg at 55 range / 1.2s
- **Ultimate**: Trap Cage (150 radius, traps enemies for 6s; 5 s cooldown)
- **Scaling**: +5 HP, +1.6 dmg per level
- **Combined DPS** (Ted + Pet): ~15.0 DPS
- **Capstones** (one equipped): War Cry (Rally Cry also hastes heroes within
  300 px), Pack of Two (two pets), Spiked Cage (6 damage per second inside the
  cage)

#### Irelia (Tank/Support)

- **Base Stats**: 160 HP, 75 speed, 200 vision
- **Passive**: Regeneration (0.5 HP/s)
- **Active**: Divine Shield (18 HP shield to all heroes, 7s duration; 13 s cooldown)
- **Basic Attack**: Shield Bash, 5 dmg at 120 range / 1.5s (+40 threat on the
  struck enemy, so packs turn to her)
- **Ultimate**: Monster Taunt (Forces monster to attack Irelia for 5s; 15 s cooldown)
- **Scaling**: +8 HP, +1.2 dmg per level
- **Capstones** (one equipped): Last Stand (survive a lethal hit once at 1 HP,
  2 s invulnerable), Guardian Angel (Divine Shield breaks stuns), Rallying
  Taunt (heroes within 250 px +25% attack speed during the taunt)

### Hero Leveling (In-Round)

- **XP Sources**: Bat (6 XP), Hog (15 XP) (`hero_xp_value` on the mob scene)
- **XP Required**: 80 XP per level (`HeroStatsComponent.XP_PER_LEVEL`), up to
  level 10; the max-HP gain of a level is healed, and the per-level damage
  reaches every ability (`get_damage_scale`)
- **XP Radius**: every living hero within 800 px of the dying mob gets it
  (100% close by, falling to 50% at the edge)
- **Scaling**: Slow growth favors early aggression

---

## 🐾 Monster Roster (overview and balance sheet)

Three monsters ship, each a scene that inherits `monster_base_class.tscn`
plus its stats, strategy and ability `.tres` (see "Shared Monster Framework"
and "Character Roster"). Hero wins at threat 0 are `MONSTER=<id> tools/sim.sh
48 heroes 6` / `... 48 monster 6` (fresh save, reproducible since 6.2); the
target is 40-60 % per monster on both sides.

| Monster | Role | Owned / unlock | Heroes meet it after | HP (S1 / S2 / S3) | Evolves at (total XP) | Hero wins, heroes side / monster side | Timeouts (H / M) |
| ------- | ---- | -------------- | -------------------- | ----------------- | --------------------- | ------------------------------------ | ---------------- |
| **Grount**, the Bull | brute: cone cleave, ram dash, leaping slam | from the start | 0 hunts | 800 / 1400 / 2200 | 150 / 300 | 46 % / 48 % | 4 / 3 |
| **Nyxa**, the Dusk Matriarch | stalker: lifesteal skirmisher, bat aura | 2,500 Leaves once a monster is Lv 3 | 3 hunts | 600 / 950 / 1250 | 150 / 400 | 54 % / 52 % | 18 / 17 |
| **Gorrak**, the Boar King | brute: armoured, returning axe, stunning stomp | 3,000 Leaves once a monster is Lv 3 | 6 hunts | 1100 / 1450 / 1500 | 150 / 500 | 42 % / 52 % | 5 / 5 |

- Every monster heals to full on evolving (`heal_to_full_on_evolution`).
  Each has a per-stage table for every ability, so `stage_N_damage_multiplier`
  only matters for an untabled ability.
- At Opponent Threat 1-4 (the AI monster's build grows with the player's
  ranks) 21 of the 30 parity cells are inside 35-65 % (table under "Opponent
  Threat"); Gorrak at threat 3-4 (62-75 %) is the weak spot.
- Capstone sanity (a fully ranked monster, one capstone, against fresh heroes,
  24 seeds): Grount Titan Form 0 %, Rampage 29 %, Trample 33 % hero wins;
  Nyxa and Gorrak 0 % with every capstone ("Monster capstones and behaviour
  nodes").
- Nyxa's wins are mostly timeouts (she evades): accepted as her trait.
- Codex, roster and pre-round show each monster's stage names, tip and moves
  from its `CharacterDef` (`Assets/Characters/<id>/<id>_def.tres`).

---

## 🐂 Monster (Grount - The Bull)

Grount (`Scenes/NPCs/Monster/Grount/Grount.tscn`, rig `grount_body`,
HUMANOID) is the roster default: owned from the start, the monster every
tool plays when no `MONSTER` is given. Stage names (placeholder copy):
Bullcalf, Rampager, Alpha Bull.

### Stage Evolution System

| Attribute        | Stage 1 (Vulnerable) | Stage 2 (Dangerous) | Stage 3 (Apex Predator) |
| ---------------- | -------------------- | ------------------- | ----------------------- |
| **HP**           | 800                  | 1400 (+600 heal)    | 2200 (+800 heal)        |
| **Speed**        | 60                   | 80 (+33%)           | 110 (+83%)              |
| **Damage Mult**  | 1.0x                 | 1.4x                | 1.8x (2.0x × 0.9, 6.3)  |
| **Attack Range** | 80 (flat × Monster Base range skill) | 80 | 80                 |
| **XP Required**  | Start                | 150 XP              | 300 XP                  |

### Abilities

#### Front Cleave (Ability 1)

| Stage | Damage | Cooldown | Cone Angle | Description          |
| ----- | ------ | -------- | ---------- | -------------------- |
| 1     | 12     | 2.5s     | 50°        | Basic frontal cleave |
| 2     | 17     | 3.0s     | 60°        | Harder, wider        |
| 3     | 10.8   | 1.8s     | 75°        | Rapid, massive cone (lighter hits, highest DPS) |

An 80 px cone (`cone_range`) in front of him; it lands on the cast. The
stage-1 cleave recasts faster than the stage-2 one (2.5 s vs 3.0 s), as the
data has shipped since the v13 balance pass.

#### Ram Dash (Ability 2)

| Stage | Damage | Cooldown | Range | Description               |
| ----- | ------ | -------- | ----- | ------------------------- |
| 1     | 18     | 12.0s    | 300   | Charge at the target      |
| 2     | 25     | 8.0s     | 300   | Faster cooldown           |
| 3     | 32.4   | 5.0s     | 300   | Spam dash                 |

A 500 px/s charge (`dash_distance` 300) that stops 40 px short of the target
(`dash_stop_short`) and hits everything within 40 px of its lane
(`dash_hit_radius`). Also his escape from a closing hero. `knockback_force`
is an unused export: no entity implements knockback (an open decision).

#### Ground Slam (Ability 3 - Ultimate)

| Stage | Damage | Cooldown  | Radius | Description             |
| ----- | ------ | --------- | ------ | ----------------------- |
| 1     | -      | 🔒 LOCKED | -      | Not available           |
| 2     | 32     | 15.0s     | 120    | Unlocked: Jump and slam |
| 3     | 22.5   | 9.0s      | 180    | Massive AoE, faster recast |

A 1 s leap (up to 150 px toward the target, 100 px high) and the slam on
landing; the combo casts it only when it hits 2+ targets.

### Evolution Mechanics

- **Healing on Evolution**: refills HP (`MonsterBase.heal_to_full_on_evolution = true`, every
  monster). The original rule, gain (new max HP - old max HP), is the `false` setting; which rule
  ships for good is an open decision (it also gates Grount's "Second Wind" node)
- **Visual Changes**: Grount's rig grows with the stage scale (1.0 / 1.25 / 1.5) and shows each
  stage's parts: bigger horns and orange eyes plus back spikes (Stage 2); huge horns, red eyes,
  glowing cracks and a chain (Stage 3); a flash and a ring pulse mark the evolution
- **Screen Shake**: Alerts players to evolution: VfxManager adds trauma 0.45 (`trauma_evolve`)
  on every `EventBus.monster_evolved`, in view or not
- **Ability Unlocks**: Ground Slam unlocks at Stage 2
- **Passive slot**: "Evolution" (`grount_evolution.tres`) names this stage system in the HUD's
  passive slot and on the character screen

### XP Sources (Monster)

- **Bat**: 8 XP per kill
- **Hog**: 25 XP per kill
- **Hero**: 100 XP per kill (`xp_value` on each hero scene)
- **Elite Hog**: designed (50 XP), not built: no Elite camp exists
- **Collection**: the monster gets a kill's XP when it lands the killing blow
  (or the dying entity was chasing it); no collection radius. The thresholds
  are total XP (`stage_2_xp`, `stage_3_xp`), not XP per stage.

**Farming Path to Stage 3** (Grount: 150 XP, then 150 more):

- Option 1: 19 Bats (152 XP) → Stage 2, then 6 Hogs (150 XP) → Stage 3
- Option 2: 6 Hogs (150 XP) → Stage 2, then 6 Hogs (150 XP) → Stage 3
- **Time Required**: median 322 s (about 5.4 min) to Stage 3 in the sim
  (Measured Balance); Stage 1 farms Bats only, Hogs from Stage 2

---

## 🦇 Monster: Nyxa (the Dusk Matriarch)

A glass-cannon skirmisher: fast, fragile, healing from every bite. She picks
off lone heroes, retreats early and punishes a clumped team with her swarm.
Her scene `Scenes/NPCs/Monster/Nyxa/Nyxa.tscn` inherits
`monster_base_class.tscn` with the bat-matriarch rig (`nyxa_body`, FLYER);
her numbers are the gamedesign's final config (v9). Not owned by default:
2,500 Leaves once any owned monster is Lv.3 (bought on the unlock sheet, see
Opponent Choice and Monster Unlocks), and the Heroes side meets her after 3
hunts (`opponent_after_matches`).

| Attribute        | Stage 1 (Duskling) | Stage 2 (Night Hunter) | Stage 3 (Dusk Matriarch) |
| ---------------- | ------------------ | ---------------------- | ------------------------ |
| **HP**           | 600                | 950 (heals to full)    | 1250 (heals to full)     |
| **Speed**        | 85                 | 105                    | 125                      |
| **Scale**        | 1.0                | 1.12                   | 1.25                     |
| **Strafe**       | 90 px/s, 1.2 s     | 110, 1.0 s             | 130, 0.8 s               |
| **XP Required**  | Start              | 150 XP                 | 400 XP                   |

Reach 110 (`base_attack_range`), she keeps 55 px (`preferred_distance` on the
scene root; min 20) and leaves Fight past 150 px. Every ability has a
per-stage table, so the stage damage multiplier never applies to her.

- **Sonic Screech** (ability 1, `BullFrontCleave`): a 110 px cone of
  50 / 60 / 70°, 8 / 10 / 8 damage every 2.0 / 1.8 / 1.5 s, lifesteal 20%.
- **Shadow Swoop** (ability 2, `BullRamDash`): 260 px at 700 px/s with
  `dash_stop_short` -60, so she ends 60 px behind the target; 12 / 16 / 22
  damage every 9 / 7 / 5 s, lifesteal 30%. Also her escape (`escape_dash_radius` 140).
- **Night Swarm** (ability 3, ULTIMATE, `night_swarm.gd`): locked at Stage 1.
  A bat aura centred on her for 3.5 s that bites every target within 110 / 140
  px on the cast and every 0.5 s after (8 bites), 4 / 5 a bite, every
  18 / 14 s, lifesteal 25%. No node and no timer: MonsterBase steps it through
  `tick_active` on her own copy; `get_cast_center` is Nyxa, so the combo casts
  it when at least one target (`slam_min_targets` 1) stands around her. It
  ends with her. AbilityVfx draws it: bats circling her body inside the
  radius, diving in on every bite, over a faint ring at the radius (see
  Ability Effects); F3 shows `swarm! <s> s left` / `swarm off`.
- **Blood Drinker** (passive slot): names her lifesteal and evolution in the
  HUD and on the character screen.
- **AI**: see Monster AI → Nyxa (Bats only until Stage 3, early retreat,
  lone-hero ambushes).
- **Counterplay** (her def's tip): she swoops onto lone heroes; keep the pack
  within 300 px and burst her before Stage 3.
- About a third of her wins are timeouts: she evades. Accepted as her trait.

---

## 🐗 Monster: Gorrak (the Boar King)

A slow, armoured brawler: wide chops, a ranged returning axe and an in-place
stomp that stuns the pack. He never flees with his axe. His scene
`Scenes/NPCs/Monster/Gorrak/Gorrak.tscn` inherits `monster_base_class.tscn`
with the boar-king rig (`gorrak_body`, HUMANOID: he stands upright); his numbers are the
gamedesign's final config (v6), except Stage 3 HP, retuned 1600 → 1500 in 6.5
(see Balance). Not owned by default: 3,000 Leaves once any owned monster is
Lv.3 (bought on the unlock sheet, see Opponent Choice and Monster Unlocks),
and the Heroes side meets him after 6 hunts (`opponent_after_matches`).

| Attribute        | Stage 1 (Tusker) | Stage 2 (Warlord)   | Stage 3 (Boar King)  |
| ---------------- | ---------------- | ------------------- | -------------------- |
| **HP**           | 1100             | 1450 (heals to full) | 1500 (heals to full) |
| **Damage taken** | × 0.85           | × 0.90              | × 1.00               |
| **Speed**        | 56               | 64                  | 74                   |
| **Scale**        | 1.0              | 1.15                | 1.3                  |
| **Strafe**       | 40 px/s, 2.5 s   | 50, 2.0 s           | 60, 1.5 s            |
| **XP Required**  | Start            | 150 XP              | 500 XP               |

Reach 85 (`base_attack_range`), he keeps 50 px (`preferred_distance` on the
scene root; min 20) and leaves Fight past 110 px. Every ability has a
per-stage table, so the stage damage multiplier never applies to him.

- **Bristled Hide** (passive slot, his armour): every hit on him lands × 0.85
  at Stage 1 and × 0.90 at Stage 2 (`MonsterStats.damage_taken_mult_per_stage`,
  after the tree's damage-taken nodes); at Stage 3 the armour is gone.
- **Cleaver Chop** (ability 1, `BullFrontCleave`): an 85 px cone of
  70 / 80 / 90°, 14 / 18 / 18 damage every 2.8 / 2.6 / 2.2 s.
- **Tusk Axe** (ability 2, ACTIVE, `thrown_axe.gd`): a spinning axe thrown at
  a hero 110–260 px away (`dash_min_range` 110 to its 260 px reach, from
  Approach, aimed at the hero). It flies out at 520 px/s and hits every
  target within 28 px of it once; a wall (the edge of the navigation mesh,
  `GameUtils.clamp_to_nav_segment`) stops it early. With `returns` it then
  flies back to his hand and can hit each target once more: 10 / 14 / 18
  damage a hit, every 7 / 6 / 5 s. It cannot be thrown again while it flies,
  and it ends with him. `stun_duration`
  (0 = off) is for the tree's Concussive Axe. No node and no timer: a point
  that MonsterBase steps through `tick_active` on his own copy, one overlap
  query per frame while it flies (about 1 s of every 5–7 s). AbilityVfx
  draws it spinning, and his rig's own `axe` part (split from the arm art)
  hides meanwhile (see Ability Effects); F3 shows `axe in hand` /
  `axe! flying out` / `axe! flying back`. `escape_with_ability_2` is false:
  he never throws it away from the heroes as an escape.
- **Warcry Stomp** (ability 3, ULTIMATE, `BullGroundSlam` with
  `leap_distance` 0): his from Stage 1. A 0.6 s hop in place (30 px), then
  12 / 18 / 22 damage within 100 / 130 / 160 px, every 18 / 15 / 12 s, and a
  0.6 s stun on everything it hits. Its cast centre is Gorrak, so the combo
  stomps when 2 targets (`slam_min_targets`) stand around him.
- **AI**: see Monster AI → Gorrak (late retreat, only with 3 heroes on him).
- **Counterplay** (his def's tip): his stomp stuns everyone close. Spread out,
  kite the axe, strike when his armour cracks at Stage 3.

---

## 🗺️ Map Design - "Primal Jungle" (9200x5185)

### Zone Layout

```
╔═══════════════════════════════════════════════════════════════╗
║  ZONE 1: Hero Spawn (0-2000)                                  ║
║  └─ Safe area, team formation                                 ║
╠═══════════════════════════════════════════════════════════════╣
║  ZONE 2: Bat Territory (2000-3500)                            ║
║  └─ Bat camps (6 hero XP / 8 monster XP per Bat)              ║
║  └─ Light farming zone for heroes                             ║
╠═══════════════════════════════════════════════════════════════╣
║  ZONE 3: Mixed Territory (3500-5500) ⚠️ CONTESTED             ║
║  └─ 3 Bat camps + 2 Hog camps                                 ║
║  └─ Monster spawn location (random in zone)                   ║
║  └─ First contact probability: HIGH                           ║
╠═══════════════════════════════════════════════════════════════╣
║  ZONE 4: Hog Territory (5500-7000) 🐗 MONSTER PARADISE        ║
║  └─ Hog camps (15 hero XP / 25 monster XP per Hog)            ║
║  └─ (planned: 1 Elite camp)                                   ║
║  └─ Monster farming priority                                  ║
╠═══════════════════════════════════════════════════════════════╣
║  ZONE 5: Deep Jungle (7000-9200) 🌲 ENDGAME                   ║
║  └─ (planned: 2 Elite camps, high risk/reward)                ║
║  └─ Dense fog of war                                          ║
║  └─ Stage 3 monster hunting grounds                           ║
╚═══════════════════════════════════════════════════════════════╝
```

The zone diagram is the design intent. `World.tscn` ships 39 camps (29 Bat,
10 Hog); the Elite camps are designed, not built.

### Mob Camps

| Type           | HP  | Damage | Cooldown | Camp Size | Hero XP | Monster XP | Total XP (Monster) |
| -------------- | --- | ------ | -------- | --------- | ------- | ---------- | ------------------ |
| **Bat Camp**   | 50  | 5      | 1.5s     | 3         | 6       | 8          | 24 XP              |
| **Hog Camp**   | 100 | 10     | 1.0s     | 3         | 15      | 25         | 75 XP              |
| **Elite Camp** | 180 | 15     | 0.9s     | 2         | 50      | 50         | 100 XP (planned, not built) |

Mob numbers live on the scenes (`mobs_base_class.tscn` for the Bat's
defaults, `Hog.tscn`): `max_health`, `base_attack_damage`, `attack_cooldown`,
`hero_xp_value`, `xp_value`. Bats fly at 150 px/s, Hogs walk at 70. One Bat
camp holds 2 Bats, every other camp 3.

**Total Map XP** (for the monster, all 39 camps once; 26-30 of them are
eligible per match and every camp respawns after 40 s):

- Bats: 688 XP (86 Bats in 29 camps)
- Hogs: 750 XP (30 Hogs in 10 camps)
- **Total configured**: 1,438 XP, about 5x the 300 Grount needs for Stage 3

### Spawn System

- **MobSpawnArea**: 39 circular camps (116 mobs configured). `SpawnManager` picks 26–30 of them as world-eligible per match and only instantiates a camp while a hero is inside its activation ring (200 px; despawn beyond 300 px)
- **Respawn Time**: 40 s on every camp in `World.tscn` (prefab default 10 s). Dead and despawned mobs are recycled from a pool instead of re-instantiated
- **Leash Distance**: Mobs return if heroes run too far (100 px from the camp centre)
- **Camp Clearing**: Important strategic decision (delay monster vs gain XP)

---

## 📊 Balance Sheet - Target Win Rates

The first three blocks are the design targets (what a match should feel
like); "Measured Balance" below is what the headless sim plays today, per
monster and side.

### Encounter Scenarios

| Timing              | Hero Level | Monster Stage | Hero DPS | Fight Duration | Target Win Rate             |
| ------------------- | ---------- | ------------- | -------- | -------------- | --------------------------- |
| **Early** (0-3 min) | 1-2        | Stage 1       | 35-40    | ~20-23s        | 70% Heroes / 30% Monster    |
| **Mid** (3-6 min)   | 2-3        | Stage 2       | 42-48    | ~30-35s        | 50% Heroes / 50% Monster ✅ |
| **Late** (6+ min)   | 3-4        | Stage 3       | 50-56    | ~40-45s        | 35% Heroes / 65% Monster    |

### Strategic Implications

**Hero Strategy Matrix**:

```
                    Monster Found Early    Monster Found Late
Rush Strategy       ✅ 70% Win             ❌ 35% Win
Balanced Strategy   ✅ 50% Win             ⚠️ 45% Win
Greedy Strategy     ⚠️ 45% Win            ❌ 30% Win
```

**Monster Strategy Matrix**:

```
                    Heroes Rush            Heroes Farm
Hide & Farm         ❌ 30% Win (found)     ✅ 65% Win (Stage 3)
Aggressive Hunt     ⚠️ 50% Win            ⚠️ 50% Win
Early Ambush        ⚠️ 40% Win            ✅ 60% Win
```

### Tuning Knobs (If Balance Needs Adjustment)

**If Heroes Win >55%**:

- Increase monster XP gains (8 → 10 per Bat, 25 → 30 per Hog)
- Reduce Stage 2 threshold (150 → 120 XP)
- Buff Stage 2 stats (+100 HP, +10 speed)

**If Heroes Win <45%**:

- Increase hero starting stats (+10 HP each)
- Improve hero level scaling (+1 dmg per level)
- Reduce monster Stage 3 damage multiplier (2.0x → 1.8x) — applied to Grount in 6.3: his
  tabled Stage 3 damage × 0.9 (see Measured Balance below)

**If Matches Too Long (>10 min)**:

- Reduce map size or add shortcuts
- Increase movement speeds (+10-15 for both sides)
- Buff damage across the board (+20%)

**If Matches Too Short (<4 min)**:

- Increase all HP pools (+20%)
- Reduce damage (-15%)
- Add more escape/kiting abilities

### Measured Balance (headless sim, fresh save)

The target is 40–60 % hero wins per monster on both sides
(`MONSTER=<id> tools/sim.sh 48 heroes 6` and `... 48 monster 6`, reproducible
since 6.2). A timeout is a monster win at the 10-minute clock. These tables are
fresh saves, threat 0; the balance at each Opponent Threat level is under
"Opponent Threat".

| Grount | Heroes side | Monster side | Timeouts (H / M) | Median Stage 3 | Median first contact |
| ------ | ----------- | ------------ | ---------------- | -------------- | -------------------- |
| before 6.3 (`16aed14`) | 19 % | 25 % | 4 / 4 | 324 s / 325 s | 409 s / 389 s |
| 6.3: Trap Cage fixed + Stage 3 damage × 0.9 | **46 %** | **48 %** | 4 / 3 | 322 s / 323 s | 400 s / 408 s |

- 6.3 changed two things. Ted's Trap Cage now traps what it lands on (it
  trapped almost nothing; see "Hero capstones and behaviour nodes"), which
  alone takes the heroes side to 33 %. Grount's
  tabled Stage 3 damage went × 0.9: Front Cleave 12 → 10.8, Ram Dash 36 → 32.4,
  Ground Slam 25 → 22.5, and `stage_3_damage_multiplier` 2.0 → 1.8 for an
  untabled ability. Nothing below Stage 3 changed.
- By Grount's stage at the first contact: at Stage 1 (6–9 of 48 matches) the
  heroes win nearly all; at Stage 3 (34–38 of 48) they now win 38–42 %
  (before: 8–14 %). The 3–5 matches without a contact are timeouts or a
  Grount killed by mobs.
- Capstone check (`SAVE=` the branch-2 capstones, River's Pathfinder among
  them, 24 seeds, heroes side): 75 % (71 % before 6.3). Pathfinder still brings
  the first contact to about 64 s, Stage 1, where the heroes win most fights.
  That save owns one rank per hero tree (power ranks 0), so under Opponent
  Threat (6.8) the AI Grount still plays threat 0, unbuilt.

| Nyxa | Heroes side | Monster side | Timeouts (H / M) | Median Stage 3 | Median first contact |
| ---- | ----------- | ------------ | ---------------- | -------------- | -------------------- |
| 6.4: gamedesign config v9 (24 seeds in the design: 46 %, 8 timeouts) | **54 %** | **52 %** | 18 / 17 | 371 s / 371 s | 417 s / 417 s |

- Nyxa's wins are almost all timeouts: in 17 of 48 matches the heroes never
  meet her (she farms Bats away from them and swoops off). When they meet
  her at Stage 1 (7 of 48) the heroes win all; at Stage 3 (24 of 48) they
  win 75–79 %. Accepted as her trait: she evades.

| Gorrak | Heroes side | Monster side | Timeouts (H / M) | Median Stage 3 | Median first contact |
| ------ | ----------- | ------------ | ---------------- | -------------- | -------------------- |
| gamedesign config v6, Stage 3 HP 1600 (24 seeds in the design: 42 %) | 38 % | 50 % | 5 / 5 | 346 s / 347 s | 448 s / 456 s |
| 6.5: Stage 3 HP 1600 → 1500 | **42 %** | **52 %** | 5 / 5 | 346 s / 347 s | 448 s / 456 s |

- The design tuned him against the old Grount framework (17 % for Grount
  then). Against today's heroes (Trap Cage traps, 6.3) config v6 came out
  at 38 % on the heroes side, below the target, so Stage 3 HP went 1600 →
  1500 (the design's h5 value; still above Stage 2's 1450). Also tried:
  1550 (38 % / 51 %) and 1500 with the Stage 3 axe at 16 (42 % / 50 %).
- Nearly every match is decided at Stage 3: the first contact falls at
  Stage 1 in 6 of 48 matches (the heroes win 4) and at Stage 3 in 37–38,
  where the heroes win 42 % (heroes side) and 57 % (monster side). The 4–5
  matches without a contact are timeouts.

---

## 🎨 Visual Systems

### Art Direction: Jungle Guild

**Reference**: UnderGuild's collection screen, moved into the jungle;
Underdark: Defense and Lucky Defense for the in-match readability.

**Rules** (the art area's spec, enforced by the generators and tests):

- Flat fills with one shade crescent, a heavy dark-brown ink outline
  (`ink` #1A1311) on everything, no gradients, filters, masks or text in the
  SVGs (`tools/art/svgkit.py`).
- One palette (`tools/art/palette.py` → `UiPalette`, 100 tokens): warm
  charcoal surfaces, copper and amber, moss / teal / carved wood / mossy
  stone; heroes warm, monsters crimson and purple. No colour literal in a UI
  script or scene (`tools/lint.sh` checks it).
- Chunky chibi characters (the characters area's art, ten of them) as SVG
  cut-out rigs: the same rig in the lobby, on the cards, in the HUD and in
  the match.
- The match keeps the 16 px pixel jungle tiles under a muted, darker grade
  so the ink-outlined rigs are the brightest thing on screen.
- Every ability gets a pooled, cheap SVG effect and a body move; numbers and
  shake are capped so a big fight stays readable.
- Lilita One for display text ("Lv.N", headers, buttons, numbers), the
  engine's Open Sans SemiBold for small body text.

### Palette and Art Pipeline ("Jungle Guild")

The UI look follows UnderGuild's collection screen moved into a jungle: a flat
warm-charcoal screen (`bg_base` #2A2826), a heavy dark-brown ink outline on
everything (`ink` #1A1311), copper card outlines (`copper` #C86A32), amber
highlights (`amber` #F2A93B), moss / teal / carved wood / mossy stone as the
jungle secondaries. The hero side reads warm (`hero` #E39A3B), the monster side
dangerous (`monster` #C2334A, `monster_purple` #7B3F95).

- **One palette**: `tools/art/palette.py` is the single source of every colour
  (100 tokens in 10 groups: surfaces, ink and text, copper and amber, jungle
  secondaries, factions, hero and monster signatures, currencies, rank tiers,
  states). The SVG generators, the theme generator and the runtime palette all
  read it. `text_dim` means secondary text.
- **Runtime palette**: `UiPalette` (`Scenes/UI/Theme/ui_palette.gd`) is a
  Resource with one exported Color per token; `Scenes/UI/Theme/palette.tres`
  holds the values. Both are generated: change a colour in `palette.py`, then
  run `python3 tools/art/make_theme.py palette` (also refreshes
  `tools/art/palette.json`). A token without a value stays magenta.
    - `UiPalette.get_default()`: the project palette; read tokens as
      `UiPalette.get_default().copper`.
    - `color(token)`: lookup by StringName for data that names a colour; an
      unknown token returns magenta.
    - `UiPalette.signature(id, is_monster)`: a character's signature colour
      (irelia, vlad, ted, river, grount; nyxa → `monster2`, gorrak →
      `monster3`, provisional); any other id falls back to `hero` / `monster`.
    - `COOLDOWN_VEIL_ALPHA` (0.70) and `LOCKED_MODULATE` (locked silhouette).
    - `test/test_ui_palette.gd` checks palette.tres against palette.json, the
      magenta fallback and the signatures.
- **Art pipeline** (`tools/art/`, ignored by Godot through `.gdignore`):
    - `build.py [module ...]` writes the SVG kit and icons into
      `Assets/UI/<group>/` and renders review sheets into `tools/art/preview/`
      (git-ignored) with `render_sheets.gd`, on a throwaway Godot project.
    - `make_theme.py [palette] [theme] [shaders]` writes the palette (above),
      the project Theme (`Scenes/UI/Theme/ui_theme.tres`, below) over the SVG
      kit and the cooldown / locked-card shaders.
    - `write_import_stubs.sh <dir>` makes every SVG import as a DPITexture
      (re-rasterised at the canvas scale, sharp on 2x / 3x phones).
    - Style rules live in `svgkit.py`: flat fills with one shade crescent, a
      3.5 px ink outline at 64 px, no gradients, filters, masks or text.
- **UI kit** (`Assets/UI/`, all generated: edit the generators, never the
  files). Every SVG imports as a DPITexture (`importer="svg"`), so it stays
  crisp at any Control size and canvas scale.
    - `Kit/` (64): card frames and inner panels (hero / monster / selected /
      locked), carved-wood nav plaques and the mossy-stone HUNT arch, buttons
      (primary, secondary, copper, hero, monster, round) with hover / pressed
      art, panels and banners (plus the match result's outcome ribbons:
      `banner_victory` copper, `banner_victory_monster` crimson,
      `banner_defeat` grey stone), ability slot frames (basic, active, passive,
      ult, locked), toggles, padlock,
      notification dot, leaf and vine ornaments, the background tile. 9-slice
      margins live in `kit.MARGINS`.
    - `Icons/` (81, 64x64): `Abilities/` (29, `<owner>_<slot>_<ability>`:
      a full-bleed tile in the owner's tone that the slot frame sits on;
      every hero and Grount ability, River's two basic modes, and Nyxa's and
      Gorrak's (their Blood Drinker and Bristled Hide passives included) on
      the `monster2` / `monster3` tiles), `Currency/`
      (gold, steel, leaves, upgrade point), `Stats/` (16), `Roles/` (9 filter
      silhouettes), `Nav/` (6) and `UI/` (17 glyphs; `ui_skull` marks a
      fallen hero and the HUD's kill count).
    - Every ability `.tres` (the 16 hero abilities and the three monsters'
      kits) sets
      its `icon` to its tile; no ability shows the old `Icon.jpg`
      placeholder (`Assets/Icon.jpg` is only the app icon now,
      `config/icon`). River's basic attack also has `heal_icon`
      (`river_basic_heal`) next to `icon` (`river_basic_sniper`).
      `test/test_ability_icons.gd` checks the resource-to-icon table, the
      DPITexture imports and River's weapon-mode swap.
    - `Crests/`: the hero and monster side crests.
    - `Shaders/ability_cooldown.gdshader` (clockwise cooldown sweep with an
      amber edge, `ready_flash`, `locked`), `card_locked.gdshader` (locked
      character silhouette) and `ready_glow.gdshader` (the pulsing halo behind
      a ready ultimate's AbilitySlot, from the UX prototype). Their default
      colours come from the palette (`ready_glow`: `amber_light`).
    - `test/test_ui_kit.gd` checks the DPITexture imports, every character's
      ability icons, the mockup's variations, the shaders' palette colours
      and the proof scenes.
- **Theme** (`Scenes/UI/Theme/ui_theme.tres`, generated by `make_theme.py
  theme`; never edit it by hand): the one Jungle Guild Theme of every screen.
  It is the project theme (`gui/theme/custom`), so every Control picks it up
  (menus, HUD, overlays, the F3 labels), and the UI scenes also set it as
  their `theme` by uid (`uid://eroe1xxhr5fc`, kept across regenerations).
    - **Fonts**: `font_display` is Lilita One (`Assets/Fonts/LilitaOne-
      Regular.ttf`, SIL OFL 1.1) for all display text: "Lv.N", headers,
      banner titles, nav labels, cooldown numbers, counters, buttons and bar
      text, each with its ink outline (CardLevel 26/9, HeaderLarge 36/11,
      buttons 22/7, ...). Lilita One has one weight and Latin glyphs only
      (German umlauts and ß included), so it falls back to `font_body` for
      anything else. `font_body` (default font, 20 px) is Godot's built-in
      Open Sans SemiBold, emboldened 0.25, for small body text (Label,
      CardName, Caption, BodyDim, tooltips, HintLabel). Dropdowns
      (OptionButton) use the display font at 16 px.
    - **Art variations**: labels (CardLevel, CardName, PillText, HeaderLarge,
      HeaderSmall, BannerTitle, Counter, CooldownNumber, NavLabel, Caption,
      BodyDim, DangerLabel, Hero/MonsterAccentLabel), buttons (Button,
      ButtonPrimary, ButtonCopper, ButtonHero, ButtonMonster, ButtonRound*,
      NavPlaque, NavArch, FilterTab), panels (PanelInset, PanelLeafy,
      PanelMonster, CharacterCard*, CardInner*, Banner*, Pill, PillReady,
      CurrencyPill, NavBar, HudPanel, HudPanelSelected, TooltipPanel) and bars
      (HpBarHero, HpBarMonster, XpBar, CooldownBar, ShieldBar, PillProgress*,
      NavProgress).
    - **Screen variations** for the Phase 3-5 screens: the skill tree's
      NodeTile (a flat 84 px rounded square in the locked look, locked_fill
      with a 4 px locked_line rim; SkillNodeButton recolours its own copy in
      the branch colour), BadgeReady (the red "+"), GutterPlaque /
      GutterPlaqueLocked (the tier gutter's wood_dark / locked_fill plaques)
      with GutterCaption / GutterNumber (and their Locked versions in
      text_muted), NodeName / NodeNameLocked (13 px names under the tiles),
      NowLabel (white) and NextLabel (moss_light) for the sheet, rank pips
      PipOn / PipOff / PipMax, SelectRing (a white rounded square),
      BranchPlaque (tinted per branch by the view), SheetPanel, ChipPanel,
      FrameHero / FrameMonster (border only), EvoBar, TabButton, FlatButton,
      BigNumberLabel, HintLabel and AmberLabel.
    - **Art names are canonical**: the UX prototype's theme is not shipped,
      and its names for looks the art set has are renamed (CardPanel →
      CharacterCard, PrimaryButton → ButtonPrimary, MossButton → ButtonHero,
      HudCard → HudPanel, TitleLabel → HeaderLarge, MutedLabel → Caption, ...;
      the full table is in `make_theme.py`).
    - The old screens (main menu, pre-round, skill screen, match result) are
      gone (8.3). The settings sheet, the tutorial's coach marks, the Codex
      and the pause menu use theme variations only (SheetPanel, PanelLeafy,
      PanelInset, SelectRing, PipOn / PipOff, HeaderLarge, HeaderSmall,
      BodyDim, Caption, HintLabel, TabButton, FlatButton, ButtonRound,
      ButtonPrimary, ButtonMonster) and the palette's scrim (`bg_void` at
      0.72); `test_tutorial` and `test_settings_and_back` check their scenes
      override no colour, font or style. The MatchHud's cards and panels use
      HudPanel / HudPanelSelected and HpBarHero / HpBarMonster.
    - **No colour literals in the UI** (`tools/lint_all.gd`,
      `_check_no_color_literals`): no script, scene or resource under
      `Scenes/UI/` writes a colour as numbers. In a script that is a
      `Color(` whose first argument is a number or a string, `Color8(` or
      `Color.html / hex / from_*(`; a token with an alpha
      (`Color(palette.bg_void, 0.72)`) and the identity `Color.WHITE` are
      fine. In a `.tscn` / `.tres` every `Color(` is a literal: use a theme
      variation, or set the token from the script (a scrim's ColorRect, the
      NavArch glow pulse animates `self_modulate:a`). Exempt: the colour
      sources themselves (`ui_palette.gd`, `palette.tres`, `ui_theme.tres`).
      The lint prints `ui_color_checked=<n>` and fails on any hit.
    - `test/test_theme_contract.gd`: the project setting points at the theme,
      every `theme_type_variation` a scene or script under `Scenes/` and
      `Scripts/` names exists, every StyleBoxTexture and icon resolves to a
      DPITexture, display types use Lilita One over `font_body` and body
      types `font_body`, every glyph of `strings.csv` (English and German)
      renders in the display font, the screen variations exist with their
      base types and colours (the old round Node* / Cap* rings and GateChip
      are gone), and no UX name is back.
- **Proof scenes** (`tools/preview/`, not shipped; any export preset must
  exclude `tools/*`): `ThemeMockup.tscn` composes every theme type and kit
  piece the way the collection and HUD screens will (role glyphs in the
  signature colours stand in for the character portraits until the rigs
  land); `ThemeScreens.tscn` shows the screen variations (real
  SkillNodeButtons and capstones in every state, tinted branch plaques, the
  tier gutter's plaques, tabs, bottom sheet, side frames); `PaletteSheet.tscn` shows every UiPalette token. Render them muted
  on a copy of the project:
  `godot --path <copy> --audio-driver Dummy --fixed-fps 30 --write-movie <dir>/f.png --quit-after 8 res://tools/preview/ThemeMockup.tscn`.

### Character Rigs (SVG cut-out runtime)

Every character is a chunky chibi SVG cut-out rig (the pixel
`AnimatedSprite2D` frames are gone since 8.3). The runtime, the builder and
the art of all ten characters are in place, and every character in the match
draws its rig: the four heroes, Ted's fox, Grount (all three stages), Nyxa,
Gorrak and the Bat and Hog mobs.

- **Source** (`Assets/Characters/<id>/src/`, ignored by Godot through
  `.gdignore`): `rig_src.json` (canvas 128x160, baseline 150, optional
  `sheet_scale`, and the parts: name, z, pivot, parent, stages) and
  `parts/<part>.svg`, each part alone on the full canvas.
- **Art**: the characters area's chibis are the one character art (world,
  cards, lobby, HUD heads). Ten characters, each `Assets/Characters/<id>/`
  with its `src/`, the generated sheet and body, `<id>_motion.tres` and the
  composite portrait `<id>.svg` (the whole chibi on the 128x160 canvas,
  imported as a **DPITexture** for UI; Grount also has `grount_s2.svg` and
  `grount_s3.svg` for its later stages):

  | id | who | parts | body plan | world_scale | sheet svg/scale | full_speed / stride |
  |---|---|---|---|---|---|---|
  | irelia, vlad, ted, river | heroes | 7 | HUMANOID | 0.4 | 3 | 75 / 80 / 85 / 85, stride 18.1 |
  | grount | monster (3 stages: horns, eyes, spikes, cracks, chain) | 16 | HUMANOID | 0.6 | 3 | 60, 24.3 |
  | gorrak | monster | 7 | HUMANOID | 0.6 | 3 | 56, 25.1 |
  | nyxa | monster | 6 | FLYER | 0.6 | 3 | 85 (no legs) |
  | hog | mob | 5 | QUADRUPED | 0.38 | 2 | 70, 19.1 |
  | bat | mob | 4 | FLYER | 0.32 | 2 | 150 (no legs) |
  | pet | Ted's fox | 5 | QUADRUPED | 0.3 | 2 | 120, 20.1 |

  The small ones' sheets rasterise at 2 px per art unit (VRAM); the rest at 3,
  which stays crisp up to about camera zoom x7.5 for heroes. `full_speed` is
  the character's move speed (stage 1 for monsters), so its usual walk swings
  the legs fully, and `stride` = 4 x leg (hip pivot to sole) x
  sin(`leg_swing`) x `world_scale`, so a planted foot does not slide. In a
  match the rig steps by `walk_stride()` = `stride` x its own +-4 % size x
  the entity's scale, so an evolved Grount (1.25x, 1.5x) or any growing
  monster takes proportionally longer steps instead of pedalling.
- **Builder**: `tools/build_rigs.sh [id ...]` runs `tools/rig_builder.gd`
  (`RigBuilder`) on a temp copy and copies back, per character:
    - `<id>_sheet.svg`: every part cropped to its alpha box and shelf-packed
      into ONE atlas (one texture, one draw per character), imported as a
      CompressedTexture2D at `svg/scale` px per art unit (3 by default) with
      mipmaps;
    - `<id>_body.tscn`: a `RigBody` with one Sprite2D region per part in the
      art's joint hierarchy, drawn in the art's z order **without z_index**
      (z_index is global and would draw parts over other entities):
      `show_behind_parent`, plus `<part>__back` proxy nodes when a branch
      must interleave with a sibling (a cape behind the legs).
  The output is deterministic text and generated only: art that no node tree
  can draw in z order, or parts that share an SVG id, are reported and nothing
  is written. Never edit the generated files; edit `src/` and rebuild.
- **`RigProfile`** (`<id>_motion.tres`, shared): body plan (HUMANOID: upright
  on two legs with two arms, the heroes and the monsters Grount and Gorrak;
  QUADRUPED: the Hog and Ted's fox; FLYER: the Bat and Nyxa), `world_scale`,
  idle breathing, locomotion (`full_speed`, `stride` so feet never slide,
  bounce, swings, lean), flyer flaps and hover, hurt and attack reactions, and
  `moves`: the body plan's move library (see Moves below).
- **`CharacterRig`** (`Scripts/Rig/character_rig.gd`) is the `Rig` node every
  entity has in `NPCBaseClass.tscn`; a migrated scene adds its body under it
  and sets `body`, `profile` and `tier`. It is presentation only and not a
  state machine: the pose is a function of the distance travelled, time and
  decaying event timers. It reads the entity's position and the hidden facing
  `Sprite2D` (which gameplay keeps rotating) and never writes either; per-
  instance phase, breathing rate and a ±4 % size come from a private RNG.
  Without a body it is inert (never wakes, draws nothing).
    - Events are wired in the scenes: `EntityBase.ability_cast(ability,
      target)` (sent by `announce_cast()`, which `EventBus.notify_ability_cast`
      and a mob's basic swing call; `ability` is null for the swing) plays the
      ability's move (below), `EntityBase.damaged(packet)` the hurt flash and
      squash plus the hurt move when no other move plays,
      `MonsterBase.evolved(stage)` → `Rig.set_stage` the stage's parts. An
      asleep rig (off screen) plays nothing; a mob's rig over the budget (see
      LOD) plays the procedural swing instead of the attack move and only
      flashes on a hit (`plays_moves()` is false).
    - `swing_fx` (scene-side, presentation only): the `AbilityFxRecipe` of a
      swing that carries no ability, which AbilityVfx draws on each hit the
      character lands while its rig `plays_moves()` (Ability Effects): the
      Bat and Ted's fox `fx_generic_bite`, the Hog `fx_generic_claw`. The
      hit's packet still carries no ability (Loyal Companion and the damage
      pipeline see the same hit).
    - **Moves** (authored, not procedural): one `AnimationLibrary` per body
      plan in `Assets/Characters/_moves/` (`humanoid_moves.tres` 22 moves,
      `quadruped_moves.tres` 7, `flyer_moves.tres` 7; hand-written, with a
      uid like every hand-written scene, which `test_legacy_retired` checks),
      set as each profile's `moves`, so one library fits every character of
      the plan. Every library
      has `attack`, `cast`, `ultimate`, `hurt` and `cheer`; the humanoid one
      also the signature moves `bash`, `shield_up`, `war_cry`, `place`,
      `rally`, `throw`, `aim`, `point`, `twirl`, `point_up`, `cleave`, `chop`,
      `slam`, `stomp`, `charge`, `spin` and `leap`; quadrupeds `charge` and
      `leap`; flyers `shriek` and `swoop`. The poses are the anim area's
      combat clips, ported and toned to the rule that a strike's contact frame
      sits at or before 0.15 s (the hit lands at the cast). Tracks address the
      parts (`%arm_f:rotation`; rest rotation is 0 in every generated body)
      and, through `..`, the rig's root channels: `move_offset` (art units,
      x forward, y down), `move_scale` (about the feet), `move_tilt` (a
      forward lean) and `arm_f_reach` / `arm_b_reach` (an arm's offset from its
      rest position, a weapon thrust to the sky). Keys are linear, eased in
      and out per segment (transition -2), so a pose never overshoots. A part
      or channel the body lacks is skipped (the Bat has no head or arm), and
      the library stays editable in Godot's animation editor (an
      AnimationPlayer rooted at a body).
    - The rig samples the move itself (`Animation.value_track_interpolate`)
      after its procedural layer and blends it over that layer: in over
      0.06 s, out over the last 0.12 s, only on the channels the move keys, so
      a cast that keys the arms leaves the legs walking. The root channels
      follow the facing (a lunge goes the way the character looks) on top of
      the rig's own flip, squash and hover. A cast replaces the move playing;
      a flinch never cuts one short. A move the library lacks falls back to
      the procedural swing.
    - Timed moves (Animation markers, editable in the animation editor): a
      leap's `contact` marker (`slam` 1.0 s, `stomp` 0.6 s, today's
      `jump_duration`s) is stretched to the airtime its `FxEvents.SLAM_LEAP`
      reports (0.25x to 4x; it comes the frame before the cast), so the
      landing pose lands with the hit whatever a node does to
      `jump_duration`, and `SLAM_LANDED` jumps a late pose straight to it; a
      dash's run loops between its `loop_from` and `loop_to` markers
      (`charge` 0.45-0.6 s, one stride; `swoop` 0.3-0.4 s, the held dive)
      while the dash `DASH_STARTED` names is still `is_dashing` (read only:
      Echo Strike's way back keeps running), then plays out. Only FULL rigs
      with an entity listen (`EventBus.ability_event`, connected in `_ready`).
    - Gorrak's `spin` (Whirlwind) turns through a mirrored body: its x scale
      narrows to 0.45, flips within 0.1 ms and broadens mirrored, so it is
      never drawn edge on (it used to pass through 0, a 2-3 px sliver).
    - Which move a cast plays is data: `AbilityBase.move_name`
      (presentation only, read through `get_move_name(caster)`), falling back
      to `attack`, `cast` or `ultimate` by the ability's slot; a mob's swing
      plays `attack`. Vlad: attack, place, ultimate; Irelia: bash, shield_up,
      war_cry; Ted: attack, rally, throw; River: aim (rifle) or point
      (`heal_move_name`, the heal staff), twirl, point_up; Grount: cleave,
      charge, slam; Gorrak: chop (`full_circle_move_name` spin while
      Whirlwind makes the cleave a full circle), throw, stomp; Nyxa: shriek,
      swoop, ultimate; the fox, the Hog and the Bat: attack. The menus'
      `StageCharacter.cheer()` plays `cheer` during its hop.
    - Mid-body anchor: `CharacterRig.mid_body()` / `mid_body_of(node)` is
      the middle of the drawn body (the art's box centre, raised by a flyer's
      mean hover, at the rig's size and the entity's scale), the start and end
      of line effects (AbilityVfx's tracers, heal hops and beams, Monster
      Taunt's tethers; BasicStrike's optional trail), which used to run feet
      to feet. A node without a rig keeps its own position. `head_top()` /
      `head_top_of(node)` is the top of the drawn body, where a lasting
      status mark (a taunt's anger vein, a "!") floats clear of the head; a
      node without a rig answers 32 px above its position.
    - Hit flash: the rig drives the body's modulate over 1 (palette white x
      `hurt_flash_gain`, easing back to white). Every generated body draws
      through ONE shared material, `Assets/Shaders/hit_flash_material.tres`
      (`hit_flash.gdshader`) on the body root, every node under it
      `use_parent_material` (written by `tools/rig_builder.gd`): the shader
      reads a modulate of (1 + f) on all three channels as a flash of f and
      mixes the art toward white, a white silhouette instead of a brightened
      one, while ordinary tints (a trapped enemy's honey, Last Stand's glow)
      pass through. One shared material keeps a character in one draw and a
      species' mobs batched together.
    - `EntityBase.visual_root()` is what effects move or tint (Ground Slam's
      hop, Trap Cage's pulse, Vampiric Rebirth's fade): the rig (null only
      for a bare base scene without a body, which draws nothing).
    - LOD: a rig animates only while its entity's ScreenNotifier is on screen.
      While more than 48 rigs are awake (`within_budget()` is false), mob
      rigs (tier BUDGETED) animate every other frame, staggered, and skip
      their authored moves (a swing plays the procedural swing, a hit only
      flashes) and their `swing_fx`; heroes and the monster use tier FULL.
      A rig writes only the pose channels that changed since its last frame
      (an idle mob mostly breathes), and forgets them after an authored move
      or `reset_pose`. The F3 overlay shows the rigs awake now, their mean
      since F3 was pressed and "mobs half rate, no moves" while over the
      budget.
    - Pooled mobs leave the tree and come back without a new `_ready`: a rig
      leaving the tree sleeps and drops its hurt flash, attack swing, move
      and walk, so the next life starts clean; on re-entry the notifier wakes it
      (or, under the tools' `force_awake`, the rig itself).
    - Contact shadow: every Rig's first child is a `Shadow` Sprite2D
      (NPCBaseClass.tscn, and TedsPet.tscn; wired to `shadow` scene-side)
      holding `Assets/Characters/shadow_blob.svg`, a white 128x48 ellipse with
      a dense core and a soft rim (CompressedTexture2D with mipmaps, drawn
      LINEAR_WITH_MIPMAPS like the rig art). `_ready` tints it with the
      palette's `ink` at `shadow_alpha` (0.55) and sizes it once to
      2 x `shadow_radius` x `SHADOW_SPREAD` (1.5) world px. The radius is
      derived, never set per scene: `CharacterRig.shadow_radius_for(body,
      profile)` = the body's width (`RigBody.bounds`) x `world_scale` x the
      profile's `shadow_per_width` (0.33 by default; 0.38 for the heroes, 0.36
      for Grount and Gorrak, 0.21 for the hovering Bat and Nyxa), which gives
      about 14 for the heroes and the Hog, 24 for Grount, 10 for the fox and 9
      for the Bat (the old hand-set numbers), 23.5 for Gorrak and 16.6 for
      Nyxa. The menus' `RigView` uses the same rule. Being
      drawn first, it sits under the body; it stays on the ground at the feet
      while the body bounces or a flyer hovers, and it is hidden while the rig
      is inert. It is not the hurt flash's target (that is the body).
    - Evolution (`set_stage`): the stage's parts, and on screen the
      evolution flash (an evolution off screen leaves no flash pending). The
      stage SIZE stays the monster's root scale (gameplay: collision and
      aggro shapes grow with it), which the rig inherits. `MonsterBase`
      adds the stage ring pulse (gold, amber at Stage 2, danger at Stage 3).
      The old sprite path (stage SpriteFrames from `MonsterVisualConfig`,
      orange/red tint) is gone (8.3).
- **Migrated scenes** (Irelia, Vlad, Ted, River, `TedsPet.tscn`, Grount, Bat
  and Hog; Nyxa and Gorrak were built on their rigs): 8.3 removed the pixel
  `AnimatedSprite2D` from `NPCBaseClass.tscn` (and every override of it),
  the `animated_sprite` code path, `MonsterVisualConfig` with its
  `*_visual.tres` and Grount's `phase_1/2/3.tres` SpriteFrames, the pixel
  PNGs (heroes, the fox, Bat-Run, Orc-Walk) and `HeroStats.portrait` (the
  roster's `CharacterDef.portrait` is the one portrait). The hidden facing
  `Sprite2D` stays as it was (gameplay keeps rotating it; the fox's is a
  plain `Sprite2D` now); `test/test_legacy_retired.gd` keeps it that way. The
  `Rig` sets
  `body` (through the scene's `node_paths`, so the export resolves at
  instantiation), `profile` and `tier` (FULL for the heroes, the fox and the
  three monsters; the mobs keep the default BUDGETED), with
  `<Id>Body` (the instanced `<id>_body.tscn`) under it. No existing node is
  reordered and World.tscn's node order and y-sort are untouched (it only
  gained the ground grade, see Ground Style), so the match and its trace are
  unchanged.
    - The rig's origin is the character's feet at the entity's position (the
      old sprites were centred on it), so the entity's y-sort now orders by
      the feet.
    - The HP bar's bottom edge sits 6 px above the art: at
      -(round(h x `world_scale`) + 6), where h is `RigBody.art_height()` for
      a walker and, for a flyer (its art floats above its feet), the art's
      top plus its highest hover (1.35 x `hover`). Heroes move their `Hud` to
      y = -68 (Irelia), -64 (Vlad), -59 (Ted) and -70 (River); the fox's bar
      (an HpBar2D like every entity's, 20x4) sits at -44..-40; Grount's
      `Hud` is at -101, Nyxa's at -100 (a flyer: art top 138 + hover 8.1 at
      0.6), Gorrak's at -90 (art 130 at 0.6), the Hog's at -45 and the Bat's
      at -48. Each clears
      the character's tallest pose (largest size, breathing in, top of the
      walk bounce or hover). A monster's `Hud` is a
      child of the growing root: its position grows with the stage scale
      while the bar keeps its pixel size, so it clears the head at every
      stage and with Titan Form.
    - The ScreenNotifier rect must enclose everything the rig can draw
      (`bounds` x `world_scale` at either facing, the size spread, breathing,
      hurt squash and bounce or hover). NPCBaseClass's rect already does for
      the heroes and the mobs. Grount's is sized from its bounds:
      Rect2(-58, -114, 116, 118) also covers Ground Slam's 1.2x hop of the
      rig, and it grows with the stage scale like the rig. Nyxa's,
      Rect2(-58, -112, 116, 112), covers her hovering body and Gorrak's,
      Rect2(-58, -100, 116, 104), his stomp's hop, with the same 1.2x margin.
    - Ted's pet is a CharacterBody2D, not an EntityBase, so its `Rig` sets
      `mover = ".."` and the scene provides what an EntityBase has: its hidden
      facing carrier "Sprite2D" (the pet aims it along its path), a unique
      `ScreenNotifier` wired to the rig, and the presentation signals
      `ability_cast` (each bite) and `damaged` (each hit) wired to the rig's
      handlers. Gameplay never listens to them.
- **Checks**: `test/test_rig_pipeline.gd` runs on the fixture character
  `test/fixtures/rig_fixture/` (generated files fresh for every character,
  z order, stages, broken art refused, no global RNG, no entity writes,
  asleep off screen, inert without a body and its shadow hidden, the budget
  rule, the stride following the entity's scale, and moves: the procedural
  pose taking over after one, blending over the walk on keyed channels only,
  root channels and reach, skipped parts, the move picked per ability and
  the flinch never cutting a move short). `test/test_rig_moves.gd` checks the
  real libraries: each profile's library is its body plan's (Grount and
  Gorrak HUMANOID), the generic and signature moves exist, every track is a
  linear one-shot on a known channel ending at rest, every ability's move
  exists in its caster's library, a cast in a match plays it while the rig
  writes no entity state, the mid-body anchor, the timed moves' markers (a
  leap's contact at its airtime, a seamless dash loop), a slam stretched to a
  reported airtime, a charge looping while its dash goes on, only FULL rigs
  listening, the spin never under 0.4 wide and Ground Slam settling without
  a snap. `test/test_mob_swings.gd` checks the swings without an ability: the
  generic recipes and who swings them, the budget rule, a Bat's bite and a
  Hog's claw inside the budget, the procedural swing and plain flash over it,
  nothing off screen, the fox's bite with its packet unchanged, and the bite
  program's rules and pools.
  `test/test_character_art.gd` checks the real art: the ten characters, their
  sheets' svg/scale and mipmaps, DPITexture portraits, body plans, world
  scales and the no-slide stride. `test/test_rigged_scenes.gd` checks the
  migrated scenes: their own body, profile and tier, the hidden sprite without
  frames, the HP bar rule (at every monster stage), the notifier covering the
  drawn body, the ink contact shadow (wiring, tint, size from the body's
  width, under the body, on the ground while the bat hovers), real heroes, the fox, Grount, Nyxa, Gorrak and the mobs
  walking (the bat and Nyxa flapping), facing and flinching in a match (the fox
  through `mover`), Grount's parts and flash through stages 1 to 3, the mob half rate over the
  budget, a pooled mob's rig starting its next life clean, and the F3 line. `RIGS_AWAKE=1 tools/sim_trace.sh`
  animates every rig and must match the parent trace byte for byte;
  `tools/bench.sh <runs> <mult> <frames> <warmup> <onscreen> 1` wakes every
  rig and reports `rigs_awake_mean`. `tools/preview/RigGallery.tscn` shows
  three large puppets, then every character in idle / walk / run / attack /
  hurt / stage 2 poses, all rows at one scale so the world sizes compare.
  `tools/preview/MoveSheet.tscn` is the moves' contact sheet: per character a
  column per move it plays (its abilities', then hurt and cheer) and three
  frozen moments of each (`-- group=heroes|monsters|small` or ids such as
  `irelia,vlad`).

### Ground Style (pixel tiles under the chibi palette)

The match keeps the 16 px pixel jungle tiles (no SVG ground redraw) and grades
them so they sit under the muted chibi palette: darker and calmer, the dirt
still brown and the grass still green, so the ink-outlined rigs are the
brightest thing on screen. The trees and props are tiles too and get the same
grade (they are not redrawn).

- **`Assets/Shaders/ground_grade.gdshader`** is the material of World.tscn's
  two TileMapLayers, `Ground` and `Deko` (one shared ShaderMaterial; it
  replaces their default fragment, no extra pass). It desaturates toward the
  luma (`saturation` 0.72), pulls the tileset's electric greens toward deep
  moss (`green_target`, `green_pull` 0.45; only pixels whose green leads), keeps
  `contrast` 1.0, then a slight warm lift (black maps to `shadow_lift`
  (0.03, 0.02, 0), white to the cream `highlight_tint` (1, 0.97, 0.9)) times
  `value` 0.85. The look is the third panel of the characters area's
  `grade_variants.png` with more contrast.
- Nothing else is graded: no CanvasModulate (it would dim the rigs and the
  HUD too).
- Both tile layers draw with **nearest** filtering (`texture_filter` 1):
  crisp texels and no atlas bleed at the tile seams (the project default,
  linear, blurred them and drew faint grid lines). The camera keeps its
  integer default zoom (2) for pixel-perfect tiles; the rigs and their
  shadows stay LINEAR_WITH_MIPMAPS.
- Every rig stands on an ink contact shadow (see Character Rigs above).
- **Checks**: `test/test_ground_style.gd` (the two layers share the grade and
  draw nearest, no CanvasModulate, nothing else graded, the shader's defaults
  are the spec, and a CPU copy of its maths makes the dirt and the grass
  darker and calmer while they stay brown and green, far apart in hue).

### Fog of War System

- **Grid**: 32 px cells (2 x 2 of the 16 px ground tiles), 235 x 188 of them
  over the match's 7520 x 6016 world (`world.gd` asks for 7500 x 6000,
  snapped up to whole tiles; `FogOfWarSystem.tile_size`, an R8 exploration
  image, one texture update per frame when something changed)
- **Reveal Radius**: the played side's vision: heroes 200-300 px
  (`HeroStats.vision_radius`: River 300, Vlad 250, Ted 220, Irelia 200), the
  monster 350 px when the player is the monster
- **Monster side**: the AI heroes keep their VisionArea as their exploration
  memory, but `World._ready` switches its `reveals_display` off before any
  VisionArea has processed a frame, so not even their first reveal shows
  their spawn on the monster player's map. The monster gets its own
  VisionArea once it stands at its match spawn
- **Persistence**: Once revealed, stays visible
- **Rendering**: World-space Node2D (not screen-space): a static
  world-covering quad in the palette's `bg_void` at 85 % (`fog_alpha`);
  outside the map is always fogged. The minimap shows the same exploration
  texture. `FogOfWarSystem.is_revealed(pos)` answers for the player's fog
  (the HUD asks it; `is_tile_explored` is the hero AI's memory)
- **Where the ground ends**: the tile map is not a rectangle (a third of its
  bounding box has no ground tile, and the fog world is larger still). A
  revealed spot without ground shows the clear colour, which is `bg_void`
  too (`rendering/environment/defaults/default_clear_color` in
  `project.godot`; `test_world_palette.gd` keeps it in step with the
  palette), not the engine's grey. The Deko layer's flowers, plants and
  rocks all stand on a Ground tile (`test_ground_style.gd`); its grass
  patches and structures may cover cells the Ground layer leaves empty
- **Purpose**: Strategic scouting value, monster can hide

### Match HUD (MatchHud)

`Scenes/UI/Hud/MatchHud.tscn` (`MatchHud`, CanvasLayer 5) is the in-match HUD
of both sides, a `MainCam` child (`MainCam.hud`, wired in `MainCam.tscn`). It
replaced HeroContainer / HeroPanel and the FPS label (F3 keeps the frame
timings). Presentation only: it reads the entities and GameManager and never
writes gameplay state, so `tools/sim_trace.sh` stays byte-identical.

- **Top bar** (80 px), refreshed at 4 Hz, each label written only when it
  changes:
    - Pause (`ButtonRound`, `process_mode` ALWAYS): opens the pause menu while
      a match runs; the icon swaps to play while it is up. Escape and the
      Android back button (`ui_cancel`) open it too.
    - The pause menu (`Hud/PauseMenu.tscn`, `pause_menu.gd`, a Root child,
      `process_mode` ALWAYS): a `PanelLeafy` card over the `bg_void` scrim; it
      pauses the tree while it is up. RESUME (or back again) unpauses;
      SETTINGS opens the settings sheet over it (back closes the sheet
      first); QUIT TO LOBBY arms on the first tap ("Leaving ends the hunt.
      It pays no rewards.", 3 s) and on the second goes to MenuRoot
      (`lobby_scene_path`; World's exit stops the clock), tracked as
      `match_quit`. Its `opened` / `resumed` swap the Pause icon (wired in
      MatchHud.tscn).
    - The first match plays the tutorial's HUD chapter 1.5 s after the HUD
      binds (TutorialOverlay `CHAPTER_HUD`, setting `tutorial_hud_seen`): the
      cooldown slots, then the pause button. It never pauses the match, so a
      headless sim plays the same match with or without it.
    - Clock chip: `GameManager.get_match_elapsed()` as "03:42".
    - Enemy tracker: heroes side, the monster's head, "STAGE II" and its HP;
      monster side, a head and mini HP bar per hero (the scene's `HeroChip`
      template, duplicated per hero), greyed when the hero falls.
    - Kills chip (`ui_skull`): the played side's mob kills
      (`GameManager.played_side_kills()`, the number the rewards pay and the
      match result shows), not every mob death.
    - Follow (`ui_follow`): `follow_requested` → `MainCam.recenter()` (leaves
      the debug fly-cam, centres on the followed entity).
- **Minimap**: the match's `Minimap` lives in the HUD's copper frame
  (`Root/MinimapFrame/MinimapSlot`, 156x124, its own HudPanel frame off via
  `show_frame`). A tap emits `Minimap.hero_picked`, wired to
  `MatchHud.select_hero` in the scene. Its colours are palette tokens
  (exports, resolved in `_ready`): hero dots `hero`, pet dots `hero_light`
  at 0.8, the monster `monster`, the camera frame `text` at 0.55, and the
  fog map (`minimap_fog.gdshader`, on a material local to the minimap)
  `moss` for explored ground over `bg_void` fog, both at 0.95.
    - The fog map is `%FogView`, a TextureRect that scales the exploration
      texture (one texel per fog tile) to its rect, so it always shows the
      whole world. `Minimap.map_rect()` is that rect (2 px inside the
      Control); `world_to_map` / `map_to_world`, the dots, the camera frame
      and the tap all map through it, so a dot sits on the fog tile its
      entity stands on.
    - The Control itself draws the dots and the camera frame. `%Frame` and
      `%FogView` are its children with `show_behind_parent` on (set in
      `Minimap.tscn`), so they draw under the dots.
    - Fairness: the heroes side sees the monster's dot only while it is
      inside a hero's vision radius, the monster side a hero's dot only
      inside the monster's.
- **In-world bars and badges** (every entity's `Hud` group, counter-scaled
  so it keeps its pixel size): the HP bar is an `HpBar2D` whose colours are
  palette tokens: a `panel_inset` trough at 0.85, an `ink` outline at 0.8 and
  the fill `heal` on the hero side (heroes, the fox) and `danger` on mobs and
  the monster (`fill_token`, set on `mobs_base_class.tscn` and
  `monster_base_class.tscn`). Heroes and the monster show their level (the
  monster: its stage) right of the bar on the HUD's level pill: `%LevelBadge`
  (a Panel, theme variation `Pill`, 22x18, ignoring taps) around `%LVLabel`
  (`PillText` at 12 px); mobs carry none. The world fog
  (`FogOfWarSystem.fog_token`) is `bg_void` at 0.85.
  `test/test_world_palette.gd` checks all three.
- **Heroes side: `HeroHudCard`** (172x146, one per HeroBase in the "Hero"
  group, tree order):
    - the head portrait: `CharacterDef.head_texture()` (the def's
      `head_region` of its portrait SVG as an AtlasTexture) in a ring of the
      hero's signature colour, the in-round level on a pill that pops
      (1.4 → 1, TRANS_BACK) on each level-up;
    - name, HP bar and in-round XP bar. The HP fill is the theme's
      `HpBarHero` above 50 %, amber down to 25 % and danger below; the two
      extra fills are built once per card;
    - the passive, active (50 px) and ultimate (54 px) AbilitySlots; active
      and ultimate are bound to a `CooldownSource.Hero`;
    - a 28 px weapon badge (`%Weapon`, an AbilitySlot with the basic frame
      and no countdown) on the portrait's lower right corner, only for a
      hero whose basic attack changes with its state
      (`AbilityBase.has_display_modes()`: River's rifle or heal staff). The
      card follows the basic attack's display icon every frame, without a
      cooldown sweep;
    - the selected card lifts 8 px and wears `HudPanelSelected`; a fallen
      hero's card greys out (`UiPalette.FALLEN_MODULATE`) under the skull
      and its slots go dead (`AbilitySlot.set_dead()`: no countdown, no
      sweep, no glow).
- **Hero focus**: a card press, the 1-4 keys, Tab, a tap on a hero in the
  world or on the minimap all go through `select_hero` / `cycle_to_next_hero`,
  which keep the lifted card in sync and emit `hero_selected` →
  `MainCam.switch_to_hero` (wired in `MainCam.tscn`). A dead hero cannot take
  the focus; when the followed hero dies the focus moves to the next living
  hero (`EventBus.entity_died`), so the camera does not stay at the death spot.
- **Monster side: `MonsterHudPanel`** (700x178), polled at 10 Hz:
    - the head portrait in the monster's signature ring and the stage pips
      I / II / III (`PillReady` once reached);
    - the name, "STAGE II · DANGEROUS" (the README stage names) and the AI
      intent pill: FARMING (moss), AMBUSH (amber), HUNTING (danger), RETREAT
      (xp blue). `MonsterHudPanel.intent_of()` reads the strategy, the rest
      state and the state chart: resting or RETREAT retreats, a monster in
      Approach / Fight against a hero hunts, otherwise the strategy names it;
    - the HP bar ("1008 / 1400") and the EVOLVE bar (XP towards
      `MonsterBase.get_evolution_threshold()`, hidden at Stage III);
    - the passive (56 px; every monster scene has a passive resource:
      Grount's Evolution) and ability_1..3 (68, 68 and 72 px) bound to a
      `CooldownSource.Monster`: Ground Slam shows its padlock and "II" until
      Stage II. The row fills the width between the portrait and the tally;
    - a tally from `EventBus.entity_died`: heroes slain of the starting count,
      and the mobs this monster killed.
- **Event toasts** (both sides): `MatchHud.show_toast(text, queued = true)`
  drops the crimson `BannerMonster` ribbon (`BannerTitle` text) at y 250,
  centred (`Root/ToastBar`): it pops in 0.7 → 1 (TRANS_BACK, 0.3 s) while
  fading in, holds 2.2 s and fades out in 0.3 s. At most one toast is
  visible; the others wait in line (up to 3, a full line drops its oldest), a
  text already showing or waiting is not added twice, and `queued` false drops
  the toast when another one is up. The scene's `Announcer`
  (`MatchAnnouncer`, `Scenes/UI/Hud/match_announcer.gd`) feeds it:
  `announced` → `show_toast` is a connection in `MatchHud.tscn`. EventBus is
  an autoload and cannot be the source of a scene connection, so the
  Announcer subscribes in `_ready` and re-emits:
    - `monster_evolved`: "GROUNT EVOLVED · STAGE II" (queued);
    - `entity_died` of a HeroBase: "VLAD HAS FALLEN" (queued; mobs, the
      monster and Ted's pet are no news);
    - `ability_cast` of an ultimate: the caster and the ability,
      "VLAD · BLOOD BOMB", not queued. Only a cast the player can know about
      (`MatchAnnouncer.player_sees`): every cast of the played side
      (`is_played_side`), and an enemy's only while the camera shows the
      caster (`GameCamera.get_viewport_rect_in_world`) on ground the player's
      fog has cleared (`FogOfWarSystem.is_revealed`). So a monster in the fog
      or heroes far from the monster player never give themselves away. The
      same caster's ultimate shows at most once per `ultimate_repeat_guard`
      (60 s of match time: heroes cast theirs on cooldown, Trap Cage every
      5 s; at 12 s one match showed 51 toasts). A cast that is not seen
      starts no guard; one dropped because another toast is up does.
  Names are the roster's `CharacterDef` display names, upper-cased; each kind
  has an `announce_*` export.
- Strings go through `Assets/Locale/strings.csv` (EN/DE), the toast lines too
  ("%s EVOLVED · STAGE %s", "%s HAS FALLEN"; the toast label does not
  auto-translate the finished line again).
- `test/test_match_hud.gd` (cards, focus across deaths, a fallen hero's dead
  slots, HP bands, pause and follow wiring, the monster panel with its slot
  row and tracker, the intent mapping), `test/test_match_toasts.gd` (toast
  texts in EN/DE, the queue, the scene-wired Announcer through an evolution,
  a hero's fall and ultimates, which ultimates the player sees on either
  side, the level badge pop), `test/test_hud_fog.gd` (the minimap in its
  frame, both sides; the heroes never clear the monster player's fog) and
  `test/test_minimap.gd` (the mapping through `map_rect()`, the fairness
  rules, the dots above the picture, the picture covering the whole world,
  and a rendered pixel check of a hero's dot and of reveals that the headless
  runner skips: run that file in a window to use it).

### HUD Cooldown Slots (CooldownSource, AbilitySlot)

The in-match ability icons of the Phase 4 HUD. A slot shows the real cooldown
of its entity and keeps no timer of its own (the old per-cast HUD timers
drifted from the real cooldown under attack-speed boosts and pauses).

- **`CooldownSource`** (`Scripts/UI/cooldown_source.gd`, RefCounted): a
  read-only view of one entity's slots in the HUD's left-to-right order. It
  never writes game state.
    - `CooldownSource.Hero.new(ability_system)`: basic attack, active,
      ultimate, passive; reads `AbilitySystem.get_cooldown_progress` and its
      `cooldowns`.
    - `CooldownSource.Monster.new(monster)`: `ability_1..3` (framed as basic,
      active and ultimate) and the passive; reads
      `MonsterBase.get_cooldown_progress(name)`, which divides the remaining
      cooldown by `_cooldown_totals` (the cooldown each slot was cast with;
      only `_cast` writes it and gameplay never reads it).
    - `slot_type`, `ability`, `icon` (`get_display_icon(caster)`, so River's
      basic-attack slot follows her weapon mode), `progress` (0 just cast,
      1 ready), `remaining`, `locked` and `lock_hint`: an ability below its
      `unlock_stage` is locked with that stage's numeral (Ground Slam: "II").
    - `debug_state(slot)`: the same readings as F3 text ("left 2.31 s",
      "ready", "locked II"; nothing for a passive). The F3 overlay prints
      one line per ability of each monster and of the followed hero, in slot
      order: `AbilityBase.debug_line()` and that state ("Blood Bomb  cd
      20.00 s  left 11.42 s", "Ram Dash  cd 12.00 s  ready"), so a slot's
      number can be checked against the real timer.
- **`AbilitySlot.tscn`** (`Scenes/UI/Hud/`, `AbilitySlot`): 72x72, scales
  freely; everything sits under `Body`, the part that pops (a container
  resets its children's scale when it sorts them).
    - The ability icon on 60/72 of the slot under the slot's own copy of
      `ability_cooldown.gdshader` (duplicated once in `_ready`): the cooling
      sector, clockwise from 12 o'clock, desaturated and veiled, with an
      amber edge on the sweep line.
    - The kit frame of its `slot_type` over the icon (`slot_basic`,
      `slot_active`, `slot_ult`, `slot_passive`; exports wired in the scene).
    - `CooldownNumber`: the seconds left, rounded up: whole seconds above
      1 s, tenths below ("3", "2", "1.0", "0.4"); `show_countdown` turns it
      off.
    - Becoming ready: `ready_flash` 1 → 0 over 0.25 s, a 1.18 scale pop and
      `became_ready(slot)`. A slot that starts ready does not pop; unlocking
      into a ready ability does. An ultimate wears the `ready_glow.gdshader`
      halo while it is ready.
    - `set_locked(true, "II")`: the padlock and the stage numeral, the icon
      greyed (`locked`), no sweep or number, the `slot_locked` frame.
    - `set_dead()`: the owner fell. The icon greyed (the shader's `locked`
      grey) under its own frame, no sweep, no number, no glow, a pop in
      flight cut; the slot stops polling and ignores every later call. A
      bound slot goes dead by itself when its source's entity is freed
      (before, it stopped polling and kept its last countdown);
      `HeroHudCard` calls it on all its slots when the card goes dead, and
      `MonsterHudPanel` when its monster is gone.
    - Fed by `bind(source, slot)` (polled every frame; callable before the
      slot enters the tree) or by a card calling
      `set_cooldown(progress, remaining)` / `set_locked()` / `set_dead()`.
      The shader parameter is written only when the progress moved by 0.002
      (and always when it reaches 1.0), the label only when the shown number
      changes.
- `test/test_cooldown_source.gd` (both sources against a real Grount and Vlad,
  read-only; the F3 texts and the overlay's lines) and
  `test/test_ability_slot.gd` (no shader or label write while the value is
  unchanged, the number format, one pop per ready transition, the lock state
  and frames, the dead state, River's icon swap, Ground Slam unlocking on
  evolution, a freed hero's slot clearing its countdown). `tools/preview/SlotStrip.tscn` renders the slots on HudPanels
  from scripted sources: sweeps, a lock, an ultimate coming ready, River's
  swap, Grount evolving.

### Combat Visuals (VfxManager)

`VfxManager` (`Scripts/Vfx/vfx_manager.gd`) is the match's hit feedback: a
`Vfx` node of `World.tscn` in group `vfx` (not an autoload, so it lives and
dies with the match; `camera` wired to `MainCam` scene-side). Its hooks are
`EventBus.damage_applied`, `EventBus.ability_event` (the heal numbers) and
`EventBus.monster_evolved` (the evolution shake), connected in `_ready` (an
autoload cannot be the source of a scene `[connection]`). What makes each
ability recognisable is AbilityVfx's (see Ability Effects below); it asks
this node for the ground telegraphs. For every packet that lands in the
camera view (grown by 64 px):

- **Impact**: an outlined cartoon star (`fx_star.svg`, gold; red on the
  player's side; bigger for a big hit) with two sparks, for 0.22 s at the
  body's centre, never over the head.
- **Damage number**: hand-lettered glyphs from `fx_digits.svg` (white with
  the ink outline; gold and larger from `big_hit` = 30; red when the
  player's side takes it), drawn at a fixed on-screen size (22 / 30 px) at
  any zoom. It starts just above the target's HP bar, pops, floats up 18 px
  and fades over 0.8 s. Hits on one target within 0.15 s add up in one
  number; a target shows at most 3 numbers (side by side: centre, right,
  left), and a hit past that adds up in its youngest.
- **Heal number**: a heal an ability reports (`FxEvents.HEAL_SHOT`,
  `CHAIN_HEAL`, `KIT_PICKED`, `RAMPAGE`: River's staff, Chain Heal, the
  supply drop, Grount's Rampage) shows as "+N" (the glyph sheet's "+" cell, then the digits) in the
  palette's `heal` green, the HP actually healed (a heal on a full bar shows
  nothing). Heals add up with heals only, in their own number beside the
  damage numbers (`show_heal`, `heals_on`).
- **Kill**: on a killing blow, 4 puffs (`fx_puff.svg`) and a star.
- **Hit flash**: the CharacterRig's hurt reaction rendered white by the
  shared hit flash shader (see Character Rigs). VfxManager does not flash.
- **Screen shake**: camera trauma (`GameCamera.add_trauma`): 0.6 when the
  monster goes down, 0.45 when it evolves (in view or not: the alert),
  0.35 for a hero, 0.12 for a big hit on a hero or the monster, plus a
  recipe's own `trauma` (a slam, a stomp, a blood bomb). Trauma is capped at 0.8, decays 1.8/s, and the offset is
  9 px x trauma², so only big moments move the view. Settings → Display →
  "Screen shake" (`screen_shake`, on by default) and the camera's
  `shake_enabled` export gate it; the offset uses the camera's private RNG.
- **Ground telegraphs**: where an ability lands, in the recipe's accent at
  35% alpha (`TELEGRAPH_ALPHA`), lines 2 px wide at any size
  (`telegraph_width`), from a pool of 4 slots (`TELEGRAPH_CAP`), each a
  pooled pair of `RingPulse` lines that a slot reshapes:
  `telegraph(pos, radius, windup, color)`, a circle: an outline at the
  radius and a ring growing from the centre that reaches it as the hit lands
  (Ground Slam and Warcry Stomp over their airtime, Whirlwind);
  `telegraph_cone(apex, angle, spread_deg, reach, windup, color)`, a cone:
  its outline and an arc growing from the apex to the rim (Front Cleave,
  Cleaver Chop, Sonic Screech: they land on the cast, so the cone flashes
  0.22 s); `telegraph_lane(from, to, half_width, windup, color)`, a dash's
  rounded lane at the hit radius and a bar crossing it with the dash (Ram
  Dash, Shadow Swoop and Echo Strike's way back; Trample's 70 px lane reads
  wider than the stock 40). The lines are children of the Vfx node at
  absolute z 0; the node sits right after the ground layers, so they draw on
  the ground under the characters, while its sprites and numbers draw at
  z 50 (above the characters and ability trails, under the fog at 100).
  `telegraph_shapes()` lists the live ones (tests).

Night Swarm's look and the thrown Tusk Axe (until 7.3 a minimal ring and an
axe sprite here) are AbilityVfx programs now (see Ability Effects).

Budget (the anim prototype measured 23 ms frames at p95): fixed pools of 64
sprites (`FxSpriteBuffer`), 32 numbers and 4 telegraphs, where a full pool
recycles its oldest entry; at most 8 hits a frame spawn sprites (the rest still
count in the numbers) and 2 kills a frame spawn puffs; nothing is allocated
per frame. Every random draw uses its private RNG and it never writes gameplay
state, so `tools/sim_trace.sh` stays byte-identical. The F3 overlay shows the
pools against their caps, the hits shown / culled / over budget and the
node's script time.

`RingPulse.spawn` (one-shot rings: the monster's stage evolution ring, in the
palette's gold, amber at Stage 2 and danger at Stage 3) grows the ring at a
constant 3 px line and frees it once its tweens end. Until 7.2 the free ran
on the tween's first step, so the evolution, Irelia taunt and supply-drop
rings were never drawn.

### Ability Effects (AbilityVfx, AbilityFxRecipe)

Every hero and monster ability's look is data: `AbilityBase.fx`, an
`AbilityFxRecipe` (`Scripts/Vfx/ability_fx_recipe.gd`; the recipes are
`Assets/Vfx/recipes/fx_<character>_<ability>.tres`). A recipe names the
program (`cue`), its colours as UiPalette tokens (`accent`, `shade`, `core`,
`alt`: the second look, River's heal staff, a rally mark, a mine's arming
ring, stun stars), `size`, `radius` (0 = the ability's own), the camera
`trauma` of its biggest moment, the life of its ground decal and `prop_part`
(a part of the caster's rig body the program hides while the ability has it
away from the hand: Gorrak's axe). It is presentation only: gameplay never
reads it, every copy of an ability shares it and nothing writes it at
runtime. The rig move a cast plays stays the ability's `move_name`. A
monster's passive carries the recipe of its capstone moments (Rampage,
Vampiric Rebirth, Unstoppable).

`AbilityVfx` (`Scripts/Vfx/ability_vfx.gd`) plays them: World.tscn's
`Vfx/Abilities` (group `ability_vfx`, `camera` and `ground` wired
scene-side), drawn over the characters at absolute z 45 (under VfxManager's
numbers at 50), with its `FxGroundLayer` child `Ground` at absolute z 0 (after
the ground layers, under the characters) for the ground half: rings, shield
wards, Last Stand halos, cage rings, swarm rings, warband rings, decals and
the back stakes of a cage. `telegraphs` (wired to its parent, the
VfxManager) draws the monster programs' ground telegraphs. Its hooks:
`EventBus.ability_cast` (cast cues), `damage_applied` (hit cues),
`ability_event` (the moments inside an ability, names in `FxEvents`) and
`entity_died` (what rides a fallen character ends). The hero and monster
scripts only emit `EventBus.notify_ability_event(...)` at points they already
reach, after their own state change; no gameplay value, timer or query
changed (the trace is byte-identical).

| Hero | Ability (cue) | Look |
|---|---|---|
| Vlad | Blood Strike (`strike`) | a slash crescent (`fx_slash`) sweeping through the target's body, 0.14 s |
| Vlad | Land Mine (`mine`) | dust at Vlad's feet; `MINE_ARMED`: a small ring at each mine. The mine itself is `fx_mine` with a blinking `fx_lamp` (Mine.tscn's `Blink`), its trigger radius a dashed ring at 35 %. `MINE_EXPLODED`: a 0.14 s amber fireball, a ring out to the blast radius, three dust clouds, three rocks, a scorch crack left for 3 s |
| Vlad | Blood Bomb (`blood_bomb`) | six drops sucked in for 0.12 s, then a crimson blast low on his body (the head stays clear), a ring to `area_of_effect`, four mist puffs rolling out along the ground, flying drops, a splat left for 3 s, trauma 0.25 |
| Irelia | Shield Bash (`strike`) | the slash in her light teal |
| Irelia | Divine Shield (`shield`) | a ring and a glint at Irelia; `SHIELD_UP` per hero: a 0.14 s bubble pop, then a ward ellipse at the feet whose alpha is the shield's strength; `SHIELD_HIT`: it pulses white; `SHIELD_BROKEN`: six shards; `SHIELD_EXPIRED`: it fades. The shielded hero is not tinted (the old blue modulate read purple on the skin; 8.3) |
| Irelia | Monster Taunt (`taunt`) | a copper ring out to the range and a "!" above Irelia; `TAUNTED` per enemy: an anger vein above its head and a dashed tether body to body for the taunt's duration (replaces `TauntLink`); Rallying Taunt: `RALLIED` per hero |
| Irelia | Regeneration (`last_stand`) | `LAST_STAND`: a gold ring, star and sparks, then a halo at her feet for the invulnerable seconds |
| Ted | Claw Swipe (`claw`) | three raking marks over the target's body |
| Ted | Rally Cry (`rally`) | two horn rings at his feet, a "!", sparks; `RALLIED` per pet and per War Cry hero: a small amber ring and rising sparks (replaces the orange and amber flashes) |
| Ted | Trap Cage (`cage`) | `CAGE_CLOSED`: 10-28 wood stakes spring up around the rim one after another (the back half on the ground, the front half over the characters), a trampled ring, six dust clouds; `CAGE_OPENED`: they sink. A trapped enemy's drawn body (`visual_root()`: its rig) pulses toward the palette's `ted` and back (RGB only, so a fade's alpha keeps running; it used to tint the hidden facing Sprite2D) |
| River | Adaptive Weapon (`sniper`) | rifle: an ink-rimmed gold tracer body to body and a muzzle star; staff, `HEAL_SHOT`: three pluses hop to the ally, two rise off it; Chain Heal, `CHAIN_HEAL`: a curved heal beam to the chained hero |
| River | Weapon Swap (`weapon_swap`) | a twinkle and a small ring in the colour of the weapon she now holds |
| River | Supply Drop (`supply_drop`) | the kit is `fx_crate` under a leaf `fx_chute` (MediKit.tscn's `Drop` animation: the chute sways down and drifts off after landing), its pickup radius a dashed ring at 35 %; `KIT_LANDED`: dust, a ring, three leaves; `KIT_PICKED`: pluses and a ring on the healed hero |

| Monster | Ability (cue) | Look |
|---|---|---|
| Grount | Front Cleave (`cleave`) | a cone telegraph (0.22 s) at the cone's live angle and reach (Titan Form's reach included), a big slash crescent through it at body height (0.14 s, `grount_light`), two dust clouds at its far edge |
| Grount | Ram Dash (`ram_dash`) | `DASH_STARTED`: a lane telegraph to the end point at the hit radius (Trample: 70 px), its bar crossing with the dash; a trail follows him while `is_dashing`: a dust cloud every 44 px (at the lane's edges, side to side, under Trample) and two speed lines at body height; `DASH_ENDED`: a skid cloud and trauma 0.15. At most 6 dust clouds a cast |
| Grount | Ground Slam (`slam`) | `SLAM_LEAP`: the landing circle telegraph fills over the airtime, dust at take-off; `SLAM_LANDED`: a crack left 3.5 s, a 3 px shockwave ring to the radius and a darker one after it, four dust clouds, four rocks, a 0.14 s star, trauma 0.35 |
| Grount | Evolution (`rampage`) | Rampage, `RAMPAGE` (a hero kill): a danger ring and a darker one at his feet, an anger vein above his head, four amber sparks rising (the cooldowns back), a star, trauma 0.2, and VfxManager's "+N" for the HP healed |
| Nyxa | Sonic Screech (`screech`) | a cone telegraph and three ink-rimmed sound arcs (at most 3 px) rolling out of her body through the cone, staggered 0.07 s, 0.3 s each |
| Nyxa | Shadow Swoop (`swoop`) | `DASH_STARTED`: the lane telegraph; a tapered violet streak (the last 10 path points) follows her and fades 0.22 s after the swoop, and a bat peels off it every 60 px (at most 4 a pass); Echo Strike, `DASH_TURNED`: a lane telegraph back, a small ring and two bats at the turn |
| Nyxa | Night Swarm (`swarm`) | 8 bats (`fx_bat`, tinted `monster2`, flapping) circle her body inside the swarm's radius, each on its own phase, speed and radius share from the private RNG, all diving to 60% of the radius on every bite (one every `tick_interval`); a faint ring at the radius on the ground; they fade in and out over 0.25 s and follow her. Brood Mother (a swarm that never ends): 12 bats. It only READS the ability (`is_active`, `is_permanent`, `area_of_effect`, `tick_interval`) |
| Nyxa | Blood Drinker (`rebirth`) | Vampiric Rebirth, `SCATTERED`: six bats burst off her body and three shade puffs where it was, a ring (her body fades to 30 % as before); `REFORMED`: six bats fly from where the bats were to her body at the re-form point (covering the jump when she re-forms 400 px away), a violet streak bows along the jump, then a ring, a star and three puffs as they arrive |
| Gorrak | Cleaver Chop (`cleave`) | as Front Cleave in `monster3_light`, a little bigger; Whirlwind (a 360° chop from Stage 3): a circle telegraph, four slashes spinning all around, a ring at the reach and three dust clouds at the rim |
| Gorrak | Tusk Axe (`axe`) | the spinning `fx_axe` (44 px, `axe_size`, 2.5 turns a second, clockwise thrown to the right, two fading ghosts at its last angles) at the ability's `axe_position` while it flies; his rig's `axe` part (the recipe's `prop_part`) hides meanwhile and shows again with a catch spark once the axe is back. It only READS the ability (`is_flying`, `axe_position`, `direction`) |
| Gorrak | Warcry Stomp (`stomp`) | `SLAM_LEAP`: the circle telegraph over the hop and a "!" over his head (the war cry); `SLAM_LANDED`: a double ring to the stun radius, a small crack, three dust clouds, two rocks, trauma 0.3. Call of the Herd, `RECRUITED` per recruit: a "!" over it and a ring at its feet while it fights in the warband (on top of its `monster3_light` tint) |
| Gorrak | Bristled Hide (`unstoppable`) | Unstoppable, `CC_SHRUGGED` (Irelia's Monster Taunt within range, or a Trap Cage, skips him): five shards burst off his body, a ring at his feet, a star |
| all | stuns | `STUNNED` (Stunning Charge, Disorienting Dive, Concussive Axe, Warcry Stomp): three stars in the recipe's `alt` (gold) circle above the stunned head while the stun lasts (they end when it is cleared, as Guardian Angel does) |

Monster event moments (`FxEvents`): `DASH_STARTED` / `DASH_TURNED` /
`DASH_ENDED` (BullRamDash's `execute` and `_dash_update`), `SLAM_LEAP` /
`SLAM_LANDED` (BullGroundSlam, after the damage), `STUNNED` (after every
`apply_stun` of Ram Dash, the Tusk Axe and the slam), `RECRUITED`
(`_recruit_mobs`), `RAMPAGE`, `SCATTERED`, `REFORMED` (MonsterBase: the
Rampage heal, the Scattered state's entry and exit) and `CC_SHRUGGED`
(IreliaUltimateTaunt and TrapCage when they skip an Unstoppable monster).

Toning-down rules (the anim prototype's previews were too busy), enforced by
`test_ability_vfx`: rings at most 3 world px wide (ink included) and on the
ground; at most 6 puffs or dust clouds per cast or event; nothing covers a
character's head longer than 0.15 s (slashes, claws, stars, bubbles and
blasts over a body live 0.14 s, lasting marks float above the head, wards
and halos ring the feet); areas shown for a while (a mine's trigger, a
pickup radius) at 35 % alpha. No hero strikes with a `BasicStrike` trail any
more (the recipes draw the hit); the trail stays a `.tres` option.

Budget: fixed pools (96 overlay sprites, 24 decals, 16 marks, 64 + 64
stakes, 40 primitives, 6 tethers, 6 wards, 4 halos, 4 cage rings, 2 dash
trails, 2 swarms, 2 axes, 8 stun stars, 8 warband rings); a full pool
recycles its oldest entry, and lasting effects (marks, stakes, trails,
swarms, axes, stuns, warband rings) have pools of their own so a burst never
recycles them. One-shot programs outside the camera view (grown by 96 px)
are skipped; lasting ones start anyway and draw only in view. Every random
draw uses its private RNG and it only READS gameplay (abilities, shields,
cages, dashes, swarms, axes, stuns, warbands; its one write is
presentation, the rig part a recipe's `prop_part` hides), so
`tools/sim_trace.sh` stays byte-identical, also with every rig awake. The
F3 overlay adds "Ability FX" (programs played and culled, the pools, script
time). `tools/preview/AbilityFxStage.tscn` (`-- hero=vlad|irelia|ted|river`
or `-- monster=grount|nyxa|gorrak`) stages one character's abilities on a
timeline for muted renders; the monster combo turns its capstones on on the
monster's own copies (Trample, Echo Strike with Disorienting Dive, Brood
Mother, Concussive Axe, Call of the Herd, Whirlwind, Unstoppable) and
triggers Rampage and the rebirth by hand; `-- mobs` stages a Bat, two Hogs
and Ted's fox swinging at Vlad and Ted.

| Who | Swing (cue) | Look |
|---|---|---|
| Bat, Ted's fox | bite (`bite`, `fx_generic_bite`) | two jaws (`fx_bite`, one sprite turned over for the lower, fangs interlocking) start 0.3 of their 22 px width above and below the target's body and snap together (speed and drag 9/s), tilted toward the biter's side (at most 0.5 rad), tinted `text`, gone after 0.14 s |
| Hog | claw (`claw`, `fx_generic_claw`) | the three raking marks of Ted's Claw Swipe at 0.8 size, tinted `danger` |

The swings that carry no ability (a mob's basic swing, `MobBase.announce_cast(null)`,
and Ted's fox's bite) have no `AbilityBase.fx`: their recipe is the swinging
character's `CharacterRig.swing_fx`. On `damage_applied` with no ability,
AbilityVfx plays it over the target only while that rig `plays_moves()`: on
screen and inside the rig budget (48 awake rigs), the same rule that plays the
attack move. Off screen or over the budget nothing is drawn or counted, and
VfxManager's impact star and number show either way. The F3 "Ability FX" line
counts them as `swings`.

Planned: evolution transformation effects, death animations.

---

## 🧠 AI Behavior Systems

### Hero Exploration AI

**Current System** (Boids-based Group Movement):

- **Separation**: Maintain 80px personal space
- **Cohesion**: Stay within 200px of group
- **Alignment**: Match team velocity
- **Formation**: Diamond pattern, 100px spread, assigned by `HeroStats.formation_rank` — the tank
  (Irelia) leads and paces the group, melee flank, the healer trails; slots turn with the direction
  of travel, and the next hero takes the lead if the leader dies
- **Goal Selection**: Target unexplored fog areas
- **Memory**: Remember last 5 explored positions (avoid backtracking)
- **Stuck Detection**: Auto-unstuck after 5s stationary

**Planned Improvements**:

- Threat assessment (flee from Stage 3 monster)
- Strategic camping (guard choke points)
- Split exploration (2+2 teams)
- Priority targeting (focus fire on monster)

### Monster AI

**Current System** (strategy layer on top of the state chart; every number lives in
`Scenes/NPCs/Monster/Grount/grount_strategy.tres`, a `MonsterStrategy` resource):

- **Spawn**: a random reachable point of Zone 3 (x 3500–5500) at match start
  (`world.gd monster_spawn_zone`; isolated nav islands are rejected)
- **Farm** (Stage 1): avoids heroes (moves away from any hero within 400 px, fights back only when
  cornered within 70 px), paths to the camp with the most mobs and no hero within 500 px; only
  camps whose mobs it can beat at its stage (`farm_max_mob_health`: Bats at Stage 1, Hogs from
  Stage 2); camps activate around the monster too
- **Rest**: below 45% HP it stops taking mob fights, keeps 450 px from camps and regenerates
  0.6% max HP/s after 4 s without damage, until 80% HP
- **Retreat**: Stage ≤ 2, below 30% HP with 2+ heroes close → flee, escape-dash a hero that closes in
- **Ambush** (Stage 2): engages only a hero with at most one ally within 300 px, or one below 30% HP
- **Hunt** (Stage 3): seeks the nearest hero anywhere on the map
- **Combos**: one cast per 0.25 s lock; Ram Dash as a gap closer only when Front Cleave is ready on
  landing; Ground Slam only when it hits 2+ targets; dashes and slam leaps stop at walls
- Irelia's taunt overrides all of the above
- **Nyxa** (`Scenes/NPCs/Monster/Nyxa/nyxa_strategy.tres`, the same layer with her numbers):
  aware of heroes within 450 px, cornered within 60; farms Bats only until Stage 3
  (`farm_max_mob_health` 60 / 60 / 1000: farming Hogs at Stage 2 bled her about 1,800 HP);
  rests below 50% HP up to 85% at 0.7%/s; retreats (Stage ≤ 2) below 40% HP with 2+ heroes
  close and swoops away from a hero within 140 px; ambushes (Stage 2) only a hero alone
  within 280 px; Shadow Swoop gap-closes from 120 px when Sonic Screech is ready within
  0.8 s; Night Swarm whenever it bites at least one target around her
- **Gorrak** (`Scenes/NPCs/Monster/Gorrak/gorrak_strategy.tres`): aware of heroes within
  350 px, cornered within 90; farms like Grount (60 / 150 / 1000); rests below 40% HP up to
  75% at 0.8%/s; retreats (Stage ≤ 2) only below 25% HP with 3+ heroes close, and never
  throws the axe as an escape (`escape_with_ability_2` false); throws the Tusk Axe from
  Approach at a hero 110–260 px away whenever it is ready (`dash_cleave_window` 99);
  Warcry Stomp when it hits 2+ targets around him

**Planned Improvements**:

- Scent tracking / strategic retreat / mob command (skill-tree unlocks)

### Combat AI (Both Sides)

**Current**:

- Basic attack when in range (the Fight gate: `min_distance <= distance <=
  attack range`); between swings an entity strafes at its preferred distance
- Heroes use their active at 4 Hz once fighting (River swaps weapons by her
  allies' HP, Irelia shields a hurt ally) and their ultimate by the pre-round
  dials (`MatchConfig`: enemies in reach, panic HP); a hero in a fight calls
  teammates within 500 px
- Monsters: the strategy layer's combos (see Monster AI)
- Targeting: priority, distance, threat (`TeamBlackboard`), low-HP focus;
  Irelia's Shield Bash adds 40 threat, her taunt overrides

**Planned**:

- **Combo System**: Chain abilities (e.g., Irelia taunt → Vlad ult) — monster combos ship (see above)
- **Positioning**: Tanks front, squishies back — ships for exploration (formation); in-fight
  positioning still follows each hero's preferred distance
- **Focus Fire**: heroes weigh low-HP enemies (`low_hp_focus_weight`) — ships
- **Cooldown Management**: Save ults for critical moments

---

## 🛠️ Technical Architecture

### Class Hierarchy

```
EntityBase (abstract base class)
├─ HeroBase
│  ├─ River (Support/Scout)
│  ├─ Vlad (DPS/Berserker)
│  ├─ Ted (DPS/Pet Master)
│  └─ Irelia (Tank/Support)
├─ MobBase
│  ├─ Bat (flying, swarm)
│  └─ Hog (ground, tanky; can join Gorrak's warband)
└─ MonsterBase (every monster is a scene + data, no subclass)
   ├─ Grount (3-stage evolution bull)
   ├─ Nyxa (bat matriarch, flyer)
   └─ Gorrak (boar king, armoured)

TedsPet (CharacterBody2D, not an EntityBase: Ted's fox, on the hero layer)
```

`River`, `Ted` and `Irelia` are HeroBase subclasses that override a few
virtuals (Vlad's scene uses HeroBase as it is); the mobs and the monsters are
scenes that inherit
`mobs_base_class.tscn` / `monster_base_class.tscn` with their own stats and
abilities, and no script of their own.

### Component Systems

#### HeroStatsComponent

**Purpose**: Runtime stat tracking and leveling

```gdscript
- base_stats: HeroStats (resource)
- current_stats: Dictionary (max_health, current_health, move_speed, ...)
- stat_modifiers: Dictionary (the skill trees' additive / multiplicative rows)
- level: int (1..MAX_LEVEL 10), current_xp: float, XP_PER_LEVEL 80

Methods:
- add_xp(amount) / level_up()            # HeroBase.gain_xp feeds add_xp
- add_stat_modifier(stat, value, is_multiplicative) / refill_health()
- get_max_health() / get_move_speed() / get_attack_range() / get_attack_damage()
- get_damage_scale() / get_attack_speed_multiplier()
- get_modifier(stat, multiplicative) / get_damage_taken_multiplier() /
  get_cooldown_multiplier() / get_start_level()   # generic stat keys

Signals: stat_changed, health_changed, leveled_up
```

#### AbilitySystem (4-Slot System)

**Purpose**: Manages hero/monster abilities

```gdscript
Slots:
- passive_ability: AbilityBase (always active)
- active_ability: AbilityBase (moderate cooldown)
- basic_attack: AbilityBase (primary DPS)
- ultimate_ability: AbilityBase (high impact)

Methods:
- use_basic_attack(target) / use_active(target) / use_ultimate(target) -> bool
- is_on_cooldown(type) / get_cooldown_progress(type)   # what the HUD reads
- make_abilities_unique()   # per-entity copies: a shared .tres is never mutated
- get_damage_multiplier() / get_attack_speed_multiplier()
# Active and ultimate cooldowns start x HeroStats cooldown_mult (Battle Drills).

Signal: ability_used(ability)
```

Monsters do not use this node: `MonsterBase` holds `passive_ability` and
`ability_1..3` itself (per-stage tables, `tick_active`, the combo logic; see
"Shared Monster Framework"). The HUD reads both through `CooldownSource`.

#### State Machine (godotstatecharts)

**States**:

- Idle: Wander, retarget
- Approach: Navigate to target
- Fight: In combat, use abilities
- Dead: Cleanup (mobs return to the spawn pool; a `reset` event brings them back to Idle)
- Scattered (monsters only, `monster_base_class.tscn`): Nyxa's Vampiric Rebirth.
  `self_scattered` enters it from any state instead of Dead; untargetable,
  fleeing; its own delayed `ToIdle` transition (3 s) brings her back

The chart owns all state. Its active state is **stepped** by the `TickScheduler` autoload (`StateChart.step()` → `state_stepped`) at a per-entity LOD rate instead of running `state_processing` every frame.

### Resource Architecture

**Separation of Concerns**:

- **HeroStats** (Resource): Immutable base data (max_health, base_damage)
- **HeroStatsComponent** (Node): Mutable runtime (current_health, level)
- **AbilityBase** (Resource): Ability data and execute logic. `icon` is the
  ability's SVG tile; `get_display_icon(caster = null)` is what a HUD slot
  shows (read-only; RiverBasicAttack returns `heal_icon` while River holds the
  heal staff, every other ability its `icon`)

### Shared Monster Framework (MonsterBase, MonsterStats, AbilityBase)

Everything a monster needs beyond Grount's kit lives in the shared classes, so
a new monster is data (a scene, its stats, its ability `.tres`) plus at most
one new ability script. Every default is Grount's old behaviour:
`tools/sim_trace.sh` stays byte-identical with Grount.

- **`MonsterStats`** (per monster `.tres`):
  - Combat: `base_attack_range` (80; attack range = this x the range nodes +
    Titan Form's flat bonus) and `fight_leave_distance` (100; + the same
    bonus). These were MonsterBase constants. The spacing (`combat_role`,
    `preferred_distance` 45, `min_distance` 20) stays on the scene root, set in
    `monster_base_class.tscn` and overridden by a monster scene's own root.
  - Toughness: `damage_taken_mult_per_stage` (index 0 = Stage 1; empty or
    shorter = 1.0) and `get_damage_taken_mult(stage)`. `_receive_damage`
    multiplies every hit by it after the tree's damage-taken nodes, so the
    `damage_applied` listeners see what landed. Gorrak's armour.
- **`AbilityBase`** (every ability, heroes and monsters):
  - `lifesteal_pct` and `deal(caster, target, amount)`: damage through
    `EventBus.deal_damage`, then `caster.heal_self(landed x lifesteal_pct)`.
    Every monster ability and every hero `BasicStrike` hit goes through it.
  - `tick_active(caster, delta)`: MonsterBase calls it for ability_1..3 every
    frame (three direct calls, no per-frame array). For abilities that keep
    acting after the cast (an aura that bites, a thrown axe in flight) without
    timers or tweens. Default: nothing.
  - `get_cast_center(caster, target)`: where the area lands. The combo's
    "slam only when it hits `slam_min_targets`" counts targets around it.
    Default: the target. `BullGroundSlam`: the leap's landing point (the
    target, at most `leap_distance` away; `leap_distance` 0 = in place).
- **`MonsterBase`**: `heal_self(amount)` (lifesteal; capped at max HP, never a
  dead monster), the stats-driven reach and Fight leave distance, the stage's
  damage-taken multiplier, and `_try_escape_dash` honours
  `MonsterStrategy.escape_with_ability_2` (true; false = ability 2 is no
  movement skill, Gorrak's thrown axe, and is never cast away as an escape).
- **Grount's kit as the shared toolkit**: `BullFrontCleave` keeps a tree's
  `cone_angle` modifier on top of each stage's angle (Nyxa "Wide Shriek",
  Gorrak "Wide Arc"); `BullGroundSlam.stun_duration` (0 = off) stuns every
  target the slam hits (Gorrak's Warcry Stomp; his node Ringing Ears adds to it);
  `BullRamDash` already had its stun. All three deal through `deal()`.
- **Passive slot**: every monster scene sets `passive_ability`. Grount's is
  Evolution (`grount_evolution.tres`, a plain PASSIVE `AbilityBase` with the
  kit's evolution icon and the stage rules as its description), Nyxa's is
  Blood Drinker (`nyxa_blood_drinker.tres`: her lifesteal and stage rules),
  Gorrak's Bristled Hide (`gorrak_bristled_hide.tres`: his armour and stage
  rules): the HUD's passive slot and the character screen show it; the
  evolution, the lifesteal and the armour themselves are MonsterBase's,
  `deal()`'s and MonsterStats'.
- **F3** (`MonsterBase.debug_meta_line`): `<name> [<monster id>] S<stage> HP
  ... <build> nodes: ...` (`<build>`: `save` when the player plays the
  monster, else `AI T<threat> <own ranks>+<base ranks>`, its Opponent Threat
  build), then after ` | ` the live state each ability reports
  through `AbilityBase.debug_tag()` ("" = nothing; Night Swarm: `swarm! 2.4 s
  left` / `swarm off`; Tusk Axe: `axe in hand` / `axe! flying out` /
  `axe! flying back`). Grount's abilities report none, so his line ends at
  the nodes.
- Checks: `test/test_monster_framework.gd`, `test/test_nyxa.gd`,
  `test/test_gorrak.gd`.

### Character Roster (Roster, CharacterDef, MonsterSlot)

One registry describes every playable character for the menus, the match, the
sim tools and the save, without instancing a character scene (instancing an
entity registers it and draws from the global RNG).

- **`Scenes/NPCs/roster.tres`** (`Roster`, `Scripts/Roster/roster.gd`) lists
  the heroes (Irelia, Vlad, Ted, River) and the monsters (Grount, Nyxa,
  Gorrak) in menu order, plus `default_monster_id` (`grount`). GameManager preloads it as
  `GameManager.ROSTER`. `find(id)`, `hero_ids()`, `monster_ids()`, and
  `resolve_monster(id)`, which falls back to the default and then to the first
  monster, so a stale save or sim argument never breaks a match.
- **`Assets/Characters/<id>/<id>_def.tres`** (`CharacterDef`) per character:
  - identity: `side` (0 heroes, 1 monster), `scene_path` (a path, so loading
    the roster loads no character scene; `scene()` loads it on first use and
    keeps it for the session), and `stats`, which is the very HeroStats /
    MonsterStats resource the scene uses.
    `character_id()` (`hero_id` / `monster_id`) is the one save key: XP, the
    `hero_<id>` / `monster_<id>` skill tree, analytics and sim results.
  - presentation: `display_name` (empty = the stats' name, `get_display_name()`),
    `role_text` ("Tank · Leader"), `role_filter` (filter key; its icon is
    `Assets/UI/Icons/Roles/role_<key>.svg`, `role_icon()`), `accent_token` (a
    UiPalette token), `tagline`, the rig (`rig_body`, `rig_profile`), the
    `portrait` (DPITexture) and `head_region`, the head crop in portrait units
    (128x160) that `head_texture()` turns into an AtlasTexture for HUD heads.
  - monsters: `stage_names` (Grount: Bullcalf, Rampager, Alpha Bull; Nyxa:
    Duskling, Night Hunter, Dusk Matriarch; Gorrak: Tusker, Warlord, Boar
    King), `opponent_after_matches` (Heroes-side quarry pool: Grount 0, Nyxa
    3, Gorrak 6), `unlock_requires_level` (Nyxa and Gorrak 3), and `tip`, the
    counterplay hint for the heroes.
  - progression: `unlocked_by_default` (false for Nyxa and Gorrak; the bought
    ones join `PersistedData`'s `[monsters] owned`),
    `unlock_cost` (in `currency()`: Steel for heroes, Leaves for monsters;
    Nyxa 2,500, Gorrak 3,000) and
    `skill_tree`, the character's
    `Data/SkillTrees/<side>_<id>.tres` (its id is `skill_tree_id()`).
    MetaSkillManager registers the tree of every roster def at startup, so a
    character's tree is live exactly while its def is in the roster.
  - abilities are never copied: `abilities()` reads the scene's own ability
    `.tres` from its SceneState, in menu order (passive, basic, active,
    ultimate; monsters passive, ability_1..3). Icons, names and descriptions
    come from there. `ability_slots()` keeps the four slots with null for an
    empty one (every shipped character fills all four), so screens caption
    each by its slot.
- **`Scenes/World/monster_slot.gd`** (`MonsterSlot`) stands where World.tscn
  used to instance Grount, as World's last child after `Heros`. It spawns
  `resolve_monster(GameManager.selected_monster_id)` in `_enter_tree`, so the
  monster registers with EntityRegistry and TickScheduler (one global `randf()`)
  at exactly the old point of the enter pass, before `Spawns._ready` shuffles the
  camps. Spawning it from `World._ready` would change every match.
  `test_roster` guards the index and the enter-pass spawn.
- **Selection**: `GameManager.selected_monster_id` is the next match's monster
  (played or hunted); `GameManager.begin_hunt()` sets it for the chosen side
  right before a menu loads World (see Opponent Choice and Monster Unlocks).
  `select_monster(id, persist = true)` sets it directly (the sim tools, with
  persist off); the `selected_monster` setting is the player's own monster
  (`choose_monster(id)`, owned only; `played_monster_id()` reads it back and
  falls back to the default). The lobby's lair, the Monsters roster and the
  pre-round's monster picker follow the player's own monster. The
  `match_ended` analytics event carries `monster`.
- **Tools**: `MONSTER=<id>` or `MONSTER=all` for `tools/sim.sh`, `tools/sim_trace.sh`
  and `tools/bench.sh` (`sim_match.gd` / `bench_match.gd ... monster=<id>`), with a
  per-monster trace baseline in `tools/baselines/`; see Headless Tools below.
  Without it the roster default plays, so the determinism baseline is unchanged.
  The SIM_RESULT JSON carries `monster` and `monster_name`.
- **Adding a monster**: a scene inheriting `monster_base_class.tscn` with its own
  MonsterStats (`monster_id`, reach, Fight leave distance, armour; see Shared
  Monster Framework below), its spacing on the scene root (`preferred_distance`,
  `min_distance`), ability `.tres` (a passive one too, for the HUD's passive
  slot) and strategy; its
  `Assets/Characters/<id>/` rig (`src/` + `tools/build_rigs.sh`); a
  `<id>_def.tres` added to `roster.tres`; its `Data/SkillTrees/monster_<id>.tres`
  linked from the def's `skill_tree`; and its trace baseline, recorded with
  `MONSTER=all RECORD_DIR=tools/baselines tools/sim_trace.sh` (`test_sim_tools`
  fails while a roster monster has none).

### Menu Component Kit (cards, rigs, top bar, nav bar)

The building blocks of the Phase 3 menu screens (lobby, roster, character
detail). They read the roster and the save, never write them (purchases go
through MenuRoot), and take every colour from the theme or `UiPalette`. Signals are wired scene-side; the only
code connections are to autoloads (`PersistedData.currency_changed`).

- **`CharacterProgress`** (`Scripts/Progression/character_progress.gd`, static
  helpers over a `CharacterDef`): `xp`, `progress` / `level` / `xp_into` /
  `xp_needed` on the one XP curve of `PersistedData.level_progress` (levels
  come from XP alone, nothing buys them), `upgrades_ready` (nodes of the
  character's own tree that `MetaSkillManager` reports AVAILABLE: tier open and
  affordable now) and `is_unlocked` (`unlocked_by_default`, or a monster in
  `PersistedData`'s `[monsters] owned`). The unlock rules: `unlock_state`
  (OWNED, NOT_FOR_SALE, GATED, SHORT, READY), `best_owned_level(side)`,
  `unlock_gate_met`, `can_unlock`, the rule in words (`unlock_rule_short`
  "Needs a Lv 3 monster" for cards, `unlock_rule` for the sheet) and
  `unlock(def)`, the purchase (only from READY: spends the price, adds the
  monster to the owned set, saves); the only helper that writes.
- **`CharacterCard.tscn`** (`CharacterCard`, a Button): the collection card.
  Size presets S 150x238 (pickers, the pre-round squad), M 160x262 (the
  4-column grid) and L 280x446 (the quarry card) scale layout and type from
  the M design. Frame `CharacterCard` (heroes), `CharacterCardMonster`,
  `CharacterCardSelected` (`selected`, pickers) or `CharacterCardLocked`; inner
  panel `CardInnerHero` / `CardInnerMonster` / `CardInnerLocked`. The art is the
  live rig (`RigView`) or, with `animated = false` for big grids, the static
  portrait. "Lv.N" (CardLevel) sits on the panel's bottom-left, the name under
  it, then the pill:
    - `PillProgress` "into/needed": XP toward the next level;
    - `PillProgressReady` with the up arrow and N, plus the red notify dot:
      N skill ranks can be bought now;
    - locked: the portrait through `card_locked.gdshader`, the padlock, the name
      "???", no level or pill, and a price chip in the currency's colour when
      `unlock_cost` > 0; while the unlock rule is unmet it reads under the
      padlock ("Needs a Lv 3 monster", `%Rule`), and once the character can be
      bought now the red notify dot shows (`unlock_state`);
    - `rumour`: the one "???" slot each side ends with ("Rumours in the deep
      jungle", no character);
    - `locked_note`: a locked card's own line under the padlock instead of
      its rule, price and dot (the quarry sheet's "Appears after 3 hunts").
  `refresh()` re-reads the save (screens call it on currency or skill
  changes); `apply_progress()` shows given numbers (previews, tests).
  `card_pressed(character)` (null for the rumour card). `play_intro(delay)`:
  the collection's staggered drop-in (the card fades in while its frame grows
  from 0.86; the frame scales, not the card, because a container resets its
  children's scale when it sorts them).
- **`RigView`** (`Scenes/UI/Widgets/rig_view.gd`): a character's `CharacterRig`
  in puppet mode inside a Control (always awake, facing right): the body's
  bounds, raised by a flyer's hover or a walker's bounce, fitted and centred
  with `padding`, feet on the bottom edge, plus the match's contact shadow.
  `stage`, `flip`, `walk_speed`, `play_move()`, `play_hurt()`, `silhouette`
  (multiplied down to `locked_fill`) and `animated = false` (posed once, never
  processed). A hidden view (a menu screen under another one, a filtered-out
  card) sleeps too and wakes when it shows again. Its taps go to the parent.
- **`StageCharacter.tscn`**: a tappable RigView standing on a menu stage with a
  squash-and-bob idle on top of the rig's breathing and `cheer(delay)` (a hop
  with a bounce landing). Period (`bob_period` x 0.85-1.2) and phase come from
  a private RandomNumberGenerator seeded by `hash(name) ^ hash(path)`, so a
  stage looks the same every launch and the global RNG is never touched.
  Locked characters stand as a silhouette under a padlock with their price
  chip and, while unmet, the unlock rule under it (`%LockInfo`).
  `character_pressed(character)`. For the match result: `celebrate(delay)`
  (the cheer hop every 0.7 s until `stop_celebrating()`) and `set_fallen(on)`
  (no idle or cheering, the rig posed still and drained of colour,
  `RigView.greyed`, darkened to `UiPalette.FALLEN_STAGE_MODULATE` (0.62,
  0.58, 0.58: lighter than the UX spec's plain tint, which drained of
  colour read as a locked silhouette), tipped back 12 degrees on its feet
  and squashed to 0.94).
  `RigView.greyed` rebuilds the rig inside a `CanvasGroup` whose material
  (`Assets/Shaders/greyscale_group_material.tres`) desaturates the whole
  body at once (85 %); only a fallen cast pays for that backbuffer.
- **`UnlockSheet.tscn`** (`UnlockSheet`, `unlock_sheet.gd`): the confirm sheet
  of a character purchase, one instance over every MenuRoot screen. `open_for(def)`
  slides it up from the bottom edge (0.22 s, cubic) over a `bg_void` scrim:
  the character as a locked silhouette under the padlock (`CardInnerLocked`),
  "Unlock Nyxa?", the role line and tagline, the rule (`unlock_rule`: what is
  missing in `DangerLabel` with a padlock, or met in `NextLabel` with a check),
  CANCEL (`ButtonCopper`) and UNLOCK (`ButtonMonster`) with the currency icon
  and the price inside it (in `danger` while the wallet is short). UNLOCK is
  disabled unless `unlock_state` is READY and reads "Need 340 more" while the
  wallet is short. It only reports `unlock_confirmed(character)`; CANCEL, a
  tap on the scrim and `ui_cancel` close it. Its wiring is in its scene.
- **`TopBar.tscn`**: a round left button (`left_icon`, `left_pressed`), the
  title, and the `CurrencyChip`s the screen's side shows (`show_gold`,
  `show_steel`, `show_leaves`; `chip(currency)`).
- **`CurrencyChip.tscn`**: currency icon and amount ("1,840",
  `format_amount`), live from `PersistedData.currency_changed`: the amount
  counts to the new value over 0.4 s (down after a purchase, `shown_amount()`)
  and pops; `preview_amount` pins a sample.
- **`NavBar.tscn`**: Heroes | Growth | HUNT | Codex | Monsters. Carved
  `NavPlaque` plaques (`NavTab.tscn`) and the mossy-stone `NavArch`
  (`NavArch.tscn`, the lobby), toggle buttons in one ButtonGroup per bar.
  `active_tab`, `tab_selected(tab_id)`, `notify_tabs` / `set_notify()` (red
  dots) and `monster_side`: the arch's additive glow is `amber` on the hero
  side and `monster` crimson on the monster side, pulsing through the scene's
  AnimationPlayer. Every bar is in the `nav_bar` group (`NavBar.GROUP`, set in
  NavBar.tscn), through which MenuRoot lights the dots.
- **Press feedback** (`PressFeedback`): cards, stage characters, ability tiles
  and nav tabs shrink to 0.95 while held and spring back with a 0.09 s
  TRANS_BACK tween.
- **`StatTile.tscn`**: a stat icon, a value in display type and a caption
  (`PanelInset`; `show_stat(icon, value, caption)`).
- **`RewardChip.tscn`** (`RewardChip`): one match reward, an icon, "+N"
  (`BigNumberLabel`, thousands separated) and a caption in a `PanelInset`;
  `play(delay)` counts from 0 to `amount` over 0.7 s and pops the number;
  `bonus_pct` > 0 shows the Opponent Threat's bonus ("+20%", `AmberLabel`).
- **`XpRow.tscn`** (`XpRow`): one character's permanent XP after a match, the
  head portrait in a ring of its signature colour, the name, "+N XP", an
  `XpBar` that `play(delay)` fills from `total_before` to `total_before + gain`
  over 0.9 s on the level curve, "Lv.N" and the LEVEL UP! pill (`PillReady`)
  popping when the fill crosses a level; `fallen` greys the head under a skull.
- **`AbilityTile.tscn`**: one ability (kind caption, its
  `get_display_icon()` as the HUD shows it, its name), a toggle button; the
  toggled tile wears `CharacterCardSelected` and reports `tile_pressed(index)`.
- **`SkillNodeButton.tscn`**: one skill-tree node in the reference's look
  (gamedesign 1.8): an 84 px `NodeTile` around its 60 px icon (a capstone's
  tile is 92 px and stands in a stone arch drawn behind it), rank pips
  (`PipOn` / `PipOff` / `PipMax`) inside the tile's bottom edge, its name
  under the tile (`NodeName`, 100 px, or up to 150 px when it is alone in its
  cell), the red "+" (`BadgeReady`, pulsing) while its next rank can be
  bought and afforded, a check on the tree's equipped capstone, the white
  `SelectRing` and `pop()` (purchase juice, 1.25 → 1 with TRANS_BACK). The
  tile wears its branch colour (`UiPalette.branch_color`): a dark fill of it
  with a rim in the branch colour once owned, darker while open, gold
  (`rank_max`) once maxed; locked tiles keep NodeTile and dim the icon to
  `UiPalette.LOCKED_ICON_MODULATE`. The arch is branch-dark stone with a gold
  rim once owned. `setup_hidden()` makes the "???" slot of a node the game
  does not have yet (padlock, ignores taps).
- **`SkillTreeView.tscn`**: a `UxTreeModel` as the reference's tree: a
  `BranchPlaque` over each named branch tinted in its colour (darkened 35 %),
  the tier gutter down the left edge (a 52x84 `GutterPlaque` per tier with
  "Lv / 5" on character trees or "pts / 10" on the base trees,
  `GutterPlaqueLocked` with a padlock while closed), one row per tier (two
  nodes sharing a cell sit ±50 px apart; capstones in their arch; a "???"
  slot per hidden node), and bezier vines from each prerequisite to the node
  it opens under the tiles: a 4.5 px core over a 9 px ink casing,
  `moss_light` with a leaf once both ends are owned, `moss` once the parent
  is, `locked_line` before. Branch colours (`UiPalette.branch_color`): heroes
  `vlad` red / `teal` / `hero` amber, monsters `monster` crimson /
  `monster_purple` / `moss`. Without named branches every row is centred;
  rows share the height (118-150 px) and the graph is centred vertically,
  re-laid out on resize. `build(model)` keeps the selection; `select(id)`
  reports `node_selected`; `pop(id)` after a purchase pops the node and fades
  its vines from their old colour to the new one over 0.45 s.
- **`StrategyRow.tscn`** (`StrategyRow`): one pre-round dial in a
  `PanelInset`: icon, name (`Counter`), the value in `AmberLabel` ("50%"), the
  themed HSlider (step 0.05) and the plain words at both ends (`HintLabel`).
  `value_changed(value)` re-emits the slider; setting `value` moves it
  without a report.
- **`ChoiceTile`** (`choice_tile.gd`; `FormationTile.tscn`,
  `InstinctTile.tscn`): one tile of a one-of-N choice, a toggle button whose
  `%Frame` wears `CharacterCard` (copper), `CharacterCardSelected` (amber, with
  an amber title) when picked, or `CharacterCardMonster` (crimson) for a
  `monster` tile. `choice_id`, `title`, `description`, `icon_texture`,
  `glyph_formation`; `chosen(choice_id)` when it becomes the picked one. The
  screen puts the tiles of one choice in a ButtonGroup it makes in code (a
  scene sub-resource would be shared by every screen instance, or copied per
  tile when marked local to scene).
- **`FormationGlyph`** (`formation_glyph.gd`): a formation drawn in `_draw`:
  four dots in the heroes' signature tokens (`dot_tokens`), ink rims and a
  highlight, spaced as `MatchConfig.Formation` spaces the squad (Tight,
  Spread, Line), under an amber heading arrow.
- **`ThreatBox.tscn`** (`ThreatBox`): the Opponent Threat in words in a
  `PanelInset` with the threat icon: "Threat T" (`AmberLabel`) and "+10%
  rewards" per level (`NextLabel`, hidden at 0), the AI side's build at T
  (`MetaSkillManager.side_ai_build`): "AI build: 6 Nyxa ranks + 4 base ranks"
  against the heroes, "AI heroes: 6 ranks each + 4 base ranks" (or per hero,
  "6/5/6/6", when they differ) against the monster, "AI build: no upgrades
  yet" at 0; and a hint: the quarry's counterplay `tip` for the heroes, what
  the threat follows for the monster. `show_for(played_side, monster)`;
  `threat`, `base_ranks`, `character_ranks` for tests.
- `test/test_character_card.gd` covers the progress numbers, the owned set,
  the card states (normal, upgrade-ready, locked-purchasable, a locked
  monster's rule then dot on its way to bought, rumour, monster, selected) with
  their pill text and variations, the size presets, the RigView fit, flip and
  silhouette, the stage idle and cheer, the global RNG left untouched, the nav
  bar's group and notify API, and the chips. `tools/preview/CardGrid.tscn`
  renders the grid and nav (default page) and the L / S cards and stage
  characters (`-- --page=sizes`) from sample numbers, never the save; every
  character there is its roster def.

### Menu Root and Lobby (the main scene)

The game boots into `Scenes/UI/Screens/MenuRoot.tscn` (`application/run/main_scene`),
and the match result's LOBBY returns to it. The old `MainMenu.tscn`,
`PreRoundSetup`, `MetaSkillScreen` and `MatchResult` were deleted in 8.3
(`test_menu_root` checks they stay gone).

- **`MenuRoot`** (`menu_root.gd`): every meta screen is a hidden child of
  `%Screens`, and every screen signal is connected in `MenuRoot.tscn`. The
  script only moves between screens and holds the hooks a scene connection
  cannot reach (autoloads cannot be `[connection]` targets):
    - `push(screen)` slides the new screen in from the right edge over 0.22 s
      (cubic ease-out) while the one below darkens to
      `UiPalette.COVERED_SCREEN_MODULATE` (0.6); `pop()` plays it backwards, and
      once a slide settles only the top screen is visible. `ui_cancel` is back on
      every screen; the home screen (the lobby) never pops.
    - On entry: the tree is unpaused (a match result pauses it), the roster
      the match result's "upgrades ready" asked for
      (`GameManager.request_menu_roster` / `take_menu_roster`, once) slides in
      over the lobby, the menu music plays, `GameManager.request_world_load()` starts loading the match in
      the background (`GameManager.get_world_scene()` collects it), and on the
      first run the tutorial opens after 0.9 s. Every button under the menu,
      including ones a screen or overlay adds later, plays the UI click.
    - The lobby's choice goes to `GameManager.choose_side()`, which persists it
      (setting `chosen_side`); the next launch opens on the same side.
    - Navigation: the plaques and the nav bar's Heroes / Monsters open that
      side's `RosterScreen`, Growth the chosen side's account-wide tree in a
      second `CharacterDetail`, a roster card or a lobby character the
      `CharacterDetail` of that character. Nav-bar destinations go through
      `switch_to(screen)`: the screen slides in and then sits right above the
      lobby (back returns home; tabs do not stack up), or, when it is already
      on the stack, the screens above it slide away (`pop_to`). A character's
      detail is pushed over the screen that asked. A locked character with a
      price (Nyxa and Gorrak until bought) opens the `UnlockSheet` instead.
    - Purchases: a detail's `upgrade_requested(tree_id, node_id)` →
      `MetaSkillManager.rank_up` (the next rank; the shop decides: gates,
      price), and `equip_requested(tree_id, node_id)` →
      `MetaSkillManager.equip_capstone` (free). The sheet's
      `unlock_confirmed(character)` → `CharacterProgress.unlock` (the rule and
      the wallet decide) and `GameManager.choose_monster` (the bought monster
      becomes the player's own), then the sheet closes (or refreshes when the
      purchase did not go through). On `MetaSkillManager.skills_changed`,
      `PersistedData.currency_changed` and `PersistedData.monster_owned`
      (connected in code: autoloads) the lobby, every roster and detail on the
      stack and an open sheet re-read the save, once per frame at most.
    - Red nav dots: on entry, after every such refresh and when the side
      changes, every nav bar under the menu (`NavBar.GROUP`) shows Heroes /
      Monsters while a character of that side has a rank to buy now
      (`CharacterProgress.upgrades_ready`) or can itself be bought
      (`CharacterProgress.can_unlock`), and Growth while the chosen side's
      account tree has one (`MetaSkillManager.card_progress`).
    - HUNT (the lobby's buttons, the nav bar's arch) pushes the chosen side's
      `PreRoundScreen` (`pre_round.open(side)`, once: a second HUNT while it
      is on the stack does nothing) over the screen that asked; its back pops
      it. `start_requested(config)` starts the hunt on
      `config.quarry_id`, `monster_start_requested(monster_id, instinct)`
      makes the monster the player's own (`choose_monster`) and starts; the
      instinct is not applied yet (today's Ambusher behaviour); a second
      start while the match loads does nothing. Every start
      goes through `GameManager.begin_hunt()` first; so does the match
      result's PLAY AGAIN. A locked monster on the pre-round's picker whose
      rule is met asks for its unlock sheet (`character_requested`, the same
      handler as the rosters'); after the purchase the pre-round shows it as
      the picked monster (`PreRoundScreen.refresh()` with the other screens).
    - The nav bar's Codex opens the `CodexScreen` (`switch_to`, after
      `codex.open()`); its Codex dot shows while it has monster pages the
      player has not opened (`CodexScreen.unseen_monsters()`). Its guide's
      `guide_requested(chapter)`: the camp tour pops home and plays the coach
      marks once the slide has settled; the hunt tips are switched on again
      for the next match (`TutorialOverlay.forget`).
    - The lobby's gear opens the `SettingsScreen` sheet; it and the
      first-run tutorial are the overlays (one at a time) over the stack.
    - Back: `application/config/quit_on_go_back` is off, so the Android back
      button arrives as `NOTIFICATION_WM_GO_BACK_REQUEST`. MenuRoot (in a
      match, MatchHud) replays it as one `ui_cancel` press (`BackButton.press`,
      `Scripts/back_button.gd`, through the viewport: the topmost taker wins):
      an open overlay, the unlock sheet or the pre-round's quarry sheet
      closes, else the top screen pops. Only when nothing took it (the bare
      lobby) does MenuRoot quit the game. `go_back()` is that press.
- **`LobbyScreen`** (`lobby_screen.gd`, the nav bar's HUNT tab): a split jungle
  stage under the top bar (gear, Gold, Steel, Leaves) and above the nav bar.
    - Hero stage (y 84-624): the campfire clearing (`Assets/UI/Lobby/lobby_heroes.svg`),
      the "BETTER HUNT" title on a `Banner`, and River, Vlad, Irelia and Ted as
      live `StageCharacter` rigs around the fire, the right pair facing inward.
    - Monster stage (y 616 down to the nav bar): the fanged lair
      (`lobby_monsters.svg`) with Grount large in the middle. Nyxa and Gorrak
      stand beside him as padlocked silhouettes with their price and, while
      unmet, the unlock rule: their roster defs (`nyxa_def.tres`,
      `gorrak_def.tres`, wired scene-side, locked until bought). A tap asks
      for them like any character (MenuRoot opens the unlock sheet);
      `refresh()` re-reads the save after a purchase.
    - Between them the HEROES and MONSTERS plaques, each side's HUNT button
      (`ButtonPrimary` / `ButtonMonster`) and the VS badge (`vs_badge.svg`).
    - Tapping a stage chooses that side in place: the other stage tweens to
      `UiPalette.UNCHOSEN_SIDE_MODULATE` (0.5, 0.47, 0.47) over 0.25 s, the
      chosen one shows its `FrameHero` (amber) or `FrameMonster` (crimson), its
      HUNT button pops in (0.6 → 1, TRANS_BACK 0.35 s), its characters cheer
      with a 0.05 s stagger, and the nav arch glows in the side's colour. With
      the export `side_tap_opens_roster` a stage tap also asks for that side's
      roster. Tapping a character chooses its side and asks for its detail.
    - It only reports: `side_chosen`, `hunt_requested(side)`,
      `roster_requested(side)`, `character_requested(def)`,
      `tab_selected(tab_id)` and `settings_requested`. `show_side()` restores a
      side without the animation. Its own wiring (stages, plaques, HUNT, the
      characters, top bar, nav bar) is all in `LobbyScreen.tscn`.
    - On a taller or wider phone the stages stretch with the window. The
      campfire's backdrop covers its stage. The lair's backdrop and its
      monsters keep their design size anchored to the bottom of the monster
      stage (the backdrop 540 px tall at full width): on a 19.5:9 phone the
      extra height shows the screen background above the lair instead of
      blowing the backdrop up around monsters that keep their size.
- `test/test_menu_root.gd`: every screen signal is connected once, scene-side,
  to MenuRoot (no code connections); push / pop and `ui_cancel`; the click on
  every button; the side choice (frames, HUNT pop, cheer stagger, tints, nav
  glow) and `side_tap_opens_roster`; each request; the cast is the roster plus
  the locked monsters with their prices; the unlock sheet (opened from the
  lair and the roster, back closes it, the purchase, the refresh of lobby,
  roster and dots, its scene-side wiring); the chosen side persists; the first-run tutorial; the
  screens each request opens (HUNT pushes the pre-round of either side once,
  back and `ui_cancel` pop it, nav tabs switch, cards push, back); a purchase
  and a capstone swap through the detail and the refresh of the screens under
  it; the nav dots follow buyable ranks; the main scene is MenuRoot; the
  Codex tab switches to the Codex. `test/test_codex.gd` and
  `test/test_settings_and_back.gd` cover the Codex, the settings, the pause
  menu, the back button and the lair on a tall phone.

### Tutorial, Codex and Settings (first-run flow)

- **First-run flow**: the first launch opens MenuRoot on the lobby; 0.9 s in,
  the tutorial's camp tour plays over it (setting `tutorial_seen`). The first
  match plays its HUD tips (setting `tutorial_hud_seen`). Skipping counts as
  seen. Both can be played again from the Codex's guide.
- **`TutorialOverlay`** (`Scenes/UI/Tutorial/`, a CanvasLayer at layer 20,
  `process_mode` ALWAYS): coach marks. A step is data (title, body, anchor);
  the anchor is a group, and the step's target is every visible Control in
  it, merged: `tutorial_hero_stage` / `tutorial_monster_stage` (the lobby's
  two stages), `tutorial_hunt` (the nav bar's arch), `tutorial_codex` (its
  Codex tab), `tutorial_hud_slots` (the HUD's ability slots, hero cards or
  the monster panel), `tutorial_pause` (the HUD's pause button). The groups
  are set in the target scenes. The scrim (`bg_void` at 0.72, drawn by the
  overlay around a hole) darkens all but the target, the amber `SelectRing`
  frames it, the amber arrow (`ui_level_up.svg`) bobs toward it and the
  `PanelLeafy` bubble (kicker, title, body, a pip per step, "2 / 5", Skip /
  Back / Next) sits on the side with more room. The frame glides to the
  next target (0.25 s) and follows its target while it moves. A step without
  a target centres the bubble over the full scrim.
    - Camp tour (`LOBBY_STEPS`): the rules, the heroes' campfire, the
      monsters' lair, the HUNT arch, the Codex tab (growth and the Codex).
    - HUD tips (`HUD_STEPS`): the cooldown slots, the pause button.
    - `has_been_seen(chapter)`, `mark_seen(chapter)`, `forget(chapter)`;
      `finished(completed)`; analytics `tutorial_finished` with the chapter.
- **`CodexScreen`** (`Screens/CodexScreen.tscn`, `codex_screen.gd`, a
  MenuRoot screen; every signal wired in MenuRoot.tscn: `back_requested`,
  `tab_selected`, `guide_requested(chapter)`): the top bar ("Codex", Gold),
  three `TabButton` pages and the nav bar.
    - GUIDE: the camp tour and the HUD tips as numbered `PanelInset` cards
      (built from `TutorialOverlay`'s steps, one source), REPLAY THE CAMP
      TOUR and SHOW THE HUNT TIPS AGAIN.
    - MONSTERS: "Beasts met N / 3", then a `CodexEntry` per quarry met, in
      the order first met (`PersistedData.get_codex_entries(CODEX_MONSTERS)`,
      which `GameManager.begin_hunt` fills on a first sighting), then the
      other roster monsters as locked pages.
    - HEROES: a `CodexEntry` per roster hero.
    - `open()` rebuilds the pages and marks the monster pages seen (setting
      `codex_seen_monsters`); with new pages it opens on MONSTERS.
- **`CodexEntry`** (`Components/CodexEntry.tscn`): a `CharacterCard` (heroes)
  or `CharacterCardMonster` panel: the portrait in its side's inner panel,
  name, role and tagline, FIELD NOTES (`CharacterDef.codex_notes`: how a hero
  plays, how a monster hunts), for a monster EVOLUTION (its `stage_names` as
  "I · Bullcalf" chips) and COUNTERPLAY (`CharacterDef.tip`), and ABILITIES
  (icon, name and description of every ability in menu order, read from the
  scene's shared resources). An unmet monster is a `CharacterCardLocked`
  page: the portrait as a silhouette (`CharacterCard.locked_material()`),
  "???" and when it turns up ("It joins the hunt after N more hunts" or
  "Hunt it to fill this page").
- **`SettingsScreen`** (`Scenes/UI/Settings/SettingsScreen.tscn`): a bottom
  sheet (`SheetPanel`) that slides up over the scrim, from the lobby's gear
  and the pause menu. AUDIO: a slider per volume (Master, Music, Effects;
  each slider's `value_changed` is bound to its setting key in the scene),
  applied live; LANGUAGE (System / English / Deutsch; the scene's labels
  re-translate themselves); DISPLAY (screen shake); PRIVACY (usage
  statistics, stored on the device only); RESET PROGRESS (`ButtonMonster`,
  a second tap within 3 s wipes the progress, the settings stay); CLOSE, the
  round close button, a tap on the scrim and back save and close it
  (`closed`). All wiring is in the scene.

### Pre-round screen (PreRoundScreen)

The step between HUNT and the match, one screen for both sides
(`Scenes/UI/Screens/PreRoundScreen.tscn`, `pre_round_screen.gd`), a hidden
child of MenuRoot's `%Screens` that HUNT pushes after `open(side)`. Under the
top bar (back, Gold and the side's Steel or Leaves) the content scrolls
(`%Scroll`) above the pinned start button. Sections carry the group
`pre_round_heroes` or `pre_round_monster` in the scene and show for their side
only. It replaced the old `PreRoundSetup` overlay (deleted in 8.3) with the same contract:
`start_requested(config: MatchConfig)`, `cancelled`, the config persisted
(`save_to_settings`) and tracked (`AnalyticsSink` `pre_round_setup`) on start;
it adds `monster_start_requested(monster_id, instinct)`.

- **Heroes ("The Hunt")**:
    - TONIGHT'S QUARRY (`BannerMonster`): `GameManager.next_quarry()` (the
      same monster until a hunt starts) as an L `CharacterCard` showing the AI
      opponent it will be: Lv.(T+1) and a pill of its AI build's ranks out of
      its threat-4 build (12), whatever the Monster side owns. Beside it the
      NEW QUARRY pill (`PillReady`, pops in) while `is_new_quarry`, the name,
      the tagline, the icons of its three moves (`NodeTile`), the `ThreatBox`
      (threat, reward bonus, AI build, the monster's counterplay tip) and
      CHANGE (`ButtonCopper`; a tap on the card does the same).
    - The quarry sheet (`SheetPanel` sliding up over a `bg_void` scrim): every
      roster monster as an S card, the pool's ones as AI cards (the current
      quarry amber) and the others as silhouettes reading "Appears after N
      hunts" (`hunts_until_quarry`, `CharacterCard.locked_note`), a line on the
      mode ("Random pick: never the same quarry twice in a row." or "Nyxa every
      hunt, until you pick Random."), and RANDOM (disabled while random). A
      pool card locks it (`lock_quarry(id)`), RANDOM unlocks
      (`lock_quarry(&"")`), a silhouette shakes; the sheet closes on a pick,
      its close button, the scrim and `ui_cancel`.
    - YOUR HUNTERS (`BannerHero`): the roster's heroes as live
      `StageCharacter` rigs (150x200, the right pair facing the fire) on the
      campfire backdrop in the amber `FrameHero`, "Lv.N" under each; they
      cheer when the screen opens and when tapped.
    - STRATEGY: three `StrategyRow`s (Aggression Careful ↔ Reckless, Farming
      Hunt the beast ↔ Clear camps, Exploration Methodical ↔ Roam wide) and
      FORMATION: three `FormationTile`s (Tight, Spread, Line) with their
      `FormationGlyph`s, editing a `MatchConfig.from_settings()`; back keeps
      the saved one. The forecast (`PanelInset`, three icon rows) puts
      MatchConfig's derived values in words: "Ultimates fire at 3+ enemies, or
      when an ally drops below 28% HP.", "Mob camps weigh 70 against 100 for
      the monster.", "New targets every 3.2 s, scanning 450 px ahead, 100 px
      apart."
    - START HUNT (`ButtonPrimary`): the config with `quarry_id` = the quarry.
- **Monster ("Your Beast")**:
    - THE LAIR (`BannerMonster`): the picked monster big on the lair backdrop
      in the crimson `FrameMonster`, with "Name · Lv.N" and its role on a
      `ChipPanel`.
    - The picker: every roster monster as an S card, then the "???" slot. An
      owned monster becomes the player's own at once
      (`GameManager.choose_monster`, persisted; `played_monster_id()` reads
      it), takes the amber frame and cheers; a locked one (its price on the
      card) or the rumour shakes. The screen opens on `played_monster_id()`.
    - EVOLUTION: the monster's body at Stage I, II and III as posed
      `RigView`s growing left to right, with "Stage I" and the def's stage
      names (`CharacterDef.stage_names`).
    - The `ThreatBox` (the AI heroes' build).
    - INSTINCT: three `InstinctTile`s (Lurker, Ambusher, Ravager, crimson
      when picked) built but hidden (`show_instincts = false`, a user
      decision) until a gameplay batch balances their MonsterStrategy presets;
      the monster plays `DEFAULT_INSTINCT` (Ambusher, today's behaviour).
    - UNLEASH (`ButtonMonster`): tracked as `pre_round_monster`, emits
      `monster_start_requested(monster_id, instinct)`.
- Wiring: every connection inside the screen is in its scene; the runtime
  cards and the squad are wired in code. Strings (headers, dials, buttons,
  forecast, threat, sheet) are in `strings.csv` with German.
- Tests: `test_match_config` (the saved strategy shown, the dials and tiles
  editing it, the forecast, START persisting and emitting with the quarry,
  back keeping the save), `test_quarry_pick` (quarry card and Change sheet),
  `test_pre_round_screen` (each side's sections, top bar and frames, the
  squad, the picker switching owned monsters and ignoring locked ones, the
  evolution strip, hidden instincts and UNLEASH, shown instincts picking one,
  the ThreatBox on both sides at threat 0 and above, the scene-side wiring),
  `test_menu_root` (HUNT pushes it once per side, back and `ui_cancel` pop
  it).

### Match result screen (MatchResultScreen)

The overlay at the end of a match (`Scenes/UI/Screens/MatchResultScreen.tscn`,
`match_result_screen.gd`), a CanvasLayer at layer 30 with `process_mode`
ALWAYS. It replaced the old `MatchResult` overlay (deleted in 8.3) with the same contract:
`GameManager.MATCH_RESULT_SCENE` instantiates it over the paused World and calls
`populate(result)` after the rewards are saved. Previews of the design:
`result_heroes.png`, `result_monster.png`, `result_heroes_defeat.png`.

- **Ribbon**: `MatchRewards.outcome_label` (VICTORY / DEFEAT / TIME UP, 54 px
  `BannerTitle`) on `BannerVictory` (copper) for a heroes win,
  `BannerVictoryMonster` (crimson) for a monster win and `BannerDefeat` (grey
  stone) for a loss or TIME UP (kit art `banner_victory*`, `banner_defeat`).
  Under it a line and the match time: "The beast is slain", "The jungle claims
  your squad", "The beast slipped away" (heroes), "The jungle is yours", "The
  hunters prevailed" (monster).
- **Stage** (680x276): the played side's cast as live `StageCharacter` rigs on
  the campfire (`FrameHero`) or in the lair (`FrameMonster`): the four heroes
  the match counted (`Result.hero_ids`, the right pair facing inward) or the
  match's monster at the stage it reached (`Result.monster_id`). On a win the
  standing ones `celebrate()` (a cheer hop every 0.7 s, staggered 0.12 s); a
  hero that fell (`Result.fallen_hero_ids`), every hero of a lost match and the
  monster of a lost match `set_fallen(true)`: posed still, drained of colour
  and darkened (`UiPalette.FALLEN_STAGE_MODULATE`), tipped back 12 degrees
  and squashed to 0.94; at TIME UP the survivors idle. The cast is a picture
  (no taps).
- **Stats**: three `StatTile`s: Duration; the played side's kills
  (`Result.mob_kills`: "Mobs slain" for the heroes, "Mobs devoured" for the
  monster); Survivors "3 / 4" (heroes) or "Stage 3" / Evolution (monster).
- **REWARDS**: `RewardChip`s (`Components/RewardChip.tscn`) for Gold, Steel
  (heroes) or Leaves (monster) and XP ("XP each" for the heroes), counting up
  from 0 over 0.7 s with a pop. At an Opponent Threat above 0 the header
  shows "Threat 2: +20% Steel and Gold" (or Leaves) and the currency chips
  carry an amber "+20%"; XP never has a bonus.
- **XP rows**: an `XpRow` (`Components/XpRow.tscn`) per character, two columns
  for the heroes: the head portrait in its signature-colour ring (greyed under
  a skull if fallen), the name, "+N XP" and an `XpBar` filling over 0.9 s from
  the pre-match total (the saved total minus the gain) on the
  `PersistedData.level_progress` curve, "Lv.N" under it and the red LEVEL UP!
  pill popping where it crosses a level.
- **"N upgrades ready"** (`PillReady` with the level-up arrow) while the cast
  can buy ranks now (`CharacterProgress.upgrades_ready` summed): it emits
  `upgrades_requested(side)`, asks the menu for that side's roster
  (`GameManager.request_menu_roster`) and returns to MenuRoot, which opens the
  Heroes or Monsters roster on entry.
- **Buttons**: LOBBY (wood, `lobby_scene_path` = MenuRoot.tscn) and PLAY AGAIN
  (`ButtonPrimary` for the heroes, `ButtonMonster` for the monster), which calls
  `GameManager.begin_hunt()` (the Heroes side never meets the same quarry twice
  in a row) and reloads World. Both unpause the tree; a second press does
  nothing. `changes_scene = false` (tests, render probes) keeps only the
  signals (`lobby_requested`, `play_again_requested`, `upgrades_requested`).
  Back (`ui_cancel`: Escape, the Android back button) is LOBBY.
- **Intro**: the scrim fades in, the ribbon pops (0.4 → 1, TRANS_BACK) at
  0.1 s, the sections fade in from 0.3 s (staggered 0.08 s), the chips count
  from 0.6 s and the XP bars fill from 0.9 s; all settled by about 1.9 s.
- **GameManager's side** (data only, the trace is unchanged): `mob_kills`
  still counts every mob death (the determinism trace hashes it), and
  `hero_mob_kills` / `monster_mob_kills` count each side's kills by
  `killer_side(killer)` (MONSTER for the MonsterBase; HEROES for a HeroBase or
  anything in the "Hero" group, i.e. Ted's pet; traps, mines and the cage deal
  damage as their caster). `played_side_kills()` pays the rewards, fills
  `Result.mob_kills` and drives the HUD's kills chip. Where `heroes_alive`
  drops, the hero's id joins `Result.fallen_hero_ids`; `Result.hero_ids` is
  the census and `Result.monster_id` the match's monster.
- Colours come from the theme and `UiPalette` only (the scrim is `bg_void` at
  86 %); strings are in `strings.csv` with German.
- Tests: `test_match_result` (GameManager shows it and LOBBY goes to the main
  scene; populate for heroes win / loss / TIME UP and monster win / loss:
  ribbon, line, stage, frame, stats, chips, XP rows, the cast's poses; fallen
  heroes; the threat bonus; the count-up and LEVEL UP!; "upgrades ready"; the
  buttons' scene-side wiring; German; `killer_side` and the counters; a match
  end paying the played side's kills with the fallen hero in the Result),
  `test_menu_root` (the requested roster on entry).

### Roster and Character Detail (collections, overview, skill trees)

- **`RosterScreen`** (`Scenes/UI/Screens/RosterScreen.tscn`, `roster_screen.gd`;
  two instances in MenuRoot, `side` heroes and monster): the side's
  characters from `GameManager.ROSTER` as a 4-column grid of M `CharacterCard`s
  (live rigs, 16 px gaps), then the side's one "???" rumour card. Above it a
  row of `FilterTab` role filters (`filters` export, icons
  `Assets/UI/Icons/Roles/role_<key>.svg`; heroes all / tank / melee / ranged /
  support, monsters all / brute / stalker / swarm, set in MenuRoot.tscn) and
  the owned / total count; a role without characters says so. The top bar
  shows Gold plus the side's Steel or Leaves. `open()` builds the grid on the
  first visit, re-reads the save and plays the intro (the shown cards drop in
  0.04 s apart). An owned character's card asks for its detail
  (`character_requested`), and so does a locked one with a price (MenuRoot
  opens the unlock sheet); the rumour and a locked card without a price
  shake. `refresh()` re-reads levels, XP, ready upgrades and what is owned.
- **`CharacterDetail`** (`CharacterDetail.tscn`, `character_detail.gd`):
    - OVERVIEW: the character on its stage (`CharacterCard` /
      `CharacterCardMonster` frame, its live rig as a `StageCharacter` with the
      stage idle; a tap cheers), the role pill, "Lv.N" and the XP bar toward
      the next level, six `StatTile`s and the ability tiles. `stat_rows(def)`
      reads the stats resource, never preview numbers: heroes Health, Damage,
      Attack speed (1 / the basic attack's cooldown), Range, Move speed and
      Vision from `HeroStats`; monsters stage I Health, Damage (multiplier),
      Move speed, the Stage II and III XP thresholds and the Stage III health
      from `MonsterStats`. The four `AbilityTile`s follow
      `CharacterDef.ability_slots()` (PASSIVE, BASIC, ACTIVE, ULTIMATE; an
      empty slot hides its tile) with each ability's display icon and name; the
      ultimate is described first, a tap describes another.
    - SKILL TREE (the tabs, `TabButton`; the tree tab carries an up-arrow
      badge with `CharacterProgress.upgrades_ready`): the stage folds into a
      compact header (head portrait, name, "Ranks owned/open", level, XP), the
      character's tree in a `SkillTreeView` and the bottom sheet
      (`SheetPanel`) of the selected node: name, "Rank r/max · branch · Tier
      t" (" · Capstone"), "Now: …" (`NowLabel`) or "Not learned yet",
      "Next: …" (`NextLabel`, moss green), and UPGRADE (`ButtonPrimary`) with
      the currency icon and the price inside it (the price in `danger` when the
      wallet is short), disabled and showing why when the node cannot be
      bought ("Needs Lv 5", "Spend 3 more points", "Needs Plated or
      Unbreakable", "Maxed", "Need 340 more"; the price hides when a gate, not
      the wallet, stops it). A capstone also gets EQUIP (`ButtonHero`):
      usable on an owned capstone that is not the equipped one, "EQUIPPED" on
      the one that applies; a bought capstone shows only EQUIP. The sheet
      opens on `UxTreeModel.suggested_node()` (the first node that can be
      bought, else the first open one), never on an empty selection.
      Everything fits 720x1280 above the nav bar without scrolling.
    - `show_base_tree(side)`: the Growth tab's account-wide tree (Hero Base or
      Monster Base, Gold) in TREE mode without tabs, under the side's crest
      (`crest_heroes` / `crest_monster` exports, `Assets/UI/Crests`) with the
      tree's name and blurb.
    - UPGRADE only reports `upgrade_requested(tree_id, node_id)` and EQUIP
      `equip_requested(tree_id, node_id)`; MenuRoot buys or equips and calls
      `refresh()`. Purchase juice: the bought node pops (1.25 → 1), its vines
      fade to their new colour, and the top bar's chip counts down. Every
      connection inside the screen is in its scene; `back_requested`,
      `tab_selected`, `upgrade_requested` and `equip_requested` go to MenuRoot,
      and the nav bar keeps the screen's own tab lit.
- **`UxTreeModel`** (`Scenes/UI/Screens/ux_tree_model.gd`): the one thing the
  tree view and the sheet read. Branches (columns, "" = unnamed), `monster`
  (the side's branch colours), tiers with `gate_kind`, `tier_gates` (the
  gutter's numbers: `gate_caption()` "Lv" / "pts" / "Tier" over
  `gate_value(tier)`), `tier_open` and block reasons, nodes with `rank`,
  `rank_costs`, `rank_values`, `rank_texts`, `requires` (any one owned opens
  a node), `capstone` and an icon, `equipped` (the capstone that applies),
  `hidden_nodes` (place only: the view's "???" slots), plus the currency and
  the wallet. `state_of()` (LOCKED, AVAILABLE, OWNED, MAXED),
  `block_reason()`, `affordable()`, `can_buy()`, `buyable_count()`,
  `is_equipped()`, `can_equip()`, `ranks_owned()` / `ranks_open()` (the
  card pill's numbers), `display_order()` and `suggested_node()`.
  `from_ranked_manager(tree_id)` maps the ranked trees: the tree's branches as
  columns, every shown node with its owned rank and each rank's price
  (`cost_of_rank`), value (`value_at_rank`) and effect text (`effect_text`),
  its capstone flag and its `requires` (hidden parents dropped), hidden nodes
  as slots, `equipped_capstone`. Tier gates read from
  `MetaSkillManager.is_tier_open` (so the screen and the shop never disagree),
  with the block reason of the gate kind: "Needs Lv 3" (character trees),
  "Spend 3 more points" (base trees: the ranks still to buy), "Learn a Tier 1
  skill first" (TIER_BELOW). Icons from the node, else the stat icon of its
  stat or ability property (`STAT_ICONS`), else the ability's display icon. A
  snapshot: rebuilt after every change.
- Strings (OVERVIEW, SKILL TREE, ABILITIES, the slot kinds, stat captions, the
  sheet's texts and block reasons) are in `Assets/Locale/strings.csv` with
  German.
- Tests: `test_ux_tree_model` (states, block reasons, prices, gutter
  captions, rank totals, the suggested node and capstone equipping on a
  hand-built ranked tree; the live Grount tree with its three capstones; the
  points gates of Hero Base and their reasons in English and German; Irelia's
  capstones following the equipped one; icons; the live states, rank totals
  and equipped capstone agree with `node_state`, `card_progress` and
  `equipped_capstone` on every node of every tree, fresh and seeded),
  `test_roster_screen` (grid, rumour, filters, count, intro, taps, the locked
  monsters asking and a purchase counting, refresh, wiring), `test_character_detail` (stat rows, overview, level / XP / badge,
  tree mode and sheet with the purchase juice, the sheet opening on a buyable
  node, capstones equipping from the sheet, the top bar counting down, every
  character and account tree fits 720x1280 with its gutter, plaques, arches
  and names, Growth, wiring), and
  `test_grount_behaviour_nodes` checks the Grount tree on this screen (every
  node on it, Rampage and Trample too, no "???" slot left, Titan Form gated
  until Grount Lv 8, bought through `upgrade_requested`).

### Headless Tools (lint, tests, sim, trace, bench)

Every tool copies the project to a temp directory with its own `user://`
(`override.cfg`) and runs Godot headless there, never on the project directory
(the editor may have it open), so no tool touches the real save or makes a sound.

- `tools/lint.sh`: loads every script, scene and resource and checks the scene
  wiring; prints `errors=0`. `tools/run_tests.sh`: the headless suite
  (`test/test_*.gd`). Both exit non-zero on a failure.
- Exit leaks: the suite ends with nothing leaked (8.3 left 140 objects, 66
  resources and the RIDs of a test Bat). The runner stops every player (`AudioManager.stop_all()`) and gives the mixer
  120 ms before it quits; `SpawnManager` frees parked mobs when it leaves the
  tree and again when it is deleted, and frees (never parks) a mob released
  after it left (a mob that died in the frame the match ended). A test that records
  signals with a lambda must not keep that lambda in what it captures (the
  VFX tests' `_stop` drops it).
- `tools/sim.sh [runs=24] [side=heroes|monster] [workers=6] [cap_seconds=660]`:
  balance. Seeded auto-play matches in parallel, then one summary per monster
  (`tools/sim_summary.py`): win rates, match length, first contact, evolution
  timing, and hero deaths by the monster (the row's `monster_name`, the spawned
  node's name) or by mob. `OUT=<file>` keeps the raw JSON lines (every monster's;
  `sim_summary.py <file>` summarizes them the same way), `SAVE=<save.cfg>`
  starts every match from that save (its power ranks set the threat; the
  summary prints it). `THREAT=<0-4>` (or a list, `THREAT="0 2 4"`, or
  `THREAT=all` = 0..4, one summary per threat and monster) is the Opponent
  Threat parity check: each seed's fresh save gets the played side's parity
  build at that threat (`MetaSkillManager.parity_build`, P = 6T), so the AI
  opponent plays its threat-T build; `SAVE` and `THREAT` together exit 2.
  `sim_match.gd` takes it as `threat=<N>`, and every result line carries the
  match's `threat` and the played side's `power`. **Reproducible**: the copies turn off the
  navigation server's asynchronous map and region iterations (as
  `sim_trace.sh` does) and every seed starts from a fresh `user://` (or
  `SAVE`), so the same tree gives the same numbers on every run, whatever the
  CPU load or worker count, and seed s is `sim_trace.sh`'s seed s. Before
  (async on), 24 seeds of identical code gave 17 % and 33 % hero wins.
- `tools/sim_trace.sh [seeds="1 2 3"] [sides="heroes monster"] [cap_seconds=660]`:
  the determinism trace (a state hash every 60 frames and at the end), byte
  for byte the same for the same tree. `BASELINE=<file>` diffs the output with
  a saved one and exits 1 on a difference; `RIGS_AWAKE=1` animates every rig
  and must not change it.
- `tools/bench.sh [runs=5] [multiplier=2] [frames=1800] [warmup=600] [onscreen=0] [rigs_awake=0]`:
  performance in the stress config (all camps, `multiplier` mobs per slot),
  run r plays seed r, medians of frame time, CPU time and LOD buckets. It
  keeps the asynchronous navigation on (the device's setting and part of the
  cost), so runs vary between invocations; a run whose match ends inside the
  window stops there (the tree pauses at the match end) and is flagged
  (`ended early: seed 3 at frame ...`; ended in the warm-up = left out). Use
  5 or more runs for a performance gate, before and after back to back.
- **Monsters** (`tools/monster_env.zsh`, shared by `sim.sh`, `sim_trace.sh`
  and `bench.sh`):
  - no `MONSTER`: no `monster=` argument, the roster default (Grount) plays,
    so old command lines replay the same matches;
  - `MONSTER=<id>`: that roster monster; an id the roster lacks exits 2
    instead of quietly playing the default;
  - `MONSTER=all`: every id `tools/list_monsters.gd` prints
    (`Roster.monster_ids()`, roster order), one monster after the other.
    `sim.sh` and `bench.sh` print one summary per monster; `sim_trace.sh`
    prefixes every line with `<id> `.
- **Per-monster trace baselines**: `tools/baselines/trace_<id>.txt` is
  `MONSTER=<id> tools/sim_trace.sh` with the default arguments, for the
  committed tree (Grount's is the roster-default trace, byte for byte;
  Nyxa's and Gorrak's were recorded in the commits that added them).
  - check every monster: `MONSTER=all BASELINE_DIR=tools/baselines tools/sim_trace.sh > trace.txt`
    (exit 1 on a difference or a missing baseline);
  - re-record: `MONSTER=all RECORD_DIR=tools/baselines tools/sim_trace.sh > /dev/null`
    (default arguments only; nothing is written if a run failed), in the
    commit that changes gameplay on purpose and in the one that adds a monster.
    `test_sim_tools` fails while a roster monster has no baseline.
  - The hashes depend on the engine build and the CPU. The committed
    baselines were recorded with Godot 4.7.2 on the development Mac: after
    an engine upgrade or on another machine (the hourly cloud loop's runner
    included), re-record them there first and compare only traces made on
    the same machine and build. `BASELINE=<file>` against a trace recorded
    on the parent commit in the same place is the gate for a change that must
    not alter gameplay.
- Typical runs: `MONSTER=all tools/sim.sh 48 heroes 6` and `... 48 monster 6`
  (balance target 40–60 % hero wins per monster), `MONSTER=all THREAT=all
  tools/sim.sh 24 heroes 8` (the Opponent Threat parity check, 35–65 % at
  every threat), `MONSTER=all tools/bench.sh 5 2 900 300`.
- `tools/bake_nav.sh`, `tools/build_rigs.sh` and `tools/build_skill_trees.sh`
  regenerate the navigation bake, the rig sheets and bodies, and the skill tree
  resources on their copy and copy only the generated files back.

### File Structure

```
res://
├─ Assets/
│  ├─ Characters/<id>/ (src/ SVG parts + rig_src.json, generated <id>_sheet.svg
│  │                    and <id>_body.tscn, <id>_motion.tres, <id>.svg portrait,
│  │                    <id>_def.tres CharacterDef for playable characters)
│  ├─ Characters/_moves/ (humanoid / quadruped / flyer_moves.tres: the rig moves)
│  ├─ Fonts/ (LilitaOne-Regular.ttf display font + LilitaOne-OFL.txt licence)
│  ├─ Locale/ (strings.csv: English + German, imported translations)
│  ├─ Shaders/ (ground_grade; hit_flash + hit_flash_material.tres on every rig body)
│  ├─ Vfx/svg/ (fx_*.svg: in-world effect sprites, mipmapped; the mine pod and
│  │            lamp, supply crate and chute are scene sprites)
│  ├─ Vfx/recipes/ (fx_<character>_<ability>.tres: AbilityFxRecipe per ability;
│  │                fx_generic_bite / fx_generic_claw: the mobs' and the fox's swings)
│  ├─ UI/ (generated Jungle Guild kit, DPITexture SVGs)
│  │  ├─ Kit/ · Crests/ · Icons/{Abilities,Currency,Stats,Roles,Nav,UI}/
│  │  ├─ Lobby/ (the lobby's campfire and lair backdrops, VS badge)
│  │  └─ Shaders/ (ability_cooldown, card_locked, ready_glow)
│  └─ Icon.jpg (the app icon, project.godot config/icon)
├─ Data/
│  └─ SkillTrees/ (the nine skill trees, <tree_id>.tres: MetaSkillTree + node sub-resources)
├─ Scenes/
│  ├─ NPCs/
│  │  ├─ npc_base_class.gd + NPCBaseClass.tscn (EntityBase: state chart, Rig, HP bar)
│  │  ├─ roster.tres (Roster: every playable character, GameManager.ROSTER)
│  │  ├─ Hero/
│  │  │  ├─ hero_base_class.gd + HeroBaseClass.tscn (HeroBase)
│  │  │  ├─ hero_stats.gd (HeroStats resource) · stat_component.gd (HeroStatsComponent)
│  │  │  ├─ hero_exploration_controller.gd (formation, exploration)
│  │  │  ├─ Abilities/ (ability_base.gd: AbilityBase · ability_system.gd: AbilitySystem)
│  │  │  └─ Heros/
│  │  │     ├─ DMG/Vlad/
│  │  │     ├─ Healer/River/
│  │  │     ├─ Support/Ted/ (Abilities/Passive/TedsPet.tscn: the fox)
│  │  │     └─ Support/Irelia/
│  │  ├─ Mob/
│  │  │  ├─ mobs_base_class.gd + mobs_base_class.tscn (MobBase, the Bat's defaults)
│  │  │  └─ Mobs/Bat/Bat.tscn · Mobs/Hog/Hog.tscn
│  │  └─ Monster/
│  │     ├─ monster_base_class.gd + .tscn (MonsterBase) · monster_stats.gd (MonsterStats)
│  │     ├─ Grount/ (Grount.tscn, grount_stats.tres, grount_strategy.tres,
│  │     │           abilities/: cleave, ram dash and slam scripts + .tres)
│  │     ├─ Nyxa/ (Nyxa.tscn, stats, strategy, abilities/ incl. night_swarm.gd)
│  │     └─ Gorrak/ (Gorrak.tscn, stats, strategy, abilities/ incl. thrown_axe.gd)
│  ├─ World/
│  │  ├─ World.tscn · world.gd · world_navigation.tres (the baked navigation)
│  │  ├─ monster_slot.gd (MonsterSlot: spawns the selected monster)
│  │  ├─ spawns.gd (SpawnManager: camp eligibility, lazy activation, mob pool)
│  │  ├─ Camera/ (MainCam: GameCamera with shake; DebugOverlay: the F3 overlay)
│  │  ├─ FogOfWar/
│  │  └─ MobSpawnArea/
│  └─ UI/
│     ├─ Screens/ (MenuRoot.tscn: the main scene, LobbyScreen.tscn,
│     │            RosterScreen.tscn, CharacterDetail.tscn, PreRoundScreen.tscn,
│     │            MatchResultScreen.tscn, CodexScreen.tscn, ux_tree_model.gd)
│     ├─ Settings/ (SettingsScreen.tscn: the settings sheet)
│     ├─ Tutorial/ (TutorialOverlay.tscn: the coach marks)
│     ├─ Hud/ (MatchHud: the in-match HUD under MainCam, HeroHudCard,
│     │        MonsterHudPanel, AbilitySlot: ability icon with the cooldown sweep,
│     │        MatchAnnouncer: match events -> the HUD's event toasts, PauseMenu)
│     ├─ Minimap/ (Minimap: fog map + side-fair dots, inside the MatchHud frame)
│     ├─ Components/ (menu kit: CharacterCard, StageCharacter, TopBar,
│     │               CurrencyChip, NavBar, NavTab, NavArch, PressFeedback,
│     │               StatTile, AbilityTile, SkillNodeButton, SkillTreeView,
│     │               UnlockSheet, RewardChip, XpRow)
│     ├─ Widgets/ (rig_view.gd: RigView, a puppet rig inside a Control)
│     └─ Theme/
│        ├─ ui_theme.tres (generated project Theme, gui/theme/custom)
│        ├─ ui_palette.gd (UiPalette)
│        └─ palette.tres (generated palette values)
├─ Scripts/ (autoloads and shared systems: globals, types, game_utils,
│  │         combat_events, event_bus, damage_packet, team_registry +
│  │         team_blackboard, entity_registry, tick_scheduler, hp_bar_2d,
│  │         ring_pulse, audio_manager, analytics_sink, persisted_data,
│  │         locale_settings, audio_settings, game_manager, match_config,
│  │         match_rewards, monster_strategy, back_button, spawn_zone)
│  ├─ MetaSkills/ (MetaSkillManager, MetaSkillTree, MetaSkillNode; skill_tree_data_v2.gd: the trees' seed data)
│  ├─ Progression/ (CharacterProgress: card level, XP pill, ready upgrades)
│  ├─ Rig/ (CharacterRig, RigBody, RigProfile: SVG cut-out rigs)
│  ├─ Roster/ (Roster, CharacterDef: the character registry)
│  ├─ UI/ (CooldownSource: read-only HUD view of an entity's ability slots)
│  └─ Vfx/ (VfxManager: pooled hit feedback; AbilityVfx, FxGroundLayer,
│           AbilityFxRecipe: ability effects; FxSpriteBuffer, FxTex, FxEase, FxEvents)
├─ addons/godot_state_charts/ (the entity state charts)
├─ test/ (headless suite, test_*.gd; fixtures/rig_fixture/ for the rig tests)
└─ tools/
   ├─ art/ (Python art pipeline: palette.py, build.py, make_theme.py, ...)
   ├─ rig_builder.gd · build_rigs.gd · build_rigs.sh (SVG parts → rig sheet + body)
   ├─ build_skill_trees.gd · build_skill_trees.sh (seed data → Data/SkillTrees, kept in step by a test)
   ├─ bake_nav.gd · bake_nav.sh (Ground tiles → world_navigation.tres)
   ├─ lint.sh · lint_all.gd · run_tests.sh (compile + wiring check, the suite)
   ├─ sim.sh · sim_match.gd · sim_summary.py · sim_trace.sh · bench.sh · bench_match.gd
   │  (headless balance, determinism and performance; see Headless Tools)
   ├─ list_monsters.gd · monster_env.zsh (MONSTER=<id>|all for those three)
   ├─ baselines/ (trace_<id>.txt: each roster monster's determinism trace)
   └─ preview/ (ThemeMockup, ThemeScreens, PaletteSheet, RigGallery, MoveSheet,
                CardGrid, SlotStrip, AbilityFxStage proof scenes, not shipped)
```

---

## 💰 Progression System - Permanent Upgrades

### Currency Types

| Currency         | Source             | Purpose                          | Shared?                 |
| ---------------- | ------------------ | -------------------------------- | ----------------------- |
| **Steel**        | Playing as Heroes  | Hero-specific upgrades           | No (Hero trees only)    |
| **Leaves**       | Playing as Monster | Monster-specific upgrades        | No (Monster trees only) |
| **Gold**         | Both sides         | Universal upgrades               | Yes (Base trees)        |
| **Permanent XP** | Each character     | Individual character progression | No (Per hero/monster)   |

### Earning Rates v2 (Per Round)

`MatchRewards.compute` (Scripts/match_rewards.gd, pure: no side effects).
"Currency" is Steel on the hero side and Leaves on the monster side; Gold is
paid on both sides. Economy only: nothing here feeds back into the match.

**Currency (Steel / Leaves)**:

- Win: 150, Loss: 75 (a timeout is a loss for the heroes and a win for the monster)
- Kills: +15 per mob killed
- Survival Time: +5 per full minute
- Heroes Alive (Heroes): +20 per survivor
- Stage Reached (Monster): +25 per stage

**Gold**: Win 100, Loss 50, +2 per mob killed.

**Opponent Threat bonus**: currency and Gold x (1 + 0.1 T) at the match's
threat T (0-4, "Opponent Threat"), rounded half up
(`MatchRewards.with_threat_bonus`; `GameManager` passes `match_threat`, and
`Result.threat` echoes it for the result screen). XP is not scaled.

**Permanent XP** (unchanged by v2; every character on the played side gets it):
Win 25, Loss 10, +2 per kill, +3 per minute, +5 per survivor (Heroes) or
+10 per stage (Monster).

**Example**:

- Heroes win at 8 minutes with 3 survivors after killing 40 mobs
- Steel: 150 (win) + 600 (kills) + 40 (time) + 60 (survivors) = **850 Steel**
- Gold: 100 (win) + 80 (kills) = **180 Gold**; XP: 25 + 80 + 24 + 15 = **144 XP**
- At threat 3: **1,105 Steel** and **234 Gold** (x 1.3), still 144 XP

**Target income** (what the tree prices are balanced against, measured with
the design tool `income.py` over sim matches, medians): about **800 Steel**
per hero match, **1,000 Leaves** per monster match and **160 Gold** per match
on either side, about 150 XP. That fills every hero tree in about 53 hero
matches, every monster tree in about 34 monster matches (plus the monster
unlock prices) and both base trees in about 85 matches.

"Mob killed" means a kill by the played side (the model above):
`GameManager.played_side_kills()` (the heroes' kills, Ted's pet and their traps
included, or the monster's own), which the result screen and the HUD's kills
chip show too. Measured on 72 sim matches per side at threat 0: a median of
about **715 Steel** per hero match and **915 Leaves** per monster match, near
the target. Until 8.2 GameManager passed `mob_kills` (every mob death on both
sides), and a match paid about 1,440 Steel / 1,470 Leaves.

### Skill Tree Structure

#### Ranks, gates and capstones (the node model)

Every tree (`MetaSkillTree`) is a grid of nodes (`MetaSkillNode`): tiers 1-4 as
rows, branches as columns (`branch` 0 = offense, 1 = defense, 2 = utility;
`MetaSkillTree.branches` names them). Each node has one effect: a character
stat, one ability property, or a behaviour key.

- **Ranks.** A node has 1..`max_rank` ranks (1 = a one-time unlock). Rank r
  costs `rank_costs[r-1]` (or `cost` x `cost_growth`^(r-1), rounded to 5).
  Owning rank r applies `value_at_rank(r)` once: the explicit cumulative
  `rank_values[r-1]` (a multiplier such as 1.14, or a total delta), else the
  linear rule (multiplicative 1 + (v-1)·r, additive v·r). Rank 1 is always
  exactly `stat_value`, the node as it was before ranks.
- **Tier gates** (`MetaSkillTree.gate_kind`, buying rank 1 only):
  `TIER_BELOW` (a node of the tier below is owned; no shipped tree uses it),
  `LEVEL` (the owner's permanent level from its XP reaches
  `tier_gates[t-1]`; character trees use 1 / 3 / 5 / 8), `POINTS` (the
  ranks owned in the tree reach `tier_gates[t-1]`; base trees use
  0 / 4 / 10 / 18). `requires` lists parent nodes, any one of which must be
  owned (`requires_all` = every one).
- **Gates guard buying only.** Owned nodes are never revoked: a save that owns
  a node above today's gate keeps it, it applies, and its next rank can be
  bought.
- **Effect text.** `description` writes the effect with "{v}" for the rank's
  value; `effect_text(rank)` fills it in: next to "%" a multiplier shows its
  distance from 1 (1.08 -> "8", 0.8 -> "20") and an additive value is a
  fraction (0.2 -> "20"); anywhere else the plain number ("{v}x" 1.5 -> "1.5x").
- **Hidden** (`hidden`): a node whose effect has no code yet. It is data only:
  not shown (`shown_nodes`, `nodes_in_tier`, `max_tier`, `capstones` leave it
  out), not buyable (`node_state` INVALID, or UNLOCKED if a save owns it), never
  applied, left out of `card_progress`. As a parent it neither opens nor blocks:
  a node whose `requires` lists only hidden ids needs just its tier. The batch
  that writes the code clears the flag in the tree's `.tres` (since 6.6 no
  shipped node is hidden; `test_skill_trees_v2` keeps the rule covered on a
  throwaway tree).
- **Capstones** (`capstone`, tier 4 of a character tree, one per branch): all
  can be bought, but only the tree's equipped capstone applies. Buying the
  first one equips it; `equip_capstone` swaps for free. A tree with no saved
  choice equips its first owned capstone in branch order (old saves that own
  Titan Form keep it).
- **MetaSkillManager:** `node_state` (INVALID, UNLOCKED = maxed, TIER_GATED,
  AVAILABLE, UNAFFORDABLE, LEVEL_GATED, REQUIRES_MISSING; an owned node below
  its max shows its next rank), `rank_up` (`skill_unlocked` at rank 1, then
  `skill_ranked`, then `skills_changed`; analytics log ranks 2+ as
  `skill_ranked`), `unlock` (rank 1 only), `get_rank`, `is_maxed`,
  `next_rank_cost`, `is_tier_open`, `points_spent`, `equipped_capstone`,
  `equip_capstone`, `applied_ranks` (what a spawn of the played side applies)
  and `card_progress(tree)` → `{owned_ranks, open_ranks, upgrade_ready}` for
  the card pill. `ai_build_order` on the tree lists the ranks an AI side buys;
  the Opponent Threat API is under "Opponent Threat" below.
- **Save v3** (`PersistedData`): `[skill_ranks] <tree_id> = {"node_id": rank}`
  and `[capstones] <tree_id> = "node_id"`. Loading a v1/v2 save backs it up
  (`save.cfg.v2.bak`), turns every id of the old `[skills]` lists into rank 1,
  verbatim, even ids no tree defines any more, and drops `[skills]`;
  `get_unlocked_skills` is its view now. The step is idempotent: an id that
  already has a rank keeps it.

#### Generic stat keys

Keys a node can carry that are not a stat of their own. Each has ONE apply
site and is neutral (x1.0, or 0 / level 1) when no node with it is owned, so a
fresh save plays exactly as before. Multiplicative keys stack by product
(Tempered Mail -10% and Plated -12% take x0.79), additive ones by sum.

| key | nodes | apply site |
|---|---|---|
| `damage_taken_mult` | hb_armor, ir_armor | `HeroBase._receive_damage` scales `packet.amount` (the final amount: `damage_applied` listeners and `deal_damage`'s return see it) |
| `cooldown_mult` | hb_cdr | `AbilitySystem._use_ability`: the active and ultimate cooldown (and the HUD's total) as they start; the basic attack keeps attack speed |
| `start_level` | hb_startlvl | `HeroBase._ready` levels the hero up to it after the tree is applied (growth on top of the % nodes, full HP) |
| `monster_damage_taken_mult` | mb_bark, g1_hide, gk_bark | `MonsterBase._receive_damage` scales `packet.amount` |
| `monster_regen_mult` | mb_regen, ny_regen, gk_regen | `MonsterBase._update_rest`: rest regeneration per second |
| `monster_cooldown_mult` | mb_cdr | `MonsterBase._cast`: every cast's cooldown (after the stage table) |
| `monster_s3_damage_mult` | mb_apex | `MonsterBase.effective_ability_damage` at `FINAL_STAGE` (3), under Enrage |
| `monster_start_xp` | mb_headstart | `MonsterBase._ready` sets `current_xp` (not gained, so Bloodhound does not scale it); the next XP gain checks evolution |

Hero keys reach `HeroStatsComponent` through `add_stat_modifier` like the
stats (`get_damage_taken_multiplier`, `get_cooldown_multiplier`,
`get_start_level`, all over `get_modifier(stat, multiplicative)`); monster
keys come from `collect_monster_modifiers` into `MonsterBase._meta_*`. The F3
overlay prints them as a "tree keys:" line under the followed hero and under
each monster ("dmg taken x0.79 cd x0.85 start Lv 2"; "-" on a fresh save).

#### Hero capstones and behaviour nodes

Nodes whose effect is an export of one hero ability (`ability_name` +
`stat_name` = the export). Every export is off by default (false, 0, 1 or
x1.0), so a fresh save plays exactly as before; a spawn sets it on the hero's
own ability copy (`AbilitySystem.make_abilities_unique`), never on the shared
`.tres`. Capstones apply only while equipped (one per tree).

| node | export (ability) | effect |
|---|---|---|
| ir_laststand CAP | `last_stand`, `last_stand_duration` 2 s (Regeneration) | once per match the lethal hit leaves Irelia at 1 HP (`HeroBase._survives_lethal_hit`, which `Irelia` overrides); `HeroBase.make_invulnerable` then cancels every hit for 2 s (a timer on the hero, not a chart state: `_receive_damage` flips `packet.canceled`, so `EventBus` skips the reaction and `damage_applied`, and `deal_damage` returns 0) |
| ir_guardian CAP | `cleanse_stuns` (Divine Shield) | every hero the shield lands on loses its stun (`EntityBase.clear_stun`) |
| ir_banner CAP | `rally_radius` 250, `rally_attack_speed` 1.25 (Monster Taunt) | every living hero within 250 px of Irelia, herself included, gets Rally Cry's attack-speed boost x1.25 for the taunt's 5 s |
| vl_execute CAP | `execute_threshold` 0.25, `execute_mult` 2 (Blood Strike, `BasicStrike`) | a target below 25% HP takes x2 (its HP fraction read before the hit) |
| vl_leech CAP | `lifesteal_pct` 0.2 (Blood Strike; `AbilityBase`) | `AbilityBase.deal()` (every `BasicStrike` hit goes through it) heals the caster for 20% of the damage that landed (`HeroBase.heal_self`, never a dead hero) |
| vl_cluster CAP | `mine_count` 3, `mine_spacing` 40 (Land Mine) | three full mines per cast on a triangle around Vlad, 40 px between neighbours (a count node is multiplicative: 1 x 3) |
| td_warcry CAP | `aura_radius` 300 (Rally Cry) | every other living hero within 300 px of Ted gets Rally Cry's x1.5 attack speed for 5 s too |
| td_petvit | `pet_health_mult` 1.2/1.4/1.6 (Loyal Companion) | each pet spawns with that much max HP |
| td_petdmg | `pet_damage_mult` 1.2/1.4/1.6 (Loyal Companion) | each pet's bite damage |
| td_respawn | `respawn_time` 10 s x0.7/0.5/0.35 (Loyal Companion) | a dead pet is back sooner (was the const RESPAWN_TIME) |
| td_twin CAP | `pet_count` 2 (Loyal Companion) | Ted keeps two pets (`pets`, one per slot, on opposite sides of him), each slot with its own respawn timer (`respawn_timers`); Rally Cry boosts every living pet (`Ted.get_pets`) |
| td_spikes CAP | `cage_dps` 6 (Trap Cage) | once a second (`TrapCage.SPIKE_INTERVAL`) every valid enemy overlapping the cage takes 6 damage through the ability's `deal()`, credited to Ted |
| rv_deadeye CAP | `crit_every` 4, `crit_mult` 2.5 (Adaptive Weapon) | every 4th sniper shot of River's copy deals x2.5, Triple Shot's extra targets included |
| rv_chain CAP | `extra_heal_targets` 1, `chain_heal_radius` 160 (Adaptive Weapon) | a staff heal also heals the most hurt other hero (lowest HP fraction, below full) within 160 px of the healed one, never River herself |
| rv_pathfinder CAP | `team_speed_aura` 1.12 (Adaptive Movement) | River's copy posts it once on the heroes' `TeamBlackboard` (`set_move_speed_aura`); `HeroBase._get_move_speed` multiplies by `move_speed_aura()`, the product of the living sources, so it ends the moment River dies (and leaves with her from the team). F3 "tree keys:" shows "team speed x1.12" |

Trap Cage takes everything its `_ready` reads before it enters the tree: its
position (on the target, in its parent's space), `cage_radius` (the ability's
`area_of_effect`, 150 px in `ted_ultimate.tres`, the README radius),
`duration` (the expiry timer, so Sturdy Cage lengthens it) and the spikes.
`_ready` then sizes the collision shape, traps the enemies inside and starts
the timer. Until 6.3 the cage entered the tree first: it scanned at its
parent's origin (World's `Heros` is a plain Node, so the world origin by the
heroes' start) with the scene's 150 px, moved onto the target afterwards and
then shrank to the ability's 2 px, so it trapped (almost) nothing. A trapped
enemy that reaches the bars is put back just inside the edge it tried to leave
by (the push used to mirror it to the opposite side). `test_hero_actives`
covers both.

Balance check (`SAVE=<save.cfg> tools/sim.sh 24 heroes 6`: every match starts
from that save; 5.4, against a fresh-save Grount). A fresh save: heroes win 33%.
Only the four capstones of one branch, equipped: branch 0 (Last Stand,
Executioner's Mark, War Cry, Deadeye) 50%, branch 1 (Guardian Angel, Sanguine
Feast, Pack of Two, Chain Heal) 71%, branch 2 (Rallying Taunt, Cluster Mines,
Spiked Cage, Pathfinder) 42%; Pathfinder brings the first hero-monster contact
from about 400 s to 81 s. All four hero trees fully ranked: 92% with any
branch's capstones and 92% without one. The trees, not the capstones, decided
that matchup; since Opponent Threat (6.8) the AI Grount meets such a save with
its threat-4 build: 79% without capstones, 96% / 100% / 92% with branch 0 / 1
/ 2 (24 seeds).
These 5.4 numbers predate the reproducible sim (6.2) and the Trap Cage fix;
6.3's re-measure is under "Measured Balance".

Haste rule (`HeroBase.apply_attack_speed_boost`, Rally Cry and the
capstones above): a weaker boost never replaces a stronger one that is still
running; an equal or stronger one restarts it. The F3 overlay's ability lines
show each export as a tree modifier ("Regeneration ... tree last_stand +1.00
last stand ready").

#### Monster capstones and behaviour nodes

The tier-4 capstones of the monster trees (6.6). Like the hero ones, every
switch is off by default (false or 0), so a fresh save plays exactly as
before and the three committed traces (`tools/baselines`) stay byte-identical;
a spawn sets it on the monster's own ability copies or reads it from
`collect_monster_modifiers` into `MonsterBase._meta_*`. Only the equipped
capstone of a tree applies. `test/test_monster_capstones.gd` turns each one on
from a seeded save.

| node | key or export (ability) | effect |
|---|---|---|
| g4_rampage CAP | `monster_rampage`; `MonsterBase.rampage_heal_pct` 0.15 | `MonsterBase` connects to `EventBus.entity_died` only while it applies; a `HeroBase` death whose killer is this monster zeroes every `ability_cooldowns` slot and heals 15% of max HP (`heal_self`, never a dead monster). Look: `RAMPAGE` (rings, an anger vein, rising sparks, "+N"; see Ability Effects). F3: "rampage(N)" with the hero kills so far |
| g4_stampede CAP | `trample`; `trample_hit_radius` 70, `trample_from_stage` 3, `trample_cooldown_mult` 0.5 (Ram Dash, `BullRamDash`) | the dash hits everything within 70 px of the bull's centre as it passes (`get_hit_radius`; the stock lane is the `dash_hit_radius` export, 40, which was the const `DASH_HIT_RADIUS`), and from Stage 3 `apply_stage_stats` halves its cooldown (5 s -> 2.5 s). Look: the dash's lane telegraph at 70 px and its dust at the lane's edges. F3: "trample 70 px" |
| ny_rebirth CAP | `monster_rebirth`; `MonsterBase.rebirth_health_pct` 0.3, `rebirth_return_distance` 400, `rebirth_flee_speed_mult` 1.5 | once per match the lethal hit sends `CombatEvents.SELF_SCATTERED` instead of `SELF_DEAD`: the chart's **Scattered** state (an atomic state of `monster_base_class.tscn`, entered from any state by `ToScattered`, its handlers wired scene-side) is the whole rebirth, no flag mirrors it (`is_scattered()` asks the state). While in it she has 0 HP, so `is_alive()` is false and nobody keeps her as a target; `_receive_damage` cancels every hit; her Body's collision layer is 0, so no detection area or overlap query finds her; her target and stun are dropped; each AI step flies her toward the scatter point at x1.5 speed, and her body fades to 30% alpha (look: a bat-scatter burst on entry, `SCATTERED`, and the bats flying to the re-form point on exit, `REFORMED`). The state's delayed `ToIdle` transition (3 s) ends it: still within 400 px of a hero, she re-forms at the scatter point (on the flee fan away from the centroid of the heroes within 800 px, 400, 600 or 800 px from her, the first point on the mesh that is at least 400 px from every living hero; her own spot if none is close), then the layer is back and she has 30% of max HP. No `entity_died` is reported, so the match goes on. F3: the chart state "Scattered"; "rebirth" / "rebirth! 1.2 s" (the pending transition's countdown) / "rebirth spent" |
| ny_echo CAP | `double_pass` (Shadow Swoop, `BullRamDash`) | a targeted swoop turns at its end and runs back the distance it travelled along the same lane with its hit list cleared, so the target is hit twice (she ends where she started); an escape swoop (no target) never turns. `is_channeling` covers both passes. Look: `DASH_TURNED`, a lane telegraph back and her streak running back along it. F3: "echo" |
| ny_brood CAP | `permanent_from_stage` 3 (Night Swarm, `NightSwarm`) | from Stage 3 (`apply_stage_stats`) a running swarm never runs out; it stops only with her (dead or scattered). While it runs `can_use` is false, so the combo falls back to the screech instead of re-casting it. Look: 12 bats instead of 8, for as long as it runs. F3: "swarm! forever" |
| gk_whirl CAP | `full_circle_from_stage` 3 (Cleaver Chop, `BullFrontCleave`) | from Stage 3 `apply_stage_stats` sets `cone_angle` to 360 and `execute` skips the cone test: the chop hits everything within its reach all around him. Look: a circle telegraph and four spinning slashes (the rig's `spin` move). F3: "whirlwind" / "whirlwind!" |
| gk_unstoppable CAP | `monster_cc_immune` | `MonsterBase.is_cc_immune()` (also true while Nyxa's bats are scattered). Look: a taunt or cage that skips him bursts into shards off him (`CC_SHRUGGED`). `IreliaUltimateTaunt` skips such a monster in both of its passes (a monster is in the "Enemy" group too), so the taunt falls back on the mobs around; `TrapCage` never traps it, and its per-frame hold and its exit check skip it, so a cage that held Nyxa lets her scattered bats out. The cage's spikes still hurt whatever overlaps it. F3: "unstoppable" |
| gk_warband CAP | `recruit_radius` 250, `recruit_duration` 20 (Warcry Stomp, `BullGroundSlam`) | a stomp cast at a hero (or Ted's pet; a stomp at a mob while farming recruits nobody, or he would stall at Stage 2 beside a camp he may no longer eat: 17 of 24 sanity matches timed out before that rule) calls the herd: at impact, before the damage, every living mob within 250 px whose scene allows it (`MobBase.can_join_warband`, set on `Hog.tscn`) joins the caster's warband (`MobBase.join_warband`): `ally_monster` is the caster while its `WarbandTimer` (a one-shot Timer in `mobs_base_class.tscn`, timeout wired scene-side) runs 20 s. `GameUtils.can_entity_target` honours it both ways (the mob never targets him, his abilities never hit it, so the stomp spares it); heroes stay its targets, it drops him as a target and goes for the hero in sight or the nearest within its `chase_distance`. Tinted toward Gorrak's palette colour (`monster3_light`) while it lasts, with a ring at its feet and a "!" as it joins (`RECRUITED`); the timeout and `prepare_for_pool` end it. F3: "warband(last N)"; a warband mob's overlay label shows "WARBAND" |

Sanity check (6.6; `SAVE=<save.cfg> MONSTER=<id> tools/sim.sh 24 heroes 6`):
each monster with `monster_base` and its own tree fully ranked (70-76 ranks)
and one capstone equipped, against fresh heroes. Grount: Titan Form 0% hero
wins (matches end at a median 86 s), Rampage 29%, Trample 33%. Nyxa: 0% with
each of her three capstones (one timeout each). Gorrak: 0% with each of his
three. A fully ranked monster beats fresh heroes, as fully ranked heroes beat
a fresh Grount (92%, above); Titan Form is the one capstone that decides
Grount's matchup on its own. Since Opponent Threat (6.8) such a save (power
ranks 70+, threat 4) meets AI heroes with their threat-4 build instead of
fresh ones.

#### Opponent Threat (the side rule and AI builds)

The player owns trees on both sides, but only the side they play uses them.
The AI opponent gets a fixed build that grows with the player's own
investment (6.8). Before 6.8 both sides read the save, so a player's Monster
unlocks made the AI monster stronger in their Heroes matches (and the other
way round).

- **Side rule.** The **played side** (`GameManager.chosen_side`) applies the
  save's trees (`applied_ranks`: owned ranks, the equipped capstone). The **AI
  opponent** applies its **AI build** (`MetaSkillManager.spawn_ranks(tree,
  side)` picks one per spawn: `HeroBase._ready` through
  `apply_unlocked_to_hero`, `MonsterBase._load_meta_modifiers` through
  `collect_monster_modifiers` and `apply_ability_nodes_to_monster`). A fresh
  save is threat 0 with an empty AI build, so fresh matches, the determinism
  trace and the committed baselines are unchanged.
- **Power ranks** `P` (`power_ranks(side, monster_id)`): ranks owned in the
  played side's base tree plus in the played character's tree, each node
  capped at its max rank (`owned_ranks`, the card pill's count). Heroes: the
  floor of the mean over the roster's four hero trees. Monster: the played
  monster's own tree (`GameManager.selected_monster_id`). Ranks in the other
  side's trees never count.
- **Threat** `T = min(4, floor(P / 6))` (`threat_for_power`, `threat_for`,
  `opponent_threat()` for this match). `GameManager.match_threat` takes it
  when the match starts; the spawns read the same value.
- **AI build at threat T** (`ai_build_ranks(tree, ai_build_entries(tree,
  T))`): the first 3T entries of the opponent character tree's
  `ai_build_order` and the first 2T of its side's base tree's. Each entry is
  one more rank of that node (capped at its max); unknown and hidden ids are
  skipped; the order's one capstone comes last and applies (threat 4). No
  RNG. When the player plays the monster, every AI hero takes its own order
  plus `hero_base`'s. `side_ai_build(side, monster_id, T)` lists a whole side
  (tree id -> node id -> rank).
- **The monster orders (6.8 retune).** The design's orders were never
  simulated; on the parity check (below) they gave Grount 25 % hero wins at
  threat 2 and Gorrak 96 % (heroes side) / 92 % (monster side) at threat 4.
  6.8 reordered them in the `.tres` (`SkillTreeDataV2` keeps the design's):
  - `monster_base`: `mb_claws, mt1_xp, mt1_hp, mb_bark, mt2_dmg, mt1_hp,
    mb_claws, mt2_evo`, then as designed (the same ranks at threat 4: a +10 %
    HP rank and the XP rank no longer both come at threat 1).
  - Grount: `g1_hide, g1_speed, g3_slam, g2_cleavecd, g1_dmg, g3_dash, g2_hp,
    g1_dmg, g2_evo, g1_stun, g3_dmg, g4_titan` (the same ranks; damage,
    Ravenous and Stunning Charge later: an early-built Grount reached Stage 3
    before the heroes had their levels).
  - Nyxa: `ny_hp, ny_dmg, ny_hp, ny_evo, ny_dmg, ny_leech, ny_hp, ny_speed,
    ny_swoopcd, ny_swarm, ny_swarmdur, ny_brood` (Wide Shriek and Night
    Recovery out, a third Dusk Hide and a second Piercing Shriek rank in).
  - Gorrak: `gk_dmg, gk_hp, gk_dmg, gk_dmg, gk_axedmg, gk_dmg, gk_axedmg,
    gk_dmg, gk_axedmg, gk_hp, gk_hp, gk_whirl`: Heavy Cleaver and Honed Tusks
    with Whirlwind. With his design order (armour, regeneration, stun,
    Unstoppable) and with every HP, stun or Call of the Herd variant tried,
    the heroes won 83-96 % at threat 4; only the axe damage moved it (71 %).
  - The hero orders are as designed.
- **Balance** (6.8, `MONSTER=all THREAT=all tools/sim.sh 24 <side> 8`, hero
  wins, heroes side / monster side; threat 0 is a fresh save):

  | threat | Grount | Nyxa | Gorrak |
  |---|---|---|---|
  | 0 | 50 % / 54 % | 58 % / 62 % | 38 % / 46 % |
  | 1 | 46 % / 50 % | 46 % / 54 % | 62 % / 42 % |
  | 2 | 42 % / 33 % | 67 % / 62 % | 58 % / 67 % |
  | 3 | 46 % / 33 % | 71 % / 67 % | 62 % / 71 % |
  | 4 | 58 % / 50 % | 42 % / 50 % | 71 % / 75 % |

  21 of the 30 cells are inside 35-65 %, the other 9 within 10 points of it
  (24 seeds: one standard error is about 10 points). Gorrak at threats 3-4
  is the weak spot: the heroes' tier-3 nodes and capstones outgrow his tree.
- **A player at the threshold** (a real save, `SAVE=`: the first 12
  `ai_build_order` entries of the base tree and of each played character
  tree, P 24, threat 4 by the rule) owns 24 ranks to the AI's 20 and wins
  most matches: heroes side 100 % (Grount), 71 % (Nyxa), 88 % (Gorrak);
  monster side 12 %, 12 %, 38 % hero wins. The fully ranked hero saves of
  "Hero capstones and behaviour nodes" (power ranks 39-42, threat 4) beat the
  threat-4 Grount 79 % without capstones and 92-100 % with them (92 % against
  an unbuilt Grount before 6.8). The 2T base entries keep the AI behind the
  player; giving it 3T would make a threshold player a parity match.
- **Rewards**: currency and Gold x (1 + 0.1 T) ("Earning Rates v2").
- **F3**: a "Threat" line (`GameManager.debug_threat_line()`: `Threat 2
  played heroes P 13  AI monster: 6 nyxa + 4 base ranks`, or `AI heroes:
  6/6/6/6 + 4 base ranks`), and the monster's line shows its build (`save` or
  `AI T2 6+4`).
- **Sims**: `tools/sim.sh` `THREAT=N` is the parity check: both sides hold
  their threat-N AI build (the AI opponent through
  `MetaSkillManager.threat_override`, a sims-only override of
  `opponent_threat()`; the played side through its save, `side_ai_build`).
  `SAVE=` runs the rule on a real save instead.
- The pre-round screen shows it before every match: its `ThreatBox`
  (`threat_for(side, monster)` and the AI side's `side_ai_build`) and, on the
  Heroes side, the quarry card's Lv.(T+1) and pill (`ai_build_size` of the
  monster's tree at T out of its threat-4 build).
- Checks: `test/test_opponent_threat.gd` (the maths, the side rule on seeded
  saves both ways, the AI build prefixes, the parity check, the F3 lines),
  `test/test_rewards.gd` (the bonus). Tests that seed a monster tree play the
  monster side (`TestCase.play_side`; the runner restores the side after every
  test).

#### Tree content v2 (Data/SkillTrees)

Nine trees, one `MetaSkillTree` resource each with its nodes as sub-resources:
`Data/SkillTrees/<tree_id>.tres`. They were generated by
`tools/build_skill_trees.sh` (runs `tools/build_skill_trees.gd` on a temp copy)
from the design's seed data, `Scripts/MetaSkills/skill_tree_data_v2.gd`
(`SkillTreeDataV2`); the `.tres` files ARE the trees and are edited in the
inspector (the tool keeps an existing file unless `--force`). The seed data
follows every edit: `test_skill_trees_v2` compares each stored property of
the generator's output (`build_tree`, static) with the shipped tree, so a
`--force` rebuild writes exactly what ships (6.8's AI build orders and the
unhidden nodes included; until 8.3 it would have reverted both).
`MetaSkillManager._ready` registers `hero_base` and `monster_base`
(`HERO_BASE_TREE`, `MONSTER_BASE_TREE`) and every roster def's `skill_tree`
(`monster_nyxa` and `monster_gorrak` since Nyxa and Gorrak joined the
roster).

- **Shape:** 3 branches (offense / defense / utility) x 4 tiers. Tier-1 stat
  nodes have 5 ranks, most others 3, behaviour nodes and capstones 1. Values
  are cumulative per rank (`rank_values`) and diminishing.
- **Currencies and gates:** `hero_base` / `monster_base` cost Gold and open
  tiers by ranks owned in the tree (0 / 4 / 10 / 18); `hero_<id>` cost Steel,
  `monster_<id>` Leaves, and open tiers at the character's permanent level
  1 / 3 / 5 / 8 (`owner_id`).
- **Cost rows** (price of rank 1..N): S5 40/60/100/150/240, T1x3 50/90/150,
  T1x1 200, T2x3 120/200/330, T2x1 450, T3x3 240/400/600, T3x1 750, CAP 1500;
  base trees G1x3 40/70/110, G2x3 100/160/250, G3x2 200/320, G4x1 600,
  G4x1b 900.
- **Save compatibility:** all 71 v1 node ids are kept and their rank 1 is the
  v1 effect (same key, same value), so a migrated save owns rank 1 of what it
  bought (`test_skill_trees_v2` checks it against a frozen copy of the v1
  seeds). Four v1 nodes never did anything and work now: `t2_trapcd` /
  `t3_trapdur` named "Trap Cage", which Ted's ultimate was called "TED ULt"
  until it was renamed; `i2_rallycd` (was "Rally Cry", Ted's) and `i3_dashcd`
  (was "Dash", no such ability) are retargeted at Irelia's Divine Shield and
  Monster Taunt cooldowns. Irelia's basic attack is named "Shield Bash"
  (was "Unnamed Ability"). Every ability name has an EN/DE entry in
  `strings.csv`. The F3 overlay lists the followed hero's ability copies with
  their cooldown, tree modifiers and the time left ("Trap Cage  cd 4.00 s  tree
  cooldown x0.80  left 2.31 s").
- **AI build orders** (`ai_build_order`: 12 entries per character tree,
  capstone last; 18 in `hero_base`, 14 in `monster_base`): the AI opponent
  takes a prefix of them at each threat ("Opponent Threat").

Nodes, "branch: tier node (ranks)", `<-` = requires any. No shipped node is
hidden any more (every hero node has its code since 5.4, every monster node
since 6.6); `hidden` stays for nodes whose code is still to come:

- **hero_base** (Might / Vitality / Tactics):
  - Might: T1 Sharp Edge +5/8/10% damage; T2 Forged Steel +10/13/15% <- Sharp
    Edge; T3 Battle Rhythm +15/20% attack speed; T4 Berserker +20% damage.
  - Vitality: T1 Iron Skin +5/8/10% max HP; T2 Hardened +10/13/15%; T2 Tempered
    Mail -4/7/10% damage taken; T3 Veteran Plate +15/20%; T4 Titan +25%.
  - Tactics: T1 Light Step +5/7/9% move speed; T2 Quick Strike +10/13/15% attack
    speed; T3 Swift Runner +15/18%; T3 Battle Drills -8/15% active and ultimate
    cooldowns; T4 Storm Blades +25% attack speed; T4 Veteran Squad heroes start
    at level 2.
- **monster_base** (Ferocity / Hide / Instinct):
  - Ferocity: T1 Sharpened Claws +3/5/7% damage; T2 Brutal Strikes +15/18/20%;
    T3 Long Reach +10/15% ability range; T4 Apex Predator +15% damage at
    Stage 3.
  - Hide: T1 Thicker Hide +10/13/15% max HP; T2 Scarred Hide -4/7/10% damage
    taken; T3 Apex Body +20/25%; T4 Primal Regeneration resting regen x2.
  - Instinct: T1 Faster Hunt +5/7/9% speed; T1 Bloodhound +10/15/20% XP; T2
    Quick Evolution -10/13/15% stage XP; T3 Primal Rhythm -5/10% cooldowns; T4
    Head Start 60 XP at the start.
- **hero_irelia** (Bulwark / Oathkeeper / Vanguard):
  - Bulwark: T1 Reinforced Plate +8/11/14/17/20% max HP; T2 Unbreakable
    +12/16/20%; T2 Plated -5/9/12% damage taken; T3 Bulwark
    +20/25/30%; T4 CAP Last Stand (a lethal hit once leaves 1 HP, 2 s
    invulnerable).
  - Oathkeeper: T1 Second Breath Regeneration heals 1.5/2/2.5x; T2 Shield
    Cadence Divine Shield cooldown -20/28/35%; T3 Aegis Divine Shield absorbs
    +30/60/90%; T4 CAP Guardian Angel (the shield breaks stuns).
  - Vanguard: T1 Shield Bash +5/8/11/14/17% damage; T1 Marching Order +5/7/9%
    speed; T2 Riposte +10/14/18% attack speed; T3 Vanguard +10/15/20% damage;
    T3 Relentless Monster Taunt cooldown -30/38/45%; T4 CAP Rallying Taunt
    (+25% attack speed to heroes within 250 px).
- **hero_vlad** (Butcher / Blood / Demolition):
  - Butcher: T1 Keen Blade +5/8/11/14/17% damage; T1 Eager Swings +5/8/11%
    attack speed; T2 Bloodthirst +10/14/18%; T3 Executioner +20/25/30%; T4 CAP
    Executioner's Mark (Blood Strike x2 below 25% HP).
  - Blood: T1 Thick Blood +5/8/11/14/17% max HP; T2 Iron Heart +10/14/18%; T2
    Deeper Thirst Bloodlust 5/10/15% HP sooner; T3 Frenzy +15/20/25% attack
    speed; T4 CAP Sanguine Feast (Blood Strike heals 20% of its damage).
  - Demolition: T1 Black Powder Land Mine damage +20/40/60%; T2 Bigger Bomb
    Blood Bomb radius +25/35/45%; T3 Quick Mines Land Mine cooldown -25/35/45%;
    T4 CAP Cluster Mines (3 mines).
- **hero_ted** (Brawler / Beastmaster / Trapper):
  - Brawler: T1 Trail Rations +5/8/11/14/17% max HP; T2 Sharpened Snares
    +10/14/18% damage; T2 Rapid Traps +10/14/18% attack speed; T3 Pack Leader
    +15/20/25% max HP; T4 CAP War Cry (Rally Cry hastes heroes within 300 px).
  - Beastmaster: T1 Loyal Bond pet HP +20/40/60%; T2 Sharp Fangs pet damage
    +20/40/60%; T3 Never Alone pet respawns 30/50/65% faster; T4 CAP Pack of
    Two (2 pets).
  - Trapper: T1 Long Leash +5/8/11/14/17% range; T1 Tracker's Pace +5/7/9%
    speed; T2 Fast Traps Trap Cage cooldown -20/28/35%; T3 Sturdy Cage Trap
    Cage duration +50/75/100% (6 s -> 9/10.5/12 s); T3 Far Whistle +15/20/25%
    range; T4 CAP Spiked Cage (6 damage per second inside).
- **hero_river** (Marksman / Field Medic / Scout):
  - Marksman: T1 Long Scope +8/11/14/17/20% range; T2 Hollow Points +10/15/20%
    damage; T2 Triple Shot (sniper shots hit 2 more enemies); T3 Sniper's Nest
    +15/20/25% range; T4 CAP Deadeye (every 4th shot x2.5).
  - Field Medic: T1 Field Dressing +5/8/11/14/17% max HP; T2 Fast Resupply
    Supply Drop cooldown -20/28/35%; T2 Steady Hands staff heals +15/30/45%; T3
    Field Hospital Supply Drop heals +50/75/100%; T3 Veteran Scout +15/20/25%
    max HP; T4 CAP Chain Heal (staff heals also heal the most hurt ally within
    160 px).
  - Scout: T1 Light Boots +5/7/9/11/13% speed; T2 Quick Hands +10/14/18% attack
    speed; T3 Adrenaline Adaptive Movement boost +50/80/110%; T4 CAP Pathfinder
    (+12% move speed for every hero while River lives).
- **monster_grount** (Horns / Hide / Charge):
  - Horns: T1 Heavy Horns +10/14/17/20/22% damage; T1 Wide Sweep +10/14/18%
    ability range; T2 Quick Cleave Front Cleave cooldown -15/20/25%; T3 Titan's
    Wrath +20/25/30%; T3 **Enrage** (below 20% HP: +30% speed and +50% on every
    cast; ends once HP is back at 20%, by rest regen or the evolution heal); T4
    CAP **Rampage** (every hero Grount kills resets all his cooldowns and heals
    15% of max HP).
  - Hide: T1 Thick Hide -3/5/7/9/10% damage taken; T2 Scar Tissue
    +15/20/25% max HP; T2 Early Slam (Ground Slam at Stage 1); T3 Wider Slam
    Ground Slam radius +20/30/40%; T3 **Gravity Slam** (at impact, living
    heroes, Ted's pet and mobs within 200 px are dragged to 80 px from it along
    the nav mesh, walls stop them, then the damage lands); T4 CAP **Titan
    Form** (Stage 3: x1.5 scale on top of the stage scale with the aggro radius
    unchanged, +500 max HP healed on reaching Stage 3, +20 attack range, Front
    Cleave reach and Fight leave distance).
  - Charge: T1 Stampede +5/7/9/11/13% speed; T1 Stunning Charge (Ram Dash stuns
    0.5 s); T2 Ravenous -10/13/15% stage XP; T3 Long Charge Ram Dash distance
    +33/45/55%; T3 Apex Charge +15/18/21% speed; T4 CAP **Trample** (Ram Dash
    hits a 70 px lane instead of 40 px, and from Stage 3 recharges twice as
    fast: 2.5 s).
- **monster_nyxa** (Hunger / Shadow / Brood), registered with her def; every
  ability node acts on her own ability copies:
  - Hunger: T1 Dusk Hide +5/8/11/14/17% max HP; T2 Thirst Sonic Screech
    lifesteal +10/15/20 points (20% -> 30/35/40%); T3 Night Recovery resting
    regen x1.5/2/2.5; T4 CAP **Vampiric Rebirth** (once per match at 0 HP she
    scatters into bats for 3 s and returns with 30% HP).
  - Shadow: T1 Silent Wings +4/7/10/12/14% speed; T2 Swift Hunter Shadow Swoop
    cooldown -15/23/30%; T2 Disorienting Dive (Shadow Swoop stuns 0.4 s); T3
    Fast Maturity -8/12/15% stage XP; T4 CAP **Echo Strike** (Shadow Swoop
    passes its target a second time).
  - Brood: T1 Piercing Shriek +4/7/10/13/15% damage; T2 Wide Shriek Sonic
    Screech cone +8/14/20 degrees; T3 Thicker Swarm Night Swarm radius
    +15/25/35%; T3 Endless Night Night Swarm lasts +30/50/70%; T4 CAP **Brood
    Mother** (from Stage 3 the Night Swarm never ends).
- **monster_gorrak** (Tusks / Bristles / Warband), registered with his def;
  every ability node acts on his own ability copies:
  - Tusks: T1 Heavy Cleaver +5/8/11/14/17% damage; T2 Wide Arc Cleaver Chop
    cone +10/18/25 degrees; T3 Honed Tusks Tusk Axe damage +20/35/50%; T3
    Concussive Axe (Tusk Axe stuns 0.5 s); T4 CAP **Whirlwind** (from Stage 3
    Cleaver Chop hits all around him).
  - Bristles: T1 Thick Bristles +5/8/11/14/17% max HP; T2 Mud Armour -5/8/11%
    damage taken; T3 Mud Bath resting regen x1.5/2/2.5; T4 CAP **Unstoppable**
    (immune to crowd control: Irelia's taunt and Ted's Trap Cage skip him;
    damage still lands, the Spiked Cage's spikes included).
  - Warband: T1 Long March +4/7/10/12/14% speed; T2 Earthshaker Warcry Stomp
    radius +15/25/35%; T2 Ringing Ears Warcry Stomp stuns 0.25/0.5/0.75 s
    longer; T3 King's Hunger -8/12/15% stage XP; T4 CAP **Call of the Herd**
    (a Warcry Stomp aimed at a hero or Ted's pet turns the Hogs within 250 px
    into his warband for 20 s).
- The capstones' mechanics are under "Monster capstones and behaviour nodes"
  and "Hero capstones and behaviour nodes". `test/test_readme_spec.gd` checks
  every node name and rank row above against `Data/SkillTrees/*.tres`.

**Permanent XP** (per hero and per monster) opens a character tree's tiers:
Lv 3, 5 and 8 take about 2, 7 and 19 matches with that character.

### Monetization (Future)

**Double XP Boost** (Premium Purchase):

- Doubles permanent XP gained per round
- Does NOT affect Steel/Leaves/Gold
- One-time purchase, permanent effect

---

## 🎮 Player Experience Flow

### First-Time Player Journey

**First launch** - the camp tour:

1. The game opens on the lobby: the four heroes at their campfire, the
   monsters in their lair (Grount awake, Nyxa and Gorrak as padlocked
   silhouettes with their price)
2. 0.9 s in, the coach marks play over it: the rules, the campfire, the
   lair, the HUNT arch, the Codex tab. Skip counts as seen; the Codex's guide
   replays it
3. Tap a side to choose it (kept for the next launch), then HUNT

**First match**:

1. Pre-round: tonight's quarry (Grount on the first hunt) or the player's
   own monster, the strategy dials and the formation with a plain-words
   forecast, the Opponent Threat (0 on a fresh save), START HUNT
2. The match plays itself; the HUD tips point at the cooldown slots and the
   pause button once
3. The result screen: VICTORY / DEFEAT / TIME UP, the rewards counting up
   (a hero win pays 150 Steel + 100 Gold plus the kill, time and survivor
   bonuses), each character's XP bar
4. "N upgrades ready" opens the side's roster; a card's red pill leads to
   the character page and its skill tree

**Hunts 2-6** - learning:

- Experiment with both sides; the first ranks cost 40-200
- The Heroes side meets Nyxa after 3 hunts and Gorrak after 6 (NEW QUARRY on
  the pre-round card, a new Codex page); the free Change picker fixes a quarry
- The Monster side unlocks Nyxa (2,500 Leaves) and Gorrak (3,000) once a
  monster is Lv 3

**Hunt 10+** - mastery:

- Tiers open with the character's permanent level (Lv 3 / 5 / 8); one
  capstone per tree is equipped and can be swapped for free
- Every 6 ranks on the played side raise the Opponent Threat by one (up to
  4): a stronger AI build and +10% Steel / Leaves / Gold per level

### Engagement Loops

**Short Loop** (Per Round - 5-10 min):

```
Setup (1 min) → Watch Battle (4-8 min) → Rewards (30s) → Upgrade (1 min)
```

**Medium Loop** (Per Session - 30-60 min):

```
Play 5-10 rounds → Major skill tree progress (daily quests: planned)
```

**Long Loop** (Per Week/Month):

```
Max out trees and capstones → Unlock the monsters (new heroes, leaderboards: planned)
```

---

## 🚧 Current Status & Roadmap

`PROGRESS.md` is the living tracker (done, backlog, open decisions,
changelog with numbers); this section is the summary.

### ✅ Implemented (Prototype v0.2, the "Jungle Guild" overhaul)

**Core Gameplay**:

- [x] 4 unique heroes with a 4-slot kit each (passive, basic, active, ultimate)
- [x] 3 monsters with 3-stage evolution: Grount (bruiser), Nyxa (lifesteal
      skirmisher, bat aura), Gorrak (armoured, returning axe, stunning stomp),
      each a scene + data on the shared monster framework
- [x] XP and leveling systems (in-round), 10-minute match clock
- [x] Asymmetric power curve; 40-60 % hero wins per monster on both sides at
      threat 0 (48 seeds)

**Combat**:

- [x] Damage pipeline (`EventBus` request → apply, shields, threat, lifesteal)
- [x] Cooldown management, per-stage ability tables, stuns, taunt, traps
- [x] Pet system (Ted's fox; two with Pack of Two)

**AI**:

- [x] Hero exploration in a role-ranked formation, call-for-help, focus fire,
      auto-used actives and ultimates driven by the pre-round dials
- [x] Monster strategy layer per monster (farm / rest / retreat / ambush /
      hunt, ability combos)
- [x] Target acquisition and combat, spawn area leashing for mobs

**Visuals**:

- [x] One palette (`UiPalette`, 100 tokens), one generated theme, the SVG UI
      kit and icons, Lilita One
- [x] SVG cut-out rigs for all ten characters (idle, walk, flinch, attack,
      cast and ultimate moves per body plan), evolution parts, contact shadows
- [x] Ability effects as data (`AbilityFxRecipe`, 27 recipes), pooled
      `VfxManager` (damage numbers, hit flash, shake, telegraphs), mob swings
      under the rig budget
- [x] Pixel jungle tiles under the muted ground grade; fog of war (world-space)
- [x] Match HUD: hero cards / monster panel, ability slots with the cooldown
      sweep, ready glow and stage locks, framed minimap, event toasts, pause menu

**Map**:

- [x] 9200x5185 map with 5 zones, one baked navigation region
- [x] 39 Bat and Hog camps (lazy activation, pooling, 40 s respawn); Elite
      camps are designed, not built

**Meta & Flow**:

- [x] Lobby (MenuRoot, the main scene): campfire and lair as live rigs, tap a
      side to choose it
- [x] Roster screens (4-column collections, role filters, locked cards) and
      the character page (overview, abilities, skill tree)
- [x] Skill trees v2: nine trees as resources (3 branches x 4 tiers, ranks,
      level / points gates, one equipped capstone), every node live
- [x] Opponent choice (tonight's quarry, Change picker), monster unlocks,
      the side rule and Opponent Threat with AI builds and the reward bonus
- [x] Pre-round screen (quarry or monster, strategy dials, formation,
      forecast, threat) and match result screen (ribbon, cast, count-up
      rewards, XP bars, upgrades ready)
- [x] First-run flow (camp tour, HUD tips), Codex (guide, monsters, heroes),
      Settings (volumes, language, screen shake, privacy, reset)
- [x] Earning Rates v2, permanent XP and levels per character
- [x] Versioned save (v3) with backup + migration, local analytics log
      (opt-out), localization (English + German UI strings)
- [x] Audio manager on the Master/Music/SFX buses (generated placeholder tones
      until real assets land in `Assets/Audio/`)
- [x] Performance pass: faction collision layers, EntityRegistry, TickScheduler
      AI LOD, HpBar2D, mob pooling, rig sleep and budget
- [x] Headless tools: `tools/lint.sh`, `tools/run_tests.sh` (600 tests),
      `tools/sim.sh`, `tools/sim_trace.sh`, `tools/bench.sh`, and the art, rig,
      skill-tree and navigation builders

---

### 🚧 Next (open items, details in `PROGRESS.md`)

**High Priority**:

- [ ] **Device build**: export presets, the stress config on a mid-range
      phone with F3, Compatibility vs Mobile renderer
- [ ] **User review of the open design decisions and placeholder copy**
      (PROGRESS: "Decisions for the user", "Placeholder copy")
- [ ] **Balance at Opponent Threat 3-4**: Gorrak's tree (heroes win 62-75 %),
      the AI build size against a player at the threshold, the 48-seed
      confirmation of the parity table
- [ ] **Real audio assets**: drop `.ogg` / `.wav` files into `Assets/Audio/`
      (keys in its README)

**Medium Priority**:

- [ ] Monster instincts on the pre-round screen (Lurker / Ambusher / Ravager
      are built and hidden until their `MonsterStrategy` presets are balanced)
- [ ] Localization of the content strings (skill node texts, tree titles,
      Codex notes, taglines, tips, ability descriptions, stage names)
- [ ] Heroes: threat assessment (flee from a Stage 3 monster)
- [ ] Hero composition selection (more than four heroes)
- [ ] "Second Wind" (needs the evolution-heal decision), trap / barrage
      slows, a second ultimate

**Low Priority**:

- [ ] Elite camps, more mob types
- [ ] Cloud save, a remote analytics provider

---

### 📅 Future Versions

#### v0.3 - Content Expansion

- [ ] 2 new heroes (Archer, Mage archetypes)
- [ ] 1 new monster (Swarm-based: Spider Queen; the roster's "swarm" role
      filter has nobody yet)
- [ ] More mob types (Ranged bats, Charging rhinos), Elite camps

#### v0.4 - Polish & Balance

- [ ] 10+ heroes total
- [ ] Advanced AI (split strategies, baiting)
- [ ] Sound design pass

#### v0.5 - Pre-Alpha Release

- [ ] 15+ heroes
- [ ] 5+ monsters
- [ ] Multiple maps (2-3)
- [ ] Daily quests & challenges
- [ ] Leaderboards (local)
- [ ] Tutorial mode (a scripted first match)

#### v1.0 - Public Alpha

- [ ] 30+ heroes (goal)
- [ ] 8+ monsters
- [ ] Online leaderboards
- [ ] Seasonal content
- [ ] Store builds (Android / iOS)
- [ ] Monetization (2x XP boost)

---

### 🔧 Known Issues & Tech Debt

`PROGRESS.md` ("Tech Debt / Improvements", "Decisions for the user") is the
full list. The ones a reader of this spec should know:

**Bugs**:

- [ ] Gorrak's camp choice and slam count still count his own warband mobs
      (`MonsterBase._pick_camp`, `_count_slam_targets`): with Call of the Herd
      he can walk to a camp he cannot farm for up to 20 s
- [ ] River's supply crate fades in mid-air when every hero in its pickup
      radius was healed during the fall; a Land Mine placed on an enemy
      detonates at once (no arming delay). Intended or not: open

**Performance**:

- [ ] 60 fps @ 150 mobs on a mid-range phone: the code side is done and the
      headless stress bench holds (frame mean about 1.5 ms with the rigs
      asleep, about 2.0 ms with all 232 awake); the device measurement is open
- [ ] Headless runs put no mob on screen, so sims tick mobs at 20 / 10 / 3 Hz
      where a device ticks the visible ones at 60 Hz

**Balance**:

- [ ] Opponent Threat: 21 of 30 parity cells inside 35-65 % at 24 seeds;
      Gorrak at threat 3-4 is too weak, a player at the threshold beats the AI
- [ ] Nyxa wins mostly by timeout (17-18 of 48): accepted as her trait
- [ ] Fully ranked heroes beat a threat-4 Grount 79-100 %

**Design Debt**:

- [ ] Hero composition is fixed (can't choose which 4 heroes yet)
- [ ] Monster spawn location is random within Zone 3 (should it become a strategic choice?)
- [ ] Evolution refills the monster's HP; the original rule was "new max HP -
      old max HP": decide which rule ships
      (`MonsterBase.heal_to_full_on_evolution`), then add Grount's "Second
      Wind" (`monster_stage_2_evo_heal` +200, wired and tested in
      `test_grount_behaviour_nodes`) to `Data/SkillTrees/monster_grount.tres`
- [ ] Knockback is not implemented (`knockback_force` on Ram Dash does nothing)
- [ ] Content strings are English only (see Next)

---

## 📝 Design Pillars & Philosophy

### Core Pillars

1. **Asymmetry Creates Tension**
    - Heroes start strong, monster becomes god
    - Information asymmetry (fog of war)
    - 4v1 vs 1v4 - different skill expressions

2. **Strategy Over Execution**
    - Auto-battler format: Brain over twitch reflexes
    - Pre-round decisions are 80% of success
    - Learning from failure is key

3. **Risk vs Reward**
    - Heroes: Rush (safe) vs Farm (risky)
    - Monster: Hide (gamble) vs Fight (consistent)
    - Greed is punished, aggression is rewarded (sometimes)

4. **Permanent Progression**
    - Every round makes you stronger
    - Character specialization via trees
    - No "dead" rounds - always progressing

5. **Readable Visuals**
    - Mobile-first design language
    - Thick ink outlines, capped VFX (numbers, shake and effects are budgeted)
    - Information clarity > flashy effects

### Design Constraints

**Mobile-Friendly**:

- Touch controls must work (tap to focus a hero, pinch to zoom; no commands mid-match)
- UI elements large enough for fingers
- Performance target: 60fps on mid-range phones (2022+)

**Session Length**:

- Target: 5-8 minute rounds
- Respect player time (no forced grinding)

**Monetization Ethics**:

- No pay-to-win (2x XP is convenience only)
- All gameplay content free
- Cosmetics only (future)

---

## 🎯 Success Metrics (Post-Launch Goals)

### Player Retention

- **Day 1**: 40% return next day
- **Day 7**: 20% still playing
- **Day 30**: 10% retained

### Engagement

- Average session: 30-45 minutes (5-7 rounds)
- Rounds per week: 20+ for engaged players
- Skill tree depth: Players reach Tier 3+ by Week 2

### Balance

- **Win Rates** (After 100+ games per player):
    - Hero Side: 48-52%
    - Monster Side: 48-52%
    - No hero below 45% or above 55% individual win rate
    - No monster below 45% or above 55%

### Monetization (Future)

- 2x XP Boost purchase rate: 5-10% of players
- Revenue per user: $2-5 over lifetime

---

## 🔍 Playtesting Focus Areas

### v0.2 Playtesting Questions

1. Is the auto-battler format engaging, or too passive?
2. Do players understand the power curve intuitively?
3. Are 5-8 minute rounds the right length?
4. Is the skill tree progression satisfying?
5. Which heroes feel weak/strong?

### v0.3 Playtesting Questions

1. Is there enough hero variety (6 heroes)?
2. Does the second monster play differently enough?
3. Are players using advanced strategies (baiting, split push)?
4. Is the grind to unlock nodes too slow/fast?

---

## 📞 Contact & Team

**Developer**: [Your Name/Studio]  
**Solo Project**: Art, Code, Design  
**Tools**: Godot 4.7, hand-written SVG art through the Python generators in `tools/art/` and the rig builder (the ground tileset is the one pixel asset left), GitHub (version control)

---

## 📚 Appendices

### A. Monster Evolution Math

Thresholds are total XP (`MonsterStats.stage_2_xp`, `stage_3_xp`); a Bat pays
the monster 8 XP, a Hog 25, a hero 100.

| Monster | Stage 2 at | Stage 3 at | Stage 1 → 2 | Stage 2 → 3 | Median Stage 3 (sim) |
| ------- | ---------- | ---------- | ----------- | ----------- | -------------------- |
| Grount  | 150 XP     | 300 XP     | 19 Bats (152 XP) | 6 Hogs (150 XP) | 322 s |
| Nyxa    | 150 XP     | 400 XP     | 19 Bats (152 XP) | 32 Bats (256 XP): she farms Bats only until Stage 3 | 371 s |
| Gorrak  | 150 XP     | 500 XP     | 19 Bats (152 XP) | 14 Hogs (350 XP) | 346 s |

- Stage 1 farms Bats only (`farm_max_mob_health` 60); Grount and Gorrak add
  Hogs from Stage 2 (150), Nyxa from Stage 3.
- The tree nodes Ravenous / Fast Maturity / King's Hunger and Quick
  Evolution lower both thresholds; Bloodhound raises the XP per kill; Head
  Start begins a match with 60 XP.
- Elite camps (50 XP per mob) are designed, not built.

### B. Hero Team Compositions (Future)

**Rush Comp** (Fast, Aggressive):

- River (vision), Vlad (burst), Ranger (TBD), Scout (TBD)
- Strategy: Find monster in 2-3 min, kill before Stage 2

**Balanced Comp** (Current Default):

- River, Vlad, Ted, Irelia
- Strategy: Farm 1-2 camps, then hunt

**Late Game Comp** (Greedy, Scales):

- Irelia (tank), Ted (sustain DPS), Mage (TBD), Healer (TBD)
- Strategy: Farm to Level 4+, fight Stage 3

### C. Glossary

- **XP**: Experience Points (in-round leveling)
- **Permanent XP**: Out-of-round progression per character; its level
  ("Lv.N" on the cards) opens the character tree's tiers
- **Steel**: Hero-specific upgrade currency
- **Leaves**: Monster-specific upgrade currency (also buys monsters)
- **Gold**: Universal upgrade currency (the two base trees)
- **Stage**: Monster evolution level (1-3)
- **Level**: Hero in-round power (1-10)
- **Rank**: One purchase of a skill node (nodes have 1, 2, 3 or 5 ranks)
- **Capstone**: A tree's tier-4 behaviour node; one per tree is equipped
- **Power ranks (P)**: Ranks owned on the played side (base tree + character tree)
- **Opponent Threat (T)**: `min(4, floor(P / 6))`; sets the AI opponent's build
  and the reward bonus
- **Quarry**: The monster the Heroes side hunts tonight
- **Rig**: A character's SVG cut-out puppet (`CharacterRig`), the same in the
  menus and the match
- **Recipe**: An ability's look as data (`AbilityFxRecipe`)
- **Boids**: Flocking algorithm for group movement
- **Leashing**: Mobs returning to spawn area
- **Fog of War**: Vision/exploration system

---

## ❓ FAQ

**Q: Can I control heroes/monster during the round?**  
A: No. You set the strategy before the round; during it you watch, follow a hero (tap, 1-4, Tab) and zoom. Mid-round commands are a future idea.

**Q: How many heroes will there be at launch?**  
A: Goal is 30+ heroes, each with unique abilities and trees.

**Q: Will there be PvP (player vs player)?**  
A: Not planned for v1.0. Focus is PvE auto-battler first.

**Q: Can I unlock heroes faster by paying?**  
A: Heroes are free. Only monetization is 2x Permanent XP boost.

**Q: What if I want to just watch high-level matches?**  
A: Replay/spectator mode planned for v0.5+.

**Q: Will console ports happen?**  
A: PC/Mobile first. Console depends on success.

---

## 📜 Licences and Credits

- **Lilita One** (the display font, `Assets/Fonts/LilitaOne-Regular.ttf`):
  Copyright (c) 2011 Juan Montoreano, with Reserved Font Name "Lilita",
  from Google Fonts. Licensed under the SIL Open Font License, Version 1.1;
  the licence ships next to the font as `Assets/Fonts/LilitaOne-OFL.txt`.
  The font may be bundled and embedded in the game; it must not be sold on
  its own, and a modified version must not use the name "Lilita".
- **Open Sans SemiBold** (the body font): Godot's built-in default font,
  used through the engine and licensed with it (see Godot's
  `COPYRIGHT.txt`); no font file of it is in this repository.

---

## 📖 Version History

**v0.2** (Current) - the "Jungle Guild" overhaul:

- 4 heroes, 3 monsters (Grount, Nyxa, Gorrak), each balanced to 40-60 % hero
  wins at threat 0
- Ranked skill trees v2 (nine trees, capstones, level gates), Opponent
  Threat, monster unlocks, Earning Rates v2
- Lobby, rosters, character pages, pre-round, match HUD, match result,
  Codex, tutorial, settings in one palette and theme
- SVG rigs with authored moves, ability effects, the muted ground grade
- Headless lint, tests, balance sim, determinism trace and bench

**v0.1** - Prototype:

- 4 heroes, 1 monster, core loop functional
- Basic AI, fog of war, UI systems
- No progression systems yet

---

**END OF README**
