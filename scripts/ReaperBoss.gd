extends CharacterBody2D
signal defeated
const TARGET := preload("res://scripts/WordTarget.gd")
const SHEET := preload("res://assets/reaper_poses.png")
var questions: Node
var player: CharacterBody2D
var points: Array[Vector2] = []
var health := 5
var dying := false
var teleporting := false
var teleport_timer := 3.0
var contact_area: Area2D
var effect := 0.0
var clock := 0.0
var sprite: Sprite2D
var words: Node2D
var word_queue: Array = []
var current_word := ""
var word_remaining := 3.0
const WORD_INTERVAL := 3.0
const SCYTHE_REACH := 115.0
var attack_remaining := 0.0
var attack_cooldown := 1.0
var attack_direction := 1.0
var attack_struck := false

func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var hit := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28, 64)
	hit.shape = shape
	add_child(hit)
	contact_area = Area2D.new()
	contact_area.name = "ContactDamage"
	contact_area.collision_layer = 0
	contact_area.collision_mask = 2
	var contact_shape := CollisionShape2D.new()
	contact_shape.shape = shape
	contact_area.add_child(contact_shape)
	add_child(contact_area)
	sprite = Sprite2D.new()
	sprite.texture = SHEET
	sprite.hframes = 4
	sprite.vframes = 2
	sprite.scale = Vector2.ONE * (105.0 / (SHEET.get_height() / 2.0))
	sprite.position.y = -20
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment(){vec4 c=texture(TEXTURE,UV); float green=c.g-max(c.r,c.b); c.a*=1.0-smoothstep(0.08,0.3,green); c.g=min(c.g,max(c.r,c.b)+0.08); COLOR=c*COLOR;}"
	var material := ShaderMaterial.new()
	material.shader = shader
	sprite.material = material
	add_child(sprite)
	words = Node2D.new()
	words.z_index = 10
	add_child(words)
	questions.correct_answer.connect(_correct)
	questions.changed.connect(rebuild_words)
	rebuild_words()

func take_damage(_amount: int) -> bool:
	# The body is never a weapon target. Only the question manager awards damage.
	return false

func rebuild_words() -> void:
	word_queue.clear()
	current_word = ""
	_advance_word()

func _advance_word() -> void:
	for child in words.get_children():
		child.collision_layer = 0
		words.remove_child(child)
		child.queue_free()
	if dying or questions.current >= 5:
		return
	# A shuffled bag guarantees every answer appears once per four-word cycle.
	if word_queue.is_empty():
		word_queue = questions.QUESTIONS[questions.current].options.duplicate()
		word_queue.shuffle()
		if word_queue[0] == current_word:
			word_queue.push_back(word_queue.pop_front())
	current_word = word_queue.pop_front()
	word_remaining = WORD_INTERVAL
	var target := StaticBody2D.new()
	target.set_script(TARGET)
	target.word = current_word
	target.question = questions.current
	target.boss = self
	target.position = Vector2(0,17)
	words.add_child(target)
	if teleporting: target.collision_layer = 0

func _correct() -> void:
	health = 5 - questions.current
	effect = 1.0
	if health == 0:
		die()

func safe_point(point: Vector2) -> bool:
	if point.distance_to(player.global_position) < 150:
		return false
	var shape := RectangleShape2D.new()
	shape.size = Vector2(28,64)
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0, point)
	query.collision_mask = 1
	if not get_world_2d().direct_space_state.intersect_shape(query).is_empty():
		return false
	var ray := PhysicsRayQueryParameters2D.create(point + Vector2(0,31), point + Vector2(0,38), 1)
	return not get_world_2d().direct_space_state.intersect_ray(ray).is_empty()

func teleport() -> void:
	if dying or teleporting or attack_remaining > 0.0:
		return
	var candidates: Array[Vector2] = []
	for point in points:
		if point.distance_to(global_position) > 80 and safe_point(point):
			candidates.append(point)
	if candidates.is_empty():
		teleport_timer = 1.0
		return
	teleporting = true
	words.hide()
	for child in words.get_children(): child.collision_layer = 0
	effect = 1.0
	var destination: Vector2 = candidates.pick_random()
	var tween := create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.25)
	await tween.finished
	if dying: return
	if not safe_point(destination):
		destination = global_position
	global_position = destination
	effect = 1.0
	# Teleport carries the current word without resetting its three-second cycle.
	words.show()
	for child in words.get_children(): child.collision_layer = 0
	var fade := create_tween()
	fade.tween_property(sprite, "modulate:a", 1.0, 0.25)
	await fade.finished
	if dying: return
	for child in words.get_children(): child.collision_layer = 8
	teleporting = false
	teleport_timer = randf_range(2,4)

func _physics_process(delta: float) -> void:
	clock += delta
	effect = maxf(0, effect - delta)
	queue_redraw()
	if dying: return
	word_remaining -= delta
	if word_remaining <= 0:
		_advance_word()
	if teleporting: return
	if is_instance_valid(player) and player.health > 0 and contact_area.overlaps_body(player):
		player.enemy_contact(self, 20)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	var offset := player.global_position - global_position
	if attack_remaining > 0.0:
		attack_remaining = maxf(0.0, attack_remaining - delta)
		sprite.frame = 6 if attack_remaining > 0.3 else 7
		if attack_remaining <= 0.3 and not attack_struck:
			attack_struck = true
			if player.health > 0 and offset.x * attack_direction >= 0 and offset.length() <= SCYTHE_REACH:
				var ray := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1, [get_rid(), player.get_rid()])
				if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
					player.enemy_contact(self, 20)
		return
	sprite.flip_h = offset.x < 0
	sprite.frame = 0
	if player.health > 0 and offset.length() <= SCYTHE_REACH and attack_cooldown <= 0.0:
		attack_direction = -1.0 if sprite.flip_h else 1.0
		attack_remaining = 0.75
		attack_cooldown = 1.7
		attack_struck = false
		sprite.frame = 6
		return
	teleport_timer -= delta
	if teleport_timer <= 0:
		teleport()

func die() -> void:
	if dying: return
	dying = true
	attack_remaining = 0.0
	contact_area.set_deferred("monitoring", false)
	words.hide()
	for child in words.get_children(): child.collision_layer = 0
	collision_layer = 0
	effect = 2.0
	var tween := create_tween()
	tween.tween_property(sprite, "modulate", Color(0.2,0.8,1,0), 1.4)
	await tween.finished
	hide()
	defeated.emit()

func _draw() -> void:
	if attack_remaining > 0.0 and attack_remaining <= 0.3 and not dying:
		var sweep := (0.3 - attack_remaining) / 0.3
		var angle := lerpf(-1.2, 1.2, sweep)
		if attack_direction < 0: angle = PI - angle
		draw_arc(Vector2.ZERO, SCYTHE_REACH, angle - 0.45, angle + 0.45, 18, Color(0.65, 0.95, 1.0, 1.0 - sweep), 5.0, true)
	if effect > 0:
		for i in range(12):
			var angle := i * TAU / 12 + clock * 2
			var point := Vector2(cos(angle)*30, sin(angle)*42-10) * (2.2-effect*0.5)
			draw_circle(point, 3 + effect, Color(0.1,0.7,1,minf(effect,1)))
