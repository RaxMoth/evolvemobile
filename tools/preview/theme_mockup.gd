extends Control
## Art-direction proof sheet: every Jungle Guild theme type and kit piece,
## composed the way the collection and HUD screens will use them. Not a
## production screen and not shipped (tools/): the real screens wire this
## scene-side; this only proves that the theme, the SVG kit, the icons and the
## two UI shaders render together.
## Render muted on a copy of the project:
##   godot --path <copy> --audio-driver Dummy --fixed-fps 30
##         --write-movie <dir>/f.png --quit-after 8 res://tools/preview/ThemeMockup.tscn
##
## Card portraits are stand-ins until the rig portraits land (Phase 2): the
## character's role glyph in its UiPalette signature colour.

const UI := "res://Assets/UI/"
const LOCKED_SHADER := preload("res://Assets/UI/Shaders/card_locked.gdshader")
const COOLDOWN_SHADER := preload("res://Assets/UI/Shaders/ability_cooldown.gdshader")
const CARD_SIZE := Vector2(164, 254)
const MONSTER_IDS: Array[String] = ["grount", "nyxa", "gorrak"]
## Stand-in portrait glyph per character id (Icons/Roles).
const ROLE_GLYPHS: Dictionary[String, String] = {
	"irelia": "role_tank",
	"vlad": "role_melee",
	"ted": "role_summoner",
	"river": "role_support",
	"grount": "role_brute",
	"nyxa": "role_stalker",
	"gorrak": "role_tank",
}
## Card kind -> frame variation.
const CARD_FRAMES: Dictionary[StringName, StringName] = {
	&"hero": &"CharacterCard",
	&"ready": &"CharacterCard",
	&"selected": &"CharacterCardSelected",
	&"monster": &"CharacterCardMonster",
	&"monster_ready": &"CharacterCardMonster",
	&"unlockable": &"CharacterCardMonster",
	&"locked": &"CharacterCardLocked",
}

@onready var _root: VBoxContainer = $Margin/Root


func _ready() -> void:
	_root.add_child(_top_bar())
	_root.add_child(_section("HEROES", &"BannerHero"))
	_root.add_child(_filters())
	var heroes := _grid()
	heroes.add_child(_card("irelia", &"hero", 3, 0.0, "0/1"))
	heroes.add_child(_card("vlad", &"ready", 2, 1.0, "1/1"))
	heroes.add_child(_card("ted", &"selected", 1, 0.5, "1/2"))
	heroes.add_child(_card("river", &"hero", 1, 0.0, "0/1"))
	_root.add_child(heroes)
	_root.add_child(_section("MONSTERS", &"BannerMonster"))
	var monsters := _grid()
	monsters.add_child(_card("grount", &"monster", 4, 0.3, "1/3"))
	monsters.add_child(_card("nyxa", &"monster_ready", 2, 1.0, "1/1"))
	monsters.add_child(_card("gorrak", &"unlockable", 0, 0.0, "3,000"))
	monsters.add_child(_card("", &"locked", 0, 0.0, ""))
	_root.add_child(monsters)
	_root.add_child(_hud_row())
	_root.add_child(_monster_slots_row())
	_root.add_child(_buttons_row())
	_root.add_child(_bars_row())
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root.add_child(spacer)
	add_child(_nav_bar())


func _svg(path: String) -> Texture2D:
	return load(UI + path + ".svg") as Texture2D


