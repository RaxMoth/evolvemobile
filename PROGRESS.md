# Progress Tracker

Last loop run: 2026-10-14 (test harness + ToDead path fix)
Stack: godot

Spec source: `README.md` + `Docs/INSTRUCTOR.md` (roadmap, "Current Status & Roadmap",
"Known Issues & Tech Debt", v0.2–v1.0 phase lists).

## Done

- [x] EventBus damage pipeline — DamagePacket + request/apply, listeners (shields, threat) — recent commits
- [x] Typed CombatEvents constants replacing stringly state-chart events (fixed "enemie" typo)
- [x] TeamRegistry + TeamBlackboard — shared threat table, aggro, focus queries
- [x] Combat feel pass — smooth rotation (`_face`), flinch, personal distance jitter, taunt_strength
- [x] Lazy/virtual MobSpawnArea + SpawnManager proximity activation (4 Hz), visual SpawnZone children
- [x] Fog of war perf fix — 1×1 canvas + `ImageTexture.update()` (was 180 MB texture + per-reveal realloc)
- [x] Side-aware vision — monster reveals fog when playing monster-side
- [x] Interactive camera — click/1-4/Tab hero select, smooth target switch, F3 DebugOverlay
- [x] PersistedData autoload — ConfigFile save (currency, hero/monster XP, skill unlocks, settings)
- [x] MatchRewards + GameManager — 10-min cap, kill/stage tracking, 3 end paths, reward grant
- [x] MatchResult screen — stats + rewards + Play Again / Main Menu (scene-side connections)
- [x] Side selection — GameManager.chosen_side plumbed to camera + hero UI + vision + rewards
- [x] In-world HP bars pinned to fixed pixel size (+ monster counter-scale through evolution)
- [x] MetaSkill system — MetaSkillManager autoload, Hero Base (12 nodes) + Monster Base (7 nodes) trees,
      MetaSkillScreen UI, applied to heroes on spawn
- [x] Code→scene cleanup — groups/signals/exports/process_mode moved scene-side; dead fog_world file
      removed; Mine.tscn root-type + bare-`range` bugs fixed
- [x] Beautified Main Menu — ui_theme.tres, portrait layout, gradient bg, title, currency chips,
      themed side cards with intro/hover animations
- [x] **Monster Base skill tree now consumed by MonsterBase** — health/damage/speed/xp/evo-threshold/range
      multipliers applied on spawn — `fdb36c6`
- [x] **Crash fix: null-target deref in Approach/Fight processing** — re-eval can clear target mid-frame;
      added validity-bail guards (iteration 2 — see Changelog)
- [x] **Permanent XP awarded & persisted on match end** — data slice of the Permanent XP System —
      `eeb2234`
- [x] **Permanent XP System — level readout on Main Menu cards** — quadratic level curve in
      PersistedData + per-hero + monster "Progression" strips that react live to the `*_xp_changed`
      signals (iteration 4 — see Changelog)

## In Progress

- [ ] **Performance pass (plan: 60 FPS @ ~150 live mobs on a mid-range phone)** — code phases
      P0→P5 all landed (see Changelog 2026-10-14). Remaining: capture before/after F3 numbers in the
      editor (stress config: SpawnManager min/max_active_spawns = 39, enable_lazy_activation = false,
      stress_mob_multiplier = 2), playtest the P1 balance change, then the production roadmap below.

## Backlog (from spec + production roadmap, in order)
- [ ] Perf pass follow-up: capture F3 before/after numbers (stress config), playtest the P1 balance
      change, retune `detection_radius` / AoE radii / Mine-MediKit-TrapCage trigger radii
- [ ] Audio content on the existing buses — `audio_manager.gd` autoload subscribed to
      `EventBus.damage_applied` / `entity_died` / `ability_cast` + a new `monster_evolved`; pooled
      SFX players, on-screen gating, 50 ms de-dupe; assets under `Assets/Audio/`
- [x] Headless test harness (`tools/run_tests.sh`, `test/`) — rewards, level curve, tier gating,
      targeted damage hook, death from Idle/Approach, spawn accounting + pooled respawn + epoch cancel.
      (Own 60-line runner instead of vendoring GUT; extend with `test/test_*.gd` extending `TestCase`.)
