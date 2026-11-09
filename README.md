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
- **Capstones** (one equipped): Deadeye (every 4th sniper shot x2.5), Chain
  Heal (staff heals also heal the most hurt ally within 160 px), Pathfinder
  (every hero +12% move speed while River lives)

#### Vlad (DPS/Berserker)

- **Base Stats**: 110 HP, 80 speed, 250 vision
- **Passive**: Bloodlust (Below 30% HP: +50% dmg, +100% attack speed)
- **Active**: Land Mine (18 dmg explosion)
- **Basic Attack**: 10 dmg at 50 range / 1.0s
- **Ultimate**: Blood Bomb (50 dmg, 150 AoE)
- **Scaling**: +6 HP, +1.7 dmg per level
- **Capstones** (one equipped): Executioner's Mark (Blood Strike x2 below 25%
  HP), Sanguine Feast (Blood Strike heals 20% of its damage), Cluster Mines
  (3 mines per Land Mine)

#### Ted (DPS/Pet Master)

- **Base Stats**: 105 HP, 85 speed, 220 vision
- **Pet Stats**: 50 HP, 9 dmg, 60 range, 1.2s cooldown
- **Passive**: Loyal Companion (pet respawns after 10s)
- **Active**: Rally Cry (+50% attack speed for 5s)
- **Basic Attack**: 9 dmg at 55 range / 1.2s
- **Ultimate**: Trap Cage (150 radius, traps enemies for 6s)
- **Scaling**: +5 HP, +1.6 dmg per level
- **Combined DPS** (Ted + Pet): ~15.0 DPS
- **Capstones** (one equipped): War Cry (Rally Cry also hastes heroes within
  300 px), Pack of Two (two pets), Spiked Cage (6 damage per second inside the
  cage)

#### Irelia (Tank/Support)

