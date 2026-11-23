extends CharacterBody2D

signal health_changed(current: int, maximum: int)
signal damaged
signal respawned
signal items_changed
signal weapons_lost
@export var retain_weapons_on_hit := false
@export var max_health := 100
@export var hurt_invulnerability := 1.0
var health := 100
var hurt_remaining := 0.0
var defeat_remaining := 0.0
const ITEMS := preload("res://scripts/box_items.gd")
const WAVE := preload("res://scripts/cannon_wave.gd")
const SLASH := preload("res://scripts/sword_slash.gd")
var active_weapon := ""
var cannon_wave: Node2D
var cannon_cooldown := 0.0
var cannon_input_buffer := 0.0
var weapon_visual: Node2D
var armor_visual: Sprite2D
var swing: Node2D
var swing_remaining := 0.0
var inventory: Dictionary = {}
var armor_hits := 0
var item_icons: Node2D
var facing := 1.0
var attack_line: Line2D
var attack_time := 0.0
var pickup_notice := ""
var notice_time := 0.0

const SPEED := 240.0
const JUMP_SPEED := -650.0
const GRAVITY := 1400.0
var jumping := false
var touch_controls: CanvasLayer
var touch_jump_boost := 0.0
var cat_animation_time := 0.0
var walk_phase := 0.0
var walk_weight := 0.0
var body_lean := 0.0
var landing_weight := 0.0
var walk_material: ShaderMaterial
const STRIDE_LENGTH := 64.0
const WALK_SHADER := """
shader_type canvas_item;
uniform vec4 region;
uniform float phase = 0.0;
uniform float weight = 0.0;
varying vec4 tint;
void vertex() {
	tint = COLOR;
}
void fragment() {
	vec2 p = (UV - region.xy) / region.zw;
	// Blend from hips into alternating paws; keep the face stable.
	float legs = smoothstep(0.72, 0.94, p.y);
	float side = smoothstep(0.49, 0.72, p.x) * 2.0 - 1.0;
	p.x -= sin(phase) * side * legs * 0.045 * weight;
	p.y += max(0.0, cos(phase) * side) * legs * 0.035 * weight;
	// A small follow-through in the tail and scarf.
	float trailing = (1.0 - smoothstep(0.18, 0.43, p.x)) * smoothstep(0.3, 0.5, p.y) * (1.0 - smoothstep(0.75, 0.9, p.y));
	p.y += sin(phase - 0.7) * trailing * 0.012 * weight;
	vec4 tex = texture(TEXTURE, region.xy + clamp(p, vec2(0.0), vec2(1.0)) * region.zw);
	tex.a *= step(0.0, p.x) * step(p.x, 1.0) * step(0.0, p.y) * step(p.y, 1.0);
	COLOR = tex * tint;
}
"""
var crouching := false
var coyote_time := 0.0
var jump_buffer := 0.0
const SIDE_REGION := Rect2(20, 48, 766, 780)
const CROUCH_REGION := Rect2(879, 409, 875, 414)
const CAT_SCALE := 48.0 / 780.0
const ARMORED_CAT := preload("res://assets/cat_armored_poses.png")
const NORMAL_CAT := preload("res://assets/cat_poses.png")
const REQUIRED_INPUTS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"crouch": [KEY_DOWN, KEY_S],
	"jump": [KEY_SHIFT, KEY_UP, KEY_W],
	"restart": [KEY_R],
	"attack": [KEY_SPACE],
	"switch_weapon": [KEY_Q],
}
var entered_water := false

var spawn_point := Vector2(100, 360)

