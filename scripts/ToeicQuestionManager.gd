extends Node
signal changed
signal correct_answer
signal finished
const QUESTIONS := [
	{"prompt": "The manager will ___ the report tomorrow.", "options": ["review", "reviews", "reviewed", "reviewing"], "answer": "review"},
	{"prompt": "Please submit the form ___ Friday.", "options": ["at", "by", "onward", "during"], "answer": "by"},
	{"prompt": "The new printer is more ___ than the old one.", "options": ["efficiency", "efficiently", "efficient", "efficiencies"], "answer": "efficient"},
	{"prompt": "Ms. Chen has ___ here since 2020.", "options": ["work", "works", "working", "worked"], "answer": "worked"},
	{"prompt": "Contact us if you need ___ information.", "options": ["addition", "additional", "additionally", "additions"], "answer": "additional"},
]
var current := 0
var locked := false

func submit(word: String, question: int) -> bool:
	if locked or current >= QUESTIONS.size() or question != current:
		return false
	if word != QUESTIONS[current].answer:
		return false
	locked = true
	current += 1
	correct_answer.emit()
	changed.emit()
	if current == QUESTIONS.size():
		finished.emit()
	else:
		get_tree().create_timer(0.45).timeout.connect(func(): locked = false)
	return true
