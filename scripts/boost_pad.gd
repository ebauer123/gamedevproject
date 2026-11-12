extends Area3D

# Boost Pad / Speed Ring
# Launches the player forward with an explosive surge of speed.

@export var boost_speed: float = 24.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("boost_forward"):
		body.boost_forward(boost_speed)
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("boost", 1.2, 2.5)
