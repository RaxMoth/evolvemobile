# Progress Tracker

Last loop run: 2026-06-09 (iteration 2)
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

## In Progress

- (none)

## Backlog (from spec, not started)

- [ ] Permanent XP System — PersistedData has hero/monster XP slots, but matches don't award permanent XP
      on end, and there's no XP bar UI. (README v0.2 high priority)
- [ ] Per-hero skill trees (Steel) + per-monster trees (Leaves) — only the universal Base trees exist
- [ ] Pre-Round Setup screen — strategy sliders (aggression/farming/exploration), formation select
- [ ] Settings menu — master/music/sfx volume, vibration, language; load/save via PersistedData settings
- [ ] Audio — music track + core SFX (hit, death, cast, ult, evolve) + audio buses
- [ ] Hero composition selection — pick 4 of N heroes per match
- [ ] Minimap with fog overlay
- [ ] Tutorial / first-time-user flow

## Proposed (NOT approved — do not implement)

- (none)

## Tech Debt / Improvements

- [ ] Debug `print()` statements still in hot/spawn paths — `world.gd` (15), `monster_base_class.gd` (8),
      `skill_tree_component.gd` (6), `spawns.gd` (2), ability files. Gate behind a debug flag or remove.
- [ ] `MonsterBase.get_health()` returns *max* health for the stage, not current — confusing semantics
      inherited by EntityBase HUD setup. Consider renaming to `get_max_health()` and adding a true
      `get_health()` returning `current_health`.
- [ ] Movement still runs through state-chart `_state_processing` (`_process`-based) rather than
      `_physics_process`; acceptable for now but revisit if physics interactions are added.
- [ ] 27 `get_nodes_in_group` / `get_first_node_in_group` call sites — most are one-time but a few are in
      periodic loops; an EntityRegistry autoload (cached faction lists) was proposed earlier.
- [ ] Legacy in-round `Scripts/Skilltree/` (SkillNode/SkillTree/SkillTreeComponent) is unused by the
      shipped MetaSkill system — confirm dead and remove, or wire it to in-round leveling.

## Changelog

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
