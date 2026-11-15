extends Area2D
@export var damage := 25

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("take_damage"):
		body.take_damage(damage)

func _physics_process(_delta: float) -> void:
	# Remaining on spikes hurts again only after the player's invulnerability ends.
	for body in get_overlapping_bodies():
		_on_body_entered(body)
