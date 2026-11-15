extends Area2D
var word := ""
var task_number := 1
var consumed := false
var ready_to_answer := false
var landing := Vector2.ZERO
var age := 0.0
var launch := Vector2.ZERO
var arc_height := 100.0

func _ready() -> void:
	add_to_group("task_words")
	$Label.text = word
	# Size the visual and contact area to the actual word, including long words.
	var font: Font = $Label.get_theme_font("font")
	var width := maxf(68.0, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 16.0)
	$Label.offset_left = -width * 0.5
	$Label.offset_right = width * 0.5
	$Background.polygon = PackedVector2Array([Vector2(-width * 0.5, -12), Vector2(width * 0.5, -12), Vector2(width * 0.5, 12), Vector2(-width * 0.5, 12)])
	var hit := RectangleShape2D.new()
	hit.size = Vector2(width, 24)
	$CollisionShape2D.shape = hit
	body_entered.connect(_on_body_entered)
	launch = global_position
	arc_height = clampf(absf(landing.x - launch.x) * 0.25, 85.0, 160.0)
	var tween := create_tween()
	tween.tween_method(_fly, 0.0, 1.0, 1.15).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_callback(func(): ready_to_answer = true)

func _fly(progress: float) -> void:
	global_position = launch.lerp(landing, progress) + Vector2(0, -sin(PI * progress) * arc_height)
	rotation = sin(PI * progress) * 0.12 * signf(landing.x - launch.x)
	scale = Vector2.ONE * lerpf(0.65, 1.0, progress)

func _physics_process(delta: float) -> void:
	if not ready_to_answer or consumed:
		return
	age += delta
	global_position.y = landing.y + sin(age * 2.3) * 3.0
	for body in get_overlapping_bodies():
		_on_body_entered(body)

func _on_body_entered(body: Node2D) -> void:
	if consumed or not ready_to_answer or body != get_tree().current_scene.get_node("Player"):
		return
	if get_tree().current_scene.get_node("WordTasks").submit(word, task_number):
		consume()

func consume() -> void:
	consumed = true
	hide()
	set_deferred("monitoring", false)
	queue_free()
