# Progress Tracker

Last loop run: 2026-11-11 (Jungle Guild overhaul done: 40 batches, `6985f6e`..8.5, on top of the code cleanup; local only, not pushed)
Stack: godot

Spec source: `README.md` (the design spec; `test/test_readme_spec.gd` checks its tables against the
data) + `Docs/INSTRUCTOR.md` (architecture guide). README "Current Status & Roadmap" is the short
summary of this file.

**Before the hourly loop works on this tree**: the overhaul is 47 local commits after `885e86a`
(origin/main), followed by its fix batches (F1 to F6 so far); push them first. On the loop's runner re-record the trace baselines before comparing
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
- [x] **Fix batch F1** (after the walkthrough of the overhaul) — minimap dots, camera frame and
      whole-world picture; ultimate toasts with the caster's name, only for casts the player
      sees; dead slots on a fallen hero's card; the monster side's fog, clear colour and slot
      row; the time left per ability on F3 (see Changelog)
- [x] **Fix batch F2** (fight readability) — rate-limited, softer hurt flash; casts face their
      target; the cleave crescent outside the grown body; y-sorted characters; stacked in-world
      HP bars and spread damage numbers; the death beat before the result screen; the Trap
      Cage's freed entry (see Changelog)
- [x] **Fix batch F3** (match speed) — a running match plays 1.2 game seconds per real second
      (`GameManager.MATCH_BASE_SPEED`) and the HUD's speed button doubles that; the pause menu,
      the death beat, the result screen and the menus stay at normal speed; headless runs keep
      game time (see Changelog)
- [x] **Fix batch F6** (German for all content) — every content text has a German row in
      `strings.csv` (590 rows): role lines, taglines, field notes, tips, stage names, ability
      descriptions, tree titles, branches, node names and effect texts; the tree model, the Codex
      chips and the evolution strip translate the parts of the lines they build; a language switch
      reaches the lobby, the match HUD, the pause menu and the tutorial without a restart;
      `tools/build_locale.sh` (see Changelog)

## In Progress

- (none)

## Backlog (in order; "user step" = needs the user, the editor or a device, not for the loop)

- [ ] **Push and review** (user step): `git log origin/main..main` is the whole overhaul; a
      whole-overhaul review (`885e86a..HEAD`) before the push was planned.
- [ ] **Decisions for the user** and **Placeholder copy** below (user step): each entry names the
      default that ships. The user accepted the list as it stood on 2026-11-11; the open list holds
      what came after.
- [ ] **Parity table at 48 seeds** — `MONSTER=all THREAT=all tools/sim.sh 48 heroes 8` and
      `... 48 monster 8`; at 24 seeds 9 of 30 cells are outside 35-65 % (Gorrak T3/T4 62-75 % both
      sides, Nyxa T2/T3 heroes side 67 / 71 %, Grount T2/T3 monster side 33 / 33 %).
- [ ] **Gorrak at threat 3-4** — his tree has no big tier-3 stat node; needs tree content or a
      retuned `ai_build_order` (only the axe damage moved the result in 6.8).
- [ ] **AI build size** (decision first): 3T character + 2T base entries keep the AI behind a player
      at the threshold (a P = 6T save wins 71-100 % as heroes at T4). Candidate: 3T + 3T.
- [ ] **Fight sides at walls** (G1) — a hero walks round its target to its side along the circle
      it stands on; a wall on that circle stops it where it is (it fights from there, as before).
      In a render where Grount stood against a wall the melee heroes stayed behind him. A detour
      (the other way round, or a smaller circle) needs care not to ping-pong at a wall's end.
- [ ] **Death moves** — the death beat (F2) is procedural (a hop, the fall backwards, a fade); an
      authored `death` move per body plan (humanoid, quadruped, flyer) could replace it.
- [ ] **Number spots for big numbers** (R4) — the columns (1.5 glyph heights, F2, with a +-2
      world px start jitter) and rows (a glyph and 4 px) are sized for the 22 px glyphs of a
      two-digit number. A big (30+, 30 px glyphs) or three-digit number next to or above a
      neighbour touches or covers its edge (seen in the zoom 0.5 render: a "33" on a "+9").
      Sizing a spot by the two numbers' sizes would fix it (`VfxManager._free_spot`); the 0.12 s
      pop overlaps briefly by design.
- [ ] **Monster instincts** — PreRoundScreen's Lurker / Ambusher / Ravager tiles are built and hidden
      (`show_instincts = false`); balance three `MonsterStrategy` presets per monster (sim), then show.
- [ ] **Pre-round scroll** — the heroes-side pre-round is about 1,700 px tall (R5's 48 px dials and
      144 px formation tiles added 52); on a 720x1280 phone STRATEGY / FORMATION need a scroll
      (START HUNT is pinned).
- [ ] **German copy review** (user step) — F6 wrote the German of all content (314 new rows in
      `Assets/Locale/strings.csv`; README "Localization" has the term table). Read it in the game
      (Settings, Language, Deutsch) and change what does not sound right: edit the `de` column,
      run `tools/build_locale.sh`, then the tests (they keep numbers, placeholders and widths in
      step). See "Decisions for the user" for the judgement calls.
- [ ] **Number format in German** — numbers are written the English way in both languages
      ("0.5 s", "2,200", "32.4"); German would be "0,5 s" and "2.200". Needs one formatter for the
      UI's numbers (`CurrencyChip.format_amount`, `MetaSkillNode.effect_text`, the "%.1f" lines)
      and German rows without digits typed by hand.
- [ ] **Dead rows in `strings.csv`** — 35 rows of the v0.1 menus (Main Menu, Pre-Round Setup,
      the old tutorial texts, "Skills", "Coming soon", ...) are no longer used by any scene or
      script. They are never shown; removing them makes the German review shorter.
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
      30 Hz, F3 at pinch zoom 0.5, and the same with the speed button on fast (F3: a frame costs
      about twice as much there). (Warnings: `tools/lint.sh` turns every one into an error on its
      copy since T1; `project.godot` keeps the editor's defaults.)
- [ ] Real audio assets (user step): `Assets/Audio/<key>.ogg|wav`; the manager plays generated tones
      until then.
- [ ] Balance retune after the P1 layer split (aggro 344→~203 px, AoE reach) — needs a playtest.
- [ ] "Second Wind" (needs the evolution-heal decision), trap / barrage slows, a second ultimate.
- [ ] Hero composition selection — a roster of more than four heroes, World spawns the chosen four.
- [ ] Heroes: threat assessment (flee from a Stage 3 monster).
- [ ] Elite camps (designed: 180 HP, 50 XP; not built), more mob types.
- [ ] Cloud save (`SaveBackend`); a remote analytics provider (`AnalyticsSink.set_provider`).

## Decisions for the user (the default that ships; change or confirm)

The user reviewed this list on 2026-11-11 and said the decisions look good overall. The entries
that were on it then are under "Accepted by the user (2026-11-11)", kept as a record; the open
list holds what was added after that review, and entries a later batch changed (marked).

### Open (added or changed after the review of 2026-11-11)

Gameplay:
- **Faster rounds** (P1, the user's request of 2026-11-11: "each round should be slightly
  faster, so faster movement speed and ingame speed"): everybody walks 20 % faster than before,
  on top of F3's base speed 1.2 (unchanged, `GameManager.MATCH_BASE_SPEED`). Every walking
  speed is x1.2 in the data (heroes 90 / 96 / 102 / 102 px/s, Grount 72 / 96 / 132, Nyxa 102 /
  126 / 150, Gorrak 67.2 / 76.8 / 88.8, Bats 180, Hogs 84, Ted's fox 144; strafing and the
  per-level gain too) with each rig's `full_speed`. On screen a character walks 1.44 times as
  fast as before both changes, everything else plays 1.2 times as fast. The match clock, the
  10-minute cap and every duration count game seconds, so a full match is 8:20 of real time.
  Measured, `MONSTER=all tools/sim.sh 24 <side> 2` (144 matches a run, threat 0; real s = game s
  / base speed; "before" = the parent `c60fa2f` at base 1.0, "base 1.2" = the parent as shipped):

  | Monster | Hero wins, heroes / monster side | Median match, real s: before / base 1.2 / P1 | Median first contact, real s | Reach Stage 2 / 3 | No contact, timeouts |
  |---|---|---|---|---|---|
  | Grount | 50 / 50 -> 58 / 54 % | 439 / 366 / **326** (-26 %) | 392 / 327 / **258** | 71 / 71 -> 50 / 50 % | 2, 2 -> 4, 4 |
  | Nyxa | 46 / 46 -> 58 / 58 % | 478 / 398 / **360** (-25 %) | 428 / 357 / **320** | 75 / 54 -> 71 / 54 % | 14, 15 -> 12, 12 |
  | Gorrak | 50 / 58 -> 46 / 42 % | 487 / 406 / **364** (-25 %) | 442 / 369 / **329** | 75 / 71 -> 83 / 75 % | 5, 5 -> 6, 6 |
  | All 144 | 50 -> 53 % | 480 / 400 / **351** (-27 %); mean 426 / 355 / 317 (-26 %) | 429 / 358 / **320** (-25 %) | | 21, 22 -> 22, 22 |

  In game seconds the median match went 480 -> 422 (-12 %). The goal was 25-35 % less real
  time ("slightly": not past about 40 %), so the pair stays at walking +20 % and base 1.2, at
  the low end of the goal. Options: base 1.25 gives about 30 % (422 / 1.25 = 338 s) with no
  other change (the sims do not see the base speed); walking +25 % needs a new sim. The match cap,
  the XP thresholds and the respawn times are untouched.
- **Gorrak walks 67.2 / 76.8 / 88.8** (P1): exactly 1.2 x his 56 / 64 / 74, so the character
  overview's Move speed tile shows "67.2" (every other character a whole number). Option: 67 /
  77 / 89 (the ratios to the others then move by 0.3-0.5 %).
- **No Reset Progress in a match** (R2): the pause menu's settings sheet hides the button
  (`SettingsScreen.allow_reset`), because a wipe in a running match let that match pay into the
  fresh save. Option: keep the button and have the wipe also drop the running match's rewards.
- **Damaged save values** (R2): a value of the wrong type reads as its default and stays in the
  file until that value is written again; a save from a newer build is backed up
  (`save.cfg.v<N>.bak`) and played on what this build knows (its version stamp is lowered on the
  next save); a file that no longer parses starts a fresh save next to `save.cfg.corrupt.bak`.
  Options: refuse a newer save with a message, or rewrite repaired values at once.
- **Match start without a map** (R2): the monster's placement waits up to 10 real seconds
  (`World.nav_wait_limit_sec`) for the navigation map, then keeps `MonsterSlot.spawn_position`
  (4509, 1794) in Zone 3 and the match goes on. The match clock and the heroes do not wait (the
  map answered within about 0.25 s in every windowed run, so the clock loses at most about 0.6
  game seconds on fast).
- **Supply Drop** (G1): the crate heals only once it has landed (0.5 s), only hurt heroes use it,
  and it fades once it has healed someone and nobody hurt is left on it (else after 20 s). River
  drops it only when a hero within its 60 px pickup radius of her (herself included) misses at
  least the kit's heal, so in practice mostly for herself: allies fight 200-300 px from her.
  Options: drop it on the most hurt ally within a range, or let the heroes walk to a kit.
- **Land Mine** (G1): an enemy already inside the 100 px trigger sets it off at once. Kept as the
  README's rule ("explosion when an enemy steps on it"): Vlad places it next to his target, so it
  is a point-blank burst every 8 s, and the balance was measured with it. Option: an arming delay
  (0.5-1 s) that makes it a trap; that weakens Vlad.
- **Ultimates in reach** (G1): every hero ultimate fires only when it reaches the pre-round
  dial's enemies inside its own area, or one enemy while an ally is below the panic HP. A lone
  monster counts as one, so at the neutral dial (3) Irelia taunts it and Vlad bombs it only in a
  panic, as before. Trap Cage's throw range is its `ability_range`, 200 px (was an unused 100).
- **Fight sides** (G1): Irelia holds the front of her target (90 degrees), Vlad its right (20),
  Ted its left (160); River strafes as before. Set per hero scene (`fight_side_deg`).
- **Monster ability 2 in a fight** (G1): Ram Dash, Shadow Swoop and the Tusk Axe are cast at the
  fought hero as the fight's opener and then every 15 s (`MonsterStrategy.fight_ability_2_interval`,
  per monster; Ambush and Hunt, the axe in every strategy), not only as the Approach gap closer.
  Cast on every cooldown (5 s at Stage 3) the burst decided the fights: 25 / 17 / 4 % hero wins
  (Grount / Nyxa / Gorrak, heroes side, 24 seeds) against 58 / 67 / 67 % without it. The interval
  keeps the cooldowns, the texts and the README tables as they were; the HUD slot then shows the
  ability ready for a while between casts. Option: longer cooldowns in the data instead.
- **River's staff** (R1): with the staff her patient comes first in every state, also between
  fights: the most hurt other hero below 95 % within 350 px; she walks to 120 px and heals within
  the staff's 150 px. Her Fight gate stays the rifle's in both modes. Options: heal only in a
  fight, let her heal herself, or keep the staff out of Idle so she enters the next fight still
  holding it.
- **Staff heal every 4 s** (R1 retune): the README's first design said 9 HP every 1.4 s. Once the
  staff really healed, that took the heroes from 42 / 42 / 25 % to 100 / 67 / 83 % wins (Grount /
  Nyxa / Gorrak, heroes side, 12 seeds); every 2.8 s gave 75 / 33 / 58 %, every 4 s 67 / 50 / 50
  %. One number changed (`heal_cooldown`, `river_basic_attack.tres`); the final balance batch
  may move it, or tune the monsters instead and give the staff its old pace back.
- **Fight leave margin** (R1): Fight is left no closer than 1.15 x the range Approach enters it at
  (`EntityBase.FIGHT_LEAVE_MARGIN`), so range nodes always pay. The stock entities are unchanged
  (their `max_distance` is already further out). Wide Sweep and Long Reach lengthen only the
  Fight gate, not Front Cleave's 80 px cone or the other abilities' reach; the cleave still
  connects at the maxed 108.6 px because a standard body adds 31 px. Making the keys lengthen
  the abilities too, as "+% ability range" suggests, is a balance change left open.
- **Exploration dial** (R1): the scan radius r (300-600 px) moves the three sample distances to
  r - 150 / r + 50 / r + 250 px, so the default dial keeps the 300 / 500 / 700 px the group always
  used and the default-strategy traces stay byte-identical. Option: centre them on r
  (r - 200 / r / r + 200), which changes the default exploration.
- **The scattered bats shed Irelia's taunt** (R3): Vampiric Rebirth's Scattered state drops the
  taunt with the target and the stun (the bats are cc-immune), so a re-formed Nyxa is no longer
  sent back to the taunter for the rest of its 5 s; a Trap Cage that held her lets her go for
  good. Option: keep the taunt on her after the re-form (it was).
- **Call of the Herd's recruits seek 350 px** (R3): a recruit that sees no hero goes for the
  nearest one within `MobBase.warband_seek_radius` (350 = the 250 px recruit radius plus the
  stomp's reach) and keeps after him out of sight while the warband lasts. Before, the camp's
  100 px leash found nobody and the recruit stood idle for 20 s, so the capstone is stronger
  now. Options: another radius, or drop the fallback (only recruits that see a hero fight).
- **Monsters stand still between casts** (R3, monsters-6): every monster is MELEE and holds its
  spot in a fight between casts, as Grount always did; the per-stage strafe numbers and the
  scenes' `preferred_distance` that nothing read are gone (README tables too). Giving monsters a
  between-casts strafe is a design choice left open: it changes every monster fight, all three
  trace baselines and the balance tables.
- **Hits on a corpse land nowhere** (R3): a second hit in an entity's death frame (three mines on
  one spot, an area attack after the killing blow) is canceled: no number, no lifesteal, no
  threat, and `deal_damage` returns 0.

Look and feel:
- **Grount's status marks follow his stage** (R4): the stun stars, the taunt's vein and the beams
  now use the box of the parts each stage draws, so at Stage I they sit on the calf's horns.
  His HP bar stays on the box of all three stages (it must clear the Stage III horns), so at
  Stage I and II the marks are now well below the bar instead of next to it. Option: keep the
  marks on the union box too (README would then say "the top of the art box").
- **Grount's stage heads** (R4): the HUD panel, the heroes' enemy tracker and the result
  screen's XP row show his Stage II / III portrait with a wider crop (Rect2(44, 24, 82, 82) and
  Rect2(26, 8, 100, 100) of the 128x160 canvas) so the grown horns fit; the head itself is
  smaller in the ring at Stage III. Option: crop the horn tips for a bigger head.
