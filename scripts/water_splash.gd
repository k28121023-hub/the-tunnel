extends Node2D
const RIPPLE := preload("res://scenes/RippleEffect.tscn")

func _ready() -> void:
	# Hard-edged procedural droplet, without external image assets.
	var droplet := Image.create_empty(7, 11, false, Image.FORMAT_RGBA8)
	droplet.fill(Color.TRANSPARENT)
	for y in range(1, 10):
		var half_width := 0.5 + float(y) * 0.22 if y < 7 else 2.3 - float(y - 7) * 0.6
		for x in range(7):
			if absf(float(x) - 3.0) <= half_width:
				droplet.set_pixel(x, y, Color.WHITE)
	$Particles.texture = ImageTexture.create_from_image(droplet)
	$Particles.restart()
	_spawn_ripple(1.0)
	var sequence := create_tween()
	sequence.tween_interval(0.10)
	sequence.tween_callback(_spawn_ripple.bind(0.78))
	sequence.tween_interval(0.10)
	sequence.tween_callback(_spawn_ripple.bind(0.56))
	sequence.tween_interval(0.8)
	sequence.tween_callback(queue_free)

func _spawn_ripple(strength: float) -> void:
	var ripple := RIPPLE.instantiate() as Node2D
	ripple.radius = Vector2(30.0, 5.0) * strength
	ripple.strength = strength
	add_child(ripple)
