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
- **Visual Changes**: Grount's rig grows with the stage scale (1.0 / 1.25 / 1.5) and shows each
  stage's parts: bigger horns and orange eyes plus back spikes (Stage 2); huge horns, red eyes,
  glowing cracks and a chain (Stage 3); a flash and a ring pulse mark the evolution
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
    - `Kit/` (65): card frames and inner panels (hero / monster / selected /
      locked), carved-wood nav plaques and the mossy-stone HUNT arch, buttons
      (primary, secondary, copper, hero, monster, round) with hover / pressed
      art, panels and banners, ability slot frames (basic, active, passive,
      ult, locked), skill-tree nodes (`node_minor` ring, `node_major` leafy
      capstone frame, and their white `_tint` versions that the theme tints
      per state), toggles, padlock, notification dot, leaf and vine
      ornaments, the background tile. 9-slice margins live in `kit.MARGINS`.
    - `Icons/` (78, 64x64): `Abilities/` (27, `<owner>_<slot>_<ability>`:
      a full-bleed tile in the owner's tone that the slot frame sits on;
      every hero and Grount ability, River's two basic modes, and Nyxa's and
      Gorrak's abilities on the `monster2` / `monster3` tiles), `Currency/`
      (gold, steel, leaves, upgrade point), `Stats/` (16), `Roles/` (9 filter
      silhouettes), `Nav/` (6) and `UI/` (16 glyphs).
    - Every ability `.tres` (the 16 hero abilities and Grount's three) sets
      its `icon` to its tile; no ability shows the old `Icon.jpg`
      placeholder. River's basic attack also has `heal_icon`
      (`river_basic_heal`) next to `icon` (`river_basic_sniper`).
      `test/test_ability_icons.gd` checks the resource-to-icon table, the
      DPITexture imports and River's weapon-mode swap.
    - `Crests/`: the hero and monster side crests.
    - `Shaders/ability_cooldown.gdshader` (clockwise cooldown sweep with an
      amber edge, `ready_flash`, `locked`) and `card_locked.gdshader` (locked
      character silhouette). Their default colours come from the palette.
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
    - **Screen variations** for the Phase 3-5 screens: skill-tree nodes
      NodeLocked / NodeAvailable / NodeOwned / NodeMaxed (the `node_minor`
      ring: locked_line, copper, moss_light, rank_max) and capstones
      CapLocked / CapAvailable / CapOwned (the `node_major` frame), rank pips
      PipOn / PipOff / PipMax, SelectRing, GateChip, BranchPlaque, SheetPanel,
      ChipPanel, FrameHero / FrameMonster (border only), EvoBar, TabButton,
      FlatButton, BigNumberLabel, HintLabel and AmberLabel.
    - **Art names are canonical**: the UX prototype's theme is not shipped,
      and its names for looks the art set has are renamed (CardPanel →
      CharacterCard, PrimaryButton → ButtonPrimary, MossButton → ButtonHero,
      HudCard → HudPanel, TitleLabel → HeaderLarge, MutedLabel → Caption, ...;
      the full table is in `make_theme.py`).
    - The old screens (main menu, pre-round, skill screen, match result,
      settings, tutorial) restyle through it until Phases 3-8 replace them;
      their own overrides still win. The HUD hero panels use HudPanel and
      HpBarHero.
    - `test/test_theme_contract.gd`: the project setting points at the theme,
      every `theme_type_variation` a scene or script under `Scenes/` and
      `Scripts/` names exists, every StyleBoxTexture and icon resolves to a
      DPITexture, display types use Lilita One over `font_body` and body
      types `font_body`, every glyph of `strings.csv` (English and German)
      renders in the display font, the screen variations exist with their
      base types and state colours, and no UX name is back.
- **Proof scenes** (`tools/preview/`, not shipped; any export preset must
  exclude `tools/*`): `ThemeMockup.tscn` composes every theme type and kit
  piece the way the collection and HUD screens will (role glyphs in the
  signature colours stand in for the character portraits until the rigs
  land); `ThemeScreens.tscn` shows the screen variations (skill-tree nodes
  and capstones in every state, pips, tabs, gate chip, bottom sheet, side
  frames); `PaletteSheet.tscn` shows every UiPalette token. Render them muted
  on a copy of the project:
  `godot --path <copy> --audio-driver Dummy --fixed-fps 30 --write-movie <dir>/f.png --quit-after 8 res://tools/preview/ThemeMockup.tscn`.

### Character Rigs (SVG cut-out runtime)

Characters are moving from the pixel `AnimatedSprite2D` frames to chunky chibi
SVG cut-out rigs. The runtime, the builder and the art of all ten characters
are in place. Every character in the match draws its rig: the four heroes,
Ted's fox, Grount (all three stages) and the Bat and Hog mobs. Gorrak and
Nyxa have their art but no scene yet.

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
  | grount | monster (3 stages: horns, eyes, spikes, cracks, chain) | 16 | QUADRUPED | 0.6 | 3 | 60, 24.3 |
  | gorrak | monster | 7 | QUADRUPED | 0.6 | 3 | 56, 25.1 |
  | nyxa | monster | 6 | FLYER | 0.6 | 3 | 85 (no legs) |
  | hog | mob | 5 | QUADRUPED | 0.38 | 2 | 70, 19.1 |
  | bat | mob | 4 | FLYER | 0.32 | 2 | 150 (no legs) |
  | pet | Ted's fox | 5 | QUADRUPED | 0.3 | 2 | 120, 20.1 |

  The small ones' sheets rasterise at 2 px per art unit (VRAM); the rest at 3,
  which stays crisp up to about camera zoom x7.5 for heroes. `full_speed` is
  the character's move speed (stage 1 for monsters), so its usual walk swings
  the legs fully, and `stride` = 4 x leg (hip pivot to sole) x
  sin(`leg_swing`) x `world_scale`, so a planted foot does not slide.
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
- **`RigProfile`** (`<id>_motion.tres`, shared): body plan (HUMANOID,
  QUADRUPED, FLYER), `world_scale`, idle breathing, locomotion (`full_speed`,
  `stride` so feet never slide, bounce, swings, lean), flyer flaps and hover,
  hurt and attack reactions.
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
      attack / cast / ultimate move, `EntityBase.damaged(packet)` the hurt
      flash and squash, `MonsterBase.evolved(stage)` → `Rig.set_stage` the
      stage's parts.
    - Hit flash: the rig drives the body's modulate over 1 (palette white x
      `hurt_flash_gain`, easing back to white). Every generated body draws
      through ONE shared material, `Assets/Shaders/hit_flash_material.tres`
      (`hit_flash.gdshader`) on the body root, every node under it
      `use_parent_material` (written by `tools/rig_builder.gd`): the shader
      reads a modulate of (1 + f) on all three channels as a flash of f and
      mixes the art toward white, a white silhouette instead of a brightened
      one, while ordinary tints (a shield's blue, a rally's orange) pass
      through. One shared material keeps a character in one draw and a
      species' mobs batched together.
    - `EntityBase.visual_root()` is what effects move or tint (Ground Slam's
      hop): the rig once the scene has a body, else the AnimatedSprite2D.
    - LOD: a rig animates only while its entity's ScreenNotifier is on screen.
      While more than 48 rigs are awake, mob rigs (tier BUDGETED) animate
      every other frame, staggered; heroes and the monster use tier FULL.
      A rig writes only the pose channels that changed since its last frame
      (an idle mob mostly breathes), and forgets them after an authored move
      or `reset_pose`. The F3 overlay shows the rigs awake now, their mean
      since F3 was pressed and "mobs half rate" while over the budget.
    - Pooled mobs leave the tree and come back without a new `_ready`: a rig
      leaving the tree sleeps and drops its hurt flash, attack swing and
      walk, so the next life starts clean; on re-entry the notifier wakes it
      (or, under the tools' `force_awake`, the rig itself).
    - Contact shadow: every Rig's first child is a `Shadow` Sprite2D
      (NPCBaseClass.tscn, and TedsPet.tscn; wired to `shadow` scene-side)
      holding `Assets/Characters/shadow_blob.svg`, a white 128x48 ellipse with
      a dense core and a soft rim (CompressedTexture2D with mipmaps, drawn
      LINEAR_WITH_MIPMAPS like the rig art). `_ready` tints it with the
      palette's `ink` at `shadow_alpha` (0.55) and sizes it once to
      2 x `shadow_radius` x `SHADOW_SPREAD` (1.5) world px: radius 14 for the
      heroes and the Hog, 24 for Grount, 10 for the fox, 9 for the Bat. Being
      drawn first, it sits under the body; it stays on the ground at the feet
      while the body bounces or a flyer hovers, and it is hidden while the rig
      is inert. It is not the hurt flash's target (that is the body).
    - Evolution (`set_stage`): the stage's parts, and on screen the
      evolution flash (an evolution off screen leaves no flash pending). The
      stage SIZE stays the monster's root scale (gameplay: collision and
      aggro shapes grow with it), which the rig inherits; the old sprite path
      (stage SpriteFrames from `MonsterVisualConfig`, orange/red tint) only
      runs for a monster scene without a rig body. The stage ring pulse
      (`enable_stage_effects`) plays either way.
- **Migrated scenes** (Irelia, Vlad, Ted, River, `TedsPet.tscn`, Grount, Bat
  and Hog): the `AnimatedSprite2D` is hidden and its dead SpriteFrames
  deleted; the hidden facing `Sprite2D` stays as it was (gameplay keeps
  rotating it); the `Rig` sets `body` (through the scene's `node_paths`, so
  the export resolves at instantiation), `profile` and `tier` (FULL for the
  heroes, the fox and Grount; the mobs keep the default BUDGETED), with
  `<Id>Body` (the instanced `<id>_body.tscn`) under it. No existing node is
  reordered and World.tscn's node order and y-sort are untouched (it only
  gained the ground grade, see Ground Style), so the match and its trace are
  unchanged. Grount keeps `grount_visual.tres` for its stage ring pulse.
    - The rig's origin is the character's feet at the entity's position (the
      old sprites were centred on it), so the entity's y-sort now orders by
      the feet.
    - The HP bar's bottom edge sits 6 px above the art: at
      -(round(h x `world_scale`) + 6), where h is `RigBody.art_height()` for
      a walker and, for a flyer (its art floats above its feet), the art's
      top plus its highest hover (1.35 x `hover`). Heroes move their `Hud` to
      y = -68 (Irelia), -64 (Vlad), -59 (Ted) and -70 (River); the fox's bar
      (an HpBar2D like every entity's, 20x4) sits at -44..-40; Grount's
      `Hud` is at -101, the Hog's at -45 and the Bat's at -48. Each clears
      the character's tallest pose (largest size, breathing in, top of the
      walk bounce or hover). Grount's `Hud` is a
      child of the growing root: its position grows with the stage scale
      while the bar keeps its pixel size, so it clears the head at every
      stage and with Titan Form.
    - The ScreenNotifier rect must enclose everything the rig can draw
      (`bounds` x `world_scale` at either facing, the size spread, breathing,
      hurt squash and bounce or hover). NPCBaseClass's rect already does for
      the heroes and the mobs. Grount's is sized from its bounds:
      Rect2(-58, -114, 116, 118) also covers Ground Slam's 1.2x hop of the
      rig, and it grows with the stage scale like the rig.
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
  rule).
  `test/test_character_art.gd` checks the real art: the ten characters, their
  sheets' svg/scale and mipmaps, DPITexture portraits, body plans, world
  scales and the no-slide stride. `test/test_rigged_scenes.gd` checks the
  migrated scenes: their own body, profile and tier, the hidden sprite without
  frames, the HP bar rule (at every Grount stage), the notifier covering the
  drawn body, the ink contact shadow (wiring, tint, size, under the body, on
  the ground while the bat hovers), real heroes, the fox, Grount and the mobs
  walking (the bat flapping), facing and flinching in a match (the fox
  through `mover`), Grount's parts and flash through stages 1 to 3, the mob half rate over the
  budget, a pooled mob's rig starting its next life clean, and the F3 line. `RIGS_AWAKE=1 tools/sim_trace.sh`
  animates every rig and must match the parent trace byte for byte;
  `tools/bench.sh <runs> <mult> <frames> <warmup> <onscreen> 1` wakes every
  rig and reports `rigs_awake_mean`. `tools/preview/RigGallery.tscn` shows
  three large puppets, then every character in idle / walk / run / attack /
  hurt / stage 2 poses, all rows at one scale so the world sizes compare.

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

