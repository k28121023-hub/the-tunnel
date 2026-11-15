extends Node2D
var player: CharacterBody2D
var direction := 1.0
var remaining := 650.0
var age := 0.0
const SPEED := 520.0

func _ready() -> void:
	z_index = 9

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player) or player.health <= 0:
		queue_free()
		return
	age += delta
	var travel := minf(remaining, SPEED * delta)
	var start := global_position
	var end := start + Vector2(direction * travel,0)
	var wall_query := PhysicsRayQueryParameters2D.create(start,end,1)
	var wall := get_world_2d().direct_space_state.intersect_ray(wall_query)
	if not wall.is_empty(): end = wall.position
	var closest := Geometry2D.get_closest_point_to_segment(player.global_position,start,end)
	if absf(player.global_position.x-closest.x) <= 16 and absf(player.global_position.y-closest.y) <= 43:
		var sight := PhysicsRayQueryParameters2D.create(closest,player.global_position,1,[player.get_rid()])
		if get_world_2d().direct_space_state.intersect_ray(sight).is_empty():
			player.enemy_contact(self,25)
			queue_free()
			return
	global_position = end
	remaining -= travel
	if remaining <= 0 or not wall.is_empty(): queue_free()
	queue_redraw()

static func ribbon(canvas: CanvasItem, center: Vector2, radius: float, width: float, start: float, end: float, tint: Color) -> void:
	var points := PackedVector2Array()
	for side in [1.0, -1.0]:
		for i in range(41):
			var t := float(i if side > 0 else 40-i)/40.0
			var angle := lerpf(start,end,t)
			var r: float = radius + side * width * pow(maxf(0,sin(t*PI)),0.8)*0.5
			points.append(center + Vector2(cos(angle)*r,sin(angle)*r*1.2))
	canvas.draw_colored_polygon(points,tint)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(direction,1))
	var fade := minf(1.0,remaining/90.0)
	for i in range(4,0,-1):
		ribbon(self,Vector2(-46-i*9,0),46,22,-1.55,1.55,Color(0.8,0.02,0.2,0.08*fade))
	var colors := [Color(1,0.03,0.2,0.16),Color(1,0.12,0.3,0.35),Color(1,0.3,0.06,0.9),Color(1,0.8,0.35,1),Color(1,1,0.9,1)]
	for i in range(5):
		var tint: Color = colors[i]
		tint.a *= fade
		ribbon(self,Vector2(-46,0),46,float([34,23,13,6,2][i]),-1.6,1.6,tint)
	for i in range(3):
		ribbon(self,Vector2(-62-i*13,sin(age*12+i)*4),48+i*5,2.5,-1.45+i*0.18,1.4-i*0.12,Color(1,0.38,0.15,fade*0.65))
	for i in range(22):
		var t := fposmod(age*2.3+i*0.137,1.0)
		var point := Vector2(-12-t*115,sin(i*2.4)*48*(0.3+t))
		var tint := Color(1,0.55+0.4*sin(i*1.7),0.3,(1-t)*fade)
		draw_line(point,point+Vector2(9+18*t,-sin(i*2.4)*4),tint,1.2,true)
		if i%3 == 0:
			var size := (1-t)*3.0
			if size > 0.2:
				draw_colored_polygon(PackedVector2Array([point+Vector2(-size*2,0),point+Vector2(0,-size),point+Vector2(size*2,0),point+Vector2(0,size)]),Color(1,0.95,0.75,(1-t)*fade))
	draw_set_transform(Vector2.ZERO)
