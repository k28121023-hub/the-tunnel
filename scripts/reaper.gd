extends CharacterBody2D
const SHEET := preload("res://assets/reaper_poses.png")
var health := 5
var facing := -1.0
var clock := 0.0
var attack_timer := 0.0
var cooldown := 1.0
var jump_cooldown := 0.0
var struck := false
var sprite: Sprite2D
var player: CharacterBody2D

func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1
	floor_snap_length = 5
	var hit := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28,58)
	hit.shape = shape
	add_child(hit)
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.scale = Vector2.ONE * (105.0 / (SHEET.get_height() / 2.0))
	sprite.position.y = -21
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV); float green=c.g-max(c.r,c.b); c.a*=1.0-smoothstep(0.08,0.3,green); c.g=min(c.g,max(c.r,c.b)+0.08); COLOR=c*COLOR;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	sprite.material = material
	add_child(sprite)

func _physics_process(delta: float) -> void:
	if health <= 0 or not is_instance_valid(player):
		return
	clock += delta
	cooldown = maxf(0,cooldown-delta)
	jump_cooldown = maxf(0,jump_cooldown-delta)
	velocity.y = minf(900,velocity.y+1400*delta)
	var offset := player.global_position-global_position
	if attack_timer > 0:
		attack_timer -= delta
		velocity.x = 0
		sprite.frame = 6 if attack_timer > 0.3 else 7
		if attack_timer <= 0.3 and not struck:
			struck = true
			if player.health > 0 and offset.x*facing >= 0 and offset.length() < 115:
				var ray := PhysicsRayQueryParameters2D.create(global_position,player.global_position,1,[get_rid(),player.get_rid()])
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					player.enemy_contact(self,20)
	else:
		var chasing: bool = offset.length() < 430 and player.health > 0
		if chasing and absf(offset.x)>12:
			facing = signf(offset.x)
		elif not chasing:
			facing = 1.0 if sin(clock*0.6)>0 else -1.0
		velocity.x = facing * (85.0 if chasing else 40.0)
		sprite.frame = 2 + int(clock*7) % 2
		if chasing and offset.length()<105 and cooldown <= 0:
			attack_timer = 0.75
			cooldown = 1.7
			struck = false
			velocity.x = 0
			sprite.frame = 6
		elif is_on_floor() and jump_cooldown <= 0 and chasing and (offset.y < -40 or is_on_wall()):
			velocity.y = -670
			jump_cooldown = 1.5
		if not is_on_floor():
			sprite.frame = 4 if velocity.y < 0 else 5
		elif absf(offset.x)<12:
			sprite.frame = 1 if offset.y < -40 else 0
	sprite.flip_h = facing < 0
	move_and_slide()

func take_damage(amount: int) -> bool:
	if health <= 0 or amount <= 0:
		return false
	health = maxi(0,health-amount)
	if health == 0:
		queue_free()
	else:
		sprite.modulate = Color(1,0.5,0.5)
		create_tween().tween_property(sprite,"modulate",Color.WHITE,0.18)
	return true
