class_name Tex
extends RefCounted
## Procedural PBR materials for the kitchen (generated once, cached, shared).
## All use world-space triplanar mapping so scaled primitives keep a constant
## texel density and merged meshes stay seamless.

const SIZE := 256

static var _mats := {}
static var _imgs := {}


static func mat(n: String) -> StandardMaterial3D:
	if _mats.has(n):
		return _mats[n]
	var m := StandardMaterial3D.new()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	match n:
		"oak":
			_tex(m, _wood(Color(0.66, 0.47, 0.3), Color(0.47, 0.31, 0.18), 7.0, 11), 1.6)
			m.roughness = 0.55
		"oak_light":
			_tex(m, _wood(Color(0.82, 0.66, 0.46), Color(0.66, 0.5, 0.33), 6.0, 12), 1.6)
			m.roughness = 0.6
		"butcher":
			_tex(m, _butcher(), 2.2)
			m.roughness = 0.5
		"crate":
			_tex(m, _wood(Color(0.78, 0.63, 0.42), Color(0.6, 0.45, 0.28), 4.0, 13), 2.5)
			m.roughness = 0.85
		"walnut":
			_tex(m, _wood(Color(0.42, 0.28, 0.18), Color(0.27, 0.17, 0.1), 8.0, 14), 1.6)
			m.roughness = 0.45
		"marble":
			_tex(m, _marble(), 0.9)
			m.roughness = 0.12
			m.metallic_specular = 0.7
		"steel":
			_tex(m, _brushed(Color(0.86, 0.87, 0.89)), 7.0)
			m.metallic = 0.7
			m.roughness = 0.34
			m.normal_scale = 0.35
		"steel_dark":
			_tex(m, _brushed(Color(0.42, 0.43, 0.45)), 7.0)
			m.metallic = 0.6
			m.roughness = 0.4
			m.normal_scale = 0.35
		"cast_iron":
			_tex(m, _speckle(Color(0.13, 0.13, 0.14), 0.05, 21), 6.0)
			m.metallic = 0.55
			m.roughness = 0.55
		"tile":
			_tex(m, _subway(), 1.0 / 0.6)
			m.roughness = 0.08
			m.metallic_specular = 0.8
		"floor":
			_tex(m, _stone_tiles(), 1.0 / 1.2)
			m.roughness = 0.45
		"plaster":
			_tex(m, _speckle(Color(0.93, 0.91, 0.87), 0.025, 31), 1.2)
			m.roughness = 0.92
		"ceiling":
			_tex(m, _speckle(Color(0.96, 0.95, 0.93), 0.02, 33), 1.0)
			m.roughness = 0.95
		"cabinet":
			_tex(m, _speckle(Color(0.42, 0.52, 0.47), 0.02, 41), 2.0)
			m.roughness = 0.55
		"cabinet_navy":
			_tex(m, _speckle(Color(0.17, 0.23, 0.33), 0.02, 42), 2.0)
			m.roughness = 0.5
		"brass":
			m.albedo_color = Color(0.86, 0.68, 0.38)
			m.metallic = 1.0
			m.roughness = 0.28
		"chrome":
			m.albedo_color = Color(0.93, 0.94, 0.96)
			m.metallic = 0.8
			m.roughness = 0.14
		"black":
			m.albedo_color = Color(0.06, 0.06, 0.07)
			m.roughness = 0.4
		"rubber":
			m.albedo_color = Color(0.09, 0.09, 0.1)
			m.roughness = 0.85
		"ceramic":
			m.albedo_color = Color(0.97, 0.97, 0.95)
			m.roughness = 0.1
			m.metallic_specular = 0.7
		"enamel_red":
			m.albedo_color = Color(0.72, 0.12, 0.1)
			m.roughness = 0.2
		"glass":
			m.albedo_color = Color(0.85, 0.93, 0.95, 0.18)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.02
			m.metallic_specular = 1.0
		"glass_fridge":
			m.albedo_color = Color(0.75, 0.9, 1.0, 0.1)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.roughness = 0.0
			m.metallic_specular = 1.0
		"chalk":
			_tex(m, _speckle(Color(0.12, 0.14, 0.13), 0.04, 51), 2.0)
			m.roughness = 0.95
		"paper":
			m.albedo_color = Color(0.98, 0.96, 0.9)
			m.roughness = 0.9
		"fridge_inside":
			m.albedo_color = Color(0.9, 0.93, 0.95)
			m.roughness = 0.3
			m.emission_enabled = true
			m.emission = Color(0.85, 0.92, 1.0)
			m.emission_energy_multiplier = 0.9
		_:
			push_error("Unknown material " + n)
	_mats[n] = m
	return m


