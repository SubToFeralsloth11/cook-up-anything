class_name Sfx
extends Node
## Synthesises every sound at startup (no audio files needed).

const RATE := 22050

var streams := {}
var _pool: Array = []
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.seed = 7
	streams["pop"] = _make(_pop(), false)
	streams["place"] = _make(_thud(0.09, 140.0), false)
	streams["chop"] = _make(_chop(), false)
	streams["ding"] = _make(_bell([1320.0, 2640.0, 3960.0], 1.0), false)
	streams["bell"] = _make(_bell([1760.0, 3520.0, 2200.0], 1.4), false)
	streams["sparkle"] = _make(_arp([784.0, 988.0, 1175.0, 1568.0], 0.08), false)
	streams["fanfare"] = _make(_arp([523.0, 659.0, 784.0, 1047.0, 1319.0], 0.1), false)
	streams["buzz"] = _make(_buzz(), false)
	streams["beep"] = _make(_tone(1040.0, 0.08, true), false)
	streams["whoosh"] = _make(_whoosh(), false)
	streams["cash"] = _make(_cash(), false)
	streams["splash"] = _make(_splash(), false)
	streams["click"] = _make(_tone(1800.0, 0.025, false), false)
	streams["whisk"] = _make(_whisk(), false)
	streams["sizzle"] = _make(_noise_loop(1.2, 0.32, 0.55, true), true)
	streams["fryer"] = _make(_noise_loop(1.2, 0.4, 0.75, true), true)
	streams["boil"] = _make(_boil(), true)
	streams["water"] = _make(_noise_loop(1.0, 0.25, 0.12, false), true)
	streams["blender"] = _make(_blender(), true)
	streams["hum"] = _make(_hum(), true)
	for i in 10:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_pool.append(p)


func play(n: String, vol := 0.0, pitch_var := 0.08) -> void:
	if not streams.has(n):
		return
	for p in _pool:
		var ap := p as AudioStreamPlayer
		if not ap.playing:
			ap.stream = streams[n]
			ap.volume_db = vol
			ap.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
			ap.play()
			return


