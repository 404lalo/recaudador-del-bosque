extends Node
## Autoload "Sfx": todo el audio se sintetiza por código (no hacen falta archivos de sonido).
## Sfx.play("coin"), Sfx.music("forest" | "desert" | "menu"), Sfx.stop_music().

const RATE := 22050
const POOL_SIZE := 10

var sounds := {}
var tracks := {}
var pool: Array[AudioStreamPlayer] = []
var pool_i := 0
var music_player: AudioStreamPlayer
var ambience_player: AudioStreamPlayer
var current_track := ""
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -10.0
	add_child(music_player)
	ambience_player = AudioStreamPlayer.new()
	ambience_player.volume_db = -22.0
	add_child(ambience_player)
	_build_sounds()
	# Cualquier botón de la interfaz hace "click" automáticamente.
	get_tree().node_added.connect(_on_node_added)


func _on_node_added(n: Node) -> void:
	if n is Button:
		(n as Button).pressed.connect(play.bind("click"))
		(n as Button).mouse_entered.connect(play.bind("hover", 1.0, -14.0))


func play(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not sounds.has(sound):
		return
	var p := pool[pool_i]
	pool_i = (pool_i + 1) % POOL_SIZE
	p.stream = sounds[sound]
	p.pitch_scale = pitch
	p.volume_db = volume_db
	p.play()


func play_varied(sound: String, volume_db := 0.0) -> void:
	play(sound, rng.randf_range(0.88, 1.12), volume_db)


## Cambia la música (con un pequeño fundido). Si ya suena esa pista no hace nada.
func music(track: String) -> void:
	if track == current_track and music_player.playing:
		return
	current_track = track
	if not tracks.has(track):
		tracks[track] = _build_track(track)
	music_player.stream = tracks[track]
	music_player.volume_db = -40.0
	music_player.play()
	create_tween().tween_property(music_player, "volume_db", -11.0, 1.5)
	if track != "menu":
		if not tracks.has("wind"):
			tracks["wind"] = _build_wind()
		ambience_player.stream = tracks["wind"]
		ambience_player.play()
	else:
		ambience_player.stop()


func stop_music() -> void:
	current_track = ""
	music_player.stop()
	ambience_player.stop()


# ------------------------------------------------------------ síntesis básica

## Genera una nota/barrido. wave: 0 seno, 1 cuadrada, 2 triángulo, 3 ruido, 4 sierra.
func _tone(f0: float, f1: float, dur: float, vol := 0.3, wave := 0, attack := 0.005, release_pow := 2.0) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var lp := 0.0
	for i in n:
		var t := float(i) / n
		var f := lerpf(f0, f1, t)
		phase += f / RATE
		var ph := fposmod(phase, 1.0)
		var s := 0.0
		match wave:
			0: s = sin(ph * TAU)
			1: s = 1.0 if ph < 0.5 else -1.0
			2: s = 4.0 * absf(ph - 0.5) - 1.0
			3:
				lp = lerpf(lp, rng.randf_range(-1.0, 1.0), clampf(f / 4000.0, 0.02, 1.0))
				s = lp
			4: s = ph * 2.0 - 1.0
		var env := pow(1.0 - t, release_pow)
		var t_s := float(i) / RATE
		if t_s < attack:
			env *= t_s / attack
		out[i] = s * env * vol
	return out


func _concat(parts: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for p in parts:
		out.append_array(p)
	return out


## Suma b dentro de a empezando en la posición de tiempo "at" (segundos).
func _mix_into(a: PackedFloat32Array, b: PackedFloat32Array, at: float) -> void:
	var start := int(at * RATE)
	for i in b.size():
		if start + i >= a.size():
			break
		a[start + i] += b[i]


func _stream(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in samples.size():
		bytes.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _build_sounds() -> void:
	sounds["jump"] = _stream(_tone(260, 560, 0.16, 0.22, 1, 0.003, 1.5))
	sounds["djump"] = _stream(_tone(420, 900, 0.18, 0.2, 2, 0.003, 1.5))
	sounds["land"] = _stream(_tone(160, 80, 0.09, 0.5, 3, 0.002, 1.5))
	sounds["step"] = _stream(_tone(260, 160, 0.05, 0.35, 3, 0.002, 1.5))
	sounds["coin"] = _stream(_concat([
		_tone(988, 988, 0.06, 0.2, 1, 0.002, 0.6),
		_tone(1319, 1319, 0.22, 0.2, 1, 0.002, 1.6)]))
	sounds["bigcoin"] = _stream(_concat([
		_tone(523, 523, 0.08, 0.22, 1, 0.002, 0.5), _tone(659, 659, 0.08, 0.22, 1, 0.002, 0.5),
		_tone(784, 784, 0.08, 0.22, 1, 0.002, 0.5), _tone(1047, 1047, 0.35, 0.22, 1, 0.002, 1.6)]))
	sounds["click"] = _stream(_tone(700, 520, 0.05, 0.25, 1, 0.001, 1.5))
	sounds["hover"] = _stream(_tone(900, 900, 0.03, 0.15, 0, 0.001, 1.0))
	sounds["blip"] = _stream(_tone(520, 560, 0.04, 0.2, 2, 0.001, 1.0))
	sounds["good"] = _stream(_concat([
		_tone(523, 523, 0.1, 0.22, 2, 0.003, 0.8), _tone(659, 659, 0.1, 0.22, 2, 0.003, 0.8),
		_tone(784, 784, 0.1, 0.22, 2, 0.003, 0.8), _tone(1047, 1047, 0.4, 0.25, 2, 0.003, 1.8)]))
	sounds["bad"] = _stream(_concat([
		_tone(330, 300, 0.15, 0.25, 4, 0.003, 0.8), _tone(250, 150, 0.4, 0.25, 4, 0.003, 1.5)]))
	sounds["growl"] = _stream(_growl())
	sounds["alarm"] = _stream(_concat([
		_tone(660, 660, 0.12, 0.2, 1, 0.003, 0.5), _tone(440, 440, 0.12, 0.2, 1, 0.003, 0.5),
		_tone(660, 660, 0.12, 0.2, 1, 0.003, 0.5), _tone(440, 440, 0.2, 0.2, 1, 0.003, 1.2)]))
	sounds["win"] = _stream(_fanfare())
	sounds["shop"] = _stream(_concat([
		_tone(784, 784, 0.1, 0.2, 2, 0.003, 0.7), _tone(988, 988, 0.1, 0.2, 2, 0.003, 0.7),
		_tone(1175, 1175, 0.3, 0.22, 2, 0.003, 1.6)]))


func _growl() -> PackedFloat32Array:
	var a := _tone(95, 55, 0.7, 0.35, 4, 0.02, 1.0)
	var b := _tone(70, 40, 0.7, 0.3, 1, 0.02, 1.0)
	var c := _tone(300, 120, 0.7, 0.25, 3, 0.02, 1.0)
	for i in a.size():
		var wob := 0.65 + 0.35 * sin(i / float(RATE) * TAU * 22.0)
		a[i] = (a[i] + b[i] + c[i]) * wob
	return a


func _fanfare() -> PackedFloat32Array:
	var notes := [523.0, 659.0, 784.0, 659.0, 784.0, 1047.0]
	var lens := [0.14, 0.14, 0.14, 0.14, 0.14, 0.7]
	var parts := []
	for i in notes.size():
		parts.append(_tone(notes[i], notes[i], lens[i], 0.22, 2, 0.003, 0.9))
	return _concat(parts)


# --------------------------------------------------------------------- música

func _build_wind() -> AudioStreamWAV:
	var n := RATE * 6
	var out := PackedFloat32Array()
	out.resize(n)
	var lp := 0.0
	for i in n:
		lp = lerpf(lp, rng.randf_range(-1.0, 1.0), 0.04)
		var swell := 0.55 + 0.45 * sin(float(i) / n * TAU)  # empalma sin corte al repetir
		out[i] = lp * swell * 0.9
	return _stream(out, true)


## Pistas: cada una es un bucle de 8 compases (4/4) con melodía, bajo y arpegio.
func _build_track(track: String) -> AudioStreamWAV:
	var bpm := 96.0
	var root := 57.0  # A3
	var scale: Array = [0, 3, 5, 7, 10]  # pentatónica menor
	var chords: Array = [[0, 7, 12], [8, 15, 12], [3, 10, 15], [5, 12, 17]]
	var melody_wave := 2
	match track:
		"forest":
			bpm = 92.0
			root = 55.0  # G3
			scale = [0, 2, 4, 7, 9]  # pentatónica mayor, alegre
			chords = [[0, 7, 12], [5, 12, 16], [7, 14, 19], [0, 7, 12]]
		"desert":
			bpm = 84.0
			root = 50.0  # D3
			scale = [0, 1, 4, 5, 7, 8]  # frigio, aire árabe
			chords = [[0, 7, 12], [1, 8, 13], [0, 7, 12], [-2, 5, 10]]
			melody_wave = 1
		"menu":
			bpm = 76.0
			root = 52.0  # E3
			scale = [0, 2, 4, 7, 9]
			chords = [[0, 7, 12], [9, 16, 12], [5, 12, 16], [7, 14, 11]]
	var beat := 60.0 / bpm
	var bars := 8
	var total := beat * 4.0 * bars
	var buf := PackedFloat32Array()
	buf.resize(int(total * RATE))
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = hash(track)
	var last_idx := 2
	for bar in bars:
		var chord: Array = chords[(bar / 2) % chords.size()]
		var t0 := bar * beat * 4.0
		# Bajo: raíz del acorde, una nota por tiempo fuerte.
		for b in [0, 2]:
			var bf := _hz(root - 12 + chord[0])
			_mix_into(buf, _tone(bf, bf, beat * 1.8, 0.28, 2, 0.01, 1.2), t0 + b * beat)
		# Arpegio suave con las notas del acorde, corcheas.
		for e in 8:
			var af := _hz(root + 12 + chord[e % 3])
			_mix_into(buf, _tone(af, af, beat * 0.5, 0.07, 0, 0.005, 1.5), t0 + e * beat * 0.5)
		# Melodía: caminata aleatoria (con semilla fija) sobre la escala.
		var t := 0.0
		while t < 4.0:
			var step := seed_rng.randi_range(-2, 2)
			last_idx = clampi(last_idx + step, 0, scale.size() * 2 - 1)
			var deg: int = scale[last_idx % scale.size()] + 12 * (last_idx / scale.size())
			var length: float = [0.5, 1.0, 1.0, 1.5][seed_rng.randi() % 4]
			length = minf(length, 4.0 - t)
			if seed_rng.randf() > 0.2:  # silencios ocasionales
				var mf := _hz(root + 12 + deg)
				_mix_into(buf, _tone(mf, mf, beat * length, 0.13, melody_wave, 0.01, 1.4), t0 + t * beat)
			t += length
	return _stream(buf, true)


func _hz(midi: float) -> float:
	return 440.0 * pow(2.0, (midi - 69.0) / 12.0)
