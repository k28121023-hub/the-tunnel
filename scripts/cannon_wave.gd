extends Node2D
var shooter: Node2D
var direction := 1.0
var remaining := 1400.0
const SPEED := 680.0

func _ready() -> void:
	z_index = 8

func _physics_process(delta: float) -> void:
	if not is_instance_valid(shooter) or shooter.health <= 0 or not shooter.inventory.has("cannon") or not shooter.is_physics_processing():
		queue_free()
		return
	var travel := minf(SPEED * delta, remaining)
	var start := global_position
	var end := start + Vector2(direction * travel, 0)
	var ray := PhysicsRayQueryParameters2D.create(start, end, 1, [shooter.get_rid()])
	var wall := get_world_2d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty():
		end = wall.position
	var word_ray := PhysicsRayQueryParameters2D.create(start, end, 8)
	word_ray.hit_from_inside = true
	var word_hit := get_world_2d().direct_space_state.intersect_ray(word_ray)
	if not word_hit.is_empty() and word_hit.collider.has_method("hit_by_weapon"):
		word_hit.collider.hit_by_weapon()
		queue_free()
		return
	var target: Node2D = null
	var nearest := INF
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"):
			continue
		var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, start, end)
		if enemy.global_position.distance_to(closest) > 14.0:
			continue
		# Never hit an enemy on the far side of a wall, including the wave radius.
		var sight := PhysicsRayQueryParameters2D.create(start, enemy.global_position, 1, [shooter.get_rid(), enemy.get_rid()])
		if not get_world_2d().direct_space_state.intersect_ray(sight).is_empty():
			continue
		var distance := start.distance_to(closest)
		if distance < nearest:
			nearest = distance
			target = enemy
	if target != null and shooter.cannon_hit(target):
		queue_free()
		return
	global_position = end
	remaining -= travel
	if remaining <= 0.0 or not wall.is_empty():
		queue_free()
	queue_redraw()

func _draw() -> void:
	draw_line(Vector2(-direction * 23, 0), Vector2.ZERO, Color(0.1, 0.7, 1, 0.4), 12)
	draw_circle(Vector2.ZERO, 9, Color(0.2, 0.85, 1, 0.5))
	draw_circle(Vector2.ZERO, 5, Color(0.75, 1, 1))

func _exit_tree() -> void:
	if is_instance_valid(shooter) and shooter.cannon_wave == self:
		shooter.cannon_wave = null