## Looping 3D emitter for a station.
func loop_player(n: String, parent: Node3D, vol := -6.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[n]
	p.volume_db = vol
	p.unit_size = 3.0
	p.max_distance = 14.0
	parent.add_child(p)
	return p


# ------------------------------------------------------------------ synthesis

func _make(s: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var b := PackedByteArray()
	b.resize(s.size() * 2)
	for i in s.size():
		b.encode_s16(i * 2, int(clampf(s[i], -1.0, 1.0) * 30000.0))
	w.data = b
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = s.size()
	return w


func _buf(sec: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(int(sec * RATE))
	return a


func _pop() -> PackedFloat32Array:
	var a := _buf(0.09)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		ph += TAU * (300.0 + t * 9000.0) / RATE
		a[i] = sin(ph) * exp(-t * 40.0) * 0.6
	return a


func _thud(sec: float, f: float) -> PackedFloat32Array:
	var a := _buf(sec)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		ph += TAU * f * (1.0 - t * 3.0) / RATE
		a[i] = (sin(ph) * 0.7 + _rng.randf_range(-1, 1) * 0.15) * exp(-t * 35.0)
	return a


func _chop() -> PackedFloat32Array:
	var a := _buf(0.12)
	var lp := 0.0
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := _rng.randf_range(-1, 1)
		lp += (n - lp) * 0.6
		ph += TAU * 180.0 / RATE
		a[i] = (lp * exp(-t * 60.0) * 0.8 + sin(ph) * exp(-t * 30.0) * 0.6)
	return a


func _bell(fs: Array, sec: float) -> PackedFloat32Array:
	var a := _buf(sec)
	for i in a.size():
		var t := float(i) / RATE
		var v := 0.0
		for j in fs.size():
			v += sin(TAU * float(fs[j]) * t) * exp(-t * (3.0 + j * 2.0)) / (j + 1.0)
		a[i] = v * 0.4
	return a


func _arp(fs: Array, step: float) -> PackedFloat32Array:
	var a := _buf(step * fs.size() + 0.4)
	for i in a.size():
		var t := float(i) / RATE
		var v := 0.0
		for j in fs.size():
			var t0 := t - j * step
			if t0 >= 0.0:
				v += (sin(TAU * float(fs[j]) * t0) + 0.3 * sin(TAU * float(fs[j]) * 2.0 * t0)) * exp(-t0 * 7.0)
		a[i] = v * 0.22
	return a


func _buzz() -> PackedFloat32Array:
	var a := _buf(0.35)
	for i in a.size():
		var t := float(i) / RATE
		var sq := 1.0 if fmod(t * 110.0, 1.0) < 0.5 else -1.0
		a[i] = sq * 0.25 * minf(1.0, (0.35 - t) * 20.0)
	return a


func _tone(f: float, sec: float, square: bool) -> PackedFloat32Array:
	var a := _buf(sec)
	for i in a.size():
		var t := float(i) / RATE
		var v := sin(TAU * f * t)
		if square:
			v = signf(v) * 0.6
		a[i] = v * 0.3 * minf(1.0, (sec - t) * 60.0)
	return a


func _whoosh() -> PackedFloat32Array:
	var a := _buf(0.35)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var env := sin(PI * t / 0.35)
		lp += (_rng.randf_range(-1, 1) - lp) * (0.05 + env * 0.25)
		a[i] = lp * env * 1.4
	return a


func _cash() -> PackedFloat32Array:
	var a := _buf(0.7)
	for i in a.size():
		var t := float(i) / RATE
		var v := sin(TAU * 2093.0 * t) * exp(-t * 9.0)
		if t > 0.09:
			var t2 := t - 0.09
			v += sin(TAU * 2637.0 * t2) * exp(-t2 * 6.0) + 0.5 * sin(TAU * 3136.0 * t2) * exp(-t2 * 8.0)
		a[i] = v * 0.3
	return a


func _splash() -> PackedFloat32Array:
	var a := _buf(0.3)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		lp += (_rng.randf_range(-1, 1) - lp) * 0.3
		a[i] = lp * exp(-t * 12.0) * 0.9
	return a


func _whisk() -> PackedFloat32Array:
	var a := _buf(0.18)
	var hp := 0.0
	var prev := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var n := _rng.randf_range(-1, 1)
		hp = n - prev
		prev = n
		a[i] = hp * sin(PI * t / 0.18) * 0.35
	return a


func _noise_loop(sec: float, amp: float, bright: float, crackle: bool) -> PackedFloat32Array:
	var a := _buf(sec)
	var lp := 0.0
	for i in a.size():
		var n := _rng.randf_range(-1, 1)
		lp += (n - lp) * bright
		var v := lp * amp
		if crackle and _rng.randf() < 0.004:
			v += _rng.randf_range(-0.8, 0.8)
		a[i] = v
	# crossfade the ends so the loop is seamless
	var fade := int(0.05 * RATE)
	for i in fade:
		var w := float(i) / fade
		a[i] = a[i] * w + a[a.size() - fade + i] * (1.0 - w)
	return a


func _boil() -> PackedFloat32Array:
	var a := _buf(1.5)
	var lp := 0.0
	for i in a.size():
		lp += (_rng.randf_range(-1, 1) - lp) * 0.08
		a[i] = lp * 0.25
	for b in 26:
		var start := _rng.randi_range(0, a.size() - 3000)
		var f := _rng.randf_range(250.0, 700.0)
		var ph := 0.0
		for j in 2500:
			var t := float(j) / RATE
			ph += TAU * f * (1.0 + t * 12.0) / RATE
			a[start + j] += sin(ph) * exp(-t * 60.0) * 0.25
	return a


func _blender() -> PackedFloat32Array:
	var a := _buf(1.0)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var saw := fmod(t * 170.0, 1.0) * 2.0 - 1.0
		lp += (_rng.randf_range(-1, 1) - lp) * 0.4
		a[i] = saw * 0.18 + lp * 0.18 + sin(TAU * 340.0 * t) * 0.08
	return a


func _hum() -> PackedFloat32Array:
	var a := _buf(1.0)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = sin(TAU * 60.0 * t) * 0.15 + sin(TAU * 120.0 * t) * 0.06
	return a
