# Progress Tracker

Last loop run: 2026-11-11 (Jungle Guild overhaul done: 40 batches, `6985f6e`..8.5, on top of the code cleanup; local only, not pushed)
Stack: godot

Spec source: `README.md` (the design spec; `test/test_readme_spec.gd` checks its tables against the
data) + `Docs/INSTRUCTOR.md` (architecture guide). README "Current Status & Roadmap" is the short
summary of this file.

**Before the hourly loop works on this tree**: the overhaul is 47 local commits after `885e86a`
(origin/main); push them first. On the loop's runner re-record the trace baselines before comparing
anything (see "Verification gate").

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
- [x] Side selection — GameManager.chosen_side plumbed to camera + hero UI + vision + rewards
- [x] In-world HP bars pinned to fixed pixel size (+ monster counter-scale through evolution)
- [x] Code→scene cleanup — groups/signals/exports/process_mode moved scene-side
- [x] Crash fix: null-target deref in Approach/Fight processing (validity-bail guards)
- [x] v0.1 menus (Main Menu, MetaSkillScreen, MatchResult, HeroContainer panel) — replaced by the
      overhaul's screens (Phases 3, 4, 5, 8) and deleted in 8.3
- [x] Monster Base skill tree consumed by MonsterBase — `fdb36c6`
- [x] Permanent XP awarded, persisted and shown per character — `eeb2234`
- [x] Performance pass P0→P5 (faction layers, EntityRegistry, TickScheduler LOD, HpBar2D, mob pool) —
      Changelog 2026-10-14; the device measurement moved to Backlog (user step)
- [x] Headless test harness, save migration, touch-input audit, `print()` gating, tutorial, minimap,
      localization scaffold, analytics sink, audio manager (placeholder tones) — Changelog 2026-10-18/19
- [x] Code cleanup (54 batches), wall/corner fixes, Godot 4.7 — `2f8207d`..`141924e`, `6730670`
- [x] **Jungle Guild overhaul, Phase 1: visual and UI foundation** — one palette (`UiPalette`, 100
      tokens), the Python art pipeline, the SVG kit (64) and icons (81), the generated theme with
      Lilita One, real ability icons, VfxManager core — `6985f6e` `b7ea686` `df3494e` `a41cb6e` `0435084`
- [x] **Phase 2: SVG character rigs and the ground style** — rig runtime and builder, ten characters,
      heroes / fox / Grount (3 stages) / Bat / Hog migrated, muted ground grade, contact shadows —
      `0dca17a` `2393cd7` `fdb24f5` `cea2768` `7599f34`
- [x] **Phase 3: lobby, rosters, nav** — Roster / CharacterDef / MonsterSlot, the menu component kit,
      MenuRoot + LobbyScreen (main scene), RosterScreen + CharacterDetail — `8d8e2aa` `85f082b`
      `e102059` `9a666c7`
- [x] **Phase 4: match HUD** — CooldownSource + AbilitySlot, MatchHud (hero cards, monster panel,
      framed minimap), event toasts and HUD juice — `cf09154` `accce01` `a388bdd`
- [x] **Phase 5: ranked skill trees** — ranked node model, capstones, gates, save v3; tree content v2
      as resources (nine trees); generic stat keys; the twelve hero capstones; the tree screen and
      upgrade flow; Earning Rates v2 — `7a866a0` `ec862d9` `8bdf570` `f41f622` `09a55d1` `e4e6913`
      `7f62756` `6a91e33` `07ae717` `0661a6b`
- [x] **Phase 6: multiple monsters** — shared monster framework, per-monster sim / trace / bench
      tooling, Grount retune, Nyxa, Gorrak, the eight monster capstones, opponent choice and monster
      unlocks, the side rule and Opponent Threat — `951175c` `16aed14` `f6b6454` `84b0760` `15fc5dc`
      `6c0541e` `bc5da84` `c633c2c` `51884c3` `3cff7cf`
- [x] **Phase 7: ability animations** — authored rig moves per body plan, hero and monster ability
      effects as recipes, telegraphs, mob swings under the rig budget — `e1738da` `9e70025` `22160b7`
      `e656c1d`
- [x] **Phase 8: polish** — PreRoundScreen, MatchResultScreen, the old UI and the pixel sprite path
      retired, Settings / Tutorial / Codex restyle and the first-run flow, this README / PROGRESS /
      INSTRUCTOR pass — `fdd3597` `53b039b` `4204a8c` `d5798bd`, `eca1e3e` (three header rewrites
      the 4.7 editor made, committed as they were) and the 8.5 docs commit

## In Progress

- (none)

## Backlog (in order; "user step" = needs the user, the editor or a device, not for the loop)

- [ ] **Push and review** (user step): `git log origin/main..main` is the whole overhaul; a
      whole-overhaul review (`885e86a..HEAD`) before the push was planned.
- [ ] **Decisions for the user** and **Placeholder copy** below (user step): each entry names the
      default that ships.
