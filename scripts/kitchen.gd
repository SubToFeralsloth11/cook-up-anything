class_name Kitchen
extends RefCounted
## Builds the room, furniture, lights and all stations.

const TOP := 0.92 # counter top height
const DEPTH := 0.7
const W := 5.0 # half width (x)
const D := 4.0 # half depth (z)
const H := 3.0

var game: Node3D
var root: Node3D
var stations: Array = []


func _init(g: Node3D) -> void:
	game = g
	root = Node3D.new()
	root.name = "Kitchen"
	g.add_child(root)


func build() -> void:
	_room()
	_environment()
	# back wall (z = -D), stations face +z
	_station("fridge", Vector3(-4.45, 0, -D + 0.4), 0.0)
	_station("pantry", Vector3(-3.45, 0, -D + 0.25), 0.0)
	_counter(Vector3(0.15, 0, -D + DEPTH / 2), Vector3(6.1, TOP, DEPTH), 0.0)
	_station("sink", Vector3(-2.35, TOP, -D + 0.35), 0.0)
	_station("board", Vector3(-1.3, TOP, -D + 0.4), 0.0)
	_station("board", Vector3(-0.55, TOP, -D + 0.4), 0.0)
	_station("bowl", Vector3(0.4, TOP, -D + 0.38), 0.0)
	_station("blender", Vector3(1.25, TOP, -D + 0.3), 0.0)
	_station("trash", Vector3(3.6, 0, -D + 0.45), 0.0)
	_upper_cabinets(Vector3(1.0, 0, -D), 4.6)
	_window(Vector3(-2.35, 1.75, -D + 0.01))
	# left wall (x = -W), stations face +x
	_counter(Vector3(-W + DEPTH / 2, 0, -0.95), Vector3(2.2, TOP, DEPTH), 90.0, Color(0.25, 0.25, 0.28))
	_station("pan", Vector3(-W + 0.35, TOP, -1.55), 90.0)
	_station("pot", Vector3(-W + 0.35, TOP, -0.75), 90.0)
	_hood(Vector3(-W + 0.3, 2.0, -1.15))
	_counter(Vector3(-W + DEPTH / 2, 0, 0.3), Vector3(0.6, TOP, DEPTH), 90.0)
	_station("fryer", Vector3(-W + 0.35, TOP, 0.3), 90.0)
	_station("oven", Vector3(-W + 0.35, TOP, 1.0), 90.0)
	_counter(Vector3(-W + DEPTH / 2, 0, 1.95), Vector3(1.2, TOP, DEPTH), 90.0)
	# right wall (x = W), stations face -x
	_counter(Vector3(W - DEPTH / 2, 0, -0.6), Vector3(3.6, TOP, DEPTH), -90.0)
	_station("plates", Vector3(W - 0.35, TOP, -2.0), -90.0)
	_upper_cabinets_side(Vector3(W, 0, -0.6), 3.2)
	_hatch(Vector3(W, 0, 2.2))
	# island
	_counter(Vector3(0, 0, 0.35), Vector3(2.6, TOP, 1.1), 0.0, Color(0.36, 0.55, 0.78))
	_pendant(Vector3(-0.7, H, 0.35))
	_pendant(Vector3(0.7, H, 0.35))
	_decor()


func _station(kind: String, pos: Vector3, rot_y: float) -> Station:
	var s := Station.new()
	s.kind = kind
	s.game = game
	s.position = pos
	s.rotation_degrees.y = rot_y
	root.add_child(s)
	stations.append(s)
	return s


func _static_box(pos: Vector3, size: Vector3, mat, rot_y := 0.0, surface := false) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	b.rotation_degrees.y = rot_y
	if surface:
		b.set_meta("surface", true)
	var c := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	c.shape = bs
	b.add_child(c)
	Models.solid(b, "box", mat, Vector3.ZERO, size)
	root.add_child(b)
	return b


