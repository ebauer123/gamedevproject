extends CharacterBody3D

# Advanced 3D Parkour Controller for Godot 4
# Includes: Sprinting, Sliding, Coyote Time, Jump Buffering, Double Jump,
# Wall Running, Wall Jumping, Ledge Vaulting, Dynamic FOV, and Head Bob.

@export var walk_speed: float = 7.5
@export var sprint_speed: float = 12.0
@export var slide_speed: float = 15.5
@export var jump_velocity: float = 8.5
@export var double_jump_velocity: float = 7.5
@export var wall_jump_up_velocity: float = 8.0
@export var wall_jump_kick_velocity: float = 9.0
@export var gravity: float = 22.0
@export var mouse_sensitivity: float = 0.0022

# Ground / Air Acceleration
@export var ground_accel: float = 50.0
@export var ground_friction: float = 38.0
@export var air_accel: float = 22.0
@export var air_friction: float = 3.0

# Node References
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var ray_wall_left: RayCast3D = $RayWallLeft
@onready var ray_wall_right: RayCast3D = $RayWallRight
@onready var ray_chest: RayCast3D = $RayChest
@onready var ray_head_clear: RayCast3D = $RayHeadClear
@onready var ray_vault_down: RayCast3D = $RayVaultDown

# State Variables
var is_sliding: bool = false
var slide_timer: float = 0.0
var slide_direction: Vector3 = Vector3.ZERO

var is_wall_running: bool = false
var wall_run_timer: float = 0.0
var wall_run_normal: Vector3 = Vector3.ZERO
var wall_side: float = 0.0 # -1 for left, 1 for right

var is_vaulting: bool = false
var vault_target_pos: Vector3 = Vector3.ZERO
var vault_timer: float = 0.0

var can_double_jump: bool = true
var coyote_timer: float = 0.0
var jump_buffer_timer: float = 0.0
var was_on_floor: bool = false
var last_y_velocity: float = 0.0

# Head Bob and Camera Tilt
var bob_cycle: float = 0.0
var camera_tilt: float = 0.0
var landing_dip: float = 0.0
var target_fov: float = 75.0
const BASE_FOV: float = 75.0
const SPRINT_FOV: float = 86.0
const SLIDE_FOV: float = 92.0
const WALLRUN_FOV: float = 83.0

# Collision dimensions
var normal_height: float = 1.8
var crouch_height: float = 1.0

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
		# Horizontal rotation on player body
		rotate_y(-event.relative.x * mouse_sensitivity)
		# Vertical rotation on head
		head.rotate_x(-event.relative.y * mouse_sensitivity)
		head.rotation.x = clampf(head.rotation.x, -deg_to_rad(89.0), deg_to_rad(89.0))
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _physics_process(delta: float) -> void:
	# Fall void check
	if global_position.y < -15.0:
		var gm = get_node_or_null("/root/GameManager")
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("respawn")
		if gm:
			gm.respawn_player()
		else:
			global_position = Vector3(0.0, 2.0, 0.0)
			velocity = Vector3.ZERO
		return

	# Timers
	if is_on_floor():
		coyote_timer = 0.15
		can_double_jump = true
		is_wall_running = false
	else:
		coyote_timer = maxf(0.0, coyote_timer - delta)

	jump_buffer_timer = maxf(0.0, jump_buffer_timer - delta)

	# Read Input
	var input_dir = _get_input_vector()
	var jump_pressed = _is_jump_just_pressed()
	var sprint_held = _is_sprint_pressed()
	var crouch_held = _is_crouch_pressed()

	if jump_pressed:
		jump_buffer_timer = 0.15

	# Ledge Vaulting Update
	if is_vaulting:
		_process_vault(delta)
		return

	# Check for Ledge Vault Initiation
	if not is_on_floor() and velocity.y > -2.0 and _check_vault():
		return

	# Handle Wall Running
	_check_wall_run(delta, input_dir)

	# Handle Jumping
	_handle_jumping()

	# Handle Sliding & Crouching
	_handle_slide(delta, crouch_held, sprint_held, input_dir)

	# Ground / Air Movement
	if not is_vaulting:
		_handle_movement(delta, input_dir, sprint_held)

	# Gravity
	if not is_on_floor():
		if is_wall_running:
			# Wall run low gravity
			velocity.y = maxf(velocity.y - (gravity * 0.18) * delta, -3.0)
		else:
			velocity.y -= gravity * delta

	last_y_velocity = velocity.y
	move_and_slide()

	# Landing impact detection
	if not was_on_floor and is_on_floor():
		_on_land()
	was_on_floor = is_on_floor()

	# Camera effects (Tilt, FOV, Bob, Landing Dip)
	_update_camera_effects(delta, input_dir, sprint_held)

