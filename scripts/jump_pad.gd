extends Area3D

# Jump Pad / Bounce Pad
# Propels the player high into the air upon contact.

@export var launch_force: float = 18.0

@onready var pad_mesh: MeshInstance3D = $PadMesh
var bounce_scale: float = 1.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if bounce_scale > 1.0:
		bounce_scale = lerpf(bounce_scale, 1.0, delta * 8.0)
		if pad_mesh:
			pad_mesh.scale = Vector3(1.0 / bounce_scale, bounce_scale, 1.0 / bounce_scale)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("launch_upward"):
		body.launch_upward(launch_force)
		bounce_scale = 1.6
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("boost", 1.3, 2.0)