## Counter with cabinet body + wooden top. `pos` is floor-level centre.
func _counter(pos: Vector3, size: Vector3, rot_y: float, cab := Color(0.98, 0.78, 0.55)) -> void:
	var body := _static_box(pos + Vector3(0, (size.y - 0.04) / 2, 0), Vector3(size.x, size.y - 0.04, size.z), Models.smat(cab, 0.5), rot_y, true)
	# top slab
	var top := Models.solid(body, "box", Models.smat(Color(0.82, 0.8, 0.76), 0.3), Vector3(0, (size.y - 0.04) / 2 + 0.02, 0.0), Vector3(size.x + 0.04, 0.04, size.z + 0.04))
	top.name = "Top"
	var c := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(size.x + 0.04, 0.04, size.z + 0.04)
	c.shape = bs
	c.position = top.position
	body.add_child(c)
	# doors + handles on the front face (local +z) and kick plate
	var n := maxi(1, int(size.x / 0.6))
	var dw := size.x / n
	for i in n:
		var x := -size.x / 2 + dw * (i + 0.5)
		Models.solid(body, "box", Models.smat(cab.lightened(0.08), 0.45), Vector3(x, 0.03, size.z / 2 + 0.005), Vector3(dw - 0.03, size.y - 0.22, 0.01))
		Models.solid(body, "box", Models.smat(Color(0.75, 0.76, 0.8), 0.25, 0.9), Vector3(x, size.y / 2 - 0.2, size.z / 2 + 0.02), Vector3(0.14, 0.02, 0.02))
	Models.solid(body, "box", Models.smat(cab.darkened(0.4)), Vector3(0, -(size.y - 0.04) / 2 + 0.04, size.z / 2 - 0.03), Vector3(size.x, 0.08, 0.02))


func _room() -> void:
	# checker floor
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in 128:
		for x in 128:
			var a := (x < 64) == (y < 64)
			var c := Color(0.95, 0.93, 0.86) if a else Color(0.2, 0.35, 0.4)
			if x % 64 == 0 or y % 64 == 0:
				c = c.darkened(0.15)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = ImageTexture.create_from_image(img)
	fm.uv1_scale = Vector3(W * 2 / 0.9, D * 2 / 0.9, 1)
	fm.roughness = 0.35
	var floor_body := _static_box(Vector3(0, -0.05, 0), Vector3(W * 2, 0.1, D * 2), fm, 0.0, true)
	(floor_body.get_child(1) as MeshInstance3D).mesh = _plane_mesh(Vector2(W * 2, D * 2))
	(floor_body.get_child(1) as MeshInstance3D).position.y = 0.05
	(floor_body.get_child(1) as MeshInstance3D).scale = Vector3.ONE
	# subway-tile wall texture
	var wi := Image.create(128, 64, false, Image.FORMAT_RGB8)
	var tile := Color(0.82, 0.93, 0.9)
	var grout := Color(0.68, 0.78, 0.76)
	for y in 64:
		for x in 128:
			var row := y / 32
			var xx := (x + (32 if row == 1 else 0)) % 64
			var g := y % 32 < 2 or xx < 2
			wi.set_pixel(x, y, grout if g else tile)
	wi.generate_mipmaps()
	var wm := StandardMaterial3D.new()
	wm.albedo_texture = ImageTexture.create_from_image(wi)
	wm.roughness = 0.3
	wm.uv1_triplanar = true
	wm.uv1_scale = Vector3(1.6, 3.2, 1.6)
	var upper := Models.smat(Color(0.98, 0.95, 0.88), 0.8)
	for spec in [[Vector3(0, H / 2, -D - 0.05), Vector3(W * 2, H, 0.1)],
			[Vector3(0, H / 2, D + 0.05), Vector3(W * 2, H, 0.1)],
			[Vector3(-W - 0.05, H / 2, 0), Vector3(0.1, H, D * 2)]]:
		_static_box(spec[0], spec[1], wm)
	# right wall with a serving hatch opening at z 1.7..2.7, y 0.95..1.9
	var rw := [[Vector3(W + 0.05, H / 2, -1.2), Vector3(0.1, H, 5.6)],
		[Vector3(W + 0.05, H / 2, 3.35), Vector3(0.1, H, 1.3)],
		[Vector3(W + 0.05, 0.475, 2.2), Vector3(0.1, 0.95, 1.0)],
		[Vector3(W + 0.05, 2.45, 2.2), Vector3(0.1, 1.1, 1.0)]]
	for spec in rw:
		_static_box(spec[0], spec[1], wm)
	# ceiling
	_static_box(Vector3(0, H + 0.05, 0), Vector3(W * 2, 0.1, D * 2), upper)
	# skirting
	for z in [-D + 0.01, D - 0.01]:
		Models.solid(root, "box", Color(0.3, 0.45, 0.5), Vector3(0, 0.05, z), Vector3(W * 2, 0.1, 0.02))
	# front wall door + art
	Models.solid(root, "box", Color(0.55, 0.38, 0.25), Vector3(-2.8, 1.05, D - 0.01), Vector3(0.95, 2.1, 0.04), Vector3.ZERO, 0.5)
	Models.solid(root, "sphere", Models.smat(Color(0.9, 0.8, 0.4), 0.2, 0.9), Vector3(-2.45, 1.0, D - 0.05), Vector3.ONE * 0.06)
	_clock(Vector3(0.5, 2.2, D - 0.03))
	_menu_board(Vector3(2.4, 1.75, D - 0.03))