func _tex(path: String, px: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.texture = _svg(path)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = px
	return t


func _label(text: String, variation: StringName) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _grid() -> GridContainer:
	var g := GridContainer.new()
	g.columns = 4
	g.add_theme_constant_override("h_separation", 10)
	g.add_theme_constant_override("v_separation", 10)
	return g


## Stand-in portrait: the role glyph in the character's signature colour.
func _portrait(id: String, px: Vector2) -> TextureRect:
	var t := _tex("Icons/Roles/" + ROLE_GLYPHS[id], px)
	t.self_modulate = UiPalette.signature(id, id in MONSTER_IDS)
	return t


func _top_bar() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(_tex("Crests/crest_heroes", Vector2(58, 64)))
	h.add_child(_tex("Crests/crest_monster", Vector2(58, 64)))
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(s)
	for c: Array in [["currency_gold", "1,240"], ["currency_steel", "85"], ["currency_leaves", "312"]]:
		var pill := PanelContainer.new()
		pill.theme_type_variation = &"CurrencyPill"
		var row := HBoxContainer.new()
		row.add_child(_tex("Icons/Currency/" + str(c[0]), Vector2(34, 34)))
		row.add_child(_label(str(c[1]), &"Counter"))
		pill.add_child(row)
		pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(pill)
	return h


func _section(title: String, variation: StringName) -> Control:
	var c := CenterContainer.new()
	var b := PanelContainer.new()
	b.theme_type_variation = variation
	b.custom_minimum_size = Vector2(300, 56)
	b.add_child(_label(title, &"BannerTitle"))
	c.add_child(b)
	return c


func _filters() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 6)
	var group := ButtonGroup.new()
	for r: String in ["role_all", "role_tank", "role_melee", "role_ranged", "role_support", "role_summoner"]:
		var b := Button.new()
		b.theme_type_variation = &"FilterTab"
		b.icon = _svg("Icons/Roles/" + r)
		b.toggle_mode = true
		b.button_group = group
		b.custom_minimum_size = Vector2(56, 50)
		b.expand_icon = true
		b.button_pressed = r == "role_all"
		h.add_child(b)
	return h


## One collection card. kind: hero / ready (red pill + dot) / selected,
## monster / monster_ready, unlockable (colour at 35 % under the padlock, with
## its price) and locked (silhouette, padlock, "???").
func _card(id: String, kind: StringName, level: int, prog: float, prog_text: String) -> Control:
	var is_monster := id in MONSTER_IDS or kind == &"locked"
	var holder := Control.new()
	holder.custom_minimum_size = CARD_SIZE
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_FULL_RECT)
	card.theme_type_variation = CARD_FRAMES[kind]
	holder.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	card.add_child(v)
	var inner := PanelContainer.new()
	if kind == &"locked":
		inner.theme_type_variation = &"CardInnerLocked"
	else:
		inner.theme_type_variation = &"CardInnerMonster" if is_monster else &"CardInnerHero"
	inner.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(inner)
	if kind == &"locked":
		var crest := _tex("Crests/crest_monster", Vector2(120, 140))
		var m := ShaderMaterial.new()
		m.shader = LOCKED_SHADER
		crest.material = m
		inner.add_child(crest)
		inner.add_child(_padlock())
		v.add_child(_label("???", &"CardName"))
		return holder
	var portrait := _portrait(id, Vector2(120, 140))
	inner.add_child(portrait)
	v.add_child(_label(id.capitalize(), &"CardName"))
	if kind == &"unlockable":
		portrait.self_modulate.a = 0.35
		inner.add_child(_padlock())
		var price := HBoxContainer.new()
		price.alignment = BoxContainer.ALIGNMENT_CENTER
		price.add_child(_tex("Icons/Currency/currency_leaves", Vector2(28, 28)))
		price.add_child(_label(prog_text, &"Counter"))
		v.add_child(price)
		return holder
	var lv := _label("Lv.%d" % level, &"CardLevel")
	lv.custom_minimum_size.y = 30
	v.add_child(lv)
	var upgrade_ready := kind == &"ready" or kind == &"monster_ready"
	var pill := ProgressBar.new()
	pill.theme_type_variation = &"PillProgressReady" if upgrade_ready else &"PillProgress"
	pill.show_percentage = false
	pill.max_value = 1.0
	pill.value = prog
	pill.custom_minimum_size = Vector2(96, 24)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var pl := _label(prog_text, &"PillText")
	pl.set_anchors_preset(Control.PRESET_FULL_RECT)
	pill.add_child(pl)
	v.add_child(pill)
	var pad := Control.new()
	pad.custom_minimum_size.y = 4
	v.add_child(pad)
	if upgrade_ready:
		var dot := _tex("Kit/dot_notify", Vector2(26, 26))
		dot.position = Vector2(CARD_SIZE.x - 18.0, -8.0)
		dot.size = Vector2(26, 26)
		holder.add_child(dot)
	return holder