- **Grid**: 2000x2000 overlay on 32px tilemap
- **Reveal Radius**: 200-300 units (hero-dependent)
- **Persistence**: Once revealed, stays visible
- **Rendering**: World-space Node2D (not screen-space)
- **Purpose**: Strategic scouting value, monster can hide

### Hero UI Container

- **Position**: Bottom of screen, fixed to camera
- **Layout**: 4 hero panels (River, Vlad, Ted, Irelia), each a `HudPanel`
  (dark, copper border) with an `HpBarHero` health bar (10 px)
- **Per Panel**:
    - Hero name label
    - Portrait (60x60)
    - Health bar (color-coded: >50% green, >25% yellow, <25% red)
    - 4 ability icons (30x30, dimmed during cooldown). Each slot shows
      `get_display_icon(hero)` and refreshes on the AbilitySystem's
      `ability_used`, so River's basic-attack slot swaps between the rifle
      and the heal staff with her weapon mode.
- **Real-time Updates**: Health changes, cooldown tracking

### Combat Visuals (VfxManager)

`VfxManager` (`Scripts/Vfx/vfx_manager.gd`) is the match's hit feedback: a
`Vfx` node of `World.tscn` in group `vfx` (not an autoload, so it lives and
dies with the match; `camera` wired to `MainCam` scene-side). Its only hook is
`EventBus.damage_applied`, connected in `_ready` (an autoload cannot be the
source of a scene `[connection]`). For every packet that lands in the camera
view (grown by 64 px):

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
- **Kill**: on a killing blow, 4 puffs (`fx_puff.svg`) and a star.
- **Hit flash**: the CharacterRig's hurt reaction rendered white by the
  shared hit flash shader (see Character Rigs). VfxManager does not flash.
