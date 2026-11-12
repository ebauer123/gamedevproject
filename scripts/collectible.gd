extends Area3D

# Collectible Parkour Token / Coin
# Rewards daring parkour routes and lines.

@onready var mesh: MeshInstance3D = $MeshInstance3D
var initial_y: float = 0.0

func _ready() -> void:
	initial_y = position.y
	body_entered.connect(_on_body_entered)
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.total_coins += 1

func _process(delta: float) -> void:
	rotate_y(delta * 2.5)
	position.y = initial_y + sin(Time.get_ticks_msec() * 0.004) * 0.2

func _on_body_entered(body: Node3D) -> void:
	if body is CharacterBody3D:
		var sm = get_node_or_null("/root/SoundManager")
		if sm:
			sm.play("coin", randf_range(0.95, 1.1))
		var gm = get_node_or_null("/root/GameManager")
		if gm:
			gm.register_coin()
		queue_free()
