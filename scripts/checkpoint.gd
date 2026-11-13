extends Area3D

# Checkpoint Trigger
# Activates when player touches it, updates spawn point, turns from amber to bright cyan.

@export var checkpoint_index: int = 1

var is_active: bool = false
@onready var indicator_mesh: MeshInstance3D = $IndicatorMesh
@onready var base_mesh: MeshInstance3D = $BaseMesh

var active_material: StandardMaterial3D
var inactive_material: StandardMaterial3D

func _ready() -> void:
	add_to_group("checkpoints")
	body_entered.connect(_on_body_entered)
	
	inactive_material = StandardMaterial3D.new()
	inactive_material.albedo_color = Color(0.95, 0.12, 0.18)
	inactive_material.emission_enabled = true
	inactive_material.emission = Color(0.95, 0.1, 0.15)
	inactive_material.emission_energy_multiplier = 0.8
	
	active_material = StandardMaterial3D.new()
	active_material.albedo_color = Color(0.2, 0.9, 1.0)
	active_material.emission_enabled = true
	active_material.emission = Color(0.2, 0.9, 1.0)
	active_material.emission_energy_multiplier = 1.5
	
	if indicator_mesh:
		indicator_mesh.material_override = inactive_material

func _process(delta: float) -> void:
	if indicator_mesh:
		indicator_mesh.rotate_y(delta * 2.0)
		indicator_mesh.position.y = 1.0 + sin(Time.get_ticks_msec() * 0.003) * 0.15

func _on_body_entered(body: Node3D) -> void:
	if is_active:
		return
	if body is CharacterBody3D:
		is_active = true
		if indicator_mesh:
			indicator_mesh.material_override = active_material
		
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("checkpoint")
			
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.register_checkpoint(global_position, global_rotation.y, checkpoint_index)
