@tool
class_name CharacterAppearance
extends Resource
## Data-driven look of a LimeZu "Character Generator" character.
## Layers are composited in the order the pack requires:
## body -> eyes -> outfit -> hairstyle -> accessory.
## Alternatively `premade` points to a complete premade sheet.
## IDs are file stems, e.g. body="Body_03", hairstyle="Hairstyle_07_03".

const LAYER_FOLDERS := {
	"body": "Bodies",
	"eyes": "Eyes",
	"outfit": "Outfits",
	"hairstyle": "Hairstyles",
	"accessory": "Accessories",
}
const LAYER_ORDER: PackedStringArray = ["body", "eyes", "outfit", "hairstyle", "accessory"]

@export var premade: String = ""
@export var body: String = "Body_03"
@export var eyes: String = "Eyes_02"
@export var outfit: String = "Outfit_05_02"
@export var hairstyle: String = "Hairstyle_07_03"
@export var accessory: String = ""
## Tint used by the placeholder when the art packs are not imported.
@export var placeholder_color: Color = Color(0.35, 0.55, 0.85)


static func default_player() -> CharacterAppearance:
	return CharacterAppearance.new()


static func from_premade(premade_id: String, color: Color = Color(0.8, 0.5, 0.4)) -> CharacterAppearance:
	var a := CharacterAppearance.new()
	a.premade = premade_id
	a.placeholder_color = color
	return a


## Ordered texture paths for compositing (bottom layer first).
func layer_paths() -> PackedStringArray:
	var out := PackedStringArray()
	if not premade.is_empty():
		out.append("%s/0_Premade_Characters/16x16/%s.png" % [AssetLibrary.CHARACTER_GENERATOR, premade])
		return out
	for layer in LAYER_ORDER:
		var id: String = get(layer)
		if not id.is_empty():
			out.append(AssetLibrary.character_layer_path(LAYER_FOLDERS[layer], id))
	return out


func to_dict() -> Dictionary:
	return {
		"premade": premade, "body": body, "eyes": eyes, "outfit": outfit,
		"hairstyle": hairstyle, "accessory": accessory,
		"placeholder_color": placeholder_color.to_html(),
	}


static func from_dict(data: Dictionary) -> CharacterAppearance:
	var a := CharacterAppearance.new()
	for key in ["premade", "body", "eyes", "outfit", "hairstyle", "accessory"]:
		if data.has(key) and data[key] is String:
			a.set(key, data[key])
	var c: Variant = data.get("placeholder_color")
	if c is String and Color.html_is_valid(c):
		a.placeholder_color = Color.html(c)
	return a