func _padlock() -> TextureRect:
	var lock := _tex("Kit/padlock", Vector2(54, 64))
	lock.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return lock


## An ability icon under the cooldown shader inside a slot frame. progress
## 0 = just cast, 1 = ready; number = the CooldownNumber label.
func _slot(icon: String, frame: String, progress: float, number: String, locked: bool, flash: float = 0.0) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(68, 68)
	var ic := _tex("Icons/Abilities/" + icon, Vector2(60, 60))
	ic.position = Vector2(4, 4)
	ic.size = Vector2(60, 60)
	var m := ShaderMaterial.new()
	m.shader = COOLDOWN_SHADER
	m.set_shader_parameter("progress", progress)
	m.set_shader_parameter("locked", 1.0 if locked else 0.0)
	m.set_shader_parameter("ready_flash", flash)
	ic.material = m
	c.add_child(ic)
	var fr := _tex("Kit/" + frame, Vector2(68, 68))
	fr.size = Vector2(68, 68)
	c.add_child(fr)
	if number != "":
		var l := _label(number, &"CooldownNumber")
		l.size = Vector2(68, 68)
		c.add_child(l)
	if locked:
		var lk := _tex("Icons/UI/ui_lock", Vector2(30, 30))
		lk.position = Vector2(19, 19)
		lk.size = Vector2(30, 30)
		c.add_child(lk)
	return c


func _hud_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var hero := PanelContainer.new()
	hero.theme_type_variation = &"HudPanelSelected"
	var hv := VBoxContainer.new()
	var top := HBoxContainer.new()
	top.add_child(_portrait("irelia", Vector2(44, 44)))
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tv.add_child(_label("Irelia  Lv.3", &"HeroAccentLabel"))
	var hp := ProgressBar.new()
	hp.theme_type_variation = &"HpBarHero"
	hp.value = 72
	hp.show_percentage = false
	hp.custom_minimum_size = Vector2(0, 16)
	tv.add_child(hp)
	top.add_child(tv)
	hv.add_child(top)
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 4)
	slots.add_child(_slot("irelia_passive_regeneration", "slot_passive", 1.0, "", false))
	slots.add_child(_slot("irelia_active_divine_shield", "slot_active", 0.35, "8", false))
	slots.add_child(_slot("irelia_basic_taunting_strike", "slot_basic", 0.8, "", false))
	slots.add_child(_slot("irelia_ult_monster_taunt", "slot_ult", 1.0, "", false))
	hv.add_child(slots)
	hero.add_child(hv)
	h.add_child(hero)
	var mon := PanelContainer.new()
	mon.theme_type_variation = &"HudPanel"
	var mv := VBoxContainer.new()
	mv.add_child(_label("Grount  Stage 1", &"MonsterAccentLabel"))
	var mhp := ProgressBar.new()
	mhp.theme_type_variation = &"HpBarMonster"
	mhp.value = 45
	mhp.show_percentage = false
	mhp.custom_minimum_size = Vector2(0, 16)
	mv.add_child(mhp)
	var ms := HBoxContainer.new()
	ms.add_theme_constant_override("separation", 4)
	ms.add_child(_slot("grount_front_cleave", "slot_basic", 0.6, "2", false))
	ms.add_child(_slot("grount_ram_dash", "slot_active", 1.0, "", false))
	ms.add_child(_slot("grount_ground_slam", "slot_locked", 1.0, "", true))
	ms.add_child(_slot("grount_passive_evolution", "slot_passive", 1.0, "", false))
	mv.add_child(ms)
	mon.add_child(mv)
	h.add_child(mon)
	return h


