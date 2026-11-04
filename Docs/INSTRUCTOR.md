# Better Hunt - AI Agent Instructor Guide

## 🎯 Project Mission

Better Hunt is a mobile-first asymmetric auto-battler RPG inspired by Evolve's 4v1 gameplay. Players control either 4 AI heroes or a single evolving monster in strategic, setup-driven battles. The game emphasizes **"Strategy Over Execution"** - players configure their approach before each round, then watch AI execute their plan.

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
- **Design for extension** - new heroes/abilities/features should slot in easily

### 3. **Scalability**
- **Performance from day one** - lazy loading, LOD systems, object pooling
- **Component-based architecture** - systems should scale independently
- **Data-driven design** - adding content shouldn't require code changes
- **Mobile constraints** - design for limited memory/processing power

### 4. **Performance**
- **Measure before optimizing** - use profiler, don't guess
- **Optimize hot paths** - focus on code that runs every frame
- **Lazy evaluation** - don't spawn/process what isn't needed
- **Batch operations** - group similar work together

---

## 📋 Core Design Principles

### Strategy Over Execution
- No real-time player control during battles
- Pre-round configuration and strategy setup
- AI executes player's strategic plan
- Victory through smart preparation, not quick reflexes

### Asymmetric Power Curves
- **Heroes**: Start strong (~35 DPS combined), grow slowly (Level 1→4)
- **Monster**: Start weak (Stage 1: 800 HP), become god-mode (Stage 3: 2200 HP, 2× damage)
- **Balance Target**: 50/50 win rate overall
  - 70% heroes if found early
  - 65% monster if reaches Stage 3

### Permanent Progression
- Every round earns resources (Steel/Leaves/Gold)
- Unlock skill tree upgrades between matches
- All systems feed into progression loop: **Setup → Watch → Upgrade**

---

## 🏗️ Architecture Overview

### File Structure

```
res://
├── Scenes/
│   ├── NPCs/
│   │   ├── Hero/
│   │   │   ├── hero_base_class.gd (HeroBase extends EntityBase)
│   │   │   ├── stat_component.gd (HeroStatsComponent - runtime stats)
│   │   │   ├── hero_stats.gd (HeroStats resource - immutable data)
│   │   │   ├── Abilities/
│   │   │   │   ├── ability_base.gd (AbilityBase resource)
│   │   │   │   └── ability_system.gd (AbilitySystem node - manages 4 slots)
│   │   │   └── Heros/
│   │   │       ├── DMG/Vlad/
│   │   │       ├── Support/River/
│   │   │       ├── Support/Ted/
│   │   │       └── Support/Irelia/
│   │   ├── Mob/
│   │   │   ├── mobs_base_class.gd (MobBase extends EntityBase)
│   │   │   ├── bat/
│   │   │   └── hog/
│   │   ├── Monster/
│   │   │   ├── monster_base_class.gd (MonsterBase extends EntityBase)
│   │   │   └── Grount/ (3-stage evolution bull)
│   │   └── npc_base_class.gd (EntityBase - abstract root)
│   ├── World/
│   │   ├── FogOfWar/
│   │   ├── MobSpawnArea/ (lazy spawning system)
│   │   └── Ground/ (TileMapLayer with navigation)
│   └── UI/
│       ├── HeroContainer/ (hero UI with ability cooldowns)
│       └── MainMenu.tscn
└── Scripts/ (autoloads + shared systems)
    ├── globals.gd, types.gd, game_utils.gd (layer/mask constants, targeting rules)
    ├── combat_events.gd, event_bus.gd, damage_packet.gd (damage pipeline)
    ├── team_registry.gd + team_blackboard.gd (threat tables)
    ├── entity_registry.gd (cached faction lists), tick_scheduler.gd (AI LOD)
    ├── hp_bar_2d.gd (in-world HP bar)
    ├── audio_manager.gd (SFX/music), analytics_sink.gd (local event log)
    ├── persisted_data.gd (versioned save), MetaSkills/ (base + per-character trees)
    └── game_manager.gd, match_rewards.gd (match flow, rewards)
    (hero_exploration_controller.gd lives in Scenes/NPCs/Hero/)
```

### Class Hierarchy

