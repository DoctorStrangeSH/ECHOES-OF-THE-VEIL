class_name Lighting
extends RefCounted
## Sun shadows and lamps, driven by the clock (see Location._update_tint).
## Shadows: a squashed, skewed black copy of each tall thing, swinging from
## west to east through the day and gone at night or indoors. Lamps: soft
## warm pools that come on at dusk.

static var _light_tex: Texture2D
## 0 at noon-bright day, 1 at full night.
static var night := 0.0
## -1 (morning: shadows fall west) .. 1 (evening: east).
static var sun := 0.0
static var outdoors := true


static func make_light(color: Color, radius: float) -> PointLight2D:
	if _light_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.45, Color(1, 1, 1, 0.45))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_light_tex = t
	var l := PointLight2D.new()
	l.texture = _light_tex
	l.color = Color(color, 1.0)
	l.texture_scale = radius / 64.0
	l.blend_mode = Light2D.BLEND_MODE_ADD
	l.add_to_group(&"lamp_lights")
	return l


static func place_light(l: PointLight2D) -> void:
	var on := night if outdoors else maxf(night, 0.35)
	l.enabled = on > 0.05
	l.energy = 0.9 * on


static func place_shadow(s: Sprite2D) -> void:
	var a := 0.0 if not outdoors else 0.26 * (1.0 - night)
	s.visible = a > 0.01
	s.modulate = Color(0, 0, 0, a)
	s.scale = Vector2(1.0, -0.42)
	s.skew = 0.85 * sun


## Called when the time or the place changes.
static func update(tree: SceneTree, hour: float, is_outdoors: bool) -> void:
	outdoors = is_outdoors
	# Night: full after 21:00 and before 5:00, fading over two hours each way.
	if hour >= 19.0:
		night = clampf((hour - 19.0) / 2.0, 0.0, 1.0)
	elif hour < 7.0:
		night = clampf((7.0 - hour) / 2.0, 0.0, 1.0)
	else:
		night = 0.0
	sun = clampf((hour - 13.0) / 6.0, -1.0, 1.0)
	for s in tree.get_nodes_in_group(&"sun_shadows"):
		place_shadow(s)
	for l in tree.get_nodes_in_group(&"lamp_lights"):
		place_light(l)
