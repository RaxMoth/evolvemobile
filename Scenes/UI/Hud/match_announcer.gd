class_name MatchAnnouncer
extends Node

## Turns match events into the MatchHud's event toasts: `announced` is wired to
## MatchHud.show_toast in MatchHud.tscn. EventBus is an autoload, and an
## autoload cannot be the source of a scene [connection], so this node
## subscribes in _ready and re-emits each event as one localized line:
##   - the monster evolved: "GROUNT EVOLVED · STAGE II" (queued);
##   - a hero fell: "VLAD HAS FALLEN" (queued);
##   - an ultimate was cast: the caster and the ability, "VLAD · BLOOD BOMB".
##     Only a cast the player can know about (player_sees): any cast of the
##     played side, and an enemy's only while the camera shows the caster on
##     revealed ground, so a monster in the fog or heroes far from the
##     monster player never give themselves away. Not queued: it shows only
##     when no other toast is up, and the same caster's ultimate at most once
##     per `ultimate_repeat_guard` seconds of match time.
## Names are the roster's CharacterDef display names. Presentation only: it
## reads the event arguments, the camera and the fog, and never writes
## gameplay state.

## One toast line. `queued` false: drop it rather than wait behind another.
signal announced(text: String, queued: bool)

@export var announce_evolutions: bool = true
@export var announce_hero_deaths: bool = true
@export var announce_ultimates: bool = true
## Match seconds before the same caster's ultimate is announced again. Heroes
## cast theirs on cooldown (Trap Cage every 5 s, Monster Taunt every 15 s):
## at 12 s one match showed 51 toasts, 26 of them Monster Taunt.
@export_range(0.0, 300.0, 0.5) var ultimate_repeat_guard: float = 60.0

## Ultimate toast text -> match time it was last announced.
var _last_ultimate: Dictionary[String, float] = {}


func _ready() -> void:
	EventBus.monster_evolved.connect(_on_monster_evolved)
	EventBus.entity_died.connect(_on_entity_died)
	EventBus.ability_cast.connect(_on_ability_cast)


## "GROUNT EVOLVED · STAGE II" (EN) / "GROUNT ENTWICKELT · STUFE II" (DE).
static func evolved_text(who: String, stage: int) -> String:
	var last := CooldownSource.STAGE_NUMERALS.size() - 1
	var numeral := CooldownSource.STAGE_NUMERALS[clampi(stage, 1, last)]
	return TranslationServer.translate("%s EVOLVED · STAGE %s") % [who.to_upper(), numeral]


## "VLAD HAS FALLEN" (EN) / "VLAD IST GEFALLEN" (DE).
static func fallen_text(who: String) -> String:
	return TranslationServer.translate("%s HAS FALLEN") % who.to_upper()


## The caster and the ability's name, upper-cased ("VLAD · BLOOD BOMB" /
## "VLAD · BLUTBOMBE"); the ability name is translated when strings.csv has it.
static func ultimate_text(who: String, ability: AbilityBase) -> String:
	return "%s · %s" % [who.to_upper(), TranslationServer.translate(ability.ability_name).to_upper()]


## The roster display name of a spawned hero or monster (its HeroStats /
## MonsterStats id), else the node's name. An empty id is never looked up:
## the roster's rumour card has none.
static func display_name_of(entity: Node) -> String:
	var id: StringName = &""
	var monster := entity as MonsterBase
	if monster != null:
		if monster.monster_stats != null:
			id = monster.monster_stats.monster_id
	else:
		id = MetaSkillManager.hero_id_of(entity)
	var def: CharacterDef = null
	if id != &"":
		def = GameManager.ROSTER.find(id)
	return def.get_display_name() if def != null else String(entity.name)


func _on_monster_evolved(monster: Node, stage: int) -> void:
	if announce_evolutions and is_instance_valid(monster):
		announced.emit(evolved_text(display_name_of(monster), stage), true)


## Heroes only: mobs, the monster (its death ends the match) and Ted's pet
## (in the "Hero" group, but no HeroBase) are not news.
func _on_entity_died(entity: Node, _killer: Node) -> void:
	if announce_hero_deaths and entity is HeroBase:
		announced.emit(fallen_text(display_name_of(entity)), true)


## True for an entity of the side the player plays (heroes side: the heroes
## and Ted's pet; monster side: the monster).
static func is_played_side(entity: Node) -> bool:
	var played := GameUtils.Faction.HERO if GameManager.chosen_side == MatchRewards.Side.HEROES \
			else GameUtils.Faction.MONSTER
	return GameUtils.cached_faction_of(entity) == played


## Whether the player can know what `caster` does: always for the played side;
## for an enemy only while the camera shows it and the fog over it is cleared.
## Without a GameCamera nothing of the enemy is in view; without a fog system
## nothing is hidden.
func player_sees(caster: Node) -> bool:
	if is_played_side(caster):
		return true
	var body := caster as Node2D
	var cam := get_viewport().get_camera_2d() as GameCamera
	if body == null or cam == null or not cam.get_viewport_rect_in_world().has_point(body.global_position):
		return false
	var fog := EntityRegistry.singleton(&"FogOfWar") as FogOfWarSystem
	return fog == null or fog.is_revealed(body.global_position)


func _on_ability_cast(caster: Node, ability: AbilityBase, _target: Node) -> void:
	if not announce_ultimates or ability == null or ability.ability_type != AbilityBase.AbilityType.ULTIMATE:
		return
	if not is_instance_valid(caster) or not player_sees(caster):
		return
	var text := ultimate_text(display_name_of(caster), ability)
	var now := GameManager.get_match_elapsed()
	var last: float = _last_ultimate.get(text, -INF)
	if now - last < ultimate_repeat_guard:
		return
	_last_ultimate[text] = now
	announced.emit(text, false)
