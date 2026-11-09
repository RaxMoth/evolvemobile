extends TestCase

## The MatchHud's event toasts and the HUD juice: the toast texts (EN/DE through
## strings.csv), the toast queue (at most one visible, the pop-in and fade, the
## pending cap, dropped unqueued toasts, no duplicates), the scene-wired
## MatchAnnouncer (monster evolved, hero fell, ultimate cast with its repeat
## guard) and the level badge's pop on a level-up.

const WORLD := "res://Scenes/World/World.tscn"
const HUD := "res://Scenes/UI/Hud/MatchHud.tscn"
const CARD := "res://Scenes/UI/Hud/HeroHudCard.tscn"
const VLAD_ULT := "res://Scenes/NPCs/Hero/Heros/DMG/Vlad/Abilities/ult/ult.tres"


func test_toast_texts_in_english_and_german() -> void:
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	assert_eq(MatchAnnouncer.evolved_text("Grount", 2), "GROUNT EVOLVED · STAGE II")
	assert_eq(MatchAnnouncer.evolved_text("Grount", 3), "GROUNT EVOLVED · STAGE III")
	assert_eq(MatchAnnouncer.fallen_text("Vlad"), "VLAD HAS FALLEN")
	assert_eq(MatchAnnouncer.ultimate_text(load(VLAD_ULT) as AbilityBase), "BLOOD BOMB", "the ultimate's name")
	TranslationServer.set_locale("de")
	assert_eq(MatchAnnouncer.evolved_text("Grount", 2), "GROUNT ENTWICKELT · STUFE II")
	assert_eq(MatchAnnouncer.fallen_text("Vlad"), "VLAD IST GEFALLEN")
	TranslationServer.set_locale(before)


func test_toast_queue_shows_one_at_a_time() -> void:
	var hud := (load(HUD) as PackedScene).instantiate() as MatchHud
	add_child(hud)
	await wait_frames(3)  # the HUD binds two frames after _ready
	var toast := hud.get_node(^"%Toast") as Control
	var label := hud.get_node(^"%ToastText") as Label
	assert_false(toast.visible, "no toast at start")
	assert_eq(toast.theme_type_variation, &"BannerMonster", "the crimson ribbon")

	hud.show_toast("A")
	assert_eq(hud.current_toast(), "A")
	assert_true(toast.visible and label.text == "A", "the first toast shows at once")
	assert_near(toast.scale.x, MatchHud.TOAST_POP_FROM, 0.001, "it pops from 0.7")
	assert_near(toast.modulate.a, 0.0, 0.001, "and fades in")
	assert_eq(toast.pivot_offset_ratio, Vector2(0.5, 0.5), "around its centre")
	await wait_frames(1)  # the ToastBar centres it
	var bar := toast.get_parent_control()
	assert_near(bar.global_position.y + toast.position.y, 250.0, 0.5, "the ribbon's top at y 250")
	assert_near(bar.global_position.x + toast.position.x + toast.size.x * 0.5,
		hud.get_viewport().get_visible_rect().size.x * 0.5, 0.5, "centred")
	hud.show_toast("B")
	hud.show_toast("A")
	hud.show_toast("B")
	hud.show_toast("ult", false)
	assert_eq(hud.pending_toasts(), PackedStringArray(["B"]), "B waits; duplicates and the unqueued one are dropped")
	hud.show_toast("C")
	hud.show_toast("D")
	hud.show_toast("E")
	assert_eq(hud.pending_toasts(), PackedStringArray(["C", "D", "E"]), "a full line drops its oldest")

	var tween := hud._toast_tween
	tween.custom_step(MatchHud.TOAST_POP)
	assert_near(toast.scale.x, 1.0, 0.001, "full size after the pop")
	assert_near(toast.modulate.a, 1.0, 0.001, "opaque")
	tween.custom_step(MatchHud.TOAST_HOLD + MatchHud.TOAST_FADE_OUT * 0.5)
	assert_eq(hud.current_toast(), "A", "still A while it fades")
	assert_true(toast.modulate.a < 1.0, "fading out")
	tween.custom_step(MatchHud.TOAST_FADE_OUT)
	assert_eq(hud.current_toast(), "C", "the next toast follows")
	assert_true(toast.visible and label.text == "C")
	assert_near(toast.scale.x, MatchHud.TOAST_POP_FROM, 0.001, "and pops in again")
	assert_eq(hud.pending_toasts(), PackedStringArray(["D", "E"]))

	_flush(hud)
	assert_eq(hud.current_toast(), "", "the line ran empty")
	assert_false(toast.visible, "the ribbon hides")
	hud.show_toast("ult", false)
	assert_eq(hud.current_toast(), "ult", "an unqueued toast shows when nothing else is up")
	_flush(hud)
	hud.queue_free()
	await wait_frames(1)


