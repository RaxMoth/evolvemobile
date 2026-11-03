# Better Hunt - Asymmetric Auto-Battler RPG

> 📖 **[Architecture Guide](Docs/INSTRUCTOR.md)** • 📚 **[All Docs](Docs/)**

**Genre**: Asymmetric PvE Auto-Battler with Strategic Setup  
**Engine**: Godot 4.5  
**Inspiration**: Evolve (4v1 asymmetric), Underdark:Defense & Lucky Defense (art style)  
**Development Status**: Prototype (Pre-Alpha with production goals)  
**Platform**: PC & Mobile

---

## 🎮 Core Concept

**Better Hunt** is a strategic auto-battler where you command either a team of 4 heroes or a single powerful monster. Before each round, you configure your team's strategy, then watch the battle unfold in real-time. Success depends on your pre-round decisions: hero composition, skill tree investments, and tactical priorities.

**The Core Loop**: Setup → Watch → Learn → Upgrade → Repeat

---

## 🎯 Game Loop

### Round Structure (Best of 1)

**Pre-Round Phase** (Strategic Setup):

1. **Choose Side**: Heroes or Monster
2. **Configure Strategy**:
    - Hero team: Composition (4 heroes from roster), formation, exploration strategy
    - Monster: Evolution strategy, farming routes, engagement timing
3. **Spend Resources**: Allocate Steel/Leaves/Gold on permanent upgrades
4. **Start Round**: AI executes your strategy

**Round Phase** (Auto-Battle):

1. **Heroes spawn** at full strength (Level 1) in safe zone
2. **Monster spawns** weak (Stage 1) in Zone 3-4
3. **AI Executes**: Both sides follow pre-configured behavior
4. **Confrontation**: Teams clash based on strategy
5. **Victory**: One side is eliminated

**Post-Round Phase** (Rewards & Upgrade):

1. View battle summary (kills, damage, time survived)
2. Earn currencies:
    - **Steel** (Hero-specific) - Earned when playing as Heroes
    - **Leaves** (Monster-specific) - Earned when playing as Monster
    - **Gold** (Universal) - Earned by both sides
    - **Permanent XP** - Each hero/monster gains individual XP
3. **Upgrade Skill Trees**: Invest in permanent progression
4. **Next Round**: Choose side and repeat

### Win Conditions

- **Heroes Win**: Kill the monster at any stage
- **Monster Wins**: Kill all 4 heroes
- **No draws**: One side must be eliminated

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
| **River**  | Support/Scout  | 90  | 10.9 | 300   | Long-range DPS, Healing, Vision |
| **Vlad**   | DPS/Berserker  | 100 | 10.0 | 50    | High melee DPS, execution       |
| **Ted**    | DPS/Pet Master | 95  | 15.0 | 55    | Sustained DPS with pet          |
| **Irelia** | Tank/Support   | 150 | 3.3  | 120   | Tank, shields, monster taunt    |

**Combined Level 1 Team DPS**: ~35 DPS

### Hero Details

#### River (Support/Scout)

- **Base Stats**: 100 HP, 85 speed, 300 vision range
- **Passive**: Mode Switch (Sniper ↔ Healer)
- **Active**: Snare Trap (15 dmg, roots enemies)
- **Basic Attack**:
    - Sniper Mode: 12 dmg at 300 range / 1.1s
    - Healer Mode: 9 heal at 150 range / 1.4s
- **Ultimate**: Arrow Barrage (40 dmg, 200 AoE)
- **Scaling**: +5 HP, +1.8 dmg per level

#### Vlad (DPS/Berserker)

- **Base Stats**: 110 HP, 80 speed, 250 vision
- **Passive**: Bloodlust (Below 30% HP: +50% dmg, +100% attack speed)
- **Active**: Land Mine (18 dmg explosion)
- **Basic Attack**: 10 dmg at 50 range / 1.0s
- **Ultimate**: Blood Bomb (50 dmg, 150 AoE)
- **Scaling**: +6 HP, +1.7 dmg per level

#### Ted (DPS/Pet Master)