func _ready() -> void:
	health = max_health
	$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
	$CatSprite.region_enabled = true
	$CatSprite.scale = Vector2.ONE * CAT_SCALE
	var walk_shader := Shader.new()
	walk_shader.code = WALK_SHADER
	walk_material = ShaderMaterial.new()
	walk_material.shader = walk_shader
	var texture_size := Vector2(NORMAL_CAT.get_size())
	walk_material.set_shader_parameter("region", Vector4(SIDE_REGION.position.x / texture_size.x, SIDE_REGION.position.y / texture_size.y, SIDE_REGION.size.x / texture_size.x, SIDE_REGION.size.y / texture_size.y))
	_update_cat_pose()
	var hud := CanvasLayer.new()
	add_child(hud)
	item_icons = Node2D.new()
	item_icons.position = Vector2(42, 126)
	hud.add_child(item_icons)
	attack_line = Line2D.new()
	attack_line.width = 5.0
	add_child(attack_line)
	weapon_visual = Node2D.new()
	weapon_visual.z_index = 7
	add_child(weapon_visual)
	armor_visual = ITEMS.sprite_for("armor", 24.0)
	armor_visual.name = "WornArmor"
	armor_visual.z_index = 1
	add_child(armor_visual)
	_update_items()
	for obsolete in ["sword_attack", "cannon_attack", "move_up", "move_down"]:
		if InputMap.has_action(obsolete):
			InputMap.erase_action(obsolete)
	# Use named Godot key constants; also repairs stale editor input settings.
	for action in REQUIRED_INPUTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		for code in REQUIRED_INPUTS[action]:
			var event := InputEventKey.new()
			event.physical_keycode = code
			InputMap.action_add_event(action, event)

	touch_controls = CanvasLayer.new()
	touch_controls.set_script(preload("res://scripts/touch_controls.gd"))
	add_child(touch_controls)

func _physics_process(delta: float) -> void:
	cannon_cooldown = maxf(0.0,cannon_cooldown-delta)
	cannon_input_buffer = maxf(0.0,cannon_input_buffer-delta)
	swing_remaining = maxf(0.0, swing_remaining - delta)
	weapon_visual.scale.x = facing
	weapon_visual.visible = swing_remaining == 0.0
	attack_time = maxf(0.0, attack_time - delta)
	attack_line.visible = attack_time > 0.0
	notice_time = maxf(0.0, notice_time - delta)
	if notice_time == 0.0 and not pickup_notice.is_empty():
		pickup_notice = ""
		_update_items()
	hurt_remaining = maxf(0.0, hurt_remaining - delta)
	modulate = Color(1.0, 0.35, 0.35, 0.6) if hurt_remaining > 0.0 and int(hurt_remaining * 12.0) % 2 == 0 else Color.WHITE
	if defeat_remaining > 0.0:
		defeat_remaining -= delta
		if defeat_remaining <= 0.0:
			respawn()
		return
	var grounded := is_on_floor()
	coyote_time = 0.1 if grounded else maxf(0.0, coyote_time - delta)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer = 0.12
	_set_crouching(Input.is_action_pressed("crouch") and grounded)
	if grounded:
		jumping = false
		velocity.y = 0.0
	else:
		var gravity_scale := 1.0
		if touch_controls.enabled and velocity.y < 0 and touch_jump_boost > 0 and Input.is_action_pressed("jump"):
			gravity_scale = 0.55
		touch_jump_boost = maxf(0.0,touch_jump_boost-delta)
		velocity.y = minf(velocity.y + GRAVITY * gravity_scale * delta, 1000.0)
	# Vertical input never sets vertical velocity. Every jump follows gravity.
	var direction := Input.get_axis("move_left", "move_right")
	velocity.x = direction * (SPEED * 0.3 if crouching else SPEED)
	if velocity.x != 0.0:
		facing = signf(velocity.x)
	if Input.is_action_just_pressed("switch_weapon"):
		switch_weapon()
	if Input.is_action_just_pressed("attack"):
		if active_weapon == "cannon": cannon_input_buffer = 0.22
		attack_selected()
	elif active_weapon == "cannon" and (Input.is_action_pressed("attack") or cannon_input_buffer > 0):
		attack_selected()
	if jump_buffer > 0.0 and coyote_time > 0.0 and not crouching:
		jumping = true
		velocity.y = JUMP_SPEED
		touch_jump_boost = 0.22
		jump_buffer = 0.0
		coyote_time = 0.0
	# A released key shortens the jump; holding it cannot restart or hover.
	if not touch_controls.enabled and Input.is_action_just_released("jump") and velocity.y < -300.0:
		velocity.y = -300.0
	var previous_position := position
	var fall_speed := velocity.y
	move_and_slide()
	_update_walk_motion(delta, position.x - previous_position.x, grounded, fall_speed)
	cat_animation_time += delta
	_update_cat_pose()
	weapon_visual.scale.x = facing
	weapon_visual.position.y = 9.0 if crouching else -absf(sin(walk_phase)) * 1.4 * walk_weight
	weapon_visual.rotation = body_lean * 0.5
	if (position.y > 750.0 and not entered_water) or Input.is_action_just_pressed("restart"):
		respawn()

