extends Node2D
## Streams a bounded window of sections, regenerating old sections when backtracking.
signal level_completed
signal question_progress_changed(correct: int, total: int)

const SECTION := preload("res://scenes/DungeonSection.tscn")
const ENDING := preload("res://scenes/EndingSection.tscn")
const SKELETON := preload("res://scripts/skeleton_guard.gd")
var defeated_guards: Dictionary = {}
const SECTION_WIDTH := 2048.0
const ENDING_WIDTH := 768.0
const GENERATE_AHEAD := 1000.0
const KEEP_BEHIND := 2
const KEEP_AHEAD := 2

@export_range(1, 10000) var total_questions: int = 11
@export var correct_answers: int = 0
var shake_remaining := 0.0
var flash_tween: Tween
var ending_index: int = -1
var level_complete := false
var highest_generated_index: int = -1
var sections: Dictionary = {}
var answered_questions: Dictionary = {}

@onready var player: CharacterBody2D = $Player
@onready var camera: Camera2D = $Camera2D
@onready var status: Label = $HUD/Status

func _ready() -> void:
	player.health_changed.connect(_on_health_changed)
	player.damaged.connect(_on_player_damaged)
	_on_health_changed(player.health, player.max_health)
	total_questions = $WordTasks.task_count()
	correct_answers = clampi(correct_answers, 0, total_questions)
	_ensure_section(0)
	_update_stream()
	camera.position = Vector2(player.position.x + 100.0, 341.5)
	camera.reset_smoothing()
	_warmup_draw()
	_prebuild_ahead()

## Call once per correctly answered question, using its stable unique ID.
## Wrong answers do not call this method; repeated IDs do not increase progress.
func record_correct_answer(question_id: StringName) -> void:
	if level_complete or answered_questions.has(question_id) or correct_answers >= total_questions:
		return
	answered_questions[question_id] = true
	correct_answers += 1
	question_progress_changed.emit(correct_answers, total_questions)
	# Scene mutations happen on the next physics frame, outside physics callbacks.

func _physics_process(_delta: float) -> void:
	if not level_complete:
		_update_stream()
	camera.position = Vector2(player.position.x + 100.0, 341.5)

func _update_stream() -> void:
	var current := maxi(0, floori(player.position.x / SECTION_WIDTH))
	if ending_index < 0 and correct_answers >= total_questions and $WordTasks.completed >= $WordTasks.task_count():
		ending_index = highest_generated_index + 1
		camera.limit_right = int(ending_index * SECTION_WIDTH + ENDING_WIDTH)
		_ensure_section(ending_index)
	if ending_index < 0 and player.position.x + GENERATE_AHEAD >= (highest_generated_index + 1) * SECTION_WIDTH:
		_ensure_section(maxi(current, highest_generated_index + 1))
	# Rebuild only a local window, never every visited section.
	var last := mini(highest_generated_index, current + KEEP_AHEAD)
	if ending_index >= 0:
		last = mini(ending_index, current + KEEP_AHEAD)
	for index in range(maxi(0, current - KEEP_BEHIND), last + 1):
		_ensure_section(index)
	for index in sections.keys():
		var tasks = $WordTasks
		var pending_index: int = tasks.active_task - 1 if tasks.active_task > tasks.completed else -1
		if index != pending_index and (index < current - KEEP_BEHIND or index > current + KEEP_AHEAD):
			sections[index].queue_free()
			sections.erase(index)
	# Safe local restart point still exists after earlier sections are recycled.
	var checkpoint_index := current
	if ending_index >= 0:
		checkpoint_index = mini(checkpoint_index, ending_index)
	player.spawn_point = Vector2(checkpoint_index * SECTION_WIDTH + 100.0, 360.0)
	var line := "ANSWERS %d / %d  |  %s" % [correct_answers, total_questions,
		"ROOM OPEN -> Enter the gold doorway for LEVEL 2" if ending_index >= 0 else "Explore the dungeon"]
	# Rewriting Label.text every physics frame forces a reshape; with the
	# fallback text server that hitch shows up as visible stutter.
	if status.text != line:
		status.text = line

