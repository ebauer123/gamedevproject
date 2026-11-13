extends StaticBody3D

# Springboard AC Unit / Vault Crate (Mirror's Edge Style)
# Players can speed-vault over it, or step on it to springboard across gaps.

@export var horizontal_boost: float = 12.5
@export var vertical_lift: float = 7.0

@onready var trigger_area: Area3D = $TriggerArea

func _ready() -> void:
	if trigger_area:
		trigger_area.body_entered.connect(_on_trigger_body_entered)

func _on_trigger_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D and body.has_method("springboard_launch"):
		body.springboard_launch(horizontal_boost, vertical_lift)
