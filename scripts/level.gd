extends Node3D

# Parkour Level Master Script
# Initializes level metrics, counts checkpoints and collectibles, and manages world setup.

func _ready() -> void:
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.reset_state()
		var ckpts = get_tree().get_nodes_in_group("checkpoints")
		gm.total_checkpoints = ckpts.size()