func _get_input_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")

func _is_jump_just_pressed() -> bool:
	return Input.is_action_just_pressed("jump")

func _is_sprint_pressed() -> bool:
	return Input.is_action_pressed("sprint")

func _is_crouch_pressed() -> bool:
	return Input.is_action_pressed("crouch")

func _handle_movement(delta: float, input_dir: Vector2, sprint_held: bool) -> void:
	if is_sliding:
		# Gradually decelerate slide towards normal crouch speed
		var horizontal = Vector2(velocity.x, velocity.z)
		horizontal = horizontal.move_toward(Vector2.ZERO, ground_friction * 0.45 * delta)
		velocity.x = horizontal.x
		velocity.z = horizontal.y
		return

	# Calculate desired direction relative to player orientation
	var transform_dir = (transform.basis * Vector3(input_dir.x, 0.0, input_dir.y)).normalized()

	var target_speed = walk_speed
	if sprint_held and input_dir.y < -0.1: # Forward sprint
		target_speed = sprint_speed

	var target_vel = transform_dir * target_speed
	var current_horizontal = Vector3(velocity.x, 0.0, velocity.z)

	if is_on_floor():
		if transform_dir.length() > 0.1:
			current_horizontal = current_horizontal.move_toward(target_vel, ground_accel * delta)
		else:
			current_horizontal = current_horizontal.move_toward(Vector3.ZERO, ground_friction * delta)
	else:
		# Air control
		if transform_dir.length() > 0.1:
			current_horizontal = current_horizontal.move_toward(target_vel, air_accel * delta)
		else:
			current_horizontal = current_horizontal.move_toward(Vector3.ZERO, air_friction * delta)

	velocity.x = current_horizontal.x
	velocity.z = current_horizontal.z

func _handle_slide(delta: float, crouch_held: bool, sprint_held: bool, input_dir: Vector2) -> void:
	var sm = get_node_or_null("/root/SoundManager")
	var horiz_speed = Vector2(velocity.x, velocity.z).length()

	# Start slide if running and pressing crouch
	if is_on_floor() and crouch_held and not is_sliding:
		if horiz_speed > walk_speed * 0.9:
			is_sliding = true
			slide_timer = 0.8
			# Boost forward into slide
			var move_forward = -transform.basis.z
			if input_dir.length() > 0.1:
				move_forward = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
			velocity.x = move_forward.x * slide_speed
			velocity.z = move_forward.z * slide_speed
			if sm:
				sm.play("slide")
		else:
			# Regular crouch height
			_set_crouch_height(true)

	if is_sliding:
		slide_timer -= delta
		_set_crouch_height(true)
		if slide_timer <= 0.0 or horiz_speed < walk_speed * 0.6 or not is_on_floor():
			is_sliding = false
			if not crouch_held:
				_set_crouch_height(false)
	elif not crouch_held:
		_set_crouch_height(false)

func _set_crouch_height(crouching: bool) -> void:
	var target_h = crouch_height if crouching else normal_height
	var target_head_y = 0.7 if crouching else 1.55

	if collision_shape and collision_shape.shape is CapsuleShape3D:
		var cap = collision_shape.shape as CapsuleShape3D
		cap.height = lerpf(cap.height, target_h, 0.25)
		collision_shape.position.y = cap.height * 0.5
	head.position.y = lerpf(head.position.y, target_head_y, 0.25)

func _handle_jumping() -> void:
	var sm = get_node_or_null("/root/SoundManager")

	if jump_buffer_timer > 0.0:
		# Wall jump
		if is_wall_running:
			jump_buffer_timer = 0.0
			is_wall_running = false
			velocity = wall_run_normal * wall_jump_kick_velocity + Vector3.UP * wall_jump_up_velocity
			can_double_jump = true
			if sm:
				sm.play("wall_jump")
			return

		# Ground jump (including coyote time)
		if coyote_timer > 0.0:
			jump_buffer_timer = 0.0
			coyote_timer = 0.0
			velocity.y = jump_velocity
			if sm:
				sm.play("jump")
			return

		# Midair double jump
		if can_double_jump and not is_on_floor():
			jump_buffer_timer = 0.0
			can_double_jump = false
			velocity.y = double_jump_velocity
			# Re-orient horizontal velocity towards input
			var input = _get_input_vector()
			if input.length() > 0.1:
				var forward = (transform.basis * Vector3(input.x, 0, input.y)).normalized()
				var speed = maxf(Vector2(velocity.x, velocity.z).length(), sprint_speed * 0.8)
				velocity.x = forward.x * speed
				velocity.z = forward.z * speed
			if sm:
				sm.play("double_jump")
			return

