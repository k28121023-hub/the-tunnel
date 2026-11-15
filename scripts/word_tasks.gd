extends Node
const BOX := preload("res://scenes/TaskBox.tscn")
const CHEST := preload("res://scenes/WordChest.tscn")
const TASKS := {
	1: {"task": 1, "meaning": "收據", "answer": "receipt"},
	2: {"task": 2, "meaning": "發票", "answer": "invoice"},
	3: {"task": 3, "meaning": "行程表", "answer": "schedule"},
	4: {"task": 4, "meaning": "顧客", "answer": "customer"},
	5: {"task": 5, "meaning": "訂單", "answer": "order"},
	6: {"task": 6, "meaning": "付款", "answer": "payment"},
	7: {"task": 7, "meaning": "折扣", "answer": "discount"},
	8: {"task": 8, "meaning": "預算", "answer": "budget"},
	9: {"task": 9, "meaning": "會議", "answer": "meeting"},
	10: {"task": 10, "meaning": "截止日期", "answer": "deadline"},
	11: {"task": 11, "meaning": "合約", "answer": "contract"},
	12: {"task": 12, "meaning": "供應商", "answer": "supplier"},
	13: {"task": 13, "meaning": "出貨", "answer": "shipment"},
	14: {"task": 14, "meaning": "倉庫", "answer": "warehouse"},
	15: {"task": 15, "meaning": "庫存", "answer": "inventory"},
	16: {"task": 16, "meaning": "利潤", "answer": "profit"},
	17: {"task": 17, "meaning": "支出", "answer": "expense"},
	18: {"task": 18, "meaning": "退款", "answer": "refund"},
	19: {"task": 19, "meaning": "保固", "answer": "warranty"},
	20: {"task": 20, "meaning": "預約", "answer": "appointment"}
}
var active_task := 0
var completed := 0
var used_words: Dictionary = {}
var opened_chests: Dictionary = {}
var box_loot: Dictionary = {}
var opened_boxes: Dictionary = {}
var collected_boxes: Dictionary = {}
var next_weapon_reward := "sword"
## Including the English chest at x=1335.5 and section seams, boxes are
## at least 475 world pixels apart. Background repairs remove unused crates.
const BOX_POSITIONS := [Vector2(200, 380), Vector2(675, 345)]

func random_weapon() -> String:
	return ["sword", "cannon"].pick_random()

func reward_for_player() -> String:
	var player = get_parent().get_node("Player")
	if player.inventory.has("armor"):
		return "potion"
	if player.inventory.has("sword") or player.inventory.has("cannon"):
		return ["potion", "armor"].pick_random()
	# Advance only for an actual unarmed box opening, never section generation.
	var reward := next_weapon_reward
	next_weapon_reward = "cannon" if reward == "sword" else "sword"
	return reward

func resolve_box(number: int, slot: int) -> String:
	var contents := loot_for(number)
	# Guarantee the first unopened box in the next task's section gives its task.
	if number == completed + 1 and active_task <= completed and TASKS.has(number):
		contents[slot] = "task"
	elif contents[slot] == "task" and number <= active_task:
		contents[slot] = reward_for_player()
	# Future task boxes stay reserved until the previous quiz is complete.
	# Never permanently replace the only source of an upcoming task with loot.
	elif contents[slot] != "task":
		# Resolve all item rewards at contact, including unarmed weapon rewards.
		contents[slot] = reward_for_player()
	return contents[slot]

func loot_for(number: int) -> Array:
	if not box_loot.has(number):
		var contents: Array = []
		for slot in range(BOX_POSITIONS.size()):
			contents.append("task" if slot == 0 and TASKS.has(number) else random_weapon())
		contents.shuffle()
		box_loot[number] = contents
	return box_loot[number]

func configure_section(section: Node2D, index: int, positions: Array = BOX_POSITIONS, chest_position := Vector2(1335.5, 269.8), repair_background := true) -> void:
	var number := index + 1
	if repair_background:
		_cover_background_boxes(section)
	var contents := loot_for(number)
	for slot in range(contents.size()):
		var box := BOX.instantiate() as Area2D
		box.name = "TaskBox" if slot == 0 else "LootBox%d" % slot
		box.slot = slot
		box.task_number = number
		box.box_id = "%d:%d" % [number, slot]
		box.content = contents[slot]
		box.position = positions[slot]
		section.add_child(box)
		if opened_boxes.has(box.box_id):
			box.opened = true
			box.get_node("Lid").rotation = -0.65
			box.get_node("Lid").position.y = -17
			if box.content != "task" and not collected_boxes.has(box.box_id):
				box.call_deferred("_spawn_pickup")
	var chest := CHEST.instantiate() as Node2D
	chest.name = "WordChest"
	chest.task_number = number
	chest.position = chest_position
	section.add_child(chest)
	if opened_chests.has(number):
		chest.opened = true
		chest.get_node("ChestLid").rotation = -0.85
		if number == active_task and number > completed:
			chest.call_deferred("_spawn_words")

func _cover_background_boxes(section: Node2D) -> void:
	# Reuse clean regions of the existing background, as the original box repair
	# already does. Only the old baked-in box art is covered, never the floors.
	var repairs := [
		# Sample the same blue arch directly above this crate, not the dark wall
		# to its right (which left a black rectangle behind the opened lid).
		[Rect2(182, 358, 35, 35), Vector2(182, 357)],
		[Rect2(227, 367, 29, 26), Vector2(269, 367)],
		[Rect2(1077, 344, 47, 49), Vector2(1020, 344)],
		[Rect2(1698, 381, 47, 35), Vector2(1770, 381)],
	]
	var background := section.get_node("Background") as Sprite2D
	for index in range(repairs.size()):
		var destination: Rect2 = repairs[index][0]
		var sample: Vector2 = repairs[index][1]
		var repair := Sprite2D.new()
		repair.name = "InteractiveBoxRepair%d" % index
		repair.texture = background.texture
		repair.centered = false
		repair.region_enabled = true
		repair.region_rect = Rect2(sample / background.scale, destination.size / background.scale)
		repair.region_filter_clip_enabled = true
		repair.position = destination.position
		repair.scale = background.scale
		if index == 0:
			# Continue the immediately adjacent wall/arch column without importing
			# an unrelated rectangular patch from elsewhere in the painting.
			repair.region_rect.size.y = 1.0
			repair.scale.y = destination.size.y
		repair.z_index = 1
		section.add_child(repair)

func start_task(number: int, box: Node2D) -> bool:
	if number != completed + 1 or active_task > completed or not TASKS.has(number):
		return false
	active_task = number
	used_words.clear()
	get_parent().get_node("TaskUI").reveal_task(box, TASKS[number])
	return true

func can_open_treasure(number: int) -> bool:
	return number == active_task and number > completed and get_parent().get_node("TaskUI").arrived

func options_for(number: int) -> Array[String]:
	var result: Array[String] = [TASKS[number].answer]
	for offset in range(1, 4):
		result.append(TASKS[(number - 1 + offset) % TASKS.size() + 1].answer)
	result.shuffle()
	return result

func submit(word: String, number: int) -> bool:
	if number != active_task or number <= completed or not opened_chests.has(number) or used_words.has(word):
		return false
	used_words[word] = true
	var ui = get_parent().get_node("TaskUI")
	if word == TASKS[number].answer:
		completed = number
		ui.show_result("Correct", true)
		for token in get_tree().get_nodes_in_group("task_words"):
			token.consume()
		get_parent().record_correct_answer(StringName("word_task_%d" % number))
	else:
		ui.show_result("Wrong", false)
		get_parent().get_node("Player").take_damage(25, true)
	return true
