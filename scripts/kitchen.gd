class_name Kitchen
extends RefCounted
## Builds the room, cabinetry, ingredient displays, lighting and stations.
## Wall runs use a local frame: x along the run, +z towards the room,
## origin on the floor at the run's centre (back of cabinets on the wall).

const TOP := 0.92
const DEPTH := 0.6
const W := 5.0
const D := 4.0
const H := 2.8
const WALL := 0.2

var game: Node3D
var root: Node3D
var stations: Array = []
var sources: Array = []
var env: Environment
var sun: DirectionalLight3D


func _init(g: Node3D) -> void:
	game = g
	root = Node3D.new()
	root.name = "Kitchen"
	g.add_child(root)


func build() -> void:
	_environment()
	_room()
	# ---- back wall (z = -D), facing +z
	var back := _frame(Vector3(0, 0, -D + 0.32), 0.0)
	_cabinets(back, -2.5, 0.9, "marble")
	_cabinets(back, 1.025, 4.35, "marble")
	_station("sink", Vector3(-1.6, TOP, -D + 0.32), 0.0)
	_station("board", Vector3(-0.75, TOP, -D + 0.38), 0.0)
	_station("board", Vector3(0.0, TOP, -D + 0.38), 0.0)
	_station("bowl", Vector3(0.8, TOP, -D + 0.36), 0.0)
	_station("blender", Vector3(1.55, TOP, -D + 0.28), 0.0)
	_station("toaster", Vector3(2.35, TOP, -D + 0.36), 0.0)
	_station("trash", Vector3(3.68, 0, -D + 0.35), 0.0)
	_upper_cabinets(_frame(Vector3(1.1, 0, -D), 0.0), 4.2)
	_backsplash(Vector3(0.1, 0, -D), 6.2, 0.0)
	_spice_shelf(Vector3(2.55, 1.15, -D + 0.1))
	_fridge(Vector3(-4.48, 0, -D + 0.4), 0.0, "FRESH", FRESH_ROWS)
	_fridge(Vector3(-W + 0.4, 0, 3.15), 90.0, "DAIRY", DAIRY_ROWS)
	_pantry(Vector3(-3.45, 0, -D + 0.22))
	_dry_goods(Vector3(3.35, 0, D - 0.22))
	# ---- left wall (x = -W), facing +x; local +x runs towards -z
	var left_x := -W + 0.32
	_cabinets(_frame(Vector3(left_x, 0, -2.275), 90.0), 0.0, 1.25, "marble")
	_station("oven", Vector3(left_x, TOP, -1.2), 90.0)
	_station("pan", Vector3(left_x + 0.02, TOP + 0.01, -1.42), 90.0)
	_station("pot", Vector3(left_x + 0.02, TOP + 0.01, -0.98), 90.0)
	_hood(Vector3(-W + 0.28, 1.95, -1.2))
	_cabinets(_frame(Vector3(left_x, 0, 0.0), 90.0), 0.0, 1.5, "marble")
	_station("fryer", Vector3(left_x + 0.02, TOP, 0.25), 90.0)
	_cabinets(_frame(Vector3(left_x, 0, 1.675), 90.0), 0.0, 1.85, "marble")
	_backsplash(Vector3(-W, 0, -0.15), 5.5, 90.0)
	_utensils(Vector3(left_x - 0.1, TOP, 1.1))
	# ---- right wall (x = W), facing -x; local +x runs towards +z
	var right_x := W - 0.32
	_cabinets(_frame(Vector3(right_x, 0, -0.75), -90.0), 0.0, 4.1, "marble")
	_station("plates", Vector3(right_x + 0.02, TOP, -2.3), -90.0)
	_station("microwave", Vector3(right_x + 0.04, TOP, -1.5), -90.0)
	_station("fridge", Vector3(right_x + 0.04, TOP, 0.9), -90.0)
	_upper_cabinets(_frame(Vector3(W, 0, -1.1), -90.0), 3.2)
	_backsplash(Vector3(W, 0, -0.75), 4.1, -90.0)
	_hatch(Vector3(W, 0, 2.0))
	# ---- island
	_island(Vector3(0, 0, 0.35))
	_station("grill", Vector3(-0.92, TOP, -0.02), 0.0)
	# ---- produce stand on the front wall
	_produce_stand(Vector3(0, 0, D))
	_decor()
	_lights()
	Batch.merge(root)


# ================================================================ helpers

func _frame(pos: Vector3, rot_y: float) -> Node3D:
	var f := Node3D.new()
	f.position = pos
	f.rotation_degrees.y = rot_y
	root.add_child(f)
	return f


