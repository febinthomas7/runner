extends CharacterBody2D

enum State {IDLE, RUNNING, WALKING, SPRINTING, JUMPING, DOUBLE_JUMPING,LANDING ,CROUCHING, STAIRS,CRAWLING, ROLL, CLIMBING_LADDER, WALL_CLINGING, SWIMMING, OBSTACLE, DIVING }
var current_state: State = State.RUNNING

# --- Physics Constants ---
const WALK_SPEED = 150.0
const RUN_SPEED = 250.0
const SPRINT_SPEED = 400.0
const CROUCH_SPEED = 100.0
const SWIM_SPEED = 120.0
const LADDER_SPEED = 150.0

const JUMP_VELOCITY = -350.0
const DOUBLE_JUMP_VELOCITY = -300.0
const WALL_JUMP_VELOCITY = Vector2(300, -320)

# --- Camera Constants ---
const BASE_CAMERA_OFFSET = 100.0
const SPRINT_CAMERA_OFFSET = 250.0
const CAMERA_LERP_SPEED = 3.0

# --- Environmental States ---
var near_ladder: bool = false
var in_water: bool = false
var has_double_jumped: bool = false
var is_stopping: bool = false
var near_stairs: bool = false      # <-- Make sure this is here!
var stair_direction: float = 1.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var camera: Camera2D = $Camera2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D



# Store the dynamic offset calculation
var horizontal_y_offset: float = 0.0

func _physics_process(delta: float) -> void:
	
	
	# 2. State Machine Physics Processing
	match current_state:
		State.IDLE,State.RUNNING, State.WALKING, State.SPRINTING:
			handle_ground_movement(delta)
		State.ROLL:
			handle_roll_movement(delta)
		State.JUMPING, State.DOUBLE_JUMPING,State.LANDING:
			handle_airborne_movement(delta)
		State.CROUCHING, State.CRAWLING:
			handle_crouch_crawl_movement(delta)
		State.CLIMBING_LADDER:
			handle_ladder_movement(delta)
		State.WALL_CLINGING:
			handle_wall_movement(delta)
		State.DIVING:
			handle_diving_movement(delta)
		State.SWIMMING:
			handle_swimming_movement(delta)
		State.OBSTACLE:
			handle_obstacle_movement(delta)

	# 3. Execution & Secondary Updates
	move_and_slide()
	update_animations()
	update_camera_lead(delta)

# --- Physics Behaviors ---

func handle_ground_movement(delta: float) -> void:
	if not is_on_floor():
		current_state = State.LANDING
		return
		
	has_double_jumped = false
	velocity.y = 0 
	
	if is_stopping:
		velocity.x = move_toward(velocity.x, 0, RUN_SPEED * 2 * delta)
		if velocity.x == 0:
			is_stopping = false
		return
		
	if Input.is_action_just_pressed("roll"): 
		current_state = State.ROLL
		velocity.x = SPRINT_SPEED * 1.35 # Fixed direction forward burst
		return
		
	if Input.is_action_pressed("ui_down"): 
		current_state = State.CRAWLING
		return
	elif Input.is_action_pressed("sprint"): 
		current_state = State.SPRINTING
		velocity.x = move_toward(velocity.x, SPRINT_SPEED, RUN_SPEED * 3 * delta)
	elif Input.is_action_pressed("ui_left"): 
		current_state = State.WALKING
		velocity.x = move_toward(velocity.x, WALK_SPEED, RUN_SPEED * 4 * delta)
	else:
		current_state = State.RUNNING
		velocity.x = move_toward(velocity.x, RUN_SPEED, RUN_SPEED * 4 * delta)

	if Input.is_action_just_pressed("ui_accept"):
		velocity.y = JUMP_VELOCITY
		current_state = State.JUMPING

func handle_roll_movement(delta: float) -> void:
	# Keep gravity off during rolls so it doesn't slam down or register airborne bugs
	velocity.y = 0
	velocity.x = move_toward(velocity.x, RUN_SPEED, 250.0 * delta)
	
	# Fallback safety validation if animation errors occur
	if not animated_sprite.is_playing() or animated_sprite.animation != "roll":
		current_state = State.RUNNING
		return

	if animated_sprite.frame >= animated_sprite.sprite_frames.get_frame_count("roll") - 1:
		current_state = State.RUNNING
		
func handle_airborne_movement(delta: float) -> void:
	velocity += get_gravity() * delta
	velocity.x = RUN_SPEED 

	if is_on_wall_only() and Input.is_action_just_pressed("vault"):
		velocity.x = RUN_SPEED * 1.35     
		has_double_jumped = false        
		current_state = State.OBSTACLE
		return

	if is_on_wall_only():
		current_state = State.WALL_CLINGING
		return

	if Input.is_action_just_pressed("ui_accept") and not has_double_jumped:
		velocity.y = DOUBLE_JUMP_VELOCITY
		has_double_jumped = true
		current_state = State.DOUBLE_JUMPING

	if is_on_floor():
		current_state = State.RUNNING

func handle_crouch_crawl_movement(_delta: float) -> void:
	if not is_on_floor():
		current_state = State.JUMPING
		return

	if not Input.is_action_pressed("ui_down"):
		current_state = State.RUNNING
		return

	velocity.x = CROUCH_SPEED

func handle_ladder_movement(_delta: float) -> void:
	if not near_ladder:
		current_state = State.RUNNING
		return
		
	velocity.x = 0 
	
	if Input.is_action_pressed("ui_up"):
		velocity.y = -LADDER_SPEED
	elif Input.is_action_pressed("ui_down"):
		velocity.y = LADDER_SPEED
	else:
		velocity.y = 0 

