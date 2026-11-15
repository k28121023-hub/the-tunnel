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

func _draw() -> void:
	draw_set_transform(Vector2.ZERO,0,Vector2(direction,1))
	var fade := minf(1.0,remaining/90.0)
	# Layered crescent with a bright core and a broad, fading red wake.
	for i in range(5,0,-1):
		draw_arc(Vector2(-i*9,0),42,-1.22,1.22,28,Color(1,0.12,0.03,0.035*fade*(6-i)),8,true)
	draw_arc(Vector2.ZERO,42,-1.22,1.22,32,Color(1,0.06,0.02,0.2*fade),20,true)
	draw_arc(Vector2.ZERO,42,-1.22,1.22,32,Color(1,0.27,0.04,0.95*fade),9,true)
	draw_arc(Vector2.ZERO,42,-1.22,1.22,32,Color(1,0.94,0.64,fade),3,true)
	for i in range(8):
		var t := fposmod(age*2.8+i*0.137,1.0)
		draw_line(Vector2(-t*80,sin(i*2.4)*32),Vector2(-t*80-12,sin(i*2.4)*32),Color(1,0.5,0.1,(1-t)*fade),2,true)
	draw_set_transform(Vector2.ZERO)