func _box(parent: Node3D, mat: Material, pos: Vector3, size: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.solid(parent, "box", mat, pos, size, rot)


func _collider(parent: Node3D, pos: Vector3, size: Vector3, surface := false) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.position = pos
	if surface:
		b.set_meta("surface", true)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	parent.add_child(b)
	return b


func _station(kind: String, pos: Vector3, rot_y: float) -> Station:
	var s := Station.new()
	s.kind = kind
	s.game = game
	s.position = pos
	s.rotation_degrees.y = rot_y
	s.set_meta("nobatch", true)
	root.add_child(s)
	stations.append(s)
	return s


func _source(parent: Node3D, id: String, pos: Vector3, slot: Vector3, rot := Vector3.ZERO) -> Source:
	var s := Source.new()
	s.id = id
	s.slot = slot
	s.position = pos
	s.rotation_degrees = rot
	parent.add_child(s)
	sources.append(s)
	return s


## Shaker-style base cabinets with a stone/wood top, along a frame's x axis.
static func cabinets_into(parent: Node3D, cx: float, length: float, top: String, body := "cabinet", with_top := true) -> void:
	var cab := Tex.mat(body)
	var dark := Tex.mat("black")
	var y0 := 0.1
	var h := TOP - 0.04 - y0
	Models.solid(parent, "box", cab, Vector3(cx, y0 + h / 2, -0.02), Vector3(length, h, DEPTH - 0.04))
	Models.solid(parent, "box", dark, Vector3(cx, 0.05, -0.05), Vector3(length - 0.02, 0.1, DEPTH - 0.12))
	if with_top:
		Models.solid(parent, "box", Tex.mat(top), Vector3(cx, TOP - 0.02, 0.0), Vector3(length + 0.02, 0.04, DEPTH + 0.04))
	var n := maxi(1, int(round(length / 0.6)))
	var dw := length / n
	var front := (DEPTH - 0.04) / 2 - 0.02
	var drawer_h := 0.16
	for i in n:
		var x := cx - length / 2 + dw * (i + 0.5)
		# drawer front
		_shaker(parent, cab, Vector3(x, TOP - 0.06 - drawer_h / 2, front), Vector2(dw - 0.006, drawer_h), 0.035)
		Models.solid(parent, "box", Tex.mat("brass"), Vector3(x, TOP - 0.06 - drawer_h / 2, front + 0.03), Vector3(0.16, 0.012, 0.012))
		# door
		var dh := h - drawer_h - 0.03
		_shaker(parent, cab, Vector3(x, y0 + 0.01 + dh / 2, front), Vector2(dw - 0.006, dh - 0.01), 0.06)
		var hx := x + (dw / 2 - 0.06) * (1 if i % 2 == 0 else -1)
		Models.solid(parent, "box", Tex.mat("brass"), Vector3(hx, y0 + dh - 0.12, front + 0.03), Vector3(0.012, 0.14, 0.012))


## A shaker door: flat panel with a raised frame. Pos is the panel centre on the face.
static func _shaker(parent: Node3D, mat: Material, pos: Vector3, size: Vector2, rail: float) -> void:
	Models.solid(parent, "box", mat, pos, Vector3(size.x, size.y, 0.012))
	var z := pos.z + 0.012
	Models.solid(parent, "box", mat, Vector3(pos.x, pos.y + size.y / 2 - rail / 2, z), Vector3(size.x, rail, 0.014))
	Models.solid(parent, "box", mat, Vector3(pos.x, pos.y - size.y / 2 + rail / 2, z), Vector3(size.x, rail, 0.014))
	Models.solid(parent, "box", mat, Vector3(pos.x - size.x / 2 + rail / 2, pos.y, z), Vector3(rail, size.y - rail * 2, 0.014))
	Models.solid(parent, "box", mat, Vector3(pos.x + size.x / 2 - rail / 2, pos.y, z), Vector3(rail, size.y - rail * 2, 0.014))


func _cabinets(frame: Node3D, cx: float, length: float, top: String) -> void:
	cabinets_into(frame, cx, length, top)
	_collider(frame, Vector3(cx, TOP / 2, 0.0), Vector3(length, TOP, DEPTH + 0.04), true)


# ================================================================ room

func _room() -> void:
	var floor_mat := Tex.mat("floor")
	var floor_b := _collider(root, Vector3(0, -0.05, 0), Vector3(W * 2, 0.1, D * 2), true)
	_box(root, floor_mat, Vector3(0, -0.05, 0), Vector3(W * 2, 0.1, D * 2))
	floor_b.name = "Floor"
	var wall := Tex.mat("plaster")
	# back wall with window opening x -2.1..-1.1, y 1.15..2.05
	var wx0 := -2.1
	var wx1 := -1.1
	var wy0 := 1.15
	var wy1 := 2.05
	var bz := -D - WALL / 2
	_wall(Vector3((-W + wx0) / 2, H / 2, bz), Vector3(wx0 + W, H, WALL), wall)
	_wall(Vector3((wx1 + W) / 2, H / 2, bz), Vector3(W - wx1, H, WALL), wall)
	_wall(Vector3((wx0 + wx1) / 2, wy0 / 2, bz), Vector3(wx1 - wx0, wy0, WALL), wall)
	_wall(Vector3((wx0 + wx1) / 2, (wy1 + H) / 2, bz), Vector3(wx1 - wx0, H - wy1, WALL), wall)
	_window(Vector3((wx0 + wx1) / 2, (wy0 + wy1) / 2, -D), Vector2(wx1 - wx0, wy1 - wy0))
	# front wall
	_wall(Vector3(0, H / 2, D + WALL / 2), Vector3(W * 2 + WALL * 2, H, WALL), wall)
	# left wall
	_wall(Vector3(-W - WALL / 2, H / 2, 0), Vector3(WALL, H, D * 2), wall)
	# right wall with hatch opening z 1.5..2.5, y 0.95..1.95
	var rx := W + WALL / 2
	_wall(Vector3(rx, H / 2, (-D + 1.5) / 2), Vector3(WALL, H, 1.5 + D), wall)
	_wall(Vector3(rx, H / 2, (2.5 + D) / 2), Vector3(WALL, H, D - 2.5), wall)
	_wall(Vector3(rx, 0.95 / 2, 2.0), Vector3(WALL, 0.95, 1.0), wall)
	_wall(Vector3(rx, (1.95 + H) / 2, 2.0), Vector3(WALL, H - 1.95, 1.0), wall)
	# ceiling
	_wall(Vector3(0, H + 0.05, 0), Vector3(W * 2 + 0.4, 0.1, D * 2 + 0.4), Tex.mat("ceiling"))
	# skirting boards (white, slightly proud of the wall)
	var skirt := Tex.tinted("plaster", Color(0.97, 0.97, 0.96))
	_box(root, skirt, Vector3(0, 0.05, D - 0.008), Vector3(W * 2, 0.1, 0.016))
	_box(root, skirt, Vector3(-W + 0.008, 0.05, 0), Vector3(0.016, 0.1, D * 2))
	# crown moulding
	for spec in [[Vector3(0, H - 0.04, -D + 0.02), Vector3(W * 2, 0.08, 0.04)], [Vector3(0, H - 0.04, D - 0.02), Vector3(W * 2, 0.08, 0.04)],
			[Vector3(-W + 0.02, H - 0.04, 0), Vector3(0.04, 0.08, D * 2)], [Vector3(W - 0.02, H - 0.04, 0), Vector3(0.04, 0.08, D * 2)]]:
		_box(root, skirt, spec[0], spec[1])
	# front door
	var door := _frame(Vector3(-3.4, 0, D), 180.0)
	_box(door, Tex.mat("walnut"), Vector3(0, 1.03, 0.02), Vector3(0.92, 2.06, 0.04))
	for py in [0.55, 1.45]:
		_box(door, Tex.mat("walnut"), Vector3(0, py, 0.045), Vector3(0.7, 0.7, 0.015))
	_box(door, skirt, Vector3(0, 2.1, 0.02), Vector3(1.04, 0.08, 0.05))
	for sx in [-0.5, 0.5]:
		_box(door, skirt, Vector3(sx, 1.03, 0.02), Vector3(0.06, 2.12, 0.05))
	Models.solid(door, "sphere", Tex.mat("brass"), Vector3(0.36, 1.0, 0.08), Vector3.ONE * 0.06)
	_clock(Vector3(0, 2.25, D - 0.02))
	_chalkboard(Vector3(W - 0.02, 1.55, 3.1))


func _wall(pos: Vector3, size: Vector3, mat: Material) -> void:
	_box(root, mat, pos, size)
	_collider(root, pos, size)


func _backsplash(pos: Vector3, length: float, rot_y: float) -> void:
	var f := _frame(pos, rot_y)
	var tile := Tex.mat("tile")
	if rot_y == 0.0:
		# leave the window opening clear
		var a0 := -length / 2
		var wx0 := -2.1 - pos.x
		var wx1 := -1.1 - pos.x
		_box(f, tile, Vector3((a0 + wx0) / 2, 1.21, 0.005), Vector3(wx0 - a0, 0.58, 0.01))
		_box(f, tile, Vector3((wx1 + length / 2) / 2, 1.21, 0.005), Vector3(length / 2 - wx1, 0.58, 0.01))
		_box(f, tile, Vector3((wx0 + wx1) / 2, (TOP + 1.13) / 2, 0.005), Vector3(wx1 - wx0, 1.13 - TOP, 0.01))
	else:
		_box(f, tile, Vector3(0, 1.21, 0.005), Vector3(length, 0.58, 0.01))


func _window(pos: Vector3, size: Vector2) -> void:
	var f := _frame(pos, 0.0)
	# outdoor backdrop: sky, clouds, hedge and trees painted onto a card
	var img := Image.create(512, 320, false, Image.FORMAT_RGB8)
	var n := Tex._noise(5, 0.01, 4)
	for y in 320:
		for x in 512:
			var t := y / 320.0
			var c := Color(0.42, 0.66, 0.95).lerp(Color(0.86, 0.92, 0.98), t * 0.9)
			var cloud := n.get_noise_2d(x * 0.6, y * 1.6)
			var xs := x * 0.5
			var ys := y * 0.5
			if cloud > 0.15 and t < 0.6:
				c = c.lerp(Color(1, 1, 1), clampf((cloud - 0.15) * 3.0, 0, 0.85))
			var tree := 105 + int(18 * sin(xs * 0.05) + 20 * n.get_noise_2d(xs * 4.0, 0))
			if ys > tree:
				var leaf := n.get_noise_2d(xs * 8.0, ys * 8.0) * 0.5 + 0.5
				c = Color(0.24, 0.42, 0.2).lerp(Color(0.1, 0.22, 0.09), leaf)
			if ys > 140:
				c = Color(0.36, 0.55, 0.25).lerp(Color(0.26, 0.44, 0.19), n.get_noise_2d(xs * 6.0, ys * 2.0) * 0.5 + 0.5)
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var out := StandardMaterial3D.new()
	out.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	out.albedo_texture = ImageTexture.create_from_image(img)
	out.albedo_color = Color(1.15, 1.15, 1.15)
	var card := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(4.0, 2.5)
	card.mesh = q
	card.material_override = out
	card.position = Vector3(0, 0.1, -1.6)
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	f.add_child(card)
	# frame, mullions, glass, sill
	var frame := Tex.tinted("plaster", Color(0.97, 0.97, 0.96))
	var hw := size.x / 2
	var hh := size.y / 2
	for spec in [[Vector3(0, hh, -0.1), Vector3(size.x + 0.1, 0.05, 0.2)], [Vector3(0, -hh, -0.1), Vector3(size.x + 0.1, 0.05, 0.2)],
			[Vector3(-hw, 0, -0.1), Vector3(0.05, size.y, 0.2)], [Vector3(hw, 0, -0.1), Vector3(0.05, size.y, 0.2)],
			[Vector3(0, 0, -0.12), Vector3(0.035, size.y, 0.05)], [Vector3(0, 0.12, -0.12), Vector3(size.x, 0.03, 0.05)]]:
		_box(f, frame, spec[0], spec[1])
	var glass := MeshInstance3D.new()
	glass.mesh = Models.mesh("box")
	glass.material_override = Tex.mat("glass")
	glass.position = Vector3(0, 0, -0.12)
	glass.scale = Vector3(size.x, size.y, 0.004)
	glass.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	glass.set_meta("nobatch", true)
	f.add_child(glass)
	_box(f, Tex.mat("marble"), Vector3(0, -hh - 0.02, 0.03), Vector3(size.x + 0.16, 0.04, 0.12))
	# herbs in terracotta pots on the sill
	for px in [-0.32, 0.3]:
		var pot := _frame(f.position + Vector3(px, -hh, 0.03), 0.0)
		Models.solid(pot, "bowl", Color(0.72, 0.38, 0.24), Vector3(0, 0.055, 0), Vector3(0.11, 0.11, 0.11), Vector3(180, 0, 0), 0.85)
		for i in 9:
			var a := i * 2.4
			Models.solid(pot, "sphere", Color(0.22, 0.48, 0.2).lerp(Color(0.35, 0.6, 0.25), (i % 3) / 2.0),
				Vector3(cos(a) * 0.035, 0.13 + (i % 4) * 0.025, sin(a) * 0.035), Vector3(0.05, 0.02, 0.03), Vector3(0, rad_to_deg(a), 25), 0.6)


func _upper_cabinets(frame: Node3D, width: float) -> void:
	var cab := Tex.mat("cabinet")
	var y0 := 1.52
	var hgt := 0.72
	var dep := 0.34
	_box(frame, cab, Vector3(0, y0 + hgt / 2, dep / 2), Vector3(width, hgt, dep - 0.02))
	var n := maxi(1, int(round(width / 0.5)))
	var dw := width / n
	for i in n:
		var x := -width / 2 + dw * (i + 0.5)
		_shaker(frame, cab, Vector3(x, y0 + hgt / 2, dep - 0.004), Vector2(dw - 0.006, hgt - 0.01), 0.055)
		var hx := x + (dw / 2 - 0.05) * (1 if i % 2 == 0 else -1)
		_box(frame, Tex.mat("brass"), Vector3(hx, y0 + 0.11, dep + 0.025), Vector3(0.012, 0.12, 0.012))
	# crown
	_box(frame, cab, Vector3(0, y0 + hgt + 0.02, dep / 2 + 0.01), Vector3(width + 0.04, 0.04, dep + 0.02))
	# warm LED strip underneath
	_box(frame, Models.glow_mat(Color(1.0, 0.82, 0.6), 2.5), Vector3(0, y0 - 0.004, dep - 0.06), Vector3(width - 0.1, 0.006, 0.02))


func _hood(pos: Vector3) -> void:
	var f := _frame(pos, 90.0)
	var steel := Tex.mat("steel")
	_box(f, steel, Vector3(0, 0, 0.27), Vector3(0.9, 0.06, 0.5))
	# sloped canopy approximated with a tapered prism stack
	for i in 4:
		var t := i / 3.0
		_box(f, steel, Vector3(0, 0.06 + i * 0.07, 0.25 - t * 0.08), Vector3(0.9 - t * 0.5, 0.07, 0.46 - t * 0.2))
	_box(f, steel, Vector3(0, 0.6, 0.12), Vector3(0.32, 0.6, 0.24))
	_box(f, Models.glow_mat(Color(1.0, 0.9, 0.75), 2.0), Vector3(0, -0.032, 0.3), Vector3(0.5, 0.004, 0.12))
	var l := SpotLight3D.new()
	l.position = Vector3(0, -0.05, 0.3)
	l.rotation_degrees.x = -90
	l.spot_range = 1.6
	l.spot_angle = 55
	l.light_energy = 1.4
	l.light_color = Color(1.0, 0.88, 0.72)
	f.add_child(l)


func _spice_shelf(pos: Vector3) -> void:
	var f := _frame(pos, 0.0)
	_box(f, Tex.mat("walnut"), Vector3(0, 0, 0.05), Vector3(1.2, 0.025, 0.14))
	for x in [-0.55, 0.55]:
		_box(f, Tex.mat("brass"), Vector3(x, -0.04, 0.02), Vector3(0.015, 0.08, 0.06))
	var ids := ["salt", "black_pepper", "herbs", "curry_powder", "cinnamon", "vanilla", "sprinkles"]
	for i in ids.size():
		_source(f, ids[i], Vector3(-0.51 + i * 0.17, 0.0125, 0.05), Vector3(0.15, 0.16, 0.12))


const FRESH_ROWS := [
	["chicken", "chicken_breast", "chicken_wings", "beef", "ground_beef", "pork_chop", "pork_mince", "pork_belly"],
	["ribs", "lamb_chop", "lamb_mince", "duck", "turkey", "bacon", "sausage", "frankfurter"],
	["chorizo", "ham", "prosciutto", "salami", "pepperoni", "turkey_slices", "salmon", "white_fish"],
	["tuna", "smoked_salmon", "shrimp", "crab", "squid", "mussels", "tofu"],
]
const DAIRY_ROWS := [
	["egg", "milk", "buttermilk", "butter", "cheese"],
	["mozzarella", "parmesan", "feta", "halloumi", "brie"],
	["blue_cheese", "goat_cheese", "cream_cheese", "ricotta", "sour_cream"],
	["cream", "yogurt", "ice_cream", "condensed_milk"],
]
const PANTRY_ROWS := [
	["bread", "bun", "brioche_bun", "hot_dog_bun", "bagel", "croissant", "baguette", "english_muffin"],
	["pita", "naan", "tortilla", "taco_shell", "waffle", "crumpet", "puff_pastry", "rice_paper"],
	["wonton_wrappers", "crackers", "biscuits", "pasta", "penne", "macaroni", "lasagne_sheets", "noodles"],
	["rice_noodles", "nori", "flour", "cornflour", "sugar", "brown_sugar", "icing_sugar", "rice"],
	["couscous", "quinoa", "lentils", "oats", "granola", "cereal", "breadcrumbs", "panko"],
]
const DRY_ROWS := [
	["canned_tuna", "anchovies", "chickpeas", "beans", "black_beans", "kidney_beans", "canned_tomatoes", "sweetcorn", "peanuts", "almonds", "walnuts", "cashews"],
	["raisins", "coconut_flakes", "tea", "coffee", "gelatin", "yeast", "oregano", "paprika", "cumin", "chili_flakes", "garlic_powder", "garam_masala"],
	["turmeric", "cajun", "nutmeg", "sesame_seeds", "oil", "olive_oil", "sesame_oil", "vinegar", "balsamic", "soy_sauce", "fish_sauce", "worcestershire"],
	["hoisin", "teriyaki", "sweet_chili", "hot_sauce", "ketchup", "mustard", "bbq_sauce", "sriracha", "ranch", "mayonnaise", "tomato_paste", "broth"],
	["coconut_milk", "peanut_butter", "tahini", "miso", "gochujang", "curry_paste", "pickles", "olives", "capers", "honey", "chocolate", "white_chocolate"],
	["cocoa", "choc_spread", "maple_syrup", "golden_syrup", "jam", "marshmallow", "gummy_bears"],
]
const PRODUCE_ROWS := [
	["tomato", "cherry_tomato", "onion", "red_onion", "shallot", "garlic", "potato", "sweet_potato", "carrot", "beetroot", "radish", "lettuce", "cucumber", "bell_pepper", "green_pepper", "yellow_pepper", "chili"],
	["jalapeno", "mushroom", "broccoli", "cauliflower", "spinach", "kale", "cabbage", "red_cabbage", "bok_choy", "corn", "zucchini", "eggplant", "pumpkin", "butternut", "scallion", "leek", "celery"],
	["asparagus", "green_beans", "peas", "ginger", "basil", "mint", "parsley", "cilantro", "rosemary", "avocado", "lemon", "lime", "apple", "green_apple", "pear", "peach", "plum"],
	["banana", "strawberry", "raspberry", "blueberry", "cherry", "grapes", "orange", "grapefruit", "pineapple", "mango", "kiwi", "watermelon", "coconut", "pomegranate"],
]


func _fridge(pos: Vector3, rot: float, label: String, rows: Array) -> void:
	# Glass-door commercial fridge.
	var f := _frame(pos, rot)
	var steel := Tex.mat("steel")
	var w := 0.92
	var d := 0.72
	var h := 2.05
	_box(f, steel, Vector3(-w / 2 + 0.02, h / 2, 0), Vector3(0.04, h, d))
	_box(f, steel, Vector3(w / 2 - 0.02, h / 2, 0), Vector3(0.04, h, d))
	_box(f, steel, Vector3(0, h - 0.08, 0), Vector3(w, 0.16, d))
	_box(f, steel, Vector3(0, 0.08, 0), Vector3(w, 0.16, d))
	_box(f, Tex.mat("fridge_inside"), Vector3(0, h / 2, -d / 2 + 0.02), Vector3(w - 0.08, h - 0.32, 0.03))
	var sign := Label3D.new()
	sign.text = label
	sign.font = UI.title_font()
	sign.font_size = 64
	sign.pixel_size = 0.0018
	sign.modulate = Color(0.85, 0.95, 1.0)
	sign.outline_size = 0
	sign.position = Vector3(0, h - 0.08, d / 2 + 0.002)
	f.add_child(sign)
	var inner := w - 0.1
	for r in rows.size():
		var y := 0.2 + r * 0.42
		_box(f, Tex.mat("glass"), Vector3(0, y - 0.006, -0.02), Vector3(inner, 0.012, d - 0.1))
		_box(f, Tex.mat("chrome"), Vector3(0, y - 0.006, d / 2 - 0.07), Vector3(inner, 0.015, 0.01))
		var ids: Array = rows[r]
		var sw := inner / ids.size()
		for i in ids.size():
			_source(f, ids[i], Vector3(-inner / 2 + sw * (i + 0.5), y, 0.02), Vector3(sw - 0.01, 0.34, 0.4))
	# glass doors (visual only, you reach through)
	for sx in [-1, 1]:
		var door := MeshInstance3D.new()
		door.mesh = Models.mesh("box")
		door.material_override = Tex.mat("glass_fridge")
		door.position = Vector3(sx * w / 4, h / 2, d / 2 + 0.01)
		door.scale = Vector3(w / 2 - 0.02, h - 0.34, 0.01)
		door.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		door.set_meta("nobatch", true)
		f.add_child(door)
		_box(f, steel, Vector3(sx * 0.03, h / 2 + 0.1, d / 2 + 0.05), Vector3(0.02, 0.5, 0.02))
	var cold := OmniLight3D.new()
	cold.position = Vector3(0, h / 2, 0.1)
	cold.light_color = Color(0.85, 0.93, 1.0)
	cold.omni_range = 1.4
	cold.light_energy = 1.2
	f.add_child(cold)
	_collider(f, Vector3(0, h / 2, -0.1), Vector3(w, h, d - 0.25))


func _pantry(pos: Vector3) -> void:
	var f := _frame(pos, 0.0)
	var wood := Tex.mat("oak")
	var w := 1.0
	var d := 0.42
	for sx in [-1, 1]:
		_box(f, wood, Vector3(sx * (w / 2 - 0.015), 1.0, 0), Vector3(0.03, 2.0, d))
	_box(f, Tex.mat("oak_light"), Vector3(0, 1.0, -d / 2 + 0.008), Vector3(w - 0.06, 2.0, 0.016))
	var rows := PANTRY_ROWS
	var inner := w - 0.06
	for r in rows.size():
		var y := 0.12 + r * 0.38
		_box(f, wood, Vector3(0, y - 0.015, 0), Vector3(inner, 0.03, d - 0.01))
		var ids: Array = rows[r]
		var sw := inner / ids.size()
		for i in ids.size():
			_source(f, ids[i], Vector3(-inner / 2 + sw * (i + 0.5), y, 0.02), Vector3(sw - 0.01, 0.3, 0.32))
	_box(f, wood, Vector3(0, 2.0, 0), Vector3(w, 0.03, d))
	_collider(f, Vector3(0, 1.0, -0.12), Vector3(w, 2.0, 0.18))


func _produce_stand(pos: Vector3) -> void:
	# Four stepped tiers of wooden crates against the front wall, facing -z.
	var f := _frame(pos, 180.0)
	var wood := Tex.mat("crate")
	var dark := Tex.mat("walnut")
	var rows := PRODUCE_ROWS
	var width := 3.2
	for t in rows.size():
		var z := 0.66 - t * 0.17
		var y := 0.46 + t * 0.24
		var cw := width / (rows[t] as Array).size()
		# tier frame
		_box(f, dark, Vector3(0, y - 0.03, z), Vector3(width + 0.06, 0.04, 0.2))
		for sx in [-1, 1]:
			_box(f, dark, Vector3(sx * (width / 2 + 0.02), y / 2, z), Vector3(0.04, y, 0.18))
		var ids: Array = rows[t]
		for i in ids.size():
			var x := -width / 2 + cw * (i + 0.5)
			var crate := Node3D.new()
			f.add_child(crate)
			crate.position = Vector3(x, y, z)
			crate.rotation_degrees.x = 12.0
			# crate: base + slatted sides
			_box(crate, wood, Vector3(0, 0.005, 0), Vector3(cw - 0.012, 0.01, 0.17))
			for side in [-1, 1]:
				for s in 2:
					_box(crate, wood, Vector3(side * (cw / 2 - 0.01), 0.02 + s * 0.04, 0), Vector3(0.008, 0.03, 0.17))
					_box(crate, wood, Vector3(0, 0.02 + s * 0.04, side * 0.082), Vector3(cw - 0.012, 0.03, 0.008))
			_source(crate, ids[i], Vector3(0, 0.01, 0), Vector3(cw - 0.03, 0.2, 0.15))
	_box(f, dark, Vector3(0, 0.25, 0.75), Vector3(width + 0.06, 0.5, 0.06))
	_collider(f, Vector3(0, 0.22, 0.45), Vector3(width, 0.45, 0.6))
	var sign := Label3D.new()
	sign.text = "FARMERS MARKET"
	sign.font = UI.title_font()
	sign.font_size = 96
	sign.pixel_size = 0.0022
	sign.modulate = Color(0.95, 0.9, 0.78)
	sign.outline_size = 0
	sign.position = Vector3(0, 1.66, 0.02)
	f.add_child(sign)
	_box(f, Tex.mat("walnut"), Vector3(0, 1.66, 0.005), Vector3(1.6, 0.22, 0.02))


## Tall open shelving on the front wall: tins, spices, oils, sauces and sweets.
func _dry_goods(pos: Vector3) -> void:
	var f := _frame(pos, 180.0)
	var wood := Tex.mat("oak")
	var w := 2.8
	var d := 0.4
	for sx in [-1, 1]:
		_box(f, wood, Vector3(sx * (w / 2 - 0.015), 1.05, 0), Vector3(0.03, 2.1, d))
	_box(f, Tex.mat("oak_light"), Vector3(0, 1.05, -d / 2 + 0.008), Vector3(w - 0.06, 2.1, 0.016))
	var inner := w - 0.06
	for r in DRY_ROWS.size():
		var y := 0.12 + r * 0.33
		_box(f, wood, Vector3(0, y - 0.015, 0), Vector3(inner, 0.03, d - 0.01))
		var ids: Array = DRY_ROWS[r]
		var sw := inner / ids.size()
		for i in ids.size():
			_source(f, ids[i], Vector3(-inner / 2 + sw * (i + 0.5), y, 0.02), Vector3(sw - 0.01, 0.27, 0.3))
	_box(f, wood, Vector3(0, 2.1, 0), Vector3(w, 0.03, d))
	var sign := Label3D.new()
	sign.text = "DRY GOODS  ·  SAUCES  ·  SWEETS"
	sign.font = UI.title_font()
	sign.font_size = 64
	sign.pixel_size = 0.0018
	sign.modulate = Color(0.95, 0.9, 0.78)
	sign.outline_size = 0
	sign.position = Vector3(0, 2.25, 0.0)
	f.add_child(sign)
	_collider(f, Vector3(0, 1.05, -0.1), Vector3(w, 2.1, 0.2))


func _island(pos: Vector3) -> void:
	var f := _frame(pos, 0.0)
	var navy := "cabinet_navy"
	var len := 2.4
	# two back-to-back cabinet runs share the butcher-block top
	var a := Node3D.new()
	a.position = Vector3(0, 0, 0.24)
	f.add_child(a)
	cabinets_into(a, 0.0, len, "butcher", navy, false)
	var b := Node3D.new()
	b.position = Vector3(0, 0, -0.24)
	b.rotation_degrees.y = 180
	f.add_child(b)
	cabinets_into(b, 0.0, len, "butcher", navy, false)
	_box(f, Tex.mat("butcher"), Vector3(0, TOP - 0.025, 0), Vector3(len + 0.1, 0.05, 1.12))
	_collider(f, Vector3(0, TOP / 2, 0), Vector3(len + 0.1, TOP, 1.12), true)


func _hatch(pos: Vector3) -> void:
	_station("serve", Vector3(pos.x - 0.25, TOP + 0.02, pos.z), -90.0)
	var f := _frame(Vector3(pos.x - 0.32, 0, pos.z), -90.0)
	cabinets_into(f, 0.0, 1.0, "steel", "steel")
	_collider(f, Vector3(0, TOP / 2, 0), Vector3(1.0, TOP, DEPTH + 0.04), true)
	# warm dining room glow beyond the hatch
	var out := StandardMaterial3D.new()
	out.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var g := Gradient.new()
	g.set_color(0, Color(0.95, 0.75, 0.5))
	g.set_color(1, Color(0.4, 0.25, 0.18))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_from = Vector2(0.5, 0.3)
	gt.fill_to = Vector2(0.5, 1.0)
	out.albedo_texture = gt
	var q := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(3.0, 2.0)
	q.mesh = qm
	q.material_override = out
	q.position = Vector3(pos.x + 1.4, 1.4, pos.z)
	q.rotation_degrees.y = -90
	q.set_meta("nobatch", true)
	root.add_child(q)


func _utensils(pos: Vector3) -> void:
	var f := _frame(pos, 90.0)
	Models.solid(f, "cyl", Tex.mat("ceramic"), Vector3(0, 0.08, 0), Vector3(0.11, 0.16, 0.11))
	var cols := [Tex.mat("walnut"), Tex.mat("steel"), Tex.mat("black"), Tex.mat("oak_light")]
	for i in 4:
		var a := i * 1.57
		Models.solid(f, "cyl", cols[i], Vector3(cos(a) * 0.025, 0.24, sin(a) * 0.025), Vector3(0.014, 0.32, 0.014), Vector3(cos(a) * 10, 0, sin(a) * 10))
		Models.solid(f, "sphere", cols[i], Vector3(cos(a) * 0.04, 0.4, sin(a) * 0.04), Vector3(0.05, 0.015, 0.035), Vector3(cos(a) * 10, rad_to_deg(a), sin(a) * 10))
	# magnetic knife strip on the wall
	var k := _frame(Vector3(-W + 0.01, 1.32, 1.6), 90.0)
	_box(k, Tex.mat("black"), Vector3(0, 0, 0.01), Vector3(0.5, 0.04, 0.02))
	for i in 4:
		_box(k, Tex.mat("steel"), Vector3(-0.18 + i * 0.12, -0.08, 0.025), Vector3(0.025, 0.16 - i * 0.02, 0.003))
		_box(k, Tex.mat("black"), Vector3(-0.18 + i * 0.12, 0.06, 0.03), Vector3(0.02, 0.1, 0.015))


func _clock(pos: Vector3) -> void:
	var b := _frame(pos, 180.0)
	Models.solid(b, "cyl", Tex.mat("ceramic"), Vector3.ZERO, Vector3(0.34, 0.025, 0.34), Vector3(90, 0, 0))
	Models.solid(b, "torus", Tex.mat("black"), Vector3.ZERO, Vector3(0.36, 0.25, 0.36), Vector3(90, 0, 0))
	for i in 12:
		var a := TAU * i / 12.0
		_box(b, Tex.mat("black"), Vector3(cos(a) * 0.135, sin(a) * 0.135, 0.014), Vector3(0.008 if i % 3 else 0.012, 0.025, 0.004), Vector3(0, 0, rad_to_deg(a) + 90))
	var hands := Node3D.new()
	hands.name = "Hands"
	hands.set_meta("nobatch", true)
	hands.position.z = 0.018
	b.add_child(hands)
	var hr := Node3D.new()
	hr.name = "Hour"
	hands.add_child(hr)
	_box(hr, Tex.mat("black"), Vector3(0, 0.045, 0), Vector3(0.012, 0.09, 0.004))
	var mn := Node3D.new()
	mn.name = "Minute"
	hands.add_child(mn)
	_box(mn, Tex.mat("black"), Vector3(0, 0.065, 0.003), Vector3(0.008, 0.13, 0.004))
	game.clock = hands


func _chalkboard(pos: Vector3) -> void:
	var b := _frame(pos, 180.0)
	_box(b, Tex.mat("oak"), Vector3(0, 0, 0.0), Vector3(1.2, 0.85, 0.03))
	_box(b, Tex.mat("chalk"), Vector3(0, 0, 0.012), Vector3(1.1, 0.75, 0.012))
	var l := Label3D.new()
	l.text = "TODAY'S SPECIAL\n\nAnything you can dream up.\nWash it. Chop it. Cook it.\nPlate it. Serve it."
	l.font = UI.hand_font()
	l.font_size = 56
	l.pixel_size = 0.0021
	l.modulate = Color(0.95, 0.95, 0.9, 0.92)
	l.outline_size = 0
	l.position.z = 0.02
	b.add_child(l)


func _decor() -> void:
	# fruit bowl on the island
	var bowl := _frame(Vector3(0.95, TOP, 0.65), 0.0)
	Models.solid(bowl, "bowl", Tex.mat("ceramic"), Vector3(0, 0.04, 0), Vector3(0.26, 0.08, 0.26))
	var fruit := ["apple", "orange", "lemon", "apple", "banana"]
	for i in fruit.size():
		var n := Node3D.new()
		n.position = Vector3(cos(i * 1.4) * 0.06, 0.05 + (0.03 if i == 4 else 0.0), sin(i * 1.4) * 0.06)
		n.scale = Vector3.ONE * 0.55
		bowl.add_child(n)
		var l := DB.new_leaf(fruit[i])
		l["washed"] = true
		Models.new(n).build(l)
	# cookbooks on top of the upper cabinets
	var books := _frame(Vector3(2.6, 2.28, -D + 0.18), 0.0)
	var cols := [Color(0.6, 0.15, 0.12), Color(0.15, 0.3, 0.45), Color(0.85, 0.7, 0.3), Color(0.25, 0.45, 0.3), Color(0.9, 0.9, 0.85)]
	for i in 5:
		Models.solid(books, "box", cols[i], Vector3(i * 0.045, 0.12, 0), Vector3(0.04, 0.24 - (i % 2) * 0.03, 0.18), Vector3(0, 0, 4 if i == 4 else 0), 0.7)
	# rug in front of the island
	var rug := StandardMaterial3D.new()
	var img := Image.create(128, 64, false, Image.FORMAT_RGB8)
	for y in 64:
		for x in 128:
			var stripe := (x / 8) % 4
			var c: Color = [Color(0.55, 0.2, 0.17), Color(0.85, 0.78, 0.62), Color(0.2, 0.28, 0.38), Color(0.85, 0.78, 0.62)][stripe]
			if y < 3 or y > 60:
				c = Color(0.55, 0.2, 0.17)
			img.set_pixel(x, y, c.darkened(randf() * 0.08))
	img.generate_mipmaps()
	rug.albedo_texture = ImageTexture.create_from_image(img)
	rug.roughness = 1.0
	var rm := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(2.6, 1.0)
	rm.mesh = pm
	rm.material_override = rug
	rm.position = Vector3(0, 0.006, 2.25)
	root.add_child(rm)


# ================================================================ lighting

func _environment() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.6, 0.7, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.88, 0.84, 0.8)
	env.ambient_light_energy = 0.32
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.tonemap_exposure = 1.25
	env.glow_enabled = true
	env.glow_intensity = 0.25
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.4
	env.ssao_enabled = true
	env.ssao_radius = 0.9
	env.ssao_intensity = 1.8
	env.ssao_power = 1.6
	env.ssao_detail = 0.4
	env.adjustment_enabled = true
	env.adjustment_contrast = 1.06
	env.adjustment_saturation = 1.05
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	sun = DirectionalLight3D.new()
	# afternoon sun coming in through the back window
	sun.rotation_degrees = Vector3(-34, 200, 0)
	sun.light_energy = 2.2
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.shadow_enabled = true
	sun.shadow_blur = 1.5
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
	sun.directional_shadow_max_distance = 12.0
	sun.light_angular_distance = 1.0
	root.add_child(sun)