- **A never-ending swarm's slot** (R3): under Brood Mother the running swarm cannot be cast
  again, so once its cooldown is over its A3 slot shows the plain icon: no ready glow, no pop, no
  number (F3: "running"). Option: an "active" look (a ring or a pulsing frame) for a running
  ability.
- **Death beat** (F2, R2; changed after the review): a dying hero, the fox and the monster pop up, fall backwards and fade
  in 0.8 s; the result screen follows 0.95 s after the deciding death. The match keeps running
  during that second (decided, its clock stopped, Pause off): the survivors move on and the
  camera shake and kill puffs play. Since R2 no hit lands in it (every `damage_requested` is
  canceled), so nobody dies after the decision and no kill feeds the monster; the rewards are
  paid at the end of the deciding death's frame, after the kill's XP (a deciding kill that
  evolves the monster pays the new stage). Alternatives: freeze the match at the killing blow
  and let only the corpse move, or let the world run on and make the result follow its final
  state.
- **The speed button's look** (F3, changed in R5 after the review): two arrows always, on the grey round button at
  the normal speed and on the amber one (lit) on fast, no number, so it stays true whatever the
  base is. The single arrow it showed at the normal speed was the pause button's own play icon
  and read as "play"; in R5's render the grey and the amber two-arrow buttons tell the two
  states apart at a glance. Option: back to one arrow at the normal speed. The choice is saved
  (`match_fast`) and holds for the next launch. Option: every match starts at the normal speed.
- **A toast that is on screen when the language is switched** (the pause menu's settings; R5
  changed it after the review) keeps its language until it fades; everything else on screen
  follows at once. Its repeat guard no longer depends on the language (R5).
- **Safe area** (R5): on a phone with a notch or a home indicator the whole menu (MenuRoot) and
  the whole match HUD (`Root`) move inside the display's safe area; the menu's bands show the
  clear colour, the match's the world (the pause menu's scrim stops at the safe area too).
  Option: keep the screens edge to edge and only push the bars in (each screen's body would need
  the same inset). Not seen on a device: no export preset exists yet.
- **Last Stand's text** (R5): "Once per match a lethal hit leaves Irelia at 1 HP and makes her
  invulnerable for 2 s" (it wrapped with "2 s" alone on the second line); the German row is
  unchanged. A sheet test now fails on any effect line that ends on a number and its unit alone.
- **The formation tile is 144 px tall** (R5, was 128): the heading arrow has its own band above
  the dots, which keep their spacing. Option: keep 128 and pull the Spread dots closer.
- **The old Codex count is dropped, not moved** (R5): a save's `[settings] codex_seen_monsters`
  is removed on load; the Codex dot lights once more for pages such a save had seen (a count
  carried over could outlive a Reset Progress and hide new pages).

Tools (T1):
- **A stuck test stops the whole run**: after 120 s (wall clock) the runner names the test
  (`TIMEOUT <file>::<test>`) and kills the process, so the tests after it do not run. A GDScript
  loop on the main thread cannot be interrupted any other way; an `await` that never returns
  could be skipped instead, at the cost of a second mechanism. The slowest test takes a few
  seconds.
- **The runner exits 1 when it is not isolated** (started by hand on a copy whose `user://` name
  lacks `evolvemobile_tests`): the save tests are then skipped, and the run says `NOT ISOLATED`.
  Probe set-ups name their user dir `evolvemobile_tests_<something>`.
- **`sim_trace.sh` plays 2 matches at a time** by default (`JOBS=2`), for the 8 GB machine; the
  full gate (all three monsters) took 151 s here. `JOBS=6` restores the old six at once.
- **`bench.sh`'s `process_peak_ms` / `physics_peak_ms` are gone**: they read Godot's
  per-wall-second monitors, which reached back into the warm-up and the world load.
  `frame_peak_ms` (the mean of the slowest frame per 60 measured frames) replaces them; older
  bench logs cannot be compared on that line. The CPU time now comes from zsh's `times` instead
  of `/usr/bin/time` (so a kill reaches Godot).
- **The audio rate-limit test** retries when the machine stalled between the two plays instead of
  driving AudioManager from a fake clock (no test hook in the game code).

### Accepted by the user (2026-11-11)

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
- **Ultimate toasts** (F1): every ultimate of the played side is announced with its caster
  ("IRELIA · MONSTER TAUNT"), also off camera; an enemy's only while the camera shows the caster
  on revealed ground. The same caster's ultimate shows at most once per 60 s
  (`MatchAnnouncer.ultimate_repeat_guard`; it was 12 s), and a toast dropped because another one
  was up still starts that minute. Replayed on the walkthrough's cast logs this gives 16 instead of
  46 ultimate toasts in the 10-minute Nyxa match and 12 instead of 24 against Grount. Options: a
  shorter guard, or own casts only while on camera.
- **Monster panel slots** (F1): the row got larger slots (56 / 68 / 68 / 72 px) spread over the
  free width instead of ability names under them; names plus larger slots need a taller panel
  than 178 px.
- **Clear colour** (F1): `default_clear_color` is the palette's `bg_void` for the whole project,
  so wherever nothing is drawn (past the tile map's edge in a match) the screen is the fog's
  near-black, not Godot's grey. 28 flowers and rocks of the Deko layer that stood outside the
  ground were removed and one in a hole of the plateau's grass became a grass tile.
- **Hurt flash** (F2): a body flashes at most once every 0.45 s
  (`CharacterRig.hurt_flash_interval`), and the monsters' flash is a 55 % white mix at its peak
  (`hurt_flash_gain` 1.55 on `monster_base_class.tscn`; heroes and mobs keep the full white).
  Options: a longer interval, the same soft flash for heroes, or a flash only on big hits.
- **Draw order** (F2): characters are y-sorted, so a hero standing behind (north of) a big
  monster's feet is behind its body. HP bars and level pills draw above every body, so the bar of
  a hidden hero shows over the monster. Stand-off distances are the next gameplay batch (G1).
- **Stacked HP bars** (F2): overlapping bars of heroes and the monster rise above each other in
  rows of 20 px; the monster's bar never moves (the heroes' bars rise above it), and the order
  among heroes is the order they came on screen. Options: fan them out sideways, or shrink the
  bars of heroes that are not followed.
- **Cleave crescent** (F2): it starts outside the monster's drawn body; when he swings upward (at
  a target behind his body) it is drawn above his head, 16-60 px past the hit reach on the
  ground, because at the hit reach it would cover his face.
- **Match speed** (F3, the request of 2026-11-11 for a slightly faster round): a running match
  plays 1.2 game seconds per real second (`GameManager.MATCH_BASE_SPEED`, the one number to
  retune; batch P1 raises the walking speeds on top) and the HUD's speed button doubles that
  (2.4). The match clock, the 10-minute cap, the cooldown numbers and the result screen's
  duration count game seconds, so they run 1.2 (2.4) times as fast as a wall clock: a full match
  takes 8:20 (4:10). Options: another base, or a clock in real time.
- **Two speeds, no third** (F3): in the stress bench a frame at the fast speed costs about twice
  a frame at game time (3.3 against 1.6 ms, 3.9 against 2.1 ms with every rig awake). That fits
  at 2.4; a third step at 3.6 would be about 5.5 ms mean and 10 ms p99 on the development Mac
  before a phone's slower CPU and the drawing, and a 60 fps frame would be 1/17 game second.
  Option: measure fast on the device first (Backlog), then add a step.
- **A watched match steps coarser than a sim** (F3): the match logic runs once per drawn frame
  (it always did), so at 60 fps the base speed plays 50 steps per game second and fast 25, the
  sims 60. Same rules, not the same match step for step; fast on a 30 fps phone is 12.5 steps
  per game second (the scheduler caps a step at 0.5 s). The alternative, several logic steps
  per frame, needs the entity logic moved off `_process`.
- **A decided match plays at normal speed** (F3): the scale goes back to 1 at the deciding death,
  so the death beat (0.95 s) and the result screen are real time, as are the pause menu and
  every menu.
- **Reading at speed** (F3): a toast holds at least 1.2 real seconds at any speed (on fast it is
  up 1.47 s instead of 1.17 s); the first-match tips wait for a tap. Telegraphs and damage
  numbers stay game time and get shorter: a damage number shows 0.67 s at the base speed and
  0.33 s on fast, a cone flash 0.18 / 0.09 s. Option: hold them in real time too.
- **Skill sheet** (F4): the sheet under a tree has one height (286 px at 720x1280) with the
  buttons at its foot, so the tree stands still while nodes are tapped; a short node leaves about
  80 px of the sheet empty and the tree's rows are 124 px apart instead of 144. The alternative, a
  sheet as tall as its text, moves the whole tree by up to 87 px when a capstone is tapped.
  "Not learned yet" is gone (the rank line says "Rank 0/3"), which is what lets a locked capstone
  with a two-line text fit that height.
- **Locked nodes** (F4): a closed gate shows its reason on an amber line of its own and the button
  says LOCKED; "Maxed" and "Need 340 more" stay on the button. EQUIP appears once a capstone is
  owned (it used to stand greyed next to UPGRADE before the purchase).