- **Screen shake**: camera trauma (`GameCamera.add_trauma`): 0.6 when the
  monster goes down, 0.35 for a hero, 0.12 for a big hit on a hero or the
  monster. Trauma is capped at 0.8, decays 1.8/s, and the offset is
  9 px x trauma², so only big moments move the view. Settings → Display →
  "Screen shake" (`screen_shake`, on by default) and the camera's
  `shake_enabled` export gate it; the offset uses the camera's private RNG.
- **Ground telegraph**: `telegraph(pos, radius, windup, color)` shows where a
  wound-up hit will land: a pooled `RingPulse` outline at the radius and a
  ring growing from the centre that reaches it as the hit lands, both at 35%
  alpha and 2 px wide at any radius. The rings are children of the Vfx node
  at absolute z 0; the node sits right after the ground layers, so they draw
  on the ground under the characters, while its sprites and numbers draw at
  z 50 (above the characters and ability trails, under the fog at 100). The
  monster abilities call it from Phase 7.

Budget (the anim prototype measured 23 ms frames at p95): fixed pools of 64
sprites (`FxSpriteBuffer`), 32 numbers and 4 telegraphs, where a full pool
recycles its oldest entry; at most 8 hits a frame spawn sprites (the rest still
count in the numbers) and 2 kills a frame spawn puffs; nothing is allocated
per frame. Every random draw uses its private RNG and it never writes gameplay
state, so `tools/sim_trace.sh` stays byte-identical. The F3 overlay shows the
pools against their caps, the hits shown / culled / over budget and the
node's script time. `EventBus.ability_event` (names in `FxEvents`) is the
presentation channel for moments inside an ability; its emits and the
per-ability effects (`AbilityFxRecipe`) land in Phase 7.

