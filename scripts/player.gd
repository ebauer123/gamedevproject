extends CharacterBody3D

# Grounded First-Person Parkour Controller (Mirror's Edge Style)
# Features: Momentum build-up, Ledge Grab & Hanging, Mantling,
# Skill Roll on landing, Hard Landing Stumble, Speed Vaulting,
# Horizontal Wallrun, Vertical Wall Climb (Tic-Tac), and Realistic Footstep Cadence.

enum State {
	GROUND,
	AIR,
	SLIDING,
	WALLRUN_HORIZONTAL,
	WALLRUN_VERTICAL,
	HANGING,
	MANTLING,
	SPEED_VAULT,
	ROLLING,
	HARD_LANDING
}

var current_state: State = State.GROUND

# Movement Speeds & Momentum
@export var walk_speed: float = 4.8
@export var jog_speed: float = 6.2
@export var max_sprint_speed: float = 10.2
@export var slide_speed: float = 11.5
@export var jump_velocity: float = 6.5
@export var gravity: float = 20.0
@export var mouse_sensitivity: float = 0.0022

var momentum: float = 0.0 # 0.0 to 1.0 (builds while running forward)
var current_speed: float = 5.0

# Node References
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ray_wall_left: RayCast3D = $RayWallLeft
@onready var ray_wall_right: RayCast3D = $RayWallRight
@onready var ray_wall_front: RayCast3D = $RayWallFront
@onready var ray_chest: RayCast3D = $RayChest
@onready var ray_head_clear: RayCast3D = $RayHeadClear
@onready var ray_vault_down: RayCast3D = $RayVaultDown

# Timers & States
var slide_timer: float = 0.0
var wallrun_timer: float = 0.0
var wallrun_side: float = 0.0 # -1 left, 1 right
var wallrun_normal: Vector3 = Vector3.ZERO

var mantle_start_pos: Vector3 = Vector3.ZERO
var mantle_target_pos: Vector3 = Vector3.ZERO
var mantle_progress: float = 0.0
var mantle_duration: float = 0.35

var roll_timer: float = 0.0
var roll_duration: float = 0.55
var roll_buffer_timer: float = 0.0

var hard_landing_timer: float = 0.0
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var fall_distance: float = 0.0
var apex_y: float = 0.0
var previous_y_velocity: float = 0.0

# Footsteps & Head Bob
var step_distance_accum: float = 0.0
var bob_cycle: float = 0.0
var camera_roll: float = 0.0
var base_head_y: float = 1.55

# Dynamic FOV
const BASE_FOV: float = 75.0
const SPRINT_FOV: float = 88.0
const SLIDE_FOV: float = 93.0
var target_fov: float = 75.0

func _ready() -> void:
	_setup_input_actions()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.player = self
		gm.current_spawn_pos = global_position
		gm.current_spawn_rot_y = rotation.y

func _setup_input_actions() -> void:
	_add_action_key("move_forward", KEY_W)
	_add_action_key("move_forward", KEY_UP)
	_add_action_key("move_back", KEY_S)
	_add_action_key("move_back", KEY_DOWN)
	_add_action_key("move_left", KEY_A)
	_add_action_key("move_left", KEY_LEFT)
	_add_action_key("move_right", KEY_D)
	_add_action_key("move_right", KEY_RIGHT)
	_add_action_key("jump", KEY_SPACE)
	_add_action_key("sprint", KEY_SHIFT)
	_add_action_key("crouch", KEY_CTRL)
	_add_action_key("crouch", KEY_C)
	_add_action_key("respawn", KEY_R)

