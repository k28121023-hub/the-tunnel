extends Area2D
## Origin is the water surface; the collision rectangle extends below it.
const SPLASH := preload("res://scenes/WaterSplash.tscn")
var water_surface_y: float

func _ready() -> void:
	water_surface_y = global_position.y
	body_entered.connect(_on_water_area_body_entered)
	body_exited.connect(_on_water_area_body_exited)

func _on_water_area_body_entered(body: Node2D) -> void:
	if body == get_tree().current_scene.get_node_or_null("Player"):
		player_enter_water(body)

func player_enter_water(player: Node2D) -> void:
	if not player.has_method("enter_water") or not player.enter_water():
		return
	water_surface_y = global_position.y
	var splash := SPLASH.instantiate() as Node2D
	# Set position before _ready starts the GPU burst and first ripple.
	splash.position = to_local(Vector2(player.global_position.x, water_surface_y))
	add_child(splash)

func _on_water_area_body_exited(body: Node2D) -> void:
	if body == get_tree().current_scene.get_node_or_null("Player") and body.has_method("exit_water"):
		body.exit_water()