func _lights() -> void:
	# recessed ceiling downlights
	for p in [Vector3(-2.6, H, -2.3), Vector3(0.0, H, -2.3), Vector3(2.6, H, -2.3),
			Vector3(-3.6, H, 0.4), Vector3(3.6, H, 0.4), Vector3(-2.0, H, 2.6), Vector3(2.0, H, 2.6)]:
		var can := _frame(p, 0.0)
		Models.solid(can, "cyl", Tex.mat("chrome"), Vector3(0, -0.006, 0), Vector3(0.14, 0.01, 0.14))
		Models.solid(can, "cyl", Models.glow_mat(Color(1.0, 0.9, 0.78), 3.0), Vector3(0, -0.014, 0), Vector3(0.1, 0.004, 0.1))
		var l := SpotLight3D.new()
		l.position.y = -0.03
		l.rotation_degrees.x = -90
		l.spot_range = 4.0
		l.spot_angle = 58
		l.spot_attenuation = 0.8
		l.light_energy = 1.6
		l.light_color = Color(1.0, 0.86, 0.7)
		can.add_child(l)
	# pendants over the island
	for x in [-0.7, 0.7]:
		_pendant(Vector3(x, H, 0.35))
	# soft bounce fills (no specular) to fake indirect light
	for p in [Vector3(0, 1.0, -2.5), Vector3(-3.5, 1.0, 0.0), Vector3(3.5, 1.0, 0.0), Vector3(0, 1.0, 2.8)]:
		var fill := OmniLight3D.new()
		fill.position = p
		fill.omni_range = 4.5
		fill.light_energy = 0.35
		fill.light_specular = 0.0
		fill.light_color = Color(1.0, 0.9, 0.8)
		root.add_child(fill)
	var probe := ReflectionProbe.new()
	probe.size = Vector3(W * 2, H, D * 2)
	probe.position = Vector3(0, H / 2, 0)
	probe.interior = true
	probe.box_projection = true
	probe.ambient_mode = ReflectionProbe.AMBIENT_DISABLED
	root.add_child(probe)


