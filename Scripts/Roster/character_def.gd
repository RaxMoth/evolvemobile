class_name CharacterDef
extends Resource

## One playable character (hero or monster): everything menus, the match and the
## tools need WITHOUT instancing its scene (instancing an entity registers it
## with EntityRegistry / TickScheduler and draws from the global RNG).
##
## Identity lives in `stats`: HeroStats.hero_id / MonsterStats.monster_id is THE
## save key (XP, level, the "<side>_<id>" skill tree, analytics, sim results).
## `stats` must be the very resource the scene's root (monster) or HeroStats
## node (hero) points at; test_roster.gd checks it through the SceneState.
## Gameplay numbers stay in the stats and ability .tres files: abilities() reads
## the scene's own ability resources, so icons, names and descriptions are never
## copied here.

## Same values as MatchRewards.Side. Plain ints, not an enum type: the roster
## sits on an autoload dependency cycle (GameManager -> Roster -> CharacterDef
## -> MetaSkillManager) where a typed enum export fails to resolve.
const HEROES := 0
const MONSTER := 1
## Size of the composite portrait (<id>.svg) in art units: head_region is in
## these units.
const PORTRAIT_CANVAS := Vector2(128, 160)
## Filter-row icon of role_filter (role_icon()).
const ROLE_ICON_PATH := "res://Assets/UI/Icons/Roles/role_%s.svg"
## Ability slots in menu order (overview tiles, pre-round icons): heroes on
## their AbilitySystem node, monsters on the scene root. Empty slots are skipped.
const HERO_ABILITY_SLOTS: Array[StringName] = [&"passive_ability", &"basic_attack", &"active_ability", &"ultimate_ability"]
const MONSTER_ABILITY_SLOTS: Array[StringName] = [&"passive_ability", &"ability_1", &"ability_2", &"ability_3"]

@export_enum("Heroes", "Monster") var side: int = HEROES
## The character's scene, as a path: loading the roster must not load every
## character's scene (GameManager preloads the roster at boot).
@export_file("*.tscn") var scene_path: String = ""
@export var stats: Resource

@export_group("Presentation")
## Menu name. Empty = the stats' hero_name / monster_name (get_display_name()).
@export var display_name: String = ""
## Role line under the name ("Tank · Leader").
@export var role_text: String = ""
## Filter-row key of the collection screen (tank, melee, ranged, support,
## brute, stalker, swarm, ...); its icon is Assets/UI/Icons/Roles/role_<key>.svg.
@export var role_filter: StringName = &""
## UiPalette token of the character's accent (name plate, minimap dot).
@export var accent_token: StringName = &""
@export_multiline var tagline: String = ""
## <id>_body.tscn (tools/build_rigs.sh): world, lobby showcase and cards.
@export var rig_body: PackedScene
@export var rig_profile: RigProfile
## <id>.svg composite (DPITexture): static card / result art, crisp at any size.
@export var portrait: Texture2D
## Head crop of the portrait in art units (PORTRAIT_CANVAS), for the HUD's head
## portraits (head_texture()).
@export var head_region: Rect2 = Rect2(32, 32, 64, 64)
## Monsters: one name per evolution stage (I, II, III). Empty for heroes.
@export var stage_names: PackedStringArray = PackedStringArray()
## The Codex's field notes: how a hero plays or how a monster hunts (its
## counterplay is `tip`).
@export_multiline var codex_notes: String = ""

@export_group("Progression")
@export var unlocked_by_default: bool = true
## Price of unlocking a locked character (the side's currency, currency()).
@export var unlock_cost: int = 0
## Owning another character of this side at this level opens the unlock
## (0 = no level gate).
@export var unlock_requires_level: int = 0
## Heroes-side quarry pool: the monster can be met once this many matches have
## been played (0 = from the first match). Monsters only.
@export var opponent_after_matches: int = 0
## The character's skill tree, Data/SkillTrees/<side>_<id>.tres; its id must be
## skill_tree_id(). MetaSkillManager registers the tree of every roster def at
## startup, so a character's tree is live exactly while its def is in the roster.
@export var skill_tree: MetaSkillTree
## Counterplay hint for the other side (pre-round threat box).
@export_multiline var tip: String = ""

