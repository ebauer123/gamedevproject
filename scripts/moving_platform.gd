extends AnimatableBody3D

# Moving Platform for Godot 4 (AnimatableBody3D ensures physics sync)
# Moves back and forth along a vector with smooth sinusoidal easing.

@export var move_offset: Vector3 = Vector3(8.0, 0.0, 0.0)
@export var cycle_duration: float = 4.0
@export var phase_offset: float = 0.0

var start_pos: Vector3
var time_accum: float = 0.0

func _ready() -> void:
	start_pos = position
	time_accum = phase_offset

func _physics_process(delta: float) -> void:
	if cycle_duration <= 0.0:
		return
	time_accum += delta
	var progress = (sin((time_accum / cycle_duration) * TAU - (PI * 0.5)) + 1.0) * 0.5
	position = start_pos + move_offset * progress