- [ ] Save-file migration — `_migrate(from_version)` ladder, `.bak` before write, version bump
- [ ] Export presets + device build — Android/iOS portrait, `max_fps=60`, `treat_warnings_as_errors`,
      Compatibility-vs-Mobile renderer benchmark (features tag says GL Compatibility), physics 30 Hz trial
- [ ] Touch-input audit — pinch zoom, tap-to-focus, ≥44 px targets; debug keys behind `OS.is_debug_build()`
- [ ] `print()` gating — `Globals.debug_log()` for world.gd (15), monster_base_class.gd (8), spawns.gd, abilities
- [ ] Pre-Round Setup screen — `MatchConfig` resource (aggression/farming/exploration, formation)
- [ ] Per-hero skill trees (Steel) + per-monster trees (Leaves) — seeds → `.tres`, `hero_id` on HeroStats
- [ ] Hero composition selection — `HeroRoster.tres`, World spawns from `GameManager.selected_hero_ids`
- [ ] Tutorial / first-time-user flow
- [ ] Minimap with fog overlay (SubViewport over `exploration_texture` + EntityRegistry dots)
- [ ] Cloud save (`SaveBackend`), localization (`tr()` + strings.csv), analytics sink

## Proposed (NOT approved — do not implement)

- (none)

## Tech Debt / Improvements

- [ ] Debug `print()` statements still in hot/spawn paths — `world.gd` (15), `monster_base_class.gd` (8),
      `spawns.gd` (2), ability files. Gate behind a debug flag or remove (Backlog item).
- [x] `MonsterBase.get_health()` returned *max* health — fixed in P0: `get_health()` = current,
      new virtual `get_max_health()` on EntityBase (Mob/Hero/Monster overrides).
- [ ] Balance retune after P1 layer split (aggro 344→~203 px, AoE reach radius+172→radius+31, single
      hits, Mine/MediKit/TrapCage trigger on Body overlap) — playtest `detection_radius` + AoE radii.
- [x] Movement no longer runs on the state chart's per-frame `state_processing` — P4 drives the
      active state through `StateChart.step()` from TickScheduler at an LOD rate (FULL/20/10/3 Hz).
- [x] Hot `get_nodes_in_group` sites → `EntityRegistry` (P3). ~20 cold one-shot/per-cast sites remain
      (world.gd, main_cam.gd, game_manager.gd, hero_container.gd, Irelia/River casts) — fine as is.
- [x] Legacy in-round `Scripts/Skilltree/` removed (zero references outside the folder).

## Changelog

### 2026-10-14 — test: headless harness + fix: CompoundState ToDead target path
- **Bug caught by the first test run:** the P0a `ToDead` transition placed on the CompoundState used
  `to = NodePath("Dead")`. The addon resolves `to` relative to the *transition node*, so the target
  did not exist ("The target state 'Dead' … is not a state") and **nothing could die** in the
  committed P0–P5 state. Fixed to `NodePath("../Dead")` (`Dead/ToIdle` already used `../../Idle`).
- `test/run_tests.gd` (SceneTree runner, starts on the first processed frame — `_initialize` runs
  before the root is in the tree), `test/case.gd` (`TestCase`: assertions, `spawn_entity`,
  `active_state_of`, frame/time waits; leftovers freed between tests),
  `tools/run_tests.sh` (copies the project to a temp dir, `override.cfg` points `user://` at
  `evolvemobile_tests` so the real save is never touched — the meta-skill tests refuse to run
  otherwise — imports with Godot 4.7.2 headless and runs the suite; exit 1 on failure or script
  errors). GUT was not vendored (would need a download); the runner is ~60 lines.
- 15 tests: `MatchRewards.compute` formula + clamping + `format_duration`; `level_progress`
  boundaries; tier gating + spending + double-unlock; targeted flinch hook; mob / hero / monster die
  from Idle and Approach and get freed; pooled toggle keeps `total_mob_count` and reuses the same
  nodes; dead mob respawns from the pool with full HP in Idle with a new `life_id`;
  `reset_population` cancels a pending respawn.

### 2026-10-14 — docs: reconcile README / INSTRUCTOR with the code after the performance pass
- README: monster stage table (XP 100/300 from `grount_stats.tres`, flat 80 attack range), spawn
  system facts (39 camps / 116 mobs, 26–30 eligible, 200/300 px rings, 40 s respawn, pooling),
  state machine section (Approach, stepped by TickScheduler, Dead→Idle reset), Implemented list
  gains the Main Menu / Settings / Meta Skills / result screen / permanent XP / 10-min cap /
  side-aware vision / perf pass; stale "In Development" entries replaced by the production
  roadmap; known-issues updated (fog fix, loss timer done, perf status).
