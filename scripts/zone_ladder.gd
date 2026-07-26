extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_near_ladder"):
		body.set_near_ladder(true)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_near_ladder"):
		body.set_near_ladder(false)