Planned: per-ability effects (slashes, explosions, heals), evolution
transformation effects, death animations.

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
- **AbilityBase** (Resource): Ability data and execute logic. `icon` is the
  ability's SVG tile; `get_display_icon(caster = null)` is what a HUD slot
  shows (read-only; RiverBasicAttack returns `heal_icon` while River holds the
  heal staff, every other ability its `icon`)

### Character Roster (Roster, CharacterDef, MonsterSlot)

One registry describes every playable character for the menus, the match, the
sim tools and the save, without instancing a character scene (instancing an
entity registers it and draws from the global RNG).

- **`Scenes/NPCs/roster.tres`** (`Roster`, `Scripts/Roster/roster.gd`) lists
  the heroes (Irelia, Vlad, Ted, River) and the monsters (Grount) in menu
  order, plus `default_monster_id` (`grount`). GameManager preloads it as
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
  - monsters: `stage_names` (Grount: Bullcalf, Rampager, Alpha Bull),
    `opponent_after_matches` (Heroes-side quarry pool), `unlock_requires_level`,
    and `tip`, the counterplay hint for the heroes.
  - progression: `unlocked_by_default`, `unlock_cost` (in `currency()`: Steel for
    heroes, Leaves for monsters) and `skill_tree` (null while the trees are
    seeded in code; `skill_tree_def()` then asks MetaSkillManager).
  - abilities are never copied: `abilities()` reads the scene's own ability
    `.tres` from its SceneState, in menu order (passive, basic, active,
    ultimate; monsters passive, ability_1..3). Icons, names and descriptions
    come from there. `ability_slots()` keeps the four slots with null for an
    empty one (Grount has no passive resource), so screens caption each by
    its slot.
