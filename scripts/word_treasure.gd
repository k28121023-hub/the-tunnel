extends Node2D
const TOKEN := preload("res://scenes/WordToken.tscn")
const LOS := preload("res://scripts/interact_los.gd")
const UI_FONT := preload("res://assets/fonts/ChineseUI.tres")
@export var task_number := 1
var opened := false
const WORD_HALF_SIZE := Vector2(60, 18)
const WORD_DISTANCE := 112.0
var solids: Array[Dictionary] = []
var hazards: Array[Rect2] = []
var reachable: Array[Vector2] = []
var words_spawned := false
var locked_hint: Label

func _ready() -> void:
	$Area2D.body_entered.connect(_on_body_entered)
	locked_hint = Label.new()
	locked_hint.visible = false
	locked_hint.z_index = 20
	locked_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	locked_hint.add_theme_font_override("font", UI_FONT)
	locked_hint.add_theme_font_size_override("font_size", 14)
	locked_hint.add_theme_color_override("font_color", Color(1, 0.9, 0.65))
	locked_hint.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.1))
	locked_hint.add_theme_constant_override("outline_size", 6)
	locked_hint.position = Vector2(-90, -52)
	locked_hint.size = Vector2(180, 24)
	add_child(locked_hint)

func _physics_process(_delta: float) -> void:
	if not opened:
		var touching := false
		for body in $Area2D.get_overlapping_bodies():
			if body == get_tree().current_scene.get_node_or_null("Player"):
				touching = true
			_on_body_entered(body)
		if not touching:
			locked_hint.visible = false

func _on_body_entered(body: Node2D) -> void:
	var level := get_tree().current_scene
	if opened or body != level.get_node("Player") or body.health <= 0 or not $Area2D.overlaps_body(body):
		return
	if LOS.blocked(get_world_2d(), body.global_position, global_position, [body.get_rid()]):
		return
	var manager = level.get_node("WordTasks")
	# Tasks originate only from ordinary boxes; this chest handles their quiz.
	if not manager.can_open_treasure(task_number):
		_show_locked_hint(manager)
		return
	locked_hint.visible = false
	opened = true
	level.get_node("WordTasks").opened_chests[task_number] = true
	var tween := create_tween()
	var rest := position
	for shift in [2.0, -2.0, 1.5, -1.5, 0.0]:
		tween.tween_property(self, "position", rest + Vector2(shift, 0), 0.04)
	# Only the original upper image region rotates about its bottom rear corner.
	tween.tween_property($ChestLid, "rotation", -0.85, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.12)
	tween.tween_callback(_spawn_words)

func _spawn_words() -> void:
	if words_spawned:
		return
	var manager = get_tree().current_scene.get_node("WordTasks")
	var options: Array[String] = manager.options_for(task_number)
	options = options.filter(func(word: String): return not manager.used_words.has(word))
	if options.is_empty():
		return
	var destinations := random_landings(options.size())
	if destinations.size() != options.size():
		# High zoom, a short viewport, or a mid-pan camera can reject every
		# strict layout. Fall back to a looser arrangement before retrying.
		destinations = _fallback_landings(options.size())
	if destinations.size() != options.size():
		# A very small or moving viewport may have too little safe space. Retry
		# in the current view instead of placing words off-screen or in a wall.
		get_tree().create_timer(0.35).timeout.connect(_spawn_words, CONNECT_ONE_SHOT)
		return
	words_spawned = true
	for i in range(options.size()):
		var token := TOKEN.instantiate() as Area2D
		token.word = options[i]
		token.task_number = task_number
		token.position = position + Vector2(0, -20)
		token.landing = destinations[i]
		get_parent().add_child(token)

func _shape_rect(shape: CollisionShape2D) -> Rect2:
	var size: Vector2 = shape.shape.size
	var corner := shape.to_global(-size * 0.5)
	return Rect2(corner, shape.to_global(size * 0.5) - corner).abs()

