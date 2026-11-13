# Better Hunt - AI Agent Instructor Guide

How the code is built and how to change it. The design spec (every number,
every screen, every tool) is the root [`README.md`](../README.md); the work
queue, open decisions and the changelog are [`PROGRESS.md`](../PROGRESS.md).
This guide is the short way in: the rules, the patterns, where things live
and the checklists for adding content.

## 🎯 Project Mission

Better Hunt is a mobile-first asymmetric auto-battler RPG inspired by Evolve's 4v1 gameplay. Players control either 4 AI heroes or a single evolving monster in strategic, setup-driven battles. The game emphasizes **"Strategy Over Execution"** - players configure their approach before each round, then watch AI execute their plan.

Godot 4.7, GDScript, Mobile renderer, portrait 720x1280. Three monsters
(Grount, Nyxa, Gorrak), four heroes (Irelia, Vlad, Ted, River), ranked skill
trees, the "Jungle Guild" look (one palette, one theme, SVG rigs).

---

## 🏆 Development Priorities (CRITICAL - READ FIRST)

Max's priorities in order of importance:

### 1. **Maintainability** (Highest Priority)
- **Clean, readable code** over clever optimizations
- **Clear separation of concerns** - composition over inheritance
- **Consistent patterns** across the codebase
- **Self-documenting code** with meaningful names
- **Comments for "why", not "what"**

### 2. **Future-Proofing**
- **Resource-based data** - keep game data in .tres files, not hardcoded
- **Virtual methods** for polymorphism, not type-checking
- **Signal-based communication** between systems
- **Avoid tight coupling** - systems should be loosely connected
- **Design for extension** - new heroes/abilities/monsters should slot in easily

### 3. **Scalability**
- **Performance from day one** - lazy loading, LOD systems, object pooling
- **Component-based architecture** - systems should scale independently
- **Data-driven design** - adding content shouldn't require code changes
- **Mobile constraints** - design for limited memory/processing power

### 4. **Performance**
- **Measure before optimizing** - `tools/bench.sh` and F3, don't guess
- **Optimize hot paths** - focus on code that runs every frame
- **Lazy evaluation** - don't spawn/process what isn't needed
- **Batch operations** - group similar work together

---

## 📏 House Rules (every change follows these)

1. **Godot-native, scene-side wiring.** Exports, groups, `process_mode` and
   signal connections live in the `.tscn`, not in `_ready`. A connection in
   code is the exception (an autoload cannot be the source of a scene
   `[connection]`).
2. **One state machine.** Entity AI state lives in the `godot_state_charts`
   chart of `NPCBaseClass.tscn`. Never add flags or a second FSM that mirror
   it; ask the chart (`is_scattered()` asks the state).
3. **No `print()` debugging.** Debug information goes to the F3 overlay
   (`Scenes/World/Camera/debug_overlay.gd`: `debug_meta_line`, `debug_tag`,
   `debug_line`); logs go through `Globals.debug_log`.
4. **Zero GDScript warnings.** `maxf / minf / clampf / absf / maxi / mini`,
   no `:=` on a Variant, typed results of `Dictionary.get`, unused parameters
   prefixed `_`, no local that shadows a base member (`name`, `scale`,
   `position`, `owner`), no unused signal or variable, no static call through
   an instance.
5. **Per-instance individuality.** Abilities are copied per entity
   (`AbilitySystem.make_abilities_unique`, `MonsterBase._make_abilities_unique`);
   a shared `.tres` is never mutated at runtime.
6. **The global RNG is gameplay.** Anything visual or menu-side uses its own
   `RandomNumberGenerator`; one extra `randf()` on the global one changes
   every match (and the determinism trace).
7. **No colour literals in the UI.** Colours come from `UiPalette` tokens and
   theme type variations (`tools/lint.sh` checks `Scenes/UI`).
8. **Generated files are never edited by hand**: the UI kit, the theme, the
   palette resource, rig sheets and bodies. Edit the source and rebuild
   (see Tools).
9. **Never run Godot on the project directory from a script or an agent**
   (the editor may have it open). The tools work on temp copies with their own
   `user://`. Every non-headless run (renders, probes) gets
   `--audio-driver Dummy`.
10. **README is the spec.** A change that alters a number or a rule updates
    the README section in the same commit; `test/test_readme_spec.gd` checks
    the tables against the data.

---

## 📋 Core Design Principles

### Strategy Over Execution
- No real-time player control during battles (the player follows a hero and zooms)
- Pre-round configuration: quarry or monster, strategy dials, formation
- AI executes the player's plan
- Victory through smart preparation, not quick reflexes

### Asymmetric Power Curves
- **Heroes**: start strong (~39 DPS combined), grow slowly (100 XP per level)
- **Monster**: starts weak (Grount Stage 1: 800 HP), evolves twice (Stage 3: 2200 HP)
- **Balance target**: 40-60 % hero wins per monster on both sides (48 seeds, `tools/sim.sh`)

### Permanent Progression
- Every round earns Steel / Leaves / Gold and permanent XP
- Ranked skill trees between matches; the AI opponent's build grows with the
  player's ranks (Opponent Threat)
- All systems feed the loop: **Setup → Watch → Upgrade**

---

## 🏗️ Architecture Overview

### Where things live

The full tree is in the README ("File Structure"). The short version:

```
res://
├── Scenes/
│   ├── NPCs/
│   │   ├── npc_base_class.gd + NPCBaseClass.tscn   (EntityBase: chart, Rig, HP bar)
│   │   ├── roster.tres                              (Roster: every playable character)
│   │   ├── Hero/      hero_base_class.gd, hero_stats.gd, stat_component.gd,
│   │   │              hero_exploration_controller.gd, Abilities/, Heros/<role>/<Hero>/
│   │   ├── Mob/       mobs_base_class.gd + .tscn, Mobs/Bat, Mobs/Hog
│   │   └── Monster/   monster_base_class.gd + .tscn, monster_stats.gd,
│   │                  Grount/, Nyxa/, Gorrak/ (scene + stats + strategy + abilities/)
│   ├── World/         World.tscn, world.gd, spawns.gd (SpawnManager), monster_slot.gd,
│   │                  Camera/ (MainCam, DebugOverlay), FogOfWar/, MobSpawnArea/
│   └── UI/            Screens/ (MenuRoot + the menu screens), Hud/ (MatchHud),
│                      Components/, Widgets/, Minimap/, Settings/, Tutorial/, Theme/
├── Scripts/           autoloads and shared systems (below), MetaSkills/, Progression/,
│                      Rig/, Roster/, UI/, Vfx/
├── Assets/            Characters/<id>/ (rig source + generated sheet, body, def),
│                      UI/ (generated kit), Vfx/ (sprites + recipes), Fonts/, Locale/
├── Data/SkillTrees/   the nine skill trees as resources
├── test/              the headless suite
└── tools/             lint, tests, sim, trace, bench and the generators
```

### Autoloads (`project.godot`, in load order)

