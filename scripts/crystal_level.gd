extends "res://scripts/dungeon_level.gd"
const HALL := preload("res://assets/crystal_hall.png")
const CROW := preload("res://scenes/CageCrow.tscn")
const REAPER := preload("res://scripts/reaper.gd")
var throne: Area2D

func _ready() -> void:
	total_questions = 1
	player.spawn_point = Vector2(90, 440)
	player.position = player.spawn_point
	if get_tree().has_meta("level_two_player"):
		var saved: Dictionary = get_tree().get_meta("level_two_player")
		get_tree().remove_meta("level_two_player")
		player.inventory = saved.inventory.duplicate()
		player.armor_hits = saved.armor_hits
		player.active_weapon = saved.active_weapon
		player.health = saved.health
		player._update_items()
	player.health_changed.connect(_on_health_changed)
	player.damaged.connect(_on_player_damaged)
	_on_health_changed(player.health, player.max_health)
	var hall := Node2D.new()
	hall.name = "CrystalHall"
	$Sections.add_child(hall)
	sections[0] = hall
	var geometry := Node2D.new()
	geometry.name = "Geometry"
	hall.add_child(geometry)
	# Rectangles match the supplied image, scaled together with the artwork.
	for rect in [Rect2(0,765,1672,42), Rect2(0,0,47,941), Rect2(1624,0,48,941), Rect2(0,0,1672,64)]:
		_add_solid(geometry, rect, false)
	for rect in [Rect2(48,502,216,24), Rect2(256,359,275,43), Rect2(521,520,193,40), Rect2(1194,520,183,40), Rect2(1367,359,214,43)]:
		_add_solid(geometry, rect, true)
	$WordTasks.configure_section(hall, 0, [Vector2(175,449), Vector2(650,449)], Vector2(890,449), false)
	for spot in [Vector2(250,175), Vector2(810,195)]:
		var crow := CROW.instantiate()
		crow.position = spot
		hall.add_child(crow)
	throne = Area2D.new()
	var reaper := CharacterBody2D.new()
	reaper.name = "CrystalReaper"
	reaper.set_script(REAPER)
	reaper.player = player
	reaper.position = Vector2(730,420)
	hall.add_child(reaper)
	throne.name = "ThroneExit"
	throne.position = Vector2(574,433)
	throne.collision_layer = 0
	throne.collision_mask = 2
	var hit := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(90,55)
	hit.shape = shape
	throne.add_child(hit)
	hall.add_child(throne)
	camera.limit_right = 1004
	camera.limit_bottom = 565
	camera.position = Vector2(502,282)
	camera.reset_smoothing()
	status.text = "LEVEL 2 | Crystal Hall | Find the task box"

func _add_solid(parent: Node, rect: Rect2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.position = (rect.position + rect.size * 0.5) * 0.6
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size * 0.6
	collision.shape = shape
	collision.one_way_collision = one_way
	body.add_child(collision)
	parent.add_child(body)

func _physics_process(_delta: float) -> void:
	camera.position = Vector2(clampf(player.position.x, 260,744),282)
	if level_complete:
		return
	if correct_answers >= total_questions:
		status.text = "LEVEL 2 | Quiz complete - return to the crystal throne"
		if throne.overlaps_body(player):
			level_complete = true
			# Keep movement and gravity active when completing the hall in mid-jump.
			status.text = "LEVEL 2 COMPLETE | A/D: Move | W: Jump | R: Replay"
			level_completed.emit()
	else:
		status.text = "LEVEL 2 | Task %d | Answers %d / %d" % [$WordTasks.active_task,correct_answers,total_questions]