```
EntityBase (abstract base - npc_base_class.gd)
├─ HeroBase (hero_base_class.gd)
│  ├─ River (Support/Scout)
│  ├─ Vlad (DPS/Berserker)
│  ├─ Ted (DPS/Pet Master)
│  └─ Irelia (Tank/Support)
├─ MobBase (mobs_base_class.gd)
│  ├─ Bat (flying, swarm)
│  └─ Hog (ground, tanky)
└─ MonsterBase (monster_base_class.gd)
   └─ Grount (3-stage evolution)
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

// ❌ WRONG - Inheritance hell
HeroBase
└─ HeroWithStats
   └─ HeroWithAbilities
      └─ River (deeply nested, hard to modify)
```

**Why**: New heroes/abilities don't require new inheritance chains. Just compose existing components.

### 2. Resource-Based Data

**Pattern**: Separate data (Resources) from behavior (Nodes).

```gdscript
// ✅ CORRECT - Data in resources
# hero_stats.gd (Resource)
extends Resource
class_name HeroStats

@export var hero_name: String = "River"
@export var base_max_health: float = 100.0
@export var base_move_speed: float = 80.0

# stat_component.gd (Node - uses resource)
extends Node
class_name HeroStatsComponent

@export var base_stats: HeroStats  # Reference to .tres file
var current_stats: Dictionary = {}  # Runtime calculations

// ❌ WRONG - Data hardcoded in behavior
class_name River extends HeroBase
func _ready():
    max_health = 100.0  # Can't be changed without code
    move_speed = 80.0
```

**Why**: Game designers can tune stats in .tres files without touching code. Scales to hundreds of heroes.

### 3. Virtual Method Polymorphism

**Pattern**: Use virtual methods for entity-specific behavior.

```gdscript
// ✅ CORRECT - Virtual methods in base class
# EntityBase
func _get_move_speed() -> float:
    """Override in child classes"""
    return 80.0

# HeroBase
func _get_move_speed() -> float:
    return stats.get_move_speed() if stats else 80.0

# MobBase
func _get_move_speed() -> float:
    return base_move_speed

# MonsterBase
func _get_move_speed() -> float:
    return monster_stats.get_speed_for_stage(current_stage)

// ❌ WRONG - Type-checking
func get_move_speed() -> float:
    if self is HeroBase:
        return self.stats.get_move_speed()
    elif self is MobBase:
        return self.base_move_speed
    elif self is MonsterBase:
        return self.monster_stats.get_speed_for_stage(current_stage)
```

**Why**: Adding new entity types doesn't require modifying base class. Each child handles its own case.

### 4. Signal-Based Communication

**Pattern**: Systems communicate via signals, not direct calls.

```gdscript
// ✅ CORRECT - Signals
# AbilitySystem
signal ability_used(ability: AbilityBase)

func use_basic_attack(target: Node2D = null) -> bool:
    ability.execute(owner_entity, target)
    ability_used.emit(ability)  # Fire and forget
    return true

# HeroContainer (separate UI system)
func _ready():
    ability_system.ability_used.connect(_on_ability_used)

func _on_ability_used(used_ability: AbilityBase):
    # Handle UI update

// ❌ WRONG - Direct coupling
# AbilitySystem
func use_basic_attack(target: Node2D = null) -> bool:
    ability.execute(owner_entity, target)
    
    # Tightly coupled to UI
    var ui = get_node("/root/Game/UI/HeroContainer")
    ui.update_ability_icon(ability)
    return true
```

**Why**: UI can be rewritten without touching combat code. Systems remain independent.

### 5. State Machine AI

**Pattern**: Use `godotstatecharts` for entity AI.

