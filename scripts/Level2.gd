extends Node2D
const QUESTIONS := preload("res://scripts/ToeicQuestionManager.gd")
const BOSS := preload("res://scripts/ReaperBoss.gd")
const CHESTS := preload("res://scripts/ChestManager.gd")
const HALL := preload("res://assets/crystal_hall.png")
var level_complete := false
var questions: Node
var boss: CharacterBody2D
var chests: Node2D
var cards: Array[PanelContainer] = []
var boss_label: Label
var health_label: Label
var status_label: Label
var clear_label: Label
var weapon_lost_notice := false
var hud: Control
var camera: Camera2D
var victory_overlay: ColorRect
var victory_options: VBoxContainer
var continue_button: Button
var leaving := false
@onready var player: CharacterBody2D = $Player

func _ready() -> void:
	player.spawn_point = Vector2(100,440)
	player.position = player.spawn_point
	player.retain_weapons_on_hit = false
	if get_tree().has_meta("level_two_player"):
		var saved: Dictionary = get_tree().get_meta("level_two_player")
		get_tree().remove_meta("level_two_player")
		# This final challenge starts unarmed; carry health through the existing portal.
		player.health = saved.health
		player._update_items()
	player.respawned.connect(func(): get_tree().call_deferred("reload_current_scene"))
	var background := Sprite2D.new()
	background.texture = HALL
	background.centered = false
	background.scale = Vector2.ONE * 0.6
	background.z_index = -10
	add_child(background)
	for rect in [Rect2(0,765,1672,42),Rect2(0,0,47,941),Rect2(1624,0,48,941),Rect2(0,0,1672,64)]:
		_add_solid(rect.position*0.6,rect.size*0.6,false)
	for rect in [Rect2(48,502,216,24),Rect2(256,359,275,43),Rect2(521,520,193,40),Rect2(1194,520,183,40),Rect2(1367,359,214,43)]:
		_add_solid(rect.position*0.6,rect.size*0.6,true)
	# Intermediate steps keep every chest/Boss platform within the existing jump arc.
	for pos in [Vector2(160,385),Vector2(465,385),Vector2(780,385)]:
		_add_solid(pos,Vector2(88,14),true)
		var art := Sprite2D.new()
		art.texture = HALL
		art.centered = false
		art.region_enabled = true
		art.region_rect = Rect2(521,520,193,24)
		art.scale = Vector2(88.0/193,14.0/24)
		art.position = pos
		add_child(art)
	questions = Node.new()
	questions.name = "ToeicQuestionManager"
	questions.set_script(QUESTIONS)
	add_child(questions)
	boss = CharacterBody2D.new()
	boss.name = "ReaperBoss"
	boss.set_script(BOSS)
	boss.player = player
	boss.questions = questions
	boss.points.assign([Vector2(300,426),Vector2(240,182.4),Vector2(370,279),Vector2(610,426),Vector2(765,279),Vector2(840,182.4)])
	boss.position = Vector2(610,426)
	add_child(boss)
	chests = Node2D.new()
	chests.name = "ChestManager"
	chests.set_script(CHESTS)
	chests.player = player
	chests.points.assign([Vector2(105,445),Vector2(235,201.4),Vector2(505,371),Vector2(865,201.4),Vector2(925,445)])
	add_child(chests)
	for i in range(chests.points.size()):
		var marker := Marker2D.new()
		marker.name = "ChestSpawnPoint%d" % i
		marker.position = chests.points[i]
		add_child(marker)
	for i in range(boss.points.size()):
		var marker := Marker2D.new()
		marker.name = "TeleportPoint%d" % i
		marker.position = boss.points[i]
		add_child(marker)
	camera = Camera2D.new()
	add_child(camera)
	_build_hud()
	questions.changed.connect(_update_hud)
	questions.finished.connect(func():
		level_complete = true
		chests.stop())
	boss.defeated.connect(_show_victory)
	player.health_changed.connect(func(_hp: int,_max_hp: int): _update_hud())
	player.items_changed.connect(_on_player_items_changed)
	player.weapons_lost.connect(_on_weapons_lost)
	get_viewport().size_changed.connect(_layout)
	_layout()
	_update_hud()

