extends CharacterBody2D
signal defeated
const PORTRAIT := preload("res://assets/antler_guard.png")
const ART_SCALE := 78.0 / 1167.0
const WALK_SHADER := preload("res://scripts/antler_walk.gdshader")
const STRIDE_LENGTH := 52.0
const ATTACK_NOTICE_RANGE := 180.0
var walk_weight := 0.0
var walk_material: ShaderMaterial
var sprite: Sprite2D
var blade: Polygon2D
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
var health_bar_time := 0.0

func get_damage_rect() -> Rect2:
	return Rect2(global_position + Vector2(-18, -56), Vector2(36, 78))

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
	sprite = Sprite2D.new()
	sprite.texture = PORTRAIT
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.centered = false
	# Anchor the body and feet, rather than the wide sword's image bounds.
	sprite.offset = Vector2(-830, -1167)
	walk_material = ShaderMaterial.new()
	walk_material.shader = WALK_SHADER
	sprite.material = walk_material
	add_child(sprite)
	blade = Polygon2D.new()
	blade.texture = PORTRAIT
	blade.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	var outline := PackedVector2Array([Vector2(0,1080),Vector2(300,1010),Vector2(500,860),Vector2(580,775),Vector2(630,665),Vector2(550,640),Vector2(500,735),Vector2(400,830),Vector2(200,960),Vector2(0,1035)])
	blade.uv = outline
	var points := PackedVector2Array()
	for point in outline: points.append(point - Vector2(610,690))
	blade.polygon = points
	blade.position = Vector2(610,690) + sprite.offset
	sprite.add_child(blade)
	_update_visual()

func _physics_process(delta: float) -> void:
	if health <= 0: return
	cooldown = maxf(0, cooldown - delta)
	hurt_time = maxf(0, hurt_time - delta)
	health_bar_time = maxf(0, health_bar_time - delta)
	velocity.y = minf(900, velocity.y + 1400 * delta)
	if hurt_time > 0:
		velocity.x = 0
	elif attack_time > 0:
		attack_time = maxf(0, attack_time - delta)
		velocity.x = 0
		if attack_time <= 0.36 and not struck:
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
			if absf(offset.x) < ATTACK_NOTICE_RANGE and absf(offset.y) < 65:
				var sight := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1, [get_rid(), player.get_rid()])
				if get_world_2d().direct_space_state.intersect_ray(sight).is_empty():
					facing = -1 if offset.x < 0 else 1
					attack_time = 0.9
					cooldown = 1.8
					struck = false
					velocity.x = 0
	var previous_x := position.x
	move_and_slide()
	position.x = clampf(position.x, patrol_left, patrol_right)
	var distance := absf(position.x - previous_x)
	var walking := is_on_floor() and attack_time <= 0 and distance > 0.01
	walk_weight = move_toward(walk_weight, 1.0 if walking else 0.0, delta * 8)
	if walking:
		phase = fposmod(phase + distance / STRIDE_LENGTH * TAU, TAU)
	_update_visual()
	queue_redraw()

func take_damage(amount: int) -> bool:
	if health <= 0 or amount <= 0: return false
	health = maxi(0, health - amount)
	hurt_time = 0.3
	health_bar_time = 2.5
	attack_time = 0.0
	cooldown = maxf(cooldown, 0.6)
	_update_visual()
	queue_redraw()
	if health == 0:
		collision_layer = 0
		remove_from_group("enemies")
		set_physics_process(false)
		defeated.emit()
		var fade := create_tween()
		fade.tween_property(sprite, "modulate:a", 0.0, 0.35)
		fade.tween_callback(queue_free)
	return true

func _update_visual() -> void:
	sprite.scale = Vector2(-facing, 1) * ART_SCALE
	walk_material.set_shader_parameter("phase", phase)
	walk_material.set_shader_parameter("amount", walk_weight)
	# Keep the head and sword stable: stepping comes from the legs, not rocking
	# the entire portrait around its feet.
	sprite.position = Vector2(0, 22 - absf(sin(phase * 2)) * 0.3 * walk_weight)
	sprite.rotation = 0.0
	blade.rotation = 0.0
	if attack_time > 0:
		if attack_time > 0.5:
			blade.rotation = lerpf(0.0,1.8,(0.9-attack_time)/0.4)
			sprite.position.x = -facing * 2
		elif attack_time > 0.25:
			blade.rotation = lerpf(1.8,-0.6,(0.5-attack_time)/0.25)
			sprite.position.x = facing * 4
		else:
			blade.rotation = lerpf(-0.6,0.0,(0.25-attack_time)/0.25)
			sprite.position.x = facing * 4 * attack_time / 0.25
	sprite.modulate = Color("ff9188") if hurt_time > 0 else Color.WHITE

func _draw() -> void:
	if attack_time > 0.5:
		draw_line(Vector2(0,-72),Vector2(0,-63),Color("ffcc62"),3,true)
		draw_circle(Vector2(0,-59),1.8,Color("ffcc62"))
	if health_bar_time > 0 and health > 0:
		draw_rect(Rect2(-19,-65,38,7),Color("080d16"))
		draw_rect(Rect2(-17,-63,34 * health / 2.0,3),Color("ff6555"))
	if attack_time > 0.25 and attack_time <= 0.5:
		var angle := 0.0 if facing > 0 else PI
		draw_arc(Vector2(0,-8), 48, angle-0.9, angle+0.8, 24, Color(1,0.35,0.22,0.8),3,true)



