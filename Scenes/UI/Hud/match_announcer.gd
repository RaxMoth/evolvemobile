class_name MatchAnnouncer
extends Node

## Turns match events into the MatchHud's event toasts: `announced` is wired to
## MatchHud.show_toast in MatchHud.tscn. EventBus is an autoload, and an
## autoload cannot be the source of a scene [connection], so this node
## subscribes in _ready and re-emits each event as one localized line:
##   - the monster evolved: "GROUNT EVOLVED · STAGE II" (queued);
##   - a hero fell: "VLAD HAS FALLEN" (queued);
##   - an ultimate was cast (hero or monster): its name, "BLOOD BOMB". Not
##     queued: it shows only when no other toast is up, and the same ultimate
##     at most once per `ultimate_repeat_guard` seconds of match time.
## Names are the roster's CharacterDef display names. Presentation only: it
## reads the event arguments and never writes gameplay state.

## One toast line. `queued` false: drop it rather than wait behind another.
signal announced(text: String, queued: bool)

@export var announce_evolutions: bool = true
@export var announce_hero_deaths: bool = true
@export var announce_ultimates: bool = true
## Match seconds before the same ultimate is announced again (Ted's Trap Cage
## comes back every few seconds in a fight).
@export_range(0.0, 60.0, 0.5) var ultimate_repeat_guard: float = 12.0

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


## The ability's name, upper-cased ("BLOOD BOMB"), translated when
## strings.csv has it.
static func ultimate_text(ability: AbilityBase) -> String:
	return TranslationServer.translate(ability.ability_name).to_upper()


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


func _on_ability_cast(_caster: Node, ability: AbilityBase, _target: Node) -> void:
	if not announce_ultimates or ability == null or ability.ability_type != AbilityBase.AbilityType.ULTIMATE:
		return
	var text := ultimate_text(ability)
	var now := GameManager.get_match_elapsed()
	var last: float = _last_ultimate.get(text, -INF)
	if now - last < ultimate_repeat_guard:
		return
	_last_ultimate[text] = now
	announced.emit(text, false)
