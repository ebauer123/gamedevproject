extends CanvasLayer

# Parkour HUD & Overlay Controller (Mirror's Edge Style)
# Handles flow speedometer, timer, checkpoints, runner bags, action prompts, and menus.

@onready var timer_label: Label = $TopBar/HBox/TimerLabel
@onready var checkpoint_label: Label = $TopBar/HBox/CheckpointLabel
@onready var token_label: Label = $TopBar/HBox/TokenLabel
@onready var speed_label: Label = $BottomBar/VBox/SpeedLabel
@onready var prompt_label: Label = $ActionPrompt/PromptLabel
@onready var crosshair: Control = $Crosshair

@onready var victory_panel: PanelContainer = $VictoryPanel
@onready var victory_time: Label = $VictoryPanel/VBox/TimeResult
@onready var victory_tokens: Label = $VictoryPanel/VBox/TokensResult
@onready var victory_deaths: Label = $VictoryPanel/VBox/DeathsResult
@onready var restart_button: Button = $VictoryPanel/VBox/RestartButton

@onready var pause_panel: PanelContainer = $PausePanel
@onready var resume_button: Button = $PausePanel/VBox/ResumeButton
@onready var pause_restart_button: Button = $PausePanel/VBox/PauseRestartButton

var player_ref: CharacterBody3D = null

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if victory_panel:
		victory_panel.visible = false
	if pause_panel:
		pause_panel.visible = false
	if prompt_label:
		prompt_label.visible = false
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
	if resume_button:
		resume_button.pressed.connect(_on_resume_pressed)
	if pause_restart_button:
		pause_restart_button.pressed.connect(_on_restart_pressed)
	
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.time_updated.connect(_on_time_updated)
		gm.checkpoint_reached.connect(_on_checkpoint_reached)
		gm.coin_collected.connect(_on_coin_collected)
		gm.game_completed.connect(_on_game_completed)
		_update_labels(gm)

func _process(_delta: float) -> void:
	if not player_ref:
		var gm = get_node_or_null("/root/GameManager")
		if gm and gm.player:
			player_ref = gm.player
	
	if player_ref and is_instance_valid(player_ref):
		var h_speed = Vector2(player_ref.velocity.x, player_ref.velocity.z).length()
		var flow_pct = int(player_ref.momentum * 100.0) if "momentum" in player_ref else 0
		if speed_label:
			speed_label.text = "%.1f m/s  (FLOW: %d%%)" % [h_speed, flow_pct]
		
		_update_action_prompt()

func _update_action_prompt() -> void:
	if not prompt_label or not player_ref:
		return
	
	var state_name = player_ref.current_state if "current_state" in player_ref else -1
	# player_ref.State: 5=HANGING, 1=AIR, 3=WALLRUN_HORIZ, 4=WALLRUN_VERT
	if state_name == 5: # HANGING
		prompt_label.text = "[W / SPACE] MANTLE UP   |   [S / CTRL] DROP"
		prompt_label.visible = true
	elif state_name == 1 and player_ref.velocity.y < -8.0: # AIR high drop
		prompt_label.text = "[CTRL] TIMED PARKOUR ROLL!"
		prompt_label.visible = true
	elif state_name == 3: # WALLRUN_HORIZONTAL
		prompt_label.text = "[SPACE] WALL JUMP KICK"
		prompt_label.visible = true
	elif state_name == 4: # WALLRUN_VERTICAL
		prompt_label.text = "[SPACE] WALL TURN & KICK"
		prompt_label.visible = true
	else:
		prompt_label.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or (event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE):
		if not victory_panel or not victory_panel.visible:
			_toggle_pause()

	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if (not victory_panel or not victory_panel.visible) and (not pause_panel or not pause_panel.visible):
			var gm = get_node_or_null("/root/GameManager")
			if gm:
				gm.respawn_player()

func _toggle_pause() -> void:
	var paused = not get_tree().paused
	get_tree().paused = paused
	if pause_panel:
		pause_panel.visible = paused
	if paused:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_resume_pressed() -> void:
	get_tree().paused = false
	if pause_panel:
		pause_panel.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _on_restart_pressed() -> void:
	get_tree().paused = false
	var gm = get_node_or_null("/root/GameManager")
	if gm:
		gm.restart_game()

func _on_time_updated(seconds: float) -> void:
	if not timer_label:
		return
	var mins = int(seconds) / 60
	var secs = int(seconds) % 60
	var millis = int((seconds - int(seconds)) * 100)
	timer_label.text = "%02d:%02d.%02d" % [mins, secs, millis]

func _on_checkpoint_reached(idx: int, total: int) -> void:
	if checkpoint_label:
		checkpoint_label.text = "Rooftop: %d / %d" % [idx, total]

func _on_coin_collected(curr: int, total: int) -> void:
	if token_label:
		token_label.text = "Bags: %d / %d" % [curr, total]

func _on_game_completed(final_time: float, coins: int, max_coins: int, deaths: int) -> void:
	var mins = int(final_time) / 60
	var secs = int(final_time) % 60
	var millis = int((final_time - int(final_time)) * 100)
	if victory_time:
		victory_time.text = "Time: %02d:%02d.%02d" % [mins, secs, millis]
	if victory_tokens:
		victory_tokens.text = "Runner Bags: %d / %d" % [coins, max_coins]
	if victory_deaths:
		victory_deaths.text = "Falls: %d" % deaths
	
	if victory_panel:
		victory_panel.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _update_labels(gm: Node) -> void:
	_on_time_updated(gm.elapsed_time)
	_on_checkpoint_reached(gm.current_checkpoint_idx, gm.total_checkpoints)
	_on_coin_collected(gm.coins_collected, gm.total_coins)
