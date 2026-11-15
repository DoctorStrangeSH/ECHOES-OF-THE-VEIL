extends Node
## Compiles every GDScript in the project (with autoloads available) and
## reports failures. Usage:
##   godot --headless --path . res://tools/check_scripts.tscn
## Exit code 0 = every script compiles.


func _ready() -> void:
	var failed := 0
	var paths := _scripts("res://")
	for path in paths:
		var s := load(path) as GDScript
		if s == null or not s.can_instantiate():
			failed += 1
			printerr("FAILED: ", path)
	print("%d scripts checked, %d failed" % [paths.size(), failed])
	get_tree().quit(1 if failed > 0 else 0)


func _scripts(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for d in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d == "assets":
			continue
		out.append_array(_scripts(dir.path_join(d)))
	for f in DirAccess.get_files_at(dir):
		if f.get_extension() == "gd":
			out.append(dir.path_join(f))
	return out
