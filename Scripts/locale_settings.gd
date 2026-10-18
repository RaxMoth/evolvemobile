class_name LocaleSettings
extends RefCounted

## LocaleSettings — persisted language choice → TranslationServer.
## Translations live in res://Assets/Locale/strings.csv (keys = the English
## text, so scene `text` properties auto-translate and code uses tr(key)).
## Choice "" = follow the device language (falls back to English).

const KEY_LOCALE: StringName = &"locale"
const CHOICES: Array[String] = ["", "en", "de"]
const CHOICE_LABELS: Array[String] = ["System", "English", "Deutsch"]
const FALLBACK := "en"


static func apply_saved() -> void:
	apply_choice(get_choice())


static func get_choice() -> String:
	var saved: Variant = PersistedData.get_setting(KEY_LOCALE, "")
	var choice := String(saved) if saved is String else ""
	return choice if CHOICES.has(choice) else ""


static func choice_index() -> int:
	return CHOICES.find(get_choice())


static func set_choice_index(idx: int) -> void:
	var choice: String = CHOICES[clampi(idx, 0, CHOICES.size() - 1)]
	PersistedData.set_setting(KEY_LOCALE, choice)
	PersistedData.save_data()
	apply_choice(choice)


static func apply_choice(choice: String) -> void:
	var locale := choice if not choice.is_empty() else OS.get_locale_language()
	if not TranslationServer.get_loaded_locales().has(locale):
		locale = FALLBACK
	TranslationServer.set_locale(locale)
