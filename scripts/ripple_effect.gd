extends Node2D
@export var radius := Vector2(30.0, 5.0)
@export var strength := 1.0
@export var duration := 0.6

func _ready() -> void:
	var ring := $Line2D as Line2D
	for i in range(49):
		var angle := TAU * float(i) / 48.0
		ring.add_point(Vector2(cos(angle), sin(angle)) * radius)
	scale = Vector2.ONE * 0.2
	modulate.a = strength
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ONE, duration * 0.45).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE * 1.5, duration * 0.55).set_delay(duration * 0.45)
	tween.tween_property(self, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(queue_free)
