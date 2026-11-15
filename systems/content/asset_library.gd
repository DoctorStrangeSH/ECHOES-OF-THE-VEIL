@tool
class_name AssetLibrary
extends RefCounted
## Central place for paths into the locally imported LimeZu packs and for safe
## texture loading. Packs are not in git (license), so every lookup must
## tolerate missing files and fall back to generated placeholders.
## Owner: content. Import step: tools/import_limezu.py.

const LIMEZU_ROOT := "res://assets/limezu"
const TILE_SIZE := 16

const INTERIORS := LIMEZU_ROOT + "/modern_interiors"
const EXTERIORS := LIMEZU_ROOT + "/modern_exteriors"
const UI := LIMEZU_ROOT + "/modern_ui"
const FARM := LIMEZU_ROOT + "/modern_farm"
const OFFICE := LIMEZU_ROOT + "/modern_office"

const CHARACTER_GENERATOR := INTERIORS + "/2_Characters/Character_Generator"

static var _placeholder_cache: Dictionary = {}


static func has_limezu() -> bool:
	return ResourceLoader.exists(CHARACTER_GENERATOR + "/Bodies/16x16/Body_01.png")


## Resolves a path relative to LIMEZU_ROOT, or returns absolute res:// paths as is.
static func resolve(path: String) -> String:
	if path.is_empty() or path.begins_with("res://"):
		return path
	return LIMEZU_ROOT.path_join(path)


static func load_texture(path: String) -> Texture2D:
	var full := resolve(path)
	if full.is_empty() or not ResourceLoader.exists(full):
		return null
	return load(full) as Texture2D


## Character generator layer, e.g. layer="Hairstyles", id="Hairstyle_07_03".
static func character_layer_path(layer: String, id: String) -> String:
	if id.is_empty():
		return ""
	return "%s/%s/16x16/%s.png" % [CHARACTER_GENERATOR, layer, id]


## File stems of the PNGs in a res:// folder, sorted. Uses ResourceLoader so
## it also works in exported builds (where files are remapped).
static func list_png_ids(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not DirAccess.dir_exists_absolute(dir):
		return out
	for f in ResourceLoader.list_directory(dir):
		if f.get_extension().to_lower() == "png":
			out.append(f.get_basename())
	out.sort()
	return out


## Solid-colour placeholder with a darker outline, cached by size and colour.
static func placeholder(size: Vector2i, color: Color) -> Texture2D:
	var key := "%s|%s" % [size, color.to_html()]
	if _placeholder_cache.has(key):
		return _placeholder_cache[key]
	var img := Image.create_empty(maxi(size.x, 1), maxi(size.y, 1), false, Image.FORMAT_RGBA8)
	img.fill(color)
	var edge := color.darkened(0.45)
	for x in size.x:
		img.set_pixel(x, 0, edge)
		img.set_pixel(x, size.y - 1, edge)
	for y in size.y:
		img.set_pixel(0, y, edge)
		img.set_pixel(size.x - 1, y, edge)
	var tex := ImageTexture.create_from_image(img)
	_placeholder_cache[key] = tex
	return tex