func _plane_mesh(size: Vector2) -> PlaneMesh:
	var p := PlaneMesh.new()
	p.size = size
	return p


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.35, 0.6, 0.95)
	sm.sky_horizon_color = Color(0.85, 0.9, 1.0)
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1.0, 0.95, 0.88)
	env.ambient_light_energy = 0.45
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.3
	env.glow_bloom = 0.0
	env.glow_hdr_threshold = 1.3
	env.ssao_enabled = true
	env.ssao_radius = 0.6
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.12
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, 25, 0)
	sun.light_energy = 0.7
	sun.light_color = Color(1.0, 0.95, 0.85)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 14.0
	root.add_child(sun)
	for p in [Vector3(-3, 2.6, -2), Vector3(3, 2.6, -2), Vector3(-3, 2.6, 2.2), Vector3(3, 2.6, 2.2)]:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 5.5
		l.light_energy = 0.75
		l.light_color = Color(1.0, 0.9, 0.78)
		root.add_child(l)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(W * 2, H, D * 2)
	probe.position = Vector3(0, H / 2, 0)
	probe.interior = true
	probe.box_projection = true
	root.add_child(probe)


func _upper_cabinets(pos: Vector3, width: float) -> void:
	var col := Color(0.98, 0.78, 0.55)
	var b := Node3D.new()
	b.position = pos + Vector3(0, 0, 0.2)
	root.add_child(b)
	Models.solid(b, "box", col, Vector3(0, 2.1, 0), Vector3(width, 0.75, 0.38), Vector3.ZERO, 0.5)
	var n := int(width / 0.6)
	for i in n:
		var x := -width / 2 + width / n * (i + 0.5)
		Models.solid(b, "box", col.lightened(0.08), Vector3(x, 2.1, 0.195), Vector3(width / n - 0.03, 0.68, 0.01))
		Models.solid(b, "box", Models.smat(Color(0.75, 0.76, 0.8), 0.25, 0.9), Vector3(x, 1.82, 0.21), Vector3(0.14, 0.02, 0.02))
	# warm under-cabinet light strip
	Models.solid(b, "box", Models.glow_mat(Color(1.0, 0.85, 0.6), 3.0), Vector3(0, 1.715, 0.1), Vector3(width - 0.2, 0.01, 0.03))
	var l := OmniLight3D.new()
	l.position = Vector3(0, 1.6, 0.25)
	l.omni_range = 2.4
	l.light_energy = 0.6
	l.light_color = Color(1.0, 0.85, 0.65)
	b.add_child(l)


func _upper_cabinets_side(pos: Vector3, width: float) -> void:
	var b := Node3D.new()
	b.position = pos + Vector3(-0.2, 0, 0)
	b.rotation_degrees.y = -90
	root.add_child(b)
	var col := Color(0.98, 0.78, 0.55)
	Models.solid(b, "box", col, Vector3(0, 2.1, 0), Vector3(width, 0.75, 0.38), Vector3.ZERO, 0.5)
	for i in 5:
		var x := -width / 2 + width / 5.0 * (i + 0.5)
		Models.solid(b, "box", col.lightened(0.08), Vector3(x, 2.1, 0.195), Vector3(width / 5.0 - 0.03, 0.68, 0.01))
		Models.solid(b, "box", Models.smat(Color(0.75, 0.76, 0.8), 0.25, 0.9), Vector3(x, 1.82, 0.21), Vector3(0.14, 0.02, 0.02))


