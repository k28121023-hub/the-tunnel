extends Node2D

signal exit_reached
var entered := false

func _ready() -> void:
	$Exit.body_entered.connect(_on_exit_entered)

func _on_exit_entered(body: Node2D) -> void:
	var level := get_tree().current_scene
	if entered or body != level.get_node_or_null("Player"):
		return
	if body.health <= 0 or not $Exit.overlaps_body(body):
		return
	if level.get_node("WordTasks").completed < 20:
		return
	entered = true
	exit_reached.emit()