## Same material but with a different tint (e.g. painted metal colours).
static func tinted(n: String, c: Color) -> StandardMaterial3D:
	var key := n + c.to_html()
	if _mats.has(key):
		return _mats[key]
	var m := mat(n).duplicate() as StandardMaterial3D
	m.albedo_color = c
	_mats[key] = m
	return m


static func _tex(m: StandardMaterial3D, imgs: Array, per_meter: float) -> void:
	m.albedo_texture = ImageTexture.create_from_image(imgs[0])
	m.normal_enabled = true
	m.normal_texture = ImageTexture.create_from_image(imgs[1])
	m.normal_scale = 1.0
	m.uv1_scale = Vector3.ONE * per_meter
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC


static func _noise(seed: int, freq: float, octaves := 4, kind := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.noise_type = kind
	n.frequency = freq
	n.fractal_octaves = octaves
	return n


## Height image -> [albedo with mipmaps, normal map with mipmaps]
static func _finish(albedo: Image, height: Image, strength: float) -> Array:
	height.bump_map_to_normal_map(strength)
	albedo.generate_mipmaps()
	height.generate_mipmaps()
	return [albedo, height]


static func _wood(light: Color, dark: Color, rings: float, seed: int) -> Array:
	var a := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var h := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var n := _noise(seed, 0.012, 3)
	var fine := _noise(seed + 1, 0.25, 2)
	for y in SIZE:
		for x in SIZE:
			# grain runs along x; seamless because both terms wrap
			var u := float(x) / SIZE
			var v := float(y) / SIZE
			var warp := n.get_noise_2d(cos(u * TAU) * 40.0, v * SIZE + sin(u * TAU) * 40.0) * 2.2
			var g := 0.5 + 0.5 * sin((v * rings + warp) * TAU)
			g = pow(g, 3.0)
			var f := fine.get_noise_2d(x * 0.3, y * 4.0) * 0.5 + 0.5
			var c := light.lerp(dark, clampf(g * 0.75 + f * 0.25, 0.0, 1.0))
			a.set_pixel(x, y, c)
			var hv := 1.0 - g * 0.6 - f * 0.25
			h.set_pixel(x, y, Color(hv, hv, hv))
	return _finish(a, h, 2.0)


static func _butcher() -> Array:
	# strips of alternating light/dark wood
	var a := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var h := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var fine := _noise(61, 0.2, 2)
	var tones := [Color(0.76, 0.55, 0.33), Color(0.62, 0.42, 0.24), Color(0.8, 0.6, 0.38), Color(0.55, 0.36, 0.2)]
	for y in SIZE:
		var strip := y / 32
		var base: Color = tones[strip % 4]
		for x in SIZE:
			var f := fine.get_noise_2d(x * 0.15, y * 3.0) * 0.5 + 0.5
			var c := base.darkened(f * 0.25)
			var seam := y % 32 == 0
			if seam:
				c = c.darkened(0.35)
			a.set_pixel(x, y, c)
			var hv := 0.6 if seam else 1.0 - f * 0.15
			h.set_pixel(x, y, Color(hv, hv, hv))
	return _finish(a, h, 2.0)


static func _marble() -> Array:
	var a := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var h := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var n := _noise(71, 0.008, 5)
	var n2 := _noise(72, 0.03, 3)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / SIZE * TAU
			var v := float(y) / SIZE * TAU
			var t := n.get_noise_3d(cos(u) * 30.0, sin(u) * 30.0, cos(v) * 30.0 + sin(v) * 30.0) * 6.0
			var vein := absf(sin(float(x + y) / SIZE * TAU * 1.0 + t))
			vein = pow(1.0 - vein, 14.0)
			var cloud := n2.get_noise_2d(x, y) * 0.5 + 0.5
			var c := Color(0.95, 0.94, 0.92).lerp(Color(0.86, 0.85, 0.84), cloud * 0.5)
			c = c.lerp(Color(0.48, 0.48, 0.5), vein * 0.85)
			a.set_pixel(x, y, c)
			var hv := 1.0 - vein * 0.1
			h.set_pixel(x, y, Color(hv, hv, hv))
	return _finish(a, h, 0.5)


static func _brushed(base: Color) -> Array:
	var a := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var h := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var n := _noise(81, 0.5, 2, FastNoiseLite.TYPE_VALUE)
	for y in SIZE:
		var row := n.get_noise_1d(y * 3.0) * 0.5 + 0.5
		for x in SIZE:
			var s := row * 0.5 + (n.get_noise_2d(x * 0.08, y * 8.0) * 0.5 + 0.5) * 0.5
			a.set_pixel(x, y, base.darkened(s * 0.05).lightened((1.0 - s) * 0.03))
			h.set_pixel(x, y, Color(s, s, s))
	return _finish(a, h, 0.6)


static func _speckle(base: Color, amount: float, seed: int) -> Array:
	var a := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var h := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var n := _noise(seed, 0.05, 4)
	var fine := _noise(seed + 7, 0.6, 1, FastNoiseLite.TYPE_VALUE)
	for y in SIZE:
		for x in SIZE:
			var u := float(x) / SIZE * TAU
			var v := float(y) / SIZE * TAU
			var c := n.get_noise_3d(cos(u) * 12.0, sin(u) * 12.0, cos(v) * 12.0 + sin(v) * 12.0) * 0.5 + 0.5
			var f := fine.get_noise_2d(x, y) * 0.5 + 0.5
			var col := base.darkened((c - 0.5) * amount * 4.0 + (f - 0.5) * amount * 2.0)
			a.set_pixel(x, y, col)
			var hv := 0.5 + (f - 0.5) * 0.6 + (c - 0.5) * 0.3
			h.set_pixel(x, y, Color(hv, hv, hv))
	return _finish(a, h, 1.0)


static func _subway() -> Array:
	# 4 bricks across (15 cm each), 8 rows (7.5 cm) per 0.6 m texture
	var a := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var h := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var n := _noise(91, 0.02, 2)
	var bw := SIZE / 4
	var bh := SIZE / 8
	for y in SIZE:
		var row := y / bh
		var off := bw / 2 if row % 2 == 1 else 0
		for x in SIZE:
			var xx := (x + off) % SIZE
			var lx := xx % bw
			var ly := y % bh
			var edge := mini(mini(lx, bw - 1 - lx), mini(ly, bh - 1 - ly))
			var grout := edge < 2
			var tile_id := (xx / bw) + row * 7
			var tone := 0.95 + sin(tile_id * 12.9898) * 0.025
			var c := Color(tone, tone, tone * 0.985)
			if grout:
				c = Color(0.72, 0.71, 0.68)
			c = c.darkened((n.get_noise_2d(x, y) * 0.5 + 0.5) * 0.03)
			a.set_pixel(x, y, c)
			var hv := 0.0 if grout else minf(1.0, 0.45 + edge * 0.12)
			h.set_pixel(x, y, Color(hv, hv, hv))
	return _finish(a, h, 3.0)


static func _stone_tiles() -> Array:
	# 2x2 tiles of 60 cm per texture, warm grey stone with grout
	var a := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var h := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
	var n := _noise(101, 0.03, 5)
	var fine := _noise(102, 0.5, 1, FastNoiseLite.TYPE_VALUE)
	var half := SIZE / 2
	for y in SIZE:
		for x in SIZE:
			var lx := x % half
			var ly := y % half
			var edge := mini(mini(lx, half - 1 - lx), mini(ly, half - 1 - ly))
			var tile_id := (x / half) + (y / half) * 2
			var base := Color(0.55, 0.53, 0.5).lightened(0.04 * float(tile_id % 3))
			var u := float(x) / SIZE * TAU
			var v := float(y) / SIZE * TAU
			var c3 := n.get_noise_3d(cos(u) * 20.0, sin(u) * 20.0, cos(v) * 20.0 + sin(v) * 20.0) * 0.5 + 0.5
			var f := fine.get_noise_2d(x, y) * 0.5 + 0.5
			var c := base.darkened((c3 - 0.5) * 0.25 + (f - 0.5) * 0.06)
			if edge < 2:
				c = Color(0.36, 0.35, 0.33)
			a.set_pixel(x, y, c)
			var hv := 0.0 if edge < 2 else minf(1.0, 0.6 + edge * 0.1) - f * 0.08
			h.set_pixel(x, y, Color(hv, hv, hv))
	return _finish(a, h, 2.5)