## Water only tracks contact; normal gravity, movement and jumping continue.
func enter_water() -> bool:
	if entered_water:
		return false
	entered_water = true
	return true

func exit_water() -> void:
	entered_water = false

func take_damage(amount: int, ignore_invulnerability := false) -> void:
	if (hurt_remaining > 0.0 and not ignore_invulnerability) or health <= 0 or amount <= 0:
		return
	health = maxi(0, health - amount)
	hurt_remaining = hurt_invulnerability
	health_changed.emit(health, max_health)
	damaged.emit()
	if health == 0:
		defeat_remaining = 0.35

func respawn() -> void:
	walk_phase = 0.0
	walk_weight = 0.0
	body_lean = 0.0
	landing_weight = 0.0
	jumping = false
	coyote_time = 0.0
	jump_buffer = 0.0
	crouching = false
	$CollisionShape2D.shape.size = Vector2(22, 36)
	$CollisionShape2D.position = Vector2.ZERO
	_update_cat_pose()
	inventory.clear()
	armor_hits = 0
	pickup_notice = ""
	_update_items()
	health = max_health
	hurt_remaining = hurt_invulnerability
	defeat_remaining = 0.0
	modulate = Color.WHITE
	health_changed.emit(health, max_health)
	position = spawn_point
	velocity = Vector2.ZERO
	entered_water = false
	respawned.emit()

func _can_stand() -> bool:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(22, 35.5)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = global_transform
	query.transform.origin.y -= 0.25
	query.collision_mask = collision_mask
	query.exclude = [get_rid()]
	return get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty()

func _set_crouching(requested: bool) -> void:
	if not requested and crouching and not _can_stand():
		return
	if crouching == requested:
		return
	crouching = requested
	$CollisionShape2D.shape.size = Vector2(22, 18) if crouching else Vector2(22, 36)
	$CollisionShape2D.position.y = 9.0 if crouching else 0.0

func _update_walk_motion(delta: float, distance_x: float, was_grounded: bool, fall_speed: float) -> void:
	var walking := is_on_floor() and not crouching and absf(distance_x) > 0.01
	var target_weight := clampf(absf(distance_x) / maxf(delta * SPEED, 0.001), 0.0, 1.0) if walking else 0.0
	walk_weight = move_toward(walk_weight, target_weight, delta * 10.0)
	if walking:
		walk_phase = fposmod(walk_phase + absf(distance_x) / STRIDE_LENGTH * TAU, TAU)
	elif walk_weight == 0.0:
		walk_phase = 0.0
	body_lean = lerpf(body_lean, facing * 0.045 * target_weight, 1.0 - exp(-14.0 * delta))
	landing_weight = move_toward(landing_weight, 0.0, delta * 6.0)
	if is_on_floor() and not was_grounded and fall_speed > 180.0:
		landing_weight = minf(fall_speed / 800.0, 1.0)

func _apply_walk_pose() -> void:
	var bob := absf(sin(walk_phase)) * walk_weight
	var squash := landing_weight * 0.09 + cos(walk_phase * 2.0) * walk_weight * 0.018
	if crouching:
		return
	$CatSprite.scale *= Vector2(1.0 + squash * 0.5, 1.0 - squash)
	# Scale around the feet so landing compression does not sink into the floor.
	$CatSprite.position.y += 24.0 * squash - bob * 1.4
	$CatSprite.rotation = body_lean + sin(walk_phase) * walk_weight * 0.012

