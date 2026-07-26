extends Node2D
@export var chunk_scenes: Array[PackedScene] = []
@export var player: CharacterBody2D
var chunk_width: float = 1280.0 # 40 tiles * 32 pixels
var spawn_x: float = 0.0
var active_chunks: Array = []

# How many chunks to keep alive ahead of the player
const DESIRED_BUFFER_CHUNKS = 3 
# How many pixels ahead of the player to look before spawning the next chunk
const LOOK_AHEAD_DISTANCE = 2500.0 
# How far behind the player before a chunk is recycled
const CLEANUP_DISTANCE = 2000.0
# How many chunks to keep pooled per scene type, ready for reuse
const POOL_SIZE_PER_TYPE = 4

# Pools: chunk_scenes index -> Array of inactive chunk instances
var _pools: Dictionary = {}

func _ready() -> void:
	if chunk_scenes.is_empty():
		push_error("LevelGenerator: No chunk scenes assigned in the Inspector!")
		return

	# Validate every entry up front so spawn_next_chunk can never silently fail
	for i in range(chunk_scenes.size()):
		if chunk_scenes[i] == null:
			push_error("LevelGenerator: chunk_scenes[%d] is empty in the Inspector!" % i)
			chunk_scenes.remove_at(i) # avoid ever picking a null entry later

	if chunk_scenes.is_empty():
		push_error("LevelGenerator: All chunk scenes were invalid, nothing to spawn.")
		return

	for i in range(chunk_scenes.size()):
		_pools[i] = []

	# 1. Pre-load a long initial track so the player NEVER drops into a void on spawn
	for i in range(DESIRED_BUFFER_CHUNKS):
		# Force the very first chunk to always be the safe base chunk (index 0)
		var index = 0 if i == 0 else randi() % chunk_scenes.size()
		spawn_next_chunk(index)

func _process(_delta: float) -> void:
	if not player or chunk_scenes.is_empty():
		return

	# 2. Aggressively check if the player is approaching the end of the generated track
	while player.global_position.x + LOOK_AHEAD_DISTANCE > spawn_x:
		var random_index = randi() % chunk_scenes.size()
		spawn_next_chunk(random_index)

	# 3. Clean up ALL old chunks that are far behind the camera, not just one
	clean_old_chunks()

func spawn_next_chunk(index: int) -> void:
	var chunk_scene = chunk_scenes[index]
	if not chunk_scene:
		return # index list is pre-validated in _ready, this is just a safety net

	var chunk_instance: Node2D = _get_pooled_chunk(index)

	chunk_instance.global_position = Vector2(spawn_x, 0)
	chunk_instance.visible = true
	chunk_instance.set_physics_process(true)
	chunk_instance.set_process(true)
	if not chunk_instance.is_inside_tree():
		add_child(chunk_instance)

	active_chunks.append({"node": chunk_instance, "pool_index": index})

	# Move the spawn marker forward perfectly by 1280 pixels
	spawn_x += chunk_width

func _get_pooled_chunk(index: int) -> Node2D:
	var pool: Array = _pools[index]
	if not pool.is_empty():
		return pool.pop_back()

	# Nothing free in the pool, instantiate a new one
	return chunk_scenes[index].instantiate() as Node2D

func clean_old_chunks() -> void:
	# Loop, not a single if — recycle every chunk that's fallen behind,
	# not just the oldest one, in case several qualify in the same frame
	while not active_chunks.is_empty():
		var oldest = active_chunks[0]
		var oldest_chunk: Node2D = oldest["node"]

		if oldest_chunk.global_position.x < player.global_position.x - CLEANUP_DISTANCE:
			active_chunks.remove_at(0)
			_return_to_pool(oldest_chunk, oldest["pool_index"])
		else:
			break # remaining chunks are newer, no need to keep checking

func _return_to_pool(chunk: Node2D, pool_index: int) -> void:
	var pool: Array = _pools[pool_index]

	if pool.size() < POOL_SIZE_PER_TYPE:
		# Deactivate instead of freeing so it can be reused
		chunk.visible = false
		chunk.set_physics_process(false)
		chunk.set_process(false)
		pool.append(chunk)
	else:
		# Pool for this chunk type is already full, just free it
		chunk.queue_free()
