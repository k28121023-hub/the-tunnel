extends Node2D
## A short swept crescent; visual only, damage remains in Player._attack.
const DURATION := 0.28
var elapsed := 0.0

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= DURATION:
		queue_free()
		return
	queue_redraw()

func _draw() -> void:
	var progress := clampf(elapsed / DURATION, 0.0, 1.0)
	var opacity := sin(progress * PI) * (1.0 - progress * 0.3)
	var tip := lerpf(-1.05, 1.05, progress)
	var tail := tip - lerpf(0.4, 1.55, minf(progress * 3.0, 1.0))
	# Soft outer ribbons, blue body and a fine white edge, tapered at both ends.
	for layer in range(4):
		var points := PackedVector2Array()
		var radius := 114.0 + layer * 2.0
		var width: float = [20.0, 12.0, 6.0, 2.0][layer]
		for side in [1.0, -1.0]:
			for i in range(33):
				var t := float(i if side > 0.0 else 32 - i) / 32.0
				var angle := lerpf(tail, tip, t)
				var r: float = radius + side * width * sin(t * PI) * 0.5
				points.append(Vector2(cos(angle) * r, sin(angle) * r * 0.58))
		var colors := [Color(0.2,0.65,1.0,0.10), Color(0.3,0.8,1.0,0.25), Color(0.65,0.95,1.0,0.7), Color(1.0,1.0,1.0,0.95)]
		var tint: Color = colors[layer]
		tint.a *= opacity
		draw_colored_polygon(points, tint)
	# Small fading glints trail the sweep instead of a straight hit beam.
	for i in range(5):
		var angle := tip - float(i) * 0.23
		var radius := 126.0 + sin(float(i) * 4.0) * 8.0
		var point := Vector2(cos(angle) * radius, sin(angle) * radius * 0.58)
		var size := (2.6 - i * 0.3) * sin(progress * PI)
		var tint := Color(0.75,0.95,1.0,opacity * 0.7)
		draw_line(point - Vector2(size,0), point + Vector2(size,0), tint, 1.0, true)
		draw_line(point - Vector2(0,size), point + Vector2(0,size), tint, 1.0, true)