- **Overview numbers** (F4): a tile shows the base number in white and what the owned build adds
  in green ("160 +124", "150 XP -20"), not the total. Option: the total with the bonus marked.
  The numbers are a hero at its start level (Veteran Squad counts) and a monster at Stage I,
  without in-match effects (Pathfinder's aura, Enrage, Bloodlust). The monsters' Damage tile is
  one hit of the basic ability at Stage I (Front Cleave 12, Sonic Screech 8, Cleaver Chop 14).
- **Two passives do more than their old text said** (F4, review heroes-10): Bloodlust is a ramp
  that starts at 30 % HP and reaches +50 % damage / +100 % attack speed only at 0 HP (at 15 % HP:
  +25 % / +50 %), and Adaptive Movement also gives +50 % attack speed for its 3 s. The texts now
  say so; the mechanics are unchanged. Options (gameplay, need sims): a flat bonus below the
  threshold as the old text promised, and a move-speed-only Adaptive Movement.
- **Quarry Change picker**: locked cards only shake (they unlock by hunt count, not for sale).
- **Tall phones** (F5): on a screen taller than 16:9 the lobby's extra height goes to the lair,
  which shows more cave above it (wall arches, thorn vines, eyes; the strip covers up to 21:9).
  The campfire stage keeps its 540 px. Option: share the height between both stages (needs taller
  campfire art too).
- **No tap on what just appeared** (F5): for 0.37 s after a screen starts to slide in or out
  (0.22 s slide + 0.15 s grace) the menu takes no new tap; a sheet the same while it slides up;
  the match result for 1.26 s, until LOBBY and PLAY AGAIN are fully shown. That is what stops a
  double tap from acting on the next screen. The price: a deliberate tap inside the grace time
  is dropped too. One number to retune: `TapGuard.GRACE`.
- **Confirm buttons** (F5): Reset Progress and QUIT TO LOBBY count the second tap only 0.6 s
  after the first (`ConfirmButton.MIN_GAP`), within 3 s. Options: a confirm dialog, or
  hold-to-confirm.
- **Lobby taps** (F5): the first tap on the stage that is not chosen only chooses the side, also
  when it lands on a character; a second tap opens the character (or a locked monster's unlock
  sheet). From the Heroes side a locked monster's sheet is two taps away.
- **Back keeps the hunters' strategy** (F5, walkthrough problem 18): dials and formation are
  kept as soon as they change, also when the pre-round is left with back. It used to be "back
  cancels" (the README said "back keeps the saved one"). Option: the old behaviour, or a visible
  RESET on the screen.
- **The HUNT arch follows the screen** (F5): on a roster, a character or a Growth tree the arch
  glows in that side's colour and opens that side's pre-round, and that side becomes the chosen
  one (as a lobby tap would). On the lobby and the Codex it is the chosen side. Option: the arch
  always means the chosen side, with the side written on it.
- **Growth** (F5) opens on the chosen side's tree and has HEROES / MONSTER tabs with a dot each;
  the nav bars' Growth dot lights when either tree has a rank to buy.
- **Codex pages of owned monsters** (F5): a monster the player owns has an open page whether or
  not the heroes have hunted it (NEW QUARRY still means "never hunted"). On a fresh save that is
  Grount's page, so the Codex dot is lit until the Codex is opened once. Option: count the
  starting monster as seen.
- **Role filters** (F5): a role without a member gets no filter button (heroes: support,
  monsters: swarm). River stays under ranged: the README's role table calls her Support / Scout
  and her card "Ranged · Healer"; filing her under support would leave ranged empty instead.
- **The AI quarry card** (F5) says "Threat N" and "AI build n/12" where the player's own cards
  have level and XP.
- **German terms** (F6; README "Localization" has the table). One word per concept, and
  existing rows changed for it: "LEVEL UP!" stays "LEVEL UP!" (it was "STUFE AUF!", but Stufe is
  the monster's Stage and the level is "Lv" everywhere); the ultimate is "Ultimate" (the slot
  caption was "ULTIMATIV", the tutorial said "eine Ultimative", the pre-round "Ultimates");
  "EVOLUTION" is "ENTWICKLUNG" like every other evolve text; the lair is "Höhle" (the tutorial
  said "Bau", the pre-round "Höhle"). Loan words a German player uses stay: Tank, Kills, Mobs, Lv.
  Options: German for any of them ("Stufenaufstieg!", "Ultimative Fähigkeit").
- **German names** (F6): the heroes' and monsters' names stay; roles and titles follow the
  character ("Tank · Anführerin", "Pirscherin · Die Fledermaus", "Koloss · Der Eber"; branches
  Schützin / Sanitäterin / Späherin for River, Eidwahrerin for Irelia). Gorrak's Stage I
  "Tusker" is "Frischling" (a young boar, as Bullcalf and Duskling are young), because "Keiler"
  is already the Hogs of Call of the Herd ("Ruf der Rotte"). The Brute role is "Koloss", the
  Stalker "Pirscher(in)".
- **Prerequisite line in German** (F6): "Benötigt: Breiterer Schlag oder Sogschlag" with a colon,
  so the node names stand as names (after "Benötigt" they would need the accusative). The lobby's
  rule is "Benötigt Lv-3-Monster": "Benötigt ein Monster auf Lv 3" ran 2 px past both screen
  edges under Nyxa and Gorrak.
- **Numbers in German** keep the English format ("0.5 s", "2,200"); see Backlog.
- **Fallen hero on the result screen**: tint 0.62 / 0.58 / 0.58 plus a colour drain instead of the
  UX spec's 0.42 / 0.39 / 0.39.
- **Heroes-side pre-round** needs a scroll on 720x1280 (Backlog).
- **Font**: Lilita One (approved, SIL OFL 1.1) is the display font. It has one weight and Latin
  glyphs only (German umlauts and ß included); anything else falls back to the body font (Godot's
  Open Sans SemiBold). A language beyond Latin needs a display font with wider coverage first.

## Placeholder copy for the user's review

- Grount's stage names (Bullcalf, Rampager, Alpha Bull) and his tip; Nyxa's (Duskling, Night
  Hunter, Dusk Matriarch) and Gorrak's (Tusker, Warlord, Boar King). German since F6: Stierkalb,
  Wüterich, Alphastier; Dämmerling, Nachtjägerin, Dämmermatriarchin; Frischling, Kriegsherr,
  Eberkönig.
- The redrawn Nyxa and Gorrak ability icons.
- Accent colours: Nyxa uses palette `monster2` (#8D55C2), not the spec's #7B3F95; Gorrak uses
  `monster3` (bog green), not the spec's crimson.
- The camp tour's fifth and sixth step (F5, English and German): "Grow between matches" now
  explains where the skill trees are; "The Codex" is a step of its own. "AI build %d/%d" /
  "KI-Ausbau %d/%d" on the quarry card.
- Codex field notes, taglines, tips and ability descriptions (English, and German since F6).
- The German of all content (F6): 130 node names, 73 effect texts, 26 branch names, 18 tree titles
  and blurbs, 26 ability descriptions and the roster's 33 texts. Written to be read by a German
  player, not word for word ("Erst der Käfig, dann die Fragen.", "Ruf der Rotte", "Nachtruhe").
- `Assets/Icon.jpg` is the app icon (`config/icon`) and stays; `test_legacy_retired` allows exactly
  two raster images (the ground tileset and this icon).

## Proposed (NOT approved — do not implement)

- (none)

## Verification gate

Every change passes `tools/lint.sh` (errors=0; every GDScript warning is an error there) and
`tools/run_tests.sh` (exit 0; 744 tests: 743 passed, 1 skipped headless, the run exits with nothing
leaked). A change that must not alter gameplay also keeps the determinism trace byte-identical:
`MONSTER=all BASELINE_DIR=tools/baselines tools/sim_trace.sh > <new trace>` (exit 0): seeds 1-3 ×
heroes/monster × every monster as full matches, `JOBS=2` at a time by default (no per-seed split
needed on the 8 GB machine). A change to a tool also passes `tools/selftest.sh`. Every 60 frames the trace hashes each EntityRegistry
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
| Grount (G1, 24 seeds) | 33 % | 33 % | 1 / 1 | 327 / 327 s | combat AI fixes; ability 2 in fights every 15 s |
| Nyxa (G1, 24 seeds) | 33 % | 33 % | 8 / 7 | 376 / 369 s | 7 matches of 24 without contact on each side |
| Gorrak (G1, 24 seeds) | 38 % | 50 % | 3 / 2 | 349 / 350 s | |
| Grount (R1, 12 seeds) | 67 % | 67 % | 0 / 0 | 305 / 305 s | River's staff heals (every 4 s); parent 42 / 42 % |
| Nyxa (R1, 12 seeds) | 50 % | 50 % | 4 / 4 | 376 / 376 s | parent 42 / 42 % |
| Gorrak (R1, 12 seeds) | 50 % | 50 % | 0 / 0 | 326 / 326 s | parent 25 / 33 % |
| Grount before P1 (`c60fa2f`, 24 seeds) | 50 % | 50 % | 1 / 1 | 331 / 331 s | first contact 392 s |
| Nyxa before P1 (`c60fa2f`, 24 seeds) | 46 % | 46 % | 8 / 7 | 376 / 376 s | first contact 428 s; 7 of 24 without contact |
| Gorrak before P1 (`c60fa2f`, 24 seeds) | 50 % | 58 % | 3 / 2 | 349 / 350 s | first contact 442 s |
| **Grount** (P1: walking +20 %, 24 seeds) | **58 %** | **54 %** | 2 / 2 | 296 / 296 s | first contact 309 s; 12 of 24 end at Stage 1 (was 7) |
| **Nyxa** (P1, 24 seeds) | **58 %** | **58 %** | 6 / 6 | 342 / 341 s | first contact 382 / 386 s; 6 of 24 without contact |
| **Gorrak** (P1, 24 seeds) | **46 %** | **42 %** | 3 / 3 | 304 / 313 s | first contact 393 / 396 s |

R1 (`MONSTER=all tools/sim.sh 12 <side> 2`, the parent `524536a` run the same way): River's staff
healed for the first time (`staff_heals`: 207-225 heals in 12 matches against Grount or Gorrak
at 1.4 s, 71-84 at 4 s). At the README's first 1.4 s per heal the heroes won 100 / 67 / 83 % (heroes side) and 100 / 67 / 83 %
(monster side), hero deaths against Grount fell from 31 to 6 in 12 matches; every 2.8 s gave
75 / 33 / 58 %, every 4 s (shipped) 67 / 50 / 50 % on both sides.

P1 (`MONSTER=all tools/sim.sh 24 <side> 2`, the parent `c60fa2f` the same way): everybody walks
20 % faster; every monster is inside 40-60 % on both sides, so nothing was retuned. Median match
480 -> 422 game s (144 matches), median first contact 429 -> 384 game s, 46 of 144 matches end
with the monster at Stage 1 (was 38): the faster walk finds the monster earlier. For the final
balance batch: the earlier contact moves the fights toward Stage 1, and a watched match on fast
takes longer steps than before (see the P1 changelog).

G1 (`MONSTER=all tools/sim.sh 24 <side> 2`): every monster is inside 30-70 %, Grount and Nyxa
below the 40-60 % target; the final balance batch retunes. Without ability 2 in fights the heroes
side was 58 / 67 / 67 %, with it on every cooldown 25 / 17 / 4 % (see the changelog).

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
| F2 `9620a45` → fix batch F2 | 1.626 → 1.648, 1.640 → 1.627 ms (p99 3.27 → 3.55, 4.29 → 4.00) | 2.183 → 2.002, 2.163 → 2.105 ms (p99 4.88 → 4.49, 4.65 → 4.65) |
| F3 `5b55a21` → fix batch F3 (game time) | 1.532 → 1.568, 1.502 → 1.616 ms (p99 3.35 → 3.31, 3.40 → 3.56) | |

Match speed (F3, `tools/bench.sh 3 2 900 300 0 <rigs_awake> <speed>`, back to back, load 4-5):

| Speed (`Engine.time_scale`) | Rigs asleep (frame mean / p99) | All rigs awake |
|---|---|---|
| game time, 1.0 (every other row of this section) | 1.613 / 3.86 ms | 2.111 / 5.08 ms |
| normal, 1.2 (what a player watches) | 1.829 / 4.47 ms | 2.418 / 5.61 ms |
| fast, 2.4 | 3.341 / 6.42 ms | 3.945 / 7.79 ms |

Walking +20 % (P1, `tools/bench.sh <runs> 2 900 300 0 1 <speed>`, all rigs awake, the parent
`c60fa2f` and P1 back to back, load 3-5): at the base speed (5 runs, alternated twice) 2.441 /
2.391 -> 2.507 / 2.535 ms frame mean (+3 to +6 %), p99 4.20 / 4.62 -> 4.53 / 4.05 ms; on fast
(2 runs) 3.386 -> 3.494 ms (+3 %), p99 5.56 -> 5.67 ms. Far inside the 16.7 ms frame, so fast
stays at 2.4.

- Total overhead of the overhaul against `885e86a`: about +0.03 ms with the rigs asleep and about
  +0.5 ms with all 232 awake (the limit was +0.6 ms).
- A frame costs more at speed because the game-time paced work (the mobs' 20 / 10 / 3 Hz AI
  ticks first) comes more often per frame: +13-15 % at the base speed, about twice at fast.
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
- [x] `MonsterBase._pick_camp` / `_count_slam_targets` counted Gorrak's warband mobs — fixed in
      G1 (`_count_huntable`, `GameUtils.can_entity_target`).
- [x] Content strings are English-only data — closed by F6 (German for all content).
- [ ] `strings.csv` keeps 35 unused rows of the old menus; numbers are not localized (Backlog).
- [ ] A headless MenuRoot run reports 3 leaked RefCounted (Godot's threaded-load tokens).
- [ ] `tools/sim_match.gd` counts a mob kill for the heroes when the killer is any `Node2D` that
      is not a monster (`_is(killer, "Node2D")`). Checked in 8.5: `is_class` matches inherited
      classes, so Ted's fox (a CharacterBody2D) counts; an earlier note said it did not. The game
      uses `GameManager.killer_side`; the sim could use the same rule. Low priority.

## Changelog
### 2026-11-12 — fix batch P1: faster rounds (everybody walks 20 % faster, base speed 1.2, pace measured)
Eighth batch of the second fix run: the user's request of 2026-11-11 ("each round should be
slightly faster, so faster movement speed and ingame speed so it does not feel as waiting").
Gameplay: every walker is faster, so the determinism traces change; the three baselines are
re-recorded in this commit.

- **Walking x1.2, in the data** (no hidden multiplier): `HeroStats` defaults (`base_move_speed`
  80 -> 96, which is Vlad's, `speed_per_level` 2.0 -> 2.4, `strafe_speed` 60 -> 72) and the four
  heroes' `.tres` (River and Ted 85 -> 102, Irelia 75 -> 90; per level 1.5 -> 1.8, 1.0 -> 1.2,
  Vlad's 1.2 -> 1.44; strafe 70 -> 84, 50 -> 60, 55 -> 66, Vlad's 75 -> 90); the fallbacks in
  `HeroBase._get_move_speed` and `EntityBase._get_move_speed` (80 -> 96) and
  `EntityBase.strafe_speed` (60 -> 72; only the monsters keep it, and they never strafe); the
  mobs (`mobs_base_class` 70 -> 84 = the Hog, strafe 40 -> 48; `Bat.tscn` 150 -> 180);
  `MonsterStats` (Grount's defaults 60 / 80 / 110 -> 72 / 96 / 132, Nyxa 85 / 105 / 125 -> 102 /
  126 / 150, Gorrak 56 / 64 / 74 -> 67.2 / 76.8 / 88.8) and `TedsPet.move_speed` 120 -> 144. Left
  alone as asked: the percent effects (Enrage x1.3, Rebirth's flight x1.5, Adaptive Movement
  x1.5, the tree nodes), the dashes (Ram Dash 500, Shadow Swoop 700 px/s), the axe (520). A
  Stage III Grount's dash is still 3.8 times his walk (2.9 enraged).
- **Rigs**: every `<id>_motion.tres` `full_speed` is the new walk speed (a monster's Stage 1);
  `stride` is unchanged. The steps follow the distance walked, so the feet stay planted at any
  speed: in the render Irelia walked 17.40 px per step cycle against a `walk_stride()` of 17.44
  at the base speed and 17.44 on fast. Her legs cycle 5.95 times a real second at the base
  speed and 11.6 on fast (2.6 frames a cycle in a 30 fps render: choppy but still a walk; 5.2
  frames at 60 fps).
- **Base speed 1.2** (F3, `c13f1b2`): it was there and is unchanged. `GameManager.MATCH_BASE_SPEED`
  is the time scale of a running match and 1.0 for the pause menu, the death beat, the result
  screen, a scene change and the menus (`test_match_speed`, 7 tests); headless runs keep game
  time. The render's clock ran 4.80 game seconds in 4.00 real seconds (x1.20) and 9.60 on fast
  (x2.40).
- **Pace** (`MONSTER=all tools/sim.sh 24 <side> 2`, parent and P1, 144 matches each): median
  match 480 -> 422 game s; in real time at the normal setting 480 s before both changes, 400 s
  with the base speed alone, 351 s now (-27 %; per monster -25 to -26 %); mean -26 %, median
  first contact -25 %. Inside the 25-35 % goal (low end), so the pair stays; base 1.25 would give
  about 30 % (Decisions, with the table). The 600 s cap, XP thresholds and respawn times are
  untouched.
- **Balance**: hero wins (heroes / monster side) Grount 50 / 50 -> 58 / 54 %, Nyxa 46 / 46 -> 58 /
  58 %, Gorrak 50 / 58 -> 46 / 42 %, all inside 40-60 %, so nothing was retuned. The heroes meet
  the monster sooner (Grount 392 -> 309 game s) and 46 of 144 matches end at Stage 1 (was 38).
  Recorded for the final balance batch (README Measured Balance, Balance below).
- **Distance per step** (checked, nothing changed): `_steer_along_nav` and `move_toward_point`
  clamp a step to the next path point and to the mesh; the rig counts a frame step over 64 px as
  a teleport, and the fastest walker (a Bat, 180 px/s) covers 14 px a frame on fast at 30 fps
  (29 px for a rig that skips every other frame over the budget); the melee bands between
  `min_distance` and the attack range are 20 px or wider against 8 px a frame for a hero on
  fast at 30 fps; the camera's follow lag is speed / 5.22, 29 px behind a Stage III Nyxa.
  In the render the camera kept the followed hero centred at both speeds.
- **Tests**: new `test/test_walk_speed.gd` (3): every walker's numbers are x1.2 of the pre-P1
  table (heroes, monsters, both mob scenes, the fox), every rig's `full_speed` is its walk speed
  and the menus' `CharacterDef.rig_profile` is the scene's, and a level 1 Vlad covers 96 px in a
  game second (80 before), straight and along a navigation path. On the parent the first and the
  third fail (29 failed asserts); the rig check passes there too (it guards the pairing).
  Updated: `test_gorrak` / `test_nyxa` stage speeds, `test_spawn_pool` mob strafe 48,
  `test_detail_fit_and_stats` Irelia's Move speed tile "90 +8".
- **Docs**: README Match Speed (the walking paragraph, the pace table, longer steps per frame),
  hero details, the three stage tables, Mob Camps, the rig table, Measured Balance and the
  roster overview, "If Matches Too Long", the Short Loop; INSTRUCTOR section 10 ("walking speeds
  are data"); `GameManager`'s comment. Decisions: split into an open list and the entries the
  user accepted on 2026-11-11 (kept as a record; three entries a later batch changed are in the
  open list, marked), with this batch's two entries on top.
- **Verified**: `tools/lint.sh` errors=0; `tools/run_tests.sh` 743 passed, 0 failed, 1 skipped (the rendered
  minimap test), nothing leaked; traces re-recorded
  (`MONSTER=all RECORD_DIR=tools/baselines tools/sim_trace.sh`: 1316 / 3226 / 2516 lines, were
  1998 / 3428 / 2846: the matches end sooner) and checked byte-identical with and without `RIGS_AWAKE=1`;
  bench in Performance; muted renders (walk at zoom 2.6 at both speeds, the first camp fight,
  a Stage III Grount fight with its toasts).

### 2026-11-12 — fix batch R5: components and HUD leftovers (pops, dials, safe area, toasts, speed button)
Seventh batch of the second fix run: review findings components-1, -2, -3, -6, -7, -9, -10,
menus-11 and hud-7, the second review's flow-3, locale-1, menus-1, menus-2 and menus-3, and the
leftovers of F3, F4 and F5. Presentational: the determinism traces stay byte-identical.

- **Pops that never showed** (components-2): the LEVEL UP! pill, the result ribbon, NEW QUARRY
  and (same trap, found on the way) the match toast sat straight in a container, which put their
  scale back to 1 in the frame they were shown: every pop ran 1 -> 1. New `PopSlot`
  (`Scenes/UI/Components/pop_slot.gd`): a plain Control that takes its content's minimum size;
  the content fills it by its anchors, pops around its centre (`pivot_offset_ratio`) and keeps
  its scale. XpRow pops `%Pill` inside `%LevelUp`, the result screen `%Ribbon` inside
  `RibbonSlot`, the pre-round `%NewBannerPill` inside `%NewBanner`, the HUD `%Toast` inside
  `ToastSlot`. The lobby's HUNT pop and the HUD level badge sit in plain Controls and were fine.
- **Currency chips** (components-7): the pop ran beside the count, and from 1,000 up a wider
  number re-sorted the row every frame (2 of 30 frames popped for 1,847 -> 4,347). The chip pops
  when the count lands.
- **Formation arrow** (components-9): Spread's top dot covered the arrow whole, Tight's a third.
  The arrow has its own 16 px band (`ARROW_BAND`), the dots their field below it
  (`arrow_points` / `dot_centres`, static, tested at the real tile size); `FormationTile` is
  144 px tall (was 128) so the dots keep their spacing.
- **Stage characters** (components-10): the random phase was an interval inside the looping
  idle, so every cycle rested up to a period. The phase is drawn once (`phase`) and applied with
  `custom_step` outside the loop; a restart resets the rig first and keeps the phase.
- **Dials** (components-1, menus-11): the strategy sliders are 48 px tall (were 36).
- **Safe area** (components-3): `SafeArea` maps `DisplayServer.get_display_safe_area()` into the
  viewport (only on a mobile build; `simulated` for tests); MenuRoot and the HUD's `Root` fit
  inside it at `_ready` and on a resize. Not seen on a device (no export preset yet).
- **Toast floor** (flow-3): the 1.2 real-second floor was fixed as game time when the toast
  started, so a toast sped up mid-hold was readable for 1.00 s. A real-time tween
  (`set_ignore_time_scale`) runs beside the game-time hold from the end of the pop; the fade
  starts when both are over, and a pause holds both.
- **Ultimate toast guard** (locale-1): keyed by the caster's instance id and the untranslated
  ability name, not the shown line, so a language switch inside the 60 s guard no longer lets
  the cast toast again. hud-7 itself was fixed by F6 (a26336e, tests in both directions); the
  on-screen toast keeping its language stays a decision.
- **Speed button** (F3's open question): two arrows always, grey at the normal speed, amber
  (lit) on fast; the single arrow was the pause button's own play icon. The render shows the
  two states apart at a glance; `speed_normal_icon` / `speed_fast_icon` are gone (the scene's
  icon).
- **Skill tree names** (menus-1; components-6 was fixed by F4, 78877ef): a selected node draws
  above the others (`z_index` 1), so its two-line name is never under a capstone's arch, and the
  view keeps `SkillNodeButton.selected_name_overhang(CAP_TILE)` (29 px) under the last tier, so
  a selected German two-line capstone name ends at 838.9 instead of 859.9, above the sheet (846).
- **Last Stand** (F4's leftover): "…leaves Irelia at 1 HP and makes her invulnerable for 2 s"
  wraps "…makes her / invulnerable for 2 s"; the sheet walk fails on any effect line that ends on
  a number and its unit alone. Translations rebuilt (`tools/build_locale.sh`).
- **F5's leftovers**: the roster's unreachable "Nobody in this role yet" label and its CSV row
  are gone; `PersistedData.RETIRED_KEYS` drops `[settings] codex_seen_monsters` on load and saves.
- **Stale shader message**: "Cannot load shader: res://Scenes/UI/HeroContainer/
  ability_cooldown.gdshader" comes from the user's editor cache only
  (`.godot/editor/editor_layout.cfg`, a shader tab left open; `.godot` is ignored); nothing in the
  repo refers to it. Closing that tab in the editor ends it.
- **Tests that measure** (menus-2, menus-3): the spawn comparisons check the Damage tile of every
  monster and the Damage and Range tiles of every hero against the spawn (River's +150 and
  Ted's +25 range); the tall-lobby test lays the lobby out at 720x1560 and 720x1680 and compares
  the cave's top with the stage's.
- Render (muted, scratch drivers on a copy, 30 fps): the result screen's ribbon is drawn at
  about 0.7 of its width at 0.13 s and full at 0.23 s; Irelia's LEVEL UP! pill shows small at
  1.03 s, overshoots and settles; NEW QUARRY grows over its first frames; the toast is drawn
  small and faint first; the formation row shows all three arrows clear of the dots; the Speed
  button shows two arrows on grey, then on amber after the press.
- Gate: `tools/lint.sh` errors=0; `tools/run_tests.sh` 740 passed, 0 failed, 1 skipped (the
  windowed minimap test), nothing leaked at exit; 14 new tests, 9 extended (the toast queue test
  steps the real-time floor too). With the fixes reverted on a copy (APIs kept where the tests
  need them), the chip, floor, dial, selected-name, retired-key, cave and spawn tests fail (the
  chip popped 0-6 frames, the floor gave 1.00 s, the dials 36 px, the names ended at 859.9 px);
  the pop tests use the new slots and were checked by render. `MONSTER=all
  BASELINE_DIR=tools/baselines tools/sim_trace.sh`: identical (1,998 / 3,428 / 2,846 lines).
  `tools/bench.sh 2 2 900 300`, parent then this tree back to back (load 4.6): frame mean
  1.808 / 1.763 ms, p99 4.367 / 4.620 ms (+6 %, inside the runs' 3.46-5.28 ms spread).
### 2026-11-12 — fix batch R4: VFX and rig polish (numbers, wards, stun stars, the fox, rigs, stage heads)
Sixth batch of the second fix run: review findings vfx-5, vfx-6, vfx-7, rig-1 to rig-7, gaps-2,
and the second review's fight-2 and fight-3 (the fox's HP bar, now required). Presentational:
the determinism traces stay byte-identical, plain and with every rig awake.

- **Damage numbers zoomed out** (vfx-5): F2's `_free_spot` had fixed the side-by-side columns;
  the rise was still 18 world px, so at zoom 1.0 / 0.5 a number had risen only 18 / 9 screen px
  (less than its 22 px glyph) when the next one in its column started on it. The rise is now at
  least one number row on screen (`number_row()`, the glyph and 4 px; zoom 2.0 keeps its 18
  world px), and a spot counts as taken while a number on it is not fading yet (70 % of its
  life; it was 0.5 s). The start's 6 world px lift over the HP bar is at least half a glyph on
  screen too (the first render at zoom 1.0 showed the numbers' lower halves on the bar).
  `number_rect()` is the drawn layout (`_draw_numbers` uses the same helpers). Ted's fox's
  numbers now start above its new hud, as everyone's do.
- **The ward of an expiring shield** (vfx-6): the Shield is freed the frame it expires and the
  ward read a missing shield as full strength, so a ward at 30 % flashed from 0.58 to 0.8 alpha
  as it faded. Each ward keeps the strength its shield last had (`_w_strength`); a broken
  shield's fade uses 0 now. `ward_alpha(hero)` is what `_paint_wards` paints.
- **Stun stars** (vfx-7): the orbit centre is `STUN_LIFT` 12 px above the head's top (it was 6,
  and the front star dipped 4 px into the head for a third of each turn); `stun_lowest_y()` is
  the drawn geometry the test now asserts on (its old check was constants only). A new test
  ends a Hog's tether, vein and stars on its death.
- **The fox bites facing its victim** (rig-1): its facing carrier turned only along its path,
  so a target already in bite range was bitten (and stared at between bites) facing away.
  `_attack_target` aims the carrier at the victim in range (`_face`).
- **Echo Strike's way back** (rig-2): the busy AI never turns the carrier during a dash, so
  Nyxa flew the return pass tail-first. While the dash the rig read from `DASH_STARTED` is in
  flight, the body faces its `dash_direction` (read only; the carrier is untouched).
- **The head channel** (rig-3): the procedural layer never set the head's angle back to rest,
  so a move's head lerped from last frame's value, froze in the blend-out and snapped at the
  hand-back (0.078 rad on the war cry). `_pose` writes it at rest like every other limb; the
  test steps the war cry and finds the head at lerp(rest, move, weight) on every frame.
- **Sleep drops the reactions** (rig-4): only leaving the tree dropped a move, the hurt flash
  and swing; a rig falling asleep off screen (or a hidden menu view) kept them and played the
  rest when it woke. `_drop_reactions()` runs on both; a move started while asleep still plays.
- **Grount's anchors per stage** (rig-5): `tools/rig_builder.gd` also writes `stage_bounds`
  (the box of the parts each stage shows; Grount's and the fixture's bodies rebuilt with
  `tools/build_rigs.sh`, one line each), `RigBody.drawn_bounds()` returns the current stage's
  box, and `mid_body` / `head_top` / `half_width` read it: at Stage I the marks sit on the
  calf's horns (17 px lower), beams end 9 px lower. `bounds` stays the union (fitting,
  notifier, shadow, HP bar; see Decisions).
- **Sub-frame key gaps** (rig-6): River's twirl unwound its full turn between 0.300 and 0.301 s
  and Gorrak's spin mirrored inside 0.1 ms gaps, which a frame could sample (an arm up to 180
  degrees off; an edge-on sliver). The first key of each gap is a step (transition 0) in
  `humanoid_moves.tres`; a library-wide test requires that of every gap shorter than 1/60 s,
  and the spin test now also samples inside every key gap.
- **Grount's stage portraits** (rig-7): `grount_s2.svg` / `grount_s3.svg` shipped unused.
  `CharacterDef.stage_portraits` and `stage_head_regions` (wider crops for the horns),
  `head_texture(stage)` and `portrait_at(stage)`; the monster panel's head follows the stage
  (`_show_stage`), the heroes' enemy tracker too, and the result screen's monster XP row shows
  the stage reached (`XpRow.stage`).
- **Placeholder tones** (gaps-2): `AudioManager._tone` draws its noise from a private
  RandomNumberGenerator with a fixed seed (`NOISE_SEED`), not about 32,000 global draws at boot.
- **A monster dying mid-leap** (fight-2): Ground Slam grew and faded the rig with a tween bound
  to the monster; the corpse kept the 1.19x size for the whole beat and snapped opaque. The
  rig's root resets before the reparent (the stage scale is the entity's), the beat fades from
  the alpha the body had, and the leap and Nyxa's scatter fade now tween the rig's `hop_scale`
  / `fade_alpha`, which a dying rig ignores (the bound tween takes one more step in the death
  frame; the first attempt still showed that frame at 1.19x).
- **The fox's HP bar** (fight-3, the backlog item): after F2's y-sort its plain z 0 bar was
  drawn under any character south of the fox. `TedsPet.tscn` puts it in an `EntityHud`
  (`%Hud`, z 1, `stacks`, a 20x4 footprint, wired to the fox's notifier), so it draws above the
  bodies and rises above a hero's bar it would overlap; `entity_hud.gd`'s header is true now.
- Render (muted, a scratch driver on a copy): the fox between two Hogs bites the left one facing
  left and, once it dies, turns to the right one (its bar 8 px above Vlad's, over the bodies);
  Nyxa with Echo Strike flies the return pass facing left (rig `_flip` -1 on every frame of the
  way back from the second one on); the monster panel shows the calf, the Stage II and the
  Stage III head (red eyes, full horns), the Stage III XP row too; at zoom 1.0 and 0.5 a hero hit
  every 0.25 s shows its numbers apart and above its HP bar, the stun stars above his head.
- Gate: `tools/lint.sh` errors=0; `tools/run_tests.sh` 726 passed, 0 failed, 1 skipped (the
  windowed minimap test), nothing leaked at exit; 16 new tests, 5 extended. With every fix
  reverted on a copy (APIs kept), 15 of them fail; the rest pin data (stage crops, every
  portrait used), the fox's hud placement or behaviour that was right (riders end on a death).
  `MONSTER=all BASELINE_DIR=tools/baselines tools/sim_trace.sh`: identical (1,998 / 3,428 /
  2,846 lines), and with `RIGS_AWAKE=1` too. `tools/bench.sh 2 2 900 300`, parent then this
  tree back to back (load 5-8): frame mean 1.675 / 1.620 ms, p99 3.509 / 3.548 ms; with every
  rig awake (`... 0 1`) 2.035 / 2.055 ms and 4.638 / 4.810 ms (+1 % / +4 %).

### 2026-11-12 — fix batch R3: monster bugs (Rebirth and the cage, Brood Mother, recruits, strafe data, intent pill)
Fifth batch of the second fix run: review findings monsters-3, monsters-4, monsters-6,
monsters-7, monsters-8, monsters-9, vfx-3, vfx-4, hud-2, hud-6 and hud-10. Flagged gameplay,
but the traces of all three monsters stayed byte-identical (1,998 / 3,428 / 2,846 lines), so
`tools/baselines` is unchanged: the capstone fixes act only where a save owns Vampiric Rebirth,
Brood Mother or Call of the Herd (no fresh save and no threat-0 build does), and the two
fresh-save edges (a hit on a corpse in its death frame, a dash whose caster died) never came up
before `match_ended` in the six traced matches per monster. The threat-0 sims (12 seeds, both
sides) gave the same summaries before and after.

- **Vampiric Rebirth and the cage** (monsters-3): a Trap Cage only skipped Nyxa while her bats
  were cc-immune; she stayed in `trapped_enemies`, so on the re-form, 3 s into the 6 s cage, the
  cage moved her from 400 px away to its edge in the same frame and held her among the heroes at
  30 % HP. `TrapCage._release` now lets a held enemy that turns cc-immune go for good (its
  `_process` hold and its exit check), with its tint. The stock test runs on past the re-form.
- **Rebirth into a sealed pocket** (monsters-8): `_scatter_point` took any fan point within
  16 px of a polygon, so the jump could land in one of the baked world's seven sealed pockets
  (or a wall edge) and hold her for the rest of the match. A point now counts only snapped onto
  the mesh and reached by a path from her within 4 px (`SCATTER_REACH_TOLERANCE`; the default
  32 px lets three pockets 19-30 px off the mesh through). Test: a pocket 15 px past the main
  mesh on the fan's first point; she re-forms on the next point her path reaches.
- **A swoop while scattered** (monsters-9): `BullRamDash._dash_update` stopped only for a freed
  caster, so a swoop in flight carried the scattered bats on and hit the heroes in its lane. It
  ends (one `DASH_ENDED`) for a caster that is not alive, as Night Swarm and the Tusk Axe do.
  The step reads its caster from `_dash_caster` instead of a bound argument, so a step queued
  for a monster freed in its death frame no longer fails to be called (the engine's "Cannot
  convert argument 1" line).
- **The taunt on the bats** (vfx-3): the Scattered state now drops Irelia's taunt with the
  target and the stun, and AbilityVfx ends whatever rode her body on `SCATTERED`
  (`_end_riders`, the same as on a death): the tether and the anger vein no longer ride the
  fleeing bats (381 px of tether in the review's probe) or follow her after the re-form. The
  pause half was fixed by R2 (`c008b27`, a pausable taunt timer); a new test pauses longer than
  the taunt and sees the taunt and its tether end together after the resume.
- **Brood Mother** (monsters-4): a swarm cast at Stage 2 and still running when a kill evolved
  her turned permanent with the Stage 2 bite (4 instead of 5, without Apex Predator) for the rest
  of the match. `apply_stage_stats` flags the turn and the next tick takes the bite from
  `MonsterBase.effective_ability_damage` again. Test through `_cast` and `gain_xp`.
- **The never-ending swarm's slot** (hud-6): once its cooldown was over the A3 slot popped and
  glowed as a ready ultimate for the rest of the match, though the swarm could not be cast.
  `CooldownSource.castable` (the ability's `can_use`) feeds `AbilitySlot.set_cooldown`: cooled
  down but not castable shows the plain icon, no glow, no pop, no number; F3 says "running".
- **Call of the Herd recruits** (monsters-7): the "nearest hero within chase_distance" fallback
  used the camp's 100 px leash, shorter than the mob's sight, and mobs drop what they do not see
  at their first re-evaluation (0.5 s), so recruits that saw no hero stood idle for the 20 s.
  `MobBase.warband_seek_radius` (350) is the fallback's radius and the warband's
  `pursue_out_of_sight_radius`, back to the scene's 0 when the warband ends. Test: a ticking camp
  Hog 300 px from the hero reaches him.
- **Strafe data** (monsters-6): monsters are MELEE and never read `strafe_speed` or
  `preferred_distance`; the per-stage strafe exports and values (`MonsterStats`, Nyxa's and
  Gorrak's stats), the two writes in `_enter_stage`, the scenes' `preferred_distance` and the
  README's Strafe rows and "keeps 55 / 50 px" are gone. Behaviour unchanged (no strafing added,
  see Decisions). A behaviour test replaces the property asserts: each monster in a fight
  between casts holds its spot (0 px in 60 frames); the README spec test refuses a Strafe row.
- **The intent pill** (hud-2, hud-10): `current_intent` tested `monster.target is HeroBase`,
  but `target` is the hero's Body Area2D, so a FARM or AMBUSH monster fighting a hero never read
  HUNTING. It tests `target_entity` now. A panel test drives a real chart (a Bat as target: the
  strategy; a hero in Approach and Fight: HUNTING) and the World test's tautology compares with an
  intent worked out from the chart instead.
- **Kills and corpse hits** (vfx-4): VfxManager inferred a kill from `is_alive()` after a hit, so
  the hit that scattered Nyxa's bats played the 0.6 monster-down shake and the kill puffs. Kills
  now come from `EventBus.entity_died` (in view), the big-hit shake only for a living target. A
  hit on a corpse in its death frame (the release is deferred: three mines on one spot) is
  canceled in Mob/Hero/Monster/pet `_receive_damage`: no second number or kill, no lifesteal or
  threat, `deal_damage` returns 0.
- Balance (`THREAT=0 MONSTER=all tools/sim.sh 12 <side> 2`), hero wins before / after: heroes
  side Grount 67 / 67 %, Nyxa 50 / 50 %, Gorrak 50 / 50 %; monster side the same 67 / 50 / 50
  % (every summary line identical before and after). No retune.
- Render (muted, a scratch driver, Monster side as Nyxa): at Stage I, FARM, fighting Vlad, the
  pill reads HUNTING; with Brood Mother at Stage III the 12-bat swarm circles her and its A3 slot
  shows the plain icon (no glow, no number), F3 "running"; with Vampiric Rebirth and Irelia's
  taunt (vein and tether on her before), the lethal hit scatters the bats with no tether or vein
  on them, no shake (trauma 0.00 -> 0.00), and she re-forms at 180 / 600 HP untaunted.
- Gate: `tools/lint.sh` errors=0; `tools/run_tests.sh` 710 passed, 0 failed, 1 skipped (the
  windowed minimap test), nothing leaked at exit; 10 new tests, 3 extended. Run against the
  parent code (the new test files on a copy of `c008b27`), 9 fail there (8 new ones and the
  extended cage test); the pause test (fixed by R2) and the hold-your-spot test (it pins
  behaviour that did not change) pass there too.
  `MONSTER=all BASELINE_DIR=tools/baselines tools/sim_trace.sh`: identical.

### 2026-11-12 — fix batch R2: pause-safe timers, match start and end edges, save robustness
Fourth batch of the second fix run: review findings heroes-5, monsters-2, meta-4, menus-8, hud-8,
menus-7, vfx-2 / gaps-1, review2:flow-1 and review2:flow-2, and the review gaps "match start with
the shipped navigation setting" and "corrupt saves". Flagged gameplay, but the traces of all
three monsters stayed byte-identical (1,998 / 3,428 / 2,846 lines), so `tools/baselines` is
unchanged: every change acts only on a paused tree, after the match is decided (the sims print
their END line and quit at `match_ended`), or while the navigation map is late (with the sims'
synchronous map the placement still tries on the second physics frame).

- **Pause-safe timers** (heroes-5, monsters-2): `SceneTree.create_timer(t)` defaults to
  `process_always = true`, so Trap Cage, the taunt's cleanup, a mine's lifetime, fuse and free,
  and a camp's 40 s respawn ran on while the pause menu or the result screen paused the tree: a
  7 s pause opened the cage and ended the taunt, a 30 s pause removed every mine, and a 40 s
  pause refilled a cleared camp (more kills, XP and pay). They are `create_timer(t, false)` now,
  like the slam, the dash and (since G1) the Supply Drop, and run in game time with the match
  speed. Tests: a 7 s pause keeps the 6 s cage closed (the monster pushed out is held), the 2 s
  taunt on and a 1 s mine in place, all run out after the resume; a 3 s pause holds a 1.2 s
  respawn, and at the fast speed (x2.4) it comes between frame 24 and 36. On the old timers all
  of these fail.
- **First-match HUD tips** (hud-8): their 1.5 s delay is a pausable timer, so a pause menu opened
  first holds them back until the resume; they no longer open over the menu and block RESUME.
- **First-run tour** (menus-7): `MenuRoot._auto_open_tutorial` opens it only over the bare,
  settled lobby; with HUNT, the settings or the unlock sheet up it looks again every 0.9 s (a
  HUNT inside the delay used to get the six lobby steps over the pre-round, the gear made it
  skip the tour for the visit). Render: no tour over the pre-round 1.3 s after the tap, step
  1 / 6 over the lobby after back.
- **QUIT TO LOBBY** (menus-8): the confirming tap calls `GameManager.abort_match()` before the
  tree unpauses, so a kill in the one physics step before the scene change cannot end and pay
  the forfeited match. Test: a monster death after the confirming tap ends nothing and pays
  nothing (it ended and paid the match before).
- **Reset Progress in a match** (meta-4): the pause menu's settings sheet has no Reset button
  (`SettingsScreen.allow_reset`, an export the pause menu turns off); the lobby's sheet keeps it.
- **Death beat** (vfx-2, gaps-1, review2:flow-1, review2:flow-2): vfx-2 itself was fixed by the
  F2 death beat (`5b55a21`); a test in a real World now shows the killing blow's number, the
  0.6 monster-down shake and its sounds at the kill, and the shake and the number done when the
  result screen pauses. Three edges of the beat are closed. (1) gaps-1: a world sound still
  playing when the result screen paused the tree finished when the player left the screen; the
  new `GameManager.result_shown` stops the pool there (`AudioManager.stop_world_sfx`, no longer
  at `match_ended`, so the kill's own sounds play), and `play_sfx` starts nothing on a paused
  tree. (2) flow-1: the kill's XP reaches the monster after the death is announced, so a
  deciding kill that evolved the monster paid the old stage (Monster side: 25 Leaves and 10 XP
  per stage short) while the beat showed the evolution. The rewards and the save are now paid at
  the end of the deciding death's frame (`_settle_after_death`, deferred); `match_ended`, the
  clock and the outcome stay at the death. Test: a Monster-side kill 1 XP short of Stage II pays
  200 Leaves / 45 XP and shows Stage II (175 / 35 and Stage I before). (3) flow-2: a hero who
  died in the beat fell, got a "HAS FALLEN" toast and then celebrated on the result screen. One
  rule now: no hit lands in the beat (`GameManager` cancels every `damage_requested` while
  `in_death_beat()`), so nobody dies after the decision and no kill feeds the monster. Test: a
  1e9 hit on River in the beat lands nothing, no toast, four survivors on the result.
- **Match start with the shipped navigation setting** (review gap): measured with a muted
  windowed run on the default settings (asynchronous map and region iterations on): the map
  answered 10 to 14 physics frames after World entered (about 0.25 s; 0.34 game seconds at the
  base speed, 0.59 on fast), 14 frames with 12 busy processes on the 8 cores; heroes started to
  move 3 to 5 frames later. An unthrottled headless run needs 96 frames (1.6 game seconds, 33 ms
  of wall clock); the old placement gave up after 180 physics frames and left the monster on its
  scene spot. `world.gd _place_monster` now waits for the map itself: until
  `GameUtils.nav_map_answers` (synchronised, with polygons) each miss waits for this world's next
  `NavigationServer2D.map_changed`, then tries on the next physics frame, so the sims' timing is
  unchanged; `nav_wait_limit_sec` (10 real seconds) is the fallback: the monster keeps
  `MonsterSlot.spawn_position` (inside Zone 3) and the match goes on. Test: World without its
  region waits 200 physics frames unplaced, and the region's arrival places it in the zone; a map
  that never answers places it once at the limit.
- **Save robustness** (review gap): `test/test_save_robustness.gd` feeds seven save.cfg variants
  through `PersistedData.load_data`, reads them as the menus and a match do, opens the lobby
  and starts a match. Before the fix the wrong-types case raised 160 SCRIPT ERRORs (`int()`,
  `float()`, `bool()` and `String()` of a list, a word or a table in `get_currency`,
  `get_hero_xp`, `get_skill_ranks`, `get_equipped_capstone`, the quarries, the volumes, the
  tutorial flags, the analytics and shake settings, `load_saved_choices`), 99 ranks counted 99
  in `points_spent` (POINTS gates) and `applied_ranks`, and a newer save was overwritten without
  a copy. Now every count reads through `_as_non_negative_int`, every id through `_as_id`,
  `get_setting` returns the default when the saved value's type does not fit it, ranks above
  the maximum count as the maximum, and a newer save is backed up as `save.cfg.v<N>.bak`. What
  each case does is the README's "Save File" table (missing: defaults; wrong type: default,
  repaired on the next write; unknown ids: ignored and kept; above max: the max; newer: backed
  up and played; truncated: kept as `save.cfg.corrupt.bak`, fresh save; empty: fresh save).
  `GameManager.load_saved_choices()` holds the boot's reads of the saved side, monster and speed.
- Render (muted, a scratch driver, Heroes side): the pause menu's settings show no Reset
  Progress; the tips open 1.5 s after the resume, not while paused; Grount killed beside the
  heroes falls with his 1e9 number while a 1e9 hit on River in the beat lands nothing; the
  result shows four heroes standing.
- Gate: `tools/lint.sh` errors=0; `tools/run_tests.sh` 700 passed, 0 failed, 1 skipped (the
  windowed minimap test; 15 new tests, 2 extended), nothing leaked at exit; each new test was
  run against the old code (the fixes reverted on a copy) and fails there. The sims were not
  rerun: with identical traces their matches are the same up to `match_ended`.

### 2026-11-12 — fix batch R1: River's staff, the range-node freeze, mines after death, the scan dial
Third batch of the second fix run: review findings heroes-2, heroes-12, meta-1, meta-2, vfx-1 /
heroes-6, heroes-7 and heroes-9. Gameplay: the traces change because River's staff heals now;
`tools/baselines` is re-recorded.

- **River's staff** (heroes-2, high): in staff mode `River._get_attack_range` returned the staff's
  150 px, under her `min_distance` of 180, so the Fight gate (measured to the enemy) never opened
  and `_on_fight_logic`, the only caller of the heal, never ran; the Approach override only turned
  her toward the ally. From the first wounded ally on she neither healed nor shot (0 staff heals in
  the reviewer's matches, 85 % of each match in staff mode). Now the Fight gate stays the rifle's
  in both modes, and in staff mode `_staff_step` serves the patient at the top of her Idle,
  Approach and Fight handlers (no new state; the chart stays the only state machine): the most
  hurt other hero below 95 % within 350 px, walked to along the nav path until 120 px away, healed
  whenever within 150 px and the staff is ready. With nobody to heal the state's own logic runs.
- **Retune**: the working heal at the README's 1.4 s took the heroes from 42 / 42 / 25 % to
  100 / 67 / 83 % wins (Grount / Nyxa / Gorrak, 12 seeds), outside 30-70 %. One number:
  `heal_cooldown` 1.4 -> 4.0 s, 67 / 50 / 50 % on both sides (Balance, Decisions).
- **Range nodes froze the fighter** (meta-1 high, meta-2 medium): the Fight leave distance was a
  fixed `max_distance` while the range nodes grew the enter range: Grount with Wide Sweep 3 + Long
  Reach 2 entered at 108.6 px and left at 100, River with Long Scope 4+ entered at 351+ and left at
  350 (the AI River at threat 3-4 holds 382.9), Ted with both nodes maxed 80.44 against 80. In
  that band the entity flipped Approach / Fight every tick, stood still and never attacked. One
  rule for every entity: `EntityBase.fight_enter_range()` (attack range or keep distance) and
  `fight_leave_range()` = `max(max_distance, 1.15 x enter)`. Every stock entity already left
  further out, so the fresh-save traces of this rule alone (with the exploration change, River's
  file at the parent) were byte-identical to the baselines.
- **Mines after Vlad's death** (vfx-1 / heroes-6): already fixed in G1 (`524536a`: the blast
  passes the guarded placer); this batch adds the test, which fails with the old line (the SCRIPT
  ERROR, the Hog at 100 HP, the mine still there). The class: Trap Cage (heroes-7) was fixed in
  F2 (`5b55a21`, covered by `test_trap_cage_outlives_a_target_freed_inside_it`); the Supply Drop,
  Divine Shield, Monster Taunt, Tusk Axe and Night Swarm never pass a freed owner or target on
  (checked; new tests for a kit and a taunt that outlive River and Irelia, and a mine's lifetime).
- **Exploration dial** (heroes-9): "scanning N px ahead" was stored and never read. The scan
  radius r now sets the sample distances (r - 150 / r + 50 / r + 250 px) and the random fallback
  (r +- 150), so the text is true; the default dial keeps 300 / 500 / 700 px.
- **Tests** (heroes-12): `test_review2_regressions` pinned the broken staff reach; it now checks
  the rifle's gate in staff mode. New `test/test_fight_gates.gd` runs the heroes' own charts:
  River heals in a fight and between fights and shoots with the rifle, every hero swings at a Hog
  inside its band, Vlad's Blood Bomb goes through `HeroBase._process` only among the enemies,
  River with Long Scope 5 + Sniper's Nest 3 shoots from 450 px, and every range-node rank
  combination of the roster (80 spawns, River in both modes) leaves Fight past its gate. Also
  Grount at Wide Sweep 3 + Long Reach 2 cleaves at his reach, the exploration dial's distances,
  and the placed objects above. On the parent's code all of them fail except the controls (the
  rifle shot, every hero's swing, Blood Bomb, the kit, the taunt, the mine's lifetime).
- `tools/sim_match.gd` reports `staff_heals` and `staff_heal_hp`.
- Traces: re-recorded (1,998 / 3,428 / 2,846 lines) and reproduced byte-identical. They part
  from the old baselines at frames 8,040-28,620, where an ally first drops below 60 % near River;
  Nyxa's seeds 1 and 3 (no such moment) are unchanged.
- Render (muted, a scratch driver: Vlad dropped to 40 % HP about 300 px from River one second
  in): she swaps to the staff at 1.5 s, walks over, heals him +9 at 3.1 s and then every 4 s,
  staying about 120 px from him as he walks on.

### 2026-11-12 — fix batch G1: combat AI (stale targets, ultimates in reach, ability 2, warband, stand-off)
Second batch of the second fix run: the walkthrough's combat items and the review findings
heroes-1, monsters-1, heroes-3, heroes-4, heroes-8 and monsters-5. Gameplay: the traces change
(every item below changes what the AI does), so `tools/baselines` is re-recorded.

- **Stale targets** (heroes-1, monsters-1): a killed mob's node goes back to the pool and the next
  camp anywhere gets it; every entity that had fought it found its old target alive again. Idle
  heroes then fired ultimates at it across the map (29 of 66 ultimates in the reviewer's seed),
  Trap Cage caged Grount there, and the monster and the call for help skipped such entities. Now
  `life_id` lives on `EntityBase`, the target pair has one writer (`_set_target_pair`, also used
  by `_broadcast_aggro`) that records the target's life, `is_target_valid()` compares it, and
  Approach / Fight clear a lost target (`_drop_lost_target`).
- **Ultimates in reach** (walkthrough, heroes-3): `HeroBase._should_auto_use_ultimate` asks the
  ultimate what a cast would reach now (`AbilityBase.count_reached`, around its own centre:
  Blood Bomb around Vlad, Monster Taunt the monsters within 200 px of Irelia, Trap Cage on a
  target at most its 200 px throw range away, which `execute` also enforces) and fires at the
  dial's enemy count, or at one enemy in a panic; nothing in reach, no cast. River's Supply Drop
  waits for a hero within its 60 px who misses at least its heal, and needs no target. In the
  144 sim matches no hero ultimate went off at a target more than 400 px away (`hero_ults_far`,
  a new field of `sim_match.gd`'s result, with per-ability cast counts `ability_casts`).
- **Supply Drop** (heroes-4): the kit's trigger was sized before its radius was set (50 px
  against the 60 px ring), its whole Area2D slid down the 100 px fall path, and River's own
  pickup mid-air faded it before it landed (alpha never above 0.16). Now everything is set before
  `add_child`, only the crate sprite falls, monitoring is off until it lands (0.5 s), full-HP
  heroes do not use it up, and it fades once nobody hurt is left on it (else after 20 s). A bug,
  by the README's own rule. **Land Mine** (heroes-8): an enemy already inside sets it off at once;
  that is the README's rule, so it stays (Decisions). Its properties are now also set before
  `add_child`, and a mine whose Vlad died during its fuse no longer passes the freed node
  (a SCRIPT ERROR in 4 of the first sims).
- **Monsters' ability 2** (walkthrough): Ram Dash, Shadow Swoop and the Tusk Axe were used only
  as a gap closer from Approach (or an escape). A fight now casts it at the fought hero as its
  opener and then every 15 s (`MonsterStrategy.fight_ability_2_interval`; the axe in every
  strategy). On every cooldown it decided the fights (heroes side 25 / 17 / 4 % against 58 / 67 /
  67 % without), hence the interval. Casts per match: 3.0 / 2.2 / 2.8 (1.4 / 1.0 / 1.0).
- **Warband** (monsters-5, PROGRESS bug): Gorrak's `_pick_camp` and `_count_slam_targets` counted
  his own Call of the Herd warband; both count only mobs `GameUtils.can_entity_target` lets him
  hit (`_count_huntable`).
- **Stand-off and fight sides** (walkthrough "heroes stack ... inside the big monster's sprite",
  F2's note on heroes hidden behind Grount): ranges to an evolved monster are measured from the
  edge of his grown body (`EntityBase.range_to` / `reach_bonus`: the Body circle x (scale - 1),
  15.5 px for Grount at Stage III), in the Fight gate and in the heroes', the fox's and the mobs'
  hit checks. Between swings Irelia, Vlad and Ted walk round their target to their own side
  (`HeroBase.hold_fight_side`, `fight_side_deg` 90 / 20 / 160 on the hero scenes: in front,
  right, left), along the circle at their distance. The four hero spawns in `World.tscn` are 80
  px apart (two pairs stood 38 and 53 px apart).
- Also: `BullRamDash._dash_update` stops when its caster left the tree (a test that ended
  mid-dash raised a SCRIPT ERROR). Existing cage tests throw across their test beds with a
  larger `ability_range` on Ted's copy.
- **Balance** (`MONSTER=all tools/sim.sh 24 <side> 2`, hero wins heroes side / monster side):
  Grount 33 / 33 %, Nyxa 33 / 33 %, Gorrak 38 / 50 % (see Balance). Inside 30-70 %, below the
  40-60 % target for Grount and Nyxa: left to the final balance batch.
- Render (muted, a scratch driver: Grount forced to Stage III on open ground, the heroes coming
  at him from the north): Irelia stands in front of him, Vlad on his right, Ted and the fox on
  his left, all drawn in front of his body. Where he stood against a wall the melee heroes stayed
  behind him (Backlog "Fight sides at walls").
- Tests: `test/test_combat_ai.gd` (14: a pooled mob's reuse, each ultimate's reach, the kit's
  landing and full-HP rule, ability 2 in a fight and its strategy, the warband in the slam count
  and the camp choice, the edge range, the fight sides in a live Stage III fight, the spawns).
  The ones the parent's code can run fail there (see the batch report).

### 2026-11-12 — fix batch T1: tools and gate that cannot pass by accident
First batch of the second fix run (review findings tools-1 to tools-12, the review's test-strength
gap, F4's warnings note). Presentational: the determinism traces of all three monsters are
byte-identical to `tools/baselines` (Grount 2,503, Nyxa 3,252 and Gorrak 2,774 lines), run by the
new `sim_trace.sh` in one call (`JOBS=2`, 151 s for all three monsters).

- **Lint fails unless it ran** (tools-1): `GODOT=/nonexistent tools/lint.sh` and a Godot that
  crashed before `LINT DONE` printed `errors=0`, exit 0. Now a missing binary exits 2 before any
  work (every tool, `tools/tool_env.zsh`) and the lint fails unless Godot reached `LINT DONE` and
  exited 0.
- **Warnings are errors in the lint** (tools-6, F4's note): `tools/list_warnings.gd` lists the 37
  warnings the project leaves at "warn" and `lint.sh` sets each to "error" in its copy's
  `override.cfg` (never in `project.godot`); `lint_all.gd` reports `warnings_as_errors=41` (with
  Godot's 4 default errors) and fails if one is still a warning. It found 5, all renamed:
  `hero_exploration_controller.gd` `snapped` (a built-in) → `on_mesh`, `tools/bake_nav.gd` `root`
  ×2 (shadowed `SceneTree.root`) → `island` and `remap` (a built-in) → `vert_remap`,
  `test_fight_readability.gd` `rig` (declared below in the parent block) → `puppet`. README
  "Headless Tools" lists the 37 names.
- **sim.sh and bench.sh see errors** (tools-4): each match writes its own log; a `SCRIPT ERROR` or
  a missing result names the seed on stderr with its first error lines and exits 1 (the summary
  still prints). `sim_summary.py` exits 1 for a group with fewer rows than runs or a Monster win
  before the cap with a hero alive. `bench.sh` fails a run without `BENCH_RESULT` or with a
  `SCRIPT ERROR` (its stderr went to the `/usr/bin/time` file, so the old check never saw one).
- **The runner** (tools-7, tools-12): a test that hits a SCRIPT ERROR fails (a `Logger` counts
  them; the error aborted the test, so its later asserts never ran and it printed `ok`); a
  skipped test counts as skipped, not passed (`== 658 passed, 0 failed, 1 skipped ==`, before
  `657 passed, 0 failed, 1 skipped` counted the skip twice); a run outside the isolated `user://`
  prints `NOT ISOLATED` and exits 1 (it reported the 221 save tests as passed, exit 0); a watchdog thread
  names a test still running after 120 s (`TIMEOUT <test>`) and kills the run. `_evolve` (three
  copies, unbounded) became the bounded `TestCase.evolve_to` with an assert, and Gorrak's F3-line
  axe loop got the 120-step bound of its siblings. `tools/run_tests.sh [name ...]` runs only the
  matching files.
- **A kill leaves nothing** (tools-3): zsh skips the EXIT trap on TERM and holds traps until a
  foreground child ends, so 26 sim user dirs, 6 trace dirs and 2 bench dirs had piled up in
  Application Support and killed `sim.sh` workers kept starting matches. `tools/tool_env.zsh`
  (sourced by all nine tools) turns TERM/INT/HUP into an exit, runs Godot in the background and
  waits for it, and its EXIT trap stops every Godot and worker before deleting the copies and
  user dirs.
- **`sim_trace.sh` has `JOBS`** (default 2): worker w plays every JOBS-th match on its own copy
  with a fresh `user://` per match, so the gate needs no per-seed split on the 8 GB machine; the
  output keeps the argument order.
- **sim details** (tools-2, tools-5, tools-8): the result is written at the end of the frame the
  match ended in, after the sim's own handlers of the deciding death and its killing blow
  (before: a wipe reported 3 hero deaths and `heroes_alive` 1). Seed 2 heroes now reports 4 deaths
  (River at 394.1 s, no ally within 500 px), `heroes_alive` 0, monster damage 674 (was 642) and
  monster XP 787 (was 687); seed 1 (a hero win) counts the killing blow: hero damage 1,355 (was
  1,335). `heroes_alive` is
  `GameManager.heroes_alive`. `SAVE=<missing file>` exits 2 (it played a fresh save), and a side
  other than `heroes` / `monster` exits 2 in `sim.sh`, `sim_trace.sh` and `sim_match.gd` (it played
  the heroes under the typed label). SIM_TRACE_END prints where it did, so the trace is unchanged.
- **bench** (tools-9): the first tick only starts the clock (`warmup=0` timed the world load as a
  frame: the review measured `frame_ms_max` 1,472 ms for `bench.sh 1 2 240 0`, now 20.3 ms against
  a p99 of 6.9 ms); `process_peak_ms` / `physics_peak_ms` (Godot's per-wall-second
  monitors, which reached into the warm-up) are replaced by `frame_peak_ms`, the mean of the
  slowest frame per 60 measured frames. CPU time comes from zsh's `times` so Godot stays the
  tool's own child (a kill reaches it). No bench gate: nothing that runs in a match changed (the
  minimap's draw only moved into `dots()`, at 4 Hz).
- **README** (tools-10): the THREAT text named a `MetaSkillManager.parity_build` with P = 6T that
  never existed; it now says what `sim_match.gd` does (`threat_override` and `side_ai_build`, 5T
  power ranks).
- **Audio test** (tools-11): the rate-limit refusal is asserted only when the clock shows both
  plays inside the 50 ms window; a stall between them is retried (up to 5 times).
- **`tools/selftest.sh`** (new): 23 checks of lint, tests, sim, trace and bench against a fake
  Godot on a stand-in project (about 10 s): crashes, planted SCRIPT ERRORs, a seed without a
  result, a bad side, a missing SAVE, `JOBS=0`, the trace order with `JOBS=2`, and a TERM
  mid-run of each tool after which no match may run and no copy or user dir may be left. The
  parent's tools fail 14 of them.
- **Test strength** (the review's gap): twelve mutations on a copy, the full suite each time. Caught:
  River's heal restores no HP (3 tests, `test_hero_capstones`, `test_ability_vfx`); a cooldown
  never starts (6: `test_hero_actives`, `test_stat_keys`, `test_hud_fog`, ...); every owned
  capstone applies (4: `test_skill_ranks::test_capstone_exclusivity`,
  `test_hero_capstones::test_only_the_equipped_capstone_applies`, ...); gold without the threat
  bonus (`test_rewards`, `test_match_result`); the tap guard lets presses through (6,
  `test_menu_flow`); no hit-flash rate limit (`test_fight_readability`); `move_speed` nodes not
  applied (`test_detail_fit_and_stats`, `test_opponent_threat`); the player's fog never clears
  (4, `test_hud_fog`, `test_match_toasts`); the heroes' fog memory never written (3,
  `test_hud_fog`). Not caught, now covered: the minimap's dots (only the rendered test, skipped
  headless, drew them): `Minimap.dots()` lists what `_draw()` draws and
  `test_minimap::test_dots_show_what_the_played_side_may_see` checks both sides' fairness rules
  on it; evolving at half the XP threshold was caught only by capstone tests and one XP point
  early by none: `test_identity_and_evolution::test_evolution_waits_for_the_full_threshold`.
- **The gate still fails when it should** (a copy with a planted unused variable and a null call
  in `GameManager._on_entity_died`): lint exit 1 (`errors=3`, the warning as a Parse Error),
  tests exit 1 (17 tests FAIL on the script error), `sim.sh 2 heroes 2 90` exit 1 (both seeds
  named, 20 script errors each), `sim_trace.sh "1"` exit 1.
- Tests: 657 → 659 (the two above). Gate: lint `errors=0` (225 scripts, `warnings_as_errors=41`);
  `tools/run_tests.sh` `== 658 passed, 0 failed, 1 skipped ==`, exit 0, nothing leaked;
  `tools/selftest.sh` 23 of 23; the traces above. Muted render of `test_minimap.gd` in a window
  (`run_tests.sh`'s runner with the file filter): the rendered pixel test passes, the hero dot
  drawn through `dots()` sits on the revealed moss (`impl_previews/fix_T1_*.png`).

### 2026-11-11 — fix batch F6: German for all content texts
Sixth fix batch after the walkthrough (`walk_menus` problem 6; review findings menus-4, meta-5,
heroes-11 and menus-9). Presentational: the determinism traces of all three monsters are
byte-identical to `tools/baselines` (Grount 2,503, Nyxa 3,252 and Gorrak 2,774 lines; one seed
per `sim_trace.sh` call, two sims at a time).

- **What was English** (problem 6; menus-4, meta-5, heroes-11): of the 338 different content
  texts the game data holds, 306 had no German row: all 7 role lines, taglines and field notes,
  the 3 tips, 9 stage names, 26 ability descriptions, 18 tree titles and blurbs, 26 branch
  names, 130 node names and 73 effect texts. With Deutsch (or a German phone on System) the
  frame was German and the content English ("Als Nächstes: +16% max HP", "Benötigt Wider Slam
  oder Gravity Slam").
- **German for all of it**: 314 new rows in `Assets/Locale/strings.csv` (590 rows now): the 306
  content texts and the 8 roster filter captions. Written as a German player reads a game, with
  one word per concept (README "Localization" has the table): "Tank · Anführerin", "Erst der
  Käfig, dann die Fragen.", "Ruf der Rotte", "Bodenschlag: +20% Radius", "Benötigt: Breiterer
  Schlag oder Sogschlag oder Narbengewebe". Proper names stay.
- **Mechanism** (the least machinery): the English text stays the key, as for the UI strings.
  A whole text handed to a Label or Button needs no code (the control translates it): role
  lines, taglines, field notes, tips, ability descriptions. The three places that build a line
  translate its parts: `UxTreeModel.from_ranked_manager` (title, blurb, branch and node names,
  so the sheet's rank line, the plaques and the block reasons follow), the Codex's stage chips
  and the pre-round's evolution strip. `MetaSkillNode.effect_text` already translated the
  description before filling "{v}" in (F4).
- **The generators stay the source of truth**: the data stays English (the `.tres` files, the
  seed data); the rows hang on the English text. `tools/build_skill_trees.sh --force` gives the
  shipped trees (`test_skill_trees_v2`, untouched) and cannot drop a translation.
- **Numbers stay in step**: the 73 effect texts take their number from the data through "{v}"
  in both languages. A fixed text with numbers (the monsters' ability descriptions) has the
  same numbers in its German row: the new test compares the numbers and the placeholders of
  every row, and an edited English text has no row until its German follows.
- **One word per concept**: eleven existing rows changed. "LEVEL UP!" (was "STUFE AUF!": Stufe
  is the Stage), "ULTIMATE" and "eine Ultimate" (were "ULTIMATIV" and "eine Ultimative" next
  to "Ultimates"), "ENTWICKLUNG" (was "EVOLUTION" next to "Entwicklung"), "Die Höhle der
  Bestie" / "Tippe auf die Höhle" (were "Bau" next to "DIE HÖHLE"), "noch keine Verbesserungen"
  (was "Upgrades"), "ein Talent der Ebene %d" and "Talentbaum" (were "Fähigkeit" /
  "Fähigkeitenbaum": Fähigkeit is the ability), "Benötigt: %s" (names after a colon) and
  "Benötigt Lv-%d-Monster". The row "HEROES" was in the file twice; one is gone.
- **A language switch needs no restart** (menus-9): MenuRoot refreshes the open screens on
  `NOTIFICATION_TRANSLATION_CHANGED` (the lobby's unlock rules stayed English under a German
  lobby); `MatchHud` and `MonsterHudPanel` write their stage, evolve, intent and tally lines
  again at once, on the paused tree (the pause menu's settings); the pause menu's QUIT button
  and the tutorial's bubble hold keys instead of translated lines (armed or opened in one
  language they stayed in it). `MenuRoot._refresh_screens` does nothing once the menu has left
  the tree: the new test caught the deferred refresh running there ("Cannot call method
  'get_nodes_in_group' on a null value").
- **German fits**: the new test lays every screen out at 720x1280 in both languages. One line
  did not fit: the lobby's "Benötigt ein Monster auf Lv 3" was 216 px, 2 px past both screen
  edges under Nyxa and Gorrak; it is "Benötigt Lv-3-Monster". Every node name fits its two
  lines of 100 px (150 px alone in its cell), every skill sheet its height
  (`test_detail_fit_and_stats`, now with real German).
- **`tools/build_locale.sh`**: imports the CSV on a temp copy and copies the two `.translation`
  files back; `--check` exits 1 when the committed files are not what the CSV gives. The files
  in this commit were built with it (a second run says "up to date").
- Tests: 647 → 657. New `test_content_locale.gd` (10 tests: every row of the CSV; every content
  text of the roster, the abilities, all nine trees and the tutorial has a German row; the
  tree model, the sheet, the plaques, the Codex chips and the evolution strip in
  German; in German no screen shows an English content text and nothing is cut or leaves the
  screen, on the overview with each ability open and the tree of all 7 characters, Growth, the
  Codex's three pages, the pre-round of both sides with every monster, the quarry sheet, the
  unlock sheet, the rosters, the lobby and every tutorial step; the switch on the lobby, in a
  match on both sides, on the pause menu and on an open tutorial step). With the old code and
  the new rows 8 of the 10 fail, with the new code and the old rows 7. `test_detail_fit_and_stats`
  and `test_ux_tree_model` updated for the German prerequisite line.
- Gate: lint errors=0; no GDScript warning in the changed or new scripts with every default
  warning set to error (the same five lines as before remain elsewhere, see Backlog).
  Bench (`tools/bench.sh 3 2 900 300`, the parent's files on the same import cache, three
  rounds strictly alternating, the averages of the rounds' medians): frame_ms_mean 1.546 →
  1.568 ms (+1.4 %), p99 3.534 → 3.431 ms (-2.9 %), CPU 3.587 → 3.590 s; each tree was ahead in
  one or two rounds. Nothing that runs per frame changed (the HUD's two `_notification` hooks
  act on a language switch only). Six earlier rounds ran while the machine was busy (load 5):
  the parent's own p99 went from 3.2 to 7.9 ms between two of them, so they say nothing.
- Muted renders in German looked at (`impl_previews/fix_F6_*.png`, 28 screens rendered): Grount's
  tree with Titanengestalt selected ("Benötigt: Breiterer Schlag oder Sogschlag oder
  Narbengewebe"), Irelia's, River's, Ted's and Gorrak's trees, Growth ("Basisverbesserungen der
  Helden"); Irelia's overview ("Tank · Anführerin", "Monster-Provokation · Ultimate") and the
  long passives of Nyxa and Gorrak; the Codex's monster and hero pages and the guide; the
  pre-round of both sides ("Stufe III / Dämmermatriarchin", the quarry's tip); the unlock
  sheet; the lobby with the two rules inside the screen. No English left, nothing cut.

### 2026-11-11 — fix batch F5: menu flow (taps, Codex, Growth, small layout bugs)
Fifth fix batch after the walkthrough (`walk_menus` problems 5, 7, 8, 9, 10, 11, 13, 14, 16, 17,
18, 19 and 20; review findings menus-1, menus-2, menus-5, menus-6, menus-10, menus-12 and
meta-3). Presentational: the determinism traces of all three monsters are byte-identical to
`tools/baselines` (Gorrak 2,774, Grount 2,503 and Nyxa 3,252 lines; one seed per
`sim_trace.sh` call, two sims at a time).

- **No tap on what just appeared** (problem 5; menus-1, menus-2). New `TapGuard`
  (`Scenes/UI/Components/tap_guard.gd`): while it holds, every new pointer press is swallowed
  before the GUI sees it. MenuRoot holds it on every push and pop (the 0.22 s slide plus 0.15 s),
  the unlock sheet, the settings sheet and the pre-round's quarry sheet while they slide up, and
  the match result until LOBBY and PLAY AGAIN have faded in (it drops `ui_cancel` for that time
  too). A double tap on HUNT at 0.08, 0.15 and 0.25 s no longer makes Grount the player's monster
  (Monster side) or opens the quarry sheet (Heroes side); a double tap on a back arrow no longer
  opens the settings; the second tap no longer closes a sheet on its scrim; a tap on a hero card
  when the match ends no longer presses the invisible LOBBY / PLAY AGAIN.
- **Confirm buttons** (menus-5, menus-10). New `ConfirmButton` (`Components/ConfirmButton.tscn`),
  used by Reset Progress and QUIT TO LOBBY: the confirming tap counts only 0.6 s after the arming
  one, so both taps of one double tap no longer wipe the save or forfeit the match; the 3 s
  window is one counter that starts again with every arming, so a QUIT armed again after a
  resume is no longer disarmed early by the first arming's timer.
- **START HUNT / UNLEASH** act once per visit (menus-12): a double press saved and tracked
  `pre_round_setup` twice.
- **Lobby** (problem 8): a tap on a character of the stage that is not chosen only chooses the
  side; on the chosen stage it opens the character's detail or the unlock sheet.
- **Tall phones** (problem 7): the cave runs on above the lair
  (`Assets/UI/Lobby/lobby_monsters_top.svg`, 720x420, from the new `tools/art/lobby.py`; it
  repeats the lair art's wall arches and continues its vines along their curves, so the join
  does not show). 720x1560 shows 280 px of it, 21:9 all of it.
- **Codex** (problems 10, 17; menus-6, meta-3): the player's own monsters have open pages
  (`CodexScreen.met_monsters()`: the quarries met, then the owned monsters); the seen count moved
  from `[settings] codex_seen_monsters` to `[codex] monsters_seen`
  (`PersistedData.get_codex_seen` / `set_codex_seen`), so Reset Progress clears it with the Codex
  and new pages light the dot again. An old `codex_seen_monsters` setting is no longer read (the
  dot lights once more for a save that had it).
- **Roster** (problems 9, 19): a role filter without a member gets no button (heroes: support,
  monsters: swarm); the grid is centred and adds columns on a wider screen (5 on a 960x1280
  tablet, where the cards sat in a 720 px block on the left).
- **Growth and the arch** (problem 11): Growth has HEROES / MONSTER tabs with a red dot each and
  the nav bars' Growth dot counts either side; a nav bar's arch starts the hunt of the side its
  screen stands for (roster, character, Growth tree) and glows in that colour.
- **AI quarry card** (problem 14): "Threat N" and "AI build n/12" (`CharacterCard.apply_ai_build`)
  on the pre-round's quarry card and the Change sheet's cards; it read "Lv.2" and "3/12". The
  threat is set at 80 % of the level's size, so "Bedrohung 4" stays inside an S card.
- **Sheets** (problem 13): the unlock sheet and the quarry sheet end on the screen's bottom edge
  (the nav tabs peeked out under them).
- **Settings** (problem 16): "Stored only on this device. Nothing is uploaded." (no
  `user://analytics.jsonl`), English and German.
- **Pre-round strategy** (problem 18): every dial and formation change goes into the settings at
  once (`MatchConfig.store()`), and the file is written when the screen is left or the hunt
  starts; it used to be lost on back (see Decisions).
- **Tour** (problem 20): step 5 "Grow between matches" frames the Heroes, Growth and Monsters
  tabs and says where the trees are (open a character, tap SKILL TREE); the Codex has a sixth
  step of its own.
- Tests: 628 → 647. New `test_menu_flow.gd` (19 tests, with real mouse presses through the
  viewport: the double taps at the three gaps with a control run without the guard, the sheets,
  the result's intro, `ConfirmButton`, Reset Progress, the pause menu's QUIT, START once, the
  lobby's first tap, the cave strip, the Codex pages and the reset, Growth's tabs and the arch,
  the AI card, the sheets' bottom edge, the privacy line, the tour step); `test_menu_root`,
  `test_roster_screen`, `test_match_config`, `test_codex`, `test_settings_and_back` and
  `test_ui_kit` updated for the new behaviour.
- Gate: lint errors=0; no GDScript warning in the changed or new scripts with every default
  warning set to error (the same five lines as before remain elsewhere, see Backlog). No bench:
  nothing that runs per frame in a match changed (the pause menu's QUIT is a `ConfirmButton`
  that processes only while armed; the result screen's guard exists only once the match is
  over).
- Muted renders looked at (`impl_previews/fix_F5_*.png`): the lobby at 720x1560 on both sides
  (the cave fills the band, no hard edge); the Codex with Grount and a bought Nyxa open on a
  save that never hunted; Growth with the MONSTER tab picked and a dot on each tab; the unlock
  sheet and the quarry sheet down to the bottom edge; the quarry card ("Threat 0", "AI build
  0/12"); the settings' privacy line; the Heroes roster at 960x1280 (five cards in a centred
  row); the tour's step 5 of 6 framing the nav bar.

### 2026-11-11 — fix batch F4: skill tree sheet and character overview
Fourth fix batch after the walkthrough (`walk_menus` problems 1, 2, 3, 4, 12 and 15; review
findings menus-3, heroes-10 and monsters-11). Presentational: the determinism traces of all three
monsters are byte-identical to `tools/baselines` (Gorrak 2,774, Grount 2,503 and Nyxa 3,252
lines; one seed per `sim_trace.sh` call, two sims at a time).

- **Texts that fit** (problem 1, menus-3): the sheet's lines run across its full width (644 px;
  the icon moved up beside the name) and Now, Next, the capstone rule and the gate's reason wrap.
  Every node of all nine trees shows its whole sheet in English and German, with nothing owned
  and with everything owned (133 nodes x 2 states x 2 languages); 11 effect texts were cut in
  English and 17 to 19 in German. The sheet has one height (286 px) with the buttons at its foot,
  so the tree does not jump between nodes; "Not learned yet" left for that (see Decisions).
- **Lock reason** (problem 2): a closed gate's reason is an amber line of its own above the
  buttons ("Needs Wider Slam or Gravity Slam or Scar Tissue", "Benötigt … oder … oder …", "Spend
  3 more points"), and the button says LOCKED / GESPERRT.
- **Real stats** (problem 3): each overview tile shows its base number and, in green, what the
  player's own build adds in a match: Irelia with Reinforced Plate 5/5, Unbreakable, Bulwark and
  Hero Base ranks reads "160 +124"; Grount "800 +350", "150 XP -20", "2,200 +1,463" with Titan
  Form. `refresh()` refills the tiles, so a purchase shows at once. The numbers come from the
  code a spawn runs: `MetaSkillManager.owned_hero_stats` (a `HeroStatsComponent` outside the tree,
  stacked by `_apply_tree_to_stats`, levelled by the new `HeroStatsComponent.apply_start_level`
  that `HeroBase` now calls too), `owned_monster_modifiers` (`_merge_monster_tree`) through the
  new static `MonsterBase.build_max_health` / `build_move_speed` / `build_evolution_xp` /
  `build_ability_damage`, and `owned_ability` (`_apply_ability_nodes`). They read the save
  whatever side is chosen. Tests spawn every roster hero and monster with its stat nodes owned
  and compare: max HP, damage, range, speed, attack speed, the evolution thresholds, and the
  Stage III health and hit with Titan Form and Apex Predator.
- **Capstone rule** (problem 4): every capstone's sheet carries one line for its state: "Only one
  capstone is active per character. Switching is free." (muted, before buying), "Equipped: this
  capstone is the active one. …" (green), "Not equipped: another capstone is active. …" (amber,
  over the green EQUIP button). EQUIPPED has the tree's check before the word. EQUIP shows once
  the capstone is owned.
- **Names** (problem 12): a node name too long for its width wraps onto a second line (Marching
  Order, Stunning Charge, Sharpened Snares, Disorienting Dive), ability tile names take two lines
  (Emergency Supply Drop, Monster-Provokation), and a selected node's name steps 7 px down, clear
  of the white ring. The capstones' tier sits 12 px lower (`SkillTreeView.arch_room`), so the
  arches no longer touch the names above them now that the rows are closer.
- **Monster numbers** (problem 15): the texts of Front Cleave, Ram Dash, Ground Slam and Nyxa's
  Sonic Screech give each stage's damage with its cooldown ("Stage 3: 10.8 every 1.8 s"), in the
  overview and the Codex. The monsters' Damage tile was the stage multiplier "×1.0", which the
  tabled abilities do not use; it is one hit of the basic ability at Stage I now.
- **Tooltips** (heroes-10, monsters-11; texts only, the mechanics are unchanged): Bloodlust "…his
  damage and attack speed rise as his health falls, up to +50% damage and +100% attack speed at
  the brink of death"; Adaptive Movement "…50% movement speed and 50% attack speed…"; Trample
  "…hits everything within 70 px of his path…" (70 is a half width; the old "70 px wide lane"
  would be narrower than the stock 80); Call of the Herd "A Warcry Stomp cast at a hero…". All
  four have German rows; `MetaSkillNode.effect_text` translates a description before filling in
  its value. README hero details and tree content follow.
- Tests: 618 → 628. New `test_detail_fit_and_stats.gd` (10 tests: the sheets, the gate's
  line, names / ring / arches, ability tile names, the tiles' bonuses, a spawned hero and a
  spawned monster of every def against the overview, tile widths, cooldowns in the texts, the
  four tooltips); `test_character_detail`, `test_grount_behaviour_nodes` and `test_match_result`
  updated for the new sheet and the tile's node path.
- Gate: lint errors=0; the changed scripts have no GDScript warning with every default warning
  set to error (Backlog lists the four that remain elsewhere). `tools/bench.sh 5 2 900 300`,
  this tree / parent, back to back: frame mean 1.559 / 1.529 ms (+2 %), p99 3.49 / 3.15 ms
  (+11 %; the five runs span 2.88-4.45 against 2.87-3.50 ms), CPU 3.65 / 3.63 s. Two 2-run
  rounds before it gave mean 1.663 / 1.595 and 1.647 / 1.629 ms and p99 4.16 / 3.92 and
  4.33 / 3.53 ms (+6 % and +23 %): with two runs the p99 moves by more than 15 % between runs of
  one tree (machine load 4.7), and no code that runs per frame in a match changed (the start
  level's loop moved into the stats component and runs once per hero spawn; the `build_*`
  statics and `effect_text` run only in the menus).
- Muted renders looked at (`impl_previews/fix_F4_*.png`): a locked capstone's sheet in English
  and German with the wrapped Next line, the rule and the reason over LOCKED / GESPERRT; the
  equipped and the owned-but-not-equipped capstone; Irelia's overview before and after buying
  ranks and Grount's with Titan Form; River's and (German) Irelia's ability tiles; the Ted, Nyxa,
  Gorrak and Hero Base trees.

### 2026-11-11 — fix batch F3: match speed (a faster round and a speed button)
Third fix batch after the walkthrough (`walk_match`: "the fight is a short burst after about 7
minutes of farming, with no speed control"), widened by the user's request of 2026-11-11 for a
slightly faster round. Presentational for the sims: a headless run keeps game time, and the
determinism traces of all three monsters are byte-identical to `tools/baselines` (Gorrak 2,774,
Grount 2,503 and Nyxa 3,252 lines; one seed per `MONSTER=all tools/sim_trace.sh "<seed>" "heroes
monster"` call, two sims in parallel, joined in the baselines' order).

- **Base speed**: `GameManager.MATCH_BASE_SPEED` = 1.2 game seconds per real second while a match
  runs, one constant (README "Match Speed"; `test_readme_spec` checks its table).
  `GameManager._sync_time_scale()` is the only writer of `Engine.time_scale`: `match_speed()`
  while a match runs unpaused, 1 for a paused tree (the pause menu, the result screen), a
  decided match (the death beat), a left World (`abort_match`) and the menus. It runs at match
  start, end and abort, on a button press and once per frame (a pause has no signal).
- **Speed button**: `%Speed` in `MatchHud.tscn`, right of Pause (the clock, the enemy tracker and
  the kills chip moved 68 px to the right; the bar still fits 720 px), wired
  scene-side to `_on_speed_pressed` → `GameManager.set_match_fast()`. Fast is the base x
  `MATCH_FAST_FACTOR` (2): 2.4. It shows one arrow (`ui_play`, `ButtonRound`) or two
  (`ui_fast_forward`, `ButtonRoundPrimary`), is 62x64 px, has the tooltip "Match speed" /
  "Spieltempo" and saves the choice (setting `match_fast`).
- **In step**: `Engine.time_scale` scales every delta, timer, tween, animation and particle, so
  cooldowns, HUD numbers, toasts and effects speed up with the match. Rendered at 30 fps with the
  HUD's slots compared with the real cooldowns every frame at both speeds: 7,912 checks, 0
  mismatches. The clock advanced 1.1998 game seconds per real second at the normal speed and
  2.4000 on fast, 0 while paused; `match_ended`, the death beat and the result screen saw 1.0.
- **Readable**: a toast's hold is `maxf(2.2, 1.2 x Engine.time_scale)` game seconds
  (`TOAST_MIN_REAL_HOLD`): on fast it was up 44 frames at 30 fps (1.47 s, 1.27 s at full alpha;
  2.2 game seconds would be 1.17 and 0.98 s). The first-match tips wait for a tap.
- **First-match tip**: the Speed button is in the `tutorial_pause` group, so the second tip
  frames both buttons: "Pause and speed" / "Pause und Tempo" ("The arrow button next to it
  speeds the hunt up."). Two lines in English, three in German.
- **Headless**: `GameManager.speed_scaling` is false when the display server is headless, so the
  sims, the trace and the tests play as before. `tools/bench.sh` takes a seventh argument
  `speed` (0 game time, 1 the base speed, 2 fast) and prints the `time_scale`.
- **F3 overlay**: "Speed x2.40  base 1.20  fast".
- The clock's hitch cap (`MAX_CLOCK_STEP`, 0.25 s) is real time now (x `Engine.time_scale`), so
  a slow frame on fast does not lose clock time.
- Tests: 610 → 618. `test_match_speed.gd` (the two speeds, a headless match's game time, the
  scale and the clock through start, fast, pause, resume and abort, the decided match hearing
  1.0 at `match_ended`, the button's looks, place, size, tooltip and saved choice with the pause
  menu and a left World, a toast's real hold on fast, the German strings),
  `test_readme_spec` (the speed table), `test_tutorial` (the tip's group).
- Gate: lint errors=0; `tools/bench.sh 3 2 900 300` parent / this tree at game time, back to
  back, twice: frame mean 1.532 / 1.568 and 1.502 / 1.616 ms, p99 3.35 / 3.31 and 3.40 / 3.56 ms.
  With the speed on (`... 0 0 <speed>`): game time 1.613 ms (p99 3.86), normal 1.829 (4.47),
  fast 3.341 (6.42); with every rig awake (`... 0 1 <speed>`) 2.111 (5.08), 2.418 (5.61) and
  3.945 ms (7.79). Fast costs about twice a frame at game time and stays well inside a 16.7 ms
  frame on this Mac; that is not enough room to add a third step before a device run (see
  Decisions). A first bench round ran into a machine at load 25-32 and was thrown away.
- Muted renders looked at (`impl_previews/fix_F3_*.png`): the heroes' HUD at the normal speed
  (one white arrow right of Pause), on fast with a toast (two arrows on the amber button), the
  monster side's bar, the pause menu over a fast match, the F3 line, the result screen, and the
  second first-match tip in English and German framing both buttons.

### 2026-11-11 — fix batch F2: fight readability
Second fix batch after the walkthrough (`walk_match`, made on `d5798bd`). Presentational: the
determinism traces of all three monsters are byte-identical to `tools/baselines`, plain and with
every rig awake (Gorrak 2,774, Grount 2,503 and Nyxa 3,252 lines each time; one seed per
`MONSTER=all [RIGS_AWAKE=1] tools/sim_trace.sh "<seed>" "heroes monster"` call, two sims in
parallel, joined in the baselines' order).

- **Hurt flash** (medium): `CharacterRig` starts a hurt reaction (flash, squash, hurt move) at
  most once every `hurt_flash_interval` (0.45 s); it used to restart the 0.18 s flash on every
  hit, and hits land every 0.15-0.2 s in a five-attacker fight. The monsters' `hurt_flash_gain`
  is 1.55 (a 55 % white mix at the peak, scene-side on `monster_base_class.tscn`). Rendered
  Stage III fights, logged per frame: Grount is flashing in 66 of 200 frames and above a 35 %
  mix in 18 (9 %), never a white silhouette (34 hits); Gorrak 33 and 9 of 135 frames (25 hits).
  The walkthrough saw a white or whitish Grount in 6 of 9 samples; now 2 of 9 show the soft
  flash with the art readable.
- **Cast facing** (low): a cast at a target sets the rig's side from target.x - caster.x and
  holds it for 0.3 s (`_face_target`). 29 casts with a target clearly to one side checked in the
  renders 4 frames later: none faced away (the walkthrough: 8 of 457).
- **Cleave crescent** (low): Front Cleave, Cleaver Chop and Whirlwind's slashes sit outside the
  caster's drawn body (`AbilityVfx._body_edge`: `CharacterRig.half_width_of` to the sides and
  downward, the way up to the head top when the swing points up, plus 10 % of the reach). Stage I
  keeps its spot at half the reach; at Stage III it is 58 px out instead of 40.
- **Draw order** (medium, presentational part): `World.tscn` y-sorts its characters. The root and
  the holders `Spawns`, `Heros` and `MonsterSlot` are y-sorted Node2Ds at the origin (the holders
  were plain Nodes: tree order, the monster over everybody). `SpawnManager` and `MonsterSlot`
  extend Node2D. No position or gameplay value changed (stand-off distances are batch G1).
- **Stacked HP bars and pills** (medium): the `Hud` node is an `EntityHud`
  (`Scripts/entity_hud.gd`) at z 1, above every body. Huds of heroes and the monster rise above
  the ones they would overlap, a row at a time; the monster's bar ranks first and never moves.
- **Damage numbers** (medium): a new number takes the next free column, then the row above,
  when a live number of any target started on its spot less than 0.5 s ago
  (`VfxManager._free_spot`).
- **Death beat** (low): a FULL rig on screen leaves its dying entity (`died`, wired in
  `NPCBaseClass.tscn` and `TedsPet.tscn`), pops up, falls backwards, fades and frees itself after
  0.8 s; the entity is freed as before. `GameManager` settles the match at the deciding death
  (outcome, clock, rewards, save, `match_ended`) and shows the result screen
  `DEATH_BEAT_SEC` = 0.95 s of game time later (rendered: 29 frames at 30 fps after the monster's
  death and after the last hero's). A timeout shows it at once; a match that is gone by then
  shows nothing.
- **Trap Cage** (low): `_process` and `_expire()` skip a trapped enemy that was freed inside the
  cage (the monster; mobs are parked). The freed monster used to be passed on as a Node2D
  argument: a script error, and the cage never faded or freed itself.
- Tests: 600 → 610. `test_fight_readability.gd` (flash share and peak under fire for a hero and
  the monster, cast facing with a carrier pointing up, the crescent at Stage I and III and aimed
  up and down, hud stacking and its rank, number spots for eight targets on one point, the
  World's y-sort, the corpse of a hero, the monster and the fox, none for a mob or off screen),
  `test_match_result` (the result screen waits for the beat, is dropped after `abort_match`, a
  timeout has none) and `test_hero_actives` (a caged monster dies and is freed; run against the
  parent's `trap_cage.gd` it fails with the walkthrough's script error).
- Gate: lint errors=0; `tools/bench.sh 3 2 900 300` parent / this tree, back to back, twice:
  frame mean 1.626 / 1.648 and 1.640 / 1.627 ms, p99 3.27 / 3.55 and 4.29 / 4.00 ms; with every
  rig awake (`... 0 1`) 2.183 / 2.002 and 2.163 / 2.105 ms, p99 4.88 / 4.49 and 4.65 / 4.65 ms.
  Five earlier rounds on a machine at load 8-12 were noise (the parent between 2.0 and 8.2 ms
  with the rigs awake). A headless run draws nothing, so the y-sort and the huds cost nothing
  there; an awake rig pays three comparisons a frame.
- Muted renders looked at (`impl_previews/fix_F2_*.png`): nine samples of a Stage III Grount
  fight half a second apart (the monster readable in all nine, a hero in front of his feet drawn
  in front, the bars in rows, the crescent beside and above him); the monster's death (white pop,
  fall, fade, then the result screen); all four heroes dying against a Stage III Gorrak (the
  corpses tip over and fade, DEFEAT follows).

### 2026-11-11 — fix batch F1: minimap, toasts, dead-hero slots and the monster-side view
First fix batch after the walkthrough of the overhaul (`walk_match`, made on `d5798bd`).
Presentational: the determinism traces of all three monsters are byte-identical to
`tools/baselines` (Gorrak 2,774, Grount 2,503 and Nyxa 3,252 lines; run one seed per
`MONSTER=all tools/sim_trace.sh "<seed>" "heroes monster"` call, two sims in parallel, and
joined in the baselines' order).

- **Minimap dots and camera frame** (high): the Control draws them in `_draw()` and its child
  `%FogView` (95 % opaque) painted over them. `%Frame` and `%FogView` now have
  `show_behind_parent` (Minimap.tscn). Rendered check: the pixel at a hero's map position is the
  dot's `#e39a3b` (it was `#567c3a`, the fog picture).
- **Minimap picture** (high): `%FogView` tiled the 235 x 188 texel exploration texture 1:1, so the
  152 x 120 view showed only the top-left 41 % of the world and nothing lined up with the dots.
  It scales now (the `stretch_mode = 1` line is gone). `Minimap.map_rect()` (FogView's rect, 2 px
  inside the Control) is the one mapping of dots, camera frame, taps and picture.
- **Ultimate toasts** (medium): `MatchAnnouncer.player_sees()`: the played side's casts always, an
  enemy's only inside the camera view on ground the player's fog has cleared
  (`FogOfWarSystem.is_revealed`, new). The toast names the caster ("VLAD · BLOOD BOMB",
  "VLAD · BLUTBOMBE"), and `ultimate_repeat_guard` is 60 s (was 12 s). See Decisions.
- **Dead hero's slots** (low): `AbilitySlot.set_dead()`: icon greyed, no sweep, no number, no
  glow, a pop cut, final. A bound slot goes dead when its source's entity is freed (it used to
  stop polling and keep "6" under the skull); `HeroHudCard` and `MonsterHudPanel` call it too.
- **Monster side** (low): `World._ready` switches the heroes' `reveals_display` off before any
  VisionArea processed a frame (it waited for the monster's placement, so their spawn showed on
  the minimap); the clear colour is `bg_void` (project.godot) instead of the engine's grey; the
  Deko layer's flowers and rocks outside the ground are gone (see Decisions).
- **Monster panel slots** (coverage gap): 56 / 68 / 68 / 72 px (were 44 / 56 / 56 / 62) across
  the width between the portrait and the tally.
- **F3 time left** (coverage gap): `CooldownSource.debug_state()` ("left 2.31 s", "ready",
  "locked II"); the overlay prints one line per ability of every monster and of the followed
  hero ("Emergency Supply Drop  cd 25.00 s  left 19.27 s" next to a slot showing 20).
- Tests: 589 → 600 (minimap draw order, world coverage and a rendered pixel test that the
  headless runner skips and a windowed run of `test_minimap.gd` executes: it fails on the parent's
  scene at the hero's dot and at a far-corner reveal; the heroes' reveals on the monster side;
  the clear colour; decorations on ground; which ultimates are announced on either side; the dead
  slot, also on a fallen hero's card; the monster panel's slot row; the F3 lines).
- Gate: lint errors=0; `tools/bench.sh 2 2 900 300` parent / this tree, back to back, twice:
  frame mean 1.546 / 1.595 and 1.531 / 1.525 ms, p99 3.309 / 3.514 and 3.523 / 3.201 ms (noise;
  no rig or VFX code changed, so no rigs-awake runs).
- Muted renders looked at: heroes vs Grount (hero dots, the monster's dot while a hero sees it,
  the camera frame, "IRELIA · MONSTER TAUNT", "GROUNT · GROUND SLAM" with the monster in view, a
  fallen hero's greyed slots, F3) and the monster side as Grount seed 4 and as Gorrak in German
  (the near-black void at the map's edge, no hero-spawn patch on the minimap, no toast for the
  heroes' unseen ultimates, the slot row).

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
