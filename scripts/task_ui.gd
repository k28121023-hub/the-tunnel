extends CanvasLayer
const TASK_DATA := {"task": 1, "answer": "receipt", "meaning": "收據"}
var started := false
var arrived := false
var source := Vector2.ZERO
var flight_tween: Tween

func _ready() -> void:
	$TaskPanel/TaskTitle.text = "TASK %d" % TASK_DATA.task
	$TaskPanel/InstructionLabel.text = "找出對應的英文單字"
	$TaskPanel/WordHint.text = "「%s」" % TASK_DATA.meaning
	get_viewport().size_changed.connect(_on_resize)

func _dock_position() -> Vector2:
	return $TaskPanel.position + Vector2(22, 21)

func reveal_task(box: Node2D, data: Dictionary = TASK_DATA) -> void:
	if flight_tween:
		flight_tween.kill()
	arrived = false
	$TaskPanel.hide()
	$TaskPanel/TaskTitle.text = "TASK %d" % data.task
	$TaskPanel/WordHint.text = "「%s」" % data.meaning
	$TaskPanel/Result.text = ""
	started = true
	# Convert world position to viewport coordinates exactly once at takeoff.
	source = box.get_global_transform_with_canvas().origin
	$Scroll.position = source
	$Scroll.scale = Vector2.ONE * 0.65
	$Scroll.visible = true
	flight_tween = create_tween()
	flight_tween.tween_method(_pop, 0.0, 1.0, 0.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	flight_tween.tween_method(_fly, 0.0, 1.0, 0.7).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	flight_tween.tween_callback(_arrive)

func _pop(progress: float) -> void:
	$Scroll.position = source + Vector2(0, -48.0 * progress)
	$Scroll.rotation = -0.2 * progress
	$Scroll.scale = Vector2.ONE * lerpf(0.65, 0.6, progress)

func _fly(progress: float) -> void:
	$Scroll.position = (source + Vector2(0, -48)).lerp(_dock_position(), progress) + Vector2(0, -50 * sin(PI * progress))
	$Scroll.rotation = lerpf(-0.2, 0.0, progress) + sin(PI * progress) * 0.3

func _arrive() -> void:
	arrived = true
	$Scroll.position = _dock_position()
	$Scroll.rotation = 0.0
	$Scroll.scale = Vector2.ONE * 0.6
	$TaskPanel.visible = true

func _on_resize() -> void:
	if arrived:
		# Anchors are updated during the UI layout pass.
		call_deferred("_place_scroll")

func _place_scroll() -> void:
	$Scroll.position = _dock_position()

func show_result(message: String, correct: bool) -> void:
	$TaskPanel/Result.text = message
	$TaskPanel/Result.modulate = Color(0.4, 1, 0.6) if correct else Color(1, 0.4, 0.35)
