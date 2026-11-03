extends TestCase

## Data validation: every combatant can actually attack (the Fight gate is
## `min_distance <= distance <= attack_range`), and basic attacks match the
## README roster numbers. Catches the class of bug that shipped twice (Hog
## range 10 < min 20; Vlad min 80 > range 50 → never attacked).

const HEROES := {
	"res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn": "Vlad",
	"res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn": "River",
	"res://Scenes/NPCs/Hero/Heros/Support/Ted/Ted.tscn": "Ted",
	"res://Scenes/NPCs/Hero/Heros/Support/Irelia/Irelia.tscn": "Irelia",
}
const MOBS := ["res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn", "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"]
const MONSTER := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"


func test_every_combatant_has_a_satisfiable_attack_gate() -> void:
	var x := 0.0
	for path in HEROES.keys() + MOBS + [MONSTER]:
		var e := await spawn_entity(path, Vector2(x, 0))
		x += 3000.0
		assert_true(e.min_distance < e.attack_range, "%s: min_distance %.0f must be < attack_range %.0f" % [path.get_file(), e.min_distance, e.attack_range])
		assert_true(e.max_distance >= e.attack_range, "%s: max_distance %.0f must be >= attack_range %.0f" % [path.get_file(), e.max_distance, e.attack_range])
		e.queue_free()


func test_melee_heroes_are_melee() -> void:
	var vlad := await spawn_entity("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2.ZERO)
	assert_eq(vlad.combat_role, Types.CombatRole.MELEE, "Vlad is the melee berserker")
	vlad.queue_free()


func test_basic_attacks_match_the_readme_roster() -> void:
	var river: AbilityBase = load("res://Scenes/NPCs/Hero/Heros/Healer/River/Abilities/basic_attack/river_basic_attack.tres")
	assert_near(river.damage, 12.0); assert_near(river.cooldown, 1.1); assert_near(river.ability_range, 300.0)
	assert_near(river.heal_amount, 9.0, 0.001, "Healer mode heals (was 0)")
	assert_near(float(river.get("heal_cooldown")), 1.4)
	var irelia: AbilityBase = load("res://Scenes/NPCs/Hero/Heros/Support/Irelia/Abilities/Basic_attack/irelia_basic_attack.tres")
	assert_near(irelia.damage, 5.0); assert_near(irelia.cooldown, 1.5)
	var vlad: AbilityBase = load("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Abilities/basic_attack/basic_attack.tres")
	assert_near(vlad.damage, 10.0); assert_near(vlad.cooldown, 1.0)


func test_vlad_actually_swings_at_an_adjacent_enemy() -> void:
	# Vlad's own AI engages a Hog 35 px away (inside his 20..50 band). Before the
	# fix his band was 80..50 and he never swung in a whole match.
	var vlad := await spawn_entity("res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn", Vector2(0, 0))
	var hog := await spawn_entity("res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn", Vector2(35, 0))
	var casts := [0]
	var cb := func(caster: Node, ability: AbilityBase, _t: Node) -> void:
		if caster == vlad and ability.ability_type == AbilityBase.AbilityType.BASIC_ATTACK:
			casts[0] += 1
	EventBus.ability_cast.connect(cb)
	await wait_seconds(2.5)
	EventBus.ability_cast.disconnect(cb)
	assert_true(casts[0] >= 2, "Vlad basic-attacked %d times in 2.5 s" % casts[0])
	if is_instance_valid(hog):
		assert_true(hog.get_health() < hog.get_max_health(), "and the Hog took damage")
		hog.queue_free()
	vlad.queue_free()


func test_monster_ability_damage_matches_the_readme_per_stage() -> void:
	# README tables already include the stage multiplier. Stage 3 hits lighter
	# than stage 2 but much more often (v13 balance), so the DPS still rises.
	var g := await spawn_frozen(MONSTER, Vector2(4000, 4000))
	var m := g as MonsterBase
	var expected := {1: [12.0, 18.0], 2: [17.0, 25.0, 32.0], 3: [12.0, 36.0, 25.0]}
	for stage in [1, 2, 3]:
		if stage > 1:
			m.gain_xp(1000.0)
		assert_eq(m.current_stage, stage)
		var want: Array = expected[stage]
		var meta: float = m._meta_damage_mult
		assert_near(m.effective_ability_damage(m.ability_1), want[0] * meta, 0.01, "Front Cleave at stage %d" % stage)
		assert_near(m.effective_ability_damage(m.ability_2), want[1] * meta, 0.01, "Ram Dash at stage %d" % stage)
		if want.size() > 2:
			assert_near(m.effective_ability_damage(m.ability_3), want[2] * meta, 0.01, "Ground Slam at stage %d" % stage)
	g.queue_free()
