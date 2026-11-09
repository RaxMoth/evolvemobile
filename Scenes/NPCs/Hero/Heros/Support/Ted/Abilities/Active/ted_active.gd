extends AbilityBase
class_name TedActiveRally

## Rally Cry - Boosts attack speed for Ted and his pets

@export var attack_speed_boost: float = 1.5 # 50% faster attacks
@export var boost_duration: float = 5.0
## hero_ted capstone "War Cry": every other living hero within this many px of
## Ted gets the same boost. 0 = off.
@export var aura_radius: float = 0.0

func execute(caster: Node2D, _target: Node2D = null, _override_damage: float = -1.0) -> void:
	if not caster:
		return
	
	# Apply boost to Ted
	if caster.has_method("apply_attack_speed_boost"):
		caster.apply_attack_speed_boost(attack_speed_boost, boost_duration)
	
	# Apply boost to his pets
	var ted := caster as Ted
	if ted:
		for pet in ted.get_pets():
			pet.set_attack_speed_boost(attack_speed_boost, boost_duration)
	
	if aura_radius > 0.0:
		_war_cry(caster)
	
	# Visual feedback
	_create_rally_effect(caster)

## War Cry: the heroes around Ted attack faster too.
func _war_cry(caster: Node2D) -> void:
	var team := TeamRegistry.get_team(TeamRegistry.HEROES)
	if team == null:
		return
	var r_sq: float = aura_radius * aura_radius
	var tint: Color = UiPalette.get_default().amber
	for ally in team.members:
		var hero := ally as HeroBase
		if hero == null or hero == caster or not hero.is_alive() \
				or hero.global_position.distance_squared_to(caster.global_position) > r_sq:
			continue
		hero.apply_attack_speed_boost(attack_speed_boost, boost_duration)
		GameUtils.flash_modulate(hero, tint, 0.15, 0.3)

func _create_rally_effect(caster: Node2D) -> void:
	# Flash Ted orange
	GameUtils.flash_modulate(caster, Color.ORANGE, 0.2, 0.2)