- **Base Stats**: 105 HP, 85 speed, 220 vision
- **Pet Stats**: 50 HP, 9 dmg, 60 range, 1.2s cooldown
- **Passive**: Loyal Companion (pet respawns after 10s)
- **Active**: Rally Cry (+50% attack speed for 5s)
- **Basic Attack**: 9 dmg at 55 range / 1.2s
- **Ultimate**: Trap Cage (150 radius, traps enemies for 6s)
- **Scaling**: +5 HP, +1.6 dmg per level
- **Combined DPS** (Ted + Pet): ~15.0 DPS

#### Irelia (Tank/Support)

- **Base Stats**: 160 HP, 75 speed, 200 vision
- **Passive**: Regeneration (0.5 HP/s)
- **Active**: Divine Shield (18 HP shield to all heroes, 7s duration)
- **Basic Attack**: 5 dmg at 120 range / 1.5s
- **Ultimate**: Monster Taunt (Forces monster to attack Irelia for 5s)
- **Scaling**: +8 HP, +1.2 dmg per level

### Hero Leveling (In-Round)

- **XP Sources**: Bat (6 XP), Hog (15 XP)
- **XP Required**: ~80 XP per level
- **XP Radius**: 800 units (50-100% based on distance)
- **Scaling**: Slow growth favors early aggression

---

## 🐂 Monster (Grount - The Bull)

### Stage Evolution System

| Attribute        | Stage 1 (Vulnerable) | Stage 2 (Dangerous) | Stage 3 (Apex Predator) |
| ---------------- | -------------------- | ------------------- | ----------------------- |
| **HP**           | 800                  | 1400 (+600 heal)    | 2200 (+800 heal)        |
| **Speed**        | 60                   | 80 (+33%)           | 110 (+83%)              |
| **Damage Mult**  | 1.0x                 | 1.4x                | 2.0x                    |
| **Attack Range** | 80 (flat × Monster Base range skill) | 80 | 80                 |
| **XP Required**  | Start                | 150 XP              | 300 XP                  |

### Abilities

#### Front Cleave (Ability 1)

| Stage | Damage | Cooldown | Cone Angle | Description          |
| ----- | ------ | -------- | ---------- | -------------------- |
| 1     | 12     | 4.5s     | 50°        | Basic frontal cleave |
| 2     | 17     | 3.0s     | 60°        | Faster, wider        |
| 3     | 12     | 1.8s     | 75°        | Rapid, massive cone (lighter hits, highest DPS) |

#### Ram Dash (Ability 2)

| Stage | Damage | Cooldown | Range | Description               |
| ----- | ------ | -------- | ----- | ------------------------- |
| 1     | 18     | 12.0s    | 300   | Charge forward, knockback |
| 2     | 25     | 8.0s     | 300   | Faster cooldown           |
| 3     | 36     | 5.0s     | 300   | Spam dash                 |

#### Ground Slam (Ability 3 - Ultimate)

| Stage | Damage | Cooldown  | Radius | Description             |
| ----- | ------ | --------- | ------ | ----------------------- |
| 1     | -      | 🔒 LOCKED | -      | Not available           |
| 2     | 32     | 15.0s     | 120    | Unlocked: Jump and slam |
| 3     | 25     | 9.0s      | 180    | Massive AoE, faster recast |

### Evolution Mechanics

- **Healing on Evolution**: Gains (new max HP - old max HP). The tuned build refills HP on evolution
  instead (`MonsterBase.heal_to_full_on_evolution = true`; false = this README rule) — open decision
- **Visual Changes**: Orange tint (Stage 2), Red glow (Stage 3)
- **Screen Shake**: Alerts players to evolution
- **Ability Unlocks**: Ground Slam unlocks at Stage 2

### XP Sources (Monster)

- **Bat**: 8 XP per kill
- **Hog**: 25 XP per kill
- **Elite Hog**: 50 XP per kill
- **Collection Radius**: 600 units (instant collection)

**Farming Path to Stage 3**:

- Option 1: 19 Bats (152 XP) → Stage 2, then 10 Hogs (250 XP) → Stage 3
- Option 2: 6 Hogs (150 XP) → Stage 2, then 10 Hogs (250 XP) → Stage 3
- Option 3: 3 Elite camps (150 XP) → Stage 2, then 5 Elite camps (250 XP) → Stage 3
- **Time Required**: ~5-7 minutes to reach Stage 3 (if undisturbed)

---

## 🗺️ Map Design - "Primal Jungle" (9200x5185)

### Zone Layout

```
╔═══════════════════════════════════════════════════════════════╗
║  ZONE 1: Hero Spawn (0-2000)                                  ║
║  └─ Safe area, team formation                                 ║
╠═══════════════════════════════════════════════════════════════╣
║  ZONE 2: Bat Territory (2000-3500)                            ║
║  └─ 4-5 Bat camps (6 XP each, 5-6 per camp)                  ║
║  └─ Light farming zone for heroes                             ║
╠═══════════════════════════════════════════════════════════════╣
║  ZONE 3: Mixed Territory (3500-5500) ⚠️ CONTESTED             ║
║  └─ 3 Bat camps + 2 Hog camps                                 ║
║  └─ Monster spawn location (random in zone)                   ║
║  └─ First contact probability: HIGH                           ║
╠═══════════════════════════════════════════════════════════════╣
║  ZONE 4: Hog Territory (5500-7000) 🐗 MONSTER PARADISE        ║
║  └─ 4-5 Hog camps (15/25 XP each, 3-4 per camp)              ║
║  └─ 1 Elite camp (50 XP each, 2 per camp)                    ║
║  └─ Monster farming priority                                  ║
╠═══════════════════════════════════════════════════════════════╣
║  ZONE 5: Deep Jungle (7000-9200) 🌲 ENDGAME                   ║
║  └─ 2 Elite camps (high risk/reward)                          ║
║  └─ Dense fog of war                                          ║
║  └─ Stage 3 monster hunting grounds                           ║
╚═══════════════════════════════════════════════════════════════╝
```

### Mob Camps

| Type           | HP  | Damage | Cooldown | Camp Size | Hero XP | Monster XP | Total XP (Monster) |
| -------------- | --- | ------ | -------- | --------- | ------- | ---------- | ------------------ |
| **Bat Camp**   | 25  | 5      | 0.6s     | 5-6       | 6       | 8          | 40-48 XP           |
| **Hog Camp**   | 100 | 10     | 1.0s     | 3-4       | 15      | 25         | 75-100 XP          |
| **Elite Camp** | 180 | 15     | 0.9s     | 2         | 50      | 50         | 100 XP             |

**Total Map XP** (for monster):

- Bats: ~300-350 XP (7-8 camps)
- Hogs: ~400-500 XP (5-6 camps)
- Elites: ~200 XP (2 camps)
- **Total Available**: ~900-1050 XP (more than enough for Stage 3)

### Spawn System

- **MobSpawnArea**: 39 circular camps (116 mobs configured). `SpawnManager` picks 26–30 of them as world-eligible per match and only instantiates a camp while a hero is inside its activation ring (200 px; despawn beyond 300 px)
- **Respawn Time**: 40 s on every camp in `World.tscn` (prefab default 10 s). Dead and despawned mobs are recycled from a pool instead of re-instantiated
- **Leash Distance**: Mobs return if heroes run too far (100 px from the camp centre)
- **Camp Clearing**: Important strategic decision (delay monster vs gain XP)

---

## 📊 Balance Sheet - Target Win Rates

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

- Increase monster XP gains (10 → 12 per Bat, 30 → 35 per Hog)
- Reduce Stage 2 threshold (150 → 120 XP)
- Buff Stage 2 stats (+100 HP, +10 speed)

**If Heroes Win <45%**:

- Increase hero starting stats (+10 HP each)
- Improve hero level scaling (+1 dmg per level)
- Reduce monster Stage 3 damage multiplier (2.0x → 1.8x)

**If Matches Too Long (>10 min)**:

- Reduce map size or add shortcuts
- Increase movement speeds (+10-15 for both sides)
- Buff damage across the board (+20%)

**If Matches Too Short (<4 min)**:

- Increase all HP pools (+20%)
- Reduce damage (-15%)
- Add more escape/kiting abilities