```gdscript
// ✅ CORRECT - State machine transitions
States: Idle → Approach → Fight → Dead   (+ Dead → Idle on CombatEvents.RESET for pooled mobs)

# EntityBase. The chart's active state is STEPPED by the TickScheduler autoload
# (EntityBase._tick -> StateChart.step() -> state_stepped, wired scene-side in
# NPCBaseClass.tscn). `delta` is the time since this entity's last tick, so a
# far-away mob at 3 Hz moves the same distance per second as one at 60 Hz.
func _on_idle_state_processing(delta: float):
    # Wander, look for enemies
    if enemy_detected:
        state_chart.send_event(CombatEvents.ENEMY_ENTERED)

func _on_approach_state_processing(delta: float):
    # Chase enemy
    if distance <= attack_range:
        state_chart.send_event(CombatEvents.ENEMY_FIGHT)

func _on_fight_state_processing(delta: float):
    # Combat
    if not is_target_valid():
        state_chart.send_event(CombatEvents.TARGET_LOST)

// ❌ WRONG - Manual state flags
var is_idle = true
var is_chasing = false
var is_fighting = false

func _process(delta):
    if is_idle and enemy_detected:
        is_idle = false
        is_chasing = true
    elif is_chasing and distance <= range:
        is_chasing = false
        is_fighting = true
    # ... complex nested conditions
```

**Why**: State machines make AI behavior predictable and debuggable. Visual state chart in editor.

---

## 📐 Code Organization Standards

### File Sections (EntityBase Pattern)

All major classes follow this structure:

```gdscript
# ============================================
# SECTION 1: EXPORTS & CONFIGURATION
# ============================================
@export_group("Group Name")
@export var property: Type = default

# ============================================
# SECTION 2: ONREADY REFERENCES
# ============================================
@onready var node_ref: Node = %NodeName

# ============================================
# SECTION 3: INSTANCE VARIABLES
# ============================================
var state_var: Type = default

# ============================================
# SECTION 4: COMPUTED PROPERTIES
# ============================================
var computed: float:
    get: return _get_computed()

# ============================================
# SECTION 5: LIFECYCLE METHODS
# ============================================
func _ready() -> void:
    pass

func _process(delta: float) -> void:
    pass

# ============================================
# SECTION 6: VIRTUAL METHODS (TO OVERRIDE)
# ============================================
func _get_move_speed() -> float:
    """Override in child classes"""
    return 80.0

# ============================================
# SECTION 7+: SYSTEM-SPECIFIC SECTIONS
# ============================================
# Combat, Movement, Targeting, etc.
```

### Naming Conventions

```gdscript
// Classes
class_name HeroBase  # PascalCase

// Files
hero_base_class.gd  # snake_case

// Variables
var current_health: float  # snake_case
var is_alive: bool  # snake_case with is_ prefix for bools

// Private/Protected
var _internal_timer: float  # Underscore prefix
func _update_ai(delta: float): pass  # Underscore prefix

// Virtual Methods
func _get_move_speed() -> float:  # Underscore prefix + descriptive
    """Override in child classes"""

// Constants
const MAX_HEALTH = 100.0  # SCREAMING_SNAKE_CASE

// Signals
signal ability_used(ability: AbilityBase)  # snake_case
signal health_changed(current: float, max_value: float)

// Exports
@export var detection_radius: float = 172.0  # snake_case
```

### Documentation Standards

```gdscript
## EntityBase - Base class for all NPCs (Heroes, Monsters, Mobs)
## Handles combat, movement, targeting, and state management
## Uses godotstatecharts for AI state machine (Idle → Approach → Fight → Dead)
class_name EntityBase

func _on_fight_state_processing(delta: float) -> void:
    """Process Fight state - combat and periodic re-evaluation"""
    # Implementation

func _get_move_speed() -> float:
    """Get movement speed. Override in child classes."""
    return 80.0

# Complex logic needs explanation
func _score_target(target_node: Node2D) -> float:
    """Calculate score for a target (higher = better).
    Considers priority, distance, threat level, and engagement penalty."""
    # Implementation
```

**Rules**:
- Class docstring: High-level purpose
- Method docstring: What it does, when to override
- Inline comments: **Why**, not what
- No obvious comments: `health -= 10  # Subtract 10 from health` ❌

---

## 🎮 Gameplay Systems

### Combat System

**Architecture**:
```
EntityBase (base combat behavior)
├─ Detection → Targeting → Approach → Fight
├─ Combat Roles: MELEE, RANGED, SUPPORT
└─ Smart Targeting System (priority-based)

AbilitySystem (manages 4 slots)
├─ Passive (always active, modifiers)
├─ Active (moderate cooldown, utility)
├─ Basic Attack (primary DPS)
└─ Ultimate (high impact, long cooldown)
```