func _add_action_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev = InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if current_state != State.ROLLING:
			rotate_y(-event.relative.x * mouse_sensitivity)
			head.rotate_x(-event.relative.y * mouse_sensitivity)
			head.rotation.x = clampf(head.rotation.x, -deg_to_rad(85.0), deg_to_rad(85.0))
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Fall void check
	if global_position.y < -15.0:
		var gm = get_node_or_null("/root/GameManager")
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("land_hard")
		if gm:
			gm.respawn_player()
		else:
			global_position = Vector3(0.0, 2.0, 0.0)
			velocity = Vector3.ZERO
		return

	# Decrement buffers
	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)
	roll_buffer_timer = maxf(0.0, roll_buffer_timer - delta)
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = 0.16
	if Input.is_action_just_pressed("crouch"):
		roll_buffer_timer = 0.32

	# State Machine execution
	match current_state:
		State.GROUND:
			_state_ground(delta)
		State.AIR:
			_state_air(delta)
		State.SLIDING:
			_state_sliding(delta)
		State.WALLRUN_HORIZONTAL:
			_state_wallrun_horizontal(delta)
		State.WALLRUN_VERTICAL:
			_state_wallrun_vertical(delta)
		State.HANGING:
			_state_hanging(delta)
		State.MANTLING:
			_state_mantling(delta)
		State.SPEED_VAULT:
			_state_speed_vault(delta)
		State.ROLLING:
			_state_rolling(delta)
		State.HARD_LANDING:
			_state_hard_landing(delta)

	previous_y_velocity = velocity.y
	_update_camera_and_hud(delta)