func _read_terrain() -> void:
	solids.clear()
	hazards.clear()
	for body in get_parent().get_node("Geometry").get_children():
		for child in body.get_children():
			if child is CollisionShape2D and child.shape is RectangleShape2D and not child.disabled:
				solids.append({"rect": _shape_rect(child), "one_way": child.one_way_collision})
	for area in get_parent().get_children():
		if area is Area2D and (area.has_method("enter_water") or area.name == "WaterArea" or "Spikes" in str(area.name)):
			for child in area.get_children():
				if child is CollisionShape2D and child.shape is RectangleShape2D:
					hazards.append(_shape_rect(child).grow(8.0))

func _clear_rect(rect: Rect2) -> bool:
	for solid in solids:
		if rect.intersects(solid.rect):
			return false
	for hazard in hazards:
		if rect.intersects(hazard):
			return false
	return true

func _jump_clear(start: Vector2, finish: Vector2) -> bool:
	var difference := finish - start
	# Same speed, jump velocity and gravity as Player; leave a small margin.
	if absf(difference.x) > 195.0 or difference.y < -140.0:
		return false
	var discriminant := 650.0 * 650.0 + 2.0 * 1400.0 * difference.y
	if discriminant <= 0.0:
		return false
	var duration := (650.0 + sqrt(discriminant)) / 1400.0
	if absf(difference.x) / duration > 240.0:
		return false
	var previous := start
	var steps := ceili(duration * 60.0)
	for step in range(1, steps):
		var time := duration * float(step) / steps
		var point := start + Vector2(difference.x * time / duration, -650.0 * time + 700.0 * time * time)
		var body := Rect2(point - Vector2(11, 18), Vector2(22, 36))
		for solid in solids:
			var rect: Rect2 = solid.rect
			if not body.intersects(rect):
				continue
			if not solid.one_way or (point.y > previous.y and previous.y + 18 <= rect.position.y + 0.5):
				return false
		for hazard in hazards:
			if body.intersects(hazard):
				return false
		previous = point
	return true

func _find_reachable() -> void:
	reachable.clear()
	var anchors: Array[Vector2] = []
	for solid in solids:
		var rect: Rect2 = solid.rect
		if rect.size.x < 30 or rect.size.y > 30:
			continue
		var x := rect.position.x + 13.0
		while x <= rect.end.x - 13.0:
			var point := Vector2(x, rect.position.y - 18.5)
			if point.distance_to(global_position) < 460.0 and _clear_rect(Rect2(point - Vector2(11, 18), Vector2(22, 36))):
				anchors.append(point)
			x += 22.0
	if anchors.is_empty():
		return
	anchors.sort_custom(func(a: Vector2, b: Vector2): return a.distance_squared_to(global_position) < b.distance_squared_to(global_position))
	if anchors[0].distance_to(global_position) > 45.0:
		return
	reachable.append(anchors.pop_front())
	var cursor := 0
	while cursor < reachable.size():
		var start := reachable[cursor]
		for index in range(anchors.size() - 1, -1, -1):
			var finish := anchors[index]
			var walking := absf(start.y - finish.y) < 1.0 and absf(start.x - finish.x) <= 24.0
			if walking or _jump_clear(start, finish):
				reachable.append(finish)
				anchors.remove_at(index)
		cursor += 1

func _visible_bounds() -> Rect2:
	var inverse := get_viewport().get_canvas_transform().affine_inverse()
	var viewport_size := get_viewport_rect().size
	# Keep the entire card within the viewport; HUD exclusions are local.
	var start := inverse * Vector2(16, 16)
	var end := inverse * (viewport_size - Vector2(16, 16))
	return Rect2(start, end - start).grow_individual(-WORD_HALF_SIZE.x, -WORD_HALF_SIZE.y, -WORD_HALF_SIZE.x, -WORD_HALF_SIZE.y)