func handle_wall_movement(delta: float) -> void:
	if not is_on_wall_only():
		current_state = State.JUMPING
		return

	velocity.y = move_toward(velocity.y, 100.0, get_gravity().y * delta)
	
	if Input.is_action_just_pressed("ui_accept"):
		var wall_normal = get_wall_normal()
		velocity.x = wall_normal.x * WALL_JUMP_VELOCITY.x
		velocity.y = WALL_JUMP_VELOCITY.y
		has_double_jumped = false 
		current_state = State.JUMPING

func handle_diving_movement(delta: float) -> void:
	if not in_water:
		current_state = State.RUNNING
		return
		
	velocity.y = move_toward(velocity.y, 20.0, 150.0 * delta)
	velocity.x = move_toward(velocity.x, SWIM_SPEED, 80.0 * delta)
		
	if animated_sprite.animation == "swimming_dive" and animated_sprite.frame == animated_sprite.sprite_frames.get_frame_count("swimming_dive") - 1:
		current_state = State.SWIMMING

func handle_swimming_movement(delta: float) -> void:
	if not in_water:
		current_state = State.RUNNING
		return

	velocity.x = SWIM_SPEED
	
	if Input.is_action_pressed("ui_up"):
		velocity.y = -SWIM_SPEED
	elif Input.is_action_pressed("ui_down"):
		velocity.y = SWIM_SPEED
	else:
		velocity.y = move_toward(velocity.y, 0.0, 100 * delta)

func handle_obstacle_movement(delta: float) -> void:
	velocity += get_gravity() * delta
	
	if is_on_floor():
		current_state = State.RUNNING
	elif velocity.y > 0 and not is_on_wall():
		current_state = State.JUMPING

func play_anim(anim_name: String, fallback_name: String = "running") -> void:
	var target_anim = anim_name if animated_sprite.sprite_frames.has_animation(anim_name) else fallback_name
	if animated_sprite.animation != target_anim or not animated_sprite.is_playing():
		animated_sprite.play(target_anim)

func update_animations() -> void:
	match current_state:
		State.RUNNING: play_anim("running","idle")
		State.WALKING: play_anim("walking", "running")
		State.SPRINTING: play_anim("speed_boost_running", "running")
		State.CROUCHING: play_anim("crouch", "running")
		State.CRAWLING: play_anim("crawl", "crouch")
		State.JUMPING: play_anim("jumping")
		State.DOUBLE_JUMPING: play_anim("double_jump", "jumping")
		State.WALL_CLINGING: play_anim("wall_climbing", "jumping")
		State.ROLL: play_anim("roll", "running")
		State.OBSTACLE: play_anim("obstacle_jump", "running") 
		State.DIVING: play_anim("swimming_dive", "swimming")
		State.SWIMMING: play_anim("swimming", "running")
		State.CLIMBING_LADDER:
			if velocity.y < 0: play_anim("climbing_ladder")
			elif velocity.y > 0: 
				play_anim("descending_ladder", "climbing_ladder")
			else: 
				play_anim("climbing_ladder") 
				animated_sprite.pause()
		State.STAIRS:
			if velocity.x != 0:
				# Reuse your ground walking animation when moving up/down stairs
				play_anim("walking")
			else:
				# Reuse your idle animation when standing still on the stairs
				play_anim("idle")

func update_camera_lead(delta: float) -> void:
	var target_offset = BASE_CAMERA_OFFSET
	if current_state == State.SPRINTING:
		target_offset = SPRINT_CAMERA_OFFSET
	elif current_state in [State.CROUCHING, State.CRAWLING, State.ROLL, State.SWIMMING, State.DIVING, State.OBSTACLE]:
		target_offset = BASE_CAMERA_OFFSET * 0.6
		
	camera.offset.x = lerp(camera.offset.x, target_offset, CAMERA_LERP_SPEED * delta)

# --- External Setup Setters ---

func set_near_ladder(value: bool, ladder_zone: Area2D = null) -> void:
	near_ladder = value
	if near_ladder:
		current_state = State.CLIMBING_LADDER
		if ladder_zone != null:
			global_position.x = ladder_zone.global_position.x
	else:
		if current_state == State.CLIMBING_LADDER:
			current_state = State.RUNNING
			
func set_near_stairs(value: bool, stair_zone: Area2D = null) -> void:
	near_stairs = value
	if near_stairs:
		current_state = State.STAIRS
		if stair_zone != null:
			# Grab the direction from metadata or script variable
			if stair_zone.has_meta("stair_direction"):
				stair_direction = stair_zone.get_meta("stair_direction")
			elif "stair_direction" in stair_zone:
				stair_direction = stair_zone.stair_direction
			# REMOVED: global_position.x snapping to prevent teleportation glitches
	else:
		if current_state == State.STAIRS:
			current_state = State.RUNNING
	
func set_in_water(value: bool) -> void:
	in_water = value
	if in_water:
		current_state = State.DIVING
		velocity.y = SWIM_SPEED * 1.5
		velocity.x = SWIM_SPEED * 0.8
	else:
		if current_state in [State.SWIMMING, State.DIVING]:
			velocity.y = JUMP_VELOCITY * 0.75 
			velocity.x = RUN_SPEED * 1.2       
			current_state = State.JUMPING
			

func trigger_stop() -> void:
	is_stopping = true