func _check_wall_run(delta: float, input_dir: Vector2) -> void:
	if is_on_floor() or is_vaulting or input_dir.y >= 0.0:
		is_wall_running = false
		return

	var left_colliding = ray_wall_left and ray_wall_left.is_colliding()
	var right_colliding = ray_wall_right and ray_wall_right.is_colliding()

	if left_colliding or right_colliding:
		var ray = ray_wall_left if left_colliding else ray_wall_right
		var normal = ray.get_collision_normal()

		# Must be a vertical wall (normal roughly horizontal)
		if absf(normal.y) < 0.2:
			if not is_wall_running:
				is_wall_running = true
				wall_run_timer = 1.4
				wall_run_normal = normal
				wall_side = -1.0 if left_colliding else 1.0
				can_double_jump = true

			wall_run_timer -= delta
			if wall_run_timer <= 0.0:
				is_wall_running = false
			else:
				# Slide along wall forward tangent
				var wall_forward = normal.cross(Vector3.UP)
				if wall_forward.dot(-transform.basis.z) < 0.0:
					wall_forward = -wall_forward
				velocity.x = wall_forward.x * sprint_speed
				velocity.z = wall_forward.z * sprint_speed
			return

	is_wall_running = false

func _check_vault() -> bool:
	if not ray_chest or not ray_head_clear or not ray_vault_down:
		return false

	# Chest hits wall, head is clear to grab
	if ray_chest.is_colliding() and not ray_head_clear.is_colliding():
		ray_vault_down.force_raycast_update()
		if ray_vault_down.is_colliding():
			var hit_pos = ray_vault_down.get_collision_point()
			var height_diff = hit_pos.y - global_position.y
			if height_diff > 0.4 and height_diff < 1.6:
				is_vaulting = true
				vault_timer = 0.22
				vault_target_pos = hit_pos + Vector3(0.0, 1.0, 0.0) + (-transform.basis.z * 0.4)
				velocity = Vector3.ZERO
				var sm = get_node_or_null("/root/SoundManager")
				if sm:
					sm.play("wall_jump", 1.2)
				return true
	return false

func _process_vault(delta: float) -> void:
	vault_timer -= delta
	global_position = global_position.lerp(vault_target_pos, delta * 14.0)
	if vault_timer <= 0.0 or global_position.distance_to(vault_target_pos) < 0.2:
		is_vaulting = false
		velocity = -transform.basis.z * walk_speed

func _on_land() -> void:
	landing_dip = clampf(absf(last_y_velocity) * 0.02, 0.05, 0.35)
	var sm = get_node_or_null("/root/SoundManager")
	if sm and absf(last_y_velocity) > 4.0:
		sm.play("land", randf_range(0.9, 1.1), -2.0)

func _update_camera_effects(delta: float, input_dir: Vector2, sprint_held: bool) -> void:
	# Landing dip recovery
	landing_dip = lerpf(landing_dip, 0.0, delta * 12.0)
	camera.position.y = -landing_dip

	# Head bob
	var horiz_vel = Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and horiz_vel > 0.5 and not is_sliding:
		var bob_speed = 10.0 if sprint_held else 7.0
		bob_cycle += delta * bob_speed
		camera.position.x = sin(bob_cycle) * 0.04
		camera.position.y += absf(sin(bob_cycle * 2.0)) * 0.03
	else:
		bob_cycle = 0.0
		camera.position.x = lerpf(camera.position.x, 0.0, delta * 10.0)

	# Camera Roll / Tilt (Strafing and Wall Running)
	var target_roll = 0.0
	if is_wall_running:
		target_roll = -wall_side * deg_to_rad(12.0)
	elif input_dir.x != 0.0:
		target_roll = -input_dir.x * deg_to_rad(2.5)

	camera_tilt = lerpf(camera_tilt, target_roll, delta * 8.0)
	camera.rotation.z = camera_tilt

	# Dynamic FOV
	if is_sliding:
		target_fov = SLIDE_FOV
	elif is_wall_running:
		target_fov = WALLRUN_FOV
	elif sprint_held and horiz_vel > walk_speed * 1.1:
		target_fov = SPRINT_FOV
	else:
		target_fov = BASE_FOV

	camera.fov = lerpf(camera.fov, target_fov, delta * 8.0)

# Public Launch API (for Jump pads and Boost pads)
func launch_upward(force: float) -> void:
	velocity.y = force
	can_double_jump = true

func boost_forward(force: float) -> void:
	var forward = -transform.basis.z
	velocity.x = forward.x * force
	velocity.z = forward.z * force
	target_fov = SLIDE_FOV + 5.0

func teleport_to(pos: Vector3, rot_y: float) -> void:
	global_position = pos
	rotation.y = rot_y
	velocity = Vector3.ZERO
	is_wall_running = false
	is_sliding = false
	is_vaulting = false