- **`Scenes/World/monster_slot.gd`** (`MonsterSlot`) stands where World.tscn
  used to instance Grount, as World's last child after `Heros`. It spawns
  `resolve_monster(GameManager.selected_monster_id)` in `_enter_tree`, so the
  monster registers with EntityRegistry and TickScheduler (one global `randf()`)
  at exactly the old point of the enter pass, before `Spawns._ready` shuffles the
  camps. Spawning it from `World._ready` would change every match.
  `test_roster` guards the index and the enter-pass spawn.
- **Selection**: `GameManager.select_monster(id, persist = true)` (persisted as
  the `selected_monster` setting) and `selected_monster_def()`. The old main
  menu's monster tree button and level row follow the selection. The
  `match_ended` analytics event carries `monster`.
- **Tools**: `MONSTER=<id> tools/sim.sh ...` and `MONSTER=<id> tools/sim_trace.sh ...`
  (`sim_match.gd ... monster=<id>`). Without it the roster default plays, so the
  determinism baseline is unchanged. The SIM_RESULT JSON gains `monster` and
  `monster_name`, and `sim_summary.py` prints the monster.
- **Adding a monster**: a scene inheriting `monster_base_class.tscn` with its own
  MonsterStats (`monster_id`), ability `.tres` and strategy; its
  `Assets/Characters/<id>/` rig (`src/` + `tools/build_rigs.sh`); a
  `<id>_def.tres` added to `roster.tres`; and its `monster_<id>` skill tree.

### Menu Component Kit (cards, rigs, top bar, nav bar)

The building blocks of the Phase 3 menu screens (lobby, roster, character
detail). They read the roster and the save, never write them, and take every
colour from the theme or `UiPalette`. Signals are wired scene-side; the only
code connections are to autoloads (`PersistedData.currency_changed`).

- **`CharacterProgress`** (`Scripts/Progression/character_progress.gd`, static
  helpers over a `CharacterDef`): `xp`, `progress` / `level` / `xp_into` /
  `xp_needed` on the one XP curve of `PersistedData.level_progress` (levels
  come from XP alone, nothing buys them), `upgrades_ready` (nodes of the
  character's own tree that `MetaSkillManager` reports AVAILABLE: tier open and
  affordable now) and `is_unlocked` (`unlocked_by_default` until the monster
  unlock flow adds bought characters).
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
      `unlock_cost` > 0;
    - `rumour`: the one "???" slot each side ends with ("Rumours in the deep
      jungle", no character).
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
  Locked characters stand as a silhouette under a padlock.
  `character_pressed(character)`.
- **`TopBar.tscn`**: a round left button (`left_icon`, `left_pressed`), the
  title, and the `CurrencyChip`s the screen's side shows (`show_gold`,
  `show_steel`, `show_leaves`; `chip(currency)`).
- **`CurrencyChip.tscn`**: currency icon and amount ("1,840",
  `format_amount`), live from `PersistedData.currency_changed` with a pop;
  `preview_amount` pins a sample.
- **`NavBar.tscn`**: Heroes | Growth | HUNT | Codex | Monsters. Carved
  `NavPlaque` plaques (`NavTab.tscn`) and the mossy-stone `NavArch`
  (`NavArch.tscn`, the lobby), toggle buttons in one ButtonGroup per bar.
  `active_tab`, `tab_selected(tab_id)`, `notify_tabs` / `set_notify()` (red
  dots) and `monster_side`: the arch's additive glow is `amber` on the hero
  side and `monster` crimson on the monster side, pulsing through the scene's
  AnimationPlayer.