- INSTRUCTOR: state-machine pattern uses `CombatEvents` and explains stepping; Performance
  Systems rewritten around the real systems (lazy spawning exports, TickScheduler buckets, mob
  pool, faction layers, EntityRegistry, HpBar2D); LOD / perf-debug tasks and Key Files updated;
  file-structure block lists the real `Scripts/` autoloads.
- Deleted dead `Scripts/Skilltree/`; `.claude/settings.local.json` now allow-lists the Godot binary
  that actually exists (`/Applications/Godot.app`).
- Backlog reordered into the production roadmap (Part B of the approved plan).

### 2026-10-14 — perf: P5 HpBar2D, mob pooling, raycast-free idle scoring
- **HpBar2D** (`Scripts/hp_bar_2d.gd`): one Node2D with a `_draw` replaces the per-entity
  `Control > HBoxContainer > ProgressBar + Label` subtree (4 nodes, a Control layout pass and two
  `StyleBoxFlat.new()` per spawn). Redraws only on change; mobs set `hide_when_full` scene-side
  (`mobs_base_class.tscn`) so idle camps draw nothing. `EntityBase.set_hp_display(cur, max)` is
  the single writer; every former `health_bar.value/max_value` site (Mob/Hero/Monster/MobSpawnArea)
  routes through it. `LVLabel` now lives only in `HeroBaseClass.tscn` / `monster_base_class.tscn`
  (`lv_label` resolves via `get_node_or_null`). `_apply_ui_counter_scale` counter-scales the bar
  and label directly (monster evolution). Dangling `Control` offset overrides in Vlad/Ted removed.
- **Mob pooling** (owned by `SpawnManager`, no new autoload): `acquire_mob(scene)` /
  `release_mob(mob)` with `pool_enabled` + `pool_cap_per_scene` exports. Dead AND deactivated mobs
  are parked out of the tree with `remove_child` (so `_exit_tree` unregisters them from
  TeamRegistry — which scrubs threat rows — EntityRegistry and TickScheduler). Chart reset path:
  `CombatEvents.RESET` + a `Dead → Idle` transition in `NPCBaseClass.tscn`;
  `EntityBase.reset_to_idle()` sends ENEMY_EXITED / TARGET_LOST / RESET. `_on_dead_state_entered`
  now ends in a virtual `_release_or_free()` (MobBase → deferred `release_mob`, others
  `queue_free`). `MobBase.prepare_for_pool()` scrubs target/timers/flags/effects (health is NOT
  restored while parked so nobody keeps targeting it), `reset_for_spawn()` + `on_spawned()`
  (heal + `reset_to_idle()` after `add_child`). `life_id` increments per life; Ted's trap cage
  snapshots it (`_still_trapped`) and kills its looping flash tween on expire / respawn (the cage was
  also teleporting the Body Area2D instead of the mob — fixed in P1); Irelia's taunt tags its
  TauntEffect / Line2D children with group `TransientEffect` so the pool scrubs them.
  `is_target_valid()` now also requires `is_inside_tree()` and alive. `MobSpawnArea` hooks `died`
  (ONE_SHOT) instead of `tree_exiting`; `SpawnManager._exit_tree` frees parked mobs.
- **Idle scoring without raycasts:** `_score_destination` uses
  `NavigationServer2D.map_get_closest_point` on the world map (>16 px off-mesh → rejected) instead
  of 5×20 `intersect_ray` + 12 more per candidate that could only ever hit Ted's pet (TileSet has
  no physics layer). `GameUtils` wall helpers kept with a note.
- Verified: headless import + load of 82 scripts / 60 resources — 0 errors; `intersect_ray`,
  `StyleBoxFlat.new`, `tree_exiting.connect` and direct `health_bar.value` writes all gone from the
  entity/world scripts.

### 2026-10-14 — perf: P4 TickScheduler + anchor-based AI LOD through `StateChart.step()`
- New `Scripts/tick_scheduler.gd` autoload. EntityBase registers in `_enter_tree`; the scheduler
  calls `entity._tick(delta)` at a per-entity rate and `_tick` runs `state_chart.step()`. The
  addon routes `step()` to the active leaf's `state_stepped` signal, which `NPCBaseClass.tscn` now
  connects (instead of `state_processing`) to `_on_idle/approach/fight_state_stepped` → these call
  the unchanged `_on_*_state_processing(delta)` virtuals with the tick's delta, so the MobBase /
  Irelia / River overrides keep working untouched. **No parallel state machine**: transitions,
  events and `state_entered` handlers are exactly as before; only the cadence moved. With no
  `state_processing` listeners left the addon disables `_process` on every state node.
