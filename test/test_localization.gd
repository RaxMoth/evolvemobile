extends TestCase

## strings.csv → .translation files are loaded; German resolves; fallback is English.

func test_german_translations_load_and_fallback_is_english() -> void:
	var loaded := TranslationServer.get_loaded_locales()
	assert_true(loaded.has("en"), "en loaded")
	assert_true(loaded.has("de"), "de loaded")
	var before := TranslationServer.get_locale()
	TranslationServer.set_locale("de")
	assert_eq(TranslationServer.translate("Settings"), "Einstellungen")
	assert_eq(TranslationServer.translate("Stage %d") % 2, "Stufe 2")
	assert_eq(TranslationServer.translate("not a key"), "not a key", "unknown keys pass through")
	TranslationServer.set_locale("en")
	assert_eq(TranslationServer.translate("Settings"), "Settings")
	TranslationServer.set_locale(before)


func test_locale_choice_persists_and_applies() -> void:
	if not OS.get_user_data_dir().contains("evolvemobile_tests"):
		skip("user:// is not the isolated test dir")
		return
	PersistedData.wipe_progress()
	LocaleSettings.set_choice_index(2)  # Deutsch
	assert_eq(LocaleSettings.get_choice(), "de")
	assert_eq(TranslationServer.get_locale(), "de")
	assert_eq(AudioSettings.label_for(AudioSettings.KEY_MUSIC), "Musik")
	LocaleSettings.set_choice_index(1)  # English
	assert_eq(TranslationServer.get_locale(), "en")
	assert_eq(AudioSettings.label_for(AudioSettings.KEY_MUSIC), "Music")
	LocaleSettings.set_choice_index(0)  # System → device language or English
	assert_true(TranslationServer.get_loaded_locales().has(TranslationServer.get_locale()))