**Combat Flow**:
1. Entity enters detection range (172.0 default)
2. Smart targeting picks best target (priority + distance + threat)
3. State: Idle → Approach (chase) → Fight (combat)
4. In Fight state:
   - If attack ready + in range → **STAND STILL and attack**
   - If on cooldown → reposition based on combat role
5. Attack completes → cooldown → repeat

**Key Files**:
- `npc_base_class.gd`: Combat behavior, targeting, movement
- `ability_system.gd`: Ability management, cooldowns
- `ability_base.gd`: Ability resource base class

### Hero System

**Architecture**:
```
HeroBase (behavior)
├─ HeroStatsComponent (runtime state)
│  ├─ level: int
│  ├─ current_stats: Dictionary
│  └─ base_stats: HeroStats (resource)
└─ AbilitySystem
   └─ 4 ability slots
```

**Stat Scaling**:
```gdscript
final_stat = (base_value + level_bonus + additive_modifier) * multiplicative_modifier

# Example: Health at level 3
base_max_health = 100.0
health_per_level = 10.0
level = 3

level_bonus = 10.0 * (3 - 1) = 20.0
additive = 0.0 (no buffs)
multiplicative = 1.0 (no buffs)

final_health = (100.0 + 20.0 + 0.0) * 1.0 = 120.0
```

**Key Files**:
- `hero_base_class.gd`: Hero behavior
- `stat_component.gd`: Runtime stat calculations
- `hero_stats.gd`: Immutable stat data (resource)

### Monster System

**Evolution System**:
```
Stage 1 (Weak)     →  Stage 2 (Medium)   →  Stage 3 (God Mode)
800 HP                1400 HP                2200 HP
Base damage           1.4× damage            2× damage
2 abilities           3 abilities            3 abilities
```

**XP Thresholds**:
- Stage 1 → 2: 100 XP
- Stage 2 → 3: 300 XP

**Evolution Triggers**:
- Stat scaling (HP, damage multiplier)
- Visual scaling (sprite size)
- Ability unlocks (ability_3 unlocks at Stage 2)
- Combat behavior changes (strafe speed, intervals)

**Key Files**:
- `monster_base_class.gd`: Evolution logic
- `monster_stats.gd`: Stage-based stat data

### Mob System

**Spawn Areas**:
- 42 total spawn areas across map
- Lazy spawning: Only spawn when heroes/monster nearby
- Despawning: Remove distant mobs, track as "debt"
- Leashing: Mobs return to spawn if too far

**Optimization**:
```
Spawn Debt System:
- Inactive area: debt = 3 (no real mobs)
- Hero approaches (800m)
- Area activates: spawn 3 mobs, debt = 0
- Hero leaves (1200m)
- Area deactivates: despawn mobs, debt = 3
```

**Key Files**:
- `mobs_base_class.gd`: Mob behavior
- `mob_spawn_area.gd`: Lazy spawning, leashing

---

## ⚡ Performance Systems

Measured with the **F3 debug overlay** (FPS, process/physics ms, node count, Phys2D objects and
collision pairs, registry counts, LOD bucket counts). Stress config for profiling: `SpawnManager`
`min/max_active_spawns = 39`, `enable_lazy_activation = false`, `stress_mob_multiplier = 2`.

### 1. Lazy Spawning / Despawning (`SpawnManager` + `MobSpawnArea`)