- Buckets are **anchor-based** (squared distance to the nearest hero / pet / monster via
  `EntityRegistry.nearest_anchor_dist_sq`), not camera-based — lazy activation only spawns mobs
  within ~300 px of a hero, so camera LOD would have throttled exactly the mobs fighting an
  off-screen hero. FULL = heroes/monster (`_is_always_full_rate`) or on screen
  (new `ScreenNotifier` VisibleOnScreenNotifier2D, scene-side `screen_entered/exited`);
  NEAR 20 Hz = has a target or < 450 px; MID 10 Hz < 1200 px; FAR 3 Hz. Rebucket at 4 Hz, phase
  spread on register, snapshot + tombstone iteration (handlers may kill/spawn entities mid-loop),
  `MAX_TICK_DELTA` 0.5 s hitch guard, `lod_enabled` export for A/B. Visual LOD: off-screen
  entities pause their AnimatedSprite2D (initial state seeded in `_ready`).
- Delta correctness for low rates: `_steer_along_nav` / `move_toward_point` clamp the step to the
  remaining distance (a 150 px/s Bat at 3 Hz overshot 6 px path points by ~45 px);
  `_face` uses `1 - exp(-k·dt)` (the linear `clamp(k·dt)` snapped at ≤ 12 Hz); idle / re-eval /
  strafe timers keep their overshoot instead of rounding up to whole ticks.
- `_setup_navigation` resolves `get_world_2d().navigation_map` — the old `'Ground'` sibling lookup
  only ever matched for the monster, so mobs/heroes never got the tuned agent distances. Same fix
  for Ted's pet (it logged "cannot find Ground tilemap" on every spawn).
- `MobBase._process` (per-frame leash/boundary check) → `_pre_tick`. `animated_sprite` onready
  moved from MonsterBase to EntityBase.
- F3 overlay: `[FULL|NEAR|MID|FAR]` after each entity's state name + a bucket-count line.
- Verified: headless import + load of 81 scripts / 60 resources — 0 errors; `state_processing` →
  0 and `state_stepped` → 3 in `NPCBaseClass.tscn`; no `_process` in `mobs_base_class.gd`.

### 2026-10-14 — perf: P3 EntityRegistry autoload (cached faction lists)
- New `Scripts/entity_registry.gd` (autoload after TeamRegistry): `heroes` (HeroBase only),
  `hero_side` (everything in group "Hero" = heroes + pets, the set the old scans returned), `mobs`,
  `monsters`, `enemies`; queries `nearest()`, `count_within(stop_at)`, `nearest_anchor_dist_sq()`
  (for P4's LOD buckets), `first_monster()`, `singleton(group)` (cached `get_first_node_in_group`,
  re-fetched if the node was freed / left the tree). All distance math squared.
- Registration moved to lifecycle hooks: `EntityBase._enter_tree` registers with TeamRegistry +
  EntityRegistry (was in `_ready` after two awaited physics frames), `_exit_tree` unregisters both.
  Pooling groundwork: a mob removed with `remove_child` drops out of every list. `TedsPet` registers
  itself the same way (lands in `hero_side` only).
- Hot sites migrated: `teds_pet._find_target` (was a full-tree group walk every physics frame →
  `nearest(enemies)` at 4 Hz); `HeroBase._should_auto_use_ultimate` (`count_within(..., stop_at)`);
  `HeroExplorationController._check_for_monsters` (Hero×Monster every frame → registry at 4 Hz via
  new `monster_check_interval` export; its only listener `world._on_monster_detected` is a no-op);
  `_find_heroes` / `_find_fog_system`; `SpawnManager` dropped its 1 s hero cache for
  `EntityRegistry.hero_side`; EntityBase idle scoring + `VisionArea` use `singleton(&"FogOfWar")`.