---

## 🎨 Visual Systems

### Art Style: Lineart Mobile Game

**Reference Games**:

- Underdark: Defense
- Lucky Defense

**Aesthetic Goals**:

- Clean lineart with minimal shading
- Vibrant, readable silhouettes
- Hand-crafted sprite work (artist: You)
- Tower Defense-style readability
- Mobile-friendly UI elements

### Fog of War System

- **Grid**: 2000x2000 overlay on 32px tilemap
- **Reveal Radius**: 200-300 units (hero-dependent)
- **Persistence**: Once revealed, stays visible
- **Rendering**: World-space Node2D (not screen-space)
- **Purpose**: Strategic scouting value, monster can hide

### Hero UI Container

- **Position**: Bottom of screen, fixed to camera
- **Layout**: 4 hero panels (River, Vlad, Ted, Irelia)
- **Per Panel**:
    - Hero name label
    - Portrait (60x60)
    - Health bar (color-coded: >50% green, >25% yellow, <25% red)
    - 4 ability icons (30x30, dimmed during cooldown)
- **Real-time Updates**: Health changes, cooldown tracking

### Combat Visuals (Planned)

- Ability effect particles (slash lines, explosions)
- Damage numbers
- Screen shake on heavy hits
- Evolution transformation effects
- Death animations

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

**Planned Improvements**:

- Scent tracking / strategic retreat / mob command (skill-tree unlocks)

### Combat AI (Both Sides)

**Current**:

- Basic attack when in range
- Ability usage: On cooldown if valid target
- Movement: Chase or flee based on health

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
│  ├─ Hog (ground, tanky)
│  └─ EliteHog (rare, high XP)
└─ MonsterBase
   └─ Grount (3-stage evolution bull)
```

### Component Systems

#### HeroStatsComponent

**Purpose**: Runtime stat tracking and leveling

```gdscript
- base_stats: HeroStats (resource)
- current_stats: Stats (runtime values)
- level: int
- current_xp: int
- xp_for_next_level: int

Methods:
- add_experience(amount: int)
- level_up()
- _recalculate_all_stats()
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
- use_ability(slot: String)
- update_cooldowns(delta: float)
```

#### State Machine (godotstatecharts)

**States**:

- Idle: Wander, retarget
- Approach: Navigate to target
- Fight: In combat, use abilities
- Dead: Cleanup (mobs return to the spawn pool; a `reset` event brings them back to Idle)

The chart owns all state. Its active state is **stepped** by the `TickScheduler` autoload (`StateChart.step()` → `state_stepped`) at a per-entity LOD rate instead of running `state_processing` every frame.

### Resource Architecture

**Separation of Concerns**:

- **HeroStats** (Resource): Immutable base data (max_health, base_damage)
- **HeroStatsComponent** (Node): Mutable runtime (current_health, level)
- **AbilityBase** (Resource): Ability data and execute logic

### File Structure

```
res://
├─ Scenes/
│  ├─ NPCs/
│  │  ├─ Hero/
│  │  │  ├─ Heros/
│  │  │  │  ├─ DMG/Vlad/
│  │  │  │  ├─ Support/River/
│  │  │  │  ├─ Support/Ted/
│  │  │  │  └─ Support/Irelia/
│  │  │  ├─ hero_stats.gd (resource)
│  │  │  └─ stat_component.gd (node)
│  │  ├─ Mob/
│  │  │  ├─ bat/Bat.tscn
│  │  │  ├─ hog/Hog.tscn
│  │  │  └─ mobs_base_class.gd
│  │  └─ Monster/
│  │     └─ Grount/
│  │        ├─ grount.gd (evolution system)
│  │        └─ abilities/
│  ├─ World/
│  │  ├─ FogOfWar/
│  │  └─ MobSpawnArea/
│  └─ UI/
│     ├─ MainMenu.tscn
│     └─ HeroContainer/
└─ Scripts/
   └─ Systems/
      ├─ ability_system.gd
      └─ hero_exploration_controller.gd
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

### Earning Rates (Per Round)

**Base Rewards**:

- Win: 100 currency + 50 Gold
- Loss: 50 currency + 25 Gold

**Performance Bonuses**:

- Kills: +10 per enemy killed
- Survival Time: +5 per minute
- Stage Reached (Monster): +25 per stage
- Heroes Alive (Heroes): +15 per survivor

**Example**:

- Heroes win at 8 minutes with 3 survivors after killing 40 mobs + Stage 2 monster
- Earn: 100 (win) + 50 (gold) + 400 (kills) + 40 (time) + 45 (survivors) = **635 Steel + 50 Gold**

### Skill Tree Structure

#### Hero Base Tree (Costs Gold)

**Universal upgrades for ALL heroes**:

**Tier 1** (0-500 Gold):

- +5% Max HP
- +5% Move Speed
- +5% Vision Range

**Tier 2** (500-1500 Gold):

- +10% Damage
- +10% Cooldown Reduction
- Unlock: Team XP Share (20% of nearby hero XP)

**Tier 3** (1500-3000 Gold):

- +15% Max HP
- +10% Attack Speed
- Unlock: Rally Point (Can set waypoint during round)

**Tier 4** (3000+ Gold):

- +20% Damage
- Start Level 2 (skip Level 1)
- Unlock: Retreat Command (Heroes flee when low HP)

#### Individual Hero Trees (Costs Steel)

**Each hero has unique tree**:

**River Tree** (Example):

**Tier 1**:

- +50 Sniper Range (300 → 350)
- +2 Heal Amount (9 → 11)
- -1s Trap Cooldown

**Tier 2**:

- Unlock: Triple Shot (Basic attack hits 3 targets)
- +1 Arrow in Barrage (8 → 9 arrows)
- Trap Slows Enemies (-30% speed for 3s)

**Tier 3**:

- Auto-Switch Mode (swaps to heal if ally <50% HP)
- Barrage Applies Slow (-50% speed for 2s)
- +100% Trap Damage (15 → 30)

**Tier 4**:

- Ultimate: Sniper's Nest (River gains +100 range, +50% dmg when stationary)
- Unlock: Second Passive (Choose new passive ability)

**Permanent XP** (Per Hero):

- Earn XP for that hero every round played
- Unlock tree nodes at XP milestones
- Encourages hero specialization

#### Monster Base Tree (Costs Gold)

**Universal for ALL monsters**:

**Tier 1** (0-500 Gold):

- +10% Max HP (all stages)
- +5% Move Speed
- +10% XP Gain from Mobs

**Tier 2** (500-1500 Gold):

- -10% Stage Evolution Requirements (150/400 → 135/360)
- +15% Damage (all stages)
- Unlock: Scent Tracking (See hero positions every 30s)

**Tier 3** (1500-3000 Gold):

- +20% Max HP
- +10% Ability Range
- Unlock: Strategic Retreat (Can flee combat at <30% HP)

**Tier 4** (3000+ Gold):

- Stage 4 Unlocked (Godlike final form)
- Start Stage 2 (skip Stage 1)
- Unlock: Mob Command (Nearby mobs fight for you)

#### Individual Monster Trees (Costs Leaves)

**Grount Tree** (Example):

**Tier 1**:

- +100 HP per Stage (800/1400/2200 → 900/1500/2300)
- -0.5s Cleave Cooldown
- Ram Dash Stuns (0.5s stun on hit)

**Tier 2**:

- Ground Slam Unlocks at Stage 1
- +10° Cleave Cone Angle
- Ram Dash Distance +100 (300 → 400)

**Tier 3**:

- Stage 2 Evolution Heal +200 HP — *wired as "Second Wind", not in the tree yet: evolution currently
  refills HP, so +200 would heal nothing (see Evolution Mechanics)*
- Ground Slam Pulls Enemies (200 radius pull) — **Gravity Slam**: at impact, living heroes, Ted's pet
  and mobs within 200 px are dragged to 80 px from the impact along the nav mesh (walls stop them),
  then the slam damage lands
- Enrage at <20% HP (+30% speed, +50% dmg) — **Enrage**: move speed and every cast; ends as soon as
  HP is back at 20% of max (rest regen, evolution heal)