- [ ] **Bug: Gorrak counts his own warband** — `MonsterBase._pick_camp` (a camp's `spawned_mobs`)
      and `_count_slam_targets` (`EntityRegistry.mobs`) count mobs with `ally_monster == self`; with
      Call of the Herd he can walk to a camp he cannot farm for up to 20 s. Gameplay fix: re-record
      `tools/baselines` only if a default (no capstone) trace changes; it should not.
- [ ] **Parity table at 48 seeds** — `MONSTER=all THREAT=all tools/sim.sh 48 heroes 8` and
      `... 48 monster 8`; at 24 seeds 9 of 30 cells are outside 35-65 % (Gorrak T3/T4 62-75 % both
      sides, Nyxa T2/T3 heroes side 67 / 71 %, Grount T2/T3 monster side 33 / 33 %).
- [ ] **Gorrak at threat 3-4** — his tree has no big tier-3 stat node; needs tree content or a
      retuned `ai_build_order` (only the axe damage moved the result in 6.8).
- [ ] **AI build size** (decision first): 3T character + 2T base entries keep the AI behind a player
      at the threshold (a P = 6T save wins 71-100 % as heroes at T4). Candidate: 3T + 3T.
- [ ] **Monster instincts** — PreRoundScreen's Lurker / Ambusher / Ravager tiles are built and hidden
      (`show_instincts = false`); balance three `MonsterStrategy` presets per monster (sim), then show.
- [ ] **Pre-round scroll** — the heroes-side pre-round is about 1,500 px tall; on a 720x1280 phone
      STRATEGY / FORMATION need a scroll (START HUNT is pinned).
- [ ] **Content localization** — skill node names, effect texts, tree titles, branch names, Codex
      field notes, taglines, tips, ability descriptions and monster stage names are English-only data
      (only UI strings, ability names and gate strings are in `Assets/Locale/strings.csv`).
- [ ] **uids on generated resources** — character bodies / motions / defs, Vfx recipes,
      `Data/SkillTrees`, `roster.tres`, Nyxa's and Gorrak's ability and stats files,
      `world_navigation.tres` and the `tools/preview` scenes have no `uid` in their header (the
      user's editor may add them on first save: commit what it writes). Hand-written scenes have
      uids and a test enforces it for `Scenes/**/*.tscn`.
- [ ] **Rigs-awake p99 on an idle machine** — `tools/bench.sh 3 2 1800 600 0 1` (7.4 measured 4.4 ms
      against the parent's 3.4-4.7 ms range under load 4-9).
- [ ] Device build (user step): Project → Export → Android + iOS presets (exclude `tools/*`), the
      stress config on a Pixel 5a-class phone with F3 (`SpawnManager` min/max_active_spawns = 39,
      enable_lazy_activation = false, stress_mob_multiplier = 2), Compatibility vs Mobile renderer
      (`config/features` still says "GL Compatibility" while `rendering_method="mobile"`), physics
      30 Hz, F3 at pinch zoom 0.5. `treat_warnings_as_errors` stays off until an editor pass shows 0
      warnings.
- [ ] Real audio assets (user step): `Assets/Audio/<key>.ogg|wav`; the manager plays generated tones
      until then.
- [ ] Balance retune after the P1 layer split (aggro 344→~203 px, AoE reach) — needs a playtest.
- [ ] "Second Wind" (needs the evolution-heal decision), trap / barrage slows, a second ultimate.
- [ ] Hero composition selection — a roster of more than four heroes, World spawns the chosen four.
- [ ] Heroes: threat assessment (flee from a Stage 3 monster).
- [ ] Elite camps (designed: 180 HP, 50 XP; not built), more mob types.
- [ ] Cloud save (`SaveBackend`); a remote analytics provider (`AnalyticsSink.set_provider`).

## Decisions for the user (the default that ships; change or confirm)

Gameplay:
- **AI opponent build**: 3T character + 2T base entries, so a player at the threshold owns more
  ranks than the AI. Options: 3T base entries, a higher `MAX_THREAT`, or keep it.
- **`THREAT=N` in `tools/sim.sh`** gives both sides their threat-N AI build (the "parity check");
  `SAVE=` runs the real rule on a save.
- **Call of the Herd** recruits only on a Warcry Stomp aimed at a hero or Ted's pet (otherwise
  Gorrak recruited the Hogs he must eat and stalled at Stage 2: 17 of 24 sanity matches timed out).
- **Unstoppable** is immunity to crowd control (taunt, Trap Cage), not to damage: Spiked Cage's
  spikes still hurt him.
- **Vampiric Rebirth** re-forms by a jump to the scatter point when heroes are still within 400 px.
- **Evolution heals to full** (`heal_to_full_on_evolution`); the first design said "new max − old
  max". It also gates Grount's "Second Wind".
- **Knockback** does not exist (`knockback_force` on Ram Dash is unused).
- **Nyxa's timeouts** (17-18 of 48 matches) are accepted as her trait.
- **Monster instincts** are hidden; every monster plays its Ambusher (default) strategy.
- **River's supply crate** fades in mid-air when every hero within its 60 px pickup radius was
  already healed during its 0.5 s fall; a **Land Mine** placed on an enemy inside its 100 px radius
  detonates at once (no arming delay). Intended or not?
- **Match rewards pay the played side's kills** (8.2), and the HUD's kills chip shows them.

Look and feel:
- **Hit effects land on the damage frame**; the attack move reaches contact about 0.1-0.16 s
  later. A contact marker could delay the hit sprite to match the lunge. The prototype's
  per-ability wind-up poses and hit-feedback delay were not ported.
- **No in-world look** for Vlad's Bloodlust, River's Adaptive Movement and Ted's Loyal Companion;
  Executioner's Mark and Deadeye crits show only the big gold number.
- **Enemy HP bars are red** (palette `danger`), heroes and the fox stay green; the **minimap** uses
  side colours (amber hero dots, a crimson monster dot, moss explored ground over warm near-black
  fog); the in-world white level number became the **HUD level pill**.
- **Quarry Change picker**: locked cards only shake (they unlock by hunt count, not for sale).
- **19.5:9 phones**: a band of about 280 px of plain background sits between the MONSTERS row and
  the lair in the lobby.
- **Fallen hero on the result screen**: tint 0.62 / 0.58 / 0.58 plus a colour drain instead of the
  UX spec's 0.42 / 0.39 / 0.39.
- **Heroes-side pre-round** needs a scroll on 720x1280 (Backlog).
- **Font**: Lilita One (approved, SIL OFL 1.1) is the display font. It has one weight and Latin
  glyphs only (German umlauts and ß included); anything else falls back to the body font (Godot's
  Open Sans SemiBold). A language beyond Latin needs a display font with wider coverage first.

## Placeholder copy for the user's review

- Grount's stage names (Bullcalf, Rampager, Alpha Bull) and his tip; Nyxa's (Duskling, Night
  Hunter, Dusk Matriarch) and Gorrak's (Tusker, Warlord, Boar King). None is in `strings.csv`.
- The redrawn Nyxa and Gorrak ability icons.
- Accent colours: Nyxa uses palette `monster2` (#8D55C2), not the spec's #7B3F95; Gorrak uses
  `monster3` (bog green), not the spec's crimson.
- The Monsters roster's "swarm" role filter has nobody: Grount and Gorrak are "brute", Nyxa is
  "stalker".
- Codex field notes, taglines, tips and ability descriptions (English only).
- `Assets/Icon.jpg` is the app icon (`config/icon`) and stays; `test_legacy_retired` allows exactly
  two raster images (the ground tileset and this icon).

## Proposed (NOT approved — do not implement)

- (none)

## Verification gate

Every change passes `tools/lint.sh` (errors=0) and `tools/run_tests.sh` (exit 0; 589 tests, the
run exits with nothing leaked). A change that must not alter gameplay also keeps the determinism
trace byte-identical: `BASELINE=<parent trace> tools/sim_trace.sh > <new trace>` (exit 0): seeds 1-3
× heroes/monster as full matches (~40 s). Every 60 frames the trace hashes each EntityRegistry
entity's class, position (1 px), health and active state, the monster's stage and XP and the mob
kill count — never node names. The temp copies turn off the navigation server's asynchronous
map/region iterations (override.cfg only), which makes runs repeat from the first line under any
load. A gameplay change says why the trace changed and reports
`MONSTER=all tools/sim.sh 48 heroes 6` and `... 48 monster 6` (target 40-60 % hero wins per
monster).

- **Committed baselines** (`tools/baselines/trace_<id>.txt`, one per roster monster) were recorded
  with **Godot 4.7.2 on the development Mac**. The hashes depend on the engine build and the CPU.
  **The hourly cloud loop must re-record on its own runner before it compares**
  (`MONSTER=all RECORD_DIR=<dir> tools/sim_trace.sh` on the untouched tree, then
  `BASELINE_DIR=<dir>` after its change) and must not commit baselines recorded elsewhere over
  the committed ones unless it changed gameplay on purpose.
- `tools/bench.sh 2 2 900 300` (or `5 2 ...` for a gate) before and after, back to back, when
  visuals touch the match runtime; more than 15 % in frame mean or p99 is fixed or explained.
- A headless MenuRoot run still reports 3 leaked RefCounted at exit: Godot's own threaded-load
  tokens, not ours.

## Balance (measured, headless sim)

Threat 0, fresh save, 48 seeds (`MONSTER=<id> tools/sim.sh 48 <side> 6`), hero wins:

| Monster | Heroes side | Monster side | Timeouts (H / M) | Median Stage 3 | Notes |
|---|---|---|---|---|---|
| Grount before 6.3 (`16aed14`) | 19 % | 25 % | 4 / 4 | 324 / 325 s | |
| **Grount** (6.3, `f6b6454`) | **46 %** | **48 %** | 4 / 3 | 322 / 323 s | Trap Cage fix alone: 33 %; plus Stage 3 damage × 0.9 |
| **Nyxa** (6.4, `84b0760`) | **54 %** | **52 %** | 18 / 17 | 371 / 371 s | wins mostly by timeout: accepted |
| **Gorrak** (6.5, `15fc5dc`) | **42 %** | **52 %** | 5 / 5 | 346 / 347 s | Stage 3 HP 1500 instead of the design's 1600 (38 % / 50 %) |

This closes "Balance retune after `74e2bff`" (heroes 29 % then).

Opponent Threat parity (6.8, `MONSTER=all THREAT=all tools/sim.sh 24 <side> 8`, hero wins, heroes
side / monster side):

| threat | Grount | Nyxa | Gorrak |
|---|---|---|---|
| 0 | 50 % / 54 % | 58 % / 62 % | 38 % / 46 % |
| 1 | 46 % / 50 % | 46 % / 54 % | 62 % / 42 % |
| 2 | 42 % / 33 % | 67 % / 62 % | 58 % / 67 % |
| 3 | 46 % / 33 % | 71 % / 67 % | 62 % / 71 % |
| 4 | 58 % / 50 % | 42 % / 50 % | 71 % / 75 % |

- 21 of 30 cells are inside 35-65 % (24 seeds: one standard error is about 10 points). Gorrak at
  threat 3-4 is the weak spot.
- Threshold finding: a player at P = 6T (a real save with the first 12 `ai_build_order` entries of
  the base tree and of each played tree, threat 4) beats the AI at T4: heroes side 100 % (Grount),
  71 % (Nyxa), 88 % (Gorrak); monster side 12 %, 12 %, 38 % hero wins.
- Fully ranked hero saves (power ranks 39-42) beat a threat-4 Grount 79 % without capstones and
  92-100 % with them.
- Capstone sanity (6.6: a fully ranked monster with one capstone against fresh heroes, 24 seeds):
  Grount Titan Form 0 % hero wins, Rampage 29 %, Trample 33 %; Nyxa and Gorrak 0 % with every
  capstone.
- Income (8.2, 72 sim matches per side, threat 0): median about 715 Steel per hero match and 915
  Leaves per monster match (target 800 / 1,000); before, with every mob death counted, 1,440 / 1,470.

## Performance (measured, headless `tools/bench.sh`, 232 mobs, stress config)

The machine was loaded (load 4-9) for all of these; compare only pairs run back to back.

| What | Rigs asleep (frame mean) | All 232 rigs awake |
|---|---|---|
| Phase 1 baseline `885e86a` | 1.505 ms | n/a (pixel sprites) |
| 7.3 `9e70025` → `22160b7` | 1.609 → 1.543 ms (p99 4.12 → 3.31) | 2.175 → 2.034 ms (p99 5.04 → 3.60) |
| 7.4 `e656c1d` | 1.535 / 1.526 ms | 1.946 / 2.020 / 2.026 ms |
| 8.4 `4204a8c` → `d5798bd` | 1.931 → 1.752 ms (p99 5.25 → 4.74) | |

- Total overhead of the overhaul against `885e86a`: about +0.03 ms with the rigs asleep and about
  +0.5 ms with all 232 awake (the limit was +0.6 ms).
- Open: the same on a device, and the rigs-awake p99 on an idle machine (Backlog).

## Tech Debt / Improvements

- [x] Debug `print()` statements — all game code goes through `Globals.debug_log`.
- [x] `MonsterBase.get_health()` returned *max* health — fixed in P0.
- [x] Sim seed 24 (v13B): the stage-1 monster died to mobs — fixed in `81fa426` and `74e2bff`.
- [x] Balance retune after `74e2bff` (heroes 29 %) — closed by 6.3: 46 % (heroes side) / 48 %
      (monster side) at 48 seeds, timeouts 4 / 3, median Stage 3 at 322 / 323 s, versus 19 % / 25 %
      before; the Trap Cage fix alone gave 33 % (see Balance).
- [x] Movement no longer runs on the state chart's per-frame `state_processing` (P4).
- [x] Hot `get_nodes_in_group` sites → `EntityRegistry` (P3). A few cold one-shot / per-cast sites
      remain (world.gd, main_cam.gd, game_manager.gd, Irelia / River casts) — fine as is.
- [x] Legacy in-round `Scripts/Skilltree/` removed.
- [x] Exit leaks: the test run ends with nothing leaked (8.4; 8.3 left 140 objects, 66 resources
      and a test Bat's RIDs).
- [x] The old UI (MainMenu, PreRoundSetup, MetaSkills, MatchResult, HeroContainer) and the pixel
      `AnimatedSprite2D` path are deleted (8.3); `test_menu_root` and `test_legacy_retired` keep
      them gone.
- [ ] Balance retune after the P1 layer split — playtest `detection_radius` + AoE radii (Backlog).
- [ ] Headless runs never put a mob on screen: nothing is drawn, so VisibleOnScreenNotifier2D never
      fires. In `tools/sim.sh` and a plain `tools/bench.sh` every mob ticks at 20/10/3 Hz
      (NEAR/MID/FAR) and only the heroes and the monster tick every frame; on a device every mob
      inside the camera rect ticks at 60 Hz (mob reaction 50–333 ms vs 16 ms). `tools/bench.sh`
      takes `onscreen=1` (marks the mobs inside the MainCam rect) and `rigs_awake=1` (animates
      every rig). Open: F3 numbers on a device, also at pinch zoom 0.5.
- [ ] Generated resources have no `uid` header (Backlog).
- [ ] `MonsterBase._pick_camp` / `_count_slam_targets` count warband mobs (Backlog, bug).
- [ ] Content strings are English-only data (Backlog).
- [ ] A headless MenuRoot run reports 3 leaked RefCounted (Godot's threaded-load tokens).
- [ ] `tools/sim_match.gd` counts a mob kill for the heroes when the killer is any `Node2D` that
      is not a monster (`_is(killer, "Node2D")`). Checked in 8.5: `is_class` matches inherited
      classes, so Ted's fox (a CharacterBody2D) counts; an earlier note said it did not. The game
      uses `GameManager.killer_side`; the sim could use the same rule. Low priority.

## Changelog
### 2026-11-11 — the "Jungle Guild" overhaul: 40 batches in 8 phases (`6985f6e`..8.5)
Run as a workflow from the plan in the session scratchpad (design deliverables backed up in
`../evolvemobile-design-backup`): one batch per commit (5.4 and 6.6 as one commit per character),
each behind lint, the suite and the determinism trace (presentational batches: byte-identical;
gameplay batches: the reason, new baselines and `tools/sim.sh` numbers), plus a muted render that was
looked at. The suite grew from 167 to 589 tests. Nothing was pushed.

- **Phase 1 — visual and UI foundation** (`6985f6e`, `b7ea686`, `df3494e`, `a41cb6e`, `0435084`;
  no gameplay change). `tools/art/palette.py` is the one source of every colour (100 tokens) →
  `UiPalette` + `palette.tres`; `build.py` writes the SVG kit (64 with 8.2's three ribbons), 81
  icons and the crests as DPITextures; `make_theme.py` writes the one project Theme with Lilita One
  (SIL OFL 1.1, licence in `Assets/Fonts`); a lint rule forbids colour literals under `Scenes/UI`;
  every ability resource got its icon; `VfxManager` (pooled sprites, damage numbers, hit flash,
  camera trauma, telegraphs) with a per-frame hit budget. Bench: frame mean 1.359 → 1.364 ms.
- **Phase 2 — SVG rigs and the ground style** (`0dca17a`, `2393cd7`, `fdb24f5`, `cea2768`,
  `7599f34`; no gameplay change). `CharacterRig` / `RigBody` / `RigProfile` and `tools/build_rigs.sh`
  (SVG parts + `rig_src.json` → one sheet and a body scene per character); ten characters; the four
  heroes, the fox, Grount with his three stages' parts, Bat and Hog draw their rigs; off-screen rigs
  sleep and a budget caps the awake ones; the pixel tiles got a muted, darker grade
  (`ground_grade`), every rig an ink contact shadow. Bench with all 232 rigs awake: mean 1.460 →
  1.772 ms (+0.31, budget +0.4).
- **Phase 3 — lobby, rosters, nav** (`8d8e2aa`, `85f082b`, `e102059`, `9a666c7`; no gameplay
  change). `roster.tres` + a `CharacterDef` per character (the one registry for menus, match, tools
  and save), `MonsterSlot` spawns the selected monster at Grount's old point of the enter pass;
  CharacterCard, RigView, TopBar, CurrencyChip, NavBar; `MenuRoot.tscn` is the main scene with the
  lobby's campfire and lair (tap a side); the 4-column rosters and the character page.
- **Phase 4 — match HUD** (`cf09154`, `accce01`, `a388bdd`; no gameplay change). `CooldownSource`
  (read-only view of an entity's slots) and `AbilitySlot` (radial sweep, countdown, ready glow,
  stage lock); `MatchHud` replaced HeroContainer and holds the minimap; event toasts (evolved,
  fallen, ultimates) and the level-up pop.
- **Phase 5 — ranked skill trees** (`7a866a0`, `ec862d9`, `8bdf570`, `f41f622`, `09a55d1`,
  `e4e6913`, `7f62756`, `6a91e33`, `07ae717`, `0661a6b`). Ranks, capstones (one equipped per tree),
  level / points gates and save v3 with a migration that loses no purchase; nine trees as
  `Data/SkillTrees/*.tres` (3 branches × 4 tiers; all 71 v1 ids kept with their v1 effect as rank
  1); new generic stat keys (damage taken, cooldowns, start level, regen, ...); the twelve hero
  capstones and Ted's Beastmaster nodes; `SAVE=` for the sim; the tree screen with the upgrade flow;
  Earning Rates v2 (150 / 75 + 15 per kill ...).
  - For existing saves: the retargeted nodes `t2_trapcd`, `t3_trapdur` (Trap Cage was named
    "TED ULt"), `i2_rallycd` and `i3_dashcd` (now Irelia's Divine Shield and Monster Taunt
    cooldowns) start working; purchases made after the update use the v2 prices and gates.
  - Known limitation: node names, effect texts and tree titles are English only.
  - Balance check then (24 seeds, against a fresh Grount, before 6.2/6.3): fresh heroes 33 %; one
    capstone branch 42-71 %; all four hero trees fully ranked 92 %.
- **Phase 6 — multiple monsters** (`951175c`, `16aed14`, `f6b6454`, `84b0760`, `15fc5dc`, `6c0541e`,
  `bc5da84`, `c633c2c`, `51884c3`, `3cff7cf`). `MonsterStats` reach / armour, `AbilityBase.deal`
  with lifesteal, `tick_active`, `get_cast_center`: a new monster is a scene plus data;
  `MONSTER=<id>|all` for sim / trace / bench, per-monster baselines in `tools/baselines`, and a
  reproducible sim (async navigation off on the copies: 24 seeds of identical code had given 17 %
  and 33 %). Grount retuned (Trap Cage traps what it lands on; Stage 3 damage × 0.9); Nyxa
  (lifesteal skirmisher, Night Swarm) and Gorrak (armour, returning Tusk Axe, stunning Warcry
  Stomp); eight monster capstones incl. the chart's Scattered state for Vampiric Rebirth; tonight's
  quarry, the Change picker and the Leaves unlocks; the side rule, Opponent Threat
  `T = min(4, floor(P / 6))`, AI builds and the +10 % reward bonus per threat. Numbers: "Balance".
- **Phase 7 — ability animations** (`e1738da`, `9e70025`, `22160b7`, `e656c1d`; no gameplay
  change). Authored attack / cast / ultimate moves per body plan and `AbilityBase.move_name`; an
  `AbilityFxRecipe` per ability (27 recipes, colours by palette token) drawn by `AbilityVfx` from
  pooled sprites, ground telegraphs for the monsters' area attacks; mob and fox swings follow the
  rig budget (`CharacterRig.plays_moves()`). Numbers: "Performance".
- **Phase 8 — polish** (`fdd3597`, `53b039b`, `4204a8c`, `d5798bd`, 8.5; no gameplay change).
  PreRoundScreen (quarry or monster, dials, formation, forecast, threat) and MatchResultScreen
  (ribbon, cast, count-up rewards, XP bars, upgrades ready) keep the old contracts; rewards now pay
  the played side's kills (median 715 Steel / 915 Leaves at threat 0 instead of 1,440 / 1,470) and
  the HUD kills chip shows them; 8.3 deleted the old screens and the pixel sprite path (281 files,
  5,927 lines out); Settings as a bottom sheet, coach-mark tutorial (camp tour, HUD tips), Codex,
  pause menu and back button; the test run exits with nothing leaked. 8.5: README reconciled with
  the data (hero kits, mob camps, map XP, fog, evolution maths, roadmap), the Nyxa / Gorrak tree
  tables, `test/test_readme_spec.gd`, `Docs/INSTRUCTOR.md` rewritten for the current code,
  `Docs/README.md` (a v0.1 copy of the spec) replaced by a pointer, this file.

### 2026-11-09 — code cleanup (54 batches), walls/corner fixes, Godot 4.7, unneeded scenes removed
- **Cleanup**: a 6-area audit (111 verified findings) became 59 batches; 54 landed one commit each
  (`2f8207d`..`141924e`), every one behind lint + 167 tests + the determinism trace (above); 5 skipped
  (17 already done; 46/48/55/59 superseded by the UI overhaul or held back). Highlights: dead code and
  warnings out, shared helpers (GameUtils.entities_in_circle, RingPulse, BasicStrike, flash_line), one
  cached faction per entity drives targeting, typed damage/threat/heal/cooldown paths, scene-side wiring,
  frame-rate-independent camera, pause-safe Ram Dash/Slam, atomic saves, background World load, pre-warmed
  mob pool, audio culling; tools: sim_trace.sh, bench LOD counts + on-screen mode, fixed-fps tests,
  per-run user:// dirs (concurrent runs no longer clobber saves).
- **Walls / corners** (`6730670`): fight strafing, River's heal approach, the mob leash and the Trap Cage
  push stop at the navigation mesh; exploration picks only reachable waypoints, a 24 px jitter-tolerant
  stuck check, detours formation keeps, formation slots pulled out of walls, 44 sealed one-tile islands
  dropped from the bake. Stall probe (24 matches): stuck time 2,971 s → 64 s, stalls ≥ 10 s 189 → 0.
- **Godot 4.7** (`6e9f747`, `004919b`): the editor migration, tracked .uid files, .DS_Store ignored;
  `main.tscn` wrapper and the DEBUGWORLD test world removed, MainMenu.tscn is the main scene (`0d0524f`).
- **Performance** (tools/bench.sh 3 2 900 300, 232 mobs, headless): frame mean 30.6 → 1.43 ms, p99
  185 → 3.2 ms, worst frame 675 → 3.5 ms, CPU 33.5 → 3.1 s (start vs now; the nav bake is most of it).
- **Balance** (24 seeds): heroes 25% (5–10/24 range since the stuck/farming fixes) → Grount retune is
  part of the feature overhaul (phase 6).

### 2026-11-03 — perf(nav): one baked navigation region; monster AI fixes; Grount behaviour nodes
Commits `81fa426` resting monster fights back · `ed7bf1a` + `b8dc8ba` Grount behaviour nodes (workflow:
design, critique, implement, 3-lens review, 5 confirmed findings fixed) · `3d4060a` `tools/bench.sh` ·
`6485eab` baked navigation · `74e2bff` stage-1 monster flees attacking Hogs.
- **Navigation**: Ground's per-tile navigation (~38,000 regions) made each path query cost ~4.4 ms and
  each closest-point query ~1.5–1.9 ms (measured with an instrumented copy: `is_navigation_finished()`
  runs the query). Baked into `Scenes/World/world_navigation.tres` (2,100 polygons, `tools/bake_nav.sh`,
  staleness test). `tools/bench.sh 2 2 900 300` (232 mobs): frame mean 30.6 → 2.1 ms, p99 185 → 5.4 ms,
  max 675 → 7.1 ms, CPU 33.5 → 4.4 s. A 24-seed sim takes ~5 min (was 35–60 min).

| Run | What changed | Hero wins | Median length | Timeouts | Median first contact | Monster reached S3 | Hero deaths |
|---|---|---|---|---|---|---|---|
| v14 (48 seeds) | resting monster fights back attacking mobs | 40% | 457 s | 0 | 413 s | 45 | 105 |
| v15 | baked navigation mesh | 42% | 467 s | 1 | 425 s | 20 | 45 |
| v16 | stage-1 monster flees attacking Hogs | 29% | 445 s | 4 | 396 s | 18 | 46 |

- Stage-1 deaths to mobs: v15 2/24 (99 s, 189 s; 790 mob damage each). A 330 s-cap probe showed the
  pattern (Hogs hit it while it farmed Bats beside them): fighting Hogs back → 7/24 deaths; fleeing them
  → 0/24 with the same mob damage taken. v16: 0 monster deaths to mobs.

### 2026-11-02 — feat/fix: monster strategy, formation, fog/cooldown UI, skill nodes, two review rounds, balance
Commits `b22ecd1` monster strategy · `70de7f0` + `33d8cea` formation · `2cdbd5c` fog flicker + cooldown
overlays · `387abc3` behaviour skill nodes · `9360899` fog layers + vision radii · `68fd729` pet ·
`5315793` formation review fixes · `a6e700e` skill cards · `a5ba09d` monster damage/spawn/hunt/farming ·
`3469b9a` exploration stalls + path budget · `38a9153` second review. Two adversarial review workflows
(18 + 11 findings, 13 + 9 confirmed) fed the fix commits. Every run is `tools/sim.sh 24 heroes 6`:

| Run | What changed | Hero wins | Median length | Timeouts | Median first contact | Monster reached S3 | Hero deaths |
|---|---|---|---|---|---|---|---|
| v5 | hero AI + balance pass (previous entry) | 54% | 88 s | 5 | 45 s | 2 | 40 |
| v6 | monster strategy layer + combos | 50% | 91 s | 3 | 43 s | 9 | 38 |
| v8 | formation (+ leader fix), rest mode, stage-1 farming gate | 66% | 98 s | 8 | 49 s | 8 | 2 |
| v9 | pet leash/hitbox, Zone-3 spawn, map-wide hunt | 16% | 313 s | 0 | 305 s | 20 | 60 |
| v11 | stage damage counted once, hero vision radii, review fixes | 29% | 381 s | 0 | 348 s | 17 | 51 |
| v12 | exploration no longer stalls, 16k path budget | 4% | 442 s | 2 | 425 s | 23 | 63 |
| v13A | README knobs: hero +10 HP / +1 dmg per level, stage-2 XP 150, Ram Dash S3 cd 5 s, Cleave/Slam S3 ×0.9 (21.6 / 45) — stopped at 18 runs | 17% | 463 s | 1 | 436 s | 15 | 44 |
| **v13B** | **same, but Cleave S3 24→12 and Slam S3 50→25 (shipped)** | **50%** | **507 s** | 4 | 469 s | 18 | 28 |
Findings worth knowing:
- Matches now land in the README's 4–10 min window, but the outcome is decided by the stage at first
  contact: across v9/v11/v12 heroes won 12/13 stage-1 contacts and 0/56 stage-3 fights (~18 s each,
  heroes deal ~460 of 2200 HP). With exploration fixed, heroes rarely meet the hiding monster before
  it hunts them at stage 3, so the stage-3 fight decides almost every match.
- README contradictions found by the balance panel: stage-2 XP 100 (stage table) vs 150 (Appendix A,
  Farming Path, Tuning Knobs); stage-3 ability tables (fights end in ~16–18 s) vs the Balance Sheet
  Late row (40–45 s fights); Front Cleave stage-1 cooldown 2.5 s (data) vs 4.5 s; Bat 50 HP / 1.5 s
  (data) vs 25 HP / 0.6 s; `stage_N_damage_multiplier` has no effect on Grount (all abilities tabled);
  hero kills pay the monster 100 XP (undocumented); Ram Dash "Charge forward, knockback" (README
  ability table) but no entity implements `apply_knockback`, so `knockback_force` does nothing (the
  dead per-hit branch was removed in the cleanup; implementing knockback waits for a user decision).
- v13B by stage at first contact: stage 1 → heroes 4/5, stage 3 → heroes 7/15 (47%, ~1,570 of 2,200 HP
  dealt), no contact (10-min timeout) → 4 runs. Stage-3 Cleave and Slam now hit lighter than at stage 2
  but recast faster, so the DPS still rises per stage (Cleave 5.7 → 6.7/s, Slam 2.1 → 2.8/s). Variant A
  (README ×0.9) still lost 14/14 stage-3 fights.
- One v13B run (seed 24) ended with the stage-1 monster dead at 220 s and no hero or pet damage
  recorded against it (Tech Debt item below).
- `World.tscn`'s Ground TileMapLayer makes ~38,000 navigation regions (one per tile): ~1 s until the
  map answers queries, and paths need a 16,384-polygon search budget. Baking the walkable area into
  one NavigationRegion2D in the editor would fix both (user step).
- Ted's pet killed the stage-1 monster alone in several runs (no leash, untargetable): fixed in `68fd729`.
- Process note: a Godot 4.7 editor session on the real project (16:58) bumped `config/features` to
  4.7, dropped two default-valued settings and re-imported addon icons; left uncommitted for the user.

### 2026-11-02 — fix/feat: hero AI + balance pass driven by the headless simulator
`tools/sim.sh` (seeded auto-play matches) showed the monster winning 92% of matches, every
match decided in ~90 s, the first hero dead at ~19 s to a mob camp, heroes stuck at level 1.
Root causes found and fixed (hero win rate 8% → 54% over 24 seeds; README target ~50%):
- **Front Cleave stage 1 dealt 52** (its own description and the README say 12/17/24) → 12.
- **Heroes never levelled in-round** (no `gain_xp`, `level_up()` never called): mob kills now
  share README hero XP (Bat 6, Hog 15) with heroes within 800 px (100% → 50% by distance),
  80 XP per level, max-HP gain healed, per-level damage reaches abilities
  (`HeroStatsComponent.get_damage_scale`); level label wired. Monster kill XP (`xp_value`,
  now README Bat 8 / Hog 25) goes only to the monster.
- **Vlad never basic-attacked**: his stats said RANGED with `min_distance 80 > attack_range 50`
  (unsatisfiable Fight gate). Now melee 20..50; HeroBase clamps any band with no room to stand.
- **River never healed** (resource `heal_amount = 0`, and nothing ever triggered her weapon
  swap) and fired 15/2.0 s with hard-coded values: data-driven 12 dmg / 1.1 s, 9 heal / 1.4 s.
  Irelia's basic was 2 dmg / 1.0 s → README 5 / 1.5 s.
- **No hero ever used its active ability**: auto-use at 4 Hz (default: once fighting); River
  swaps to the heal staff when an ally within 350 px drops below 60% and back above 85%;
  Irelia shields when someone near her is below 85%. **Divine Shield only protected Irelia**
  (the other heroes' shields hooked a removed `take_damage`): the Shield node now absorbs for its
  owner through `EventBus.damage_requested`. **Rally Cry did nothing** (Ted computed the boost
  into an unused local; the pet lacked the method): temporary attack-speed boost now lives in
  HeroBase and feeds `AbilitySystem.get_attack_speed_multiplier`; the pet's cooldown scales too.
- **Heroes fought alone**: heroes call teammates within 500 px into a fight
  (`alert_allies_radius`, scene-side), and summoned heroes keep that target out of their own
  detection circle (`pursue_out_of_sight_radius = 600`; previously the first re-evaluation
  0.5 s later dropped it). **Tank and focus fire** (README "planned"): Irelia's basic attack adds
  40 flat threat (`taunt_threat` on the resource, `taunt_strength` now scene-side) so packs turn
  to her; heroes prefer wounded enemies (`low_hp_focus_weight = 60`).
- Data validation tests: every combatant has a satisfiable attack band; README roster numbers.
- Still open (next): matches end too early (median ~90 s vs README 4–10 min) because the monster
  never farms and walks into the heroes at stage 1 → monster strategy layer (hide & farm /
  ambush / hunt / retreat, ability combos) from the investigation design.

### 2026-11-02 — fix: match clock + headless balance simulator (`e841302`)
- GameManager started a match in its own `_ready` (clock ran in the main menu → phantom match
  with result screen and rewards after 10 idle minutes); the clock used wall time (pauses and a
  backgrounded app counted). Now: unpaused game time, only between `start_new_match()` and
  end/abort. `monster_stage_reached` follows `EventBus.monster_evolved` (a winning stage-3
  monster was paid as stage 1).
- `tools/sim.sh [runs] [side] [workers] [cap]` + `tools/sim_match.gd` + `tools/sim_summary.py`.

### 2026-10-19 — fix: second adversarial review (production batch): 21 confirmed findings
A 69-agent read-only review of the commits after the perf pass (5 lenses × 2 refuters). Fixed:
- **River never attacked or healed**: `RiverBasicAttack.execute` returned early because River had
  no `get_weapon_mode()` (pre-existing). Added it; mode ranges now scale with the attack_range
  upgrades; the sniper hit check uses the caster's effective range.
- **attack_damage / attack_speed skill nodes had no effect** (12 nodes sold for Steel):
  `AbilitySystem.get_damage_multiplier / get_attack_speed_multiplier` now fold the HeroStats
  modifiers in. **Ted's +range nodes made him swing at air**: range-checked basic attacks
  (Ted, Irelia, Vlad, River) use `AbilityBase.effective_range(caster)` = max(ability range,
  caster attack range) so the Fight gate and the hit check agree.
- **Heroes spawned damaged** after +max-HP nodes (HeroStats initialised HP before the modifiers):
  `refill_health()` after the trees are applied.
- **Monster-side outcome was inverted** for rewards/label (pre-existing, made visible by the new
  jingle): `MatchRewards.outcome_for_side()` converts the heroes-view outcome; timeout = monster win.
- **Ted's pet respawned the next frame** (never waited 10 s) once AoE could kill it again:
  `TedPassivePet.on_passive_update` is one timer-respecting path; `teds_pet._receive_damage`
  ignores hits while dying (no double `died`).
- **Reset Progress wiped every setting** (silently re-enabling analytics, resetting language /
  volumes / tutorial flag): `wipe_progress(keep_settings = true)` keeps the [settings] section;
  tests use `wipe_progress(false)`.
- **Match-end jingle and music were paused with the tree**: UI + music players are
  `PROCESS_MODE_ALWAYS`; in-flight world SFX are stopped at match end.
- **Settings / Meta-skill overlays sat on canvas layer 0 under the menu's STOP Root** and could
  not be tapped: they are added under `%Root` now. Main-menu tooltips / header store untranslated
  keys so a language change re-translates them; tutorial auto-open re-checks the flag;
  camera debug toggle gated like the other debug keys.
- Test harness: locale pinned to `en` per test; `tools/lint.sh` isolates `user://`; the
  "not rewritten" save test counts saves and checks the file; epoch test re-arms the camp before
  the stale timer; pet test kills the mob the pet actually targeted; locale / tutorial tests
  re-read from disk. New: preferences survive Reset Progress, pet respawn timing, damage /
  attack-speed multipliers reach combat, spawn at full upgraded HP, River weapon mode + range,
  melee reach, side outcome mapping. Suite: 57 green.
- Refuted (no change): newer-save stamping, corrupt-backup naming, truncated-file migration,
  placeholder synthesis cost, skipped-tests counting, lint.sh exit semantics, concurrent test dirs,
  engine ERROR filtering, deferred-attach guard.

### 2026-10-19 — feat: ability-modifying skill nodes
- `MetaSkillNode.ability_name` (+ `make_ability()`): a node now targets one ability by its
  `ability_name` and modifies a property (cooldown, damage, ability_range, area_of_effect,
  duration, heal_amount, or any subclass export such as `dash_distance` / `slam_radius`).
- `AbilityBase.apply_meta_modifier()` records multipliers/adds on the INSTANCE and
  `apply_stage_stats()` re-applies them, so the monster's per-stage cooldown/damage tables no
  longer wipe permanent upgrades on evolution. `AbilitySystem.make_abilities_unique()` and
  `MonsterBase._make_abilities_unique()` duplicate the shared `.tres` per entity first (monster
  stage application used to mutate the shared resources).
- Seeded: River (Supply Drop cooldown / heal), Vlad (Blood Bomb radius, Land Mine cooldown), Ted
  (Trap Cage cooldown / duration), Irelia (Rally Cry / Dash cooldown), Grount (Front Cleave
  cooldown, Ram Dash distance, Ground Slam radius).
- Tests: hero node hits only the hero's own copy (shared `.tres` untouched); monster nodes survive
  evolution. Suite: 49 green.

### 2026-10-19 — feat: minimap with fog overlay
- `Scenes/UI/Minimap/Minimap.tscn` (Control in MainCam's CanvasLayer, top-right, 160×128):
  `%FogView` TextureRect shows `FogOfWarSystem.exploration_texture` through
  `minimap_fog.gdshader` (R8 explored → ground colour, else dark); `minimap.gd` draws hero / pet /
  monster dots and the camera's world rect at 4 Hz. Fairness: hero side sees the monster only
  inside a hero's `vision_radius`; monster side sees heroes only inside its 350 px vision.
  Tap/click → camera focuses the nearest hero (through HeroContainer so the panel highlight
  follows). Binds the fog lazily via `EntityRegistry.singleton(&"FogOfWar")`.
- Tests: world↔map mapping + clamping, fairness rules. Suite: 47 green.

### 2026-10-19 — feat: Pre-Round Setup (MatchConfig)
- `Scripts/match_config.gd` (Resource): aggression / farming / exploration sliders + formation
  (Tight / Spread / Line). `from_settings()` / `save_to_settings()` persist the last choice;
  `for_current_match()` returns the player's config on the hero side and neutral defaults when the
  AI plays the heroes against a monster player. Derived getters are the only thing the AI reads:
  `auto_ult_min_enemies` 4→1, `auto_ult_panic_hp_pct` 0.15→0.4, `priority_mob` 20→120,
  `exploration_update_interval` 5→1.5 s, `search_radius` 300→600, `formation_spread_px` 60/100/160.
- `Scenes/UI/PreRoundSetup/PreRoundSetup.tscn` (scene-built, 48 px sliders, en/de strings): opens
  from the heroes' PLAY button, emits `start_requested(config)` and the menu changes the scene.
- Consumers: `HeroBase._ready` (ult thresholds, mob priority) and `HeroExplorationController._ready`
  (update interval, search radius, formation spread).
- Tests: derived values, settings round-trip, screen collects + persists + frees; hero spawned with
  an aggressive config gets the aggressive thresholds. Suite: 45 green.

### 2026-10-19 — feat: post-review wiring (ids from resources, evolve signal, touch camera, log gating)
- `EventBus.monster_evolved` emitted by `MonsterBase._evolve_to_stage`; AudioManager plays `evolve`.
  MonsterBase merges its own `monster_<id>` tree via `monster_stats.monster_id`; world.gd starts
  the match music.
- Ids and vision are data now: `HeroStats.vision_radius` (300/250/220/200 in the four `.tres`)
  replaces world.gd's name-substring vision map; `GameManager._hero_id_from` reads
  `HeroStats.hero_id` (name matching only as fallback); `_monster_id` from `MonsterStats.monster_id`.
- `Globals.debug_log()` (static, `verbose_logs` flag + debug build) replaces the 25 raw `print()`
  calls in world.gd / monster_base_class.gd / spawns.gd. Debug keys (F1/K/M, Shift+R, F3) are
  ignored outside debug builds.
- Camera: pinch-zoom from two touches or a magnify gesture, tap-to-focus on the nearest hero
  (routes through the HeroContainer so the panel highlight stays in sync).
- `tools/lint.sh` + `tools/lint_all.gd` added to the repo (headless compile check on a temp copy).
- Tests: ids from resources, per-monster tree reaches the spawned monster, evolve signal. 41 green.

### 2026-10-19 — fix: adversarial review of the performance pass (8 confirmed defects + 3 hardenings)
A 53-agent read-only review (5 lenses × 2 refuters per finding) of commits P0–P5 confirmed:
- **Ted's pet locked onto parked mobs** (4 lenses): it only dropped a target on
  `is_instance_valid`, and pooled mobs stay valid instances. `_target_ok()` now requires in-tree,
  alive and within 1.5× search radius; a lost target retargets on the same frame.
- **Ted's pet became invulnerable**: P1 made the monster AoE queries area-only, but the pet is a
  CharacterBody2D with no Area2D. The pet's body now sits on `body_hero` (layer 2) and
  grount_slam / bull_front_cleave / ram_dash query bodies as well (entity roots are Node2D, so the
  pet is the only body those masks can return). DetectionAreas still never aggro it.
- **Corpse leash-healed in its death frame**: release is deferred, so a dead mob ticked once more;
  `_pre_tick` / `_reset_to_spawn` bail when parked or dead, and parked mobs keep HP 0.
- **Parked mobs lingered in the heroes' threat rows** (Irelia peel/taunt picked them):
  `TeamBlackboard.forget_attacker()` runs for every team in `TeamRegistry.unregister`.
- **`EntityRegistry.singleton()` raised after a scene reload** (typed assign of a freed instance
  aborted before the cache could refresh — blocker): the cache is read as Variant and validated.
- FULL-rate entities bypassed the `MAX_TICK_DELTA` hitch guard; parked mobs kept animating
  off-screen after reuse (sprite paused on park); HP bar + level label drifted apart as the monster
  scaled (both now under one counter-scaled `%Hud` node).
- Hardening from split verdicts: `EntityBase._ready` survives being parked mid-await
  (`await tree_entered`), `_setup_navigation` is out-of-tree safe, `deactivate()` clears
  `spawned_mobs` before releasing (synchronous `area_exited` no longer leash-resets a mob being
  parked), `_check_mob_exit` / `_attach_mob_deferred` ignore parked mobs, `attack_timer` guarded.
- Refuted (no change): accum reset on LOD change, FAR start bucket, trap-cage typed helpers,
  warning patterns, and the ToDead path (already fixed by the test harness commit).
- 6 regression tests (`test/test_review_regressions.gd`). Suite: 38 green.

### 2026-10-18 — feat: localization scaffold (English + German)
- `Assets/Locale/strings.csv` (63 keys; keys are the English text so every scene `text` property
  auto-translates), imported to `strings.en/de.translation` and registered in `project.godot`
  `[internationalization]` with `locale/fallback="en"`.
- `Scripts/locale_settings.gd`: persisted choice (`locale` setting: "" = device language, `en`, `de`),
  applied on save load and live from the new Settings LANGUAGE row (OptionButton; the code-built
  settings panel rebuilds itself so the change is visible immediately).
- `tr()` on the code-built strings in the main menu, settings, tutorial, match result, meta-skill
  screen and node buttons; `AudioSettings.label_for` and `MatchRewards.outcome_label` keys translate.
  Skill-tree node names/descriptions remain English (content, not UI).
- Tests: de/en resolve with fallback; locale choice persists and applies. Suite: 32 green.

### 2026-10-18 — feat: AnalyticsSink (local JSONL event log, opt-out, provider hook)
- `Scripts/analytics_sink.gd` autoload: `track(name, props)` buffers events, flushes every 5 s /
  20 events / on close-pause / on exit as JSON lines appended to `user://analytics.jsonl`.
  Hooks: `PersistedData.data_loaded` → session_start (save_version, total_matches),
  `GameManager.match_ended` → match_ended (winner, duration, side, kills, stage),
  `MetaSkillManager.skill_unlocked` → skill_unlocked; the tutorial reports tutorial_finished.
  `set_provider(callable)` receives every event for a future remote backend.
- Settings: new PRIVACY section with a "Usage statistics" CheckButton (`analytics_opt_out`
  setting, local-only explained in the tooltip). `PersistedData.is_loaded()` added for late
  subscribers. Match result screen now shows the permanent XP earned.
- Tests: buffering + JSONL append, opt-out + provider, unlock signal tracked. Suite: 30 green.

### 2026-10-18 — feat: AudioManager with generated placeholder audio
- `Scripts/audio_manager.gd` (autoload after GameManager, Node2D): 10 pooled `AudioStreamPlayer2D`
  voices on the SFX bus (max_distance 1400, attenuation 1.5 → distant fights are quiet), one global
  SFX player, one Music player; per-key 50 ms retrigger limit; voice stealing picks the voice
  furthest along. Hooks: `damage_applied` → hit / hit_big (heroes, monster), `entity_died` →
  death_mob / death_big, `ability_cast` → cast / ult, `GameManager.match_ended` → victory /
  defeat relative to the chosen side. Main menu plays `menu` music and clicks on every button.
- Sources: `Assets/Audio/<key>.ogg|wav` when present (README lists the keys), otherwise a
  procedurally generated 16-bit WAV placeholder (decaying sine sweeps with optional noise; a looped
  two-chord pad for music) so the game is never silent while assets are produced.
- Tests: every key has a stream (all placeholders today), rate limiting, music switching.

### 2026-10-18 — feat: per-hero (Steel) and per-monster (Leaves) skill trees, stat-only slice
- `HeroStats.hero_id` / `MonsterStats.monster_id` exports (set in the five `.tres` files) — the stable
  save keys; `MetaSkillManager.hero_id_of(hero)` reads it from the spawned hero's HeroStats.
- `MetaSkillManager`: `hero_tree_id()` / `monster_tree_id()` helpers, `_seed_character_tree()` builder,
  trees `hero_river/vlad/ted/irelia` (7 nodes, tiers 100/300/700 Steel) and `monster_grount`
  (7 nodes, 100/500/1000 Leaves). `apply_unlocked_to_hero` now stacks Hero Base + the hero's own
  tree; `collect_monster_modifiers(monster_id)` merges Monster Base + the monster's tree.
  The MetaSkillScreen picker lists the new trees automatically.
- Bug found by the new test: `HeroStatsComponent.add_stat_modifier` indexed `stat_modifiers[key]`
  with no default, so any stat without a pre-seeded key (attack_range) crashed. Reads with defaults now.
- Tests: every character has a tree with the right currency; River's +8% range applies to River
  only; monster base + personal trees merge.

### 2026-10-18 — feat: first-run tutorial overlay + touch targets
- `Scenes/UI/Tutorial/TutorialOverlay.tscn` + `tutorial_overlay.gd` (`class_name TutorialOverlay`,
  CanvasLayer, `process_mode = ALWAYS` so it also works over a paused tree): four steps (pick a
  side, heroes, monster evolution, progression) as a `const STEPS` array; Back / Next ("Got it" on
  the last step) / Skip wired scene-side; Esc skips. `has_been_seen()` / `mark_seen()` use the
  PersistedData `tutorial_seen` setting — skipping also counts as seen.
- Main menu: auto-opens the overlay 0.9 s after the intro on a fresh save; new "How to play"
  footer button re-opens it any time.
- Touch targets: every menu / settings / meta-skill control is now ≥ 48 px tall (`TOUCH_TARGET`
  const in the settings screen for the code-built buttons and volume sliders).
- Tests: walkthrough reaches the last step, Back works, finishing marks seen and frees the
  overlay; Skip marks seen. Suite: 21 tests green.

### 2026-10-18 — feat: versioned save migration with backups (`PersistedData`)
- `CURRENT_SAVE_VERSION` 1 → 2. `load_data()` now: resets the ConfigFile, backs up an older file
  to `save.cfg.v<N>.bak`, walks `_migrate(from_version)` one step at a time, re-saves; keeps an
  unreadable file as `save.cfg.corrupt.bak` before seeding defaults; warns (does not touch) on a
  file from a newer build. `get_save_version()` treats a file without the key as v1.
- v1 → v2 step normalizes what the first builds wrote loosely: currency / XP / match counters to
  non-negative ints (floats rounded, numeric strings parsed), skill lists to de-duplicated strings,
  volumes clamped to 0–1 (garbage → default), and seeds `[meta] created_unix` from the last save
  time. Each step is idempotent and tolerant of missing sections.
- Tests (`test/test_save_migration.gd`, isolated user:// only): v1 backed up + normalized,
  unversioned file counts as v1, current file untouched, corrupt file kept aside.
- Also: `_score_destination` skips the NavigationServer query until the map has synchronized
  (`map_get_iteration_id() > 0`) — it logged an engine error on the first frames; the test runner
  now fails only on `SCRIPT ERROR` lines (engine `ERROR:` lines can be deliberate in tests).

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
  the lazy helper) and is rate-independent. `GameManager.match_timer_changed` emitted at 4 Hz
  (the signal had no listener and was removed later in the 2026-11 cleanup).
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
