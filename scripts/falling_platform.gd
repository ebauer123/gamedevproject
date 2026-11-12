extends StaticBody3D

# Falling / Crumbling Platform
# Shakes when player lands on it, drops/vanishes, and respawns after a delay.

@export var delay_before_fall: float = 0.8
@export var respawn_time: float = 3.2

@onready var trigger_area: Area3D = $TriggerArea
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

var original_pos: Vector3
var is_triggered: bool = false
var is_fallen: bool = false
var fall_timer: float = 0.0
var respawn_timer: float = 0.0
var shake_amount: float = 0.0

func _ready() -> void:
	original_pos = position
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)

func _process(delta: float) -> void:
	if is_triggered and not is_fallen:
		fall_timer += delta
		shake_amount = clampf(fall_timer / delay_before_fall, 0.0, 1.0) * 0.12
		position = original_pos + Vector3(
			randf_range(-shake_amount, shake_amount),
			0.0,
			randf_range(-shake_amount, shake_amount)
		)
		
		if fall_timer >= delay_before_fall:
			_fall()

	elif is_fallen:
		respawn_timer += delta
		if respawn_timer >= respawn_time:
			_respawn()

func _on_trigger_body_entered(body: Node3D) -> void:
	if not is_triggered and not is_fallen and body is CharacterBody3D:
		is_triggered = true
		fall_timer = 0.0
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("crumble", 1.1)

func _fall() -> void:
	is_fallen = true
	is_triggered = false
	respawn_timer = 0.0
	position = original_pos
	collision_shape.set_deferred("disabled", true)
	mesh_instance.visible = false

func _respawn() -> void:
	is_fallen = false
	is_triggered = false
	position = original_pos
	collision_shape.set_deferred("disabled", false)
	mesh_instance.visible = true