func _window(pos: Vector3) -> void:
	var b := Node3D.new()
	b.position = pos
	root.add_child(b)
	var sky := StandardMaterial3D.new()
	sky.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var g := Gradient.new()
	g.set_color(0, Color(0.55, 0.8, 1.0))
	g.set_color(1, Color(0.95, 0.95, 0.85))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	sky.albedo_texture = gt
	Models.solid(b, "box", sky, Vector3.ZERO, Vector3(1.3, 0.9, 0.01))
	# distant hills
	Models.solid(b, "sphere", Models.smat(Color(0.45, 0.75, 0.45)).duplicate(), Vector3(-0.3, -0.5, 0.008), Vector3(1.0, 0.4, 0.001))
	Models.solid(b, "sphere", Models.smat(Color(0.35, 0.65, 0.4)), Vector3(0.35, -0.48, 0.009), Vector3(0.9, 0.35, 0.001))
	var frame := Models.smat(Color(1, 1, 1), 0.4)
	for spec in [[Vector3(0, 0.47, 0.02), Vector3(1.4, 0.06, 0.06)], [Vector3(0, -0.47, 0.04), Vector3(1.45, 0.06, 0.12)],
			[Vector3(-0.67, 0, 0.02), Vector3(0.06, 1.0, 0.06)], [Vector3(0.67, 0, 0.02), Vector3(0.06, 1.0, 0.06)],
			[Vector3(0, 0, 0.02), Vector3(0.04, 0.9, 0.04)], [Vector3(0, 0, 0.02), Vector3(1.3, 0.04, 0.04)]]:
		Models.solid(b, "box", frame, spec[0], spec[1])
	# plants on the sill
	for x in [-0.45, 0.45]:
		Models.solid(b, "cyl", Color(0.85, 0.45, 0.3), Vector3(x, -0.4, 0.08), Vector3(0.12, 0.1, 0.12))
		for i in 4:
			Models.solid(b, "sphere", Color(0.3, 0.65, 0.3), Vector3(x + cos(i * 1.6) * 0.04, -0.3 + i * 0.015, 0.08 + sin(i * 1.6) * 0.04), Vector3(0.08, 0.12, 0.08))
	var l := OmniLight3D.new()
	l.position = Vector3(0, 0, 0.6)
	l.light_color = Color(0.85, 0.92, 1.0)
	l.omni_range = 3.0
	l.light_energy = 0.8
	b.add_child(l)


func _hood(pos: Vector3) -> void:
	var b := Node3D.new()
	b.position = pos
	root.add_child(b)
	var steel := Models.smat(Color(0.78, 0.8, 0.83), 0.25, 0.85)
	Models.solid(b, "box", steel, Vector3(0, 0, 0), Vector3(0.6, 0.15, 1.4))
	Models.solid(b, "box", steel, Vector3(-0.1, 0.5, 0), Vector3(0.35, 0.85, 0.5))
	Models.solid(b, "box", Models.glow_mat(Color(1.0, 0.9, 0.7), 2.0), Vector3(0.05, -0.076, 0), Vector3(0.3, 0.005, 1.0))
	var l := OmniLight3D.new()
	l.position = Vector3(0.1, -0.3, 0)
	l.omni_range = 1.8
	l.light_energy = 0.7
	l.light_color = Color(1.0, 0.88, 0.7)
	b.add_child(l)


func _hatch(pos: Vector3) -> void:
	var st := _station("serve", pos + Vector3(-0.2, TOP + 0.03, 0), -90.0)
	_counter(pos + Vector3(-0.35, 0, 0), Vector3(1.0, TOP, 0.7), -90.0, Color(0.9, 0.45, 0.4))
	# awning
	var b := Node3D.new()
	b.position = pos + Vector3(0.12, 1.98, 0)
	root.add_child(b)
	for i in 6:
		var c := Color(0.9, 0.25, 0.25) if i % 2 == 0 else Color(1, 1, 1)
		Models.solid(b, "box", c, Vector3(0, 0, -0.5 + 0.1 + i * 0.16), Vector3(0.35, 0.03, 0.16), Vector3(0, 0, -20), 0.6)
	# outside: a bright "dining room" glow
	var out := StandardMaterial3D.new()
	out.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	out.albedo_color = Color(1.0, 0.88, 0.65)
	Models.solid(root, "box", out, pos + Vector3(1.0, 1.4, 0), Vector3(0.02, 1.2, 1.2))
	var l := OmniLight3D.new()
	l.position = pos + Vector3(-0.4, 1.6, 0)
	l.omni_range = 2.5
	l.light_energy = 0.9
	l.light_color = Color(1.0, 0.85, 0.6)
	root.add_child(l)


func _pendant(pos: Vector3) -> void:
	var b := Node3D.new()
	b.position = pos
	root.add_child(b)
	Models.solid(b, "cyl", Color(0.15, 0.15, 0.15), Vector3(0, -0.4, 0), Vector3(0.01, 0.8, 0.01))
	var shade := Models.smat(Color(0.2, 0.45, 0.45), 0.4, 0.3)
	var c := CylinderMesh.new()
	c.top_radius = 0.05
	c.bottom_radius = 0.2
	c.height = 0.18
	c.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = c
	var sm := shade.duplicate() as StandardMaterial3D
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = sm
	mi.position.y = -0.85
	b.add_child(mi)
	Models.solid(b, "sphere", Models.glow_mat(Color(1.0, 0.85, 0.6), 4.0), Vector3(0, -0.92, 0), Vector3.ONE * 0.08)
	var l := OmniLight3D.new()
	l.position.y = -1.0
	l.omni_range = 3.2
	l.light_energy = 1.1
	l.light_color = Color(1.0, 0.82, 0.6)
	l.shadow_enabled = false
	b.add_child(l)