- **Press feedback** (`PressFeedback`): cards, stage characters, ability tiles
  and nav tabs shrink to 0.95 while held and spring back with a 0.09 s
  TRANS_BACK tween.
- **`StatTile.tscn`**: a stat icon, a value in display type and a caption
  (`PanelInset`; `show_stat(icon, value, caption)`).
- **`AbilityTile.tscn`**: one ability (kind caption, the `.tres` icon, its
  name), a toggle button; the toggled tile wears `CharacterCardSelected` and
  reports `tile_pressed(index)`.
- **`SkillNodeButton.tscn`**: one skill-tree node: an 84 px `Node*` ring
  (`Cap*` square frame for a capstone) around its icon, rank pips (`PipOn` /
  `PipOff` / `PipMax`), a padlock while LOCKED, a star once MAXED, the red
  notify dot (pulsing) while its next rank can be bought, the white
  `SelectRing` and `pop()` (purchase juice, 1.25 → 1 with TRANS_BACK).
  Locked icons are dimmed to `UiPalette.LOCKED_ICON_MODULATE`.
- **`SkillTreeView.tscn`**: a `UxTreeModel` as a node graph: one column per
  branch (a `BranchPlaque` when it is named), one row per tier, a dashed rule
  with a `GateChip` ("Tier 2", padlocked while closed) between the rows, and
  requirement links (ink casing, amber core once the parent is owned, stone
  before). Without named branches every row is centred; rows share the height
  (110-156 px) and the graph is centred vertically, re-laid out on resize.
  `build(model)` keeps the selection; `select(id)` reports `node_selected`.
- `test/test_character_card.gd` covers the progress numbers, the card states
  (normal, upgrade-ready, locked-purchasable, rumour, monster, selected) with
  their pill text and variations, the size presets, the RigView fit, flip and
  silhouette, the stage idle and cheer, the global RNG left untouched, the nav
  bar's group and notify API, and the chips. `tools/preview/CardGrid.tscn`
  renders the grid and nav (default page) and the L / S cards and stage
  characters (`-- --page=sizes`) from sample numbers, never the save.

### Menu Root and Lobby (the main scene)

The game boots into `Scenes/UI/Screens/MenuRoot.tscn` (`application/run/main_scene`).
The old `MainMenu.tscn` stays reachable from the match result's Main Menu
button until the Phase 8 screens retire it.

