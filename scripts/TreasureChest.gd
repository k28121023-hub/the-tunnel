extends Area2D
signal opened
const ITEMS := preload("res://scripts/box_items.gd")
var manager: Node
var used := false
var lid: Sprite2D
const CHEST_TEXTURE := preload("res://assets/word_chest_original.png")

func _ready() -> void:
	collision_layer = 0
	collision_mask = 2
	var hit := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(36,28)
	hit.shape = shape
	add_child(hit)
	# Reuse the existing treasure chest artwork with a separately hinged lid.
	var body := Sprite2D.new()
	body.name = "ChestBody"
	body.texture = CHEST_TEXTURE
	body.centered = false
	body.region_enabled = true
	body.region_rect = Rect2(10,49,59,25)
	body.region_filter_clip_enabled = true
	body.scale = Vector2.ONE * 0.6
	body.position = Vector2(-17.7,-1)
	add_child(body)
	lid = Sprite2D.new()
	lid.name = "ChestLid"
	lid.texture = CHEST_TEXTURE
	lid.centered = false
	lid.region_enabled = true
	lid.region_rect = Rect2(10,28,59,21)
	lid.region_filter_clip_enabled = true
	lid.scale = Vector2.ONE * 0.6
	lid.position = Vector2(-17.7,-1)
	lid.offset = Vector2(0,-21)
	add_child(lid)

func _physics_process(_delta: float) -> void:
	if used or manager.stopped: return
	if overlaps_body(manager.player) and manager.player.health > 0:
		var ray := PhysicsRayQueryParameters2D.create(manager.player.global_position, global_position, 1, [manager.player.get_rid()])
		if get_world_2d().direct_space_state.intersect_ray(ray).is_empty():
			open()

func open() -> void:
	if used or manager.stopped: return
	used = true
	var reward: String = manager.choose_reward()
	manager.grant(reward)
	opened.emit()
	var icon := ITEMS.sprite_for(reward,32)
	add_child(icon)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(lid,"rotation",-0.8,0.25)
	tween.tween_property(icon,"position:y",-42,0.6)
	tween.tween_property(self,"modulate:a",0,1.0).set_delay(0.5)
	tween.chain().tween_callback(queue_free)
