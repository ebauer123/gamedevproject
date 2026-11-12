extends Node

# Procedural Sound Effect Generator and Player
# Generates 16-bit PCM synthesized sound effects at runtime with zero external dependencies.

var players: Array[AudioStreamPlayer] = []
const POOL_SIZE: int = 8
var sounds: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	
	_generate_all_sounds()

func _generate_all_sounds() -> void:
	sounds["jump"] = _create_jump_sfx()
	sounds["double_jump"] = _create_double_jump_sfx()
	sounds["land"] = _create_land_sfx()
	sounds["wall_jump"] = _create_wall_jump_sfx()
	sounds["slide"] = _create_slide_sfx()
	sounds["checkpoint"] = _create_checkpoint_sfx()
	sounds["coin"] = _create_coin_sfx()
	sounds["boost"] = _create_boost_sfx()
	sounds["crumble"] = _create_crumble_sfx()
	sounds["respawn"] = _create_respawn_sfx()
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
	# If all busy, reuse the first
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

func _create_jump_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.14
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / count
		var freq = lerpf(220.0, 580.0, t)
		phase += (freq * TAU) / rate
		var env = (1.0 - t) * minf(t * 20.0, 1.0)
		# Square / Triangle blend for punchy retro synth jump
		var wave = sin(phase) * 0.7 + (1.0 if sin(phase) > 0.0 else -1.0) * 0.3
		samples[i] = wave * env * 0.45
	return _build_wav(samples, rate)

func _create_double_jump_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.16
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / count
		var freq = lerpf(380.0, 880.0, pow(t, 0.7))
		phase += (freq * TAU) / rate
		var env = (1.0 - t) * minf(t * 30.0, 1.0)
		var wave = sin(phase) + 0.3 * sin(phase * 2.0)
		samples[i] = wave * env * 0.4
	return _build_wav(samples, rate)

func _create_land_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.12
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / count
		var freq = lerpf(140.0, 45.0, t)
		phase += (freq * TAU) / rate
		var env = pow(1.0 - t, 2.0)
		var noise = (randf() * 2.0 - 1.0) * 0.4
		var wave = sin(phase) * 0.7 + noise
		samples[i] = wave * env * 0.5
	return _build_wav(samples, rate)

func _create_wall_jump_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.13
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / count
		var freq = lerpf(300.0, 650.0, t)
		phase += (freq * TAU) / rate
		var env = pow(1.0 - t, 1.5)
		var wave = sin(phase) + (randf() * 2.0 - 1.0) * 0.2
		samples[i] = wave * env * 0.45
	return _build_wav(samples, rate)

func _create_slide_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.28
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var last = 0.0
	for i in range(count):
		var t = float(i) / count
		var env = sin(t * PI)
		# Low pass noise
		var white = randf() * 2.0 - 1.0
		last = lerpf(last, white, 0.18)
		samples[i] = last * env * 0.35
	return _build_wav(samples, rate)

func _create_checkpoint_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.45
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	# 3 note arpeggio: C5, E5, G5
	var notes = [523.25, 659.25, 783.99, 1046.50]
	var seg_len = count / notes.size()
	var phase = 0.0
	for i in range(count):
		var note_idx = mini(i / seg_len, notes.size() - 1)
		var freq = notes[note_idx]
		phase += (freq * TAU) / rate
		var local_t = float(i % seg_len) / seg_len
		var env = (1.0 - local_t * 0.6) * minf(local_t * 20.0, 1.0)
		var wave = sin(phase) + 0.25 * sin(phase * 2.0)
		samples[i] = wave * env * 0.4
	return _build_wav(samples, rate)

func _create_coin_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.22
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / count
		var freq = 987.77 if t < 0.4 else 1318.51 # B5 then E6
		phase += (freq * TAU) / rate
		var env = pow(1.0 - t, 1.3)
		var wave = sin(phase) + 0.2 * sin(phase * 3.0)
		samples[i] = wave * env * 0.45
	return _build_wav(samples, rate)

func _create_boost_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.30
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / count
		var freq = lerpf(180.0, 950.0, pow(t, 1.4))
		phase += (freq * TAU) / rate
		var env = sin(t * PI)
		var wave = sin(phase) * 0.8 + (randf() * 2.0 - 1.0) * 0.2
		samples[i] = wave * env * 0.45
	return _build_wav(samples, rate)

func _create_crumble_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.25
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / count
		var freq = lerpf(200.0, 60.0, t)
		phase += (freq * TAU) / rate
		var env = pow(1.0 - t, 0.8)
		var noise = (randf() * 2.0 - 1.0) * 0.6
		var wave = sin(phase) * 0.4 + noise
		samples[i] = wave * env * 0.4
	return _build_wav(samples, rate)

func _create_respawn_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 0.35
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var phase = 0.0
	for i in range(count):
		var t = float(i) / count
		var freq = lerpf(150.0, 440.0, t)
		phase += (freq * TAU) / rate
		var env = (1.0 - t)
		var wave = sin(phase) * 0.8
		samples[i] = wave * env * 0.4
	return _build_wav(samples, rate)

func _create_victory_sfx() -> AudioStreamWAV:
	var rate = 22050
	var duration = 1.1
	var count = int(rate * duration)
	var samples = PackedFloat32Array()
	samples.resize(count)
	var notes = [523.25, 659.25, 783.99, 1046.50, 1318.51] # C5, E5, G5, C6, E6
	var seg_len = count / notes.size()
	var phase = 0.0
	for i in range(count):
		var note_idx = mini(i / seg_len, notes.size() - 1)
		var freq = notes[note_idx]
		phase += (freq * TAU) / rate
		var local_t = float(i % seg_len) / seg_len
		var env = (1.0 - local_t * 0.3)
		var wave = sin(phase) + 0.3 * sin(phase * 2.0) + 0.15 * sin(phase * 3.0)
		samples[i] = wave * env * 0.4
	return _build_wav(samples, rate)
