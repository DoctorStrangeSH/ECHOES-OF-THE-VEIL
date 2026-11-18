class_name WeaponSwing
extends Sprite2D
## The equipped weapon, visible in the hand while attacking: blades and heavy
## weapons sweep an arc, polearms thrust, staffs and slings are held out.

var _tween: Tween


func show_attack(icon: String, style: String, facing: Vector2, duration: float, finisher: bool) -> void:
	if style == "fists" or icon == "" or icon.contains("#"):
		visible = false
		return
	var tex := AssetLibrary.load_texture(icon)
	if tex == null:
		visible = false
		return
	texture = tex
	# Arsenal icons are 32 px; in the hand they read at character scale.
	var k := 16.0 / float(maxi(tex.get_width(), 1))
	scale = Vector2(k, k)
	offset = Vector2(tex.get_width() * 0.25, -tex.get_height() * 0.25)
	visible = true
	modulate.a = 1.0
	z_index = 1 if facing.y >= 0 else -1
	var base := facing.angle()
	var hand := Vector2(0, -9) + facing * 6.0
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	match style:
		"blade", "heavy":
			var arc := deg_to_rad(150.0 if finisher else 110.0)
			rotation = base - arc * 0.5 + PI / 4
			position = hand
			_tween.tween_property(self, "rotation", base + arc * 0.5 + PI / 4, duration * (1.2 if style == "heavy" else 0.8)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		"thrust":
			rotation = base + PI / 4
			position = hand - facing * 2.0
			_tween.tween_property(self, "position", hand + facing * 12.0, duration * 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_:
			rotation = base + PI / 4
			position = hand + facing * 4.0
			_tween.tween_property(self, "position", hand + facing * 7.0, duration * 0.3)
	_tween.tween_property(self, "modulate:a", 0.0, 0.12)
	_tween.tween_callback(func() -> void: visible = false)
