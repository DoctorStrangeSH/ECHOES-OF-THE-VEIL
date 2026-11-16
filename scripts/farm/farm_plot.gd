@tool
class_name FarmPlot
extends Interactable
## One square of the Brookside field (R5). Draws the wet soil and the crop's
## growth stage; using it plants, waters or harvests (Farm autoload). Unusable
## until the farm is yours.

const WET_TEX := "modern_farm/16x16/1_Terrains_16x16.png"
const WET_REGION := Rect2(16, 208, 16, 16)  # dark watered soil

@export var plot_id: StringName = &""

var _sheets: Dictionary = {}  # crop -> Texture2D
var _wet: Texture2D


func _init() -> void:
	prompt_key = "PROMPT_PLANT"
	interaction_priority = 12
	area_size = Vector2(14, 14)


func _ready() -> void:
	super._ready()
	if interaction_id == &"":
		interaction_id = StringName("plot_%s" % plot_id)
	if Engine.is_editor_hint():
		return
	_wet = AssetLibrary.load_texture(WET_TEX)
	Farm.changed.connect(queue_redraw)
	WorldClock.weather_changed.connect(func(_w: String) -> void: queue_redraw())
	EventHub.flag_changed.connect(func(_f: StringName, _v: Variant) -> void: _sync())
	_sync()


func _sync() -> void:
	enabled = Farm.owned()
	set_deferred("monitorable", enabled)
	queue_redraw()


func get_prompt() -> String:
	match Farm.state(plot_id):
		"empty":
			var seeds := Farm.seeds_held()
			if seeds.is_empty():
				return tr("PROMPT_PLANT_NO_SEEDS")
			var s := Farm.last_seed if seeds.has(Farm.last_seed) else seeds[0]
			return tr("PROMPT_PLANT_SEED") % tr(String(Inventory.def(s).get("name", "")))
		"growing":
			return tr("PROMPT_LOOK") if Farm.is_watered(plot_id) else tr("PROMPT_WATER")
		"ready":
			return tr("PROMPT_HARVEST")
	return tr(prompt_key)


func _on_interact(_actor: Node) -> void:
	match Farm.state(plot_id):
		"empty":
			var seeds := Farm.seeds_held()
			if seeds.is_empty():
				EventHub.toast_requested.emit(tr("FARM_NO_SEEDS"))
			elif seeds.size() == 1 or SeedMenu.instance == null:
				Farm.plant(plot_id, Farm.last_seed if seeds.has(Farm.last_seed) else seeds[0])
			else:
				SeedMenu.instance.open(plot_id)
		"growing":
			if Farm.is_watered(plot_id):
				EventHub.toast_requested.emit(tr("FARM_WATERED"))
			elif not Inventory.has(&"watering_can"):
				EventHub.toast_requested.emit(tr("FARM_NO_CAN"))
			else:
				Farm.water(plot_id)
		"ready":
			Farm.harvest(plot_id)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(-8, -8, 16, 16), Color(0.4, 0.25, 0.1, 0.5), false, 1.0)
		return
	var p: Dictionary = Farm.plots.get(plot_id, {})
	if p.is_empty():
		return
	if Farm.is_watered(plot_id) and _wet != null:
		draw_texture_rect_region(_wet, Rect2(-8, -8, 16, 16), WET_REGION, Color(1, 1, 1, 0.85))
	var c := StringName(p["crop"])
	if not _sheets.has(c):
		_sheets[c] = AssetLibrary.load_texture(String(Farm.crop(c).get("sheet", "")))
	var tex: Texture2D = _sheets[c]
	if tex == null:
		draw_circle(Vector2(0, -2), 2.0 + float(p["growth"]), Color(0.3, 0.7, 0.3))
		return
	var frames := tex.get_width() / 16
	var f := Farm.frame(plot_id, frames)
	var h := float(Farm.crop(c).get("frame_h", 16))
	draw_texture_rect_region(tex, Rect2(-8, 6 - h, 16, h), Rect2(f * 16, 0, 16, h))