func _update_cat_pose() -> void:
	$CatSprite.material = null
	if inventory.has("armor"):
		var frame := 4
		var step := int(walk_phase / PI) % 2
		if crouching:
			frame = 7
		elif not is_on_floor():
			frame = 6 if absf(velocity.x) > 1.0 else (2 + step if velocity.y < 0.0 else step)
		elif absf(velocity.x) > 1.0:
			frame = 4 + step
		var cell := Vector2(ARMORED_CAT.get_width() / 4.0, ARMORED_CAT.get_height() / 2.0)
		$CatSprite.texture = ARMORED_CAT
		$CatSprite.region_rect = Rect2(Vector2(frame % 4, frame / 4) * cell, cell)
		$CatSprite.scale = Vector2.ONE * (48.0 / cell.y)
		$CatSprite.position.y = 18.0 - 24.0
		$CatSprite.flip_h = facing < 0.0 and frame >= 4
		$CatSprite.rotation = 0.0
		_apply_walk_pose()
		_update_armor_pose()
		return
	$CatSprite.texture = NORMAL_CAT
	$CatSprite.scale = Vector2.ONE * CAT_SCALE
	var region := CROUCH_REGION if crouching else SIDE_REGION
	$CatSprite.region_rect = region
	$CatSprite.position.y = 18.0 - region.size.y * CAT_SCALE * 0.5
	$CatSprite.flip_h = facing < 0.0
	$CatSprite.rotation = 0.0
	if not crouching and walk_material != null:
		$CatSprite.material = walk_material
		walk_material.set_shader_parameter("phase", walk_phase)
		walk_material.set_shader_parameter("weight", walk_weight)
	_apply_walk_pose()
	_update_armor_pose()

func _update_armor_pose() -> void:
	if not is_instance_valid(armor_visual):
		return
	# Armor is painted into the full character frames, not overlaid as an icon.
	armor_visual.visible = false
	armor_visual.flip_h = facing < 0.0
	armor_visual.position = Vector2(-5.0 * facing, 7.0 if crouching else 5.0)
	armor_visual.rotation = -0.65 * facing if crouching else $CatSprite.rotation

func acquire_item(item_id: String) -> void:
	if health <= 0 or not ITEMS.DATA.has(item_id):
		return
	if item_id == "potion":
		health = mini(max_health, health + 25)
		health_changed.emit(health, max_health)
	else:
		# One slot per type; duplicates never create hidden extra charges.
		if item_id == "armor" and not inventory.has("armor"):
			armor_hits = 2
		inventory[item_id] = true
		if item_id in ["sword", "cannon"]:
			active_weapon = item_id
	pickup_notice = item_id if item_id == "potion" else ""
	notice_time = 2.0
	_update_items()

func _update_items() -> void:
	_update_cat_pose()
	if not inventory.has(active_weapon):
		active_weapon = "sword" if inventory.has("sword") else ("cannon" if inventory.has("cannon") else "")
	if not is_instance_valid(item_icons):
		return
	for icon in item_icons.get_children():
		item_icons.remove_child(icon)
		icon.queue_free()
	var shown: Array = inventory.keys()
	if pickup_notice == "potion":
		shown.append("potion")
	for index in range(shown.size()):
		var slot := Node2D.new()
		slot.position.x = index * 52.0
		item_icons.add_child(slot)
		slot.add_child(ITEMS.sprite_for(shown[index], 46.0))
		if shown[index] in ["sword", "cannon"]:
			var key := Label.new()
			key.text = "Space" if shown[index] == active_weapon else "Q"
			key.add_theme_font_size_override("font_size", 12)
			key.position = Vector2(-16, 24)
			slot.add_child(key)
	for child in weapon_visual.get_children():
		weapon_visual.remove_child(child)
		child.queue_free()
	if not active_weapon.is_empty():
		var held := ITEMS.sprite_for(active_weapon, 38.0)
		# Lift the sword so its grip meets the raised front paw.
		held.position = Vector2(18, -14 if active_weapon == "sword" else -2)
		weapon_visual.add_child(held)
	items_changed.emit()

