class_name DataFiles
extends RefCounted
## Loads definition files so new content never needs code changes.
##
## defs("res://data/items/items") merges items.json with every items_*.json in
## the same folder (items_harbour.json, items_act2.json, ...). Keys starting
## with "_" are comments. A duplicate id is an error: the first file wins.
## Also lists location scenes, so a new .tscn in scenes/locations is enough to
## register a location.

const LOCATIONS_DIR := "res://scenes/locations"


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		push_error("DataFiles: missing %s" % path)
		return null
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if data == null:
		push_error("DataFiles: %s is not valid JSON" % path)
	return data


## The files defs(base) would read, primary file first.
static func files_for(base: String) -> PackedStringArray:
	var dir := base.get_base_dir()
	var prefix := base.get_file()
	var out := PackedStringArray()
	var extra: Array[String] = []
	for f in DirAccess.get_files_at(dir):
		if f == prefix + ".json":
			out.append(dir.path_join(f))
		elif f.begins_with(prefix + "_") and f.get_extension() == "json":
			extra.append(dir.path_join(f))
	extra.sort()
	out.append_array(extra)
	return out


static func defs(base: String) -> Dictionary:
	var out := {}
	var origin := {}
	for path in files_for(base):
		var data: Variant = read_json(path)
		if not data is Dictionary:
			push_error("DataFiles: %s is not a JSON object" % path)
			continue
		for id: String in data:
			if id.begins_with("_"):
				continue
			var key := StringName(id)
			if out.has(key):
				push_error("DataFiles: '%s' in %s is already defined in %s" % [id, path, origin[key]])
				continue
			out[key] = data[id]
			origin[key] = path
	return out


## scene id -> path for every location scene (exported builds list *.tscn.remap).
static func location_scenes() -> Dictionary:
	var out := {}
	for f in DirAccess.get_files_at(LOCATIONS_DIR):
		var name := f.trim_suffix(".remap")
		if name.get_extension() == "tscn":
			out[StringName(name.get_basename())] = LOCATIONS_DIR.path_join(name)
	return out