```gdscript
# MobSpawnArea exports (per camp, visualised by the SpawnZone children)
@export var lazy_spawning: bool = true
@export var activation_radius: float   # World camps: 200 px
@export var deactivation_radius: float # World camps: 300 px (hysteresis)
# SpawnManager: 26–30 of 39 camps are world-eligible; a camp only holds a
# virtual_count until a hero (EntityRegistry.hero_side) is inside its ring.
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
not camera-based, because lazy activation only spawns mobs near heroes. Camera visibility only
pauses off-screen sprite animation (`ScreenNotifier`). Movement steps are clamped to the remaining
distance and `_face` uses an exponential lerp so low rates stay correct.

### 3. Mob Pooling (`SpawnManager.acquire_mob / release_mob`)

Dead and despawned mobs are parked **out of the tree** (so `_exit_tree` unregisters them from
TeamRegistry / EntityRegistry / TickScheduler) and reused. `MobBase.prepare_for_pool` scrubs
per-life state, `reset_for_spawn` + `on_spawned` restore it, `CombatEvents.RESET` drives the chart
Dead → Idle. `life_id` increments per life — anything that holds a mob reference across frames
(trap cage, taunt) must compare it before acting. Projectile / particle pooling: still TODO.

### 4. Faction Collision Layers (`project.godot` `[layer_names]`, `GameUtils.LAYER_* / MASK_*`)

Each entity exposes ONE monitorable Area2D (`Body`, r≈31) on its faction layer
(hero 2 / mob 4 / monster 8). `DetectionArea` is on no layer and masks enemy bodies only, so mob
vs mob areas never pair and AoE queries see each entity once. Abilities live on layer 16 and set
an explicit `collision_mask` on every `intersect_shape`.

### 5. EntityRegistry + targeted damage

`EntityRegistry` (autoload) keeps `heroes / hero_side / mobs / monsters / enemies` lists — never
call `get_nodes_in_group` in a per-frame path. `EventBus._route_packet` calls the target's
`_on_damage_taken` directly; `damage_applied` is for global listeners only.

### 6. HpBar2D

In-world HP bars are one `Node2D` with a `_draw` (`Scripts/hp_bar_2d.gd`), written only through
`EntityBase.set_hp_display`. Mobs hide the bar while full.

---

## 🚫 Anti-Patterns to Avoid

### ❌ Don't: Hardcode Game Data

```gdscript
// ❌ WRONG
class_name River extends HeroBase
func _ready():
    max_health = 120.0
    move_speed = 85.0
    
// ✅ CORRECT
# river_stats.tres (Resource file)
hero_name = "River"
base_max_health = 120.0
base_move_speed = 85.0

# river.gd
class_name River extends HeroBase
# No hardcoded stats - uses stats component
```

### ❌ Don't: Use Type Checking

```gdscript
// ❌ WRONG
func get_damage(entity: Node2D) -> float:
    if entity is HeroBase:
        return entity.stats.get_attack_damage()
    elif entity is MobBase:
        return entity.base_attack_damage
    elif entity is MonsterBase:
        return entity.get_current_damage()

// ✅ CORRECT
func get_damage(entity: Node2D) -> float:
    return entity._get_attack_damage()  # Virtual method

# EntityBase
func _get_attack_damage() -> float:
    return 10.0

# HeroBase, MobBase, MonsterBase override as needed
```

### ❌ Don't: Tightly Couple Systems

```gdscript
// ❌ WRONG
class_name AbilitySystem
func use_ability(ability: AbilityBase):
    ability.execute()
    var ui = get_node("/root/Game/UI/HeroContainer")
    ui.update_cooldown(ability)  # Direct dependency

// ✅ CORRECT
class_name AbilitySystem
signal ability_used(ability: AbilityBase)

func use_ability(ability: AbilityBase):
    ability.execute()
    ability_used.emit(ability)  # Fire and forget

# HeroContainer connects to signal separately
```

### ❌ Don't: Put Logic in _process Unless Necessary

```gdscript
// ❌ WRONG - Runs every frame
func _process(delta: float):
    check_for_enemies()  # 60 times per second
    update_pathfinding()

// ✅ CORRECT - State-based or timer-based
func _on_idle_state_processing(delta: float):
    _idle_timer -= delta
    if _idle_timer <= 0.0:
        _idle_timer = idle_retarget_time
        check_for_enemies()
        update_pathfinding()
```

### ❌ Don't: Premature Optimization

```gdscript
// ❌ WRONG - Optimizing before profiling
var damage_cache: Dictionary = {}
func get_damage(entity: Node2D) -> float:
    if damage_cache.has(entity):
        return damage_cache[entity]
    var dmg = calculate_damage(entity)
    damage_cache[entity] = dmg
    return dmg

// ✅ CORRECT - Simple first, optimize if needed
func get_damage(entity: Node2D) -> float:
    return calculate_damage(entity)
