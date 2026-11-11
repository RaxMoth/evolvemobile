class_name CodexScreen
extends Control

## The nav bar's Codex tab: what the player has learned, on three pages
## (TabButtons under the top bar):
##   - GUIDE: the walkthroughs as text (TutorialOverlay's camp and hunt
##     chapters, one card per step), REPLAY THE CAMP TOUR (guide_requested
##     lobby: MenuRoot goes home and plays the coach marks) and SHOW THE HUNT
##     TIPS AGAIN (guide_requested hud: the next match plays them; disabled
##     while they are still to come);
##   - MONSTERS: a CodexEntry per quarry the heroes have met, in the order
##     they were first met (PersistedData [codex] monsters, which
##     GameManager.begin_hunt fills on a first sighting): tagline, field notes,
##     evolution stages, counterplay and abilities; the roster's other monsters
##     follow as locked pages ("???" and when they turn up);
##   - HEROES: a CodexEntry per roster hero.
## Opening the Codex marks every monster page as seen (SETTING_SEEN_MONSTERS);
## until then MenuRoot lights the nav bars' Codex dot and the Codex opens on
## MONSTERS. The screen only reports: MenuRoot calls open() before it slides
## the screen in and connects every signal in MenuRoot.tscn; every connection
## inside the screen is in CodexScreen.tscn (the entries and guide cards are
## built here).

signal back_requested
signal tab_selected(tab_id: StringName)
## Replay a walkthrough (TutorialOverlay.CHAPTER_LOBBY / CHAPTER_HUD).
signal guide_requested(chapter: StringName)

const ENTRY_SCENE := preload("res://Scenes/UI/Components/CodexEntry.tscn")
const PAGE_GUIDE: StringName = &"guide"
const PAGE_MONSTERS: StringName = &"monsters"
const PAGE_HEROES: StringName = &"heroes"
## How many monster pages the player has seen (the count of [codex] monsters
## when the Codex was last opened).
const SETTING_SEEN_MONSTERS: StringName = &"codex_seen_monsters"
## The nav bar tab this screen is.
const OWN_TAB: StringName = &"codex"

## The page shown.
var page: StringName = PAGE_GUIDE

## The monster pages in shown order (met first), and the hero pages.
var _monster_entries: Array[CodexEntry] = []
var _hero_entries: Array[CodexEntry] = []
var _built := false
## Made here, not as a scene sub-resource (see RosterScreen).
var _page_group := ButtonGroup.new()

@onready var _top_bar: TopBar = %TopBar
@onready var _nav: NavBar = %NavBar
@onready var _pages: Dictionary[StringName, Control] = {
	PAGE_GUIDE: %GuidePage,
	PAGE_MONSTERS: %MonstersPage,
	PAGE_HEROES: %HeroesPage,
}
@onready var _tabs: Dictionary[StringName, Button] = {
	PAGE_GUIDE: %GuideTab,
	PAGE_MONSTERS: %MonstersTab,
	PAGE_HEROES: %HeroesTab,
}
@onready var _camp_steps: VBoxContainer = %CampSteps
@onready var _hunt_steps: VBoxContainer = %HuntSteps
@onready var _monster_list: VBoxContainer = %MonsterList
@onready var _hero_list: VBoxContainer = %HeroList
@onready var _met_count: Label = %MetCount
@onready var _scroll: ScrollContainer = %Scroll
@onready var _replay_hunt: Button = %ReplayHunt


func _ready() -> void:
	_top_bar.title = "Codex"
	_top_bar.show_steel = false
	_top_bar.show_leaves = false
	_nav.active_tab = OWN_TAB
	for id: StringName in _tabs:
		_tabs[id].button_group = _page_group
	show_page(page)


## Monster pages met since the Codex was last opened (the nav bar's dot).
static func unseen_monsters() -> int:
	var met := PersistedData.get_codex_entries(PersistedData.CODEX_MONSTERS).size()
	return maxi(0, met - int(PersistedData.get_setting(SETTING_SEEN_MONSTERS, 0)))


## Before the screen slides in: builds the pages on the first visit, re-reads
## what has been met and marks it seen. New monster pages open on MONSTERS.
func open() -> void:
	var fresh := unseen_monsters() > 0
	if not _built:
		_build_guide()
		_built = true
	refresh()
	_replay_hunt.disabled = not TutorialOverlay.has_been_seen(TutorialOverlay.CHAPTER_HUD)
	_nav.monster_side = GameManager.chosen_side == MatchRewards.Side.MONSTER
	_nav.active_tab = OWN_TAB
	PersistedData.set_setting(SETTING_SEEN_MONSTERS, PersistedData.get_codex_entries(PersistedData.CODEX_MONSTERS).size())
	PersistedData.save_data()
	show_page(PAGE_MONSTERS if fresh else page)