# --- STATE: GROUND ---
func _state_ground(delta: float) -> void:
	if not is_on_floor():
		current_state = State.AIR
		apex_y = global_position.y
		coyote_timer = 0.15
		return

	coyote_timer = 0.15
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var is_sprinting = Input.is_action_pressed("sprint")
	var is_moving_forward = input_vec.y < -0.3

	# Momentum build-up (Flow)
	if is_moving_forward:
		var build_rate = 0.6 if is_sprinting else 0.4
		momentum = minf(1.0, momentum + delta * build_rate)
	else:
		momentum = maxf(0.0, momentum - delta * 1.5)

	# Calculate current target speed
	var target_max = max_sprint_speed if is_sprinting else jog_speed
	current_speed = lerpf(walk_speed, target_max, momentum)

	# Jump execution
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		# Check for low obstacle speed vault
		if _can_speed_vault():
			_start_speed_vault()
			return
		_execute_jump()
		return

	# Slide initiation
	if Input.is_action_just_pressed("crouch") or (Input.is_action_pressed("crouch") and momentum > 0.4):
		if momentum > 0.3:
			_start_slide()
			return

	# Ground movement & acceleration
	var move_dir = (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
	if move_dir.length() > 0.1:
		var target_vel = move_dir * current_speed
		velocity.x = move_toward(velocity.x, target_vel.x, 38.0 * delta)
		velocity.z = move_toward(velocity.z, target_vel.z, 38.0 * delta)
		_process_footsteps(delta, current_speed)
	else:
		velocity.x = move_toward(velocity.x, 0.0, 32.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 32.0 * delta)

	velocity.y = -0.5 # keep grounded
	move_and_slide()

# --- STATE: AIR ---
func _state_air(delta: float) -> void:
	coyote_timer = maxf(0.0, coyote_timer - delta)
	apex_y = maxf(apex_y, global_position.y)

	# Jump during coyote time
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		jump_buffer_timer = 0.0
		coyote_timer = 0.0
		_execute_jump()
		return

	# Check for Ledge Grab / Hang while airborne & falling
	if velocity.y < 1.0 and _check_ledge_grab():
		return

	# Check for Vertical Wall Climb (Tic-Tac) when facing wall & jumping
	if jump_buffer_timer > 0.0 and ray_wall_front and ray_wall_front.is_colliding():
		jump_buffer_timer = 0.0
		_start_vertical_wallrun()
		return

	# Check for Horizontal Wallrun
	if _check_horizontal_wallrun():
		return

	# Apply realistic gravity
	velocity.y -= gravity * delta

	# Controlled air-strafe preserving forward momentum
	var input_vec = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	if input_vec.length() > 0.1:
		var air_dir = (transform.basis * Vector3(input_vec.x, 0.0, input_vec.y)).normalized()
		velocity.x = move_toward(velocity.x, air_dir.x * current_speed, 14.0 * delta)
		velocity.z = move_toward(velocity.z, air_dir.z * current_speed, 14.0 * delta)

	move_and_slide()

	# Landing detection
	if is_on_floor():
		_handle_landing()

# --- STATE: SLIDING ---
func _state_sliding(delta: float) -> void:
	slide_timer -= delta
	_set_crouch_height(true)

	var h_vel = Vector2(velocity.x, velocity.z)
	h_vel = h_vel.move_toward(Vector2.ZERO, 15.0 * delta)
	velocity.x = h_vel.x
	velocity.z = h_vel.y

	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5

	move_and_slide()

	# Jump out of slide
	if jump_buffer_timer > 0.0 and is_on_floor():
		jump_buffer_timer = 0.0
		_set_crouch_height(false)
		_execute_jump()
		return

	if slide_timer <= 0.0 or h_vel.length() < 3.0:
		_set_crouch_height(false)
		current_state = State.GROUND if is_on_floor() else State.AIR

# --- STATE: WALLRUN HORIZONTAL ---
func _state_wallrun_horizontal(delta: float) -> void:
	wallrun_timer -= delta

	# Low wall gravity
	velocity.y = maxf(velocity.y - (gravity * 0.22) * delta, -2.5)

	# Wall tangent direction
	var wall_forward = wallrun_normal.cross(Vector3.UP)
	if wall_forward.dot(-transform.basis.z) < 0.0:
		wall_forward = -wall_forward

	velocity.x = wall_forward.x * (max_sprint_speed * 1.05)
	velocity.z = wall_forward.z * (max_sprint_speed * 1.05)

	move_and_slide()

	# Wall jump off
	if jump_buffer_timer > 0.0:
		jump_buffer_timer = 0.0
		var kick_dir = (wallrun_normal * 6.5 + wall_forward * 4.0 + Vector3.UP * 6.8).normalized()
		velocity = kick_dir * 9.0
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("wall_hit", 1.1)
		current_state = State.AIR
		return

	# End of wall or timer expired
	var still_on_wall = (ray_wall_left and ray_wall_left.is_colliding()) or (ray_wall_right and ray_wall_right.is_colliding())
	if wallrun_timer <= 0.0 or not still_on_wall or is_on_floor():
		current_state = State.AIR

# --- STATE: WALLRUN VERTICAL (TIC-TAC) ---
func _state_wallrun_vertical(delta: float) -> void:
	wallrun_timer -= delta
	velocity.x = move_toward(velocity.x, 0.0, 20.0 * delta)
	velocity.z = move_toward(velocity.z, 0.0, 20.0 * delta)
	velocity.y -= gravity * 0.6 * delta

	move_and_slide()

	# Check if we can grab a ledge at the top
	if _check_ledge_grab():
		return

	# Wall kick-off turn
	if jump_buffer_timer > 0.0 and wallrun_timer < 0.3:
		jump_buffer_timer = 0.0
		var kick = transform.basis.z * 6.0 + Vector3.UP * 5.5
		velocity = kick
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("wall_hit")
		current_state = State.AIR
		return

	if wallrun_timer <= 0.0:
		current_state = State.AIR

# --- STATE: HANGING ---
func _state_hanging(_delta: float) -> void:
	velocity = Vector3.ZERO
	# Pull up onto ledge
	if Input.is_action_just_pressed("jump") or Input.is_action_pressed("move_forward"):
		_start_mantle()
		return
	# Drop down
	if Input.is_action_just_pressed("crouch") or Input.is_action_pressed("move_back"):
		current_state = State.AIR
		velocity = transform.basis.z * 1.5 + Vector3.DOWN * 1.0

# --- STATE: MANTLING ---
func _state_mantling(delta: float) -> void:
	mantle_progress += delta / mantle_duration
	global_position = mantle_start_pos.lerp(mantle_target_pos, minf(mantle_progress, 1.0))
	velocity = Vector3.ZERO

	if mantle_progress >= 1.0:
		current_state = State.GROUND
		momentum = 0.6
		velocity = -transform.basis.z * jog_speed

# --- STATE: SPEED VAULT ---
func _state_speed_vault(delta: float) -> void:
	mantle_progress += delta / 0.26
	global_position = mantle_start_pos.lerp(mantle_target_pos, minf(mantle_progress, 1.0))

	if mantle_progress >= 1.0:
		current_state = State.GROUND
		velocity = -transform.basis.z * current_speed

# --- STATE: ROLLING ---
func _state_rolling(delta: float) -> void:
	roll_timer += delta
	var progress = roll_timer / roll_duration
	# 360 degree forward pitch roll
	head.rotation.x = -sin(progress * PI) * deg_to_rad(45.0)
	camera.rotation.z = sin(progress * TAU) * deg_to_rad(15.0)

	_set_crouch_height(true)

	# Forward roll momentum
	var forward = -transform.basis.z
	velocity.x = forward.x * max_sprint_speed
	velocity.z = forward.z * max_sprint_speed
	velocity.y = -0.5
	move_and_slide()

	if roll_timer >= roll_duration:
		_set_crouch_height(false)
		head.rotation.x = 0.0
		camera.rotation.z = 0.0
		current_state = State.GROUND
		momentum = 0.85 # Reward successful roll with high momentum!

# --- STATE: HARD LANDING ---
func _state_hard_landing(delta: float) -> void:
	hard_landing_timer -= delta
	velocity = Vector3.ZERO
	head.rotation.x = deg_to_rad(-18.0) * (hard_landing_timer / 0.6)

	if hard_landing_timer <= 0.0:
		head.rotation.x = 0.0
		current_state = State.GROUND
		momentum = 0.0

# --- HELPER FUNCTIONS ---

func _execute_jump() -> void:
	velocity.y = jump_velocity
	current_state = State.AIR
	apex_y = global_position.y
	var sm = get_node_or_null("/root/SoundManager")
	if sm:
		sm.play("jump", randf_range(0.95, 1.05))

func _start_slide() -> void:
	current_state = State.SLIDING
	slide_timer = 0.75
	var forward = -transform.basis.z
	velocity.x = forward.x * slide_speed
	velocity.z = forward.z * slide_speed
	var sm = get_node_or_null("/root/SoundManager")
	if sm:
		sm.play("slide", 1.0)

func _check_horizontal_wallrun() -> bool:
	if momentum < 0.3:
		return false
	var left = ray_wall_left and ray_wall_left.is_colliding()
	var right = ray_wall_right and ray_wall_right.is_colliding()
	if not left and not right:
		return false

	var ray = ray_wall_left if left else ray_wall_right
	var normal = ray.get_collision_normal()
	if absf(normal.y) < 0.25: # vertical wall
		current_state = State.WALLRUN_HORIZONTAL
		wallrun_timer = 1.3
		wallrun_normal = normal
		wallrun_side = -1.0 if left else 1.0
		velocity.y = maxf(velocity.y, 1.5)
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("wall_hit", 1.2)
		return true
	return false

func _start_vertical_wallrun() -> void:
	current_state = State.WALLRUN_VERTICAL
	wallrun_timer = 0.45
	velocity.y = 6.2
	var sm = get_node_or_null("/root/SoundManager")
	if sm:
		sm.play("wall_hit", 0.95)

func _check_ledge_grab() -> bool:
	if not ray_chest or not ray_head_clear or not ray_vault_down:
		return false

	if ray_chest.is_colliding() and not ray_head_clear.is_colliding():
		ray_vault_down.force_raycast_update()
		if ray_vault_down.is_colliding():
			var hit_pt = ray_vault_down.get_collision_point()
			var height_delta = hit_pt.y - global_position.y
			if height_delta > 0.8 and height_delta < 2.3:
				current_state = State.HANGING
				global_position.y = hit_pt.y - 1.45
				var sm = get_node_or_null("/root/SoundManager")
				if sm:
					sm.play("grab", randf_range(0.95, 1.05))
				return true
	return false

func _can_speed_vault() -> bool:
	if momentum < 0.4:
		return false
	if ray_chest and ray_chest.is_colliding() and not ray_head_clear.is_colliding():
		ray_vault_down.force_raycast_update()
		if ray_vault_down.is_colliding():
			var hit_pt = ray_vault_down.get_collision_point()
			var h_diff = hit_pt.y - global_position.y
			return h_diff > 0.4 and h_diff < 1.3
	return false

func _start_speed_vault() -> void:
	current_state = State.SPEED_VAULT
	mantle_start_pos = global_position
	var hit_pt = ray_vault_down.get_collision_point()
	mantle_target_pos = hit_pt + Vector3(0.0, 1.0, 0.0) + (-transform.basis.z * 1.0)
	mantle_progress = 0.0
	var sm = get_node_or_null("/root/SoundManager")
	if sm:
		sm.play("mantle", 1.2)

func _start_mantle() -> void:
	current_state = State.MANTLING
	mantle_start_pos = global_position
	ray_vault_down.force_raycast_update()
	var hit_pt = ray_vault_down.get_collision_point()
	mantle_target_pos = hit_pt + Vector3(0.0, 1.0, 0.0) + (-transform.basis.z * 0.6)
	mantle_progress = 0.0
	var sm = get_node_or_null("/root/SoundManager")
	if sm:
		sm.play("mantle", 1.0)

func _handle_landing() -> void:
	var impact = absf(previous_y_velocity)
	var sm = get_node_or_null("/root/SoundManager")

	# High drop impact (needs roll)
	if impact > 9.0:
		var wants_roll = roll_buffer_timer > 0.0 or Input.is_action_pressed("crouch")
		if wants_roll:
			# Skill Roll!
			current_state = State.ROLLING
			roll_timer = 0.0
			roll_buffer_timer = 0.0
			if sm:
				sm.play("roll", 1.0)
			return
		else:
			# Hard landing stumble
			current_state = State.HARD_LANDING
			hard_landing_timer = 0.65
			if sm:
				sm.play("land_hard", 1.0)
			return

	# Normal landing
	current_state = State.GROUND
	if impact > 3.0 and sm:
		sm.play("land_soft", randf_range(0.95, 1.05))

func _process_footsteps(delta: float, speed: float) -> void:
	step_distance_accum += speed * delta
	var step_interval = 1.8 if speed > jog_speed else 1.3
	if step_distance_accum >= step_interval:
		step_distance_accum = 0.0
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("step", randf_range(0.9, 1.1), -4.0)

func _set_crouch_height(crouching: bool) -> void:
	var target_h = 1.0 if crouching else 1.8
	var target_head_y = 0.75 if crouching else base_head_y

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var cap = collision_shape.shape as CapsuleShape3D
		cap.height = lerpf(cap.height, target_h, 0.3)
		collision_shape.position.y = cap.height * 0.5
	head.position.y = lerpf(head.position.y, target_head_y, 0.3)

func _update_camera_and_hud(delta: float) -> void:
	# Head bob
	var horiz_vel = Vector2(velocity.x, velocity.z).length()
	if current_state == State.GROUND and horiz_vel > 1.0:
		bob_cycle += delta * (current_speed * 1.5)
		camera.position.x = sin(bob_cycle * 0.5) * 0.04
		camera.position.y = absf(sin(bob_cycle)) * 0.04
	elif current_state != State.ROLLING:
		camera.position.x = lerpf(camera.position.x, 0.0, delta * 10.0)
		camera.position.y = lerpf(camera.position.y, 0.0, delta * 10.0)

	# Camera Roll Tilt
	var target_roll = 0.0
	if current_state == State.WALLRUN_HORIZONTAL:
		target_roll = -wallrun_side * deg_to_rad(14.0)
	camera_roll = lerpf(camera_roll, target_roll, delta * 8.0)
	if current_state != State.ROLLING:
		camera.rotation.z = camera_roll

	# Dynamic FOV
	if current_state == State.SLIDING or current_state == State.ROLLING:
		target_fov = SLIDE_FOV
	elif momentum > 0.6:
		target_fov = lerpf(BASE_FOV, SPRINT_FOV, momentum)
	else:
		target_fov = BASE_FOV

	camera.fov = lerpf(camera.fov, target_fov, delta * 6.0)

# Springboard integration (e.g. stepping on an AC unit or vault box)
func springboard_launch(horizontal_boost: float, vertical_lift: float) -> void:
	var forward = -transform.basis.z
	velocity.x = forward.x * horizontal_boost
	velocity.z = forward.z * horizontal_boost
	velocity.y = vertical_lift
	current_state = State.AIR
	momentum = 1.0
	var sm = get_node_or_null("/root/SoundManager")
	if sm:
		sm.play("springboard", 1.05)

func teleport_to(pos: Vector3, rot_y: float) -> void:
	global_position = pos
	rotation.y = rot_y
	velocity = Vector3.ZERO
	current_state = State.GROUND
	momentum = 0.0
	_set_crouch_height(false)