# Profile → identify bottleneck → then optimize
```

---

## ✅ When Adding New Features

### Checklist for New Heroes

```
[ ] Create hero folder in Scenes/NPCs/Hero/Heros/{Role}/{HeroName}/
[ ] Create HeroStats resource (.tres file) with base stats
[ ] Create hero script extending HeroBase
[ ] Override virtual methods (_get_move_speed, etc.) ONLY if needed
[ ] Create 4 abilities (passive, active, basic_attack, ultimate)
[ ] Add abilities to .tres resource exports, not hardcoded
[ ] Test with existing AbilitySystem (no changes needed)
[ ] Add to combat role groups (melee/ranged/support)
[ ] Create portrait image (Texture2D)
[ ] No modification to HeroBase or EntityBase needed
```

### Checklist for New Abilities

```
[ ] Create ability script extending AbilityBase
[ ] Set ability_type enum (PASSIVE/ACTIVE/BASIC_ATTACK/ULTIMATE)
[ ] Implement execute(caster, target, override_damage) method
[ ] Implement can_use(caster) if needed (default: true)
[ ] For passives: Implement on_passive_update(caster, delta)
[ ] Create .tres resource file with icon and stats
[ ] Use damage multipliers from passive abilities
[ ] Signal ability_used handled by AbilitySystem (automatic)
[ ] No modification to AbilitySystem needed
```

### Checklist for New Mobs

```
[ ] Create mob folder in Scenes/NPCs/Mob/{MobName}/
[ ] Create mob script extending MobBase
[ ] Set base stats as exports (@export var max_health: float)
[ ] Override _on_fight_logic for custom attack behavior
[ ] Add to "Enemy" group for targeting
[ ] Set xp_value for progression
[ ] Create MobSpawnArea with mob_scene reference
[ ] Enable lazy spawning for performance
[ ] Test leashing and respawning
[ ] No modification to MobBase needed (unless new behavior)
```

---

## 🔧 Common Development Tasks

### Task: Add New Stat to Heroes

**Steps**:
1. Add to `HeroStats` resource:
```gdscript
# hero_stats.gd
@export var base_critical_chance: float = 0.05
```

2. Add to `HeroStatsComponent`:
```gdscript
# stat_component.gd
var current_stats := {
    "max_health": 0.0,
    "critical_chance": 0.0,  # Add here
}

func _recalculate_all_stats() -> void:
    _recalculate_stat("critical_chance", base_stats.base_critical_chance, 0.0)

func get_critical_chance() -> float:
    return current_stats.critical_chance
```

3. Use in abilities:
```gdscript
# In ability execute()
var crit_chance = caster.stats.get_critical_chance()
if randf() < crit_chance:
    damage *= 2.0  # Critical hit!
```

**No changes to HeroBase or EntityBase needed**.

### Task: Balance Mob Difficulty

**Steps**:
1. Open mob scene in editor
2. Adjust Inspector exports:
   - `max_health`
   - `base_move_speed`
   - `base_attack_damage`
   - `attack_cooldown`
3. Save scene

**No code changes needed**.

### Task: Add LOD to New Entity Type

**Steps**:
1. Extend `EntityBase` — registration with TickScheduler / EntityRegistry / TeamRegistry happens
   in `EntityBase._enter_tree`, nothing to call.
2. Override `_is_always_full_rate()` → `true` only for camera anchors (heroes, monster).
3. Put per-tick work that is independent of the active state in `_pre_tick(delta)`; keep the
   `_on_*_state_processing(delta)` overrides rate-invariant (`speed * delta`, `timer -= delta`).
4. Do NOT add `_process` for AI — it would run every frame regardless of LOD.

### Task: Debug Performance Issue

**Steps**:
1. Press **F3** in a match: FPS, process/physics ms, node count, Phys2D objects + collision pairs,
   `Registry: H P M Mob`, `LOD FULL/NEAR/MID/FAR` counts, and per-entity `state [LOD]` labels.
2. Reproduce with the stress config (see top of this section) so numbers are comparable.
3. Profile with the Godot profiler (Debug → Profiler): `TickScheduler._process`, `_steer_along_nav`,
   Physics 2D.
4. Optimize hot paths only; record before/after numbers in `PROGRESS.md`.

**Don't optimize blindly**.

---

## 🧪 Testing Guidelines

### Automated (run before every commit)

```bash
tools/lint.sh               # loads every script/scene on a temp copy → compile errors
tools/run_tests.sh          # the test suite (GODOT=/path/to/godot overrides the binary)
```

The script copies the project to a temp dir, writes an `override.cfg` that points `user://` at
`evolvemobile_tests` (the real save file is never touched — tests that write the save refuse to
run otherwise), imports with the installed Godot and runs `test/run_tests.gd`. Exit 1 on any
failed assertion or `SCRIPT ERROR`.