| Autoload | File | Job |
|---|---|---|
| `Globals`, `Types`, `GameUtils`, `CombatEvents` | `Scripts/globals.gd`, `Scripts/types.gd`, `Scripts/game_utils.gd`, `Scripts/combat_events.gd` | flags and `debug_log`, enums, layer / mask constants and targeting rules, the chart's event names |
| `EventBus` | `Scripts/event_bus.gd` | the damage pipeline and the global combat signals |
| `TeamRegistry` | `Scripts/team_registry.gd` | teams and their `TeamBlackboard` threat tables |
| `EntityRegistry` | `Scripts/entity_registry.gd` | cached faction lists, nearest / count queries, singletons by group |
| `TickScheduler` | `Scripts/tick_scheduler.gd` | steps every entity's chart at its LOD rate |
| `PersistedData` | `Scripts/persisted_data.gd` | the versioned save (currencies, XP, ranks, settings, owned monsters, codex) |
| `MetaSkillManager` | `Scripts/MetaSkills/meta_skill_manager.gd` | skill trees, ranks, gates, capstones, threat and AI builds |
| `GameManager` | `Scripts/game_manager.gd` | match flow and match speed, side, selected monster, quarry, rewards |
| `AudioManager` | `Scripts/audio_manager.gd` | pooled SFX and music |
| `AnalyticsSink` | `Scripts/analytics_sink.gd` | the local event log |

`VfxManager` and `AbilityVfx` are nodes of `World.tscn`, not autoloads: they
live and die with the match.

### Class Hierarchy

```
EntityBase (npc_base_class.gd)
├─ HeroBase (hero_base_class.gd)
│  ├─ River, Ted, Irelia (small subclasses that override a few virtuals)
│  └─ Vlad (the scene uses HeroBase as it is)
├─ MobBase (mobs_base_class.gd)
│  └─ Bat, Hog (scenes that inherit mobs_base_class.tscn, no script of their own)
└─ MonsterBase (monster_base_class.gd)
   └─ Grount, Nyxa, Gorrak (scenes that inherit monster_base_class.tscn:
      stats + strategy + ability resources, no subclass)

TedsPet (CharacterBody2D, not an EntityBase: Ted's fox, on the hero layer)
```

---

## 🧩 Key System Patterns

### 1. Component-Based Architecture

**Pattern**: Composition over inheritance for stats and abilities.

```gdscript
// ✅ CORRECT - Component composition
HeroBase (behavior)
├─ HeroStatsComponent (runtime state)
│  └─ HeroStats (resource - immutable data)
└─ AbilitySystem (ability management)
   ├─ passive_ability: AbilityBase
   ├─ active_ability: AbilityBase
   ├─ basic_attack: AbilityBase
   └─ ultimate_ability: AbilityBase

MonsterBase (behavior, evolution, strategy layer)
├─ monster_stats: MonsterStats (per-stage data)
├─ strategy_profile: MonsterStrategy (the AI's numbers)
└─ passive_ability, ability_1..3: AbilityBase (per-stage tables)

// ❌ WRONG - Inheritance hell
HeroBase
└─ HeroWithStats
   └─ HeroWithAbilities
      └─ River (deeply nested, hard to modify)
```

**Why**: New heroes, abilities and monsters don't require new inheritance chains. A new monster is a scene plus data, with at most one new ability script.

### 2. Resource-Based Data

**Pattern**: Separate data (Resources) from behavior (Nodes).

```gdscript
// ✅ CORRECT - Data in resources
# hero_stats.gd (Resource)
class_name HeroStats
@export var hero_id: StringName = &""
@export var base_max_health: float = 100.0
@export var base_move_speed: float = 96.0

# stat_component.gd (Node - uses the resource)
class_name HeroStatsComponent
@export var base_stats: HeroStats   # the .tres
var current_stats := {}             # runtime values

// ❌ WRONG - Data hardcoded in behavior
class_name River extends HeroBase
func _ready():
    max_health = 100.0  # Can't be changed without code
```

The same split everywhere: `MonsterStats` / `MonsterStrategy`, `AbilityBase`
(data and `execute`), `CharacterDef` (what the menus know about a character),
`MetaSkillTree` / `MetaSkillNode` (the trees), `AbilityFxRecipe` (an ability's
look), `RigProfile` (how a rig moves), `MatchConfig` (the pre-round choices),
`UiPalette` (colours).

**Why**: Designers tune stats in .tres files without touching code. Scales to hundreds of characters.

### 3. Virtual Method Polymorphism

**Pattern**: Use virtual methods for entity-specific behavior.

```gdscript
// ✅ CORRECT - Virtual methods in base class
# EntityBase
func _get_move_speed() -> float:
    return 96.0

# HeroBase
func _get_move_speed() -> float:
    return stats.get_move_speed() if stats else 96.0

# MonsterBase
func _get_move_speed() -> float:
    return monster_stats.get_speed_for_stage(current_stage)

// ❌ WRONG - Type-checking
func get_move_speed() -> float:
    if self is HeroBase:
        return self.stats.get_move_speed()
    elif self is MobBase:
        return self.base_move_speed
```

EntityBase's virtuals: `_get_move_speed`, `_get_attack_range`,
`_get_idle_retarget_time`, `_get_idle_wander_radius`, `_get_keep_distance`,
`_get_entity_level`, `_get_target_priority`, `_receive_damage`,
`_on_damage_taken`, `_on_fight_logic`, `_pre_tick`, `_is_always_full_rate`,
`_release_or_free`. AbilityBase's: `execute`, `can_use`, `on_passive_update`,
`tick_active`, `get_cast_center`, `get_display_icon`, `get_move_name`,
`debug_tag`.

**Why**: Adding new entity types doesn't require modifying the base class.

### 4. Signal-Based Communication

**Pattern**: Systems communicate via signals and read-only views, not direct calls into each other.

```gdscript
// ✅ CORRECT - gameplay emits, presentation listens
# an ability, after its own state change
EventBus.notify_ability_event(caster, self, FxEvents.CAGE_CLOSED, pos, radius)

# AbilityVfx (World.tscn, a separate system)
EventBus.ability_cast    -> the cast cue of the ability's recipe
EventBus.damage_applied  -> the hit cue
EventBus.ability_event   -> the moments inside an ability

# The HUD never asks an ability system for anything it could change:
CooldownSource.Hero.new(ability_system)   # read-only slots: icon, progress, locked
CooldownSource.Monster.new(monster)       # an AbilitySlot polls its source

// ❌ WRONG - Direct coupling
func use_basic_attack(target: Node2D = null) -> bool:
    ability.execute(owner_entity, target)
    get_node("/root/World/MainCam/MatchHud").flash_slot(ability)   # gameplay knows the HUD
```

`EventBus` signals: `damage_requested` (mutate the packet: shields),
`damage_applied` (threat, VFX, audio), `entity_died`, `monster_evolved`,
`ability_cast`, `ability_event`. Presentation never writes gameplay state,
which is why presentational changes keep the determinism trace byte-identical.

**Why**: The HUD, the VFX and the audio were all rewritten without touching combat code.

### 5. State Machine AI

**Pattern**: `godot_state_charts` for entity AI; the chart owns all state.

```gdscript
States: Idle → Approach → Fight → Dead   (+ Dead → Idle on CombatEvents.RESET for pooled mobs;
                                          monsters also have Scattered: Nyxa's Vampiric Rebirth)

# EntityBase. The chart's active state is STEPPED by the TickScheduler autoload
# (EntityBase._tick -> StateChart.step() -> state_stepped, wired scene-side in
# NPCBaseClass.tscn). `delta` is the time since this entity's last tick, so a
# far-away mob at 3 Hz moves the same distance per second as one at 60 Hz.
func _on_idle_state_processing(delta: float):
    if enemy_detected:
        state_chart.send_event(CombatEvents.ENEMY_ENTERED)

func _on_fight_state_processing(delta: float):
    if not is_target_valid():
        _drop_lost_target(CombatEvents.TARGET_LOST)   # clear_target() + send_event

// ❌ WRONG - Manual state flags next to the chart
var is_idle = true
var is_chasing = false
```