- `TeamBlackboard.bump_threat` ignores non-members (Ted's pet leaked a `threat[pet]` row forever);
  `decay_threat` prunes freed attackers and values < 0.05 instead of keeping dead keys.
- F3 overlay: `Registry: H P M Mob` counts next to the TeamRegistry counts.
- Verified: headless import + load of 80 scripts / 60 resources — 0 errors; 0 group scans left in
  the six hot files.

### 2026-10-14 — perf: P2 targeted damage notify (`_on_damage_taken`)
- Every entity subscribed to the global `EventBus.damage_applied` only to check
  `packet.target != self` for the flinch → one hit = ~150 callbacks at 150 live mobs.
  `EventBus._route_packet` now calls `target._on_damage_taken(packet)` directly after
  `_receive_damage` (guarded: target must be a living `EntityBase` — Ted's pet is a valid AoE
  target but a plain CharacterBody2D; killing blows skip the flinch). `damage_applied` is reserved
  for true global listeners (TeamRegistry threat today; audio/analytics later). Pipeline comment in
  `event_bus.gd` updated; EntityBase no longer touches EventBus in `_ready` (pooling groundwork).
- Verified: headless load of all scripts/resources — 0 errors; `damage_applied.connect` →
  `team_registry.gd` only.

### 2026-10-14 — perf: P1 faction collision layers + orphan connections + lazy approach nav
- **Collision layers split per faction** (`project.godot` `[layer_names]`: world / body_hero /
  body_mob / body_monster / ability_zone; constants in `GameUtils.LAYER_*` / `MASK_*`). Every entity
  had TWO Area2Ds (DetectionArea r=172 + Body r=31) on layer 3 / mask 3, all monitoring AND
  monitorable → 300 mutually-pairing areas at 150 mobs, `area_entered` storms for mob-vs-mob, and AoE
  queries seeing each entity twice. Now: `Body` is the only monitorable area (faction layer, mask 0,
  monitoring off); `DetectionArea` is on no layer, masks enemy bodies only, not monitorable.
  Hero 2/12, Mob 4/10, Monster 8/6 set scene-side in the three base scenes.
- Consumers moved with it: Mine/MediKit/TrapCage → layer 16 (ability_zone), faction masks,
  monitorable off (Mine was on layer 2 = the new hero bit); MobSpawnArea → layer 0, mask body_mob;
  all 7 `intersect_shape` sites set an explicit `collision_mask` + `collide_with_bodies = false`
  (they used the all-layers default and `max_results = 32`); `ult_bomb` / `mine` / `grount_slam`
  now dedupe per entity; `trap_cage._get_entity` resolved the collider Area2D itself (it IS a Node2D)
  so the cage teleported collision shapes, not mobs — fixed to resolve the EntityBase root.
  Deleted `shockwave.gd` (`UltimateAreaDamage`): unreferenced, and with `collide_with_areas=false`
  + mask 1 it could only ever hit Ted's pet.
- **Balance change (user decision: adopt intended values, retune later):** aggro 172+172≈344 px →
  172+31≈203 px; AoE reach radius+172 → radius+31 and single hits (ult_bomb/mine/grount_slam lose
  the accidental double damage); Mine/MediKit/TrapCage trigger on Body overlap (−141 px);
  leash fires once per mob. Retune item added to Tech Debt.
- Orphan scene connections removed: Bat/Hog `state_physics_processing` → nonexistent
  `_on_fight_state_physics_processing` (the addon enabled `_physics_process` on Fight purely
  because a connection existed → one error print per fighting mob per physics frame) and
  `state_exited`; NPCBase `child_entered_tree → _on_to_fight_child_entered_tree`.
  `Movetimer` (autostart, no handler, ×150) deleted; VisionArea indices re-based.
- Approach state now uses `_set_nav_target_lazy` (was `target_position =` every frame → path
  recompute per approaching mob per frame); new `_set_nav_target()` forced sibling keeps the lazy
  cache in sync at the idle-goal sites (EntityBase/MobBase/Irelia); cache seeded with INF so the
  first call always paths; strafe moves directly (the ~1 px nav target it pushed was swallowed by
  the lazy helper) and is rate-independent. `GameManager.match_timer_changed` emitted at 4 Hz.
- Verified: headless 4.7.2 import + load of 79 scripts / 60 resources — 0 errors; greps: 0 orphan
  names, every `intersect_shape` file sets a mask, `target_position =` only in the two nav helpers.

### 2026-10-14 — fix: P0 correctness fixes + measurement baseline (performance pass, phase 0)
- Adversarially-verified plan (14 claims × 2 refuters + completeness critic) found correctness bugs
  that would skew any profiling; all fixed before measuring:
- `NPCBaseClass.tscn`: `ToDead` moved from `Fight` to the `CompoundState` level (addon offers an
  event to the active leaf first, then to the compound state's own transitions). Heroes and the
  monster could previously only die while in Fight — lethal damage in Idle/Approach (River's 300 px
  sniper vs an approaching monster) made them immortal and the match never ended. The mob-only
  Idle/Approach `ToDead` overrides in `mobs_base_class.tscn` are gone (inherited now).
- `mobs_base_class.gd`: `_on_attack_timer_timeout` always clears `attacking` (a target dying
  mid-swing left the flag stuck → mob never attacked again); `min_distance = minf(20, range*0.5)`.
  `Hog.tscn`: `base_attack_range` 10 → 40 (was below the melee floor → Hogs never attacked); root
  node renamed "Hug" → "Hog".
- `mob_spawn_area.gd`: respawn accounting rewritten. `deactivate()` detaches each mob's
  `tree_exiting` hook before `queue_free()` (the deferred free used to fire `_on_mob_died` after the
  `_deactivating` flag was already cleared → +1 virtual mob per deactivation). New `_epoch` counter;
  the respawn coroutine captures it before `await` and bails if the area was deactivated or
  re-randomized (Shift+R) meanwhile. Dead slots are now carried in `_pending_respawns` so
  `total_mob_count()` stays flat. New `reset_population()` used by `SpawnManager.randomize_spawns`.
- `npc_base_class.gd`: XP goes to `last_attacker` (fallback: current target) — AoE kills by the
  monster on hero-chasing mobs now feed evolution; `_get_threat_score` low-HP bonus was dead code
  (both numbers came from `get_health()`), now uses `get_max_health()`; detection shape radius only
  written when it changes. `NPCBaseClass.tscn` + VisionArea/Mine/MediKit/TrapCage shapes are
  `resource_local_to_scene` (every spawn used to rewrite ONE shared CircleShape2D → physics server
  re-sync for every live entity).
- Measurement: F3 overlay now shows FPS, process/physics ms, node count, Phys2D objects and
  collision pairs. `FpsCounter` moved from HeroContainer (hero side only) to MainCam's CanvasLayer.
  `SpawnManager.stress_mob_multiplier` export (×2 with lazy activation off + 39/39 active areas →
  232 mobs). `project.godot`: stretch `canvas_items`/`expand`, portrait orientation.
- World facts corrected vs. older notes: 39 MobSpawnAreas / 116 configured mobs (not 43/128);
  normal play tops out near ~90 live mobs, so the 150-mob target uses the stress config.
- Verified: Godot 4.7.2 (`/Applications/Godot.app`) headless import + load of all 80 scripts and
  60 scenes/resources on a scratchpad copy — 0 errors. (Earlier notes claimed a "Godot 6.app";
  that path does not exist.) In-game F3 baseline still to be captured.

### 2026-07-06 (iteration 4) — feat: Main Menu shows permanent character levels
- Closed the last slice of the Permanent XP System (In Progress → Done). The XP data has been
  written & persisted since `eeb2234`; now it is finally surfaced to the player.
- `Scripts/persisted_data.gd`: added the shared permanent-level curve. `XP_PER_LEVEL_STEP = 100`;
  level L→L+1 costs `100*L` (cumulative 100/300/600/1000…). New `level_from_xp(total)` and
  `level_progress(total) -> {level, into, needed}` — pure helpers, no side effects, used by both
  heroes and the monster.
- `Scripts/game_manager.gd`: promoted the monster's default id to a public const
  `DEFAULT_MONSTER_ID = &"grount"` (was a bare `&"grount"` literal on `_monster_id`) so the menu and
  the reward code share one source of truth for the monster XP key.
- `Scenes/UI/MainMenu/main_menu.gd`: builds a compact "PROGRESSION" strip in code on each side card
  (inserted above the Filler spacer, matching the existing "awkward-in-scene bits live in the script"
  pattern). Heroes card lists all four `KNOWN_HERO_IDS` as `Name … Lv N` rows; monster card shows
  `Grount … Lv N` plus a thin progress bar toward the next level. Labels are cached and updated in
  place by new `_on_hero_xp_changed` / `_on_monster_xp_changed` handlers wired to the PersistedData
  signals — no rebuild, so a match that awards XP is reflected the moment the player returns to menu.
- Verified: headless editor compile (Godot at `/Applications/Godot 6.app`) — 0 script errors,
  0 GDScript warnings on the three changed files.
- Optional future polish (not blocking): a `+XP` row on the MatchResult screen (result already
  carries `result.xp`); left out to keep this iteration to a single scene surface.

### 2026-07-06 (iteration 3) — feat: award permanent hero/monster XP on match end (`eeb2234`)
- Delivered the persistence slice of the Permanent XP System backlog item (the XP-bar UI is split off
  into In Progress). Prior loops had the PersistedData XP slots but nothing wrote to them.
- `Scripts/match_rewards.gd`: `Result` gains an `xp: int` field; `compute()` derives a per-match XP
  chunk — `(25 win / 10 loss) + mob_kills*2 + minutes*3`, plus `heroes_alive*5` (hero side) or
  `monster_stage*10` (monster side). Pure logic, no side effects (mirrors the currency formula).
- `Scripts/game_manager.gd`: captures participating characters at `_initial_census` —
  `_participating_hero_ids` (new `_hero_id_from()` maps node name → id via substring, same convention
  as world.gd's vision_map) and `_monster_id` (monster node name). Captured at census so XP survives
  the nodes being freed at match end. `_apply_rewards_to_save` now awards `result.xp` to each hero id
  (hero side) or the monster id (monster side) via PersistedData, alongside the existing currency.
- `Scripts/persisted_data.gd`: added `monster_xp_changed` signal + emit in `add_monster_xp`, symmetric
  with the existing `hero_xp_changed` — completes the data layer for the future XP-bar UI.
- Verified: full headless editor compile (Godot 4.4, found at `/Applications/Godot 6.app`) — rc=0,
  0 script errors, 0 GDScript warnings. (Earlier "clean" runs were false — the machine has no
  `timeout` binary, so the wrapped command silently no-op'd; re-ran unwrapped to confirm.)
- Next run: the XP-bar UI slice (In Progress) — surface levels on the Main Menu side cards or a
  character screen using the `*_xp_changed` signals; optionally add a `+XP` row to MatchResult.

### 2026-06-09 (iteration 2) — fix: null-target dereference in Approach/Fight state processing
- `Scenes/NPCs/npc_base_class.gd`: `_reevaluate_current_target()` can clear `target`/`target_entity`
  and queue `ENEMY_EXITED` when no valid target remains, but the state transition is deferred to the
  next frame — so `_on_approach_state_processing` / `_on_fight_state_processing` continued and
  dereferenced the now-null `target` (`Invalid access to 'global_position' on Nil`). Added an
  `if not is_target_valid(): return` bail immediately after each re-eval call. The detection-area-exited
  re-eval site (line ~601) was already safe (returns without touching target).
- `project.godot`: editor bumped `config/features` 4.4 → 4.5 (matches documented engine target).
- Surfaced more often post the earlier state-event typo fix, since combat now transitions reliably and
  targets are re-evaluated mid-chase more frequently.
- Verified: guards confirmed at all three re-eval call sites; Godot CLI not installed locally so
  parse-checked manually.

### 2026-06-09 — feat: Monster Base meta-skill tree now affects gameplay
- `Scenes/NPCs/Monster/monster_base_class.gd`: added 6 cached meta multipliers
  (`_meta_health/damage/speed/xp/evo_threshold/range_mult`), loaded once in `_ready` via new
  `_load_meta_modifiers()` (reads `MetaSkillManager.collect_monster_modifiers()`) BEFORE stage config.
  Applied at read points: stage health + damage_multiplier, `get_health` (bar max), `_get_move_speed`,
  `_get_attack_range`, `gain_xp`, `_get_next_evolution_threshold`.
- Effect: purchased Monster Base upgrades (Thicker Hide, Faster Hunt, Bloodhound, Quick Evolution,
  Brutal Strikes, Apex Body, Long Reach) now actually modify the monster instead of being inert.
  Un-upgraded monster is unchanged (all multipliers default to 1.0).
- Verified: no warnings-as-errors risks; modifier keys match the manager's output; Godot CLI not
  installed locally so parse-checked manually.
- Next run: award permanent hero/monster XP on match end (Permanent XP System backlog item) — wire
  `GameManager._apply_rewards_to_save` to also call `PersistedData.add_hero_xp` / `add_monster_xp`.
