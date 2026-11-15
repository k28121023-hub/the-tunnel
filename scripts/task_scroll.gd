extends Node2D
func _draw() -> void:
	draw_rect(Rect2(-13, -17, 26, 34), Color(0.93, 0.83, 0.57))
	draw_rect(Rect2(-16, -19, 32, 6), Color(0.66, 0.43, 0.2))
	draw_rect(Rect2(-16, 13, 32, 6), Color(0.66, 0.43, 0.2))
	for y in [-7, -1, 5]:
		draw_line(Vector2(-7, y), Vector2(7, y), Color(0.48, 0.32, 0.16), 1.5)
