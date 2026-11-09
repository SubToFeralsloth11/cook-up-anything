class_name Models
extends RefCounted
## Procedural low-poly models for every food state, plus shared mesh/material
## helpers for the kitchen. A Models instance builds one food model and
## records which materials belong to which leaf so cooking can tint them live.

const S := 1.5 # food visual scale
const BROWN_TARGET := Color(0.62, 0.38, 0.16)
const CHAR := Color(0.07, 0.05, 0.04)
const MUD := Color(0.42, 0.33, 0.22)

static var _meshes := {}
static var _mats := {}

var root: Node3D
var tints: Array = [] # [material, base colour, leaf dict]
var leaf = null
var o := Vector3.ZERO # current offset
var k := 1.0 # current scale
var rng := RandomNumberGenerator.new()


static func mesh(kind: String) -> Mesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var m: Mesh
	match kind:
		"sphere":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 1.0
			s.radial_segments = 14
			s.rings = 7
			m = s
		"hemi":
			var s := SphereMesh.new()
			s.radius = 0.5
			s.height = 0.5
			s.is_hemisphere = true
			s.radial_segments = 14
			s.rings = 4
			m = s
		"box":
			var b := BoxMesh.new()
			m = b
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 16
			c.rings = 1
			m = c
		"cone":
			var c := CylinderMesh.new()
			c.top_radius = 0.0
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 12
			c.rings = 1
			m = c
		"bowl":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.3
			c.height = 1.0
			c.radial_segments = 18
			c.rings = 1
			m = c
		"prism":
			var c := CylinderMesh.new()
			c.top_radius = 0.5
			c.bottom_radius = 0.5
			c.height = 1.0
			c.radial_segments = 3
			c.rings = 1
			m = c
		"torus":
			var t := TorusMesh.new()
			t.inner_radius = 0.32
			t.outer_radius = 0.5
			t.rings = 16
			t.ring_segments = 8
			m = t
		"capsule":
			var c := CapsuleMesh.new()
			c.radius = 0.25
			c.height = 1.0
			c.radial_segments = 12
			c.rings = 4
			m = c
	_meshes[kind] = m
	return m


