class_name Sfx
extends Node
## Every sound is synthesised at startup (no audio files): filtered noise and
## modal resonances for impacts, granular crackle for frying, chirped bubbles
## for boiling. 3D one-shots + loops run through a small-room reverb bus.

const RATE := 32000

var streams := {}
var _flat: Array = []
var _spatial: Array = []
var _rng := RandomNumberGenerator.new()
var _ambience: AudioStreamPlayer


func _ready() -> void:
	_rng.seed = 7
	_setup_buses()
	# impacts & handling
	streams["pop"] = _make(_thump(0.07, 160.0, 0.35), false)
	streams["place"] = _make(_modal([180.0, 410.0, 760.0], [0.04, 0.03, 0.02], 0.12, 0.5), false)
	streams["place_wood"] = _make(_modal([170.0, 390.0, 720.0, 1180.0], [0.05, 0.035, 0.025, 0.015], 0.15, 0.6), false)
	streams["place_metal"] = _make(_modal([820.0, 2170.0, 3900.0, 5600.0], [0.25, 0.18, 0.12, 0.08], 0.5, 0.12), false)
	streams["plate"] = _make(_modal([1850.0, 3320.0, 5180.0], [0.18, 0.12, 0.08], 0.35, 0.15), false)
	streams["chop"] = _make(_chop(), false)
	streams["whisk"] = _make(_whisk(), false)
	streams["splash"] = _make(_splash(), false)
	streams["sizzle_hit"] = _make(_crackle(0.7, 0.55, 900.0, true), false)
	streams["whoosh"] = _make(_whoosh(), false)
	streams["door_open"] = _make(_creak(0.35), false)
	streams["door_close"] = _make(_door_close(), false)
	streams["footstep"] = _make(_footstep(), false)
	# signals
	streams["bell"] = _make(_bell({1.0: 1.0, 2.32: 0.55, 4.25: 0.3, 6.63: 0.15}, 1900.0, 1.6), false)
	streams["ding"] = _make(_bell({1.0: 1.0, 2.76: 0.35, 5.4: 0.12}, 1480.0, 0.9), false)
	streams["beep"] = _make(_beep(), false)
	streams["click"] = _make(_click(), false)
	streams["sparkle"] = _make(_arp([1046.5, 1318.5, 1568.0, 2093.0], 0.07, 0.5), false)
	streams["fanfare"] = _make(_arp([523.3, 659.3, 784.0, 1046.5, 1318.5], 0.09, 0.9), false)
	streams["cash"] = _make(_cash(), false)
	streams["buzz"] = _make(_buzz(), false)
	# loops
	streams["sizzle"] = _make(_crackle(3.0, 0.32, 1100.0, false), true)
	streams["fryer"] = _make(_fryer(), true)
	streams["boil"] = _make(_boil(), true)
	streams["water"] = _make(_water(), true)
	streams["blender"] = _make(_blender(), true)
	streams["hum"] = _make(_hum(), true)
	streams["ambience"] = _make(_ambience_loop(), true)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "UI"
		add_child(p)
		_flat.append(p)
	for i in 12:
		var p := AudioStreamPlayer3D.new()
		p.bus = "World"
		p.unit_size = 4.0
		p.max_distance = 18.0
		p.attenuation_filter_cutoff_hz = 9000.0
		add_child(p)
		_spatial.append(p)
	_ambience = AudioStreamPlayer.new()
	_ambience.stream = streams["ambience"]
	_ambience.volume_db = -16.0
	_ambience.bus = "World"
	add_child(_ambience)
	_ambience.play()


func _setup_buses() -> void:
	if AudioServer.get_bus_index("World") >= 0:
		return
	AudioServer.add_bus()
	var w := AudioServer.bus_count - 1
	AudioServer.set_bus_name(w, "World")
	AudioServer.set_bus_send(w, "Master")
	var rev := AudioEffectReverb.new()
	rev.room_size = 0.28
	rev.damping = 0.55
	rev.spread = 0.8
	rev.wet = 0.14
	rev.dry = 1.0
	rev.predelay_msec = 12.0
	AudioServer.add_bus_effect(w, rev)
	AudioServer.add_bus()
	var u := AudioServer.bus_count - 1
	AudioServer.set_bus_name(u, "UI")
	AudioServer.set_bus_send(u, "Master")


