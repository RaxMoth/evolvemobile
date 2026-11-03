extends TestCase

## Base EntityBase target scoring and selection, the path heroes and mobs use
## as-is (only MonsterBase overrides _score_target). Pins today's numbers before
## the targeting refactors:
##   priority     hero / monster 100, mob priority_mob
##   distance     < 50 px +50, < 150 +30, < 300 +10, < 500 -10, else -50
##   penalties    -20 for a target that is not the current one,
##                -100 past max_chase_distance
##   threat       +30 when it targets me, +15 below 30 % HP,
##                low_hp_focus_weight × missing HP, -20 for my current target
##                fleeing past 400 px, team-blackboard threat × threat_score_weight
##   selection    _find_best_target needs a positive best score;
##                _reevaluate_current_target switches only when the best beats
##                the current target by MORE than the threshold.
## Fixture: Vlad at the origin, a Bat 40 px east and a Hog 160 px south, all in
## each other's 172 px detection circles (mobs never target mobs). AIs frozen,
## Vlad's auto-casts off, every target and threat row cleared.

const VLAD := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Vlad.tscn"
const BAT := "res://Scenes/NPCs/Mob/Mobs/Bat/Bat.tscn"
const HOG := "res://Scenes/NPCs/Mob/Mobs/Hog/Hog.tscn"
const EPS := 1e-4

var vlad: HeroBase
var bat: MobBase
var hog: MobBase


func test_a_hero_scores_mobs_by_priority_distance_and_switch_penalty() -> void:
	await _spawn_fixture()
	assert_near(vlad._score_target(bat), 100.0, EPS, "priority_mob 70 + 50 (< 50 px) - 20 switch penalty")
	assert_near(vlad._score_target(hog), 60.0, EPS, "70 + 10 (150-300 px) - 20")
	assert_near(vlad._get_threat_score(bat), 0.0, EPS, "healthy, not attacking, no blackboard threat")
	vlad.target = _body(hog)
	vlad.target_entity = hog
	assert_near(vlad._score_target(hog), 80.0, EPS, "the current target pays no switch penalty")
	assert_near(vlad._score_target(bat), 100.0, EPS)
	vlad.target = null
	vlad.target_entity = null
	# Band edges (only positions are read, so no physics frame is needed).
	for row: Array in [[49.0, 100.0], [50.0, 80.0], [149.0, 80.0], [150.0, 60.0], [299.0, 60.0],
			[300.0, 40.0], [499.0, 40.0], [500.0, 0.0], [1000.0, 0.0], [1001.0, -100.0]]:
		hog.global_position = Vector2(0.0, row[0])
		assert_near(vlad._score_target(hog), row[1], EPS, "Hog %d px away" % int(row[0]))


func test_mobs_score_the_hero_within_their_chase_distance() -> void:
	await _spawn_fixture()
	var vlad_body := _body(vlad)
	assert_near(bat._score_target(vlad), 130.0, EPS, "hero priority 100 + 50 (< 50 px) - 20")
	assert_near(hog._score_target(vlad), 90.0, EPS, "100 + 10 (150-300 px) - 20")
	assert_eq(bat._find_best_target(), vlad_body)
	vlad.target_entity = bat
	assert_near(bat._get_threat_score(vlad), 30.0, EPS, "Vlad targets the Bat")
	assert_near(bat._score_target(vlad), 160.0, EPS)
	vlad.target_entity = null
	# The Bat's max_chase_distance is 100: -100 beyond it.
	await _place(Vector2(120, 0), Vector2(0, 160))
	assert_near(bat._score_target(vlad), 10.0, EPS, "100 + 30 - 20 - 100")
	assert_eq(bat._find_best_target(), vlad_body, "still positive")
	await _place(Vector2(160, 0), Vector2(0, 160))
	assert_true(bat.detection_area.overlaps_area(vlad_body), "Vlad is still in the Bat's detection circle")
	assert_near(bat._score_target(vlad), -10.0, EPS, "100 + 10 - 20 - 100")
	assert_eq(bat._find_best_target(), null, "no positive score, no target")


func test_threat_terms() -> void:
	await _spawn_fixture()
	# +30: the candidate is targeting me.
	hog.target_entity = vlad
	assert_near(vlad._get_threat_score(hog), 30.0, EPS, "the Hog targets Vlad")
	assert_near(vlad._score_target(hog), 90.0, EPS)
	hog.target_entity = null
	# Focus fire: low_hp_focus_weight (60 on heroes) × missing HP, +15 below 30 %.
	assert_near(vlad.low_hp_focus_weight, 60.0, EPS, "HeroBaseClass.tscn")
	hog.current_health = 0.5 * hog.max_health
	assert_near(vlad._get_threat_score(hog), 30.0, EPS, "60 × 0.5")
	hog.current_health = 0.2 * hog.max_health
	assert_near(vlad._get_threat_score(hog), 63.0, EPS, "15 + 60 × 0.8")
	assert_near(vlad._score_target(hog), 123.0, EPS)
	assert_eq(bat.low_hp_focus_weight, 0.0, "mobs do not focus fire")
	hog.current_health = hog.max_health
	# Team blackboard: the Hog's threat on Vlad × threat_score_weight 1.5.
	TeamRegistry.get_team(TeamRegistry.HEROES).bump_threat(vlad, hog, 10.0)
	assert_near(vlad._get_threat_score(hog), 15.0, EPS, "10 × 1.5")
	_clear_targets_and_threat()
	# -20: my current target is past 400 px (fleeing).
	vlad.target = _body(hog)
	vlad.target_entity = hog
	hog.global_position = Vector2(0, 450)
	assert_near(vlad._get_threat_score(hog), -20.0, EPS, "current target fleeing")
	assert_near(vlad._score_target(hog), 40.0, EPS, "70 - 10 (300-500 px) - 20, no switch penalty")
	vlad.target = null
	vlad.target_entity = null
	assert_near(vlad._get_threat_score(hog), 0.0, EPS, "not my target: not fleeing")


