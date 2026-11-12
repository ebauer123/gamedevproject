extends Node

# Global Game Manager (Autoload / Singleton or Scene Manager)
# Manages parkour state, timers, checkpoints, score, and respawning.

signal checkpoint_reached(index: int, total: int)
signal coin_collected(current: int, total: int)
signal player_respawned(death_count: int)
signal game_completed(final_time: float, coins: int, max_coins: int, deaths: int)
signal time_updated(elapsed: float)

var player: Node3D = null
var current_spawn_pos: Vector3 = Vector3(0.0, 2.0, 0.0)
var current_spawn_rot_y: float = 0.0

var elapsed_time: float = 0.0
var is_running: bool = false
var is_completed: bool = false

var current_checkpoint_idx: int = 0
var total_checkpoints: int = 0

var coins_collected: int = 0
var total_coins: int = 0
var deaths: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	reset_state()

func reset_state() -> void:
	elapsed_time = 0.0
	is_running = true
	is_completed = false
	current_checkpoint_idx = 0
	coins_collected = 0
	total_coins = 0
	deaths = 0

func _process(delta: float) -> void:
	if is_running and not is_completed:
		elapsed_time += delta
		emit_signal("time_updated", elapsed_time)

func register_checkpoint(pos: Vector3, rot_y: float, idx: int) -> void:
	if idx > current_checkpoint_idx:
		current_checkpoint_idx = idx
		current_spawn_pos = pos + Vector3(0.0, 1.0, 0.0)
		current_spawn_rot_y = rot_y
		emit_signal("checkpoint_reached", current_checkpoint_idx, total_checkpoints)

func register_coin() -> void:
	coins_collected += 1
	emit_signal("coin_collected", coins_collected, total_coins)

func respawn_player() -> void:
	deaths += 1
	emit_signal("player_respawned", deaths)
	if player and is_instance_valid(player):
		if player.has_method("teleport_to"):
			player.teleport_to(current_spawn_pos, current_spawn_rot_y)
		else:
			player.global_position = current_spawn_pos
			player.velocity = Vector3.ZERO

func complete_game() -> void:
	if is_completed:
		return
	is_completed = true
	is_running = false
	emit_signal("game_completed", elapsed_time, coins_collected, total_coins, deaths)

func restart_game() -> void:
	reset_state()
	get_tree().reload_current_scene()