## Rebuilds the monster and hero pages from the save (met monsters first, in
## the order they were met).
func refresh() -> void:
	_clear(_monster_list)
	_clear(_hero_list)
	_monster_entries.clear()
	_hero_entries.clear()
	var met_ids := PersistedData.get_codex_entries(PersistedData.CODEX_MONSTERS)
	var met := 0
	for id in met_ids:
		var def := GameManager.ROSTER.find(id)
		if def != null and def.is_monster():
			_monster_entries.append(_add_entry(_monster_list, def, true))
			met += 1
	for def in GameManager.ROSTER.monsters:
		if def != null and not met_ids.has(def.character_id()):
			_monster_entries.append(_add_entry(_monster_list, def, false, _unmet_note(def)))
	_met_count.text = tr("Beasts met %d / %d") % [met, GameManager.ROSTER.monsters.size()]
	for def in GameManager.ROSTER.heroes:
		if def != null:
			_hero_entries.append(_add_entry(_hero_list, def, true))


## Shows one page (PAGE_*) and lights its tab.
func show_page(id: StringName) -> void:
	page = id if _pages.has(id) else PAGE_GUIDE
	for key: StringName in _pages:
		_pages[key].visible = key == page
		# set_pressed_no_signal does not release the group's other buttons.
		_tabs[key].set_pressed_no_signal(key == page)
	_scroll.scroll_vertical = 0


func monster_entries() -> Array[CodexEntry]:
	return _monster_entries


func hero_entries() -> Array[CodexEntry]:
	return _hero_entries


## The guide's step cards of one chapter (their titles), in order.
func guide_titles(chapter: StringName) -> PackedStringArray:
	var out := PackedStringArray()
	var box := _hunt_steps if chapter == TutorialOverlay.CHAPTER_HUD else _camp_steps
	for card in box.get_children():
		out.append((card.get_node(^"Row/Text/Title") as Label).text)
	return out


## "Appears after 3 hunts", or how to meet a monster already in the pool.
static func _unmet_note(def: CharacterDef) -> String:
	var hunts := GameManager.hunts_until_quarry(def)
	if hunts == 1:
		return TranslationServer.translate("Not met yet. It joins the hunt after 1 more hunt.")
	if hunts > 1:
		return TranslationServer.translate("Not met yet. It joins the hunt after %d more hunts.") % hunts
	return TranslationServer.translate("Not met yet. Hunt it to fill this page.")


func _add_entry(list: VBoxContainer, def: CharacterDef, met: bool, note: String = "") -> CodexEntry:
	var entry := ENTRY_SCENE.instantiate() as CodexEntry
	list.add_child(entry)
	entry.show_entry(def, met, note)
	return entry


func _build_guide() -> void:
	_fill_steps(_camp_steps, TutorialOverlay.steps_of(TutorialOverlay.CHAPTER_LOBBY))
	_fill_steps(_hunt_steps, TutorialOverlay.steps_of(TutorialOverlay.CHAPTER_HUD))


## One PanelInset card per step: its number on a chip, its title and body.
func _fill_steps(box: VBoxContainer, steps: Array[Dictionary]) -> void:
	_clear(box)
	var n := 1
	for step in steps:
		var card := PanelContainer.new()
		card.theme_type_variation = &"PanelInset"
		var row := HBoxContainer.new()
		row.name = "Row"
		row.add_theme_constant_override(&"separation", 14)
		var chip := PanelContainer.new()
		chip.theme_type_variation = &"ChipPanel"
		chip.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		var number := Label.new()
		number.theme_type_variation = &"AmberLabel"
		number.text = str(n)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number.custom_minimum_size = Vector2(28, 0)
		chip.add_child(number)
		row.add_child(chip)
		var text := VBoxContainer.new()
		text.name = "Text"
		text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := Label.new()
		title.name = "Title"
		title.theme_type_variation = &"HeaderSmall"
		title.text = String(step.get("title", ""))
		text.add_child(title)
		var body := Label.new()
		body.theme_type_variation = &"BodyDim"
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.text = String(step.get("body", ""))
		text.add_child(body)
		row.add_child(text)
		card.add_child(row)
		box.add_child(card)
		n += 1


static func _clear(box: Node) -> void:
	for child in box.get_children():
		box.remove_child(child)
		child.queue_free()


# --- scene-side connections (CodexScreen.tscn) ---

func _on_top_bar_left_pressed() -> void:
	back_requested.emit()


func _on_page_pressed(id: StringName) -> void:
	show_page(id)


func _on_replay_camp_pressed() -> void:
	guide_requested.emit(TutorialOverlay.CHAPTER_LOBBY)


func _on_replay_hunt_pressed() -> void:
	guide_requested.emit(TutorialOverlay.CHAPTER_HUD)
	_replay_hunt.disabled = true


## The screen stays on its own tab: a tab that does not leave (HUNT's
## pre-round) must not leave another one lit.
func _on_nav_bar_tab_selected(tab_id: StringName) -> void:
	tab_selected.emit(tab_id)
	_nav.active_tab = OWN_TAB