func _pendant(pos: Vector3) -> void:
	var b := _frame(pos, 0.0)
	Models.solid(b, "cyl", Tex.mat("black"), Vector3(0, -0.45, 0), Vector3(0.008, 0.9, 0.008))
	var c := CylinderMesh.new()
	c.top_radius = 0.04
	c.bottom_radius = 0.17
	c.height = 0.2
	c.cap_bottom = false
	var mi := MeshInstance3D.new()
	mi.mesh = c
	var m := Tex.tinted("brass", Color(0.8, 0.62, 0.35)).duplicate() as StandardMaterial3D
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.position.y = -1.0
	b.add_child(mi)
	Models.solid(b, "sphere", Models.glow_mat(Color(1.0, 0.85, 0.62), 5.0), Vector3(0, -1.07, 0), Vector3.ONE * 0.07)
	var l := SpotLight3D.new()
	l.position.y = -1.06
	l.rotation_degrees.x = -90
	l.spot_range = 2.6
	l.spot_angle = 52
	l.light_energy = 2.2
	l.light_color = Color(1.0, 0.82, 0.58)
	b.add_child(l)


## High = SSAO + soft sun shadows + glow; low = cheapest look.
func set_quality(high: bool) -> void:
	env.ssao_enabled = high
	env.glow_enabled = high
	sun.shadow_enabled = high
	var vp := root.get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR if high else Viewport.SCALING_3D_MODE_FSR
	vp.scaling_3d_scale = 1.0 if high else 0.75
	vp.msaa_3d = Viewport.MSAA_2X if high else Viewport.MSAA_DISABLED
