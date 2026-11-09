extends TestCase

## Every ability resource shows its own SVG tile from Assets/UI/Icons/Abilities
## (art spec section 4: <owner>_<slot>_<name>.svg, imported as a DPITexture),
## never the old Icon.jpg placeholder. River's basic attack has two: the rifle
## (`icon`) and the staff (`heal_icon`); get_display_icon follows her weapon
## mode, read-only (an AbilitySlot bound to her basic attack swaps with it:
## test_ability_slot.gd).

const NPC_DIR := "res://Scenes/NPCs"
const ICON_DIR := "res://Assets/UI/Icons/Abilities"
const PLACEHOLDER := "res://Assets/Icon.jpg"
const RIVER := "res://Scenes/NPCs/Hero/Heros/Healer/River/River.tscn"
const RIVER_BASIC := "res://Scenes/NPCs/Hero/Heros/Healer/River/Abilities/basic_attack/river_basic_attack.tres"

## Ability resource (relative to NPC_DIR) -> its icon's file name.
const EXPECTED: Dictionary[String, String] = {
	"Hero/Heros/Support/Irelia/Abilities/Basic_attack/irelia_basic_attack.tres": "irelia_basic_taunting_strike",
	"Hero/Heros/Support/Irelia/Abilities/Active/irelia_active.tres": "irelia_active_divine_shield",
	"Hero/Heros/Support/Irelia/Abilities/Passive/irelia_passive.tres": "irelia_passive_regeneration",
	"Hero/Heros/Support/Irelia/Abilities/Ult/irelia_ult.tres": "irelia_ult_monster_taunt",
	"Hero/Heros/DMG/Vlad/Abilities/basic_attack/basic_attack.tres": "vlad_basic_blood_strike",
	"Hero/Heros/DMG/Vlad/Abilities/active/active_mine.tres": "vlad_active_land_mine",
	"Hero/Heros/DMG/Vlad/Abilities/passive/passive_vlad.tres": "vlad_passive_bloodlust",
	"Hero/Heros/DMG/Vlad/Abilities/ult/ult.tres": "vlad_ult_blood_bomb",
	"Hero/Heros/Support/Ted/Abilities/Basic_attack/ted_basic_attack.tres": "ted_basic_claw_swipe",
	"Hero/Heros/Support/Ted/Abilities/Active/ted_active.tres": "ted_active_rally_cry",
	"Hero/Heros/Support/Ted/Abilities/Passive/ted_passive.tres": "ted_passive_loyal_companion",
	"Hero/Heros/Support/Ted/Abilities/Ult/ted_ultimate.tres": "ted_ult_trap_cage",
	"Hero/Heros/Healer/River/Abilities/basic_attack/river_basic_attack.tres": "river_basic_sniper",
	"Hero/Heros/Healer/River/Abilities/active/river_active.tres": "river_active_weapon_swap",
	"Hero/Heros/Healer/River/Abilities/passive/river_passive.tres": "river_passive_adaptive_movement",
	"Hero/Heros/Healer/River/Abilities/ult/river_ult.tres": "river_ult_supply_drop",
	"Monster/Grount/abilities/grount_front_cleave.tres": "grount_front_cleave",
	"Monster/Grount/abilities/grount_ground_slam.tres": "grount_ground_slam",
	"Monster/Grount/abilities/grout_ram_dash.tres": "grount_ram_dash",
}
## The <slot> part of a hero icon's name, per AbilityBase.AbilityType.
const SLOT_WORD: Dictionary[int, String] = {
	AbilityBase.AbilityType.PASSIVE: "passive",
	AbilityBase.AbilityType.ACTIVE: "active",
	AbilityBase.AbilityType.BASIC_ATTACK: "basic",
	AbilityBase.AbilityType.ULTIMATE: "ult",
}


func _tres_files(dir_path: String, out: Array[String]) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for sub: String in d.get_directories():
		_tres_files(dir_path.path_join(sub), out)
	for f: String in d.get_files():
		if f.ends_with(".tres"):
			out.append(dir_path.path_join(f))


func _icon_path(icon_name: String) -> String:
	return ICON_DIR.path_join(icon_name + ".svg")


func test_every_ability_resource_has_its_svg_icon() -> void:
	var files: Array[String] = []
	_tres_files(NPC_DIR, files)
	var found: Array[String] = []
	var used: Dictionary[String, String] = {}
	for path: String in files:
		var ability := load(path) as AbilityBase
		if ability == null:
			continue
		var rel := path.trim_prefix(NPC_DIR + "/")
		found.append(rel)
		assert_true(EXPECTED.has(rel), "%s is in the icon table" % rel)
		assert_true(ability.icon != null, "%s has an icon" % rel)
		if ability.icon == null:
			continue
		var icon_path := ability.icon.resource_path
		assert_false(icon_path == PLACEHOLDER, "%s no longer shows Icon.jpg" % rel)
		assert_true(ability.icon is DPITexture, "%s: the icon is an SVG DPITexture (got %s)" % [rel, ability.icon.get_class()])
		var expected_name: String = EXPECTED.get(rel, "")
		assert_eq(icon_path, _icon_path(expected_name), "%s: the art spec's icon" % rel)
		assert_false(used.has(icon_path), "%s: %s is not shared with %s" % [rel, icon_path, used.get(icon_path, "")])
		used[icon_path] = rel
		if rel.begins_with("Hero/"):
			var parts := icon_path.get_file().split("_")
			assert_eq(parts[1], SLOT_WORD.get(ability.ability_type, "?"), "%s: the icon's slot matches ability_type" % rel)
	assert_eq(found.size(), EXPECTED.size(), "every ability resource was found")


func test_display_icon_defaults_to_the_resource_icon() -> void:
	for rel: String in EXPECTED:
		var ability := load(NPC_DIR.path_join(rel)) as AbilityBase
		assert_true(ability.get_display_icon() == ability.icon, "%s: no caster, own icon" % rel)


func test_river_icon_follows_her_weapon_mode() -> void:
	var shared := load(RIVER_BASIC) as RiverBasicAttack
	assert_true(shared.heal_icon is DPITexture, "the staff has its own SVG icon")
	assert_eq(shared.heal_icon.resource_path, _icon_path("river_basic_heal"))
	assert_eq(shared.icon.resource_path, _icon_path("river_basic_sniper"))

	var river := await spawn_entity(RIVER)
	var system := river.get_node("AbilitySystem") as AbilitySystem
	var basic := system.basic_attack as RiverBasicAttack
	assert_eq(river.get_weapon_mode(), RiverActiveWeaponSwap.WeaponMode.SNIPER)
	assert_true(basic.get_display_icon(river) == shared.icon, "rifle: the sniper icon")

	river._use_active_now()
	assert_eq(river.get_weapon_mode(), RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF)
	assert_true(basic.get_display_icon(river) == shared.heal_icon, "staff: the heal icon")
	assert_true(basic.icon == shared.icon and shared.icon.resource_path == _icon_path("river_basic_sniper"),
		"reading the display icon changes neither River's copy nor the shared .tres")
	assert_eq(river.get_weapon_mode(), RiverActiveWeaponSwap.WeaponMode.HEAL_STAFF, "and not the weapon mode")
	assert_true(system.passive_ability.get_display_icon(river) == system.passive_ability.icon,
		"her other abilities keep their own icon")

	river.queue_free()
	await wait_frames(1)
