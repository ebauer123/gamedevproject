extends Node

# Procedural Sound Effect Generator and Player (Mirror's Edge / Grounded Parkour Style)
# Synthesizes realistic grounded parkour sounds: footsteps, cloth whooshes, rolls, mantles, grunts, and wind.

var players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 10
var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	
	_generate_all_sounds()

func _generate_all_sounds() -> void:
	sounds["step"] = _create_step_sfx()
	sounds["jump"] = _create_jump_sfx()
	sounds["land_soft"] = _create_land_soft_sfx()
	sounds["land_hard"] = _create_land_hard_sfx()
	sounds["roll"] = _create_roll_sfx()
	sounds["grab"] = _create_grab_sfx()
	sounds["mantle"] = _create_mantle_sfx()
	sounds["wall_hit"] = _create_wall_hit_sfx()
	sounds["slide"] = _create_slide_sfx()
	sounds["springboard"] = _create_springboard_sfx()
	sounds["checkpoint"] = _create_checkpoint_sfx()
	sounds["victory"] = _create_victory_sfx()

func play(sound_name: String, pitch_scale: float = 1.0, volume_db: float = 0.0) -> void:
	if not sounds.has(sound_name):
		return
	for p in players:
		if not p.playing:
			p.stream = sounds[sound_name]
			p.pitch_scale = pitch_scale
			p.volume_db = volume_db
			p.play()
			return
	var p = players[0]
	p.stream = sounds[sound_name]
	p.pitch_scale = pitch_scale
	p.volume_db = volume_db
	p.play()

func _build_wav(samples: PackedFloat32Array, rate: int = 22050) -> AudioStreamWAV:
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	
	var data = PackedByteArray()
	data.resize(samples.size() * 2)
	var idx = 0
	for s in samples:
		var clamped = clampf(s, -1.0, 1.0)
		var val = int(clamped * 32767.0)
		if val < 0:
			val += 65536
		data[idx] = val & 0xFF
		data[idx + 1] = (val >> 8) & 0xFF
		idx += 2
	wav.data = data
	return wav

# Footstep on rooftop concrete / metal
func _create_step_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.08
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var env = pow(1.0 - t, 3.0)
		var noise = randf() * 2.0 - 1.0
		var thump = sin(t * TAU * 110.0) * 0.6
		samples[i] = (noise * 0.4 + thump) * env * 0.35
	return _build_wav(samples, rate)

# Leg push jump take-off
func _create_jump_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.12
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var env = sin(t * PI)
		var whoosh = (randf() * 2.0 - 1.0) * 0.3 + sin(t * TAU * 140.0) * 0.7
		samples[i] = whoosh * env * 0.4
	return _build_wav(samples, rate)

# Soft landing
func _create_land_soft_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.14
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var env = pow(1.0 - t, 2.5)
		var low = sin(t * TAU * 80.0) * 0.8
		var grit = (randf() * 2.0 - 1.0) * 0.3
		samples[i] = (low + grit) * env * 0.5
	return _build_wav(samples, rate)

# Hard landing stun / slam
func _create_land_hard_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.28
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var env = pow(1.0 - t, 1.8)
		var impact = sin(t * TAU * 60.0) * 0.9 + sin(t * TAU * 120.0) * 0.4
		var crunch = (randf() * 2.0 - 1.0) * 0.5
		samples[i] = (impact + crunch) * env * 0.65
	return _build_wav(samples, rate)

# Smooth parkour roll whoosh
func _create_roll_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.45
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var filter = 0.0
	for i in range(count):
		var t = float(i) / count
		var env = sin(t * PI)
		var noise = randf() * 2.0 - 1.0
		filter = lerpf(filter, noise, 0.15)
		var body_sweep = sin(pow(t, 0.8) * TAU * 95.0) * 0.5
		samples[i] = (filter * 0.6 + body_sweep) * env * 0.45
	return _build_wav(samples, rate)

# Hand slapping a ledge to hang
func _create_grab_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.15
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var env = pow(1.0 - t, 2.0)
		var slap = (randf() * 2.0 - 1.0) * 0.6 + sin(t * TAU * 160.0) * 0.5
		samples[i] = slap * env * 0.55
	return _build_wav(samples, rate)

# Pulling up / mantling over a wall
func _create_mantle_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.25
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var env = sin(t * PI)
		var effort = (randf() * 2.0 - 1.0) * 0.35 + sin(t * TAU * 100.0) * 0.5
		samples[i] = effort * env * 0.4
	return _build_wav(samples, rate)

# Kicking off a wall (wallrun kick or tic-tac climb)
func _create_wall_hit_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.12
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var env = pow(1.0 - t, 2.5)
		var impact = sin(t * TAU * 130.0) * 0.7 + (randf() * 2.0 - 1.0) * 0.4
		samples[i] = impact * env * 0.5
	return _build_wav(samples, rate)

# Sliding on concrete / rooftop gravel
func _create_slide_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.35
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var f = 0.0
	for i in range(count):
		var t = float(i) / count
		var env = sin(t * PI)
		var n = randf() * 2.0 - 1.0
		f = lerpf(f, n, 0.22)
		samples[i] = f * env * 0.4
	return _build_wav(samples, rate)

# Springboard off an AC unit or vault box
func _create_springboard_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.16
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var env = pow(1.0 - t, 2.0)
		var metal = sin(t * TAU * 280.0) * 0.6 + sin(t * TAU * 140.0) * 0.5
		samples[i] = metal * env * 0.5
	return _build_wav(samples, rate)

# Clean, subtle checkpoint chime
func _create_checkpoint_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.35
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var env = pow(1.0 - t, 1.5)
		var wave = sin(t * TAU * 880.0) * 0.5 + sin(t * TAU * 1320.0) * 0.3
		samples[i] = wave * env * 0.35
	return _build_wav(samples, rate)

# Victory chime
func _create_victory_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.9
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	for i in range(count):
		var t = float(i) / count
		var freq = 659.25 if t < 0.25 else (880.0 if t < 0.5 else 1318.51)
		var env = (1.0 - t * 0.5) * 0.4
		samples[i] = sin(t * TAU * freq) * env
	return _build_wav(samples, rate)