Writing a test: add `test/test_<topic>.gd` extending `TestCase` (`test/case.gd`); every
`test_*` method runs, may `await`, and uses `assert_eq / assert_true / assert_near / skip`.
Helpers: `spawn_entity(scene, pos)` (adds under the test and waits for the awaited `_ready`),
`active_state_of(entity)`, `wait_frames / wait_physics_frames / wait_seconds`. Nodes a test
leaves behind are freed between tests. `GameManager.match_ended_flag` is set so deaths never end
a match. Current coverage: rewards formula, level curve, save migration, meta-skill gating and
per-character trees, targeted damage hook, death from Idle/Approach for mob/hero/monster, spawn
accounting + pooled respawn, tutorial, audio manager, analytics sink.

### Manual Testing Checklist

```
[ ] Heroes spawn and move correctly
[ ] Mobs spawn in designated areas; camps activate/deactivate with the F3 LOD readout
[ ] Monster evolves at 100 / 300 XP
[ ] Combat: entities stop moving when attacking; Hogs attack
[ ] Abilities trigger cooldowns; AoE hits each target once
[ ] UI shows health, abilities, levels correctly; mob bars appear only when damaged
[ ] Fog of war reveals/unreveals properly (both sides)
[ ] Killed mobs respawn from the pool after 40 s with full HP
[ ] FPS stable at 60 on target device (F3: stress config)
[ ] No memory leaks: OBJECT_NODE_COUNT plateaus while walking camp rings
```

### Debug Flags to Enable

```gdscript
# MobSpawnArea
show_debug_area = true  # Visualize ranges

# EntityBase
show_detection_radius = true  # Show detection range

# TickScheduler (inspector on the autoload, or at runtime)
lod_enabled = false     # A/B: tick everything every frame
```

---

## 📚 Key Files Reference

### Core Systems

| File | Purpose | Modify When |
|------|---------|-------------|
| `npc_base_class.gd` | EntityBase - all NPC behavior | Rarely - affects all entities |
| `hero_base_class.gd` | HeroBase - hero-specific behavior | Adding hero-wide features |
| `mobs_base_class.gd` | MobBase - mob-specific behavior | Adding mob-wide features |
| `monster_base_class.gd` | MonsterBase - evolution system | Changing evolution rules |
| `ability_system.gd` | Manages 4 ability slots | Rarely - system is stable |
| `ability_base.gd` | Base class for abilities | Rarely - extend, don't modify |
| `stat_component.gd` | Runtime stat calculations | Adding new stats |
| `hero_stats.gd` | Immutable hero data | Adding stat properties |
| `Scripts/event_bus.gd` | Damage pipeline (request → receive → `_on_damage_taken` → applied) | Adding global combat listeners |
| `Scripts/team_registry.gd` / `team_blackboard.gd` | Threat tables, aggro queries | Coordination behaviour |
| `Scripts/entity_registry.gd` | Cached faction lists, anchors, singletons | Any per-frame entity lookup |
| `Scripts/tick_scheduler.gd` | AI LOD, `StateChart.step()` cadence | Tuning LOD radii / rates |
| `Scripts/hp_bar_2d.gd` | In-world HP bar | Bar visuals |
| `Scripts/audio_manager.gd` | SFX/music, placeholder synthesis, asset lookup | Adding sounds |
| `Scripts/analytics_sink.gd` | Local event log, provider hook | Adding tracked events |
| `Scripts/persisted_data.gd` | Save file, versioning + migration ladder | Any save-layout change (bump + `_migrate_vN_to_vN1`) |
| `Scripts/MetaSkills/meta_skill_manager.gd` | Base + per-character skill trees | Adding nodes / trees |