## Non-positional (UI, jingles, things in your hands).
func play(n: String, vol := 0.0, pitch_var := 0.06) -> void:
	if not streams.has(n):
		return
	for p in _flat:
		var ap := p as AudioStreamPlayer
		if not ap.playing:
			ap.stream = streams[n]
			ap.volume_db = vol
			ap.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
			ap.play()
			return


## Positional one-shot in the world.
func play_at(n: String, pos: Vector3, vol := 0.0, pitch_var := 0.06) -> void:
	if not streams.has(n):
		return
	for p in _spatial:
		var ap := p as AudioStreamPlayer3D
		if not ap.playing:
			ap.stream = streams[n]
			ap.volume_db = vol
			ap.pitch_scale = 1.0 + _rng.randf_range(-pitch_var, pitch_var)
			ap.global_position = pos
			ap.play()
			return


## Looping 3D emitter for a station.
func loop_player(n: String, parent: Node3D, vol := -6.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = streams[n]
	p.volume_db = vol
	p.unit_size = 3.0
	p.max_distance = 14.0
	p.bus = "World"
	parent.add_child(p)
	return p


# ================================================================ DSP helpers

func _make(s: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var peak := 0.0
	for v in s:
		peak = maxf(peak, absf(v))
	var g := 0.9 / peak if peak > 0.9 else 1.0
	var b := PackedByteArray()
	b.resize(s.size() * 2)
	for i in s.size():
		b.encode_s16(i * 2, int(clampf(s[i] * g, -1.0, 1.0) * 32000.0))
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


## RBJ biquad, applied in place. kind: lp, hp, bp
func _biquad(a: PackedFloat32Array, kind: String, f: float, q := 0.707) -> void:
	var w0 := TAU * f / RATE
	var alpha := sin(w0) / (2.0 * q)
	var c := cos(w0)
	var b0 := 0.0
	var b1 := 0.0
	var b2 := 0.0
	match kind:
		"lp":
			b0 = (1.0 - c) / 2.0
			b1 = 1.0 - c
			b2 = b0
		"hp":
			b0 = (1.0 + c) / 2.0
			b1 = -(1.0 + c)
			b2 = b0
		"bp":
			b0 = alpha
			b1 = 0.0
			b2 = -alpha
	var a0 := 1.0 + alpha
	var a1 := -2.0 * c
	var a2 := 1.0 - alpha
	b0 /= a0
	b1 /= a0
	b2 /= a0
	a1 /= a0
	a2 /= a0
	var x1 := 0.0
	var x2 := 0.0
	var y1 := 0.0
	var y2 := 0.0
	for i in a.size():
		var x := a[i]
		var y := b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
		x2 = x1
		x1 = x
		y2 = y1
		y1 = y
		a[i] = y


func _noise(sec: float) -> PackedFloat32Array:
	var a := _buf(sec)
	for i in a.size():
		a[i] = _rng.randf_range(-1.0, 1.0)
	return a


func _seamless(a: PackedFloat32Array, fade_sec := 0.08) -> void:
	var fade := int(fade_sec * RATE)
	var n := a.size()
	for i in fade:
		var w := float(i) / fade
		a[i] = a[i] * w + a[n - fade + i] * (1.0 - w)
	a.resize(n - fade)


func _mix(dst: PackedFloat32Array, src: PackedFloat32Array, at: int, gain := 1.0) -> void:
	for i in src.size():
		var j := at + i
		if j >= dst.size():
			return
		dst[j] += src[i] * gain


# ================================================================ impacts

func _thump(sec: float, f: float, noise: float) -> PackedFloat32Array:
	var a := _buf(sec)
	var n := _noise(sec)
	_biquad(n, "lp", 1200.0)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		ph += TAU * f * (1.0 - t * 4.0) / RATE
		a[i] = (sin(ph) * 0.8 + n[i] * noise) * exp(-t * 45.0)
	return a


## Struck object: decaying partials + a short contact click.
func _modal(freqs: Array, decays: Array, sec: float, click: float) -> PackedFloat32Array:
	var a := _buf(sec)
	var n := _noise(0.01)
	_biquad(n, "hp", 2000.0)
	for i in a.size():
		var t := float(i) / RATE
		var v := 0.0
		for k in freqs.size():
			v += sin(TAU * float(freqs[k]) * t + k) * exp(-t / float(decays[k])) / (k + 1.0)
		a[i] = v * 0.6
	for i in n.size():
		a[i] += n[i] * click * (1.0 - float(i) / n.size())
	return a


func _chop() -> PackedFloat32Array:
	# blade slice (bright noise) then knife hitting the board (woody modes)
	var a := _modal([230.0, 560.0, 990.0, 1700.0], [0.035, 0.025, 0.018, 0.01], 0.18, 0.0)
	var s := _noise(0.05)
	_biquad(s, "bp", 5500.0, 0.8)
	for i in s.size():
		s[i] *= exp(-float(i) / RATE * 70.0) * 0.9
	var out := _buf(0.2)
	_mix(out, s, 0)
	_mix(out, a, int(0.012 * RATE), 1.2)
	return out


func _whisk() -> PackedFloat32Array:
	var a := _noise(0.22)
	_biquad(a, "bp", 4200.0, 1.2)
	var ting := _modal([3100.0, 4700.0], [0.05, 0.03], 0.22, 0.0)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = a[i] * sin(PI * t / 0.22) * 0.9 + ting[i] * 0.15
	return a


func _splash() -> PackedFloat32Array:
	var a := _noise(0.45)
	_biquad(a, "lp", 3000.0)
	for i in a.size():
		var t := float(i) / RATE
		a[i] *= exp(-t * 9.0) * 0.9
	for d in 10:
		var at := _rng.randi_range(int(0.03 * RATE), int(0.35 * RATE))
		var f := _rng.randf_range(900.0, 2400.0)
		var drop := _buf(0.03)
		for i in drop.size():
			var t := float(i) / RATE
			drop[i] = sin(TAU * f * (1.0 + t * 25.0) * t) * exp(-t * 120.0) * 0.25
		_mix(a, drop, at)
	return a


func _crackle(sec: float, density: float, centre: float, one_shot: bool) -> PackedFloat32Array:
	# hiss bed + thousands of tiny oil pops
	var a := _noise(sec)
	_biquad(a, "hp", 2500.0)
	_biquad(a, "lp", 9000.0)
	for i in a.size():
		a[i] *= 0.12
	var pops := int(sec * 900.0 * density)
	for k in pops:
		var at := _rng.randi_range(0, a.size() - 200)
		var amp := pow(_rng.randf(), 3.0) * 0.9
		var ln := _rng.randi_range(20, 120)
		for i in ln:
			a[at + i] += _rng.randf_range(-1, 1) * amp * exp(-float(i) / (ln * 0.25))
	_biquad(a, "hp", centre)
	if one_shot:
		for i in a.size():
			var t := float(i) / RATE
			a[i] *= minf(1.0, t * 60.0) * exp(-t * 3.5)
	else:
		_seamless(a)
	return a


func _whoosh() -> PackedFloat32Array:
	var a := _noise(0.4)
	var f := 300.0
	var out := _buf(0.4)
	var lp := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var env := sin(PI * t / 0.4)
		f = 300.0 + env * 2500.0
		var k := TAU * f / RATE
		lp += (a[i] - lp) * clampf(k, 0.0, 1.0)
		out[i] = lp * env * 1.2
	return out


func _creak(sec: float) -> PackedFloat32Array:
	var a := _buf(sec)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		var f := 90.0 + sin(t * 9.0) * 25.0 + t * 60.0
		ph += f / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		a[i] = saw * sin(PI * t / sec) * 0.35
	_biquad(a, "bp", 1400.0, 2.0)
	return a


func _door_close() -> PackedFloat32Array:
	var a := _modal([95.0, 240.0, 610.0, 1500.0], [0.08, 0.05, 0.03, 0.02], 0.35, 0.5)
	var rattle := _modal([2100.0, 3400.0], [0.06, 0.04], 0.35, 0.0)
	for i in a.size():
		a[i] = a[i] + rattle[i] * 0.3
	return a


func _footstep() -> PackedFloat32Array:
	var a := _noise(0.09)
	_biquad(a, "lp", 900.0)
	var heel := _modal([110.0, 260.0], [0.02, 0.015], 0.09, 0.0)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = a[i] * exp(-t * 55.0) * 0.6 + heel[i] * 0.8
	return a


# ================================================================ signals

func _bell(partials: Dictionary, f0: float, sec: float) -> PackedFloat32Array:
	var a := _buf(sec)
	for i in a.size():
		var t := float(i) / RATE
		var v := 0.0
		var k := 0
		for ratio in partials:
			var amp: float = partials[ratio]
			v += sin(TAU * f0 * float(ratio) * t) * amp * exp(-t * (2.2 + k * 2.5))
			k += 1
		a[i] = v * 0.45 * minf(1.0, t * 800.0)
	return a


func _beep() -> PackedFloat32Array:
	var a := _buf(0.09)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = (sin(TAU * 2000.0 * t) + 0.3 * sin(TAU * 4000.0 * t)) * 0.3 * minf(1.0, (0.09 - t) * 200.0) * minf(1.0, t * 400.0)
	return a


func _click() -> PackedFloat32Array:
	var a := _noise(0.02)
	_biquad(a, "bp", 3500.0, 1.5)
	for i in a.size():
		a[i] *= exp(-float(i) / RATE * 300.0) * 0.6
	return a


func _arp(fs: Array, step: float, tail: float) -> PackedFloat32Array:
	var a := _buf(step * fs.size() + tail)
	for i in a.size():
		var t := float(i) / RATE
		var v := 0.0
		for j in fs.size():
			var t0 := t - j * step
			if t0 >= 0.0:
				var f := float(fs[j])
				v += (sin(TAU * f * t0) + 0.25 * sin(TAU * f * 2.0 * t0) + 0.1 * sin(TAU * f * 3.0 * t0)) * exp(-t0 * 4.0) * minf(1.0, t0 * 300.0)
		a[i] = v * 0.16
	return a


func _cash() -> PackedFloat32Array:
	var out := _buf(0.9)
	_mix(out, _bell({1.0: 1.0, 2.4: 0.4, 3.9: 0.2}, 2600.0, 0.8), 0, 0.7)
	_mix(out, _bell({1.0: 1.0, 2.4: 0.4}, 3150.0, 0.7), int(0.08 * RATE), 0.6)
	var drawer := _noise(0.25)
	_biquad(drawer, "lp", 2500.0)
	for i in drawer.size():
		drawer[i] *= exp(-float(i) / RATE * 14.0) * 0.4
	_mix(out, drawer, int(0.15 * RATE))
	return out


func _buzz() -> PackedFloat32Array:
	var a := _buf(0.32)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = (sin(TAU * 196.0 * t) + sin(TAU * 207.7 * t)) * 0.22 * minf(1.0, (0.32 - t) * 30.0) * minf(1.0, t * 200.0)
	_biquad(a, "lp", 1500.0)
	return a


# ================================================================ loops

func _fryer() -> PackedFloat32Array:
	var a := _crackle(3.0, 0.9, 700.0, false)
	var bub := _boil_bubbles(a.size(), 60, 180.0, 420.0, 0.15)
	for i in a.size():
		a[i] += bub[i]
	return a


func _boil_bubbles(n: int, count: int, f_lo: float, f_hi: float, amp: float) -> PackedFloat32Array:
	var a := PackedFloat32Array()
	a.resize(n)
	for b in count:
		var at := _rng.randi_range(0, n - 1200)
		var f := _rng.randf_range(f_lo, f_hi)
		var ln := _rng.randi_range(500, 1100)
		var ph := 0.0
		var g := amp * _rng.randf_range(0.4, 1.0)
		for i in ln:
			var t := float(i) / RATE
			ph += TAU * f * (1.0 + t * 30.0) / RATE
			a[at + i] += sin(ph) * exp(-t * 70.0) * g
	return a


func _boil() -> PackedFloat32Array:
	var n := int(3.0 * RATE)
	var a := _noise(3.0)
	_biquad(a, "lp", 350.0)
	for i in n:
		a[i] *= 0.5
	var bub := _boil_bubbles(n, 140, 260.0, 900.0, 0.35)
	for i in n:
		a[i] += bub[i]
	_seamless(a)
	return a


func _water() -> PackedFloat32Array:
	var a := _noise(2.5)
	_biquad(a, "bp", 1800.0, 0.5)
	var ph := 0.0
	for i in a.size():
		var t := float(i) / RATE
		ph += (3.0 + sin(t * 1.3) * 1.5) / RATE
		a[i] *= 0.6 + 0.4 * sin(TAU * ph) * sin(TAU * ph * 0.37)
	var splats := _buf(2.5)
	for k in 160:
		var at := _rng.randi_range(0, splats.size() - 400)
		var f := _rng.randf_range(1200.0, 3500.0)
		for i in 300:
			var t := float(i) / RATE
			splats[at + i] += sin(TAU * f * t) * exp(-t * 300.0) * 0.12
	for i in a.size():
		a[i] += splats[i]
	_seamless(a)
	return a


func _blender() -> PackedFloat32Array:
	var a := _buf(2.0)
	var ph := 0.0
	var n := _noise(2.0)
	_biquad(n, "bp", 2500.0, 0.7)
	for i in a.size():
		var t := float(i) / RATE
		var f := 118.0 + sin(t * 5.0) * 2.0
		ph += f / RATE
		var saw := fmod(ph, 1.0) * 2.0 - 1.0
		var rattle := n[i] * (0.5 + 0.5 * sin(TAU * ph))
		a[i] = saw * 0.25 + rattle * 0.5 + sin(TAU * f * 15.0 * t) * 0.05
	_biquad(a, "lp", 6000.0)
	_seamless(a)
	return a


func _hum() -> PackedFloat32Array:
	var a := _noise(2.0)
	_biquad(a, "bp", 400.0, 0.6)
	for i in a.size():
		var t := float(i) / RATE
		a[i] = a[i] * 0.25 + sin(TAU * 100.0 * t) * 0.12 + sin(TAU * 50.0 * t) * 0.1
	_seamless(a)
	return a


func _ambience_loop() -> PackedFloat32Array:
	# room tone + distant traffic + the odd bird through the window
	var sec := 9.0
	var a := _noise(sec)
	_biquad(a, "lp", 220.0)
	for i in a.size():
		a[i] *= 0.5
	for b in 7:
		var at := _rng.randi_range(0, a.size() - int(0.6 * RATE))
		var f0 := _rng.randf_range(2800.0, 4200.0)
		var notes := _rng.randi_range(2, 5)
		for k in notes:
			var start := at + int(k * 0.11 * RATE)
			var chirp := _buf(0.08)
			for i in chirp.size():
				var t := float(i) / RATE
				chirp[i] = sin(TAU * (f0 + sin(t * 60.0) * 400.0 - t * 3000.0) * t) * sin(PI * t / 0.08) * 0.08
			_mix(a, chirp, start)
	_seamless(a, 0.5)
	return a