func _ensure_section(index: int) -> void:
	if index < 0 or sections.has(index) or (ending_index >= 0 and index > ending_index):
		return
	var is_ending := index == ending_index and ending_index >= 0
	var section: Node2D = (ENDING if is_ending else SECTION).instantiate()
	section.name = ("Ending_" if is_ending else "Dungeon_") + str(index)
	section.position.x = index * SECTION_WIDTH
	$Sections.add_child(section)
	sections[index] = section
	if is_ending:
		section.exit_reached.connect(_on_exit_reached)
	else:
		highest_generated_index = maxi(highest_generated_index, index)
		$WordTasks.configure_section(section, index)
		for guard_slot in range(2):
			var guard_id := "%d:%d" % [index, guard_slot]
			if defeated_guards.has(guard_id): continue
			var guard := CharacterBody2D.new()
			guard.set_script(SKELETON)
			guard.name = "SkeletonGuard%d" % guard_slot
			guard.player = player
			guard.patrol_left = 280.0 if guard_slot == 0 else 1010.0
			guard.patrol_right = 365.0 if guard_slot == 0 else 1090.0
			guard.position = Vector2((guard.patrol_left + guard.patrol_right) * 0.5, 370)
			guard.defeated.connect(func(): defeated_guards[guard_id] = true)
			section.add_child(guard)

func _on_exit_reached() -> void:
	if level_complete or correct_answers < total_questions or $WordTasks.completed < $WordTasks.task_count():
		return
	if not sections.has(ending_index) or not sections[ending_index].get_node("Exit").overlaps_body(player) or player.health <= 0:
		return
	level_complete = true
	player.velocity = Vector2.ZERO
	player.set_physics_process(false)
	status.text = "Entering LEVEL 2..."
	level_completed.emit()
	get_tree().set_meta("level_two_player", {"health": player.health, "inventory": player.inventory.duplicate(), "armor_hits": player.armor_hits, "active_weapon": player.active_weapon})
	get_tree().call_deferred("change_scene_to_file", "res://scenes/dungeon_level_02.tscn")

func _unhandled_key_input(event: InputEvent) -> void:
	if level_complete and event.is_action_pressed("restart"):
		get_tree().reload_current_scene()

func _on_health_changed(current: int, maximum: int) -> void:
	$HUD/Health.text = "HP %d / %d" % [current, maximum]

func _on_player_damaged() -> void:
	shake_remaining = 0.25
	if flash_tween:
		flash_tween.kill()
	$HUD/DamageFlash.color.a = 0.18
	flash_tween = create_tween()
	flash_tween.tween_property($HUD/DamageFlash, "color:a", 0.0, 0.22)

func _process(delta: float) -> void:
	shake_remaining = maxf(0.0, shake_remaining - delta)
	var strength := 5.0 * shake_remaining / 0.25
	camera.offset = Vector2(randf_range(-strength, strength), randf_range(-strength, strength)) if shake_remaining > 0.0 else Vector2.ZERO

func _warmup_draw() -> void:
	# Compile the guard walk shader and upload shared combat textures before
	# the first streamed section would otherwise hitch mid-stride.
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/antler_guard.png")
	var material := ShaderMaterial.new()
	material.shader = preload("res://scripts/antler_walk.gdshader")
	sprite.material = material
	sprite.position = Vector2(-10000, -10000)
	sprite.modulate.a = 0.0
	add_child(sprite)
	get_tree().create_timer(0.4).timeout.connect(sprite.queue_free)

func _prebuild_ahead() -> void:
	# Build the next dungeon section after the first frames so walking into
	# it does not pay the full instantiate cost on the same frame as input.
	await get_tree().create_timer(0.35).timeout
	if ending_index < 0 and not sections.has(highest_generated_index + 1):
		_ensure_section(highest_generated_index + 1)
