extends TestCase

## HUD cooldown plumbing: CooldownSource reads the real cooldowns of heroes
## (AbilitySystem) and monsters (MonsterBase) in the HUD's slot order, locks
## stage-gated abilities with their stage numeral, and never writes the
## entity's state. MonsterBase.get_cooldown_progress mirrors
## AbilitySystem.get_cooldown_progress (remaining / the cooldown cast with).
## The F3 overlay prints the same readings as text (debug_state), so a HUD
## slot can be cross-checked.

const GROUNT := "res://Scenes/NPCs/Monster/Grount/Grount.tscn"
const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"


func test_monster_source_tracks_a_cast() -> void:
	var g := (await spawn_frozen(GROUNT, Vector2(4000, 0))) as MonsterBase
	var src := CooldownSource.Monster.new(g)
	assert_true(src.is_valid())
	assert_eq(src.slot_count(), 4)
	assert_true(src.ability(0) == g.ability_1 and src.ability(1) == g.ability_2 and src.ability(2) == g.ability_3,
		"slots 0-2 = ability_1..3")
	assert_true(src.ability(3) == g.passive_ability, "slot 3 = the passive")
	assert_true(src.caster() == g)
	assert_eq(src.slot_type(0), AbilityBase.AbilityType.BASIC_ATTACK)
	assert_eq(src.slot_type(2), AbilityBase.AbilityType.ULTIMATE)
	assert_eq(src.slot_type(3), AbilityBase.AbilityType.PASSIVE)
	assert_true(src.icon(1) == g.ability_2.icon, "Ram Dash shows its own icon")
	assert_near(src.progress(0), 1.0, 0.0001, "ready before any cast")
	assert_near(src.remaining(0), 0.0, 0.0001)
	assert_near(src.progress(3), 1.0, 0.0001, "the passive slot never cools down")
	assert_false(src.locked(0), "Front Cleave is a stage-1 ability")
	assert_true(src.locked(2), "Ground Slam is locked at Stage I")
	assert_eq(src.lock_hint(2), "II")

	var total: float = g.ability_1.cooldown
	assert_true(g._cast("ability_1", g.ability_1, null))
	assert_true(src.progress(0) < 0.05, "just cast")
	assert_near(src.remaining(0), total, 0.05)
	await wait_seconds(0.5)
	assert_true(src.progress(0) > 0.05 and src.progress(0) < 1.0, "recharging")
	assert_near(src.progress(0), 1.0 - src.remaining(0) / total, 0.001, "progress = 1 - remaining / total")
	assert_near(g.get_cooldown_progress("ability_1"), src.progress(0), 0.0001)

	g.gain_xp(1000.0)
	assert_eq(g.current_stage, 2)
	assert_false(src.locked(2), "Ground Slam unlocks at Stage II")
	assert_near(src.progress(0), 1.0, 0.0001, "evolving resets every cooldown")
	g.queue_free()
	await wait_frames(1)
	assert_false(src.is_valid(), "invalid once the monster is gone")


func test_hero_source_reads_the_ability_system() -> void:
	var v := await spawn_frozen(VLAD, Vector2(0, 0))
	var sys := v.get_node("AbilitySystem") as AbilitySystem
	var src := CooldownSource.Hero.new(sys)
	assert_eq(src.slot_count(), 4)
	assert_true(src.ability(0) == sys.basic_attack, "slot 0 = basic attack")
	assert_true(src.ability(1) == sys.active_ability, "slot 1 = active")
	assert_true(src.ability(2) == sys.ultimate_ability, "slot 2 = ultimate")
	assert_true(src.ability(3) == sys.passive_ability, "slot 3 = passive")
	assert_eq(src.slot_type(0), AbilityBase.AbilityType.BASIC_ATTACK)
	assert_eq(src.slot_type(2), AbilityBase.AbilityType.ULTIMATE)
	assert_true(src.caster() == v)
	assert_true(src.icon(2) == sys.ultimate_ability.icon)
	assert_false(src.locked(2), "heroes have no stage locks")
	var ult := AbilityBase.AbilityType.ULTIMATE
	sys.cooldowns[ult] = 5.0
	sys._cooldown_totals[ult] = 10.0
	assert_near(src.progress(2), 0.5, 0.0001)
	assert_near(src.remaining(2), 5.0, 0.0001)
	assert_near(src.progress(3), 1.0, 0.0001, "the passive never cools down")
	v.queue_free()
	await wait_frames(1)
	assert_false(src.is_valid())


