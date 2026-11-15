extends CanvasLayer
## Real multi-touch buttons allow holding movement while jumping or attacking.
var enabled := false
var pad := Node2D.new()
var buttons: Array[TouchScreenButton] = []
var toggle := Button.new()
const ACTIONS := ["move_left", "move_right", "crouch", "jump", "attack"]
const LABELS := ["◀", "▶", "▼", "▲", "攻擊"]

func _ready() -> void:
	layer = 5
	add_child(pad)
	for i in range(ACTIONS.size()):
		var button := TouchScreenButton.new()
		button.action = ACTIONS[i]
		var shape := CircleShape2D.new()
		shape.radius = 42
		button.shape = shape
		button.passby_press = true
		var disk := Polygon2D.new()
		var points := PackedVector2Array()
		for j in range(48): points.append(Vector2.from_angle(j*TAU/48)*42)
		disk.polygon = points
		disk.color = Color(0.08,0.13,0.21,0.78)
		button.add_child(disk)
		var rim := Line2D.new()
		for j in range(49): rim.add_point(Vector2.from_angle(j*TAU/48)*42)
		rim.width = 2
		rim.default_color = Color(1,0.8,0.42,0.9)
		button.add_child(rim)
		var label := Label.new()
		label.text = LABELS[i]
		label.position = Vector2(-42,-20)
		label.size = Vector2(84,40)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size",26)
		label.add_theme_color_override("font_color",Color.WHITE)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.add_child(label)
		button.pressed.connect(func(): disk.color = Color(0.6,0.32,0.08,0.9))
		button.released.connect(func(): disk.color = Color(0.08,0.13,0.21,0.78))
		pad.add_child(button)
		buttons.append(button)
	toggle.text = "觸控"
	toggle.custom_minimum_size = Vector2(90,44)
	toggle.pressed.connect(func(): _set_enabled(not enabled))
	add_child(toggle)
	get_viewport().size_changed.connect(_layout)
	enabled = DisplayServer.is_touchscreen_available() or OS.has_feature("mobile")
	if OS.has_feature("web"):
		enabled = enabled or bool(JavaScriptBridge.eval("navigator.maxTouchPoints > 0 || matchMedia('(pointer: coarse)').matches"))
	_set_enabled(enabled)

func _set_enabled(value: bool) -> void:
	_release()
	enabled = value
	pad.visible = value
	toggle.text = "隱藏按鈕" if value else "觸控"
	var help := get_parent().get_parent().get_node_or_null("HUD/Controls") as Label
	if help != null:
		help.text = "▲ 輕點跳躍／按住跳更高 · ▼ 蹲下" if value else "A/D: Move | S: Crouch | W: Jump | Space: Attack | Q: Switch | R: Restart"
	_layout()
	if not value:
		var level := get_parent().get_parent()
		var camera := get_viewport().get_camera_2d()
		if camera != null and level.has_method("_layout"):
			level._layout()
		elif camera != null:
			camera.zoom = Vector2.ONE*1.5

func _layout() -> void:
	var size := get_viewport().get_visible_rect().size
	var factor := clampf(size.y/800.0,1.0,1.65)
	var gap := 66.0*factor
	var center := Vector2(122.0*factor,size.y-120.0*factor)
	# A low, familiar D-pad: up jumps, down crouches.
	var positions := [center+Vector2(-gap,0),center+Vector2(gap,0),center+Vector2(0,gap),center+Vector2(0,-gap),Vector2(size.x-66.0*factor,size.y-66.0*factor)]
	for i in range(buttons.size()):
		buttons[i].position = positions[i]
		buttons[i].scale = Vector2.ONE*factor
	toggle.position = Vector2(size.x-140,12)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed and not enabled:
		_set_enabled(true)

func _release() -> void:
	for action in ACTIONS:
		if InputMap.has_action(action): Input.action_release(action)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _release()

func _exit_tree() -> void:
	_release()



func _process(_delta: float) -> void:
	_position_mobile_hud()
	if not enabled: return
	var camera := get_viewport().get_camera_2d()
	if camera == null: return
	var size := get_viewport().get_visible_rect().size
	var level := get_parent().get_parent()
	var boss_room := level.has_method("_continue_game")
	# Fit the complete normal play area. Portrait height must never increase
	# zoom, otherwise the sides disappear on narrow phones.
	var top := 90.0
	var bottom := 150.0
	var world_size := Vector2(1004,500) if boss_room else Vector2(768,500)
	var zoom_value := minf(size.x/world_size.x,maxf(150,size.y-top-bottom)/world_size.y)
	camera.zoom = Vector2.ONE*zoom_value
	if boss_room:
		camera.position = Vector2(502,250+(bottom-top)/(2*zoom_value))


func _position_mobile_hud() -> void:
	var level := get_parent().get_parent()
	var shift := clampf(get_viewport().get_visible_rect().size.y*0.075,48.0,72.0) if enabled else 0.0
	var hud := level.get_node_or_null("HUD")
	if hud != null:
		for entry in [["Controls",16.0],["Status",44.0],["Health",74.0]]:
			var label := hud.get_node_or_null(entry[0]) as Control
			if label != null: label.position.y = entry[1]+shift
	var tasks := level.get_node_or_null("TaskUI") as CanvasLayer
	if tasks != null: tasks.offset.y = shift
	if level.has_method("_continue_game") and is_instance_valid(level.health_label):
		level.health_label.position.y = 64+shift
		level.boss_label.position.y = 64+shift
		if not level.cards.is_empty(): level.cards[0].position.y = 4+shift
		get_parent().item_icons.position.y = 120+shift
	else:
		get_parent().item_icons.position.y = 126+shift
