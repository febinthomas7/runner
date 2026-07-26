extends ColorRect

func _ready() -> void:
	# 1. Get the shape from the parent CollisionShape2D
	var parent_shape = get_parent().shape as RectangleShape2D
	
	if parent_shape:
		# 2. Set the ColorRect size to match the exact size of the rectangle shape
		size = parent_shape.size
		
		# 3. Center the ColorRect perfectly over the CollisionShape2D 
		# (CollisionShapes center on (0,0); ColorRects scale from the top-left)
		position = -size / 2.0