func enemy_contact(enemy: Node2D, amount: int) -> void:
	if health <= 0 or hurt_remaining > 0.0 or amount <= 0 or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
		return
	if inventory.has("armor"):
		armor_hits = maxi(0, armor_hits - 1)
		if armor_hits == 0:
			inventory.erase("armor")
		hurt_remaining = hurt_invulnerability
		_update_items()
		return
	# Only a successful enemy hit removes weapons. Attacking never consumes them.
	var lost_weapon := false
	take_damage(amount)
	if not retain_weapons_on_hit:
		lost_weapon = inventory.has("sword") or inventory.has("cannon")
		inventory.erase("sword")
		inventory.erase("cannon")
		swing_remaining = 0.0
		cannon_input_buffer = 0.0
	if is_instance_valid(swing):
		swing.hide()
		if lost_weapon:
			swing.queue_free()
	attack_time = 0.0
	attack_line.hide()
	if is_instance_valid(cannon_wave):
		cannon_wave.queue_free()
	pickup_notice = ""
	_update_items()
	if lost_weapon:
		weapons_lost.emit()

func _attack(item_id: String, reach: float) -> void:
	if not inventory.has(item_id):
		return
	_hit_word_with_sword()
	var target: Node2D = null
	var closest := reach + 1.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion() or not enemy.has_method("take_damage"):
			continue
		var aim: Vector2 = enemy.global_position
		if enemy.has_method("get_damage_rect"):
			var bounds: Rect2 = enemy.get_damage_rect()
			aim = global_position.clamp(bounds.position, bounds.end)
		var offset: Vector2 = aim - global_position
		if offset.x * facing < 0.0 or absf(offset.y) > 72.0 or offset.length() > reach:
			continue
		var ray := PhysicsRayQueryParameters2D.create(global_position, aim, 1, [get_rid(), enemy.get_rid()])
		if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			continue
		if offset.length() < closest:
			closest = offset.length()
			target = enemy
	if item_id == "sword":
		var slash := Node2D.new()
		slash.set_script(SLASH)
		slash.name = "SwordSlash"
		slash.z_index = 8
		slash.scale.x = facing
		slash.position.y = 9.0 if crouching else 0.0
		add_child(slash)
	if target != null:
		target.take_damage(1)

func switch_weapon() -> void:
	var other := "cannon" if active_weapon == "sword" else "sword"
	if inventory.has(other):
		active_weapon = other
		_update_items()

func attack_selected() -> void:
	if health <= 0 or not inventory.has(active_weapon):
		return
	if active_weapon == "cannon":
		if cannon_cooldown > 0:
			return
		cannon_cooldown = 0.2
		cannon_input_buffer = 0.0
		cannon_wave = Node2D.new()
		cannon_wave.set_script(WAVE)
		cannon_wave.shooter = self
		cannon_wave.direction = facing
		get_parent().add_child(cannon_wave)
		cannon_wave.global_position = global_position + Vector2(0, 9 if crouching else 0)
	else:
		if swing_remaining > 0.0:
			return
		swing_remaining = 0.24
		swing = Node2D.new()
		swing.z_index = 7
		swing.scale.x = facing
		# Rotate around the same hand used by the resting sword.
		swing.position = Vector2(18 * facing, 7.0 if crouching else -2.0)
		add_child(swing)
		var blade := ITEMS.sprite_for("sword", 62.0)
		blade.position = Vector2(0, -25)
		swing.add_child(blade)
		swing.rotation = -0.55 * facing
		var tween := create_tween()
		tween.tween_property(swing, "rotation", 2.3 * facing, 0.22)
		tween.tween_callback(swing.queue_free)
		_attack("sword", 150.0)

func cannon_hit(enemy: Node2D) -> bool:
	if not inventory.has("cannon") or health <= 0:
		return false
	return enemy.take_damage(1)

func _hit_word_with_sword() -> void:
	var shape := RectangleShape2D.new()
	shape.size = Vector2(76,32)
	var origin := global_position + Vector2(42*facing,9 if crouching else 0)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0,origin)
	query.collision_mask = 8
	var hits := get_world_2d().direct_space_state.intersect_shape(query,16)
	hits.sort_custom(func(a: Dictionary,b: Dictionary): return global_position.distance_squared_to(a.collider.global_position) < global_position.distance_squared_to(b.collider.global_position))
	for hit in hits:
		var word = hit.collider
		if not word.has_method("hit_by_weapon"): continue
		var ray := PhysicsRayQueryParameters2D.create(global_position,word.global_position,1,[get_rid()])
		if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			word.hit_by_weapon()
			break



