extends StaticBody2D
var word := ""
var question := 0
var boss: Node2D
var label: Label
var flash := 0.0
var enabled := true
const SIZE := Vector2(108, 26)

func _ready() -> void:
	add_to_group("boss_word_targets")
	collision_layer = 8
	collision_mask = 0
	var hit := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = SIZE
	hit.shape = shape
	add_child(hit)
	label = Label.new()
	label.position = -SIZE * 0.5
	label.size = SIZE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = word
	add_child(label)
	queue_redraw()

func hit_by_weapon() -> bool:
	if not enabled or not is_instance_valid(boss) or boss.dying or boss.teleporting:
		return false
	if boss.questions.locked or question != boss.questions.current:
		return false
	if boss.questions.submit(word, question):
		enabled = false
	else:
		flash = 0.6
		label.text = "Wrong"
	queue_redraw()
	return true

func _process(delta: float) -> void:
	if flash > 0:
		flash = maxf(0, flash - delta)
		if flash == 0:
			label.text = word
		queue_redraw()

func _draw() -> void:
	var rect := Rect2(-SIZE * 0.5, SIZE)
	draw_style_box(_panel(), rect)

func _panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("581c36") if flash > 0 else Color("091e35")
	style.border_color = Color("ff637c") if flash > 0 else Color("59c9ed")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	return style