## Shared (cached) material for static kitchen geometry.
static func smat(c: Color, rough := 0.6, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [c.to_html(), rough, metal]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	_mats[key] = m
	return m


static func solid(parent: Node3D, kind: String, c, pos: Vector3, scl: Vector3,
		rot := Vector3.ZERO, rough := 0.6, metal := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(kind)
	if c is Material:
		mi.material_override = c
	else:
		mi.material_override = smat(c, rough, metal)
	mi.position = pos
	mi.scale = scl
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


static func glass_mat(c := Color(0.85, 0.95, 1.0, 0.25)) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 1.0
	return m


static func glow_mat(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


static func tinted(base: Color, l: Dictionary) -> Color:
	var id: String = l["id"]
	var c := base
	if DB.flag(id, "d") and not l.get("washed", false):
		c = c.lerp(MUD, 0.38)
	var br: float = l.get("br", 0.0)
	if br > 0.0:
		var ing: Array = DB.ING[id]
		var target := Color(ing[7]) if ing.size() > 7 else BROWN_TARGET
		c = c.lerp(target, clampf(br, 0.0, 1.0))
	var ch: float = l.get("ch", 0.0)
	if ch > 0.0:
		c = c.lerp(CHAR, clampf(ch, 0.0, 1.0) * 0.9)
	return c


# ------------------------------------------------------------------ build

func _init(r: Node3D) -> void:
	root = r


## Adds one primitive in the current leaf's frame.
func p(kind: String, col: Color, pos: Vector3, scl: Vector3, rot := Vector3.ZERO,
		tint := true, rough := 0.55) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(kind)
	var m := StandardMaterial3D.new()
	m.roughness = rough
	mi.material_override = m
	mi.position = o + pos * k
	mi.scale = scl * k
	mi.rotation_degrees = rot
	root.add_child(mi)
	if tint and leaf != null:
		tints.append([m, col, leaf])
		m.albedo_color = tinted(col, leaf)
	else:
		m.albedo_color = col
	return mi


func build(d: Dictionary) -> void:
	rng.seed = hash(str(d.get("id", ""))) + d.get("parts", []).size()
	if d["id"] == "mix":
		build_combo(d["parts"])
	else:
		draw_leaf(d)


## Draws a single ingredient at offset `at` with scale `sc`.
func draw_leaf(d: Dictionary, at := Vector3.ZERO, sc := 1.0) -> void:
	leaf = d
	o = at
	k = sc
	var id: String = d["id"]
	var ing: Array = DB.ING[id]
	var oc := Color(ing[3])
	var ic := Color(ing[4])
	var s: float = ing[5] * S
	var cut: int = d.get("cut", 0)
	if d.has("flavor"):
		var fc := Color(DB.ING[d["flavor"]][4])
		if id in ["smoothie", "juice", "milkshake", "pie", "cake"]:
			ic = fc
			if id != "pie" and id != "cake":
				oc = fc
	if cut >= 3 or (DB.flag(id, "l") and not DB.flag(id, "i") and cut > 0):
		_bowl(s * 0.9, ic, "liquid")
		return
	if cut > 0 and not ing[2] in ["bowl", "bowlmound", "bowlchunks", "glass", "mug"]:
		_cut(id, ing[2], s, oc, ic, cut)
		return
	_shape(ing[2], s, oc, ic, d)


func _cut(id: String, shape: String, s: float, oc: Color, ic: Color, cut: int) -> void:
	match id:
		"egg":
			_bowl(s * 1.1, Color(1, 1, 0.92, 1), "liquid")
			p("hemi", ic, Vector3(0, s * 0.55, 0), Vector3(s * 0.7, s * 0.7, s * 0.7))
			return
		"bread", "bread_loaf":
			for i in 3:
				p("box", ic, Vector3((i - 1) * s * 0.5, s * 0.75, 0), Vector3(s * 0.22, s * 1.4, s * 1.5), Vector3(0, 0, (i - 1) * 8))
				p("box", oc, Vector3((i - 1) * s * 0.5, s * 1.47, 0), Vector3(s * 0.23, s * 0.08, s * 1.52), Vector3(0, 0, (i - 1) * 8))
			return
		"bun":
			p("cyl", ic, Vector3(-s * 0.6, s * 0.2, 0), Vector3(s * 2, s * 0.4, s * 2))
			p("hemi", oc, Vector3(s * 0.8, s * 0.05, 0), Vector3(s * 2, s * 1.3, s * 2), Vector3(0, 0, 0))
			return
		"dough":
			p("cyl", oc, Vector3(0, s * 0.08, 0), Vector3(s * 3, s * 0.16, s * 3))
			return
		"tortilla":
			for i in 6:
				var a := TAU * i / 6.0
				p("prism", oc, Vector3(cos(a), 0.2 + i * 0.05, sin(a)) * s * 0.6, Vector3(s * 0.9, s * 0.05, s * 0.9), Vector3(0, rad_to_deg(a), 0))
			return
		"pizza", "cake", "pie", "toast":
			_shape(shape, s, oc, ic, leaf)
			var cutter := p("box", Color(1, 1, 1, 1), Vector3(0, s * 0.6, 0), Vector3(s * 3.2, s * 0.02, s * 0.03), Vector3.ZERO, false)
			cutter.visible = id != "toast"
			return
	var is_round := shape in ["round", "lemon", "long", "potato", "corn", "eggplant", "pumpkin", "carrot", "banana", "mango", "avocado", "egg", "sausage"]
	var n := 6 if cut == 1 else 12
	var piece := s * (0.55 if cut == 1 else 0.32)
	for i in n:
		var a := TAU * i / n + rng.randf() * 0.6
		var r := s * (0.25 + rng.randf() * 0.75)
		var pos := Vector3(cos(a) * r, piece * 0.3 + rng.randf() * piece * 0.4 + (i % 3) * piece * 0.15, sin(a) * r)
		var col := ic if i % 3 != 0 else oc
		var rot := Vector3(rng.randf() * 40 - 20, rng.randf() * 180, rng.randf() * 40 - 20)
		if is_round and cut == 1:
			p("cyl", ic, pos, Vector3(piece * 1.5, piece * 0.25, piece * 1.5), rot)
			p("torus", oc, pos, Vector3(piece * 1.55, piece * 0.5, piece * 1.55), rot)
		elif shape == "leafy" or shape == "herb":
			p("sphere", col, pos, Vector3(piece * 1.4, piece * 0.25, piece * 1.1), rot)
		else:
			p("box", col, pos, Vector3(piece, piece * 0.8, piece), rot)


func _bowl(s: float, fill: Color, style: String) -> void:
	var rim := Color(0.97, 0.97, 0.95)
	p("bowl", rim, Vector3(0, s * 0.45, 0), Vector3(s * 2.4, s * 0.9, s * 2.4), Vector3.ZERO, false, 0.25)
	match style:
		"liquid":
			p("cyl", fill, Vector3(0, s * 0.82, 0), Vector3(s * 2.15, s * 0.04, s * 2.15), Vector3.ZERO, true, 0.15)
		"mound":
			p("sphere", fill, Vector3(0, s * 0.85, 0), Vector3(s * 2, s * 1.1, s * 2))
			p("sphere", fill, Vector3(0, s * 1.3, 0), Vector3(s * 0.8, s * 0.7, s * 0.8))
		"chunks":
			p("cyl", fill, Vector3(0, s * 0.8, 0), Vector3(s * 2.1, s * 0.04, s * 2.1))
			for i in 7:
				var a := TAU * i / 7.0
				var c := fill.lerp(Color(0.95, 0.95, 0.85), 0.4) if i % 2 == 0 else Color(0.3, 0.7, 0.3)
				p("box", c, Vector3(cos(a) * s * 0.6, s * 0.86, sin(a) * s * 0.6), Vector3.ONE * s * 0.25, Vector3(0, i * 37, 20))


func _shape(shape: String, s: float, oc: Color, ic: Color, d: Dictionary) -> void:
	var green := Color(0.25, 0.6, 0.2)
	var brown := Color(0.4, 0.27, 0.15)
	match shape:
		"round":
			p("sphere", oc, Vector3(0, s * 0.9, 0), Vector3(s * 2, s * 1.8, s * 2), Vector3.ZERO, true, 0.3)
			p("cyl", green if d["id"] != "onion" else brown, Vector3(0, s * 1.85, 0), Vector3(s * 0.12, s * 0.25, s * 0.12))
			if d["id"] == "tomato":
				for i in 5:
					p("box", green, Vector3(0, s * 1.78, 0), Vector3(s * 0.7, s * 0.04, s * 0.15), Vector3(0, i * 36, 0))
			elif d["id"] == "apple":
				p("sphere", green, Vector3(s * 0.2, s * 1.9, 0), Vector3(s * 0.4, s * 0.08, s * 0.2), Vector3(0, 0, -20))
		"potato":
			p("sphere", oc, Vector3(0, s * 0.75, 0), Vector3(s * 2.4, s * 1.5, s * 1.8))
			for i in 4:
				p("sphere", oc.darkened(0.25), Vector3(cos(i * 1.7) * s * 0.9, s * (0.8 + 0.4 * sin(i * 2.1)), sin(i * 1.7) * s * 0.7), Vector3.ONE * s * 0.15)
		"garlic":
			for i in 6:
				var a := TAU * i / 6.0
				p("sphere", oc, Vector3(cos(a) * s * 0.45, s * 0.7, sin(a) * s * 0.45), Vector3(s * 0.9, s * 1.3, s * 0.9))
			p("cone", oc, Vector3(0, s * 1.55, 0), Vector3(s * 0.5, s * 0.8, s * 0.5))
		"carrot":
			p("cone", oc, Vector3(0, s * 0.18, 0), Vector3(s * 0.36, s * 2.0, s * 0.36), Vector3(0, 0, 90))
			for i in 3:
				p("box", green, Vector3(s * 1.1, s * 0.3, (i - 1) * s * 0.08), Vector3(s * 0.6, s * 0.05, s * 0.06), Vector3(0, (i - 1) * 25, 15))
		"leafy":
			for i in 7:
				var a := TAU * i / 7.0
				var r := s * 0.45
				p("sphere", oc if i % 2 == 0 else ic, Vector3(cos(a) * r, s * 0.8, sin(a) * r), Vector3(s * 1.3, s * 1.5, s * 1.3), Vector3(rng.randf() * 30, 0, rng.randf() * 30))
			p("sphere", ic, Vector3(0, s * 1.1, 0), Vector3(s * 1.3, s * 1.2, s * 1.3))
		"long":
			p("capsule", oc, Vector3(0, s * 0.3, 0), Vector3(s * 1.2, s * 2.0, s * 1.2), Vector3(0, 0, 90), true, 0.35)
		"pepper":
			for i in 3:
				var a := TAU * i / 3.0
				p("sphere", oc, Vector3(cos(a) * s * 0.3, s * 0.9, sin(a) * s * 0.3), Vector3(s * 1.4, s * 1.9, s * 1.4), Vector3.ZERO, true, 0.25)
			p("cyl", green, Vector3(0, s * 1.9, 0), Vector3(s * 0.2, s * 0.4, s * 0.2))
		"chili":
			p("capsule", oc, Vector3(0, s * 0.15, 0), Vector3(s * 0.6, s * 2.0, s * 0.6), Vector3(0, 0, 80), true, 0.25)
			p("cyl", green, Vector3(-s * 1.0, s * 0.3, 0), Vector3(s * 0.25, s * 0.25, s * 0.25), Vector3(0, 0, 80))
		"mushroom":
			p("cyl", ic, Vector3(0, s * 0.45, 0), Vector3(s * 0.7, s * 0.9, s * 0.7))
			p("hemi", oc, Vector3(0, s * 0.8, 0), Vector3(s * 2.0, s * 1.6, s * 2.0))
		"broccoli":
			p("cyl", ic, Vector3(0, s * 0.45, 0), Vector3(s * 0.55, s * 0.9, s * 0.55))
			for i in 5:
				var a := TAU * i / 5.0
				p("sphere", oc, Vector3(cos(a) * s * 0.45, s * 1.1, sin(a) * s * 0.45), Vector3.ONE * s * 0.95)
			p("sphere", oc, Vector3(0, s * 1.35, 0), Vector3.ONE * s * 1.0)
		"corn":
			p("capsule", oc, Vector3(0, s * 0.3, 0), Vector3(s * 1.0, s * 2.0, s * 1.0), Vector3(0, 0, 90))
			for i in 2:
				p("sphere", green, Vector3(-s * 0.5, s * 0.3, (i - 0.5) * s * 0.35), Vector3(s * 1.5, s * 0.15, s * 0.5), Vector3(0, (i - 0.5) * 30, 0), false)
		"eggplant":
			p("capsule", oc, Vector3(0, s * 0.4, 0), Vector3(s * 1.5, s * 1.8, s * 1.5), Vector3(0, 0, 75), true, 0.2)
			p("cone", green, Vector3(-s * 0.9, s * 0.65, 0), Vector3(s * 0.4, s * 0.4, s * 0.4), Vector3(0, 0, 75))
		"pumpkin":
			for i in 7:
				var a := TAU * i / 7.0
				p("sphere", oc, Vector3(cos(a) * s * 0.45, s * 0.75, sin(a) * s * 0.45), Vector3(s * 1.1, s * 1.4, s * 1.1))
			p("cyl", Color(0.35, 0.5, 0.15), Vector3(0, s * 1.5, 0), Vector3(s * 0.2, s * 0.4, s * 0.2), Vector3(10, 0, 10))
		"scallion":
			p("cyl", oc, Vector3(s * 0.3, s * 0.12, 0), Vector3(s * 0.22, s * 1.4, s * 0.22), Vector3(0, 0, 90))
			p("cyl", ic, Vector3(-s * 0.85, s * 0.12, 0), Vector3(s * 0.26, s * 0.6, s * 0.26), Vector3(0, 0, 90))
		"herb":
			for i in 5:
				var a := TAU * i / 5.0
				p("cyl", Color(0.3, 0.55, 0.2), Vector3(cos(a) * s * 0.1, s * 0.4, sin(a) * s * 0.1), Vector3(s * 0.05, s * 0.8, s * 0.05), Vector3(cos(a) * 20, 0, sin(a) * 20))
				p("sphere", oc, Vector3(cos(a) * s * 0.4, s * 0.85, sin(a) * s * 0.4), Vector3(s * 0.7, s * 0.2, s * 0.5), Vector3(0, rad_to_deg(a), 15))
		"avocado":
			p("sphere", oc, Vector3(0, s * 1.0, 0), Vector3(s * 1.5, s * 2.0, s * 1.5), Vector3(0, 0, 10), true, 0.7)
		"lemon":
			p("sphere", oc, Vector3(0, s * 0.8, 0), Vector3(s * 2.2, s * 1.6, s * 1.6), Vector3.ZERO, true, 0.35)
			p("sphere", oc, Vector3(s * 1.1, s * 0.8, 0), Vector3.ONE * s * 0.3)
		"banana":
			for i in 4:
				var a := -0.6 + i * 0.4
				p("capsule", oc, Vector3(sin(a) * s * 1.6, s * 0.3 + cos(a) * s * 0.4 - s * 0.3, 0), Vector3(s * 0.85, s * 1.0, s * 0.85), Vector3(0, 0, 90 - rad_to_deg(a) * 0.8))
			p("cyl", brown, Vector3(s * 1.0, s * 0.45, 0), Vector3(s * 0.1, s * 0.3, s * 0.1), Vector3(0, 0, -50))
		"strawberry":
			p("cone", oc, Vector3(0, s * 0.85, 0), Vector3(s * 1.6, s * 1.7, s * 1.6), Vector3(180, 0, 0), true, 0.35)
			p("cyl", green, Vector3(0, s * 1.72, 0), Vector3(s * 1.3, s * 0.08, s * 1.3))
		"berries":
			for i in 9:
				var a := TAU * i / 7.0
				var r := s * (0.2 if i > 6 else 0.75)
				p("sphere", oc, Vector3(cos(a) * r, s * (0.45 + (0.5 if i > 6 else 0.0)), sin(a) * r), Vector3.ONE * s * 0.85, Vector3.ZERO, true, 0.4)
		"pineapple":
			p("sphere", oc, Vector3(0, s * 0.9, 0), Vector3(s * 1.5, s * 1.9, s * 1.5))
			for i in 5:
				p("cone", Color(0.25, 0.55, 0.25), Vector3(0, s * 2.05, 0), Vector3(s * 0.25, s * 0.9, s * 0.25), Vector3(cos(i * 1.3) * 25, 0, sin(i * 1.3) * 25), false)
		"mango":
			p("sphere", oc, Vector3(0, s * 0.75, 0), Vector3(s * 1.9, s * 1.5, s * 2.3), Vector3.ZERO, true, 0.35)
			p("sphere", Color(0.9, 0.35, 0.2), Vector3(0, s * 1.2, s * 0.4), Vector3(s * 1.0, s * 0.6, s * 1.0))
		"drumstick":
			p("sphere", oc, Vector3(-s * 0.2, s * 0.65, 0), Vector3(s * 1.7, s * 1.3, s * 1.3))
			p("cyl", Color(0.97, 0.95, 0.88), Vector3(s * 0.85, s * 0.6, 0), Vector3(s * 0.22, s * 1.0, s * 0.22), Vector3(0, 0, 80), false)
			p("sphere", Color(0.97, 0.95, 0.88), Vector3(s * 1.35, s * 0.62, 0), Vector3.ONE * s * 0.35, Vector3.ZERO, false)
		"steak":
			p("sphere", oc, Vector3(0, s * 0.3, 0), Vector3(s * 2.6, s * 0.6, s * 1.9), Vector3.ZERO, true, 0.45)
			p("torus", Color(0.98, 0.92, 0.88), Vector3(0, s * 0.3, 0), Vector3(s * 2.55, s * 0.6, s * 1.85))
		"mince":
			for i in 10:
				var a := TAU * i / 7.0
				var r := s * (0.3 + (i % 3) * 0.3)
				p("sphere", oc if i % 2 == 0 else ic, Vector3(cos(a) * r, s * (0.35 + (0.3 if i > 6 else 0.0)), sin(a) * r), Vector3.ONE * s * 0.6)
		"bacon":
			for i in 3:
				p("box", oc if i % 2 == 0 else ic, Vector3(0, s * 0.08, (i - 1) * s * 0.18), Vector3(s * 2.4, s * 0.06, s * 0.2), Vector3(0, 0, sin(i * 2.0) * 5))
			p("box", oc, Vector3(0, s * 0.14, s * 0.55), Vector3(s * 2.4, s * 0.06, s * 0.5), Vector3(4, 4, 0))
		"sausage":
			p("capsule", oc, Vector3(0, s * 0.25, 0), Vector3(s * 1.1, s * 2.0, s * 1.1), Vector3(0, 0, 90), true, 0.35)
		"ham":
			p("cyl", oc, Vector3(0, s * 0.2, 0), Vector3(s * 2.2, s * 0.4, s * 2.2))
			p("torus", ic, Vector3(0, s * 0.2, 0), Vector3(s * 2.25, s * 0.5, s * 2.25))
		"disc":
			for i in 4:
				p("cyl", oc, Vector3((i - 1.5) * s * 0.35, s * (0.08 + i * 0.04), 0), Vector3(s * 1.2, s * 0.1, s * 1.2), Vector3(0, 0, 10))
		"fillet":
			p("sphere", oc, Vector3(0, s * 0.25, 0), Vector3(s * 2.8, s * 0.5, s * 1.4))
			for i in 3:
				p("box", ic, Vector3((i - 1) * s * 0.6, s * 0.48, 0), Vector3(s * 0.05, s * 0.02, s * 1.1), Vector3(0, 20, 0))
		"shrimp":
			for i in 5:
				var a := PI * i / 5.0
				p("sphere", oc if i % 2 == 0 else ic, Vector3(cos(a) * s * 0.8, s * 0.35, sin(a) * s * 0.8), Vector3.ONE * s * (0.8 - i * 0.08))
			p("cone", oc, Vector3(-s * 0.9, s * 0.35, -s * 0.2), Vector3(s * 0.5, s * 0.6, s * 0.2), Vector3(0, 0, 90))
		"box":
			p("box", oc, Vector3(0, s * 0.6, 0), Vector3(s * 2, s * 1.2, s * 1.4), Vector3.ZERO, true, 0.4)
		"egg":
			p("sphere", oc, Vector3(0, s * 0.95, 0), Vector3(s * 1.5, s * 1.9, s * 1.5), Vector3.ZERO, true, 0.35)
		"carton":
			var label := Color(0.25, 0.55, 0.9) if d["id"] == "milk" else (Color(0.9, 0.6, 0.3) if d["id"] == "broth" else Color(0.95, 0.75, 0.3))
			p("box", oc, Vector3(0, s * 0.9, 0), Vector3(s * 1.1, s * 1.8, s * 1.1), Vector3.ZERO, false, 0.6)
			p("box", label, Vector3(0, s * 0.8, 0), Vector3(s * 1.12, s * 0.6, s * 1.12), Vector3.ZERO, false)
			p("prism", oc, Vector3(0, s * 1.95, 0), Vector3(s * 0.75, s * 1.1, s * 0.65), Vector3(90, 0, 0), false)
		"wedge":
			p("prism", oc, Vector3(0, s * 0.5, 0), Vector3(s * 2.2, s * 1.0, s * 2.2), Vector3.ZERO, true, 0.5)
			for i in 3:
				p("sphere", oc.darkened(0.15), Vector3((i - 1) * s * 0.3, s * 1.0, s * 0.1), Vector3.ONE * s * 0.2)
		"tub":
			var lid := Color(0.4, 0.6, 0.95) if d["id"] == "yogurt" else Color(0.95, 0.45, 0.6)
			p("bowl", Color(0.98, 0.98, 0.98), Vector3(0, s * 0.6, 0), Vector3(s * 2, s * 1.2, s * 2), Vector3(180, 0, 0), false)
			p("cyl", lid, Vector3(0, s * 1.22, 0), Vector3(s * 2.05, s * 0.1, s * 2.05), Vector3.ZERO, false)
			if d["id"] == "ice_cream":
				p("sphere", ic, Vector3(0, s * 1.35, 0), Vector3(s * 1.1, s * 0.8, s * 1.1))
		"sack":
			var paper := Color(0.88, 0.8, 0.62)
			p("sphere", paper, Vector3(0, s * 0.9, 0), Vector3(s * 1.8, s * 1.9, s * 1.5), Vector3.ZERO, false, 0.9)
			p("cone", paper, Vector3(0, s * 1.85, 0), Vector3(s * 0.8, s * 0.5, s * 0.6), Vector3.ZERO, false, 0.9)
			p("cyl", ic, Vector3(0, s * 0.9, s * 0.72), Vector3(s * 0.9, s * 0.05, s * 0.9), Vector3(90, 0, 0))
		"pasta":
			for i in 9:
				p("cyl", oc, Vector3(0, s * (0.1 + (i % 3) * 0.08), ((i / 3) - 1) * s * 0.08 + (i % 3) * s * 0.03), Vector3(s * 0.05, s * 2.2, s * 0.05), Vector3(0, i * 2, 90))
			p("cyl", Color(0.2, 0.4, 0.8), Vector3(0, s * 0.18, 0), Vector3(s * 0.42, s * 0.3, s * 0.42), Vector3(0, 0, 90), false)
		"noodles":
			p("box", oc, Vector3(0, s * 0.3, 0), Vector3(s * 1.8, s * 0.6, s * 1.4))
			for i in 4:
				p("torus", oc.darkened(0.1), Vector3((i - 1.5) * s * 0.4, s * 0.62, 0), Vector3(s * 0.4, s * 0.4, s * 1.2), Vector3(0, 0, 90))
		"loaf":
			p("sphere", oc, Vector3(0, s * 0.6, 0), Vector3(s * 2.6, s * 1.3, s * 1.5), Vector3.ZERO, true, 0.7)
			p("box", oc, Vector3(0, s * 0.3, 0), Vector3(s * 2.4, s * 0.6, s * 1.4))
			for i in 3:
				p("box", ic, Vector3((i - 1) * s * 0.6, s * 1.22, 0), Vector3(s * 0.08, s * 0.05, s * 0.9), Vector3(0, 30, 0))
		"bun":
			p("cyl", ic, Vector3(0, s * 0.2, 0), Vector3(s * 2, s * 0.4, s * 2))
			p("hemi", oc, Vector3(0, s * 0.4, 0), Vector3(s * 2.05, s * 1.3, s * 2.05), Vector3.ZERO, true, 0.4)
			for i in 6:
				var a := TAU * i / 6.0
				p("sphere", Color(1, 0.97, 0.85), Vector3(cos(a) * s * 0.5, s * 0.98, sin(a) * s * 0.5), Vector3(s * 0.12, s * 0.06, s * 0.08), Vector3(0, rad_to_deg(a), 0), false)
		"tortilla":
			for i in 3:
				p("cyl", oc, Vector3(0, s * (0.03 + i * 0.05), 0), Vector3(s * 2.4, s * 0.04, s * 2.4), Vector3(0, 0, i * 2))
			for i in 5:
				p("cyl", oc.darkened(0.2), Vector3(cos(i * 1.9) * s * 0.7, s * 0.16, sin(i * 1.9) * s * 0.7), Vector3(s * 0.2, s * 0.01, s * 0.2))
		"sheet":
			for i in 3:
				p("box", oc, Vector3(0, s * (0.02 + i * 0.03), 0), Vector3(s * 1.8, s * 0.02, s * 1.8), Vector3(0, i * 6, 0), true, 0.8)
		"can":
			p("cyl", Color(0.8, 0.82, 0.85), Vector3(0, s * 0.7, 0), Vector3(s * 1.5, s * 1.4, s * 1.5), Vector3.ZERO, false, 0.25)
			p("cyl", ic, Vector3(0, s * 0.7, 0), Vector3(s * 1.52, s * 0.8, s * 1.52), Vector3.ZERO, false)
		"shaker":
			p("cyl", oc, Vector3(0, s * 0.7, 0), Vector3(s * 0.9, s * 1.4, s * 0.9), Vector3.ZERO, false, 0.3)
			p("hemi", Color(0.75, 0.75, 0.78), Vector3(0, s * 1.4, 0), Vector3(s * 0.92, s * 0.6, s * 0.92), Vector3.ZERO, false, 0.2)
		"jar":
			p("cyl", oc, Vector3(0, s * 0.65, 0), Vector3(s * 1.4, s * 1.3, s * 1.4), Vector3.ZERO, false, 0.2)
			p("cyl", Color(0.9, 0.3, 0.3) if d["id"] != "sprinkles" else Color(1, 1, 1), Vector3(0, s * 1.38, 0), Vector3(s * 1.45, s * 0.2, s * 1.45), Vector3.ZERO, false)
			if d["id"] == "sprinkles":
				for i in 6:
					p("box", Color.from_hsv(i / 6.0, 0.7, 1), Vector3(cos(i) * s * 0.4, s * 0.8 + (i % 2) * s * 0.3, s * 0.7), Vector3(s * 0.25, s * 0.08, s * 0.05), Vector3(0, 0, i * 40), false)
		"bottle":
			p("cyl", oc, Vector3(0, s * 0.8, 0), Vector3(s * 0.9, s * 1.6, s * 0.9), Vector3.ZERO, false, 0.15)
			p("cyl", oc, Vector3(0, s * 1.85, 0), Vector3(s * 0.35, s * 0.5, s * 0.35), Vector3.ZERO, false, 0.15)
			p("cyl", Color(0.95, 0.95, 0.95), Vector3(0, s * 0.9, 0), Vector3(s * 0.92, s * 0.5, s * 0.92), Vector3.ZERO, false)
			p("cyl", Color(0.15, 0.15, 0.15), Vector3(0, s * 2.15, 0), Vector3(s * 0.38, s * 0.15, s * 0.38), Vector3.ZERO, false)
		"bar":
			p("box", Color(0.85, 0.2, 0.25), Vector3(-s * 0.4, s * 0.2, 0), Vector3(s * 1.2, s * 0.42, s * 1.25), Vector3.ZERO, false)
			p("box", oc, Vector3(s * 0.5, s * 0.2, 0), Vector3(s * 1.0, s * 0.38, s * 1.2))
			for i in 2:
				p("box", oc.darkened(0.25), Vector3(s * 0.5, s * 0.4, (i - 0.5) * s * 0.6), Vector3(s * 0.95, s * 0.02, s * 0.03))
		"marsh":
			for i in 5:
				p("cyl", oc, Vector3(cos(i * 1.3) * s * 0.6, s * (0.35 + (0.6 if i == 4 else 0.0)), sin(i * 1.3) * s * 0.6), Vector3(s * 0.8, s * 0.7, s * 0.8), Vector3(0, 0, 90 if i % 2 == 0 else 0))
		"bowl":
			_bowl(s, ic, "liquid")
		"bowlmound":
			_bowl(s, ic, "mound")
		"bowlchunks":
			_bowl(s, ic, "chunks")
		"mound":
			p("sphere", oc, Vector3(0, s * 0.5, 0), Vector3(s * 2.2, s * 1.0, s * 2.2))
			for i in 5:
				var a := TAU * i / 5.0
				p("sphere", oc.lightened(0.05), Vector3(cos(a) * s * 0.5, s * 0.8, sin(a) * s * 0.5), Vector3.ONE * s * 0.6)
		"dough":
			p("sphere", oc, Vector3(0, s * 0.5, 0), Vector3(s * 2.0, s * 1.1, s * 2.0), Vector3.ZERO, true, 0.8)
		"patty":
			p("cyl", oc, Vector3(0, s * 0.22, 0), Vector3(s * 2.2, s * 0.45, s * 2.2), Vector3.ZERO, true, 0.75)
		"balls":
			for i in 5:
				var a := TAU * i / 4.0
				var r := s * (0.0 if i == 4 else 0.6)
				p("sphere", oc, Vector3(cos(a) * r, s * (0.4 + (0.55 if i == 4 else 0.0)), sin(a) * r), Vector3.ONE * s * 0.85, Vector3.ZERO, true, 0.8)
		"friedegg":
			p("cyl", oc, Vector3(0, s * 0.04, 0), Vector3(s * 2.2, s * 0.08, s * 1.8))
			p("cyl", oc, Vector3(s * 0.3, s * 0.04, s * 0.2), Vector3(s * 1.4, s * 0.08, s * 1.4))
			p("hemi", ic, Vector3(0, s * 0.08, 0), Vector3(s * 0.8, s * 0.6, s * 0.8), Vector3.ZERO, true, 0.2)
		"fries":
			p("bowl", Color(0.85, 0.15, 0.15), Vector3(0, s * 0.5, 0), Vector3(s * 1.5, s * 1.0, s * 1.2), Vector3(180, 0, 0), false)
			for i in 11:
				p("box", oc, Vector3((i % 4 - 1.5) * s * 0.25, s * 1.1, ((i / 4) - 1) * s * 0.22), Vector3(s * 0.14, s * 1.2, s * 0.14), Vector3(rng.randf() * 24 - 12, 0, rng.randf() * 24 - 12))
		"chips":
			for i in 10:
				var a := TAU * i / 10.0
				p("cyl", oc, Vector3(cos(a) * s * 0.6, s * (0.15 + (i % 3) * 0.12), sin(a) * s * 0.6), Vector3(s * 0.8, s * 0.04, s * 0.8), Vector3(rng.randf() * 50 - 25, 0, rng.randf() * 50 - 25))
		"noodlepile":
			p("sphere", oc, Vector3(0, s * 0.4, 0), Vector3(s * 2.2, s * 0.8, s * 2.2))
			for i in 6:
				p("torus", oc.lightened(0.08), Vector3(cos(i * 1.1) * s * 0.4, s * 0.7, sin(i * 1.1) * s * 0.4), Vector3(s * 0.9, s * 0.4, s * 0.9), Vector3(rng.randf() * 40, i * 30, rng.randf() * 40))
		"popcorn":
			p("bowl", Color(0.9, 0.2, 0.2), Vector3(0, s * 0.5, 0), Vector3(s * 2.0, s * 1.0, s * 2.0), Vector3.ZERO, false)
			for i in 14:
				var a := TAU * i / 9.0
				var r := s * (0.2 + (i % 3) * 0.3)
				p("sphere", oc if i % 3 else Color(1, 0.92, 0.6), Vector3(cos(a) * r, s * (1.05 + (i / 9) * 0.3), sin(a) * r), Vector3.ONE * s * 0.45)
		"toast":
			p("box", oc, Vector3(0, s * 0.18, 0), Vector3(s * 2.0, s * 0.36, s * 2.0), Vector3.ZERO, true, 0.8)
			p("box", ic, Vector3(0, s * 0.2, 0), Vector3(s * 1.75, s * 0.38, s * 1.75), Vector3.ZERO, true, 0.8)
		"sandwich":
			for i in 2:
				p("box", oc, Vector3(0, s * (0.15 + i * 0.5), 0), Vector3(s * 2.0, s * 0.3, s * 2.0), Vector3(0, 45, 0))
			p("box", ic, Vector3(0, s * 0.42, 0), Vector3(s * 2.1, s * 0.15, s * 2.1), Vector3(0, 45, 0))
		"pizza":
			p("cyl", oc, Vector3(0, s * 0.1, 0), Vector3(s * 2.6, s * 0.2, s * 2.6))
			p("cyl", ic, Vector3(0, s * 0.15, 0), Vector3(s * 2.3, s * 0.2, s * 2.3))
			p("cyl", Color(1, 0.86, 0.45), Vector3(0, s * 0.18, 0), Vector3(s * 2.0, s * 0.2, s * 2.0), Vector3.ZERO, true, 0.4)
			for i in 6:
				p("sphere", Color(1, 0.95, 0.75), Vector3(cos(i) * s * 0.6, s * 0.28, sin(i) * s * 0.6), Vector3(s * 0.4, s * 0.06, s * 0.4))
		"pie":
			p("bowl", oc, Vector3(0, s * 0.25, 0), Vector3(s * 2.4, s * 0.5, s * 2.4), Vector3(180, 0, 0))
			p("cyl", ic, Vector3(0, s * 0.5, 0), Vector3(s * 2.25, s * 0.04, s * 2.25))
			for i in 4:
				p("box", oc.lightened(0.1), Vector3((i - 1.5) * s * 0.5, s * 0.54, 0), Vector3(s * 0.2, s * 0.06, s * 2.1))
				p("box", oc.lightened(0.1), Vector3(0, s * 0.56, (i - 1.5) * s * 0.5), Vector3(s * 2.1, s * 0.06, s * 0.2))
		"cake":
			p("cyl", oc, Vector3(0, s * 0.55, 0), Vector3(s * 2.2, s * 1.1, s * 2.2))
			p("cyl", ic, Vector3(0, s * 1.15, 0), Vector3(s * 2.3, s * 0.2, s * 2.3), Vector3.ZERO, true, 0.3)
			p("cyl", ic, Vector3(0, s * 0.55, 0), Vector3(s * 2.25, s * 0.12, s * 2.25))
			p("sphere", Color(0.85, 0.1, 0.15), Vector3(0, s * 1.35, 0), Vector3.ONE * s * 0.35, Vector3.ZERO, false, 0.2)
		"muffins":
			for i in 3:
				var a := TAU * i / 3.0
				var pos := Vector3(cos(a) * s * 0.65, 0, sin(a) * s * 0.65)
				p("bowl", Color(0.95, 0.5, 0.55), pos + Vector3(0, s * 0.3, 0), Vector3(s * 0.9, s * 0.6, s * 0.9), Vector3(180, 0, 0), false)
				p("sphere", oc, pos + Vector3(0, s * 0.65, 0), Vector3(s * 1.05, s * 0.8, s * 1.05))
		"cookies":
			for i in 4:
				var pos := Vector3(cos(i * 1.6) * s * 0.5, s * (0.08 + i * 0.1), sin(i * 1.6) * s * 0.5)
				p("cyl", oc, pos, Vector3(s * 1.2, s * 0.15, s * 1.2), Vector3(rng.randf() * 10, 0, rng.randf() * 10))
				for j in 3:
					p("box", ic, pos + Vector3(cos(j * 2.0) * s * 0.3, s * 0.08, sin(j * 2.0) * s * 0.3), Vector3.ONE * s * 0.14)
		"stack":
			for i in 4:
				p("cyl", oc, Vector3(0, s * (0.1 + i * 0.2), 0), Vector3(s * 2.0, s * 0.18, s * 2.0), Vector3(0, 0, (i % 2) * 2.0))
			p("box", ic, Vector3(0, s * 0.95, 0), Vector3(s * 0.4, s * 0.15, s * 0.4), Vector3(0, 30, 0))
			p("cyl", Color(0.6, 0.3, 0.08), Vector3(0, s * 0.88, 0), Vector3(s * 1.6, s * 0.03, s * 1.6), Vector3.ZERO, false, 0.1)
		"donuts":
			for i in 2:
				p("torus", oc, Vector3((i - 0.5) * s * 1.2, s * (0.25 + i * 0.25), 0), Vector3(s * 1.4, s * 1.4, s * 1.4))
				p("torus", ic, Vector3((i - 0.5) * s * 1.2, s * (0.32 + i * 0.25), 0), Vector3(s * 1.3, s * 0.9, s * 1.3), Vector3.ZERO, true, 0.3)
		"glass":
			p("cyl", oc, Vector3(0, s * 0.85, 0), Vector3(s * 1.15, s * 1.6, s * 1.15), Vector3.ZERO, true, 0.25)
			var g := p("cyl", Color(1, 1, 1), Vector3(0, s * 1.0, 0), Vector3(s * 1.3, s * 2.0, s * 1.3), Vector3.ZERO, false)
			g.material_override = glass_mat()
			p("cyl", Color(1, 0.3, 0.45), Vector3(s * 0.3, s * 2.0, 0), Vector3(s * 0.1, s * 1.6, s * 0.1), Vector3(0, 0, -15), false)
			if d["id"] == "lemonade":
				p("cyl", Color(1, 0.95, 0.4), Vector3(-s * 0.4, s * 1.95, 0), Vector3(s * 0.8, s * 0.05, s * 0.8), Vector3(90, 0, 0), false)
		"mug":
			p("cyl", Color(0.9, 0.3, 0.3), Vector3(0, s * 0.8, 0), Vector3(s * 1.5, s * 1.6, s * 1.5), Vector3.ZERO, false, 0.3)
			p("torus", Color(0.9, 0.3, 0.3), Vector3(s * 0.8, s * 0.8, 0), Vector3(s * 0.8, s * 0.8, s * 0.8), Vector3(90, 0, 0), false)
			p("cyl", oc, Vector3(0, s * 1.58, 0), Vector3(s * 1.35, s * 0.04, s * 1.35))
		_:
			p("sphere", oc, Vector3(0, s, 0), Vector3.ONE * s * 2)


# ------------------------------------------------------------------ combos

const BASE_SHAPES := ["pizza", "pancakes", "cake", "steamed_rice", "cooked_pasta", "cooked_noodles",
	"toast", "mashed_potato", "pie", "porridge", "tortilla_chips", "fries", "nori", "french_toast",
	"bread_loaf", "ice_cream", "yogurt", "hot_chocolate", "smoothie", "milkshake", "juice", "lemonade"]


func build_combo(ls: Array) -> void:
	var stack_base := -1
	var wrap := -1
	for i in ls.size():
		var id: String = ls[i]["id"]
		if id == "bun" or ((id == "bread" or id == "bread_loaf") and int(ls[i].get("cut", 0)) > 0):
			stack_base = i
		elif id == "tortilla" and wrap < 0:
			wrap = i
	if stack_base >= 0 and ls.size() > 1:
		_stack(ls, stack_base)
		return
	if wrap >= 0 and ls.size() > 1:
		_wrap(ls, wrap)
		return
	var liquid := 0
	for l in ls:
		var id: String = l["id"]
		if int(l.get("cut", 0)) >= 3 or DB.flag(id, "l") or (l.get("cook", "") == "boil" and not DB.flag(id, "n")):
			liquid += 1
	if liquid * 2 >= ls.size() and ls.size() > 1:
		_soup(ls)
		return
	_pile(ls)


func _layer_color(l: Dictionary) -> Color:
	return Color(DB.ING[l["id"]][4] if int(l.get("cut", 0)) > 0 else DB.ING[l["id"]][3])


func _stack(ls: Array, bi: int) -> void:
	var b: Dictionary = ls[bi]
	var bun: bool = b["id"] == "bun"
	var s := 0.08 * S
	leaf = b
	o = Vector3.ZERO
	k = 1.0
	var crumb := Color(DB.ING[b["id"]][4])
	var crust := Color(DB.ING[b["id"]][3])
	var y := 0.0
	if bun:
		p("cyl", crust, Vector3(0, s * 0.2, 0), Vector3(s * 2.1, s * 0.4, s * 2.1))
		y = s * 0.4
	else:
		p("box", crumb, Vector3(0, s * 0.15, 0), Vector3(s * 2.0, s * 0.3, s * 2.0))
		y = s * 0.3
	for i in ls.size():
		if i == bi:
			continue
		var l: Dictionary = ls[i]
		leaf = l
		var id: String = l["id"]
		var c := _layer_color(l)
		var th := s * 0.18
		var w := 2.1
		var kind := "cyl"
		var rot := Vector3(0, i * 23, 0)
		match id:
			"cheese", "mozzarella", "ham":
				kind = "box"
				th = s * 0.08
				w = 2.0
				rot = Vector3(0, 45, 0)
			"lettuce", "spinach", "cabbage", "basil":
				th = s * 0.1
				w = 2.5
				c = Color(DB.ING[id][3])
			"patty", "beef", "chicken", "white_fish", "salmon":
				th = s * 0.4
				w = 2.2
			"bacon":
				kind = "box"
				th = s * 0.07
				w = 2.3
			"fried_egg":
				th = s * 0.1
				c = Color(1, 1, 1)
		if DB.flag(id, "l"):
			th = s * 0.05
			w = 1.9
		var sz := Vector3(s * w, th, s * w * (0.35 if id == "bacon" else 1.0))
		p(kind, c, Vector3(0, y + th * 0.5, 0), sz, rot)
		if id == "fried_egg":
			p("hemi", Color(1, 0.75, 0.1), Vector3(0, y + th, 0), Vector3.ONE * s * 0.6)
		y += th
	leaf = b
	if bun:
		p("hemi", crust, Vector3(0, y, 0), Vector3(s * 2.15, s * 1.3, s * 2.15), Vector3.ZERO, true, 0.4)
		for i in 6:
			var a := TAU * i / 6.0
			p("sphere", Color(1, 0.97, 0.85), Vector3(cos(a) * s * 0.5, y + s * 0.6, sin(a) * s * 0.5), Vector3(s * 0.12, s * 0.06, s * 0.08), Vector3.ZERO, false)
	else:
		p("box", crumb, Vector3(0, y + s * 0.15, 0), Vector3(s * 2.0, s * 0.3, s * 2.0))
		p("box", crust, Vector3(0, y + s * 0.15, 0), Vector3(s * 2.05, s * 0.28, s * 1.9))


func _wrap(ls: Array, wi: int) -> void:
	var s := 0.12 * S
	leaf = ls[wi]
	o = Vector3.ZERO
	k = 1.0
	var tc := Color(DB.ING["tortilla"][3])
	if ls[wi].get("cook", "") == "fry":
		# taco shell: tilted half disc with filling
		p("cyl", tc, Vector3(0, s * 0.5, -s * 0.12), Vector3(s * 1.8, s * 0.05, s * 1.0), Vector3(70, 0, 0))
		p("cyl", tc, Vector3(0, s * 0.5, s * 0.12), Vector3(s * 1.8, s * 0.05, s * 1.0), Vector3(-70, 0, 0))
		var n := 0
		for i in ls.size():
			if i == wi:
				continue
			leaf = ls[i]
			p("sphere", _layer_color(ls[i]), Vector3((n % 4 - 1.5) * s * 0.35, s * (0.5 + (n / 4) * 0.12), 0), Vector3(s * 0.4, s * 0.3, s * 0.3))
			n += 1
		return
	p("cyl", tc, Vector3(0, s * 0.3, 0), Vector3(s * 0.6, s * 1.8, s * 0.6), Vector3(0, 0, 90))
	var j := 0
	for i in ls.size():
		if i == wi:
			continue
		leaf = ls[i]
		var a := TAU * j / maxf(1, ls.size() - 1)
		p("sphere", _layer_color(ls[i]), Vector3(s * 0.9, s * 0.3 + sin(a) * s * 0.15, cos(a) * s * 0.15), Vector3(s * 0.12, s * 0.22, s * 0.22))
		j += 1


func _soup(ls: Array) -> void:
	var s := 0.1 * S
	leaf = null
	o = Vector3.ZERO
	k = 1.0
	p("bowl", Color(0.97, 0.97, 0.95), Vector3(0, s * 0.45, 0), Vector3(s * 2.6, s * 0.9, s * 2.6), Vector3.ZERO, false, 0.25)
	var lc := Color(0, 0, 0)
	var lw := 0.0
	for l in ls:
		var c := Models.tinted(Color(DB.ING[l["id"]][4]), l)
		var w := 2.0 if (DB.flag(l["id"], "l") or int(l.get("cut", 0)) >= 3) else 1.0
		lc += c * w
		lw += w
	lc = lc / lw
	lc.a = 1.0
	p("cyl", lc, Vector3(0, s * 0.83, 0), Vector3(s * 2.35, s * 0.04, s * 2.35), Vector3.ZERO, false, 0.12)
	var n := 0
	for l in ls:
		if DB.flag(l["id"], "l") or int(l.get("cut", 0)) >= 3:
			continue
		leaf = l
		var a := TAU * n / 6.0 + 0.3
		var r := s * (0.35 + (n % 2) * 0.35)
		p("box", _layer_color(l), Vector3(cos(a) * r, s * 0.86, sin(a) * r), Vector3.ONE * s * 0.3, Vector3(20, n * 41, 10))
		n += 1
		if n >= 9:
			break


func _pile(ls: Array) -> void:
	var base := -1
	var best := 999
	for i in ls.size():
		var idx := BASE_SHAPES.find(ls[i]["id"])
		if idx >= 0 and idx < best:
			best = idx
			base = i
	var top := 0.0
	var radius := 0.09
	if base >= 0:
		draw_leaf(ls[base])
		var aabb := _bounds()
		top = aabb.end.y
		radius = maxf(0.03, minf(aabb.size.x, aabb.size.z) * 0.32)
	var others := []
	for i in ls.size():
		if i != base:
			others.append(ls[i])
	var n := others.size()
	for i in n:
		var a := TAU * i / maxf(1, n) + 0.4
		var r := 0.0 if n == 1 else radius * (0.6 + 0.4 * (i % 2))
		var sc := 0.6 if base >= 0 else (0.75 if n <= 3 else 0.6)
		if base < 0:
			r = 0.0 if n == 1 else 0.075 + 0.025 * (i % 2)
		draw_leaf(others[i], Vector3(cos(a) * r, top, sin(a) * r), sc)


func _bounds() -> AABB:
	var out := AABB()
	var first := true
	for c in root.get_children():
		if c is MeshInstance3D:
			var b: AABB = (c as MeshInstance3D).transform * (c as MeshInstance3D).get_aabb()
			if first:
				out = b
				first = false
			else:
				out = out.merge(b)
	return out


# ------------------------------------------------------------------ particles

static func particles(kind: String) -> CPUParticles3D:
	var pt := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.material = m
	pt.mesh = sm
	pt.local_coords = false
	var g := Gradient.new()
	var curve := Curve.new()
	match kind:
		"steam", "smoke":
			pt.amount = 24
			pt.lifetime = 1.8
			pt.direction = Vector3.UP
			pt.spread = 18
			pt.gravity = Vector3(0, 0.25, 0)
			pt.initial_velocity_min = 0.15
			pt.initial_velocity_max = 0.35
			pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			pt.emission_sphere_radius = 0.08
			pt.scale_amount_min = 0.05
			pt.scale_amount_max = 0.09
			curve.add_point(Vector2(0, 0.4))
			curve.add_point(Vector2(1, 1.6))
			var c := Color(1, 1, 1) if kind == "steam" else Color(0.15, 0.13, 0.12)
			g.set_color(0, Color(c, 0.45 if kind == "steam" else 0.75))
			g.set_color(1, Color(c, 0.0))
		"sizzle":
			pt.amount = 30
			pt.lifetime = 0.5
			pt.direction = Vector3.UP
			pt.spread = 50
			pt.gravity = Vector3(0, -6, 0)
			pt.initial_velocity_min = 0.8
			pt.initial_velocity_max = 1.6
			pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			pt.emission_sphere_radius = 0.1
			pt.scale_amount_min = 0.006
			pt.scale_amount_max = 0.012
			curve.add_point(Vector2(0, 1))
			curve.add_point(Vector2(1, 0.3))
			g.set_color(0, Color(1, 0.95, 0.6, 1))
			g.set_color(1, Color(1, 0.7, 0.2, 0))
		"bubbles":
			pt.amount = 20
			pt.lifetime = 0.6
			pt.direction = Vector3.UP
			pt.spread = 10
			pt.gravity = Vector3(0, 0.5, 0)
			pt.initial_velocity_min = 0.05
			pt.initial_velocity_max = 0.15
			pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
			pt.emission_box_extents = Vector3(0.12, 0.0, 0.12)
			pt.scale_amount_min = 0.015
			pt.scale_amount_max = 0.03
			curve.add_point(Vector2(0, 0.5))
			curve.add_point(Vector2(1, 1.2))
			g.set_color(0, Color(1, 1, 1, 0.7))
			g.set_color(1, Color(1, 1, 1, 0.0))
		"water":
			pt.amount = 40
			pt.lifetime = 0.45
			pt.direction = Vector3.DOWN
			pt.spread = 4
			pt.gravity = Vector3(0, -9, 0)
			pt.initial_velocity_min = 0.3
			pt.initial_velocity_max = 0.6
			pt.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
			pt.emission_sphere_radius = 0.012
			pt.scale_amount_min = 0.012
			pt.scale_amount_max = 0.02
			curve.add_point(Vector2(0, 1))
			curve.add_point(Vector2(1, 1))
			g.set_color(0, Color(0.6, 0.85, 1, 0.8))
			g.set_color(1, Color(0.7, 0.9, 1, 0.3))
		"burst", "confetti", "sparkle":
			pt.amount = 40 if kind != "sparkle" else 24
			pt.lifetime = 1.0 if kind != "confetti" else 1.8
			pt.one_shot = true
			pt.explosiveness = 0.95
			pt.direction = Vector3.UP
			pt.spread = 70 if kind != "sparkle" else 180
			pt.gravity = Vector3(0, -6 if kind != "sparkle" else 0.5, 0)
			pt.initial_velocity_min = 1.0 if kind != "sparkle" else 0.2
			pt.initial_velocity_max = 2.6 if kind != "sparkle" else 0.6
			pt.scale_amount_min = 0.015
			pt.scale_amount_max = 0.03
			if kind == "confetti":
				pt.scale_amount_min = 0.03
				pt.scale_amount_max = 0.05
				pt.initial_velocity_max = 4.0
				var bm := BoxMesh.new()
				bm.size = Vector3(1, 0.2, 0.6)
				bm.material = m
				pt.mesh = bm
				pt.angular_velocity_min = -400
				pt.angular_velocity_max = 400
				var hue := Gradient.new()
				hue.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
				hue.colors = PackedColorArray([Color(1, 0.3, 0.4), Color(1, 0.85, 0.2), Color(0.3, 0.9, 0.5), Color(0.3, 0.6, 1), Color(0.9, 0.4, 1)])
				pt.color_initial_ramp = hue
			curve.add_point(Vector2(0, 1))
			curve.add_point(Vector2(1, 0.2))
			var c := Color(1, 0.95, 0.5) if kind == "sparkle" else Color(1, 1, 1)
			g.set_color(0, Color(c, 1))
			g.set_color(1, Color(c, 0 if kind != "confetti" else 1))
			pt.emitting = false
	pt.scale_amount_curve = curve
	pt.color_ramp = g
	return pt
