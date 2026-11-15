extends CharacterBody2D
signal defeated
const PORTRAIT := preload("res://assets/antler_guard.png")
const ART_SCALE := 78.0 / 1167.0
const WALK_SHADER := preload("res://scripts/antler_walk.gdshader")
const STRIDE_LENGTH := 52.0
const ATTACK_NOTICE_RANGE := 180.0
const SWORD_WAVE := preload("res://scripts/demon_sword_wave.gd")
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
var drawing := false

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
	# Counter-clockwise winding; a clockwise outline fails canvas triangulation.
	points.reverse()
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
		if attack_time <= 0.43 and not struck:
			struck = true
			var wave := Node2D.new()
			wave.set_script(SWORD_WAVE)
			wave.player = player
			wave.direction = facing
			get_parent().add_child(wave)
			wave.global_position = global_position + Vector2(20*facing,-8)
			if is_instance_valid(player) and player.health > 0:
				var offset := player.global_position - global_position
				if offset.x * facing >= 0 and absf(offset.x) < 56 and absf(offset.y) < 32:
					var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1, [get_rid(), player.get_rid()])
					if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
						player.enemy_contact(self, 25)
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
	var needs_draw := attack_time > 0.0 or health_bar_time > 0.0
	if needs_draw or drawing:
		queue_redraw()
	drawing = needs_draw

func take_damage(amount: int) -> bool:
	if health <= 0 or amount <= 0: return false
	health = maxi(0, health - amount)
	hurt_time = 0.3
	health_bar_time = 2.5
	attack_time = 0.0
	cooldown = maxf(cooldown, 0.6)
	_update_visual()
	var needs_draw := attack_time > 0.0 or health_bar_time > 0.0
	if needs_draw or drawing:
		queue_redraw()
	drawing = needs_draw
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
		if attack_time > 0.54:
			var t := clampf((0.9-attack_time)/0.3,0,1)
			var weight := 1.0-pow(1.0-t,3)
			blade.rotation = 2.0*weight
			sprite.rotation = -facing*0.13*weight
			sprite.position += Vector2(-facing*4*weight,2*weight)
		elif attack_time > 0.40:
			var t := (0.54-attack_time)/0.14
			var weight := t*t
			blade.rotation = lerpf(2.0,-0.85,weight)
			sprite.rotation = facing*lerpf(-0.13,0.16,weight)
			sprite.position += Vector2(facing*lerpf(-4,9,weight),2)
		elif attack_time > 0.31:
			blade.rotation = -0.85
			sprite.rotation = facing*0.16
			sprite.position += Vector2(facing*9,2)
		else:
			var t := attack_time/0.31
			blade.rotation = -0.85*t
			sprite.rotation = facing*0.16*t
			sprite.position += Vector2(facing*9*t,2*t)
	sprite.modulate = Color("ff9188") if hurt_time > 0 else Color.WHITE

func _draw() -> void:
	if attack_time > 0.5:
		draw_line(Vector2(0,-72),Vector2(0,-63),Color("ffcc62"),3,true)
		draw_circle(Vector2(0,-59),1.8,Color("ffcc62"))
	if health_bar_time > 0 and health > 0:
		draw_rect(Rect2(-19,-65,38,7),Color("080d16"))
		draw_rect(Rect2(-17,-63,34 * health / 2.0,3),Color("ff6555"))
	if attack_time > 0.54:
		var charge := clampf((0.9-attack_time)/0.36,0,1)
		for i in range(8):
			var angle := i*TAU/8 + charge*2
			var point := Vector2(facing*12,-15)+Vector2.from_angle(angle)*(26-18*charge)
			draw_line(point,point+Vector2.from_angle(angle)*4,Color(1,0.4,0.15,charge),1.5,true)
	if attack_time > 0.24 and attack_time <= 0.5:
		draw_set_transform(Vector2(0,-8),0,Vector2(facing,1))
		var progress := clampf((0.5-attack_time)/0.10,0,1)
		var fade := minf(1,(attack_time-0.24)/0.12)
		var tip := lerpf(-1.5,1.3,progress)
		for i in range(5):
			var tint: Color = [Color(1,0.03,0.15,0.16),Color(1,0.12,0.25,0.35),Color(1,0.4,0.08,0.8),Color(1,0.85,0.4,0.95),Color(1,1,0.95,1)][i]
			tint.a *= fade
			SWORD_WAVE.ribbon(self,Vector2.ZERO,55+i,float([28,18,10,5,1.5][i]),tip-2.1,tip,tint)
		if attack_time <= 0.43:
			var flash := clampf((attack_time-0.30)/0.13,0,1)
			for i in range(8):
				var axis := Vector2.from_angle(i*TAU/8)
				draw_line(Vector2(30,0)+axis*4,Vector2(30,0)+axis*(10+18*flash),Color(1,0.9,0.6,flash),2,true)
		draw_set_transform(Vector2.ZERO)
