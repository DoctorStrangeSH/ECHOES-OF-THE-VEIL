extends Node
## Loads player-facing strings from res://data/localization/*.json and
## registers them with TranslationServer, so `tr("KEY")` works everywhere.
## JSON (not CSV import) keeps the source diff-friendly and export-safe.
## Owner: localization. Test: tests/run_tests.gd (missing keys, both locales).

const STRINGS_DIR := "res://data/localization"
const SUPPORTED_LOCALES: PackedStringArray = ["en", "ru"]
const FALLBACK_LOCALE := "en"

var _translations: Dictionary = {}  # locale -> Translation


func _enter_tree() -> void:
	load_all()
	var os_lang := OS.get_locale_language()
	set_locale(os_lang if os_lang in SUPPORTED_LOCALES else FALLBACK_LOCALE)


func load_all() -> void:
	for locale in SUPPORTED_LOCALES:
		var t := Translation.new()
		t.locale = locale
		_translations[locale] = t
	var dir := DirAccess.open(STRINGS_DIR)
	if dir == null:
		push_error("Localization: cannot open %s" % STRINGS_DIR)
		return
	for file_name in dir.get_files():
		if file_name.get_extension() == "json":
			_load_file(STRINGS_DIR.path_join(file_name))
	for locale: String in _translations:
		TranslationServer.add_translation(_translations[locale])


func _load_file(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		push_error("Localization: %s is not a JSON object" % path)
		return
	for key: String in data:
		var entry: Variant = data[key]
		if not entry is Dictionary:
			push_error("Localization: %s has a malformed entry '%s'" % [path, key])
			continue
		for locale: String in entry:
			if _translations.has(locale):
				(_translations[locale] as Translation).add_message(key, entry[locale])


func set_locale(locale: String) -> void:
	TranslationServer.set_locale(locale)


func get_locale() -> String:
	return TranslationServer.get_locale()


## Returns keys that are missing in any supported locale (used by tests).
func find_missing_keys() -> PackedStringArray:
	var missing := PackedStringArray()
	var all_keys := {}
	for locale: String in _translations:
		for key in (_translations[locale] as Translation).get_message_list():
			all_keys[key] = true
	for key: String in all_keys:
		for locale: String in _translations:
			if (_translations[locale] as Translation).get_message(key) == &"":
				missing.append("%s [%s]" % [key, locale])
	return missing
