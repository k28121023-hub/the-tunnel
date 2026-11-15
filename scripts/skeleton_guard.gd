extends CharacterBody2D
signal defeated
var player: CharacterBody2D
var patrol_left := 280.0
var patrol_right := 365.0
var health := 2
var facing := 1.0
var phase := 0.0
var attack_time := 0.0
var cooldown := 0.8
var struck := false
var hurt_time := 0.0

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 5
	z_index = 4
	var hit := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(20, 44)
	hit.shape = shape
	add_child(hit)

func _physics_process(delta: float) -> void:
	if health <= 0: return
	cooldown = maxf(0, cooldown - delta)
	hurt_time = maxf(0, hurt_time - delta)
	velocity.y = minf(900, velocity.y + 1400 * delta)
	if attack_time > 0:
		attack_time = maxf(0, attack_time - delta)
		velocity.x = 0
		if attack_time <= 0.2 and not struck:
			struck = true
			if is_instance_valid(player) and player.health > 0:
				var offset := player.global_position - global_position
				if offset.x * facing >= 0 and absf(offset.x) < 56 and absf(offset.y) < 32:
					var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1, [get_rid(), player.get_rid()])
					if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
						player.enemy_contact(self, 15)
	else:
		if position.x <= patrol_left: facing = 1
		elif position.x >= patrol_right: facing = -1
		if is_on_floor():
			var ahead := global_position + Vector2(facing * 17, 0)
			var ground := PhysicsRayQueryParameters2D.create(ahead, ahead + Vector2(0, 32), 1, [get_rid()])
			if is_on_wall() or get_world_2d().direct_space_state.intersect_ray(ground).is_empty():
				facing *= -1
		velocity.x = facing * 48
		if is_instance_valid(player) and player.health > 0 and cooldown <= 0:
			var offset := player.global_position - global_position
			if absf(offset.x) < 52 and absf(offset.y) < 30:
				facing = -1 if offset.x < 0 else 1
				attack_time = 0.65
				cooldown = 1.5
				struck = false
				velocity.x = 0
	move_and_slide()
	position.x = clampf(position.x, patrol_left, patrol_right)
	phase += absf(velocity.x) * delta * 0.16
	queue_redraw()

func take_damage(amount: int) -> bool:
	if health <= 0 or amount <= 0: return false
	health = maxi(0, health - amount)
	hurt_time = 0.18
	if health == 0:
		collision_layer = 0
		defeated.emit()
		queue_free()
	return true

func bone(a: Vector2, b: Vector2, color: Color, width := 3.0) -> void:
	draw_line(a, b, Color("18202b"), width + 2, true)
	draw_line(a, b, color, width, true)

func _draw() -> void:
	draw_set_transform(Vector2.ZERO, 0, Vector2(facing, 1))
	var ivory := Color("fff0d0") if hurt_time <= 0 else Color("ff8e82")
	var stride := sin(phase) * 5 if attack_time <= 0 else 0.0
	# Articulated legs, pelvis, spine and ribs.
	bone(Vector2(-4,7), Vector2(-6-stride,15), ivory)
	bone(Vector2(-6-stride,15), Vector2(-7+stride,21), ivory)
	bone(Vector2(4,7), Vector2(6+stride,15), ivory)
	bone(Vector2(6+stride,15), Vector2(8-stride,21), ivory)
	bone(Vector2(-7+stride,21),Vector2(-2+stride,21),ivory)
	bone(Vector2(8-stride,21),Vector2(13-stride,21),ivory)
	bone(Vector2(-6,6),Vector2(6,6),ivory,4)
	bone(Vector2(0,-12),Vector2(0,6),ivory)
	for y in [-8,-3,2]:
		bone(Vector2(-7,y-2),Vector2(0,y),ivory,2)
		bone(Vector2(0,y),Vector2(7,y-2),ivory,2)
	bone(Vector2(-7,-9),Vector2(-12,0),ivory)
	bone(Vector2(-12,0),Vector2(-9,6),ivory)
	var hand := Vector2(15,-3)
	if attack_time > 0:
		hand = Vector2(10,-16) if attack_time > 0.2 else Vector2(23,0)
	bone(Vector2(7,-9),hand,ivory)
	# Skull, dark sockets, nose and teeth.
	draw_circle(Vector2(0,-18),10,Color("18202b"))
	draw_circle(Vector2(0,-18),8.5,ivory)
	draw_rect(Rect2(-5,-15,10,7),ivory)
	draw_circle(Vector2(-3,-19),2.4,Color("141a22"))
	draw_circle(Vector2(4,-19),2.4,Color("141a22"))
	draw_circle(Vector2(1,-15),1.3,Color("141a22"))
	for x in [-3,0,3]: draw_line(Vector2(x,-11),Vector2(x,-8),Color("5b5550"),1)
	# Short steel sword and brass guard, attached to the hand.
	var angle := 1.1 if attack_time > 0 and attack_time <= 0.2 else -0.25
	draw_set_transform(Vector2(hand.x * facing, hand.y), angle * facing, Vector2(facing,1))
	bone(Vector2(0,4),Vector2(0,-4),Color("8c5934"),3)
	draw_colored_polygon(PackedVector2Array([Vector2(-3,-5),Vector2(-2,-23),Vector2(0,-29),Vector2(3,-23),Vector2(3,-5)]),Color("e0f3ff"))
	draw_line(Vector2(0,-6),Vector2(0,-24),Color("718da6"),1)
	bone(Vector2(-6,-4),Vector2(6,-4),Color("ecc474"),2)
	draw_set_transform(Vector2.ZERO)
