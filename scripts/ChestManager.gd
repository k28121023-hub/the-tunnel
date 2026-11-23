extends Node2D
const CHEST := preload("res://scripts/TreasureChest.gd")
enum Weapon { NONE, SWORD, LIGHT_CANNON }
var weapon_owned := Weapon.NONE
var armor_owned := false
var player: CharacterBody2D
var points: Array[Vector2] = []
var active_chest: Area2D
var remaining := 0.0
var stopped := false
var last_point := -1

func _ready() -> void:
	_sync_equipment()
	if is_instance_valid(player) and player.has_signal("weapons_lost"):
		player.weapons_lost.connect(_on_weapons_lost)
	spawn_chest()

func _sync_equipment() -> void:
	if not is_instance_valid(player):
		weapon_owned = Weapon.NONE
		armor_owned = false
		return
	if player.inventory.has("sword"): weapon_owned = Weapon.SWORD
	elif player.inventory.has("cannon"): weapon_owned = Weapon.LIGHT_CANNON
	else: weapon_owned = Weapon.NONE
	armor_owned = player.inventory.has("armor")

func _on_weapons_lost() -> void:
	_sync_equipment()
	if not stopped and not is_instance_valid(active_chest):
		remaining = minf(remaining, 0.5)

func choose_reward() -> String:
	_sync_equipment()
	if weapon_owned == Weapon.NONE:
		return ["sword","cannon"].pick_random()
	if not armor_owned:
		return ["armor","potion"].pick_random()
	return "potion"

func grant(item: String) -> void:
	player.acquire_item(item)
	_sync_equipment()

func _physics_process(delta: float) -> void:
	if stopped or is_instance_valid(active_chest): return
	remaining -= delta
	if remaining <= 0: spawn_chest()

func spawn_chest() -> void:
	if stopped or is_instance_valid(active_chest) or points.is_empty(): return
	var choices: Array[int] = []
	for i in range(points.size()):
		if i != last_point and points[i].distance_to(player.global_position) > 48: choices.append(i)
	if choices.is_empty():
		remaining = 1.0
		return
	last_point = choices.pick_random()
	active_chest = Area2D.new()
	active_chest.set_script(CHEST)
	active_chest.name = "TreasureChest"
	active_chest.manager = self
	active_chest.position = points[last_point]
	add_child(active_chest)
	active_chest.opened.connect(func():
		active_chest = null
		remaining = randf_range(6,12))

func stop() -> void:
	stopped = true
	for child in get_children(): child.queue_free()
	active_chest = null
