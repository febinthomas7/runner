extends TextureRect

# Drag your Player node into this slot in the Inspector
@export var player: CharacterBody2D

# Lower values make the background scroll slower (creates distance depth)
# 0.1 means the background moves at 10% of the player's speed
@export var scroll_speed_scale: float = 0.1

func _process(_delta: float) -> void:
	if player:
		# Calculate how far the background should shift based on player position
		var offset_x = player.global_position.x * scroll_speed_scale
		
		# Shift the visual canvas region of the texture
		# Note: In Godot 4, we adjust the position offset of the tiled region
		position.x = -fmod(offset_x, texture.get_width())