func test_find_best_target_returns_the_top_scoring_body() -> void:
	await _spawn_fixture()
	assert_eq(vlad._find_best_target(), _body(bat), "Bat 100 beats Hog 60")
	hog.current_health = 0.2 * hog.max_health
	assert_eq(vlad._find_best_target(), _body(hog), "the wounded Hog: 123")
	hog.current_health = hog.max_health
	TeamRegistry.get_team(TeamRegistry.HEROES).bump_threat(vlad, hog, 40.0)
	assert_eq(vlad._find_best_target(), _body(hog), "blackboard threat: 60 + 40 × 1.5 = 120")


func test_reevaluate_switches_only_past_the_threshold() -> void:
	await _spawn_fixture()
	# No target yet: take the best.
	vlad._reevaluate_current_target(30.0)
	assert_eq(vlad.target_entity, bat)
	assert_eq(vlad.target, _body(bat))
	# Current Hog 80 (no switch penalty) vs Bat 100 (with it): 100 > 80 + 30 fails.
	vlad.target = _body(hog)
	vlad.target_entity = hog
	vlad._reevaluate_current_target(30.0)
	assert_eq(vlad.target_entity, hog, "a 20-point lead does not clear threshold 30")
	vlad._reevaluate_current_target(20.0)
	assert_eq(vlad.target_entity, hog, "strictly greater: a 20-point lead does not clear threshold 20")
	vlad._reevaluate_current_target(10.0)
	assert_eq(vlad.target_entity, bat, "a 20-point lead clears threshold 10")
	assert_eq(vlad.target, _body(bat))
	# Already on the best target: kept.
	vlad._reevaluate_current_target(30.0)
	assert_eq(vlad.target_entity, bat)


func test_reevaluate_pursues_out_of_sight_only_within_the_radius() -> void:
	await _spawn_fixture()
	await _place(Vector2(3000, 0), Vector2(0, 400))  # both outside Vlad's detection circle
	assert_eq(vlad._find_best_target(), null)
	vlad.target = _body(hog)
	vlad.target_entity = hog
	vlad._reevaluate_current_target(30.0)
	assert_eq(vlad.target_entity, hog, "400 px: within pursue_out_of_sight_radius 600")
	hog.global_position = Vector2(0, 700)
	vlad._reevaluate_current_target(30.0)
	assert_eq(vlad.target_entity, null, "700 px: dropped")
	assert_eq(vlad.target, null)
	# Mobs do not pursue out of sight (radius 0).
	bat.target = _body(vlad)
	bat.target_entity = vlad
	bat._reevaluate_current_target(30.0)
	assert_eq(bat.target_entity, null)


# ---------- fixture ----------

func _spawn_fixture() -> void:
	vlad = await spawn_frozen(VLAD, Vector2.ZERO) as HeroBase
	# HeroBase._process auto-casts outside the frozen AI: keep the mine and the ult out.
	vlad.auto_use_active = false
	vlad.auto_use_ultimate = false
	# MatchConfig's neutral farming (0.5); a saved choice from another test must not leak in.
	vlad.priority_mob = 70
	# Spawned out of everyone's detection so nothing fights during the spawn frames.
	bat = await spawn_frozen(BAT, Vector2(3000, 0)) as MobBase
	hog = await spawn_frozen(HOG, Vector2(-3000, 0)) as MobBase
	await _place(Vector2(40, 0), Vector2(0, 160))


## Vlad back at the origin and the mobs at exact positions; once the detection
## overlaps have caught up, every target and threat row is cleared.
func _place(bat_pos: Vector2, hog_pos: Vector2) -> void:
	_clear_targets_and_threat()
	vlad.global_position = Vector2.ZERO
	bat.global_position = bat_pos
	hog.global_position = hog_pos
	await wait_physics_frames(3)
	_clear_targets_and_threat()


func _clear_targets_and_threat() -> void:
	for e: EntityBase in [vlad, bat, hog]:
		e.target = null
		e.target_entity = null
	for team_name: StringName in [TeamRegistry.HEROES, TeamRegistry.ENEMIES]:
		var rows: Dictionary = TeamRegistry.get_team(team_name).threat
		for ally in rows:
			(rows[ally] as Dictionary).clear()


func _body(e: EntityBase) -> Area2D:
	return e.get_node(^"Body") as Area2D