**Tier 4**:

- Ultimate: Titan Form (Stage 3: +50% size, +500 HP, +20 range) — **Titan Form** (2000 Leaves): x1.5
  scale on top of the stage-3 scale (aggro radius unchanged), +500 flat max HP (healed on reaching
  Stage 3), +20 flat attack range, Front Cleave reach and Fight leave distance
- Unlock: Second Ultimate Ability

**Permanent XP** (Per Monster):

- Separate XP per monster type
- Specialization encouraged

### Monetization (Future)

**Double XP Boost** (Premium Purchase):

- Doubles permanent XP gained per round
- Does NOT affect Steel/Leaves/Gold
- One-time purchase, permanent effect

---

## 🎮 Player Experience Flow

### First-Time Player Journey

**Round 1** - Tutorial (Auto-Play):

1. Game auto-selects Heroes side
2. "Your heroes will now hunt the monster. Watch and learn!"
3. Heroes rush aggressively, find Stage 1 monster at 2 minutes
4. Easy victory (70% win rate scenario)
5. **Rewards**: 100 Steel, 50 Gold
6. "You can now spend Steel on hero upgrades!"

**Round 2** - First Strategy Decision:

1. Player chooses: Heroes or Monster?
2. If Heroes: Can now select 4 heroes from roster (Currently only 4, so no choice yet)
3. If Monster: Play as Grount
4. "Configure your strategy..." (simple sliders for aggression/farming balance)
5. Watch AI execute strategy
6. Learn from outcome

**Round 3-5** - Learning Phase:

- Experiment with both sides
- Earn currencies, start upgrading skill trees
- Discover synergies (e.g., Vlad's Bloodlust is strong in late fights)

**Round 10+** - Mastery:

- Deep tree investments create unique playstyles
- Permanent XP unlocks powerful nodes
- Meta strategies emerge (rush comps vs late-game comps)

### Engagement Loops

**Short Loop** (Per Round - 5-10 min):

```
Setup (1 min) → Watch Battle (4-8 min) → Rewards (30s) → Upgrade (1 min)
```

**Medium Loop** (Per Session - 30-60 min):

```
Play 5-10 rounds → Complete daily quests → Major skill tree progress
```

**Long Loop** (Per Week/Month):

```
Max out hero trees → Unlock new heroes → Compete on leaderboards
```

---

## 🚧 Current Status & Roadmap

### ✅ Implemented (Prototype v0.1)

**Core Gameplay**:

- [x] 4 unique heroes with abilities
- [x] Grount monster with 3-stage evolution
- [x] XP and leveling systems (in-round)
- [x] Asymmetric power curve

**Combat**:

- [x] 4-slot ability system
- [x] Cooldown management
- [x] Damage calculation and stat scaling
- [x] Pet system (Ted's companion)

**AI**:

- [x] Hero exploration (boids flocking)
- [x] Monster hunting behavior
- [x] Target acquisition and combat
- [x] Spawn area leashing for mobs

**Visuals**:

- [x] Fog of war (world-space)
- [x] Hero UI container with real-time stats
- [x] Health bars
- [x] Ability cooldown indicators

**Map**:

- [x] 9200x5185 map with 5 zones
- [x] Bat/Hog/Elite mob camps
- [x] XP award system

**Meta & Flow** (since v0.1):

- [x] Main Menu with side selection, Settings (volumes) and the Meta Skill screen
- [x] Match result screen (stats, currency + permanent XP rewards, Play Again / Main Menu)
- [x] Hero Base + Monster Base skill trees (MetaSkillManager, applied on spawn), ConfigFile save
- [x] Permanent XP per hero/monster with level readout on the menu cards
- [x] 10-minute match cap (loss-condition timer)
- [x] Side-aware fog/vision (playing the monster reveals for the monster)
- [x] Performance pass: faction collision layers, EntityRegistry, TickScheduler AI LOD, HpBar2D, mob pooling
- [x] Per-hero (Steel) and per-monster (Leaves) skill trees — stat nodes and ability-modifying nodes, applied on spawn
- [x] First-run tutorial overlay + "How to play" button
- [x] Versioned save file with automatic backup + migration
- [x] Audio manager on the Master/Music/SFX buses (generated placeholder tones until real assets land in `Assets/Audio/`)
- [x] Local analytics log (`user://analytics.jsonl`, opt-out in Settings)
- [x] Pre-round setup screen (aggression / farming / exploration / formation) driving the hero AI
- [x] Minimap with fog overlay and side-fair entity dots
- [x] Localization scaffold (English + German, language setting)
- [x] Headless test suite — `tools/run_tests.sh` (47 tests) + `tools/lint.sh`

---

### 🚧 In Development (v0.2 - Next 2 Months)

**High Priority**:

- [ ] **Behaviour-changing skill nodes** — shipped: Grount "Stunning Charge" (Ram Dash stuns 0.5 s),
      "Early Slam" (Ground Slam at Stage 1), "Gravity Slam" (200 px pull), "Enrage" (<20% HP: +30%
      speed, +50% dmg), "Titan Form" (T4); River "Triple Shot" (sniper shots hit 2 more enemies).
      Open: "Second Wind" (needs the evolution-heal decision), trap/barrage slows (River's README kit
      — Snare Trap, Arrow Barrage — differs from the shipped Weapon Swap / Supply Drop), second
      ultimate
- [ ] **Device build** — export presets, measure the perf pass on a mid-range phone, retune the
      shrunken aggro / AoE ranges from the collision-layer split
- [ ] **Real audio assets** — drop `.ogg`/`.wav` files into `Assets/Audio/` (keys in its README)

**Medium Priority**:

- [ ] **Improved AI Behaviors** (2 weeks)
    - [x] Monster: Hide & Farm / Rest / Ambush / Hunt strategy layer + combo logic
    - [x] Heroes: role-ranked formation (tank leads), call-for-help, focus fire, auto-used actives
    - [ ] Heroes: threat assessment (flee from a Stage 3 monster)
- [ ] **Pre-Round Setup — visual strategy preview** (the sliders and formation picker ship; a preview of the resulting behaviour does not yet)

**Low Priority** (v0.2):

- [ ] Audio content (buses + volume settings exist; no music/SFX assets yet)
- [ ] Pinch-zoom / tap-to-focus on the match camera, `print()` gating, debug keys behind `OS.is_debug_build()`

---

### 📅 Future Versions

#### v0.3 (3-4 months) - Content Expansion

- [ ] 2 new heroes (Archer, Mage archetypes)
- [ ] 1 new monster (Swarm-based: Spider Queen)
- [ ] Hero skill trees (Tier 3-4 nodes)
- [ ] More mob types (Ranged bats, Charging rhinos)
- [ ] Basic particle effects

#### v0.4 (5-6 months) - Polish & Balance

- [ ] Full skill trees for all characters
- [ ] 10+ heroes total
- [ ] 3+ monsters total
- [ ] Advanced AI (split strategies, baiting)
- [ ] Animated sprites (basic)
- [ ] Sound design pass

#### v0.5 (7-9 months) - Pre-Alpha Release

- [ ] 15+ heroes
- [ ] 5+ monsters
- [ ] Multiple maps (2-3)
- [ ] Daily quests & challenges
- [ ] Leaderboards (local)
- [ ] Tutorial mode
- [ ] Full art pass (lineart style)

#### v1.0 (12+ months) - Public Alpha

- [ ] 30+ heroes (goal)
- [ ] 8+ monsters
- [ ] Online leaderboards
- [ ] Seasonal content
- [ ] Mobile port
- [ ] Monetization (2x XP boost)

---

### 🔧 Known Issues & Tech Debt

**Bugs**:

- [ ] Pet sometimes doesn't respawn if Ted dies during respawn timer
- [x] Fog of war flickered at the screen edge — fixed: the fog quad is static and world-covering
      (it chased the camera a frame late), the world size snaps to whole tiles, and outside the map
      is always fogged
- [ ] Monster stuck in corners — code side fixed (dashes and slam leaps stop at walls, idle re-picks
      an unreachable goal, fleeing slides along walls); the map still has 39 isolated one-tile
      navigation islands to repaint in `World.tscn`
- [x] Heroes parked at the map edge for minutes (off-map fog counted as unexplored) and agents
      stranded far behind their group (paths cut off at the engine's 4096-polygon search budget on
      the per-tile navigation map) — fixed
- [x] Ted's pet could not be targeted by mobs or the monster and chased targets across the map —
      it now has a hitbox on the hero layer and a 350 px leash to Ted
- [x] Hero UI cooldown overlays drifted from the real cooldown (attack-speed boosts, pause, recasts)
      — fixed: the panel reads `AbilitySystem.get_cooldown_progress()` every frame

**Performance**:

- [ ] 60 fps @ 150 mobs on a mid-range phone — code side landed 2026-10-14 (see `PROGRESS.md`); device
      measurement and the balance retune of the now-smaller aggro / AoE ranges are pending
- [x] Fog of war recalculated every frame — fixed (dirty flag, one texture update per frame)
- [x] One navigation region per Ground tile (~38,000) made every path query cost ~3–5 ms — fixed:
      the walkable area is baked into one `NavigationRegion2D` ("Navigation",
      `Scenes/World/world_navigation.tres`, ~2,100 polygons). After editing the Ground tiles, re-bake
      with `tools/bake_nav.sh` or the editor's Bake NavigationPolygon button (a test fails on a
      stale bake). Stress config (232 mobs, headless): frame time 30.6 → 2.1 ms, p99 185 → 5.4 ms

**Balance**:

- [ ] Monster Stage 3 may be too strong (needs more playtesting)
- [ ] Vlad's Bloodlust is overpowered in 1v1 scenarios
- [ ] Irelia's regen too weak early game

**Design Debt**:

- [x] Loss-condition timer — 10-minute match cap in `GameManager`
- [ ] Hero composition is fixed (can't choose which 4 heroes yet)
- [ ] Monster spawn location is random within Zone 3 (should it become a strategic choice?)
- [ ] Evolution refills the monster's HP, while this README says "new max HP - old max HP": decide
      which rule ships (`MonsterBase.heal_to_full_on_evolution`), then seed Grount's "Second Wind"
      (`MetaSkillManager.GROUNT_SECOND_WIND_SPEC`)

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
    - Clean lineart, minimal VFX spam
    - Information clarity > flashy effects

### Design Constraints

**Mobile-Friendly**:

- Touch controls must work (tap to command)
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
**Tools**: Godot 4.5, Aseprite (art), GitHub (version control)

---

## 📚 Appendices

### A. Monster Evolution Math

**Stage 1 → Stage 2** (150 XP):

- 19 Bats (152 XP) - Takes ~2-3 min
- 6 Hogs (150 XP) - Takes ~2-3 min
- 3 Elite Hogs (150 XP) - Takes ~2 min (risky)

**Stage 2 → Stage 3** (250 XP):

- 32 Bats (256 XP) - Takes ~3-4 min
- 10 Hogs (250 XP) - Takes ~3-4 min
- 5 Elite Hogs (250 XP) - Takes ~2-3 min

**Full Evolution** (400 XP total):

- Optimal path: 3 Elite camps → Stage 2 → 5 more Elite camps → Stage 3 (~4-5 min)
- Safe path: 6 Hogs → Stage 2 → 10 Hogs → Stage 3 (~6-7 min)

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
- **Permanent XP**: Out-of-round progression currency
- **Steel**: Hero-specific upgrade currency
- **Leaves**: Monster-specific upgrade currency
- **Gold**: Universal upgrade currency
- **Stage**: Monster evolution level (1-3)
- **Level**: Hero in-round power (1-10)
- **Boids**: Flocking algorithm for group movement
- **Leashing**: Mobs returning to spawn area
- **Fog of War**: Vision/exploration system

---

## ❓ FAQ

**Q: Can I control heroes/monster during the round?**  
A: Not in v0.1. Future versions will add mid-round commands.

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

## 📖 Version History

**v0.1** (Current) - Prototype:

- 4 heroes, 1 monster, core loop functional
- Basic AI, fog of war, UI systems
- No progression systems yet

---

**END OF README**