- **`MenuRoot`** (`menu_root.gd`): every meta screen is a hidden child of
  `%Screens`, and every screen signal is connected in `MenuRoot.tscn`. The
  script only moves between screens and holds the hooks a scene connection
  cannot reach (autoloads cannot be `[connection]` targets):
    - `push(screen)` slides the new screen in from the right edge over 0.22 s
      (cubic ease-out) while the one below darkens to
      `UiPalette.COVERED_SCREEN_MODULATE` (0.6); `pop()` plays it backwards, and
      once a slide settles only the top screen is visible. `ui_cancel` is back on
      every screen; the home screen (the lobby) never pops.
    - On entry: the tree is unpaused (a match result pauses it), the menu
      music plays, `GameManager.request_world_load()` starts loading the match in
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
      detail is pushed over the screen that asked. Locked characters (the
      lair's teasers) open nothing yet.
    - Purchases: a detail's `upgrade_requested(tree_id, node_id)` →
      `MetaSkillManager.unlock` (the shop decides: tier gate, price). On
      `MetaSkillManager.skills_changed` and `PersistedData.currency_changed`
      (connected in code: autoloads) every roster and detail on the stack
      re-reads the save, once per frame at most.
    - Until their new screens land, HUNT opens the old `PreRoundSetup` overlay on
      the hero side (the monster side starts the match at once), Codex the
      tutorial and the gear Settings.
- **`LobbyScreen`** (`lobby_screen.gd`, the nav bar's HUNT tab): a split jungle
  stage under the top bar (gear, Gold, Steel, Leaves) and above the nav bar.
    - Hero stage (y 84-624): the campfire clearing (`Assets/UI/Lobby/lobby_heroes.svg`),
      the "BETTER HUNT" title on a `Banner`, and River, Vlad, Irelia and Ted as
      live `StageCharacter` rigs around the fire, the right pair facing inward.
    - Monster stage (y 616 down to the nav bar): the fanged lair
      (`lobby_monsters.svg`) with Grount large in the middle. Nyxa and Gorrak,
      not playable yet, stand beside him as padlocked silhouettes: scene-local
      locked `CharacterDef`s over their built rigs, outside the roster.
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
    - On a taller or wider phone the stages stretch with the window: the
      backdrops cover their stage, the characters stay centred, and the lair
      grows down to the nav bar.
- `test/test_menu_root.gd`: every screen signal is connected once, scene-side,
  to MenuRoot (no code connections); push / pop and `ui_cancel`; the click on
  every button; the side choice (frames, HUNT pop, cheer stagger, tints, nav
  glow) and `side_tap_opens_roster`; each request; the cast is the roster plus
  the locked teasers; the chosen side persists; the first-run tutorial; the
  screens each request opens (nav tabs switch, cards push, back); a purchase
  through the detail and the refresh of the screens under it; the main scene
  is MenuRoot.

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
  (`character_requested`); a locked card or the rumour shakes. `refresh()`
  re-reads levels, XP and ready upgrades.
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
      empty slot hides its tile) with each `.tres`'s icon and name; the
      ultimate is described first, a tap describes another.
    - SKILL TREE (the tabs, `TabButton`; the tree tab carries an up-arrow
      badge with `CharacterProgress.upgrades_ready`): the stage folds into a
      compact header (head portrait, name, level, XP), the character's tree in
      a `SkillTreeView` and the bottom sheet (`SheetPanel`) of the selected
      node: name, "Rank r/max · Tier t", "Now: …" or "Not learned yet",
      "Next: …", the price (in `danger` when the wallet is short) and UPGRADE
      (`ButtonPrimary`), disabled and showing why when the node cannot be
      bought ("Learn a Tier 1 skill first", "Maxed", "Need 340 more").
    - `show_base_tree(side)`: the Growth tab's account-wide tree (Hero Base or
      Monster Base, Gold) in TREE mode without tabs, under the side's crest
      (`crest_heroes` / `crest_monster` exports, `Assets/UI/Crests`) with the
      tree's name and blurb.
    - UPGRADE only reports `upgrade_requested(tree_id, node_id)`; MenuRoot buys
      and calls `refresh()`, and the bought node pops. Every connection inside
      the screen is in its scene; `back_requested` and `tab_selected` go to
      MenuRoot, and the nav bar keeps the screen's own tab lit.
- **`UxTreeModel`** (`Scenes/UI/Screens/ux_tree_model.gd`): the one thing the
  tree view and the sheet read. Branches (columns, "" = unnamed), tiers with
  `tier_open`, gate chip texts and block reasons, nodes with `rank`,
  `rank_costs`, `rank_texts`, `requires` (any one owned opens a node),
  `capstone` and an icon, plus the currency and the wallet. `state_of()`
  (LOCKED, AVAILABLE, OWNED, MAXED), `block_reason()`, `affordable()`,
  `can_buy()`, `buyable_count()`. `from_meta_skills(tree_id)` maps today's
  trees: one rank per node, column = index inside its tier, the lone node of
  the top tier is the capstone, tier gates read from
  `MetaSkillManager.node_state` (so the screen and the shop never disagree),
  icons from the node, else the stat icon of its stat or ability property
  (`STAT_ICONS`), else the ability's icon. The ranked trees add their own
  adapter with the same fields. A snapshot: rebuilt after every change.