### World Systems

| File | Purpose | Modify When |
|------|---------|-------------|
| `spawns.gd` (SpawnManager) | Camp eligibility, lazy activation, mob pool | Population / pooling |
| `mob_spawn_area.gd` | Per-camp spawning, respawn accounting, leashing | Tuning camps |
| `game_manager.gd` | Victory/defeat detection | Changing win conditions |
| `hero_exploration_controller.gd` | Group pathfinding | Tweaking exploration |

### UI Systems

| File | Purpose | Modify When |
|------|---------|-------------|
| `hero_container.gd` | Hero UI, ability cooldowns | Adding UI features |
| `Scenes/UI/Tutorial/tutorial_overlay.gd` | First-run walkthrough (data-driven steps) | Changing onboarding |
| `Scenes/UI/Settings/settings_screen.gd` | Volumes, privacy toggle, reset | Adding settings |
| `fps_counter.gd` | FPS label (MainCam) | Never - it's complete |
| `debug_overlay.gd` | F3 overlay: perf counters, states, LOD, threat | Adding debug readouts |

---

## 🎓 Learning Resources

### Understanding the Codebase

**Start here**:
1. Read `npc_base_class.gd` sections 1-6 (exports, lifecycle, virtual methods)
2. Look at `hero_base_class.gd` to see how it overrides virtual methods
3. Check `river.gd` (simplest hero) for minimal overrides
4. Read `ability_system.gd` to understand the 4-slot system
5. Look at Vlad's `basic_melee_strike.gd` (`BasicStrike`, shared by the heroes' basic attacks) for the simplest ability example

**State Machine Flow**:
```
EntityBase:
Idle → (enemy detected) → Approach → (in range) → Fight → (target lost) → Idle
                                                     ↓
                                                   Dead
```

**Key Concepts**:
- **Virtual Methods**: Base class defines interface, children override
- **Resources**: .tres files = data, .gd scripts = behavior
- **Signals**: Decoupled communication between systems
- **State Charts**: Visual AI behavior in editor

---

## 🚀 Future-Proofing Checklist

When adding new code, ask:

```
[ ] Can this be a resource instead of hardcoded?
[ ] Does this belong in a component or the base class?
[ ] Am I using signals or direct calls?
[ ] Is this a virtual method or type-checking?
[ ] Will adding 100 more heroes/abilities break this?
[ ] Does this run every frame or only when needed?
[ ] Can a designer tune this without code changes?
[ ] Is this self-explanatory or does it need comments?
```

---

## 📞 Getting Help

When asking for help, provide:

1. **What you're trying to do** (goal)
2. **What you've tried** (attempted solution)
3. **What happened** (actual result)
4. **What you expected** (expected result)
5. **Relevant code snippet** (minimal reproduction)

**Example**:
```
Goal: Add critical hit chance to heroes
Tried: Added stat to HeroStats resource
Result: stat_component.gd doesn't recognize it
Expected: stat_component.get_critical_chance() works
Code: [snippet from stat_component.gd]
```

---

## 🎯 TL;DR - Quick Reference

**Adding Content**:
- New Hero → Extend HeroBase, create HeroStats .tres
- New Ability → Extend AbilityBase, create .tres
- New Mob → Extend MobBase, set stats in Inspector

**Modifying Behavior**:
- Change how ALL entities work → EntityBase
- Change how heroes work → HeroBase
- Change specific hero → Hero script (river.gd)

**Performance**:
- Spawn optimization → MobSpawnArea (lazy spawning)
- AI optimization → EntityBase (LOD system)
- Don't optimize → Until profiler says to

**Priorities**:
1. Clean, maintainable code
2. Future-proof architecture
3. Scalable systems
4. Measured performance

**Mantras**:
- "Composition over inheritance"
- "Resources for data, nodes for behavior"
- "Signals over direct calls"
- "Virtual methods over type-checking"
- "Profile before optimizing"

---

**Remember**: Max values clean, maintainable code that can scale to hundreds of heroes and abilities without architectural rewrites. Make decisions with this in mind.
