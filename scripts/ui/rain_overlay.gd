class_name RainOverlay
extends CanvasLayer
## Screen-space rain shown outdoors on rainy days.

var _particles: CPUParticles2D


func _ready() -> void:
	layer = 5
	_particles = CPUParticles2D.new()
	var img := Image.create_empty(1, 5, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.75, 0.85, 1.0, 0.55))
	_particles.texture = ImageTexture.create_from_image(img)
	_particles.amount = 160
	_particles.lifetime = 0.7
	_particles.preprocess = 0.7
	_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	_particles.emission_rect_extents = Vector2(300, 4)
	_particles.position = Vector2(260, -10)
	_particles.direction = Vector2(-0.25, 1)
	_particles.spread = 3.0
	_particles.gravity = Vector2(0, 0)
	_particles.initial_velocity_min = 380.0
	_particles.initial_velocity_max = 440.0
	_particles.local_coords = false
	add_child(_particles)
	_particles.emitting = false


func _process(_delta: float) -> void:
	var loc := SceneFlow.current_location as Location
	var on := GameState.is_playing and WorldClock.weather == "rain" and loc != null and loc.outdoors
	if on != _particles.emitting:
		_particles.emitting = on
	visible = on or _particles.emitting