## scene_path once loaded (scene()). A memo, never saved: the roster lives as
## long as GameManager, so the scene stays cached across Play Again reloads.
var _scene: PackedScene = null


func character_id() -> StringName:
	if stats is HeroStats:
		return (stats as HeroStats).hero_id
	if stats is MonsterStats:
		return (stats as MonsterStats).monster_id
	return &""


## The character's scene, loaded on first use and then kept.
func scene() -> PackedScene:
	if _scene == null and not scene_path.is_empty():
		_scene = load(scene_path) as PackedScene
	return _scene


func is_monster() -> bool:
	return side == MONSTER


func get_display_name() -> String:
	if not display_name.is_empty():
		return display_name
	if stats is HeroStats:
		return (stats as HeroStats).hero_name
	if stats is MonsterStats:
		return (stats as MonsterStats).monster_name
	return "?"


## Steel for heroes, Leaves for monsters (README currencies).
func currency() -> StringName:
	return PersistedData.STEEL if side == HEROES else PersistedData.LEAVES


func skill_tree_id() -> StringName:
	if side == HEROES:
		return MetaSkillManager.hero_tree_id(character_id())
	return MetaSkillManager.monster_tree_id(character_id())


func skill_tree_def() -> MetaSkillTree:
	return skill_tree


## Name of evolution stage `stage` (1-based), or "" when the def has none.
func stage_name(stage: int) -> String:
	if stage < 1 or stage > stage_names.size():
		return ""
	return stage_names[stage - 1]


func role_icon() -> Texture2D:
	var path := ROLE_ICON_PATH % role_filter
	return load(path) as Texture2D if ResourceLoader.exists(path) else null


## AtlasTexture cropping head_region out of the portrait (HUD head portraits).
func head_texture() -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = portrait
	if portrait != null:
		var k := float(portrait.get_width()) / PORTRAIT_CANVAS.x
		tex.region = Rect2(head_region.position * k, head_region.size * k)
	return tex


## The ability resources the character's scene uses, in menu order (see
## HERO_ABILITY_SLOTS / MONSTER_ABILITY_SLOTS). Read from the scene's state, so
## nothing is instanced; they are the shared .tres: read them, never modify.
func abilities() -> Array[AbilityBase]:
	var out: Array[AbilityBase] = []
	for ability in ability_slots():
		if ability != null:
			out.append(ability)
	return out


## The ability in each menu slot (passive, basic, active, ult): always four
## entries, null where a scene leaves a slot empty (every shipped character
## fills all four), so a screen can caption each one by its slot. Empty when the def
## has no scene.
func ability_slots() -> Array[AbilityBase]:
	var out: Array[AbilityBase] = []
	var packed := scene()
	if packed == null:
		return out
	var node_path := "./AbilitySystem" if side == HEROES else "."
	var slots: Array[StringName] = HERO_ABILITY_SLOTS if side == HEROES else MONSTER_ABILITY_SLOTS
	for slot: StringName in slots:
		out.append(scene_property(packed, node_path, slot) as AbilityBase)
	return out


## Value of `prop` on node `node_path` ("." = the root) of a PackedScene, read
## from its SceneState and, for an inherited scene, its base scenes' states.
## Null when no state sets it.
static func scene_property(packed: PackedScene, node_path: String, prop: StringName) -> Variant:
	var state := packed.get_state()
	while state != null:
		for n in state.get_node_count():
			if String(state.get_node_path(n)) != node_path:
				continue
			for i in state.get_node_property_count(n):
				if state.get_node_property_name(n, i) == prop:
					return state.get_node_property_value(n, i)
		state = state.get_base_scene_state()
	return null
