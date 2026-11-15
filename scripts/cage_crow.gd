extends CharacterBody2D
## One reusable crow per cage, with a telegraphed straight swoop and return path.
@export var damage := 15
@export var detection_radius := 360.0
@export var wait_min := 2.5
@export var wait_max := 5.5
@export var flight_speed := 260.0
enum State { PERCHED, WARNING, ATTACK, RETURN }
var state := State.PERCHED
var countdown := 0.0
var home: Vector2
var target: Vector2
var route: Array[Vector2] = []
var hit_this_flight := false
var animation_time := 0.0
var facing := 1.0
var player: Node2D
var perched_drawn := false
var health := 1

func take_damage(amount: int) -> bool:
	if health <= 0 or amount <= 0:
		return false
	health = maxi(0, health - amount)
	if health == 0:
		hide()
		set_physics_process(false)
		queue_free()
	return true

func _ready() -> void:
	add_to_group("enemies")
	home = global_position
	countdown = randf_range(wait_min, wait_max)
	$Hitbox.body_entered.connect(_try_hit)

func _physics_process(delta: float) -> void:
	animation_time += delta
	if state != State.PERCHED or not perched_drawn:
		queue_redraw()
		perched_drawn = state == State.PERCHED
	var level := get_tree().current_scene
	if not is_instance_valid(player):
		player = level.get_node_or_null("Player")
	var active := is_instance_valid(player) and player.is_physics_processing()
	match state:
		State.PERCHED:
			countdown -= delta
			if active and countdown <= 0.0 and global_position.distance_to(player.global_position) < detection_radius:
				# Do not launch through platforms or walls.
				var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1, [get_rid()])
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					state = State.WARNING
					countdown = 0.3
					perched_drawn = false
		State.WARNING:
			countdown -= delta
			if not active:
				_rest()
			elif countdown <= 0.0:
				target = player.global_position
				route = [home]
				hit_this_flight = false
				state = State.ATTACK
		State.ATTACK:
			if not active:
				state = State.RETURN
				return
			var movement := global_position.direction_to(target) * minf(flight_speed * delta, global_position.distance_to(target))
			if absf(movement.x) > 0.01:
				facing = signf(movement.x)
			var collision := move_and_collide(movement)
			route.append(global_position)
			for body in $Hitbox.get_overlapping_bodies():
				_try_hit(body)
			if collision or global_position.distance_to(target) < 2.0 or hit_this_flight:
				state = State.RETURN
		State.RETURN:
			# Retrace the actual outbound path instead of cutting through stonework.
			var travel := flight_speed * 0.8 * delta
			while travel > 0.0 and not route.is_empty():
				var point: Vector2 = route.back()
				var distance := global_position.distance_to(point)
				if absf(point.x - global_position.x) > 0.01:
					facing = signf(point.x - global_position.x)
				global_position = global_position.move_toward(point, travel)
				if distance <= travel:
					route.pop_back()
				travel -= distance
			if route.is_empty():
				_rest()

func _rest() -> void:
	state = State.PERCHED
	global_position = home
	countdown = randf_range(wait_min, wait_max)

func _try_hit(body: Node2D) -> void:
	if health > 0 and state == State.ATTACK and not hit_this_flight and body == player:
		hit_this_flight = true
		player.enemy_contact(self, damage)
		state = State.RETURN

func _draw() -> void:
	var flying := state == State.ATTACK or state == State.RETURN
	var flap := sin(animation_time * 25.0) * 10.0 if flying else -2.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1))
	var ink := Color(0.045, 0.055, 0.09)
	var feather := Color(0.13, 0.17, 0.23)
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 1), Vector2(-15, 5), Vector2(-11, -2)]), feather)
	draw_colored_polygon(PackedVector2Array([Vector2(-5, 0), Vector2(-15, -5 + clampf(flap, -8.0, 8.0)), Vector2(-4, -3)]), feather)
	draw_colored_polygon(PackedVector2Array([Vector2(-4, -3), Vector2(4, -4), Vector2(7, 2), Vector2(1, 6), Vector2(-7, 3)]), ink)
	draw_circle(Vector2(5, -5), 4.5, ink)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -6), Vector2(14, -3), Vector2(8, -2)]), Color(0.32, 0.36, 0.4))
	draw_circle(Vector2(6, -6), 1.1, Color(1, 0.3, 0.12) if state == State.WARNING else Color(0.85, 0.82, 0.65))
	if not flying:
		draw_line(Vector2(-2, 5), Vector2(-2, 9), feather, 1.0)
		draw_line(Vector2(3, 5), Vector2(3, 9), feather, 1.0)

