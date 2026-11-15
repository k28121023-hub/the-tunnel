extends Area2D
@export var task_number := 1
var opened := false
const PICKUP := preload("res://scripts/box_pickup.gd")
var content := "task"
var box_id := ""
var slot := 0
var open_lid_y := -17.0

func align_with_background_crate() -> void:
	# Cover only the original wooden crate, leaving all surrounding scenery intact.
	$BoxBody.position = Vector2(-16, -19)
	$BoxBody.scale = Vector2(0.67, 0.8)
	$Lid.position = Vector2(-16, -19)
	$Lid.scale = Vector2(0.67, 0.6)
	open_lid_y = -26.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _physics_process(_delta: float) -> void:
	if not opened or _has_pending_task():
		for body in get_overlapping_bodies():
			_on_body_entered(body)

func _on_body_entered(body: Node2D) -> void:
	if (opened and not _has_pending_task()) or body != get_tree().current_scene.get_node_or_null("Player"):
		return
	# Reject stale callbacks unless the actual player collider touches the box.
	if not overlaps_body(body) or body.health <= 0:
		return
	var ray := PhysicsRayQueryParameters2D.create(body.global_position, global_position + Vector2(0, -3), 1, [body.get_rid()])
	if not get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
		return
	var manager = get_tree().current_scene.get_node("WordTasks")
	if opened:
		manager.start_task(task_number, self)
		return
	content = manager.resolve_box(task_number, slot)
	if content == "task" and not manager.start_task(task_number, self):
		return
	opened = true
	manager.opened_boxes[box_id] = true
	var tween := create_tween().set_parallel(true)
	tween.tween_property($Lid, "rotation", -0.65, 0.2)
	tween.tween_property($Lid, "position:y", open_lid_y, 0.2)
	if content != "task":
		tween.chain().tween_callback(_spawn_pickup)

func _has_pending_task() -> bool:
	var manager = get_tree().current_scene.get_node_or_null("WordTasks")
	return manager != null and task_number == manager.completed + 1 and manager.active_task <= manager.completed and manager.TASKS.has(task_number)

func _spawn_pickup() -> void:
	if has_node("Pickup"):
		return
	var pickup := Area2D.new()
	pickup.name = "Pickup"
	pickup.set_script(PICKUP)
	pickup.item_id = content
	pickup.box_id = box_id
	add_child(pickup)