func _add_solid(pos: Vector2, size: Vector2, one_way: bool) -> void:
	var body := StaticBody2D.new()
	body.position = pos + size*0.5
	var shape := RectangleShape2D.new()
	shape.size = size
	var hit := CollisionShape2D.new()
	hit.shape = shape
	hit.one_way_collision = one_way
	body.add_child(hit)
	add_child(body)

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(hud)
	for i in range(1):
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(panel)
		cards.append(panel)
		var margin := MarginContainer.new()
		for side in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+side,6)
		panel.add_child(margin)
		var label := Label.new()
		label.name = "Question"
		label.autowrap_mode = TextServer.AUTOWRAP_OFF
		label.add_theme_font_size_override("font_size",16)
		margin.add_child(label)
	boss_label = Label.new()
	boss_label.add_theme_font_size_override("font_size",18)
	hud.add_child(boss_label)
	status_label = Label.new()
	status_label.name = "WeaponStatus"
	status_label.add_theme_font_size_override("font_size",17)
	status_label.add_theme_color_override("font_outline_color", Color("071327"))
	status_label.add_theme_constant_override("outline_size", 6)
	hud.add_child(status_label)
	health_label = Label.new()
	health_label.add_theme_font_size_override("font_size",18)
	health_label.modulate = Color("ff8c9e")
	hud.add_child(health_label)
	victory_overlay = ColorRect.new()
	victory_overlay.color = Color(0.02, 0.04, 0.09, 0.85)
	victory_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	victory_overlay.hide()
	hud.add_child(victory_overlay)
	clear_label = Label.new()
	clear_label.text = "You Win!"
	clear_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	clear_label.add_theme_font_size_override("font_size",42)
	clear_label.add_theme_color_override("font_outline_color",Color("071327"))
	clear_label.add_theme_constant_override("outline_size",12)
	clear_label.modulate = Color("8be7ff")
	clear_label.hide()
	victory_overlay.add_child(clear_label)
	victory_options = VBoxContainer.new()
	victory_options.add_theme_constant_override("separation", 16)
	victory_options.hide()
	victory_overlay.add_child(victory_options)
	continue_button = Button.new()
	continue_button.text = "繼續遊戲"
	continue_button.custom_minimum_size = Vector2(240, 52)
	continue_button.pressed.connect(_continue_game)
	victory_options.add_child(continue_button)
	var exit_button := Button.new()
	exit_button.text = "離開"
	exit_button.custom_minimum_size = Vector2(240, 52)
	exit_button.pressed.connect(_exit_game)
	victory_options.add_child(exit_button)

func _exit_game() -> void:
	if OS.has_feature("web"):
		clear_label.text = "感謝遊玩！\n你可以關閉此分頁"
		victory_options.get_child(1).hide()
		continue_button.grab_focus()
	else:
		get_tree().quit()

func _show_victory() -> void:
	if victory_overlay.visible or player.health <= 0: return
	level_complete = true
	chests.stop()
	victory_overlay.show()
	clear_label.show()
	get_tree().paused = true
	await get_tree().create_timer(1.5, true).timeout
	victory_options.show()
	continue_button.grab_focus()

func _continue_game() -> void:
	if leaving: return
	leaving = true
	var tree := get_tree()
	var error := tree.change_scene_to_file("res://scenes/dungeon_level_01.tscn")
	if error == OK:
		tree.paused = false
	else:
		leaving = false
		push_error("Could not continue game: %s" % error)

func _layout() -> void:
	var size := get_viewport_rect().size
	var top := 90.0
	var zoom_value := minf(size.x/1004.0,maxf(150,size.y-top)/500.0)
	camera.zoom = Vector2.ONE * zoom_value
	camera.position = Vector2(502,250.0-top/(2*zoom_value))
	cards[0].position = Vector2(8,4)
	cards[0].size = Vector2(size.x-16,58)
	boss_label.position = Vector2(12,64)
	health_label.position = Vector2(size.x-150,64)
	if is_instance_valid(status_label):
		if size.x >= 760.0:
			status_label.position = Vector2(330, 64)
			status_label.size = Vector2(size.x - 490, 28)
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			status_label.position = Vector2(12, 90)
			status_label.size = Vector2(size.x - 24, 24)
			status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	victory_overlay.size = size
	clear_label.position = Vector2(0,size.y*0.3)
	clear_label.size.x = size.x
	victory_options.position = Vector2((size.x-240)*0.5,size.y*0.52)
	victory_options.size.x = 240
	# Keep the existing inventory icons clear of the current-question strip.
	player.item_icons.position = Vector2(30, 142 if size.x < 760.0 else 120)

func _update_hud() -> void:
	var panel := cards[0]
	panel.visible = questions.current < 5
	if questions.current < 5:
		var data: Dictionary = questions.QUESTIONS[questions.current]
		var label: Label = panel.get_child(0).get_child(0)
		label.text = "Q%d / 5   %s\nA. %s     B. %s     C. %s     D. %s" % [questions.current+1,data.prompt,data.options[0],data.options[1],data.options[2],data.options[3]]
		var style := StyleBoxFlat.new()
		style.bg_color = Color("133447")
		style.border_color = Color("74e4ff")
		style.set_border_width_all(2)
		style.set_corner_radius_all(6)
		panel.add_theme_stylebox_override("panel",style)
	var boss_text := "SOUL REAPER   HP %s  %d / 5" % ["■".repeat(boss.health) + "□".repeat(5-boss.health),boss.health]
	if boss_label.text != boss_text:
		boss_label.text = boss_text
	var health_text := "HP %d / %d" % [player.health,player.max_health]
	if health_label.text != health_text:
		health_label.text = health_text
	if is_instance_valid(status_label):
		var status_text := ""
		var status_color := Color("ffd166")
		if not player.active_weapon.is_empty():
			var weapon_name := "長劍" if player.active_weapon == "sword" else "光砲"
			var switch_hint := " / Q 切換" if player.inventory.has("sword") and player.inventory.has("cannon") else ""
			status_text = "武器：%s（Space 攻擊%s）" % [weapon_name, switch_hint]
			status_color = Color("9be7ff")
		elif weapon_lost_notice:
			status_text = "武器已遺失！請從寶箱重新拿取"
			status_color = Color("ff8c69")
		else:
			status_text = "目前無武器，請打開寶箱拿取"
			status_color = Color("ffd166")
		if status_label.text != status_text:
			status_label.text = status_text
		status_label.modulate = status_color

func _on_player_items_changed() -> void:
	if not player.active_weapon.is_empty():
		weapon_lost_notice = false
	_update_hud()

func _on_weapons_lost() -> void:
	weapon_lost_notice = true
	_update_hud()