- **Base Stats**: 160 HP, 75 speed, 200 vision
- **Passive**: Regeneration (0.5 HP/s)
- **Active**: Divine Shield (18 HP shield to all heroes, 7s duration)
- **Basic Attack**: 5 dmg at 120 range / 1.5s
- **Ultimate**: Monster Taunt (Forces monster to attack Irelia for 5s)
- **Scaling**: +8 HP, +1.2 dmg per level
- **Capstones** (one equipped): Last Stand (survive a lethal hit once at 1 HP,
  2 s invulnerable), Guardian Angel (Divine Shield breaks stuns), Rallying
  Taunt (heroes within 250 px +25% attack speed during the taunt)

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
      ult, locked), the old round skill-tree rings (`node_minor`,
      `node_major` and their `_tint` versions; no theme type uses them since
      the square tiles of the ranked tree screen), toggles, padlock,
      notification dot, leaf and vine ornaments, the background tile. 9-slice
      margins live in `kit.MARGINS`.
    - `Icons/` (79, 64x64): `Abilities/` (27, `<owner>_<slot>_<ability>`:
      a full-bleed tile in the owner's tone that the slot frame sits on;
      every hero and Grount ability, River's two basic modes, and Nyxa's and
      Gorrak's abilities on the `monster2` / `monster3` tiles), `Currency/`
      (gold, steel, leaves, upgrade point), `Stats/` (16), `Roles/` (9 filter
      silhouettes), `Nav/` (6) and `UI/` (17 glyphs; `ui_skull` marks a
      fallen hero and the HUD's kill count).
    - Every ability `.tres` (the 16 hero abilities and Grount's three) sets
      its `icon` to its tile; no ability shows the old `Icon.jpg`
      placeholder. River's basic attack also has `heal_icon`
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
    - The old screens (main menu, pre-round, skill screen, match result,
      settings, tutorial) restyle through it until Phases 3-8 replace them;
      their own overrides still win. The MatchHud's cards and panels use
      HudPanel / HudPanelSelected and HpBarHero / HpBarMonster.
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

### Match HUD (MatchHud)

`Scenes/UI/Hud/MatchHud.tscn` (`MatchHud`, CanvasLayer 5) is the in-match HUD
of both sides, a `MainCam` child (`MainCam.hud`, wired in `MainCam.tscn`). It
replaced HeroContainer / HeroPanel and the FPS label (F3 keeps the frame
timings). Presentation only: it reads the entities and GameManager and never
writes gameplay state, so `tools/sim_trace.sh` stays byte-identical.

- **Top bar** (80 px), refreshed at 4 Hz, each label written only when it
  changes:
    - Pause (`ButtonRound`, `process_mode` ALWAYS): toggles the tree's pause
      while a match runs; the icon swaps to play.
    - Clock chip: `GameManager.get_match_elapsed()` as "03:42".
    - Enemy tracker: heroes side, the monster's head, "STAGE II" and its HP;
      monster side, a head and mini HP bar per hero (the scene's `HeroChip`
      template, duplicated per hero), greyed when the hero falls.
    - Kills chip (`ui_skull`, `GameManager.mob_kills`).
    - Follow (`ui_follow`): `follow_requested` → `MainCam.recenter()` (leaves
      the debug fly-cam, centres on the followed entity).
- **Minimap**: the match's `Minimap` lives in the HUD's copper frame
  (`Root/MinimapFrame/MinimapSlot`, 156x124, its own frame off via
  `show_frame`). A tap emits `Minimap.hero_picked`, wired to
  `MatchHud.select_hero` in the scene.
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
    - the selected card lifts 8 px and wears `HudPanelSelected`; a fallen
      hero's card greys out (`UiPalette.FALLEN_MODULATE`) under the skull.
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
    - the passive (the monster's Evolution icon when it has no passive
      resource) and ability_1..3 bound to a `CooldownSource.Monster`: Ground
      Slam shows its padlock and "II" until Stage II;
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
    - `ability_cast` of an ultimate (hero or monster): its name, "BLOOD BOMB",
      not queued, and the same ultimate at most once per
      `ultimate_repeat_guard` (12 s of match time; Ted's Trap Cage is back
      every few seconds).
  Names are the roster's `CharacterDef` display names, upper-cased; each kind
  has an `announce_*` export.
- Strings go through `Assets/Locale/strings.csv` (EN/DE), the toast lines too
  ("%s EVOLVED · STAGE %s", "%s HAS FALLEN"; the toast label does not
  auto-translate the finished line again).
- `test/test_match_hud.gd` (cards, focus across deaths, HP bands, pause and
  follow wiring, the monster panel and tracker, the intent mapping),
  `test/test_match_toasts.gd` (toast texts in EN/DE, the queue, the scene-wired
  Announcer through an evolution, a hero's fall and ultimates, the level badge
  pop) and `test/test_hud_fog.gd` (the minimap in its frame, both sides).

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
    - Fed by `bind(source, slot)` (polled every frame; callable before the
      slot enters the tree, and a freed entity stops the polling) or by a
      card calling `set_cooldown(progress, remaining)` / `set_locked()`. The shader parameter is written only when
      the progress moved by 0.002 (and always when it reaches 1.0), the label
      only when the shown number changes.
- `test/test_cooldown_source.gd` (both sources against a real Grount and Vlad,
  read-only) and `test/test_ability_slot.gd` (no shader or label write while
  the value is unchanged, the number format, one pop per ready transition,
  the lock state and frames, River's icon swap, Ground Slam unlocking on
  evolution). `tools/preview/SlotStrip.tscn` renders the slots on HudPanels
  from scripted sources: sweeps, a lock, an ultimate coming ready, River's
  swap, Grount evolving.

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
- get_modifier(stat, multiplicative) / get_damage_taken_multiplier() /
  get_cooldown_multiplier() / get_start_level()   # generic stat keys
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
# Active and ultimate cooldowns start x HeroStats cooldown_mult (Battle Drills).
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
    heroes, Leaves for monsters) and `skill_tree`, the character's
    `Data/SkillTrees/<side>_<id>.tres` (its id is `skill_tree_id()`).
    MetaSkillManager registers the tree of every roster def at startup, so a
    character's tree is live exactly while its def is in the roster.
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
  `<id>_def.tres` added to `roster.tres`; and its `Data/SkillTrees/monster_<id>.tres`
  linked from the def's `skill_tree` (Nyxa's and Gorrak's are generated and wait
  for their defs).

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
      `MetaSkillManager.rank_up` (the next rank; the shop decides: gates,
      price), and `equip_requested(tree_id, node_id)` →
      `MetaSkillManager.equip_capstone` (free). On
      `MetaSkillManager.skills_changed` and `PersistedData.currency_changed`
      (connected in code: autoloads) every roster and detail on the stack
      re-reads the save, once per frame at most.
    - Red nav dots: on entry, after every such refresh and when the side
      changes, every nav bar under the menu (`NavBar.GROUP`) shows Heroes /
      Monsters while a character of that side has a rank to buy now
      (`CharacterProgress.upgrades_ready`) and Growth while the chosen side's
      account tree has one (`MetaSkillManager.card_progress`).
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
  and a capstone swap through the detail and the refresh of the screens under
  it; the nav dots follow buyable ranks; the main scene is MenuRoot.

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
  hand-built ranked tree; the live Grount tree with its hidden slots; the
  points gates of Hero Base and their reasons in English and German; Irelia's
  capstones following the equipped one; icons; the live states, rank totals
  and equipped capstone agree with `node_state`, `card_progress` and
  `equipped_capstone` on every node of every tree, fresh and seeded),
  `test_roster_screen` (grid, rumour, filters, count, intro, taps, refresh,
  wiring), `test_character_detail` (stat rows, overview, level / XP / badge,
  tree mode and sheet with the purchase juice, the sheet opening on a buyable
  node, capstones equipping from the sheet, the top bar counting down, every
  character and account tree fits 720x1280 with its gutter, plaques, arches
  and names, Growth, wiring), and
  `test_grount_behaviour_nodes` checks the Grount tree on this screen (every
  shown node on it, hidden ones not, Titan Form gated until Grount Lv 8, bought
  through `upgrade_requested`).

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
│     └─ Shaders/ (ability_cooldown, card_locked, ready_glow)
├─ Data/
│  └─ SkillTrees/ (the nine skill trees, <tree_id>.tres: MetaSkillTree + node sub-resources)
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
│     ├─ Hud/ (MatchHud: the in-match HUD under MainCam, HeroHudCard,
│     │        MonsterHudPanel, AbilitySlot: ability icon with the cooldown sweep,
│     │        MatchAnnouncer: match events -> the HUD's event toasts)
│     ├─ Minimap/ (Minimap: fog map + side-fair dots, inside the MatchHud frame)
│     ├─ Components/ (menu kit: CharacterCard, StageCharacter, TopBar,
│     │               CurrencyChip, NavBar, NavTab, NavArch, PressFeedback,
│     │               StatTile, AbilityTile, SkillNodeButton, SkillTreeView)
│     ├─ Widgets/ (rig_view.gd: RigView, a puppet rig inside a Control)
│     └─ Theme/
│        ├─ ui_theme.tres (generated project Theme, gui/theme/custom)
│        ├─ ui_palette.gd (UiPalette)
│        └─ palette.tres (generated palette values)
├─ Scripts/
│  ├─ MetaSkills/ (MetaSkillManager, MetaSkillTree, MetaSkillNode; skill_tree_data_v2.gd: the trees' seed data)
│  ├─ Progression/ (CharacterProgress: card level, XP pill, ready upgrades)
│  ├─ Rig/ (CharacterRig, RigBody, RigProfile: SVG cut-out rigs)
│  ├─ Roster/ (Roster, CharacterDef: the character registry)
│  ├─ UI/ (CooldownSource: read-only HUD view of an entity's ability slots)
│  ├─ Vfx/ (VfxManager, FxSpriteBuffer, FxTex, FxEase, FxEvents: pooled hit feedback)
│  └─ Systems/
│     ├─ ability_system.gd
│     └─ hero_exploration_controller.gd
├─ test/ (headless suite, test_*.gd; fixtures/rig_fixture/ for the rig tests)
└─ tools/
   ├─ art/ (Python art pipeline: palette.py, build.py, make_theme.py, ...)
   ├─ rig_builder.gd · build_rigs.gd · build_rigs.sh (SVG parts → rig sheet + body)
   ├─ build_skill_trees.gd · build_skill_trees.sh (one-off: seed data → Data/SkillTrees)
   └─ preview/ (ThemeMockup, ThemeScreens, PaletteSheet, RigGallery, CardGrid,
                SlotStrip proof scenes, not shipped)
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
  that writes the code clears the flag in the tree's `.tres`.
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
  `equip_capstone`, `applied_ranks` (what a spawn applies) and
  `card_progress(tree)` → `{owned_ranks, open_ranks, upgrade_ready}` for the
  card pill. `ai_build_order` on the tree lists the ranks an AI side buys.
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

Trap Cage takes its `duration` before it enters the tree (its `_ready` starts
the expiry timer), so Sturdy Cage lengthens it; `ted_ultimate.tres` now says
6 s, the cage's own default that every cage used while the ability's 2 s
arrived too late.

Balance check (`SAVE=<save.cfg> tools/sim.sh 24 heroes 6`: every match starts
from that save; 5.4, against a fresh-save Grount). A fresh save: heroes win 33%.
Only the four capstones of one branch, equipped: branch 0 (Last Stand,
Executioner's Mark, War Cry, Deadeye) 50%, branch 1 (Guardian Angel, Sanguine
Feast, Pack of Two, Chain Heal) 71%, branch 2 (Rallying Taunt, Cluster Mines,
Spiked Cage, Pathfinder) 42%; Pathfinder brings the first hero-monster contact
from about 400 s to 81 s. All four hero trees fully ranked: 92% with any
branch's capstones and 92% without one. The trees, not the capstones, decide
that matchup until the AI monster gets its build from Opponent Threat (6.8).

Haste rule (`HeroBase.apply_attack_speed_boost`, Rally Cry and the
capstones above): a weaker boost never replaces a stronger one that is still
running; an equal or stronger one restarts it. The F3 overlay's ability lines
show each export as a tree modifier ("Regeneration ... tree last_stand +1.00
last stand ready").

#### Tree content v2 (Data/SkillTrees)

Nine trees, one `MetaSkillTree` resource each with its nodes as sub-resources:
`Data/SkillTrees/<tree_id>.tres`. They were generated once by
`tools/build_skill_trees.sh` (runs `tools/build_skill_trees.gd` on a temp copy)
from the design's seed data, `Scripts/MetaSkills/skill_tree_data_v2.gd`
(`SkillTreeDataV2`); since then the `.tres` files ARE the trees and are edited
in the inspector (the tool keeps an existing file unless `--force`).
`MetaSkillManager._ready` registers `hero_base` and `monster_base`
(`HERO_BASE_TREE`, `MONSTER_BASE_TREE`) and every roster def's `skill_tree`;
`monster_nyxa` and `monster_gorrak` are generated but wait for their defs.

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
  their cooldown and tree modifiers ("Trap Cage  cd 4.00 s  tree cooldown x0.80").
- **AI build orders** (`ai_build_order`, 12 ranks per character tree, capstone
  last) wait for the Opponent Threat rule.

Nodes, "branch: tier node (ranks)", `<-` = requires any; **[hidden]** = no
code yet (every hero node has its code since 5.4; 6.6: monster behaviours):

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
    CAP Rampage (a hero kill resets the cooldowns, heals 15%) **[hidden]**.
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
    +33/45/55%; T3 Apex Charge +15/18/21% speed; T4 CAP Trample **[hidden]**.
- **monster_nyxa** (Hunger / Shadow / Brood) and **monster_gorrak** (Tusks /
  Bristles / Warband): generated with the gamedesign values, registered with
  their defs in Phase 6. Their generic-key nodes (Night Recovery, Mud Armour,
  Mud Bath) are already shown; their other new-code nodes stay hidden.

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
- [x] Match HUD: hero cards / monster panel with real-time stats, top bar, framed minimap
- [x] Match event toasts (evolution, hero fallen, ultimates) and the level-up badge pop
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
- [x] Skill trees v2 as resources (`Data/SkillTrees`): 3 branches x 4 tiers, ranks, capstones, level / points gates; nodes without code yet are hidden
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

- [x] Pet sometimes didn't respawn if Ted died during the respawn timer — closed: every pet slot
      has its own respawn timer on Ted's own copy of the passive (`TedPassivePet.pets` /
      `respawn_timers`), so nothing is shared between Teds or matches; heroes do not respawn, so a
      dead Ted's pets end with him
- [ ] Trap Cage traps (almost) nothing: `TrapCage._ready` scans for enemies before
      `TedUltimateTrapCage` moves it onto the target (it scans at the world origin, by the heroes'
      start) and before `cage_radius` arrives (`area_of_effect` is 2 in `ted_ultimate.tres`, the
      scene says 150); setting position and radius before `add_child` changes default gameplay, so
      it waits for a balance pass. The spikes of Spiked Cage use the cage's 150 px shape where it lands
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
      which rule ships (`MonsterBase.heal_to_full_on_evolution`), then add Grount's "Second Wind"
      (`monster_stage_2_evo_heal` +200, wired and tested in `test_grount_behaviour_nodes`) to
      `Data/SkillTrees/monster_grount.tres`

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