func random_landings(count: int, min_spread := 65.0, min_distance := WORD_DISTANCE) -> Array[Vector2]:
	_read_terrain()
	_find_reachable()
	var bounds := _visible_bounds()
	if reachable.is_empty() or not bounds.has_area():
		return []
	var neighbor_x := min_distance + 20.0
	for layout in range(24):
		var result: Array[Vector2] = []
		for attempt in range(700):
			var anchor: Vector2 = reachable.pick_random()
			var point := anchor + Vector2(randf_range(-9, 9), -randf_range(10, 85))
			if not bounds.has_point(point) or point.distance_to(global_position) > 410.0:
				continue
			if not _clear_hud(point):
				continue
			var player := get_tree().current_scene.get_node("Player") as Node2D
			if Rect2(point - WORD_HALF_SIZE, WORD_HALF_SIZE * 2.0).intersects(Rect2(player.global_position - Vector2(21, 28), Vector2(42, 56))):
				continue
			# The entire word and its bobbing margin must fit in open space.
			if not _clear_rect(Rect2(point - WORD_HALF_SIZE, WORD_HALF_SIZE * 2.0)):
				continue
			# Clear standing/jumping corridor from a reachable platform to the word.
			if not _clear_rect(Rect2(Vector2(point.x - 11, point.y - 18), Vector2(22, anchor.y - point.y + 36))):
				continue
			var separated := true
			for other in result:
				if point.distance_to(other) < min_distance or (absf(point.x - other.x) < neighbor_x and absf(point.y - other.y) < 48.0):
					separated = false
					break
			if separated:
				result.append(point)
			if result.size() == count:
				var min_y := result[0].y
				var max_y := result[0].y
				for chosen in result:
					min_y = minf(min_y, chosen.y)
					max_y = maxf(max_y, chosen.y)
				if count < 2 or max_y - min_y >= min_spread:
					result.shuffle()
					return result
				break
	return []

func _show_locked_hint(manager: Node) -> void:
	# The scroll is already flying in; the chest will open as soon as it arrives.
	if manager.active_task == task_number and task_number > manager.completed:
		locked_hint.visible = false
		return
	if task_number > manager.completed + 1:
		locked_hint.text = "先完成前面的任務"
	else:
		locked_hint.text = "先打開木箱，取得任務"
	locked_hint.visible = true

func _try_add_landing(point: Vector2, slots: Array[Vector2], min_distance := 52.0) -> bool:
	var bounds := _visible_bounds()
	if bounds.has_area() and not bounds.grow(24.0).has_point(point):
		return false
	if not _clear_hud(point) or point.distance_to(global_position) > 480.0:
		return false
	if not _clear_rect(Rect2(point - WORD_HALF_SIZE, WORD_HALF_SIZE * 2.0)):
		return false
	var player := get_tree().current_scene.get_node_or_null("Player") as Node2D
	if player != null and Rect2(point - WORD_HALF_SIZE, WORD_HALF_SIZE * 2.0).intersects(Rect2(player.global_position - Vector2(21, 28), Vector2(42, 56))):
		return false
	for other in slots:
		if point.distance_to(other) < min_distance:
			return false
	slots.append(point)
	return true

func _fallback_landings(count: int) -> Array[Vector2]:
	var relaxed := random_landings(count, 28.0, 76.0)
	if relaxed.size() == count:
		return relaxed
	var slots: Array[Vector2] = []
	var offsets: Array[Vector2] = [
		Vector2(-100, -36), Vector2(100, -36), Vector2(-50, -78), Vector2(50, -78),
		Vector2(0, -56), Vector2(-150, -20), Vector2(150, -20), Vector2(-70, -110),
		Vector2(70, -110), Vector2(0, -100), Vector2(-180, -48), Vector2(180, -48),
	]
	for offset in offsets:
		if _try_add_landing(global_position + offset, slots) and slots.size() == count:
			return slots
	for anchor in reachable:
		for height in [24.0, 48.0, 72.0, 96.0]:
			if _try_add_landing(anchor + Vector2(0, -height), slots, 64.0) and slots.size() == count:
				return slots
	return slots

func _clear_hud(point: Vector2) -> bool:
	var canvas := get_viewport().get_canvas_transform()
	var screen_card := Rect2(canvas * (point - WORD_HALF_SIZE), canvas * (point + WORD_HALF_SIZE) - canvas * (point - WORD_HALF_SIZE))
	if screen_card.intersects(Rect2(0, 0, get_viewport_rect().size.x, 98)) or screen_card.intersects(Rect2(12, 98, 230, 80)):
		return false
	var panel := get_tree().current_scene.get_node_or_null("TaskUI/TaskPanel") as Control
	return panel == null or not panel.visible or not screen_card.intersects(panel.get_global_rect().grow(8.0))
