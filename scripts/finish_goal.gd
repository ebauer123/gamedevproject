extends Area3D

# Finish Goal / Victory Portal
# Reaching this marks the completion of the parkour course!

@onready var portal_ring: MeshInstance3D = $PortalRing
var is_finished: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _process(delta: float) -> void:
	if portal_ring:
		portal_ring.rotate_z(delta * 1.5)

func _on_body_entered(body: Node3D) -> void:
	if is_finished:
		return
	if body is CharacterBody3D:
		is_finished = true
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("victory", 1.0, 3.0)
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.complete_game()