- Strings (OVERVIEW, SKILL TREE, ABILITIES, the slot kinds, stat captions, the
  sheet's texts and block reasons) are in `Assets/Locale/strings.csv` with
  German.
- Tests: `test_ux_tree_model` (states, block reasons, prices on a hand-built
  ranked tree; the live Grount tree; icons; the live states agree with
  `node_state` on every node of every tree, fresh and seeded),
  `test_roster_screen` (grid, rumour, filters, count, intro, taps, refresh,
  wiring), `test_character_detail` (stat rows, overview, level / XP / badge,
  tree mode and sheet, every tree fits 720x1280, Growth, wiring), and
  `test_grount_behaviour_nodes` checks the Grount tree on this screen (every
  node shown, tier 4 gated until a tier-3 node is owned, bought through
  `upgrade_requested`).

### File Structure

```
res://
├─ Assets/
│  ├─ Characters/<id>/ (src/ SVG parts + rig_src.json, generated <id>_sheet.svg
│  │                    and <id>_body.tscn, <id>_motion.tres, <id>.svg portrait,
│  │                    <id>_def.tres CharacterDef for playable characters)
│  ├─ Fonts/ (LilitaOne-Regular.ttf display font + LilitaOne-OFL.txt licence)
│  ├─ Shaders/ (ground_grade; hit_flash + hit_flash_material.tres on every rig body)
│  ├─ Vfx/svg/ (fx_star, fx_spark, fx_puff, fx_digits: in-world effect sprites)
│  └─ UI/ (generated Jungle Guild kit, DPITexture SVGs)
│     ├─ Kit/ · Crests/ · Icons/{Abilities,Currency,Stats,Roles,Nav,UI}/
│     ├─ Lobby/ (the lobby's campfire and lair backdrops, VS badge)
│     └─ Shaders/ (ability_cooldown, card_locked)
├─ Scenes/
│  ├─ NPCs/
│  │  ├─ roster.tres (Roster: every playable character, GameManager.ROSTER)
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
│  │  ├─ monster_slot.gd (MonsterSlot: spawns the selected monster)
│  │  ├─ FogOfWar/
│  │  └─ MobSpawnArea/
│  └─ UI/
│     ├─ Screens/ (MenuRoot.tscn: the main scene, LobbyScreen.tscn,
│     │            RosterScreen.tscn, CharacterDetail.tscn, ux_tree_model.gd)
│     ├─ MainMenu/ (the old menu, reachable from the match result until Phase 8)
│     ├─ HeroContainer/
│     ├─ Components/ (menu kit: CharacterCard, StageCharacter, TopBar,
│     │               CurrencyChip, NavBar, NavTab, NavArch, PressFeedback,
│     │               StatTile, AbilityTile, SkillNodeButton, SkillTreeView)
│     ├─ Widgets/ (rig_view.gd: RigView, a puppet rig inside a Control)
│     └─ Theme/
│        ├─ ui_theme.tres (generated project Theme, gui/theme/custom)
│        ├─ ui_palette.gd (UiPalette)
│        └─ palette.tres (generated palette values)
├─ Scripts/
│  ├─ Progression/ (CharacterProgress: card level, XP pill, ready upgrades)
│  ├─ Rig/ (CharacterRig, RigBody, RigProfile: SVG cut-out rigs)
│  ├─ Roster/ (Roster, CharacterDef: the character registry)
│  ├─ Vfx/ (VfxManager, FxSpriteBuffer, FxTex, FxEase, FxEvents: pooled hit feedback)
│  └─ Systems/
│     ├─ ability_system.gd
│     └─ hero_exploration_controller.gd
├─ test/ (headless suite, test_*.gd; fixtures/rig_fixture/ for the rig tests)
└─ tools/
   ├─ art/ (Python art pipeline: palette.py, build.py, make_theme.py, ...)
   ├─ rig_builder.gd · build_rigs.gd · build_rigs.sh (SVG parts → rig sheet + body)
   └─ preview/ (ThemeMockup, ThemeScreens, PaletteSheet, RigGallery, CardGrid
                proof scenes, not shipped)
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

- [x] Lobby (the main scene, MenuRoot): the heroes' campfire and the monster lair as live rigs, tap a side to choose it (persisted)
- [x] Roster screens (4-column collections with role filters) and the character detail (overview with stats and abilities, skill tree with upgrades); Growth shows the side's base tree
- [x] Main Menu with side selection, Settings (volumes) and the Meta Skill screen (old; reachable from the match result)
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
- [x] Monster / heroes stuck in corners — fixed: dashes, leaps, strafes and pushes stop at walls;
      exploration only targets reachable waypoints; the nav bake drops the sealed one-tile islands
      (`tools/bake_nav.gd`)
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

**v0.1** (Current) - Prototype:

- 4 heroes, 1 monster, core loop functional
- Basic AI, fog of war, UI systems
- No progression systems yet

---

**END OF README**