## Nyxa's and Gorrak's ability icons (monster slots 2 and 3) in their frames.
func _monster_slots_row() -> Control:
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	h.add_child(_label("Nyxa", &"MonsterAccentLabel"))
	h.add_child(_slot("nyxa_basic_sonic_screech", "slot_basic", 0.45, "3", false))
	h.add_child(_slot("nyxa_active_shadow_swoop", "slot_active", 1.0, "", false, 0.5))
	h.add_child(_slot("nyxa_ult_night_swarm", "slot_locked", 1.0, "", true))
	var gap := Control.new()
	gap.custom_minimum_size.x = 18
	h.add_child(gap)
	h.add_child(_label("Gorrak", &"MonsterAccentLabel"))
	h.add_child(_slot("gorrak_basic_cleaver_chop", "slot_basic", 1.0, "", false))
	h.add_child(_slot("gorrak_active_tusk_axe", "slot_active", 0.7, "5", false))
	h.add_child(_slot("gorrak_ult_warcry_stomp", "slot_ult", 0.15, "12", false))
	return h


func _buttons_row() -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	for b: Array in [["HUNT!", &"ButtonPrimary", ""], ["Upgrade", &"ButtonCopper", "Icons/Currency/currency_steel"],
			["Heroes", &"ButtonHero", ""], ["Monster", &"ButtonMonster", ""]]:
		var bt := Button.new()
		bt.text = str(b[0])
		bt.theme_type_variation = b[1]
		if str(b[2]) != "":
			bt.icon = _svg(str(b[2]))
		bt.custom_minimum_size = Vector2(0, 60)
		h.add_child(bt)
	for r: Array in [["Icons/UI/ui_pause", &"ButtonRound"], ["Icons/UI/ui_fast_forward", &"ButtonRoundPrimary"]]:
		var rb := Button.new()
		rb.icon = _svg(str(r[0]))
		rb.theme_type_variation = r[1]
		rb.custom_minimum_size = Vector2(60, 64)
		rb.expand_icon = true
		h.add_child(rb)
	return h


func _bars_row() -> Control:
	var g := GridContainer.new()
	g.columns = 2
	g.add_theme_constant_override("h_separation", 12)
	for b: Array in [["stat_hp", &"HpBarHero", 80.0], ["stat_threat", &"HpBarMonster", 35.0],
			["stat_xp", &"XpBar", 55.0], ["stat_cooldown", &"CooldownBar", 30.0]]:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_tex("Icons/Stats/" + str(b[0]), Vector2(30, 30)))
		var pb := ProgressBar.new()
		pb.theme_type_variation = b[1]
		pb.value = float(b[2])
		pb.custom_minimum_size = Vector2(0, 20)
		pb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pb.show_percentage = false
		row.add_child(pb)
		g.add_child(row)
	return g


func _nav_bar() -> Control:
	var bar := PanelContainer.new()
	bar.theme_type_variation = &"NavBar"
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -132
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var h := HBoxContainer.new()
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 4)
	var group := ButtonGroup.new()
	for t: Array in [["Heroes", "nav_heroes", &"NavPlaque"], ["Growth", "nav_growth", &"NavPlaque"],
			["HUNT", "nav_hunt", &"NavArch"], ["Codex", "nav_codex", &"NavPlaque"], ["Monsters", "nav_monsters", &"NavPlaque"]]:
		var holder := Control.new()
		var arch: bool = t[2] == &"NavArch"
		holder.custom_minimum_size = Vector2(150, 120) if arch else Vector2(124, 118)
		var b := Button.new()
		b.text = str(t[0])
		b.icon = _svg("Icons/Nav/" + str(t[1]))
		b.theme_type_variation = t[2]
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = arch
		b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		b.expand_icon = true
		b.set_anchors_preset(Control.PRESET_FULL_RECT)
		if arch:
			b.offset_top = -44
		holder.add_child(b)
		if t[0] == "Growth":
			var dot := _tex("Kit/dot_notify", Vector2(24, 24))
			dot.position = Vector2(98, 0)
			dot.size = Vector2(24, 24)
			holder.add_child(dot)
		h.add_child(holder)
	v.add_child(h)
	var prog := ProgressBar.new()
	prog.theme_type_variation = &"NavProgress"
	prog.show_percentage = false
	prog.value = 62
	prog.custom_minimum_size = Vector2(0, 4)
	v.add_child(prog)
	bar.add_child(v)
	return bar