func _clock(pos: Vector3) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation_degrees.y = 180
	root.add_child(b)
	Models.solid(b, "cyl", Color(1, 1, 1), Vector3.ZERO, Vector3(0.4, 0.03, 0.4), Vector3(90, 0, 0), 0.3)
	Models.solid(b, "torus", Color(0.85, 0.3, 0.3), Vector3.ZERO, Vector3(0.42, 0.2, 0.42), Vector3(90, 0, 0))
	for i in 12:
		var a := TAU * i / 12.0
		Models.solid(b, "box", Color(0.2, 0.2, 0.2), Vector3(cos(a) * 0.16, sin(a) * 0.16, 0.02), Vector3(0.015, 0.015, 0.01))
	var hands := Node3D.new()
	hands.name = "Hands"
	hands.position.z = 0.025
	b.add_child(hands)
	var hr := Node3D.new()
	hr.name = "Hour"
	hands.add_child(hr)
	Models.solid(hr, "box", Color(0.1, 0.1, 0.1), Vector3(0, 0.05, 0), Vector3(0.015, 0.1, 0.005))
	var mn := Node3D.new()
	mn.name = "Minute"
	hands.add_child(mn)
	Models.solid(mn, "box", Color(0.1, 0.1, 0.1), Vector3(0, 0.07, 0.003), Vector3(0.01, 0.14, 0.005))
	game.clock = hands


func _menu_board(pos: Vector3) -> void:
	var b := Node3D.new()
	b.position = pos
	b.rotation_degrees.y = 180
	root.add_child(b)
	Models.solid(b, "box", Color(0.15, 0.2, 0.18), Vector3.ZERO, Vector3(1.3, 0.8, 0.03), Vector3.ZERO, 0.9)
	Models.solid(b, "box", Color(0.55, 0.38, 0.25), Vector3(0, 0, -0.005), Vector3(1.38, 0.88, 0.02))
	var l := Label3D.new()
	l.text = "TODAY'S SPECIAL\nAnything you want!\n~ ~ ~\nCook it. Plate it.\nServe it."
	l.font_size = 64
	l.pixel_size = 0.0026
	l.modulate = Color(0.95, 0.95, 0.9)
	l.position.z = 0.02
	b.add_child(l)


func _decor() -> void:
	# utensil rail with hanging tools on the back wall
	Models.solid(root, "cyl", Models.smat(Color(0.75, 0.76, 0.8), 0.25, 0.9), Vector3(-0.9, 1.5, -D + 0.05), Vector3(0.02, 1.2, 0.02), Vector3(0, 0, 90))
	var cols := [Color(0.9, 0.35, 0.3), Color(0.3, 0.6, 0.9), Color(0.95, 0.75, 0.25), Color(0.4, 0.75, 0.4)]
	for i in 4:
		var x := -1.35 + i * 0.3
		Models.solid(root, "box", Models.smat(Color(0.75, 0.76, 0.8), 0.25, 0.9), Vector3(x, 1.36, -D + 0.06), Vector3(0.012, 0.28, 0.012))
		Models.solid(root, "sphere", cols[i], Vector3(x, 1.2, -D + 0.07), Vector3(0.08, 0.1, 0.02))
	# fruit bowl & herb pot on the island are decoration only
	var bowl := Node3D.new()
	bowl.position = Vector3(1.05, TOP + 0.0, 0.7)
	root.add_child(bowl)
	Models.solid(bowl, "bowl", Color(0.95, 0.85, 0.6), Vector3(0, 0.04, 0), Vector3(0.24, 0.08, 0.24), Vector3.ZERO, 0.4)
	for i in 3:
		var n := Node3D.new()
		n.position = Vector3(cos(i * 2.1) * 0.05, 0.05, sin(i * 2.1) * 0.05)
		n.scale = Vector3.ONE * 0.6
		bowl.add_child(n)
		Models.new(n).build(DB.new_leaf(["apple", "orange", "lemon"][i]))
	# rug
	Models.solid(root, "box", Color(0.75, 0.3, 0.3), Vector3(0, 0.003, 2.4), Vector3(2.4, 0.004, 1.2), Vector3.ZERO, 0.95)
	Models.solid(root, "box", Color(0.95, 0.85, 0.6), Vector3(0, 0.004, 2.4), Vector3(2.2, 0.004, 1.0), Vector3.ZERO, 0.95)
	Models.solid(root, "box", Color(0.75, 0.3, 0.3), Vector3(0, 0.005, 2.4), Vector3(2.0, 0.004, 0.8), Vector3.ZERO, 0.95)