func test_announcer_feeds_the_hud_from_match_events() -> void:
	var side_before: int = GameManager.chosen_side
	var locale_before := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	GameManager.chosen_side = MatchRewards.Side.HEROES
	var world := (load(WORLD) as PackedScene).instantiate()
	add_child(world)
	var hud := (world.get_node("MainCam") as GameCamera).hud
	for i in range(60):  # the HUD binds two frames after _ready
		if hud.cards.size() == 4:
			break
		await wait_frames(1)
	GameManager.match_ended_flag = true  # a hero's death must not end the match
	var announcer := hud.get_node(^"Announcer") as MatchAnnouncer
	assert_true(announcer != null, "MatchHud has its Announcer")
	var wired := false
	for c in announcer.get_signal_connection_list(&"announced"):
		var callable: Callable = c["callable"]
		if callable.get_object() == hud and callable.get_method() == &"show_toast":
			wired = (int(c["flags"]) & CONNECT_PERSIST) != 0
	assert_true(wired, "announced -> show_toast is a scene connection")
	_flush(hud)

	# The monster evolves: its CharacterDef name and the stage numeral.
	var grount := (world.get_node("MonsterSlot") as MonsterSlot).monster as MonsterBase
	grount.gain_xp(1000.0)
	assert_eq(grount.get_stage(), 2)
	var evolved := MatchAnnouncer.evolved_text(GameManager.ROSTER.find(&"grount").get_display_name(), 2)
	assert_eq(evolved, "GROUNT EVOLVED · STAGE II")
	assert_eq(hud.current_toast(), evolved, "the evolution toast shows")

	# A hero falls while it shows: queued behind it.
	var card := hud.cards[1]
	var hero := card.hero as HeroBase
	var fallen := MatchAnnouncer.fallen_text(GameManager.ROSTER.find(MetaSkillManager.hero_id_of(hero)).get_display_name())
	_kill(hero)
	assert_eq(hud.pending_toasts(), PackedStringArray([fallen]), "the fall waits its turn")

	# An ultimate while toasts are up is dropped, not queued.
	var caster := hud.cards[0].hero as HeroBase
	var system := caster.get_node("AbilitySystem") as AbilitySystem
	var ult := system.ultimate_ability
	EventBus.notify_ability_cast(caster, ult, null)
	assert_eq(hud.pending_toasts().size(), 1, "the ultimate does not queue")
	_flush(hud)

	# Idle: the ultimate shows its name (no guard: the dropped cast above
	# started one); the same one again inside the guard does not; a
	# non-ultimate never does.
	announcer.ultimate_repeat_guard = 0.0
	EventBus.notify_ability_cast(caster, ult, null)
	assert_eq(hud.current_toast(), MatchAnnouncer.ultimate_text(ult), "the ultimate's name")
	_flush(hud)
	announcer.ultimate_repeat_guard = 1000.0
	EventBus.notify_ability_cast(caster, ult, null)
	assert_eq(hud.current_toast(), "", "the repeat guard holds it back")
	EventBus.notify_ability_cast(caster, system.active_ability, null)
	assert_eq(hud.current_toast(), "", "actives are no news")
	announcer.ultimate_repeat_guard = 0.0
	EventBus.notify_ability_cast(caster, ult, null)
	assert_eq(hud.current_toast(), MatchAnnouncer.ultimate_text(ult), "past the guard it shows again")
	_flush(hud)

	# Switched off per export.
	announcer.announce_evolutions = false
	grount.gain_xp(10000.0)
	assert_eq(grount.get_stage(), 3)
	assert_eq(hud.current_toast(), "", "announce_evolutions off")

	# The level badge pops on a real level-up, and only then.
	var badge := hud.cards[0].get_node(^"%LevelBadge") as Control
	assert_near(badge.scale.x, 1.0, 0.001, "no pop at bind")
	var stats := caster.get_node("HeroStats") as HeroStatsComponent
	var level := stats.level
	stats.add_xp(HeroStatsComponent.XP_PER_LEVEL)
	assert_eq((hud.cards[0].get_node(^"%LevelText") as Label).text, str(level + 1))
	assert_near(badge.scale.x, HeroHudCard.LEVEL_POP, 0.001, "the badge pops to 1.4")
	hud.cards[0]._level_pop.custom_step(HeroHudCard.LEVEL_POP_TIME)
	assert_near(badge.scale.x, 1.0, 0.001, "and settles back")

	world.queue_free()
	await wait_frames(2)
	GameManager.chosen_side = side_before
	GameManager.match_ended_flag = true
	TranslationServer.set_locale(locale_before)
	AudioManager.stop_music()  # World started the match music


func test_level_badge_pop_restarts() -> void:
	var card := (load(CARD) as PackedScene).instantiate() as HeroHudCard
	add_child(card)
	await wait_frames(1)
	var badge := card.get_node(^"%LevelBadge") as Control
	assert_eq(badge.pivot_offset_ratio, Vector2(0.5, 0.5), "it pops around its centre")
	card._on_leveled_up(4)
	card._level_pop.custom_step(0.05)
	assert_true(badge.scale.x < HeroHudCard.LEVEL_POP and badge.scale.x > 1.0, "settling")
	card._on_leveled_up(5)
	assert_near(badge.scale.x, HeroHudCard.LEVEL_POP, 0.001, "a second level-up pops again")
	assert_eq((card.get_node(^"%LevelText") as Label).text, "5")
	card.queue_free()
	await wait_frames(1)


## Runs the toast line to its end (each toast's tween to completion).
func _flush(hud: MatchHud) -> void:
	for i in range(MatchHud.TOAST_MAX_PENDING + 2):
		if hud._toast_tween == null:
			return
		hud._toast_tween.custom_step(10.0)


func _kill(hero: HeroBase) -> void:
	for i in range(5):  # a Divine Shield may absorb the first hit
		if not hero.is_alive():
			break
		EventBus.deal_damage(null, hero, 1.0e7)
	assert_false(hero.is_alive(), "%s is dead" % hero.name)
