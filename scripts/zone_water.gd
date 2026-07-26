extends Area2D

@export var player: CharacterBody2D
@export var water_level_y: float = 700.0 # Set the exact height of your global water surface

func _ready() -> void:
	# Your clean signal connections work perfectly here
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func _process(_delta: float) -> void:
	if player:
		# This keeps the water pinned horizontally to the player,
		# mimicking a CanvasLayer but staying inside the physical world!
		global_position.x = player.global_position.x - 600.0
		global_position.y = water_level_y

func _on_body_entered(body: Node2D) -> void:
	if body.has_method("set_in_water"):
		body.set_in_water(true)

func _on_body_exited(body: Node2D) -> void:
	if body.has_method("set_in_water"):
		body.set_in_water(false)