func test_sources_never_write_the_entity() -> void:
	var g := (await spawn_frozen(GROUNT, Vector2(4000, 0))) as MonsterBase
	assert_true(g._cast("ability_2", g.ability_2, null))
	var cooldowns: Dictionary = g.ability_cooldowns.duplicate()
	var totals: Dictionary = g._cooldown_totals.duplicate()
	var cast_cooldown: float = g.ability_2.cooldown
	var src := CooldownSource.Monster.new(g)
	var read: Array = []
	for i in src.slot_count():
		read.append_array([src.ability(i), src.icon(i), src.progress(i), src.remaining(i),
				src.locked(i), src.lock_hint(i)])
	assert_eq(read.size(), 24, "every reader called on every slot")
	assert_eq(g.ability_cooldowns, cooldowns, "ability_cooldowns untouched")
	assert_eq(g._cooldown_totals, totals, "_cooldown_totals untouched")
	assert_near(g.ability_2.cooldown, cast_cooldown, 0.0001)
	g.queue_free()
	await wait_frames(1)


## The slot states as F3 text: the time left, "ready", "locked II", nothing
## for a passive.
func test_debug_state_names_the_time_left() -> void:
	var v := await spawn_frozen(VLAD, Vector2(0, 0))
	var sys := v.get_node("AbilitySystem") as AbilitySystem
	var src := CooldownSource.Hero.new(sys)
	var ult := AbilityBase.AbilityType.ULTIMATE
	assert_eq(src.debug_state(2), "ready", "no cast yet")
	sys.cooldowns[ult] = 11.42
	sys._cooldown_totals[ult] = 20.0
	assert_eq(src.debug_state(2), "left 11.42 s", "what the ultimate's slot counts down")
	assert_eq(src.debug_state(3), "", "a passive never cools down")
	assert_eq(src.debug_state(1), "ready", "the active")
	v.queue_free()

	var g := (await spawn_frozen(GROUNT, Vector2(4000, 0))) as MonsterBase
	var monster_src := CooldownSource.Monster.new(g)
	assert_eq(monster_src.debug_state(2), "locked II", "Ground Slam before Stage II")
	assert_eq(monster_src.debug_state(3), "", "the passive slot")
	assert_true(g._cast("ability_1", g.ability_1, null))
	assert_eq(monster_src.debug_state(0), "left %.2f s" % g.get_ability_cooldown("ability_1"), "Front Cleave just cast")
	assert_eq(monster_src.debug_state(1), "ready", "Ram Dash")
	g.queue_free()
	await wait_frames(1)


## The F3 overlay shows the time left next to each of the followed hero's
## abilities (it listed only the cooldown each one starts), and the same
## lines for each monster's abilities.
func test_f3_overlay_shows_the_time_left() -> void:
	var overlay := DebugOverlay.new()
	add_child(overlay)
	var v := await spawn_frozen(VLAD, Vector2(0, 0))
	var g := (await spawn_frozen(GROUNT, Vector2(4000, 0))) as MonsterBase
	var sys := v.get_node("AbilitySystem") as AbilitySystem
	var ult := AbilityBase.AbilityType.ULTIMATE
	sys.cooldowns[ult] = 11.42
	sys._cooldown_totals[ult] = 20.0
	overlay._update_hud_label(v, null, null)
	var text := overlay._hud_label.text
	assert_true(text.contains("  %s  left 11.42 s" % sys.ultimate_ability.debug_line()), "the ultimate's time left:\n" + text)
	assert_true(text.contains("  %s  ready" % sys.active_ability.debug_line()), "a ready active")
	var passive_line := "  " + sys.passive_ability.debug_line()
	assert_true(text.contains(passive_line + "\n") or text.ends_with(passive_line), "the passive has no cooldown state")
	assert_true(text.contains("  %s  ready\n" % g.ability_1.debug_line()), "the monster's Front Cleave:\n" + text)
	assert_true(text.contains("  %s  locked II\n" % g.ability_3.debug_line()), "its locked Ground Slam")
	assert_true(g._cast("ability_1", g.ability_1, null))
	overlay._update_hud_label(v, null, null)
	assert_true(overlay._hud_label.text.contains("  %s  left %.2f s\n" % [g.ability_1.debug_line(),
			g.get_ability_cooldown("ability_1")]), "and its time left after a cast")
	overlay.queue_free()
	v.queue_free()
	g.queue_free()
	await wait_frames(1)
