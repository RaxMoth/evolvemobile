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
│   │   │   │   ├── ability_system.gd (AbilitySystem node - manages 4 slots)
│   │   │   │   └── Shared/ (reusable abilities)
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
└── Scripts/
    └── Systems/
        ├── game_manager.gd (victory detection)
        └── hero_exploration_controller.gd (group pathfinding)
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
States: Idle → Approach → Fight → Dead

# EntityBase
func _on_idle_state_processing(delta: float):
    # Wander, look for enemies
    if enemy_detected:
        state_chart.send_event("enemie_entered")

func _on_approach_state_processing(delta: float):
    # Chase enemy
    if distance <= attack_range:
        state_chart.send_event("enemy_fight")

func _on_fight_state_processing(delta: float):
    # Combat
    if not is_target_valid():
        state_chart.send_event("target_lost")

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

### 1. Lazy Spawning/Despawning

**MobSpawnArea Optimization**:
```gdscript
@export var enable_lazy_spawning: bool = true
@export var activation_range: float = 800.0
@export var despawn_range: float = 1200.0

# Only 5-8 of 42 spawn areas active at once
# ~20-30 mobs instead of ~126
```

**Impact**: +15-25 FPS

### 2. LOD (Level of Detail) System

**EntityBase LOD**:
```gdscript
@export var enable_lod: bool = true
@export var lod_distance_full: float = 600.0      # Every frame
@export var lod_distance_reduced: float = 1000.0  # Every 2nd frame
@export var lod_distance_minimal: float = 1500.0  # Every 5th frame
# Beyond 1500m: Frozen (no processing)
```

**Impact**: +20-30 FPS

**When to Use**:
- ✅ Mobs: Always enable LOD
- ✅ Monsters: Optional (it's a main character)
- ❌ Heroes: Disable LOD (player-controlled)

### 3. Object Pooling (Not Yet Implemented)

**Future optimization for projectiles, particles, damage numbers**:
```gdscript
// TODO: Implement object pooling
var arrow_pool: Array[Arrow] = []

func get_arrow() -> Arrow:
    if arrow_pool.is_empty():
        return Arrow.new()
    return arrow_pool.pop_back()

func return_arrow(arrow: Arrow):
    arrow.reset()
    arrow_pool.append(arrow)
```

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
1. In entity script, ensure it extends EntityBase
2. Call `super._process(delta)` first if overriding _process
3. In Inspector:
   - ✅ Enable LOD
   - Set distance thresholds

**EntityBase handles LOD automatically**.

### Task: Debug Performance Issue

**Steps**:
1. Add FPS counter (fps_counter.gd)
2. Enable debug output in spawn areas
3. Check console for:
   - `[SPAWN] X activated/deactivated`
   - `[LOD] Entity: FULL → REDUCED`
4. Profile with Godot profiler (Debug → Profiler)
5. Identify hot paths (functions called most often)
6. Optimize hot paths only

**Don't optimize blindly**.

---

## 🧪 Testing Guidelines

### Manual Testing Checklist

```
[ ] Heroes spawn and move correctly
[ ] Mobs spawn in designated areas
[ ] Monster evolves at correct XP thresholds
[ ] Combat: entities stop moving when attacking
[ ] Abilities trigger cooldowns
[ ] UI shows health, abilities, levels correctly
[ ] Fog of war reveals/unreveals properly
[ ] Spawn areas activate/deactivate based on distance
[ ] LOD changes visible in debug output
[ ] FPS stable at 60+ on target device
[ ] No memory leaks (mobs despawn properly)
```

### Debug Flags to Enable

```gdscript
# MobSpawnArea
show_debug_area = true  # Visualize ranges

# EntityBase
show_detection_radius = true  # Show detection range

# Check console for:
OS.is_debug_build()  # Only print debug in debug builds
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

### World Systems

| File | Purpose | Modify When |
|------|---------|-------------|
| `mob_spawn_area.gd` | Lazy spawning, leashing | Tuning performance |
| `game_manager.gd` | Victory/defeat detection | Changing win conditions |
| `hero_exploration_controller.gd` | Group pathfinding | Tweaking exploration |

### UI Systems

| File | Purpose | Modify When |
|------|---------|-------------|
| `hero_container.gd` | Hero UI, ability cooldowns | Adding UI features |
| `fps_counter.gd` | Performance monitoring | Never - it's complete |

---

## 🎓 Learning Resources

### Understanding the Codebase

**Start here**:
1. Read `npc_base_class.gd` sections 1-6 (exports, lifecycle, virtual methods)
2. Look at `hero_base_class.gd` to see how it overrides virtual methods
3. Check `river.gd` (simplest hero) for minimal overrides
4. Read `ability_system.gd` to understand the 4-slot system
5. Look at `BasicMeleeAttack` for simplest ability example

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