Pacing that must not depend on the tick rate is kept off the tick: a mob's
swing is its repeating `AttackTimer`, and when a swing lands while the mob
can swing on (`MobBase._keeps_swinging`, which asks the chart's Fight state)
the next one starts there with the frame's overshoot, not on the next 20 Hz
tick (fix batch G3); heroes and monsters credit a cooldown's overshoot to
the next cast (G2).

A Transition's `to` NodePath resolves relative to the transition node itself
(`../Dead`, not `Dead`): the first headless test run caught exactly that.
The monster's strategy layer (farm / rest / retreat / ambush / hunt) picks
targets and goals; it does not replace the chart.

**Why**: Predictable, debuggable AI; the F3 overlay shows each entity's state and LOD bucket.

---

## 📐 Code Organization Standards

### File Sections (EntityBase Pattern)

Major classes are laid out in numbered sections:

```gdscript
# ============================================
# SECTION 1: EXPORTS & CONFIGURATION
# SECTION 2: ONREADY REFERENCES
# SECTION 3: INSTANCE VARIABLES
# SECTION 4: COMPUTED PROPERTIES
# SECTION 5: LIFECYCLE METHODS (+ 5a tick scheduler / LOD, 5b HUD-pin helpers)
# SECTION 6: VIRTUAL METHODS (TO OVERRIDE)
# SECTION 7+: SYSTEM-SPECIFIC SECTIONS (targeting, movement, states, ...)
# ============================================
```

### Naming Conventions

```gdscript
class_name HeroBase                      # PascalCase classes
hero_base_class.gd                       # snake_case files
var current_health: float                # snake_case, typed
var _internal_timer: float               # underscore prefix: private
func _get_move_speed() -> float:         # underscore prefix: virtual / private
const MAX_LEVEL: int = 10                # SCREAMING_SNAKE_CASE
signal ability_used(ability: AbilityBase)
@export var detection_radius: float = 172.0
```

### Documentation Standards

- `##` doc comments on classes, exports and public functions (newer code);
  older entity code uses `"""docstrings"""`. Match the file you are in.
- Comments say **why**: the constraint, the trap, the number's source.
- No obvious comments: `health -= 10  # Subtract 10 from health` ❌

---

## 🎮 Gameplay Systems (what to read in the README)

| System | Core files | README section |
|---|---|---|
| Combat, targeting, damage | `Scenes/NPCs/npc_base_class.gd`, `Scripts/event_bus.gd`, `Scripts/damage_packet.gd`, `Scripts/team_blackboard.gd` | Combat AI, Technical Architecture |
| Heroes | `Scenes/NPCs/Hero/hero_base_class.gd`, `Scenes/NPCs/Hero/stat_component.gd`, `Scenes/NPCs/Hero/Abilities/ability_system.gd` | Heroes, Hero capstones and behaviour nodes |
| Hero group movement | `Scenes/NPCs/Hero/hero_exploration_controller.gd`, `Scripts/match_config.gd` | Hero Exploration AI, Pre-round screen |
| Monsters | `Scenes/NPCs/Monster/monster_base_class.gd`, `Scenes/NPCs/Monster/monster_stats.gd`, `Scripts/monster_strategy.gd` | Monster sections, Shared Monster Framework, Monster AI |
| Abilities | `Scenes/NPCs/Hero/Abilities/ability_base.gd` and each character's `abilities/` | the character sections |
| Mobs and camps | `Scenes/NPCs/Mob/mobs_base_class.gd`, `Scenes/World/spawns.gd`, `Scenes/World/MobSpawnArea/mob_spawn_area.gd` | Mob Camps, Spawn System |
| Roster | `Scripts/Roster/roster.gd`, `Scripts/Roster/character_def.gd`, `Scenes/World/monster_slot.gd` | Character Roster |
| Skill trees, threat | `Scripts/MetaSkills/meta_skill_manager.gd`, `Scripts/MetaSkills/meta_skill_tree.gd`, `Scripts/MetaSkills/meta_skill_node.gd` | Skill Tree Structure, Opponent Threat |
| Match flow, rewards | `Scripts/game_manager.gd`, `Scripts/match_rewards.gd` | Game Loop, Earning Rates v2 |
| Save | `Scripts/persisted_data.gd` | (bump `CURRENT_SAVE_VERSION` + a `_migrate` step for any layout change) |
| Rigs | `Scripts/Rig/character_rig.gd`, `Scripts/Rig/rig_body.gd`, `Scripts/Rig/rig_profile.gd`, `tools/rig_builder.gd` | Character Rigs |
| Ability effects | `Scripts/Vfx/ability_vfx.gd`, `Scripts/Vfx/ability_fx_recipe.gd`, `Scripts/Vfx/fx_events.gd` | Ability Effects |
| Hit feedback | `Scripts/Vfx/vfx_manager.gd` | Combat Visuals |
| Match HUD | `Scenes/UI/Hud/match_hud.gd`, `Scenes/UI/Hud/ability_slot.gd`, `Scripts/UI/cooldown_source.gd` | Match HUD, HUD Cooldown Slots |
| Menus | `Scenes/UI/Screens/menu_root.gd` and the screens beside it | Menu Root and Lobby, Roster and Character Detail, Pre-round, Match result, Tutorial / Codex / Settings |
| Look | `Scenes/UI/Theme/ui_palette.gd`, `Scenes/UI/Theme/ui_theme.tres`, `tools/art/palette.py` | Palette and Art Pipeline |

### Combat flow

1. An enemy `Body` enters an entity's `DetectionArea` (172 px by default).
2. Smart targeting scores candidates (priority + distance + threat + low-HP focus).
3. Chart: Idle → Approach (navigate) → Fight. The target pair is written in
   one place (`_set_target_pair`), which records the target's `life_id`;
   `is_target_valid()` compares it, and Approach / Fight clear a lost target
   (`_drop_lost_target`). A pooled mob that died and came back in another
   camp is nobody's old target. Approach enters Fight within
   `fight_enter_range()` and Fight leaves past `fight_leave_range()`, which
   is always 15 % beyond the enter range (`FIGHT_LEAVE_MARGIN`), so a range
   upgrade can never make the two cross and freeze an entity between them.
4. In Fight: attack ready and in range → stand and attack; on cooldown →
   reposition by combat role (RANGED / SUPPORT strafe at the preferred
   distance; MELEE walks in past its reach, out below `min_distance`, else
   holds: a hero with a fight side, `HeroBase.hold_fight_side`, walks round
   the target to its own side, `EntityBase._hold_fight_side`, and a monster,
   always MELEE, stands where it is between casts). Every range TO an
   entity is `range_to(target)`: centre distance less its `reach_bonus()`
   (0, or what an evolved monster's body grew by), so melee attackers stand
   at the edge of a Stage III body. The basic attacks' hit checks subtract
   the same bonus.
5. Damage goes `EventBus.deal_damage` → `damage_requested` (shields absorb) →
   the target's `_receive_damage` → `_on_damage_taken` → `damage_applied`
   (threat, VFX, audio). `AbilityBase.deal()` wraps it and applies lifesteal.
   A target that cancels the packet in `_receive_damage` (a corpse hit again
   in its death frame, Nyxa's scattered bats, Last Stand) gets no reaction and
   no `damage_applied`, and `deal_damage` returns 0. VfxManager takes a kill
   from `entity_died`, never from a hit.
6. Hero ultimates (`HeroBase._should_auto_use_ultimate`, 4 Hz) ask the
   ultimate what a cast would reach (`AbilityBase.count_reached`: its own
   centre and radius) and fire at the pre-round dial's enemy count, or at one
   while an ally is below the panic HP. River's Supply Drop counts the hurt
   heroes on its spot instead. Monsters: `MonsterBase._choose_and_use_ability_combo`
   (slam, then ability 2 once `MonsterStrategy.fight_ability_2_interval` has
   passed since its last cast, then the cleave).

### Hero stat scaling

```gdscript
final_stat = (base_value + level_bonus + additive_modifier) * multiplicative_modifier
# River's HP at level 3: (100 + 5 * (3 - 1) + 0) * 1.0 = 110
```

Skill-tree ranks arrive as modifiers (`add_stat_modifier`) and through the
generic stat keys (`get_damage_taken_multiplier`, `get_cooldown_multiplier`,
`get_start_level`). Only the **played side** applies the save's trees; the AI
opponent applies its threat build (`MetaSkillManager.spawn_ranks`), which
never holds a capstone.

### Monster evolution

Total XP against `MonsterStats.stage_2_xp` / `stage_3_xp` (Grount 150 / 300,
Nyxa 150 / 400, Gorrak 150 / 500). On evolving: the stage's HP, speed and
scale, every ability's `apply_stage_stats(stage)` (per-stage damage,
cooldown, range, radius; an `unlock_stage`), the rig's stage parts, a heal to
full, `EventBus.monster_evolved`.

---

## ⚡ Performance Systems

Measured with `tools/bench.sh` (headless stress config: every camp, two mobs
per slot, 232 mobs) and the **F3 debug overlay** (FPS, process/physics ms,
node count, Phys2D objects and collision pairs, registry counts, LOD bucket
counts, the VFX pool). Stress config in the editor: `SpawnManager`
`min/max_active_spawns = 39`, `enable_lazy_activation = false`,
`stress_mob_multiplier = 2`.

### 1. Lazy Spawning / Despawning (`SpawnManager` + `MobSpawnArea`)

```gdscript
# MobSpawnArea exports (per camp, visualised by the SpawnZone children)
@export var lazy_spawning: bool = true
@export var activation_radius: float   # World camps: 200 px
@export var deactivation_radius: float # World camps: 300 px (hysteresis)
# SpawnManager: 26–30 of 39 camps are world-eligible; a camp only holds a
# virtual_count until a hero (or the monster) is inside its ring.
```

### 2. AI LOD (`Scripts/tick_scheduler.gd`)

Entities register from `_enter_tree`. The scheduler calls `EntityBase._tick(delta)` which runs
`StateChart.step()`; the chart still owns every state and transition — only the cadence moved.

| Bucket | Rate | Who |
|---|---|---|
| FULL | every frame | heroes, monster (`_is_always_full_rate`), anything on screen |
| NEAR | 20 Hz | has a target, or < 450 px from the nearest hero / pet / monster |
| MID | 10 Hz | < 1200 px |
| FAR | 3 Hz | everything else |

Buckets are **anchor-based** (distance to the action via `EntityRegistry.nearest_anchor_dist_sq`),
not camera-based, because lazy activation only spawns mobs near heroes. Movement steps are clamped
to the remaining distance and `_face` uses an exponential lerp so low rates stay correct. Headless
runs draw nothing, so no mob is ever "on screen" there (`tools/bench.sh` has `onscreen=1`).

### 3. Mob Pooling (`SpawnManager.acquire_mob / release_mob`)

Dead and despawned mobs are parked **out of the tree** (so `_exit_tree` unregisters them from
TeamRegistry / EntityRegistry / TickScheduler) and reused. `MobBase.prepare_for_pool` scrubs
per-life state, `reset_for_spawn` + `on_spawned` restore it, `CombatEvents.RESET` drives the chart
Dead → Idle. `life_id` (on `EntityBase`, stepped by MobBase) increments per life: anything that
holds a mob reference across frames must compare it before acting. The target pair does
(`_set_target_pair` records it, `is_target_valid` compares it), and so does the trap cage; Ted's
fox drops a target that left its leash around Ted. The pool is pre-warmed during load.

### 4. Faction Collision Layers (`project.godot` `[layer_names]`, `GameUtils.LAYER_* / MASK_*`)

Each entity exposes ONE monitorable Area2D (`Body`, r≈31) on its faction layer
(hero 2 / mob 4 / monster 8). `DetectionArea` is on no layer and masks enemy bodies only, so mob
vs mob areas never pair and AoE queries see each entity once. Abilities live on layer 16 and set
an explicit `collision_mask` on every `intersect_shape`.

### 5. EntityRegistry + targeted damage

`EntityRegistry` keeps `heroes / hero_side / mobs / monsters / enemies` lists — never
call `get_nodes_in_group` in a per-frame path. `EventBus` calls the target's
`_on_damage_taken` directly; `damage_applied` is for global listeners only.

### 6. Rigs: sleep and budget (`Scripts/Rig/character_rig.gd`)

One texture and one draw per character. A rig off screen sleeps (no pose
writes) and drops the reactions in flight (a move, the hurt flash), so it
wakes clean; a budget caps how many rigs animate fully, the rest take a cheaper
path (`within_budget()`, `plays_moves()`). A pose writes a property only when
it changed. `tools/bench.sh ... 0 1` wakes every rig to measure the worst case.
An effect that animates the drawn body from gameplay code (Ground Slam's hop,
Nyxa's scatter fade) tweens the rig's `hop_scale` / `fade_alpha`, not its
`scale` / `modulate`: a corpse in its death beat ignores them. Effect anchors
(`mid_body`, `head_top`, `half_width`) read `RigBody.drawn_bounds()`, the box
of the parts the current evolution stage shows; keep `bounds` (the union)
for fitting. Two keys of a move track closer than a frame must be a step
(transition 0), or a frame between them draws the jump half done.

### 7. VFX: pools and per-frame budgets (`Scripts/Vfx/vfx_manager.gd`)

Pooled sprites, digits and telegraphs, no node made per hit. Hits outside the
camera view are skipped; at most 8 hits and 2 kills per frame get the full
treatment, the rest only their number. Screen shake is trauma-based and
capped. F3 shows the pool use and the cost in ms. Numbers keep their screen
size at any zoom, so anything that spaces them (columns, rows, the rise) needs
a floor in screen px (`number_column()`, `number_row()`); `number_rect()` is
the drawn layout the tests measure.

### 8. HpBar2D

In-world HP bars are one `Node2D` with a `_draw` (`Scripts/hp_bar_2d.gd`), written only through
`EntityBase.set_hp_display`. Mobs hide the bar while full. The bar and the level pill sit in the
entity's `Hud` node, an `EntityHud` (`Scripts/entity_hud.gd`): it draws one z step above the
bodies, and the huds of heroes, Ted's fox and the monster (`stacks`) rise above each other when
they would overlap, so four heroes on one spot show four rows. A character that is not an
EntityBase gets the same `Hud` node scene-side (`TedsPet.tscn`), wired to its notifier.

### 9. Fight readability (fix batch F2)

- **Draw order**: `World.tscn` y-sorts its characters (the root and the holders `Spawns`, `Heros`,
  `MonsterSlot` are y-sorted Node2Ds at the origin). Add a new holder the same way, or its
  children draw in tree order again.
- **Hurt flash**: `CharacterRig` starts a hurt reaction at most every `hurt_flash_interval`; the
  monsters' `hurt_flash_gain` is lower. Do not flash from anywhere else.
- **Cast facing**: the rig takes its side from the cast's target for 0.3 s, then from the facing
  carrier again.
- **Death beat**: on `died` a FULL rig on screen leaves its entity and plays the fall as a puppet
  (`CharacterRig._on_entity_died`); the entity is freed as before. `GameManager` decides the
  match at the deciding death, pays it at the end of that frame (after the kill's XP reached the
  monster: `_settle_after_death`, deferred) and shows the result screen `DEATH_BEAT_SEC` later
  (`result_shown`, which stops the world's sounds). In the beat every hit is canceled
  (`in_death_beat()`), so nothing can die after the decision. Anything that keeps a reference to
  a dead entity across frames must check `is_instance_valid` before passing it on (the Trap Cage
  did not).

### 10. Match speed and walking speeds (fix batches F3, P1)

- **One owner**: `GameManager._sync_time_scale()` is the only code that writes
  `Engine.time_scale`: `match_speed()` (`MATCH_BASE_SPEED`, times `MATCH_FAST_FACTOR` on the speed
  button's fast setting) while a match runs unpaused, 1 for the pause menu, the death beat, the
  result screen, a scene change and the menus. Never set `Engine.time_scale` anywhere else, and
  never pause without the tree's `paused` flag (that flag is what puts the scale back).
- **Everything in a match is game time**: use `delta`, tweens and `create_timer` and it speeds up
  with the match. Only what a player must read may ask for real time, and then with a clock of
  its own: a tween with `set_ignore_time_scale()` beside the game-time one (the toast's floor,
  `MatchHud.TOAST_MIN_REAL_HOLD`; a node-bound tween still stops while the tree is paused). A
  duration scaled once by `Engine.time_scale` breaks when the speed button is pressed while it
  runs (the toast's first floor did, fix batch R5).
- **Match timers are pausable**: `get_tree().create_timer(t)` defaults to `process_always = true`
  and keeps counting while the pause menu or the result screen has paused the tree. Anything that
  belongs to the match passes `false` (`create_timer(t, false)`: the cage, the taunt, mines, the
  kit, the slam, the dash, camp respawns, the death beat, the HUD tips) or is a node `_process`
  timer. Only UI on `PROCESS_MODE_ALWAYS` (menus, the pause menu, the result screen) may use an
  always-processing timer.
- **Headless runs are not scaled** (`GameManager.speed_scaling` is false without a display): the
  sims and the trace keep 60 steps per game second. A test that needs the speed sets
  `speed_scaling` and restores it (`test/test_match_speed.gd`). `tools/sim.sh`'s `SPEED`, `FPS`
  and `LOD=off` play a match at a device's step instead (README "Headless Tools"); keep game
  logic step-size independent (`timer -= delta`, steps clamped to the distance left) so those
  sims agree with the 60 Hz ones.
- **Walking speeds are data** (fix batch P1 raised all of them by 20 %): `HeroStats`
  (`base_move_speed`, `speed_per_level`, `strafe_speed`), `MonsterStats` (`stage_N_speed`), the
  mob scenes (`base_move_speed`, `strafe_speed`) and `TedsPet.move_speed`, each with its rig's
  `RigProfile.full_speed` (the hero's base speed, the monster's Stage 1 speed). Change a speed and
  its `full_speed` together and keep the README's tables in step (`test/test_walk_speed.gd`,
  `test_readme_spec`); never put a hidden multiplier on `move_speed`. Unlike the match speed, a
  walking speed changes the game: the trace baselines and the balance tables move with it.

### 11. Localization (fix batch F6)

- **The English text is the key.** `Assets/Locale/strings.csv` has one row per text (`keys,en,de`)
  and the data stays English: a `.tres`, the tree seed data and the scripts never hold German.
  Every text a player can read has a row, the content too (role lines, taglines, field notes,
  tips, stage names, ability names and descriptions, tree titles, branches, node names and effect
  texts). `test_content_locale` walks the data and fails on a text without a German row.
- **Hand a whole text to the control**: `label.text = def.tagline` is enough, the Label translates
  the key and follows a language switch by itself. Do not write `label.text = tr(key)` where the
  key would do: the translated string is not a key any more and stays in the old language (the
  pause menu's QUIT button and the tutorial's bubble did).
- **A line built from parts translates its parts** (`tr("Needs %s") % tr(name)`) and belongs to
  whoever built it: if the node can be on screen when the language changes (the lobby under the
  settings sheet, the match HUD under the pause menu's settings), write the line again on
  `NOTIFICATION_TRANSLATION_CHANGED` (`MenuRoot`, `MatchHud`, `MonsterHudPanel`). A screen that
  re-reads everything on open needs nothing.
- **Never key a cache or a guard by a translated line**: after a switch the same thing has
  another key (the ultimate toast's repeat guard let every cast toast again; it is keyed by the
  caster's instance id and the untranslated ability name now). Translate only what is shown.
- **`UxTreeModel` is a snapshot in the current language**: `from_ranked_manager` translates the
  tree's title, blurb, branch and node names; `MetaSkillNode.effect_text` translates the
  description and then fills "{v}" in from the data. Rebuild the model after a switch.
- **Numbers stay in step**: a German row repeats the placeholders (`%d`, `%s`, "{v}", in the same
  order: GDScript fills them by position) and the numbers of its English text; the test compares
  both. Change a number in an English text and its row is gone until the German follows.
- **German is longer**: `test_content_locale` and `test_detail_fit_and_stats` lay the screens out
  at 720x1280 in both languages and fail on a cut line, a word wider than its label or a text
  past the screen edge. Node names have 100 px (150 px alone in their cell) and two lines.
- **After editing the CSV**: `tools/build_locale.sh` (the two `.translation` files are committed;
  `--check` tells whether they are current). README "Localization" has the term table: use the
  word that is there.

---

## 🚫 Anti-Patterns to Avoid

### ❌ Don't: Hardcode Game Data

```gdscript
// ❌ WRONG
class_name River extends HeroBase
func _ready():
    max_health = 120.0

// ✅ CORRECT
# river_stats.tres (Resource file)
base_move_speed = 102.0
vision_radius = 300.0
# river.gd overrides only behaviour (her weapon mode), no stats
```

### ❌ Don't: Use Type Checking

```gdscript
// ❌ WRONG
if entity is HeroBase: return entity.stats.get_attack_range()
elif entity is MobBase: return entity.base_attack_range

// ✅ CORRECT
return entity._get_attack_range()  # virtual method, each class overrides
```

### ❌ Don't: Tightly Couple Systems

```gdscript
// ❌ WRONG - an ability reaching into the HUD or the VFX
get_tree().get_first_node_in_group("vfx").spawn_ring(...)

// ✅ CORRECT - emit, and let the recipe decide the look
EventBus.notify_ability_event(caster, self, FxEvents.MINE_ARMED, pos, 0.0)
```

### ❌ Don't: Mutate Shared Resources

```gdscript
// ❌ WRONG - every Vlad in every match now has the short cooldown
ability.cooldown *= 0.8

// ✅ CORRECT - the entity's own copy, through the modifier record
ability.apply_meta_modifier("cooldown", 0.8, true)   # after make_abilities_unique()
```

### ❌ Don't: Put Logic in _process Unless Necessary

```gdscript
// ❌ WRONG - runs every frame for every entity, ignores LOD
func _process(delta: float):
    check_for_enemies()

// ✅ CORRECT - in the stepped state (rate-invariant: speed * delta, timer -= delta)
func _on_idle_state_processing(delta: float):
    _idle_timer -= delta
    if _idle_timer <= 0.0:
        _idle_timer = idle_retarget_time
        check_for_enemies()
```

### ❌ Don't: Draw From the Global RNG for Looks

```gdscript
// ❌ WRONG - changes every match's outcome and the trace
sprite.rotation = randf() * TAU

// ✅ CORRECT
var _rng := RandomNumberGenerator.new()
sprite.rotation = _rng.randf() * TAU
```

### ❌ Don't: Scale a Container's Own Child

A container lays its children out whenever one changes size or visibility and
puts their `scale` back to 1 before the frame is drawn, so a pop tween on such
a child never shows (the LEVEL UP! pill, the result ribbon, NEW QUARRY and the
match toast ran 1 -> 1 until fix batch R5). Wrap the content in a `PopSlot`
(`Scenes/UI/Components/pop_slot.gd`: a plain Control that takes its content's
minimum size; the content fills it by its anchors, with `pivot_offset_ratio`
0.5) and scale the content, or scale a part that no container lays out (a
card's frame, an ability slot's `Body`). A label whose text changes every
frame inside a container re-sorts it every frame: pop it after the text has
settled (`CurrencyChip` pops when its count lands).

### ❌ Don't: Premature Optimization

Simple first. Then `tools/bench.sh` before and after, back to back, and only
then optimize the hot path the numbers point at.

---

## ✅ When Adding New Features

### Checklist for a New Hero

```
[ ] Scenes/NPCs/Hero/Heros/{Role}/{Hero}/: a scene inheriting HeroBaseClass.tscn
[ ] HeroStats .tres (hero_id is the save key; base stats, per-level gains, spacing)
[ ] A script extending HeroBase ONLY if a virtual must change (Vlad has none)
[ ] Four ability .tres (passive, basic, active, ultimate): name, description, icon,
    move_name, fx recipe; new behaviour = a script extending AbilityBase
[ ] Rig: Assets/Characters/<id>/src/ (parts + rig_src.json), tools/build_rigs.sh,
    <id>_motion.tres, the portrait
[ ] Assets/Characters/<id>/<id>_def.tres (CharacterDef) added to roster.tres
[ ] Skill tree: seed in skill_tree_data_v2.gd, tools/build_skill_trees.sh,
    linked from the def's skill_tree
[ ] Ability icons (tools/art/icons_abilities.py + build.py)
[ ] strings.csv rows (EN + DE) for the role line, tagline, field notes, every ability name
    and description and every tree text, then tools/build_locale.sh (test_content_locale
    fails until every text has its German row)
[ ] README: the roster table and a hero section (test_readme_spec reads them)
[ ] Gate: lint, tests, a new trace baseline if the default match changed, sim balance
```

### Checklist for a New Ability

```
[ ] A script extending AbilityBase only if no existing one fits (BasicStrike,
    BullFrontCleave, BullRamDash, BullGroundSlam are reusable toolkits)
[ ] ability_type, execute(caster, target, override_damage), can_use if needed
[ ] Passives: on_passive_update(caster, delta); lingering effects: tick_active
[ ] Damage through deal() (EventBus.deal_damage + lifesteal), never direct HP writes
[ ] .tres with icon, description, stats (per-stage arrays for a monster)
[ ] Look: an AbilityFxRecipe in Assets/Vfx/recipes (colours by palette token),
    moments via EventBus.notify_ability_event + a name in FxEvents
[ ] Rig move: move_name (an authored move of the body plan, Assets/Characters/_moves)
[ ] No change to AbilitySystem or MonsterBase needed
```

### Checklist for a New Monster

```
[ ] Scenes/NPCs/Monster/<Name>/<Name>.tscn inheriting monster_base_class.tscn
[ ] MonsterStats .tres (monster_id, reach, leave distance, armour, stages, XP thresholds)
[ ] MonsterStrategy .tres (awareness, retreat, rest, ambush, farming, combos)
[ ] passive_ability + ability_1..3 .tres, each with per-stage tables
[ ] Rig, CharacterDef (stage_names, tip, unlock rules; stage_portraits and
    stage_head_regions when its look changes with the stage, as Grount's),
    roster.tres, skill tree (with an ai_build_order of 12 entries, no capstone)
[ ] Recipes and telegraphs, icons, strings
[ ] Baseline: MONSTER=all RECORD_DIR=tools/baselines tools/sim_trace.sh
    (test_sim_tools fails while a roster monster has none)
[ ] Balance: MONSTER=<id> tools/sim.sh 48 heroes 6 and ... 48 monster 6 (40-60 %),
    then MONSTER=<id> THREAT=all tools/sim.sh 24 heroes 8
[ ] README: the overview table, a monster section, Measured Balance
```

### Checklist for a New Mob

```
[ ] Scenes/NPCs/Mob/Mobs/{Mob}/{Mob}.tscn inheriting mobs_base_class.tscn
[ ] Stats as exports on the scene root (max_health, base_attack_damage,
    attack_cooldown, xp_value, hero_xp_value)
[ ] Override _on_fight_logic only for custom attack behaviour
[ ] Rig (QUADRUPED / FLYER body plan), generic bite / claw recipe
[ ] MobSpawnArea camps in World.tscn with mob_scene, respawn_time 40
[ ] Test leashing, pooling (prepare_for_pool scrubs any new per-life state)
```

### Checklist for a New Skill Node

```
[ ] Seed it in Scripts/MetaSkills/skill_tree_data_v2.gd, run tools/build_skill_trees.sh
    (test_skill_trees_v2 keeps the seed and the .tres in step)
[ ] A stat node: a generic key the spawn reads; an ability node: ability_name + property
    on the character's own copy; a behaviour node / capstone: off by default
    (false or 0), so a fresh save and the trace are unchanged
[ ] Effect text with {v}; rank_values cumulative; costs from the cost rows. The text
    must say what the code does (half width or width, when it triggers); a German
    row in strings.csv for the name and for the text, keyed by the English text with
    its {v}, then tools/build_locale.sh. A node name has two lines of 100 px
[ ] A key that changes a number of the character overview (max HP, damage, speed,
    evolution XP): the overview reads the owned build through
    MetaSkillManager.owned_hero_stats / owned_monster_modifiers and
    MonsterBase.build_*; test_detail_fit_and_stats compares them with a spawn
[ ] README "Tree content v2" (test_readme_spec checks names and rank rows)
[ ] Never remove or rename a shipped node id (saves own ranks by id)
```

### Checklist for a New Screen or Widget

```
[ ] A scene under Scenes/UI/..., theme = the project theme, looks by theme type variation
[ ] Colours from UiPalette tokens, no Color(...) literal (lint fails otherwise)
[ ] Signals connected in the parent scene (MenuRoot.tscn wires every screen)
[ ] Characters shown as RigView / CharacterCard from their CharacterDef, never by
    instancing the gameplay scene in a menu
[ ] Strings in Assets/Locale/strings.csv (EN + DE), tools/build_locale.sh; a line the
    screen builds with tr() is written again on NOTIFICATION_TRANSLATION_CHANGED when
    the screen can be on show during a language switch; ≥ 48 px touch targets
[ ] A muted render of the scene on a copy, looked at; a test for the wiring
[ ] Anything that appears under the finger (a screen, a sheet, a result) holds a
    TapGuard while it appears: one TapGuard node in its scene, hold(<appear time>)
    where it opens. MenuRoot does it for every screen it pushes or pops
[ ] An action that cannot be undone sits behind a ConfirmButton (arm, then a
    second tap at least 0.6 s later), never behind two plain presses
```

**Taps on what just appeared** (fix batch F5). A screen that slides in is live
from its first frame, so the second tap of a double tap lands on whatever now
sits under the finger: it picked the pre-round's first monster card, opened
the quarry sheet, closed a sheet on its scrim, pressed a button that was
still invisible. `TapGuard` (`Scenes/UI/Components/tap_guard.gd`) is the one
answer: while it holds, every NEW pointer press in the viewport is swallowed
in `_input`, before the GUI sees it (releases, drags and keys pass). It counts
in game time like the tweens, so a test steps it with `wait_seconds` and real
mouse presses (`Viewport.push_input`, see `test/test_menu_flow.gd`).
`ConfirmButton` (`Components/ConfirmButton.tscn`) is the same idea for
arm-then-confirm buttons: the confirming tap counts only `MIN_GAP` after the
arming one, and the time since arming is a single counter, so there is no
stale timer to disarm a button that was armed again.

---

## 🔧 Common Development Tasks

### Task: Add New Stat to Heroes

1. Add to `HeroStats` (`@export var base_critical_chance: float = 0.05`).
2. Add to `HeroStatsComponent`: a `current_stats` key, `_recalculate_stat(...)`
   in `_recalculate_all_stats`, a getter.
3. Use it in the ability's `execute()`. If it is random, remember the global
   RNG is gameplay: the trace changes, record why.

**No changes to HeroBase or EntityBase needed**.

### Task: Balance a Monster or Mob

1. Change the `.tres` (stats, per-stage ability arrays, strategy) or the mob
   scene's exports. No code.
2. `MONSTER=<id> tools/sim.sh 48 heroes 6` and `... 48 monster 6`; report the
   summary lines. Check the other monsters if the change is shared.
3. Re-record the baselines (`MONSTER=all RECORD_DIR=tools/baselines
   tools/sim_trace.sh > /dev/null`) in the same commit and update the README
   tables.

### Task: Add LOD to New Entity Type

1. Extend `EntityBase` — registration with TickScheduler / EntityRegistry / TeamRegistry happens
   in `EntityBase._enter_tree`, nothing to call.
2. Override `_is_always_full_rate()` → `true` only for camera anchors (heroes, monster).
3. Put per-tick work that is independent of the active state in `_pre_tick(delta)`; keep the
   `_on_*_state_processing(delta)` overrides rate-invariant (`speed * delta`, `timer -= delta`).
4. Do NOT add `_process` for AI — it would run every frame regardless of LOD.

### Task: Debug Performance Issue

1. `tools/bench.sh 5 2 900 300` on the parent and on the change, back to back
   (frame mean, p95, p99, LOD buckets; add `0 1` to wake every rig).
2. Press **F3** in a match: FPS, process/physics ms, node count, Phys2D objects + collision pairs,
   `Registry: H P M Mob`, `LOD FULL/NEAR/MID/FAR` counts, the VFX line, per-entity `state [LOD]`,
   and each ability's time left (one line per ability of every monster and of the followed hero).
3. Profile with the Godot profiler: `TickScheduler._process`, `_steer_along_nav`, Physics 2D.
4. Optimize hot paths only; record before/after numbers in `PROGRESS.md`.

---

## 🧪 Testing and Tools

Every tool copies the project to a temp directory with its own `user://` and
runs Godot headless there: the real save is never touched, nothing makes a
sound, and the editor can stay open. Details: README "Headless Tools".

```bash
tools/lint.sh               # loads every script, scene and resource; scene wiring; UI colour literals;
                            # every GDScript warning is an error on the lint's copy
tools/run_tests.sh [name]   # the headless suite, or the files whose name contains <name>
                            # (GODOT=/path/to/godot overrides the binary)
BASELINE=<file> tools/sim_trace.sh > new.txt    # determinism: byte-identical for a non-gameplay change
                                                # (JOBS=2 matches at a time by default)
MONSTER=all tools/sim.sh 48 heroes 6            # balance per monster (also: monster side, THREAT=, SAVE=)
SPEED=2 FPS=30 tools/sim.sh 12 heroes 2         # the same game at a device's step (SPEED, FPS, LOD=off)
tools/bench.sh 5 2 900 300                      # performance in the stress config
tools/bake_nav.sh · tools/build_rigs.sh · tools/build_skill_trees.sh   # regenerate, copy back
tools/build_locale.sh [--check]                 # strings.csv → the two .translation files
python3 tools/art/build.py · python3 tools/art/make_theme.py           # UI kit, palette, theme
tools/selftest.sh                               # the tools' own failure paths, with a fake Godot
```

No tool passes by accident: a missing Godot, one that crashed or exited
non-zero (also after its end marker), a run that never reached its end
marker, one past its time limit (`TOOL_TIME_LIMIT_S`: a loop that never ends
cannot hang a tool) and any `SCRIPT ERROR` fail it, and a test that hits a
script error, or an engine `ERROR` it did not announce, fails even when its
asserts passed. A killed tool stops its Godot processes and deletes its
copies (`tools/tool_env.zsh`). After changing a tool run `tools/selftest.sh`.

**The gate for every commit**: lint `errors=0`, the suite green, and

- a change that must not alter gameplay keeps the trace byte-identical
  against the parent's trace recorded on the same machine;
- a gameplay change says why the trace changed, re-records `tools/baselines`
  and reports the sim summaries;
- anything visible gets a muted render on a copy that somebody looks at
  (`--audio-driver Dummy --write-movie`).

The committed baselines belong to the machine and engine build that recorded
them (Godot 4.7.2 on the development Mac). On another machine re-record on
the untouched tree first.

### Writing a test

Add `test/test_<topic>.gd` extending `TestCase` (`test/case.gd`); every
`test_*` method runs, may `await`, and uses `assert_eq / assert_true /
assert_false / assert_near / skip`. Helpers: `spawn_entity(scene, pos)` (adds
under the test and waits for the awaited `_ready`), `spawn_frozen`,
`active_state_of(entity)`, `wait_frames / wait_physics_frames / wait_seconds`,
`play_side(side)`, `require_isolated()` for tests that write the save,
`bake_nav_rect`, `wait_for_nav_map(map, probe)` (a private navigation map,
never asked before its first sync), `evolve_to(monster, stage)`,
`expect_error(fragment)` (the test provokes that engine `ERROR` on purpose,
e.g. a corrupt save; any other engine `ERROR` fails the test). Nodes a test
leaves behind are freed between tests; the locale is pinned to `en`; deaths
never end a match. Await what a test starts: a coroutine, timer or deferred
call that errors after the test ended fails the next test (its message names
the culprit's `file:line`).
A loop that waits for a condition needs a bound (and an assert after it): a
test still running after 120 s is named and stops the run. A probe script run with
`-s` must not use project `class_name`s as types.

### Manual Testing Checklist

```
[ ] Lobby: tap a side, HUNT, pre-round, START HUNT
[ ] Heroes spawn in formation and explore; camps activate and deactivate (F3)
[ ] The monster evolves at its thresholds (Grount 150 / 300 XP) with the flash and shake
[ ] HUD: cooldown sweeps, the ultimate's ready glow, stage locks, a fallen hero's greyed slots
[ ] Toasts name the caster ("VLAD · BLOOD BOMB"); none for an enemy the player cannot see
[ ] Minimap: dots and the camera frame on the fog map, which covers the whole world (both sides)
[ ] Abilities: each has its move and effect; AoE hits each target once
[ ] Fog of war reveals properly (both sides)
[ ] Killed mobs respawn from the pool after 40 s with full HP
[ ] Result screen: rewards count up, XP bars, "upgrades ready" opens the roster
[ ] Skill tree: buy a rank, equip a capstone, the next match applies it (F3)
[ ] FPS stable at 60 on the target device (F3: stress config)
```

### Debug Flags

```gdscript
# MobSpawnArea
show_debug_area = true          # visualize the camp's rings
# EntityBase
show_detection_radius = true    # show the detection range
# TickScheduler (inspector on the autoload, or at runtime)
lod_enabled = false             # A/B: tick everything every frame
# Globals
verbose_logs = true             # Globals.debug_log output in a debug build
```

Debug keys work in debug builds only (F3 overlay, F1 / K / M, Shift+R).

---

## 📚 Key Files Reference

### Core Systems

| File | Purpose | Modify When |
|------|---------|-------------|
| `Scenes/NPCs/npc_base_class.gd` | EntityBase - all NPC behavior | Rarely - affects all entities |
| `Scenes/NPCs/Hero/hero_base_class.gd` | HeroBase - hero-wide behavior | Adding hero-wide features |
| `Scenes/NPCs/Mob/mobs_base_class.gd` | MobBase - mobs, leash, pool, warband | Adding mob-wide features |
| `Scenes/NPCs/Monster/monster_base_class.gd` | MonsterBase - evolution, strategy layer, combos | Changing monster-wide rules |
| `Scenes/NPCs/Hero/Abilities/ability_system.gd` | The heroes' 4 ability slots | Rarely - system is stable |
| `Scenes/NPCs/Hero/Abilities/ability_base.gd` | Base class for abilities | Rarely - extend, don't modify |
| `Scenes/NPCs/Hero/stat_component.gd` | Runtime stat calculations | Adding new stats |
| `Scripts/event_bus.gd` | Damage pipeline (request → receive → `_on_damage_taken` → applied) | Adding global combat listeners |
| `Scripts/team_registry.gd` / `Scripts/team_blackboard.gd` | Threat tables, aggro queries | Coordination behaviour |
| `Scripts/entity_registry.gd` | Cached faction lists, anchors, singletons | Any per-frame entity lookup |
| `Scripts/tick_scheduler.gd` | AI LOD, `StateChart.step()` cadence | Tuning LOD radii / rates |
| `Scripts/persisted_data.gd` | Save file, versioning + migration ladder | Any save-layout change |
| `Scripts/MetaSkills/meta_skill_manager.gd` | Trees, ranks, gates, threat, AI builds | Tree rules |
| `Scripts/game_manager.gd` | Match flow, side, quarry, rewards | Match rules |

### World Systems

| File | Purpose | Modify When |
|------|---------|-------------|
| `Scenes/World/spawns.gd` (SpawnManager) | Camp eligibility, lazy activation, mob pool | Population / pooling |
| `Scenes/World/MobSpawnArea/mob_spawn_area.gd` | Per-camp spawning, respawn accounting, leashing | Tuning camps |
| `Scenes/World/monster_slot.gd` | Spawns the selected monster in the enter pass | Rarely - the spawn point in the pass is load-bearing |
| `Scenes/World/FogOfWar/fog_of_war_system.gd` | Exploration grid and fog quad | Fog rules |
| `Scenes/NPCs/Hero/hero_exploration_controller.gd` | Formation and exploration | Tweaking exploration |
| `tools/bake_nav.gd` | Bakes the Ground tiles into `Scenes/World/world_navigation.tres` | After editing the Ground tiles |

### Presentation

| File | Purpose | Modify When |
|------|---------|-------------|
| `Scripts/Rig/character_rig.gd` | The rig runtime: pose, moves, sleep, budget | Rig behaviour |
| `Scripts/Vfx/ability_vfx.gd` | Plays the ability recipes | A new effect program |
| `Scripts/Vfx/vfx_manager.gd` | Numbers, hit flash, shake, telegraphs | Hit feedback |
| `Scenes/UI/Hud/match_hud.gd` | The in-match HUD | HUD features |
| `Scenes/UI/Screens/menu_root.gd` | Moves between the menu screens | A new screen |
| `Scenes/UI/Components/tap_guard.gd` | No tap on what has just appeared | A new sheet or overlay |
| `Scenes/UI/Components/confirm_button.gd` | Arm, then confirm with a second tap | A destructive action |
| `Scenes/UI/Tutorial/tutorial_overlay.gd` | Coach marks (steps are data) | Onboarding |
| `Scenes/UI/Settings/settings_screen.gd` | Volumes, language, shake, privacy, reset | Adding settings |
| `Scenes/World/Camera/debug_overlay.gd` | F3 overlay: perf counters, states, LOD, threat | Adding debug readouts |
| `Scenes/UI/Theme/ui_palette.gd` | The palette tokens (generated) | Never by hand: `tools/art/palette.py` |

---

## 🎓 Learning Resources

**Start here**:
1. `Scenes/NPCs/npc_base_class.gd` sections 1-6 (exports, lifecycle, tick, virtual methods)
2. `Scenes/NPCs/Hero/hero_base_class.gd`: how it overrides the virtuals and auto-uses abilities
3. `Scenes/NPCs/Hero/Heros/Healer/River/river.gd`: a hero with one special rule (her weapon mode: with the staff, `_staff_step` serves her patient at the top of each state handler before the base logic runs)
4. `Scenes/NPCs/Hero/Abilities/ability_system.gd` and `ability_base.gd`
5. `Scenes/NPCs/Monster/Grount/abilities/bull_front_cleave.gd`: a monster ability with per-stage data
6. `Scenes/NPCs/Monster/Nyxa/abilities/night_swarm.gd`: an ability that keeps acting (`tick_active`)
7. `test/test_nyxa.gd`: how a monster's rules are pinned by tests

**State Machine Flow**:
```
Idle → (enemy detected) → Approach → (in range) → Fight → (target lost) → Idle
                                                     ↓
                                                   Dead  (pooled mobs: → Idle on reset)
```

---

## 🚀 Future-Proofing Checklist

When adding new code, ask:

```
[ ] Can this be a resource instead of hardcoded?
[ ] Does this belong in a component or the base class?
[ ] Am I using signals or direct calls? Is the wiring in the scene?
[ ] Is this a virtual method or type-checking?
[ ] Will adding 100 more heroes/abilities break this?
[ ] Does this run every frame or only when needed? Does it respect LOD?
[ ] Does it touch the global RNG, a shared .tres or the save layout?
[ ] Can a designer tune this without code changes?
[ ] Did the README section and its test follow the change?
```

---

## 🎯 TL;DR - Quick Reference

**Adding Content**:
- New Hero → scene on HeroBaseClass, HeroStats, four abilities, rig, def, tree
- New Monster → scene on monster_base_class, stats, strategy, abilities, rig, def, tree, baseline
- New Ability → `.tres` (+ a script extending AbilityBase if needed), recipe, move
- New Mob → scene on mobs_base_class, stats in the Inspector

**Modifying Behavior**:
- Change how ALL entities work → EntityBase
- Change how heroes / monsters work → HeroBase / MonsterBase
- Change one character → its data first, its script last

**Gate**: `tools/lint.sh`, `tools/run_tests.sh`, `tools/sim_trace.sh` (or the sim
numbers), a muted render for anything visible.

**Mantras**:
- "Composition over inheritance"
- "Resources for data, nodes for behavior"
- "Signals over direct calls, wired in the scene"
- "Virtual methods over type-checking"
- "The chart owns the state"
- "Profile before optimizing"

---

**Remember**: Max values clean, maintainable code that can scale to hundreds of heroes and abilities without architectural rewrites. Make decisions with this in mind.
