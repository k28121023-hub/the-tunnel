extends Area2D
signal collected
const ITEMS := preload("res://scripts/box_items.gd")
const LOS := preload("res://scripts/interact_los.gd")
var item_id := "sword"
var box_id := ""
var ready_to_collect := false
var consumed := false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	z_index = 8
	var hit := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	hit.shape = circle
	add_child(hit)
	add_child(ITEMS.sprite_for(item_id, 40.0))
	body_entered.connect(_try_collect)
	# Stay at the opened box; never chase the player or grant loot on a timer.
	var tween := create_tween()
	tween.tween_property(self, "position:y", -42.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", -28.0, 0.2)
	tween.tween_callback(func(): ready_to_collect = true)

func _physics_process(_delta: float) -> void:
	if ready_to_collect and not consumed:
		for body in get_overlapping_bodies():
			_try_collect(body)

func _try_collect(body: Node2D) -> void:
	if consumed or not ready_to_collect or not overlaps_body(body):
		return
	if body != get_tree().current_scene.get_node_or_null("Player") or body.health <= 0:
		return
	if LOS.blocked(get_world_2d(), body.global_position, global_position, [body.get_rid()]):
		return
	consumed = true
	get_tree().current_scene.get_node("WordTasks").collected_boxes[box_id] = true
	body.acquire_item(item_id)
	collected.emit()
	queue_free()
