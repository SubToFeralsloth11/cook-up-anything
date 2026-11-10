class_name Models
extends RefCounted
## Food models. Every ingredient, cut state and dish is generated procedurally
## (scripts/meshgen.gd) into ONE cached ArrayMesh per (id, cut, flavour, variant)
## and drawn with the shared food shader (shaders/food.gdshader). Cooking colour,
## charring and mud are per-instance shader parameters, so live cooking never
## rebuilds meshes or creates materials. Also hosts the primitive/material
## helpers the kitchen uses.

const S := 1.5 # food visual scale
const BROWN_TARGET := Color(0.62, 0.38, 0.16)
const CHAR := Color(0.07, 0.05, 0.04)
const MUD := Color(0.42, 0.33, 0.22)
const LEAF := Color(0.3, 0.55, 0.2)
const DARK_LEAF := Color(0.16, 0.36, 0.12)
const STALK := Color(0.45, 0.38, 0.22)
const CERAMIC := Color(0.96, 0.95, 0.92)
const METAL := Color(0.78, 0.79, 0.82)
const BOWLS := ["bowl", "bowlmound", "bowlchunks", "glass", "mug"]
const STACK_R := 0.115 # burger/sandwich layer radius
const WASH_TIME := 1.8

static var _meshes := {}
static var _mats := {}
static var _food := {}
static var _fmat: ShaderMaterial
static var _gmat: StandardMaterial3D

var root: Node3D
var tints: Array = [] # [MeshInstance3D, leaf dict, br, ch, mud] (last applied values)
var rng := RandomNumberGenerator.new()
var b: MeshGen
var gl: MeshGen


# ================================================================ kitchen helpers

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
			m = BoxMesh.new()
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


## CPU-side approximation of the shader's cooking tint (pot liquid colour etc).
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


static func food_material() -> ShaderMaterial:
	if _fmat == null:
		_fmat = ShaderMaterial.new()
		_fmat.shader = load("res://shaders/food.gdshader")
	return _fmat


static func _glass() -> StandardMaterial3D:
	if _gmat == null:
		_gmat = glass_mat(Color(0.92, 0.96, 1.0, 0.16))
		_gmat.roughness = 0.03
	return _gmat


# ================================================================ instances & tint

func _init(r: Node3D) -> void:
	root = r


func build(d: Dictionary) -> void:
	rng.seed = hash(str(d.get("id", ""))) + d.get("parts", []).size()
	if d["id"] == "mix":
		build_combo(d["parts"])
	else:
		_leaf(d)


## Adds one cached leaf mesh as a MeshInstance3D with live tint parameters.
func _leaf(d: Dictionary, tr := Transform3D.IDENTITY, variant := "") -> MeshInstance3D:
	return _inst(leaf_mesh(d, variant), d, tr)


func _inst(m: Mesh, d, tr := Transform3D.IDENTITY) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.transform = tr
	root.add_child(mi)
	if d is Dictionary:
		var ing: Array = DB.ING[d["id"]]
		var bc := Color(ing[7]) if ing.size() > 7 else BROWN_TARGET
		mi.set_instance_shader_parameter("brown", Vector3(bc.r, bc.g, bc.b))
		var t := [mi, d, -1.0, -1.0, -1.0]
		apply_tint(t)
		tints.append(t)
	return mi


## Pushes a leaf's cooking state to its instance. Cheap: only changed values are sent.
static func apply_tint(t: Array) -> void:
	var mi: MeshInstance3D = t[0]
	var l: Dictionary = t[1]
	var br: float = l.get("br", 0.0)
	var ch: float = l.get("ch", 0.0)
	var mud := 0.0
	if DB.flag(l["id"], "d") and not l.get("washed", false):
		mud = clampf(1.0 - float(l.get("wash_t", 0.0)) / WASH_TIME, 0.0, 1.0)
	if br != t[2]:
		t[2] = br
		mi.set_instance_shader_parameter("br", br)
	if ch != t[3]:
		t[3] = ch
		mi.set_instance_shader_parameter("ch", ch)
	if mud != t[4]:
		t[4] = mud
		mi.set_instance_shader_parameter("mud", mud)


static func leaf_mesh(d: Dictionary, variant := "") -> ArrayMesh:
	var key := "%s|%d|%s|%s|%s|%s|%d|%s" % [d["id"], int(d.get("cut", 0)), d.get("flavor", ""), variant,
		d.get("style", ""), d.get("coat", ""), int(d.get("pieces", 0)), "p" if d.get("portion", false) else ""]
	if _food.has(key):
		return _food[key]
	var g := Models.new(null)
	g.begin(key)
	g._gen(d, variant)
	var m := g.finish()
	_food[key] = m
	return m


## Exaggeration over real life so food reads well in first person.
const K := 2.2
static var _fix := {}


## Scale that makes an ingredient's whole model match DB.REAL (cm) x K.
static func size_fix(id: String) -> float:
	if not DB.REAL.has(id):
		return 1.0
	if _fix.has(id):
		return _fix[id]
	_fix[id] = 1.0
	var g := Models.new(null)
	g.begin("fix|" + id)
	g._gen(DB.new_leaf(id), "")
	var bb := g.b.aabb().merge(g.gl.aabb()) if not g.gl.empty() else g.b.aabb()
	var longest := maxf(bb.size.x, maxf(bb.size.y, bb.size.z))
	var f := float(DB.REAL[id]) / 100.0 * K / maxf(longest, 0.001)
	_fix[id] = f
	return f


func begin(key: String) -> void:
	b = MeshGen.new()
	gl = MeshGen.new()
	rng.seed = hash(key)


func finish() -> ArrayMesh:
	var m := ArrayMesh.new()
	b.commit(m, food_material())
	gl.commit(m, _glass())
	return m


func _bounds() -> AABB:
	var out := AABB()
	var first := true
	for c in root.get_children():
		if c is MeshInstance3D:
			var bb: AABB = (c as MeshInstance3D).transform * (c as MeshInstance3D).get_aabb()
			if first:
				out = bb
				first = false
			else:
				out = out.merge(bb)
	return out


# ================================================================ small utilities

static func _nz(c: Color, p: Vector3, amt: float, freq: float) -> Color:
	var n := 1.0 + amt * MeshGen.n3(p * freq)
	return Color(c.r * n, c.g * n, c.b * n, c.a)


static func _sh(c: Color, k: float) -> Color:
	return Color(c.r * k, c.g * k, c.b * k, c.a)


static func _a(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, a)


## Catmull-Rom point on a polyline (Vector2 or Vector3 arrays), t in 0..1.
static func _path(pts: Array, t: float):
	var n := pts.size()
	var f := clampf(t, 0.0, 1.0) * (n - 1)
	var i := mini(int(f), n - 2)
	var u := f - i
	var p0 = pts[maxi(i - 1, 0)]
	var p1 = pts[i]
	var p2 = pts[i + 1]
	var p3 = pts[mini(i + 2, n - 1)]
	var u2 := u * u
	var u3 := u2 * u
	return 0.5 * ((2.0 * p1) + (p2 - p0) * u + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * u2 + (3.0 * p1 - p0 - 3.0 * p2 + p3) * u3)


## Smooths a profile with Catmull-Rom; a repeated point stays a crease.
static func _cr(pts: Array, sub := 3) -> Array:
	var out := []
	var seg := []
	for k in pts.size() + 1:
		var end: bool = k == pts.size() or (k > 0 and (pts[k] as Vector2).is_equal_approx(pts[k - 1]))
		if end:
			if seg.size() > 1:
				var m := (seg.size() - 1) * sub
				for i in m + 1:
					out.append(_path(seg, float(i) / m))
			elif seg.size() == 1:
				out.append(seg[0])
			seg = []
		if k < pts.size():
			seg.append(pts[k])
	return out


## Splits long straight profile segments so vertex colours/bends have rows to work with.
static func _sub(pts: Array, maxlen: float) -> Array:
	var out := [pts[0]]
	for i in range(1, pts.size()):
		var a: Vector2 = pts[i - 1]
		var c: Vector2 = pts[i]
		var n := int(ceil(a.distance_to(c) / maxlen))
		for k in range(1, n):
			out.append(a.lerp(c, float(k) / n))
		out.append(c)
	return out


## Revolves a smooth profile [Vector2(r, y)] around Y. rf(th, t) scales the
## radius, yf(th, t) shifts height (t = 0..1 along the profile).
func _rev(pts: Array, cf, nu: int, rf := Callable(), yf := Callable()) -> void:
	var n := pts.size()
	b.surf(nu, n - 1, func(u: float, v: float) -> Vector3:
		var j := int(round(v * (n - 1)))
		var pt: Vector2 = pts[j]
		var th := u * TAU
		var r := pt.x * (1.0 if rf.is_null() else float(rf.call(th, v)))
		var y := pt.y + (0.0 if yf.is_null() else float(yf.call(th, v)))
		return Vector3(cos(th) * r, y, sin(th) * r), cf)


## Tapered tube through points (stems, roots, straws).
func _stem(pts: Array, r0: float, r1: float, cf, nu := 6, nv := 0, cap := true) -> void:
	var n := nv if nv > 0 else maxi(3, (pts.size() - 1) * 3)
	b.tube(n, nu, func(t: float) -> Vector3: return _path(pts, t),
		func(t: float, _th: float) -> float: return 0.0 if cap and t >= 0.999 else lerpf(r0, r1, t), cf)


## Ring of sepals/leaves around pos (tomato calyx, strawberry top).
func _calyx(pos: Vector3, n: int, length: float, width: float, col: Color, droop := 0.5, rise := 0.1, phase := 0.3) -> void:
	var cf := func(u: float, v: float, p: Vector3) -> Color:
		return _nz(col.lerp(col.lightened(0.25), v * 0.4), p, 0.12, 40.0)
	for i in n:
		var a := TAU * i / n + phase + rng.randf() * 0.3
		b.leaf(pos, Vector3(cos(a), 0.15, sin(a)), length * (0.85 + rng.randf() * 0.3), width, cf,
			rise, droop, 0.25, 0.04, 0.3, 4, 6)


## Leafy colour: pale base and midrib, greener toward the tip/edges.
static func _leafcol(base: Color, tip: Color, rib := 0.12) -> Callable:
	return func(u: float, v: float, p: Vector3) -> Color:
		var x := absf(u * 2.0 - 1.0)
		var c := base.lerp(tip, clampf(v * 0.9 + x * 0.35 - 0.1, 0.0, 1.0))
		if x < rib:
			c = c.lerp(base.lightened(0.35), (1.0 - x / rib) * 0.7)
		return _nz(c, p, 0.1, 30.0)


## Thin flat disc-like piece with a face pattern (slices, rounds, discs).
## Centred on y=0. face(rn, th, p) colours the cut faces; rim is the skin.
func _slice(R: float, H: float, face: Callable, rim: Color, rf := Callable(), nu := 36, nr := 14) -> void:
	var top := func(rn: float, _th: float) -> float: return H * (0.5 - 0.25 * pow(rn, 10.0))
	var bot := func(rn: float, _th: float) -> float: return -H * (0.5 - 0.25 * pow(rn, 10.0))
	b.dsolid(R, top, bot, func(f: int, rn: float, th: float, p: Vector3) -> Color:
		if f == 2:
			return _nz(rim, p, 0.08, 40.0)
		return face.call(rn, th, p), nu, nr, rf)


## Lays n flat pieces as overlapping shingles that rest on each other.
func _shingle(n: int, R: float, H: float, piece: Callable, step_k := 0.55) -> void:
	var keep := b.xf
	var step := 2.0 * R * step_k
	var al := asin(clampf(H / step, 0.0, 0.6))
	for i in n:
		var x := (i - (n - 1) * 0.5) * step
		var y := R * sin(al) + H * 0.5 * cos(al)
		b.at(Vector3(x, y, 0), Vector3(0, 0, -rad_to_deg(al)), Vector3.ONE, keep)
		piece.call(i)
	b.xf = keep


## Lumpy rounded chunk centred at the origin (dice, mince, crumbs).
func _chunk(size: Vector3, cf, e := 0.45, lump := 0.15, nu := 8, nv := 6) -> void:
	var o := Vector3(rng.randf() * 9.0, rng.randf() * 9.0, rng.randf() * 9.0)
	var k := 3.0 / maxf(size.x, 0.001)
	b.rbox(Vector3.ZERO, size, e, cf, nu, nv, func(p: Vector3) -> Vector3:
		return p * (1.0 + lump * MeshGen.n3(p * k + o)))


## Ceramic bowl centred at origin, base on y=0; returns the inner radius at `level` (0..1).
func _bowl_shell(R: float, H: float, band := Color(0.3, 0.5, 0.75)) -> void:
	var pts := _cr([Vector2(0, 0.012 * R), Vector2(0.5 * R, 0.0), Vector2(0.56 * R, 0.07 * H),
		Vector2(0.8 * R, 0.28 * H), Vector2(0.96 * R, 0.66 * H), Vector2(1.0 * R, 0.96 * H),
		Vector2(0.975 * R, 1.0 * H), Vector2(0.94 * R, 0.96 * H), Vector2(0.9 * R, 0.68 * H),
		Vector2(0.72 * R, 0.3 * H), Vector2(0.4 * R, 0.12 * H), Vector2(0, 0.1 * H)], 2)
	b.mat(0.12, 0.0, 0.0)
	var outer_end := 0.55
	_rev(pts, func(u: float, v: float, p: Vector3) -> Color:
		if v < outer_end and p.y > 0.8 * H and p.y < 0.88 * H:
			return band
		return CERAMIC, 40)


func _bowl_inner_r(R: float, H: float, level: float) -> float:
	return lerpf(0.72 * R, 0.9 * R, clampf((level - 0.3) / 0.38, 0.0, 1.0)) if level < 0.68 else lerpf(0.9 * R, 0.94 * R, (level - 0.68) / 0.28)


# ================================================================ dispatch

func _gen(d: Dictionary, variant: String) -> void:
	var id: String = d["id"]
	var ing: Array = DB.ING[id]
	var oc := Color(ing[3])
	var ic := Color(ing[4])
	var s: float = ing[5] * S * size_fix(id)
	var cut: int = int(d.get("cut", 0))
	_pie_closed = id == "pie" and d.has("flavor") and DB.ING[d["flavor"]][1] != "fruit"
	if d.has("flavor"):
		var fc := Color(DB.ING[d["flavor"]][4])
		if id in ["smoothie", "juice", "milkshake", "pie", "cake", "muffins", "donuts", "porridge", "yogurt", "ice_cream",
				"pancakes", "jelly", "ice_pop", "frozen_yogurt", "mug_cake", "cheesecake", "dal", "spring_rolls"]:
			ic = fc
			if id in ["smoothie", "juice", "milkshake", "jelly", "ice_pop"]:
				oc = fc
		if id == "kebab":
			oc = Color(DB.ING[d["flavor"]][7]) if DB.ING[d["flavor"]].size() > 7 else fc
	match variant:
		"layer":
			_layer(id, cut, oc, ic)
			return
		"bun_bot", "bun_top":
			_bun_half(s, oc, ic, variant == "bun_top", id)
			return
		"dog_open":
			_hotdog_open(oc, ic)
			return
		"wrap", "taco":
			_wrap_shell(oc, variant == "taco")
			return
	if variant.begins_with("bits"):
		_bits(id, cut, s, oc, ic, int(variant.substr(4)))
		return
	if variant.begins_with("sauce|"):
		var parts := variant.split("|")
		var base := DB.new_leaf(parts[1])
		base["cut"] = int(parts[2])
		_sauce_on(ic, base)
		return
	if d.get("coat", "") != "":
		_coated(d)
		return
	if d.get("portion", false):
		_portion(id, oc, ic)
		return
	var shape: String = ing[2]
	var look: String = DB.LOOK.get(id, id)
	var liquid := DB.flag(id, "l")
	if cut >= 3 or (liquid and not DB.flag(id, "i") and cut > 0):
		_bowl_food(s * 0.9, ic, "liquid" if liquid else "puree", look)
	elif cut > 0 and not shape in BOWLS:
		if cut == 1 and d.get("style", "") in ["dice", "free"]:
			_styled_cut(d.get("style", ""), int(d.get("pieces", 0)), s, oc, ic, id)
		else:
			_cut(look, shape, s, oc, ic, cut)
	else:
		_whole(id, shape, s, oc, ic)


## Diced cubes or the chunks a free-hand cut made.
func _styled_cut(style: String, pieces: int, s: float, oc: Color, ic: Color, id: String) -> void:
	var meat: bool = DB.ING[id][1] in ["meat", "fish"]
	var skin := oc if not meat else ic.darkened(0.08)
	if style == "dice":
		_dice(18, 0.32 * s, 0.85 * s, ic, skin, 0.35)
		return
	var n := clampi(pieces, 2, 30)
	var sz := 1.25 * s / pow(float(n), 0.42)
	_dice(n, sz, sz * (0.6 + 0.35 * sqrt(float(n))), ic, skin, 0.55, 1.25)


## Breaded / battered: the plain model inflated under a craggy crumb crust.
func _coated(d: Dictionary) -> void:
	var base := d.duplicate()
	base["coat"] = ""
	base.erase("portion")
	var g := Models.new(null)
	g.begin("coatbase")
	g._gen(base, "")
	var kind: String = d["coat"]
	var cc := Color(DB.COAT_COLOR[kind])
	var crumb: bool = kind in ["crumb", "panko"]
	var bb := g.b.aabb()
	var c := bb.get_center()
	var th := minf(0.006, maxf(bb.size.y, 0.01) * 0.12)
	for i in g.b.verts.size():
		var p: Vector3 = g.b.verts[i]
		var dir := p - c
		dir.y *= 0.6
		dir = dir.normalized() if dir.length() > 0.0001 else Vector3.UP
		var bump := th * (0.6 + (0.9 * MeshGen.n3(p * 260.0) if crumb else 0.25 * MeshGen.n3(p * 70.0)))
		g.b.verts[i] = p + dir * bump
		g.b.cols[i] = _nz(cc, p, 0.28 if crumb else 0.1, 200.0 if crumb else 60.0)
	b.append(g.b, Transform3D.IDENTITY)


## A poured/scooped amount of a shop ingredient (no packet): puddle, heap, dollop or scoop.
func _portion(id: String, oc: Color, ic: Color) -> void:
	var shape: String = DB.ING[id][2]
	var R := 0.055
	if DB.flag(id, "l"):
		b.mat(0.06, 0.05, 0.4)
		b.dsolid(R, func(rn: float, _th: float) -> float: return 0.006 * (1.0 - pow(rn, 6.0)) + 0.001,
			func(_rn: float, _th: float) -> float: return 0.0,
			func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(ic, p, 0.04, 80.0), 28, 4,
			func(th: float) -> float: return 1.0 + 0.16 * sin(th * 3.0 + 1.0) + 0.07 * sin(th * 7.0))
		return
	if DB.is_dust(id) or shape == "sack":
		b.mat(0.9, 0.6)
		b.dsolid(R * 0.8, func(rn: float, th: float) -> float: return 0.03 * pow(1.0 - rn, 1.4) + 0.002 * MeshGen.n3(Vector3(cos(th), 0, sin(th)) * rn * 9.0),
			func(_rn: float, _th: float) -> float: return 0.0,
			func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(ic, p, 0.22, 400.0), 24, 6)
		return
	if shape == "can" or id in ["peanuts", "almonds", "walnuts", "cashews", "raisins", "olives", "capers", "pickles"]:
		b.mat(0.4, 0.3)
		var r := 0.012 if id != "pickles" else 0.02
		b.heap(16, R * 0.7, r * 0.6, r * 1.2, func(i: int) -> void:
			b.blob(Vector3.ZERO, Vector3(r, r * 0.75, r * 0.85), oc.lerp(ic, MeshGen.h1(i) * 0.6), 8, 6), 7)
		return
	# spreads, tubs, pastes: a soft dollop/scoop
	b.mat(0.3, 0.3)
	b.blob(Vector3(0, 0.022, 0), Vector3(0.04, 0.024, 0.038), func(_u: float, _v: float, p: Vector3) -> Color: return _nz(ic, p, 0.06, 90.0), 16, 10,
		func(th: float, v: float, _dd: Vector3) -> float: return 1.0 + 0.1 * sin(th * 5.0 + v * 4.0))


# ================================================================ whole ingredients

func _whole(id: String, shape: String, s: float, oc: Color, ic: Color) -> void:
	var pid := id
	id = DB.LOOK.get(id, id)
	match id:
		"tomato": _tomato(s, oc)
		"onion": _onion(s, oc)
		"garlic": _garlic(s, oc)
		"potato": _potato(s, oc)
		"ginger": _ginger(s, oc)
		"carrot": _carrot(s, oc)
		"lettuce": _lettuce(s, oc, ic)
		"spinach": _spinach(s, oc, ic)
		"cabbage": _cabbage(s, oc, ic)
		"cucumber", "zucchini": _cucumber(s, oc, id == "zucchini")
		"bell_pepper": _pepper(s, oc)
		"chili": _chili(s, oc)
		"mushroom": _mushroom(s, oc, ic)
		"broccoli": _broccoli(s, oc, ic)
		"corn": _corn(s, oc)
		"eggplant": _eggplant(s, oc)
		"pumpkin": _pumpkin(s, oc)
		"scallion": _scallion(s, oc, ic)
		"basil": _basil(s, oc)
		"avocado": _avocado(s, oc)
		"lemon", "lime": _citrus(s, oc, id == "lime")
		"orange": _orange(s, oc)
		"apple": _apple(s, oc)
		"banana": _banana(s, oc)
		"strawberry": _strawberry(s, oc)
		"blueberry": _blueberries(s, oc)
		"pineapple": _pineapple(s, oc)
		"mango": _mango(s, oc)
		"chicken": _drumstick(s, oc)
		"beef": _steak(s, oc, ic)
		"ground_beef": _mince(s, oc, ic)
		"bacon": _bacon(s, oc, ic)
		"sausage": _sausage(s, oc, pid == "frankfurter")
		"ham": _ham(s, oc, ic)
		"pepperoni": _pepperoni(s, oc)
		"salmon", "white_fish": _fillet(s, oc, ic, id == "salmon")
		"shrimp": _shrimp(s, oc, ic)
		"tofu": _tofu(s, oc)
		"egg", "boiled_egg": _egg(s, oc)
		"milk", "cream", "broth": _carton(s, pid, oc)
		"butter": _butter(s, oc)
		"cheese", "parmesan": _wedge(s, oc, id == "parmesan")
		"mozzarella": _mozzarella(s, oc)
		"yogurt", "ice_cream": _tub(s, oc, ic, id == "ice_cream")
		"flour", "sugar", "breadcrumbs", "rice": _bag(s, pid, ic)
		"oats": _canister(s, ic)
		"pasta": _spaghetti(s, oc)
		"noodles": _noodle_brick(s, oc)
		"bread", "bread_loaf": _loaf(s, oc, ic, id == "bread_loaf")
		"bun": _bun(s, oc, ic)
		"hot_dog_bun": _hotdog_bun(s, oc, ic)
		"bagel": _bagel(s, oc, ic)
		"croissant": _croissant(s, oc)
		"kebab": _skewer(s, oc, ic)
		"ice_pop": _icepop(s, oc)
		"tortilla": _tortillas(s, oc)
		"nori": _nori(s, oc)
		"chickpeas", "beans", "coconut_milk": _can(s, pid, ic)
		"salt": _salt(s)
		"black_pepper": _mill(s)
		"herbs", "curry_powder", "cinnamon": _spice_jar(s, pid, ic)
		"vanilla", "oil", "soy_sauce", "maple_syrup": _bottle(s, id, oc)
		"ketchup", "mustard": _squeeze(s, id, oc)
		"honey", "jam", "peanut_butter", "sprinkles": _jar(s, pid, oc)
		"chocolate": _choc_bar(s, oc)
		"marshmallow": _marshmallows(s, oc)
		"fried_egg": _fried_egg(s)
		"scrambled_eggs": _scrambled(s, oc)
		"cookie_dough", "dough": _dough(s, oc, id == "cookie_dough")
		"patty": _patty(s, oc)
		"meatballs": _meatballs(s, oc)
		"mashed_potato": _mash(s, oc)
		"fries": _fries(s, oc)
		"crisps", "tortilla_chips": _chips(s, oc, id == "tortilla_chips")
		"steamed_rice": _rice_mound(s, oc)
		"cooked_pasta", "cooked_noodles": _noodle_pile(s, oc, id == "cooked_noodles")
		"popcorn": _popcorn(s, oc)
		"toast", "french_toast": _toast(s, oc, ic, id == "french_toast")
		"grilled_cheese": _grilled_cheese(s, oc, ic)
		"pizza": _pizza(s, oc, ic, false)
		"pie": _pie(s, oc, ic, false)
		"cake": _cake(s, oc, ic, false)
		"batter", "cake_batter", "mayo", "pesto": _bowl_food(s, ic, "puree", id)
		"beaten_egg", "tomato_sauce", "caramel", "melted_chocolate": _bowl_food(s, ic, "liquid", id)
		"muffins": _muffins(s, oc, ic)
		"cookies": _cookies(s, oc, ic)
		"pancakes": _pancakes(s, oc, ic)
		"donuts": _donuts(s, oc, ic)
		"smoothie", "juice", "milkshake", "lemonade": _drink(s, id, oc)
		"hot_chocolate": _mug(s, oc)
		"whipped_cream": _bowl_food(s, oc, "whip", id)
		"salsa": _bowl_food(s, oc, "chunks", id)
		"guacamole", "hummus", "porridge": _bowl_food(s, ic, "thick", id)
		_:
			if shape == "bowl" or shape == "bowlmound" or shape == "bowlchunks":
				_bowl_food(s, ic, "liquid", id)
			else:
				b.mat(0.5, 0.3)
				b.blob(Vector3(0, s, 0), Vector3.ONE * s, oc, 16, 10)


# ---------------------------------------------------------------- vegetables

func _tomato(s: float, oc: Color) -> void:
	var ry := s * 0.82
	b.mat(0.2, 0.06)
	b.blob(Vector3(0, ry, 0), Vector3(s, ry, s), func(u: float, v: float, p: Vector3) -> Color:
		var t := clampf((p.y - ry) / ry, -1.0, 1.0)
		var c := oc.lerp(Color(0.93, 0.52, 0.2), clampf(t - 0.5, 0.0, 1.0) * 0.8)
		return _nz(c, p, 0.07, 6.0 / s), 30, 18, func(th: float, v: float, _d: Vector3) -> float:
			var lob := 1.0 + 0.05 * cos(5.0 * th) * pow(sin(v * PI), 2.0) * (0.3 + v)
			return lob * (1.0 - 0.3 * exp(-pow((1.0 - v) / 0.13, 2.0)) - 0.12 * exp(-pow(v / 0.1, 2.0))))
	var top := ry + ry * 0.7
	b.mat(0.65, 0.2, 0.4)
	_calyx(Vector3(0, top + s * 0.03, 0), 5, s * 0.5, s * 0.16, Color(0.24, 0.48, 0.16), 0.45, 0.15)
	_stem([Vector3(0, top, 0), Vector3(0, top + s * 0.14, 0), Vector3(s * 0.05, top + s * 0.24, 0)], s * 0.05, s * 0.035, Color(0.3, 0.5, 0.2))


func _onion(s: float, oc: Color) -> void:
	var pts := _cr([Vector2(0, 0.12 * s), Vector2(0.4 * s, 0.07 * s), Vector2(0.85 * s, 0.35 * s), Vector2(1.0 * s, 0.8 * s),
		Vector2(0.88 * s, 1.25 * s), Vector2(0.45 * s, 1.6 * s), Vector2(0.14 * s, 1.8 * s), Vector2(0.07 * s, 2.0 * s), Vector2(0, 2.04 * s)], 3)
	b.mat(0.42, 0.3)
	var dry := oc.darkened(0.35)
	_rev(pts, func(u: float, _v: float, p: Vector3) -> Color:
		var st := 0.5 + 0.5 * sin(u * TAU * 28.0 + MeshGen.n3(p * 6.0 / s) * 4.0)
		var c := _sh(oc, 0.82 + 0.2 * st)
		if p.y > 1.55 * s:
			c = c.lerp(dry, clampf((p.y - 1.55 * s) / (0.3 * s), 0.0, 1.0))
		if p.y < 0.25 * s:
			c = c.lerp(Color(0.75, 0.62, 0.42), 1.0 - p.y / (0.25 * s))
		return c, 30, func(th: float, v: float) -> float: return 1.0 + 0.025 * sin(th * 3.0 + v * 5.0))
	b.mat(0.8, 0.2, 0.5)
	for i in 10:
		var a := TAU * i / 10.0 + rng.randf()
		var d := Vector3(cos(a), 0, sin(a))
		_stem([Vector3(0, 0.12 * s, 0), d * 0.12 * s + Vector3(0, 0.04 * s, 0), d * 0.22 * s + Vector3(0, 0.012 * s, 0)], 0.018 * s, 0.01 * s, Color(0.8, 0.72, 0.55), 3, 3)
	_stem([Vector3(0, 1.98 * s, 0), Vector3(0.04 * s, 2.15 * s, 0), Vector3(0.12 * s, 2.25 * s, 0.02 * s)], 0.05 * s, 0.02 * s, dry, 5)


func _garlic(s: float, oc: Color) -> void:
	var pts := _cr([Vector2(0, 0.1 * s), Vector2(0.5 * s, 0.04 * s), Vector2(0.95 * s, 0.4 * s), Vector2(0.97 * s, 0.75 * s),
		Vector2(0.62 * s, 1.15 * s), Vector2(0.2 * s, 1.45 * s), Vector2(0.08 * s, 1.75 * s), Vector2(0, 1.8 * s)], 3)
	b.mat(0.5, 0.2)
	var purple := Color(0.72, 0.52, 0.66)
	_rev(pts, func(u: float, _v: float, p: Vector3) -> Color:
		var st := pow(0.5 + 0.5 * sin(u * TAU * 22.0 + MeshGen.n3(p * 5.0 / s) * 3.0), 5.0)
		var c := oc.lerp(purple, st * clampf(1.0 - p.y / (1.2 * s), 0.0, 1.0) * 0.55)
		if p.y > 1.4 * s:
			c = c.lerp(Color(0.82, 0.74, 0.58), 0.6)
		return _nz(c, p, 0.04, 9.0 / s), 32, func(th: float, v: float) -> float:
			var k := sin(PI * clampf(v * 1.6, 0.0, 1.0))
			return 1.0 - 0.1 * k * pow(absf(sin(th * 4.0 + 0.4)), 1.5))
	b.mat(0.8, 0.2, 0.5)
	for i in 8:
		var a := TAU * i / 8.0 + rng.randf()
		var d := Vector3(cos(a), 0, sin(a))
		_stem([Vector3(0, 0.1 * s, 0), d * 0.1 * s + Vector3(0, 0.03 * s, 0), d * 0.18 * s + Vector3(0, 0.01 * s, 0)], 0.016 * s, 0.01 * s, Color(0.78, 0.7, 0.55), 3, 3)


func _potato(s: float, oc: Color) -> void:
	var eyes := []
	for i in 6:
		eyes.append(Vector3(rng.randf() - 0.5, rng.randf() - 0.5, rng.randf() - 0.5).normalized())
	var off := Vector3(rng.randf() * 10.0, 3.0, 1.0)
	var eye_k := func(d: Vector3) -> float:
		var e := 0.0
		for ev in eyes:
			e = maxf(e, exp(-(1.0 - d.dot(ev)) / 0.006))
		return e
	b.mat(0.85, 0.7)
	b.blob(Vector3(0, 0.66 * s, 0), Vector3(1.25 * s, 0.7 * s, 0.9 * s), func(_u: float, _v: float, p: Vector3) -> Color:
		var q := (p - Vector3(0, 0.66 * s, 0)) / Vector3(1.25 * s, 0.7 * s, 0.9 * s)
		var c := _nz(oc, p, 0.12, 4.0 / s)
		if MeshGen.n3(p * 30.0 / s) > 0.5:
			c = _sh(c, 0.78)
		return c.lerp(oc.darkened(0.45), eye_k.call(q.normalized()) * 0.8), 26, 16, func(_th: float, _v: float, d: Vector3) -> float:
			return 1.0 + 0.08 * MeshGen.n3(d * 1.4 + off) + 0.03 * MeshGen.n3(d * 4.0 + off) - 0.06 * eye_k.call(d))


func _ginger(s: float, oc: Color) -> void:
	b.mat(0.75, 0.6)
	var cf := func(_u: float, _v: float, p: Vector3) -> Color:
		var ring := pow(absf(sin(p.x * 22.0 / s + MeshGen.n3(p * 6.0 / s))), 24.0)
		return _nz(oc, p, 0.12, 6.0 / s).lerp(oc.darkened(0.4), ring * 0.7)
	var lump := func(_th: float, _v: float, d: Vector3) -> float: return 1.0 + 0.1 * MeshGen.n3(d * 2.0)
	b.blob(Vector3(0, 0.5 * s, 0), Vector3(1.5 * s, 0.5 * s, 0.6 * s), cf, 22, 12, lump)
	for k in [[Vector3(0.9, 0.85, 0.3), 0.45], [Vector3(-0.7, 0.8, -0.3), 0.4], [Vector3(0.1, 0.9, 0.55), 0.38], [Vector3(-1.4, 0.55, 0.3), 0.35]]:
		var r: float = k[1] * s
		b.blob((k[0] as Vector3) * s, Vector3(r * 1.1, r, r * 0.9), cf, 14, 9, lump)


func _carrot(s: float, oc: Color) -> void:
	var L := 2.3 * s
	var R := 0.3 * s
	var rad := func(t: float, th: float) -> float:
		var r := R * sqrt(clampf(t / 0.04, 0.0, 1.0)) * pow(1.0 - t, 0.72)
		return r * (1.0 - 0.07 * pow(absf(sin(t * 58.0)), 12.0)) * (1.0 + 0.04 * MeshGen.n3(Vector3(t * 30.0, cos(th), sin(th))))
	b.mat(0.5, 0.35)
	b.tube(34, 14, func(t: float) -> Vector3:
		return Vector3(-L * 0.5 + L * t, R * pow(1.0 - t, 0.72) + 0.002, sin(t * PI) * 0.06 * s), rad,
		func(_u: float, v: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.08, 8.0 / s)
			c = c.lerp(oc.darkened(0.25), pow(absf(sin(v * 58.0)), 12.0) * 0.6)
			if v < 0.05:
				c = c.lerp(Color(0.45, 0.5, 0.15), (1.0 - v / 0.05) * 0.6)
			return c)
	b.mat(0.6, 0.15, 0.5)
	var base := Vector3(-L * 0.5, R * 0.95, 0)
	for i in 5:
		var a := (i - 2) * 0.32
		var tip := base + Vector3(-cos(a) * 0.95 * s, 0.25 * s + absf(a) * 0.1 * s, sin(a) * 0.8 * s)
		var mid := base.lerp(tip, 0.5) + Vector3(0, 0.12 * s, 0)
		_stem([base, mid, tip], 0.03 * s, 0.015 * s, Color(0.36, 0.55, 0.22), 4, 6)
		for j in 3:
			var t := 0.45 + j * 0.25
			var pp: Vector3 = _path([base, mid, tip], t)
			var dir := (tip - base).normalized() + Vector3(0, 0.0, 0.5 if j % 2 == 0 else -0.5)
			b.leaf(pp, dir, 0.4 * s, 0.22 * s, _leafcol(Color(0.3, 0.55, 0.2), DARK_LEAF.lightened(0.1)), 0.1, 0.25, 0.1, 0.3, 0.45, 5, 6)


func _lettuce(s: float, oc: Color, ic: Color) -> void:
	b.mat(0.5, 0.45)
	b.blob(Vector3(0, 0.7 * s, 0), Vector3(0.72 * s, 0.66 * s, 0.72 * s), func(_u: float, _v: float, p: Vector3) -> Color:
		return _nz(ic.lerp(oc, 0.25), p, 0.08, 8.0 / s), 18, 12)
	for i in 18:
		var k := i / 17.0
		var a := i * 2.39996
		var r := Vector3(cos(a), 0, sin(a))
		var lean := lerpf(0.95, 0.3, k)
		var dir := r * lean + Vector3.UP * (1.0 - 0.35 * lean)
		var dark := oc.darkened(0.12).lerp(ic, k * 0.7)
		b.leaf(r * lerpf(0.32, 0.12, k) * s + Vector3(0, 0.04 * s + k * 0.22 * s, 0), dir, s * lerpf(1.35, 1.0, k), s * lerpf(1.9, 1.3, k),
			_leafcol(ic.lightened(0.1), dark, 0.08), lerpf(0.42, 0.5, k), 0.0, lerpf(0.55, 0.85, k), lerpf(0.11, 0.05, k), 0.62, 10, 10)


func _spinach(s: float, oc: Color, ic: Color) -> void:
	b.mat(0.32, 0.3)
	var root := Vector3(-0.95 * s, 0.03 * s, 0)
	for i in 9:
		var a := (i - 4) * 0.17 + (rng.randf() - 0.5) * 0.1
		var d := Vector3(cos(a), 0, sin(a))
		var y := 0.02 * s + (i % 3) * 0.035 * s
		var start := root + d * 0.45 * s + Vector3(0, y, 0)
		_stem([root, root.lerp(start, 0.5) + Vector3(0, y * 0.5, 0), start], 0.035 * s, 0.03 * s, ic.lightened(0.25), 5, 4)
		b.leaf(start, d + Vector3(0, 0.1, 0), s * lerpf(1.0, 1.25, MeshGen.h1(i)), s * 0.8,
			_leafcol(ic, oc, 0.05), 0.12, 0.15, 0.22, 0.03, 0.5, 8, 9)


func _cabbage(s: float, oc: Color, ic: Color) -> void:
	b.mat(0.45, 0.35)
	var cy := 0.88 * s
	var head := ic.lerp(oc, 0.6).lerp(Color(0.45, 0.68, 0.35), 0.35)
	b.blob(Vector3(0, cy, 0), Vector3(0.95 * s, 0.86 * s, 0.95 * s), func(u: float, v: float, p: Vector3) -> Color:
		var vein := pow(absf(sin(u * TAU * 4.0 + v * 3.0 + MeshGen.n3(p * 4.0 / s) * 1.5)), 40.0)
		return _nz(head, p, 0.08, 5.0 / s).lerp(Color(0.92, 0.96, 0.82), vein * 0.7), 36, 20,
		func(th: float, v: float, d: Vector3) -> float:
			return 1.0 + 0.012 * pow(absf(sin(th * 4.0 + v * 3.0 + MeshGen.n3(d * 4.0) * 1.5)), 40.0) - 0.06 * exp(-pow((1.0 - v) / 0.1, 2.0)))
	for i in 6:
		var a := TAU * i / 6.0 + 0.4
		var r := Vector3(cos(a), 0, sin(a))
		b.leaf(r * 0.4 * s + Vector3(0, 0.04 * s, 0), r * 0.7 + Vector3.UP, s * 1.35, s * 1.8, _leafcol(head.lightened(0.15), head.darkened(0.25), 0.07),
			0.12, 0.05, 0.6, 0.06, 0.6, 10, 10)


func _cucumber(s: float, oc: Color, zuc: bool) -> void:
	var L := 2.1 * s
	var R := 0.3 * s
	b.mat(0.3 if zuc else 0.4, 0.35 if zuc else 0.6)
	var rad := func(t: float, th: float) -> float:
		var r := R * pow(sin(PI * clampf(t, 0.0, 1.0)), 0.32) * (lerpf(0.85, 1.08, t) if zuc else 1.0)
		if zuc:
			return r * (1.0 + 0.03 * cos(5.0 * th))
		return r * (1.0 + 0.025 * cos(8.0 * th) + 0.05 * maxf(0.0, MeshGen.n3(Vector3(t * 40.0, cos(th) * 3.0, sin(th) * 3.0)) - 0.3))
	b.tube(30, 18, func(t: float) -> Vector3: return Vector3(-L * 0.5 + L * t, R + 0.003, 0), rad,
		func(u: float, v: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.1, 6.0 / s)
			var stripe := 0.5 + 0.5 * cos(u * TAU * (5.0 if zuc else 8.0))
			c = c.lerp(oc.lightened(0.35), stripe * (0.25 if zuc else 0.35) * (0.5 + absf(v - 0.5)))
			if zuc and MeshGen.n3(p * 40.0 / s) > 0.45:
				c = c.lightened(0.3)
			if not zuc and v > 0.85:
				c = c.lerp(Color(0.75, 0.78, 0.4), (v - 0.85) * 3.0)
			return c)
	if zuc:
		b.mat(0.6, 0.3, 0.6)
		_stem([Vector3(-L * 0.5 + 0.02 * s, R, 0), Vector3(-L * 0.5 - 0.12 * s, R * 1.05, 0), Vector3(-L * 0.5 - 0.2 * s, R * 1.1, 0)], 0.09 * s, 0.07 * s, Color(0.55, 0.55, 0.3), 6)


func _pepper(s: float, oc: Color) -> void:
	var pts := _cr([Vector2(0, 0.18 * s), Vector2(0.45 * s, 0.05 * s), Vector2(0.85 * s, 0.25 * s), Vector2(1.0 * s, 0.8 * s),
		Vector2(0.98 * s, 1.4 * s), Vector2(0.78 * s, 1.75 * s), Vector2(0.38 * s, 1.84 * s), Vector2(0.14 * s, 1.7 * s), Vector2(0, 1.68 * s)], 3)
	b.mat(0.14, 0.05)
	_rev(pts, func(_u: float, _v: float, p: Vector3) -> Color: return _nz(oc, p, 0.08, 5.0 / s), 32,
		func(th: float, t: float) -> float: return 1.0 + 0.12 * cos(4.0 * th) * (0.6 + 0.4 * sin(PI * t)) - 0.04 * pow(absf(sin(2.0 * th)), 8.0),
		func(th: float, t: float) -> float: return -0.12 * s * maxf(0.0, cos(4.0 * th)) * sin(PI * clampf(t / 0.3, 0.0, 1.0)) * float(t < 0.3))
	b.mat(0.5, 0.2, 0.5)
	b.blob(Vector3(0, 1.72 * s, 0), Vector3(0.22 * s, 0.07 * s, 0.22 * s), Color(0.25, 0.45, 0.18), 10, 5)
	_stem([Vector3(0, 1.7 * s, 0), Vector3(0, 1.95 * s, 0), Vector3(0.08 * s, 2.12 * s, 0), Vector3(0.18 * s, 2.18 * s, 0)], 0.09 * s, 0.07 * s, Color(0.3, 0.48, 0.2), 7)


func _chili(s: float, oc: Color) -> void:
	var L := 2.2 * s
	var R := 0.24 * s
	var path := func(t: float) -> Vector3:
		return Vector3(-L * 0.5 + L * t, R + 0.002 + 0.25 * s * pow(t, 3.0) * 0.6, 0.35 * s * sin(t * 2.6))
	b.mat(0.18, 0.12)
	b.tube(30, 12, path, func(t: float, _th: float) -> float:
		return R * sqrt(clampf(t / 0.05, 0.0, 1.0)) * pow(1.0 - t, 0.65) * (1.0 + 0.04 * sin(t * 23.0)),
		func(_u: float, _v: float, p: Vector3) -> Color: return _nz(oc, p, 0.08, 6.0 / s))
	b.mat(0.5, 0.2, 0.5)
	var p0: Vector3 = path.call(0.0)
	b.blob(p0 + Vector3(0.03 * s, 0, 0), Vector3(0.12 * s, 0.24 * s, 0.24 * s), Color(0.28, 0.45, 0.18), 10, 6)
	_stem([p0, p0 + Vector3(-0.25 * s, 0.08 * s, 0), p0 + Vector3(-0.4 * s, 0.25 * s, 0.05 * s)], 0.05 * s, 0.035 * s, Color(0.32, 0.48, 0.2), 6)


func _mushroom(s: float, oc: Color, ic: Color) -> void:
	var gill := ic.darkened(0.35)
	var cap := _cr([Vector2(0, 1.32 * s), Vector2(0.55 * s, 1.26 * s), Vector2(0.92 * s, 1.0 * s), Vector2(1.02 * s, 0.72 * s),
		Vector2(0.95 * s, 0.6 * s), Vector2(0.85 * s, 0.64 * s), Vector2(0.85 * s, 0.64 * s), Vector2(0.55 * s, 0.76 * s), Vector2(0.24 * s, 0.82 * s)], 3)
	b.mat(0.45, 0.25)
	b.lathe(cap, func(u: float, v: float, p: Vector3) -> Color:
		if v > 0.7:
			return gill.lerp(gill.darkened(0.3), pow(absf(sin(u * TAU * 40.0)), 4.0))
		var c := _nz(oc, p, 0.08, 8.0 / s)
		return c.lerp(oc.darkened(0.25), clampf(MeshGen.n3(p * 16.0 / s) - 0.3, 0.0, 1.0)), 32)
	var stem := _cr([Vector2(0.26 * s, 0.84 * s), Vector2(0.24 * s, 0.5 * s), Vector2(0.28 * s, 0.12 * s), Vector2(0.3 * s, 0.0),
		Vector2(0.3 * s, 0.0), Vector2(0, 0.0)], 2)
	b.mat(0.6, 0.3)
	b.lathe(stem, func(_u: float, _v: float, p: Vector3) -> Color: return _nz(ic, p, 0.06, 10.0 / s), 14)


func _broccoli(s: float, oc: Color, ic: Color) -> void:
	b.mat(0.55, 0.3)
	var stalk := _cr([Vector2(0.22 * s, 0.0), Vector2(0.2 * s, 0.4 * s), Vector2(0.28 * s, 0.75 * s), Vector2(0.15 * s, 0.85 * s)], 2)
	b.lathe([Vector2(0, 0.0)] + stalk, func(_u: float, _v: float, p: Vector3) -> Color: return _nz(ic, p, 0.08, 8.0 / s), 12)
	var heads := [Vector3(0, 1.32, 0)]
	for i in 6:
		var a := TAU * i / 6.0 + 0.3
		heads.append(Vector3(cos(a) * 0.55, 1.05 + (i % 2) * 0.1, sin(a) * 0.55))
	for h in heads:
		var hp: Vector3 = h * s
		_stem([Vector3(0, 0.7 * s, 0), (Vector3(0, 0.7 * s, 0) + hp) * 0.5, hp], 0.12 * s, 0.08 * s, ic, 6, 4)
	b.mat(0.75, 1.0)
	for h in heads:
		var hp: Vector3 = h * s
		var o := Vector3(hp.x * 13.0, 0, hp.z * 13.0)
		b.blob(hp, Vector3(0.48 * s, 0.4 * s, 0.48 * s), func(_u: float, _v: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.15, 14.0 / s)
			return c.lerp(ic, clampf((hp.y - p.y) / (0.35 * s), 0.0, 1.0) * 0.6), 16, 10,
			func(_th: float, v: float, d: Vector3) -> float:
				return (1.0 + 0.12 * absf(MeshGen.n3(d * 3.0 + o)) + 0.06 * MeshGen.n3(d * 8.0 + o)) * (0.75 if v < 0.3 else 1.0))


func _corn(s: float, oc: Color) -> void:
	var L := 2.0 * s
	var R := 0.42 * s
	b.mat(0.35, 0.2)
	b.tube(64, 56, func(t: float) -> Vector3: return Vector3(-L * 0.5 + L * t, R + 0.003, 0),
		func(t: float, th: float) -> float:
			var k := pow(absf(sin(th * 7.0)), 0.5) * pow(absf(sin(t * PI * 20.0 + (0.5 if int(floor(th * 7.0 / PI)) % 2 == 0 else 0.0))), 0.5)
			return R * pow(sin(PI * t), 0.3) * (0.92 - 0.12 * t) * (1.0 + 0.08 * k),
		func(u: float, v: float, p: Vector3) -> Color:
			var k := pow(absf(sin(u * TAU * 7.0)), 0.5) * pow(absf(sin(v * PI * 20.0)), 0.5)
			return _nz(oc, p, 0.05, 20.0 / s).lerp(oc.darkened(0.35), (1.0 - k) * 0.6))
	b.mat(0.6, 0.3, 0.5)
	var husk := Color(0.55, 0.7, 0.32)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var off := Vector3(0, cos(a), sin(a)) * R * 0.75
		var base := Vector3(-L * 0.42, R, 0) + off
		b.leaf(base, Vector3(-1.0, 0.0, 0.0) + off.normalized() * 0.7, s * 1.0, s * 0.55, _leafcol(Color(0.82, 0.85, 0.55), husk, 0.05),
			0.0, -0.15, -0.25, 0.05, 0.4, 6, 8, Vector3(1, 0, 0).cross(off.normalized()))
	_stem([Vector3(-L * 0.45, R, 0), Vector3(-L * 0.55, R, 0), Vector3(-L * 0.62, R * 1.05, 0)], 0.16 * s, 0.13 * s, Color(0.6, 0.62, 0.38), 8)


func _eggplant(s: float, oc: Color) -> void:
	var L := 2.2 * s
	var R := 0.55 * s
	var path := func(t: float) -> Vector3:
		return Vector3(-L * 0.5 + L * t, 0.0, 0.25 * s * sin(t * PI * 0.8))
	var rad := func(t: float, _th: float) -> float:
		return R * (0.42 + 0.58 * smoothstep(0.1, 0.75, t)) * pow(sin(PI * clampf(t, 0.0, 1.0)), 0.38)
	b.mat(0.12, 0.08)
	b.tube(30, 18, func(t: float) -> Vector3: return path.call(t) + Vector3(0, rad.call(t, 0.0) + 0.003, 0), rad,
		func(_u: float, _v: float, p: Vector3) -> Color: return _nz(oc, p, 0.12, 4.0 / s))
	b.mat(0.55, 0.35, 0.5)
	var p0: Vector3 = path.call(0.06) + Vector3(0, rad.call(0.06, 0.0), 0)
	for i in 5:
		var a := TAU * i / 5.0
		var d := Vector3(0.8, cos(a), sin(a))
		b.leaf(p0 + Vector3(-0.05 * s, 0, 0), d, s * 0.55, s * 0.32, _leafcol(Color(0.3, 0.45, 0.2), Color(0.22, 0.36, 0.15), 0.05),
			-0.35, 0.0, -0.3, 0.06, 0.35, 4, 6, Vector3.RIGHT.cross(Vector3(0, cos(a), sin(a))))
	_stem([p0, p0 + Vector3(-0.3 * s, 0.04 * s, 0), p0 + Vector3(-0.5 * s, 0.12 * s, 0)], 0.1 * s, 0.08 * s, Color(0.36, 0.48, 0.25), 7)


func _pumpkin(s: float, oc: Color) -> void:
	var ry := 0.75 * s
	b.mat(0.45, 0.3)
	b.blob(Vector3(0, ry, 0), Vector3(s, ry, s), func(u: float, _v: float, p: Vector3) -> Color:
		var g := exp(-pow(sin(u * TAU * 5.0) / 0.3, 2.0))
		return _nz(oc, p, 0.08, 5.0 / s).lerp(oc.darkened(0.3), g * 0.55), 40, 18,
		func(th: float, v: float, _d: Vector3) -> float:
			var g := exp(-pow(sin(th * 5.0) / 0.3, 2.0))
			return (1.0 - 0.1 * g * sin(v * PI)) * (1.0 - 0.32 * exp(-pow((1.0 - v) / 0.14, 2.0)) - 0.15 * exp(-pow(v / 0.12, 2.0))))
	b.mat(0.7, 0.5, 0.4)
	var top := ry * 1.68
	b.tube(6, 10, func(t: float) -> Vector3: return Vector3(0.12 * s * t * t, top + t * 0.38 * s, 0),
		func(t: float, th: float) -> float: return (0.0 if t >= 1.0 else (0.13 * s - 0.03 * s * t) * (1.0 + 0.18 * cos(5.0 * th + t * 2.0))),
		Color(0.45, 0.42, 0.22))


func _scallion(s: float, oc: Color, ic: Color) -> void:
	b.mat(0.4, 0.15)
	var L := 2.0 * s
	for i in 3:
		var z := (i - 1) * 0.12 * s
		var y := 0.07 * s + (0.09 * s if i == 1 else 0.0)
		var cf := func(_u: float, v: float, p: Vector3) -> Color:
			return _nz(ic.lerp(oc, smoothstep(0.18, 0.35, v)), p, 0.06, 20.0 / s)
		b.tube(18, 8, func(t: float) -> Vector3: return Vector3(-L * 0.5 + L * 0.6 * t, y, z + sin(t * 3.0 + i) * 0.02 * s),
			func(t: float, _th: float) -> float: return 0.07 * s * (1.0 + 0.4 * exp(-pow((t - 0.08) / 0.07, 2.0))) * sqrt(clampf(t / 0.03, 0.0, 1.0)), cf)
		for k in 2:
			var a := (k - 0.5) * 0.4 + (i - 1) * 0.15
			var st := Vector3(-L * 0.5 + L * 0.58, y, z)
			b.tube(10, 6, func(t: float) -> Vector3: return st + Vector3(t * L * 0.48, sin(t * 2.5) * 0.06 * s * k, sin(a) * t * 0.5 * s),
				func(t: float, _th: float) -> float: return 0.05 * s * (1.0 - t * 0.6) * (0.0 if t >= 1.0 else 1.0),
				_nz(oc, Vector3(i, k, 0), 0.1, 1.0))
		b.mat(0.8, 0.1, 0.5)
		for k in 5:
			var a := (k - 2) * 0.5
			_stem([Vector3(-L * 0.5, y, z), Vector3(-L * 0.5 - 0.1 * s, y - 0.02 * s, z + sin(a) * 0.06 * s), Vector3(-L * 0.5 - 0.18 * s, 0.01 * s, z + sin(a) * 0.12 * s)], 0.012 * s, 0.008 * s, Color(0.88, 0.85, 0.75), 3, 3)
		b.mat(0.4, 0.15)


func _basil(s: float, oc: Color) -> void:
	b.mat(0.6, 0.15)
	var stem := [Vector3(-1.0 * s, 0.05 * s, 0), Vector3(-0.2 * s, 0.08 * s, 0.05 * s), Vector3(0.7 * s, 0.14 * s, 0)]
	_stem(stem, 0.05 * s, 0.03 * s, Color(0.35, 0.5, 0.22), 5)
	b.mat(0.3, 0.2)
	for i in 4:
		var t := 0.3 + i * 0.22
		var p: Vector3 = _path(stem, t)
		for sd in [-1.0, 1.0]:
			var d := Vector3(0.55, 0.15, sd)
			var ln := s * (0.85 - i * 0.12)
			b.leaf(p, d, ln, ln * 0.65, _leafcol(oc.lightened(0.15), oc, 0.06), 0.25, 0.25, 0.4, 0.0, 0.45, 6, 7)
	b.leaf(_path(stem, 1.0), Vector3(1, 0.3, 0), s * 0.45, s * 0.3, _leafcol(oc.lightened(0.15), oc, 0.06), 0.4, 0.1, 0.5, 0.0, 0.45, 5, 6)


# ---------------------------------------------------------------- fruit

func _avocado(s: float, oc: Color) -> void:
	var pts := _cr([Vector2(0, 0.06 * s), Vector2(0.6 * s, 0.12 * s), Vector2(0.88 * s, 0.6 * s), Vector2(0.82 * s, 1.05 * s),
		Vector2(0.55 * s, 1.55 * s), Vector2(0.38 * s, 1.85 * s), Vector2(0, 1.98 * s)], 3)
	b.mat(0.62, 1.2)
	var o := Vector3(rng.randf() * 5.0, 0, 0)
	_rev(pts, func(_u: float, _v: float, p: Vector3) -> Color:
		var c := _nz(oc, p, 0.25, 9.0 / s)
		if MeshGen.n3(p * 40.0 / s) > 0.5:
			c = c.lightened(0.25)
		return c, 28, func(th: float, v: float) -> float:
			return 1.0 + 0.035 * MeshGen.n3(Vector3(cos(th), v * 3.0, sin(th)) * 4.0 + o))
	b.mat(0.7, 0.3, 0.3)
	_stem([Vector3(0, 1.95 * s, 0), Vector3(0, 2.05 * s, 0.02 * s)], 0.06 * s, 0.05 * s, Color(0.35, 0.25, 0.15), 5)


func _citrus(s: float, oc: Color, lime: bool) -> void:
	var R := Vector3(1.0 if lime else 1.12, 0.82 if lime else 0.8, 0.82 if lime else 0.8) * s
	b.mat(0.32, 0.9)
	b.blob(Vector3(0, R.y, 0), R, func(_u: float, _v: float, p: Vector3) -> Color:
		return _nz(oc, p, 0.07, 7.0 / s).lerp(oc.lightened(0.2), clampf(MeshGen.n3(p * 3.0 / s), 0.0, 1.0) * 0.4), 26, 16,
		func(th: float, v: float, d: Vector3) -> float:
			var tip := pow(absf(d.x), 40.0)
			return 1.0 + (0.06 if lime else 0.16) * tip * (1.0 if d.x > 0.0 else 0.7))
	b.mat(0.7, 0.3, 0.5)
	b.blob(Vector3(-R.x * 0.98, R.y, 0), Vector3(0.05, 0.08, 0.08) * s, Color(0.45, 0.5, 0.2), 8, 5)


func _orange(s: float, oc: Color) -> void:
	b.mat(0.42, 1.1)
	b.blob(Vector3(0, 0.95 * s, 0), Vector3(s, 0.95 * s, s), func(_u: float, _v: float, p: Vector3) -> Color:
		return _nz(oc, p, 0.07, 6.0 / s), 26, 16, func(_th: float, v: float, _d: Vector3) -> float:
			return 1.0 - 0.05 * exp(-pow((1.0 - v) / 0.08, 2.0)) - 0.04 * exp(-pow(v / 0.08, 2.0)))
	b.mat(0.6, 0.3, 0.4)
	b.blob(Vector3(0, 1.82 * s, 0), Vector3(0.1, 0.05, 0.1) * s, Color(0.45, 0.5, 0.22), 8, 5)


func _apple(s: float, oc: Color) -> void:
	var ry := 0.88 * s
	var o := Vector3(rng.randf() * 7.0, 0, 0)
	var yellow := Color(0.95, 0.78, 0.35)
	b.mat(0.28, 0.1)
	b.blob(Vector3(0, ry, 0), Vector3(s, ry, s), func(_u: float, v: float, p: Vector3) -> Color:
		var st := MeshGen.n3(Vector3(p.x * 9.0 / s, p.y * 1.5 / s, p.z * 9.0 / s) + o) * 0.5 + 0.5
		var c := oc.lerp(yellow, clampf(st * 0.6 + (0.4 - v) * 0.6, 0.0, 1.0) * 0.55)
		if MeshGen.n3(p * 45.0 / s) > 0.62:
			c = c.lerp(yellow.lightened(0.3), 0.5)
		return c, 28, 18, func(th: float, v: float, _d: Vector3) -> float:
			var w := (0.92 + 0.12 * v) * (1.0 + 0.03 * cos(5.0 * th) * (1.0 - v))
			return w * (1.0 - 0.32 * exp(-pow((1.0 - v) / 0.13, 2.0)) - 0.16 * exp(-pow(v / 0.1, 2.0))))
	var top := ry + ry * 0.68
	b.mat(0.7, 0.2, 0.3)
	_stem([Vector3(0, top - 0.05 * s, 0), Vector3(0.02 * s, top + 0.15 * s, 0), Vector3(0.08 * s, top + 0.32 * s, 0)], 0.04 * s, 0.03 * s, Color(0.4, 0.28, 0.15), 5)
	b.mat(0.4, 0.1, 0.3)
	b.leaf(Vector3(0.03 * s, top + 0.18 * s, 0), Vector3(1, 0.3, 0.3), s * 0.6, s * 0.3, _leafcol(LEAF.lightened(0.2), LEAF), 0.1, 0.2, 0.3, 0.0, 0.45, 5, 6)


func _banana(s: float, oc: Color) -> void:
	var A := 1.3 * s
	var R := 0.27 * s
	var path := func(t: float) -> Vector3:
		var a := (t - 0.5) * 1.5
		return Vector3(sin(a) * A, (1.0 - cos(a)) * A * 0.75, 0)
	var rad := func(t: float, th: float) -> float:
		var r := R * pow(sin(PI * clampf((t - 0.04) / 0.94, 0.0, 1.0)), 0.45)
		if t < 0.14:
			r = lerpf(R * 0.32, r, smoothstep(0.06, 0.14, t))
		if t < 0.02:
			r = R * 0.3 * (1.0 if t > 0.0 else 0.0)
		return r * (1.0 + 0.07 * cos(5.0 * th))
	b.mat(0.42, 0.15)
	var dk := Color(0.28, 0.2, 0.1)
	b.tube(34, 15, func(t: float) -> Vector3: return path.call(t) + Vector3(0, R + 0.003, 0), rad,
		func(_u: float, v: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.06, 6.0 / s)
			if v < 0.12:
				c = c.lerp(Color(0.6, 0.65, 0.25), (1.0 - v / 0.12) * 0.8)
			if v < 0.03 or v > 0.97:
				c = dk
			if MeshGen.n3(p * 35.0 / s) > 0.6:
				c = c.lerp(Color(0.45, 0.3, 0.12), 0.7)
			return c)


func _strawberry(s: float, oc: Color) -> void:
	var pts := _cr([Vector2(0, 0), Vector2(0.4 * s, 0.25 * s), Vector2(0.78 * s, 0.85 * s), Vector2(0.86 * s, 1.25 * s),
		Vector2(0.6 * s, 1.58 * s), Vector2(0.2 * s, 1.68 * s), Vector2(0, 1.64 * s)], 4)
	var seed := func(th: float, t: float) -> float:
		var row := t * 16.0
		var ri := floorf(row)
		var col := th / TAU * 13.0 + (0.5 if int(ri) % 2 == 1 else 0.0)
		var d := Vector2(row - ri - 0.5, col - floor(col) - 0.5).length()
		return exp(-d * d / 0.03) * float(t < 0.86 and t > 0.06)
	var keep := b.xf
	b.at(Vector3(0, 0.85 * s, 0), Vector3(0, 0, 75), Vector3.ONE)
	b.xf = keep * b.xf * Transform3D(Basis.IDENTITY, Vector3(0, -0.85 * s, 0))
	b.mat(0.3, 0.15)
	_rev(pts, func(u: float, v: float, p: Vector3) -> Color:
		var c := _nz(oc, p, 0.08, 6.0 / s)
		if v > 0.86:
			c = c.lerp(Color(0.95, 0.9, 0.75), (v - 0.86) * 4.0)
		return c.lerp(Color(0.95, 0.85, 0.35), seed.call(u * TAU, v) * 0.85), 52,
		func(th: float, v: float) -> float: return 1.0 - 0.04 * seed.call(th, v))
	b.mat(0.55, 0.2, 0.4)
	_calyx(Vector3(0, 1.66 * s, 0), 7, s * 0.6, s * 0.2, Color(0.28, 0.52, 0.2), 0.55, 0.1)
	_stem([Vector3(0, 1.6 * s, 0), Vector3(0, 1.85 * s, 0), Vector3(0.05 * s, 2.0 * s, 0)], 0.05 * s, 0.035 * s, Color(0.3, 0.5, 0.22), 5)
	b.xf = keep


func _blueberries(s: float, oc: Color) -> void:
	var r := 0.42 * s
	var spots := []
	for i in 6:
		var a := TAU * i / 6.0
		spots.append(Vector3(cos(a) * r * 2.05, r, sin(a) * r * 2.05))
	spots.append(Vector3(0, r, 0))
	for i in 3:
		var a := TAU * i / 3.0 + 0.5
		spots.append(Vector3(cos(a) * r * 1.18, r * 2.62, sin(a) * r * 1.18))
	b.mat(0.55, 0.2)
	var bloom := oc.lerp(Color(0.62, 0.66, 0.8), 0.45)
	for c in spots:
		var cc: Vector3 = c
		b.blob(cc, Vector3(r, r * 0.9, r), func(_u: float, v: float, p: Vector3) -> Color:
			var col := oc.lerp(bloom, clampf(MeshGen.n3(p * 20.0 / s) * 0.5 + 0.5, 0.0, 1.0) * 0.8)
			return col.lerp(Color(0.12, 0.1, 0.2), smoothstep(0.88, 0.95, v)), 14, 9,
			func(th: float, v: float, _d: Vector3) -> float:
				return 1.0 - 0.2 * smoothstep(0.88, 1.0, v) * (0.7 + 0.3 * cos(5.0 * th)))


func _pineapple(s: float, oc: Color) -> void:
	var R := Vector3(0.78 * s, 1.0 * s, 0.78 * s)
	var cell := func(th: float, v: float) -> float:
		var a := th / TAU * 9.0 + v * 7.0
		var c := th / TAU * 9.0 - v * 7.0
		var d := maxf(absf(a - floor(a) - 0.5), absf(c - floor(c) - 0.5))
		return 1.0 - smoothstep(0.2, 0.5, d)
	b.mat(0.6, 0.5)
	b.blob(Vector3(0, R.y, 0), R, func(u: float, v: float, p: Vector3) -> Color:
		var k: float = cell.call(u * TAU, v)
		var c := Color(0.42, 0.3, 0.12).lerp(oc, smoothstep(0.1, 0.5, k))
		c = c.lerp(Color(0.55, 0.58, 0.25), smoothstep(0.75, 1.0, k) * 0.6)
		return _nz(c, p, 0.08, 10.0 / s), 54, 30,
		func(th: float, v: float, _d: Vector3) -> float:
			return (1.0 + 0.05 * cell.call(th, v)) * (1.0 - 0.15 * exp(-pow((1.0 - v) / 0.1, 2.0))) * (0.92 if v < 0.06 else 1.0))
	b.mat(0.5, 0.2, 0.3)
	var top := R.y * 1.88
	for i in 16:
		var a := i * 2.39996
		var k := i / 15.0
		var d := Vector3(cos(a) * lerpf(0.6, 0.15, k), 1.0, sin(a) * lerpf(0.6, 0.15, k))
		b.leaf(Vector3(cos(a) * 0.05 * s, top, sin(a) * 0.05 * s), d, s * lerpf(1.0, 1.4, k), s * 0.2,
			_leafcol(Color(0.42, 0.55, 0.32), Color(0.25, 0.45, 0.32), 0.04), 0.0, lerpf(0.5, 0.15, k), 0.3, 0.0, 0.25, 4, 7)


func _mango(s: float, oc: Color) -> void:
	b.mat(0.3, 0.1)
	b.blob(Vector3(0, 0.78 * s, 0), Vector3(0.95 * s, 0.78 * s, 1.18 * s), func(_u: float, _v: float, p: Vector3) -> Color:
		var c := Color(0.45, 0.6, 0.2).lerp(oc, smoothstep(-0.9 * s, 0.4 * s, p.z))
		c = c.lerp(Color(0.85, 0.25, 0.2), smoothstep(0.9 * s, 1.5 * s, p.y + p.z * 0.4) * 0.8)
		return _nz(c, p, 0.05, 6.0 / s), 26, 16,
		func(_th: float, _v: float, d: Vector3) -> float: return 1.0 + 0.1 * d.z * d.y - 0.06 * absf(d.x) * d.y)
	b.mat(0.6, 0.2, 0.3)
	_stem([Vector3(0, 1.45 * s, -0.75 * s), Vector3(0, 1.55 * s, -0.85 * s)], 0.05 * s, 0.04 * s, Color(0.35, 0.28, 0.15), 5)


# ---------------------------------------------------------------- meat & fish

## Smoothly interpolated keyed value: keys = [Vector2(t, value)...] sorted by t.
static func _keys(keys: Array, t: float) -> float:
	if t <= (keys[0] as Vector2).x:
		return (keys[0] as Vector2).y
	for i in range(1, keys.size()):
		var k1: Vector2 = keys[i]
		if t <= k1.x:
			var k0: Vector2 = keys[i - 1]
			return lerpf(k0.y, k1.y, smoothstep(k0.x, k1.x, t))
	return (keys[keys.size() - 1] as Vector2).y


func _drumstick(s: float, oc: Color) -> void:
	var L := 2.6 * s
	var R := 0.62 * s
	var keys := [Vector2(0, 0), Vector2(0.03, 0.62), Vector2(0.13, 0.96), Vector2(0.3, 1.0), Vector2(0.5, 0.7),
		Vector2(0.62, 0.3), Vector2(0.67, 0.2), Vector2(0.86, 0.17), Vector2(0.92, 0.29), Vector2(0.97, 0.25), Vector2(1.0, 0.0)]
	var bone := Color(0.95, 0.9, 0.8, 0.25)
	b.mat(0.42, 0.75)
	b.tube(40, 20, func(t: float) -> Vector3: return Vector3(-L * 0.5 + L * t, lerpf(R, 0.3 * R, t) + 0.003, 0),
		func(t: float, th: float) -> float:
			return R * _keys(keys, t) * (1.0 + 0.04 * MeshGen.n3(Vector3(t * 8.0, cos(th), sin(th)) * 2.0)) * (1.0 - 0.08 * float(sin(th) < 0.0) * absf(sin(th))),
		func(_u: float, v: float, p: Vector3) -> Color:
			if v > 0.64:
				return bone.lerp(Color(0.85, 0.75, 0.62, 0.25), clampf(MeshGen.n3(p * 30.0 / s), 0.0, 1.0))
			var c := _nz(oc, p, 0.1, 9.0 / s)
			return c.lerp(oc.lightened(0.15), clampf(MeshGen.n3(p * 25.0 / s), 0.0, 1.0) * 0.6))


func _steak(s: float, oc: Color, _ic: Color) -> void:
	var R := 1.05 * s
	var H := 0.42 * s
	var fat := Color(0.96, 0.9, 0.8)
	var o := Vector3(rng.randf() * 9.0, 0, 0)
	var rf := func(th: float) -> float:
		return 1.0 + 0.09 * cos(2.0 * th + 0.3) + 0.06 * sin(3.0 * th + 1.0) + 0.04 * MeshGen.n3(Vector3(cos(th), sin(th), 0) * 2.0 + o)
	var keep := b.xf
	b.at(Vector3.ZERO, Vector3.ZERO, Vector3(1.22, 1.0, 0.85))
	b.mat(0.42, 0.35)
	b.dsolid(R, func(rn: float, _th: float) -> float: return H * (1.0 - 0.32 * pow(rn, 7.0)),
		func(rn: float, _th: float) -> float: return H * 0.12 * pow(rn, 7.0),
		func(f: int, rn: float, th: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.08, 9.0 / s)
			var side := 0.5 + 0.5 * cos(th - 2.2)
			var cap := smoothstep(0.55, 0.85, side) * (1.0 if f == 2 else smoothstep(0.8, 0.92, rn))
			var vein := 1.0 - smoothstep(0.012, 0.04, absf(MeshGen.n3(Vector3(p.x * 9.0, p.y * 9.0, p.z * 4.0) / s + o)))
			if f != 2:
				c = c.lerp(fat, vein * 0.6)
			return c.lerp(fat, cap), 44, 12, rf)
	b.xf = keep


func _mince(s: float, oc: Color, ic: Color) -> void:
	var R := 1.05 * s
	var H := 0.5 * s
	var o := Vector3(rng.randf() * 9.0, 0, 0)
	var dome := func(rn: float) -> float: return H * pow(maxf(0.0, 1.0 - rn * rn), 0.6)
	var col := func(p: Vector3) -> Color:
		var c := oc.lerp(ic.lightened(0.12), clampf(MeshGen.n3(p * 30.0 / s + o) + 0.3, 0.0, 1.0))
		if MeshGen.n3(p * 70.0 / s) > 0.5:
			c = c.lerp(Color(0.95, 0.85, 0.8), 0.7)
		return c
	b.mat(0.55, 1.4)
	b.dsolid(R, func(rn: float, _th: float) -> float: return dome.call(rn) + 0.002,
		func(_rn: float, _th: float) -> float: return 0.0,
		func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return col.call(p), 32, 8, Callable(), 0.0, TAU, false)
	_worms(80, R * 0.95, func(x: float, z: float) -> float: return dome.call(minf(Vector2(x, z).length() / R, 1.0)), 0.055 * s, 0.16 * s, col)


## Short mince strands lying on a surface top(x, z) (ground beef, patties).
func _worms(n: int, R: float, top: Callable, r: float, ln: float, col: Callable) -> void:
	for i in n:
		var rn := sqrt(MeshGen.h1(i * 3 + 5))
		var th := i * 2.39996
		var a := MeshGen.h1(i * 7) * TAU
		var c := Vector3(cos(th) * rn * R, 0, sin(th) * rn * R)
		var d := Vector3(cos(a), 0, sin(a)) * ln
		var pts := []
		for k in 4:
			var q := c + d * (k - 1.5) / 1.5 * 0.5 + Vector3(-d.z, 0, d.x) * 0.25 * sin(k * 2.0 + i)
			pts.append(Vector3(q.x, float(top.call(q.x, q.z)) + r * 0.45, q.z))
		b.tube(8, 5, func(t: float) -> Vector3: return _path(pts, t),
			func(t: float, _th: float) -> float: return r * sqrt(clampf(minf(t, 1.0 - t) / 0.2, 0.0, 1.0)),
			func(_u: float, _v: float, p: Vector3) -> Color: return col.call(p))


func _bacon(s: float, oc: Color, ic: Color) -> void:
	var W := 0.55 * s
	var L := 2.4 * s
	var T := 0.06 * s
	var fat := Color(0.98, 0.88, 0.84)
	b.mat(0.45, 0.35)
	for i in 3:
		var z := (i - 1) * (W + 0.06 * s)
		var ph := i * 1.7
		b.tube(36, 12, func(t: float) -> Vector3:
			return Vector3(-L * 0.5 + L * t, T * 0.5 + 0.05 * s * (0.5 + 0.5 * sin(t * 9.0 + ph)) + 0.002, z + 0.04 * s * sin(t * 5.0 + ph)),
			func(t: float, _th: float) -> float: return W * 0.5 * pow(sin(PI * clampf(t, 0.0, 1.0)), 0.1),
			func(u: float, v: float, p: Vector3) -> Color:
				var x := cos(u * TAU)
				var band := MeshGen.n3(Vector3(x * 2.2 + i * 3.0, v * 1.8, 0.0))
				var c := oc.lerp(ic, clampf(MeshGen.n3(p * 20.0 / s), 0.0, 1.0) * 0.4)
				c = c.lerp(fat, smoothstep(0.05, 0.2, band) * 0.9)
				return c.lerp(fat, smoothstep(0.65, 0.85, x)), T / W)


func _sausage(s: float, oc: Color, thin := false) -> void:
	var L := 2.1 * s
	var R := (0.22 if thin else 0.34) * s
	var keys := [Vector2(0, 0), Vector2(0.015, 0.3), Vector2(0.035, 0.42), Vector2(0.06, 0.75), Vector2(0.1, 0.94), Vector2(0.9, 0.94),
		Vector2(0.94, 0.75), Vector2(0.965, 0.42), Vector2(0.985, 0.3), Vector2(1.0, 0)]
	b.mat(0.3, 0.3)
	b.tube(30, 16, func(t: float) -> Vector3: return Vector3(-L * 0.5 + L * t, R + 0.003, (0.08 if thin else 0.3) * s * sin(t * PI)),
		func(t: float, _th: float) -> float: return R * _keys(keys, t),
		func(_u: float, _v: float, p: Vector3) -> Color:
			return _nz(oc, p, 0.1, 8.0 / s).lerp(oc.darkened(0.2), clampf(MeshGen.n3(p * 22.0 / s), 0.0, 1.0) * 0.5))


func _ham(s: float, oc: Color, ic: Color) -> void:
	var R := 1.05 * s
	var H := 0.07 * s
	var fat := Color(0.98, 0.9, 0.88)
	var rf := func(th: float) -> float: return 1.0 + 0.08 * cos(2.0 * th) + 0.03 * sin(3.0 * th)
	b.mat(0.4, 0.25)
	for k in 3:
		var dx := (k - 1) * 0.18 * s
		var y0 := 0.1 * s + k * (H + 0.025 * s)
		var wave := func(rn: float, th: float) -> float:
			var x := cos(th) * rn * R + dx
			return y0 + 0.08 * s * sin(x / R * 2.2)
		var keep := b.xf
		b.at(Vector3(dx, 0, (k - 1) * 0.05 * s), Vector3(0, 0, 0))
		b.dsolid(R, func(rn: float, th: float) -> float: return wave.call(rn, th) + H * 0.5,
			func(rn: float, th: float) -> float: return wave.call(rn, th) - H * 0.5,
			func(f: int, rn: float, _th: float, p: Vector3) -> Color:
				var c := oc.darkened(0.08).lerp(ic, clampf(MeshGen.n3(p * 12.0 / s), 0.0, 1.0) * 0.4)
				return c.lerp(fat, smoothstep(0.86, 0.95, rn) if f != 2 else 1.0), 32, 7, rf)
		b.xf = keep


func _pepperoni(s: float, oc: Color) -> void:
	var R := 0.36 * s
	var L := 2.0 * s
	var face := func(rn: float, _th: float, p: Vector3) -> Color:
		var c := _nz(oc, p, 0.1, 20.0 / s)
		if MeshGen.n3(p * 70.0 / s) > 0.45:
			c = Color(0.95, 0.82, 0.75)
		return c.lerp(oc.darkened(0.35), smoothstep(0.85, 1.0, rn))
	b.mat(0.4, 0.4)
	b.tube(20, 14, func(t: float) -> Vector3: return Vector3(-L * 0.3 + L * 0.65 * t, R + 0.003, -0.35 * s),
		func(t: float, th: float) -> float:
			return R * pow(sin(PI * clampf(t, 0.0, 1.0)), 0.15) * (1.0 + 0.04 * MeshGen.n3(Vector3(t * 12.0, cos(th) * 2.0, sin(th) * 2.0))),
		func(_u: float, v: float, p: Vector3) -> Color:
			return face.call(0.3, 0.0, p).darkened(0.15) if v > 0.02 and v < 0.98 else face.call(0.4, 0.0, p))
	var keep := b.xf
	b.at(Vector3(-0.2 * s, 0, 0.45 * s))
	_shingle(4, R, 0.08 * s, func(_i: int) -> void: _slice(R, 0.08 * s, face, oc.darkened(0.3)), 0.6)
	b.xf = keep


## Polar radius of a convex-ish outline given by inside(x, z) <= 0, found by bisection.
static func _outline_r(inside: Callable, th: float, rmax: float) -> float:
	var lo := 0.0
	var hi := rmax
	for i in 14:
		var m := (lo + hi) * 0.5
		if float(inside.call(cos(th) * m, sin(th) * m)) <= 0.0:
			lo = m
		else:
			hi = m
	return lo


func _fillet(s: float, oc: Color, ic: Color, salmon: bool) -> void:
	var L := 1.4 * s
	var W := 0.68 * s
	var H := 0.42 * s
	var inside := func(x: float, z: float) -> float:
		var xn := x / L
		if absf(xn) >= 1.0:
			return 1.0
		var w := W * (1.0 - 0.5 * smoothstep(-0.4, 1.0, xn)) * sqrt(1.0 - xn * xn)
		return absf(z) - w
	var rs := []
	for i in 64:
		rs.append(_outline_r(inside, TAU * i / 64.0, L))
	var rf := func(th: float) -> float:
		var f := fposmod(th, TAU) / TAU * 64.0
		var i := int(f)
		return lerpf(rs[i % 64], rs[(i + 1) % 64], f - i) / L
	var skin := Color(0.55, 0.55, 0.58, 0.6) if salmon else Color(0.45, 0.45, 0.5, 0.6)
	var line := Color(1.0, 0.88, 0.8) if salmon else Color(0.98, 0.98, 0.96)
	b.mat(0.35, 0.35)
	b.dsolid(L, func(rn: float, th: float) -> float:
			var xn := cos(th) * rn * float(rf.call(th))
			return H * (1.0 - 0.45 * smoothstep(-0.6, 1.0, xn)) * (1.0 - 0.55 * pow(rn, 5.0)),
		func(rn: float, _th: float) -> float: return H * 0.08 * pow(rn, 5.0),
		func(f: int, _rn: float, _th: float, p: Vector3) -> Color:
			if f == 1:
				return skin
			var x := p.x / L
			var z := absf(p.z) / W
			var fl := absf(fposmod(x * (6.0 if salmon else 8.0) + z * (1.4 if salmon else 2.5) + (0.0 if salmon else MeshGen.n3(p * 9.0 / s) * 0.3), 1.0) - 0.5)
			var c := _nz(oc, p, 0.06, 6.0 / s)
			if salmon:
				c = c.lerp(oc.darkened(0.12), smoothstep(0.2, 0.9, z))
			return c.lerp(line, (1.0 - smoothstep(0.03, 0.09, fl)) * (0.75 if salmon else 0.35)), 48, 10, rf)


func _shrimp(s: float, oc: Color, ic: Color) -> void:
	var Rc := 0.6 * s
	var R := 0.32 * s
	var path := func(t: float) -> Vector3:
		var a := t * 3.3 + 1.0
		var rc := Rc * (1.0 - 0.38 * t)
		return Vector3(cos(a) * rc, 0.0, sin(a) * rc)
	var rad := func(t: float, _th: float) -> float:
		var seg := 1.0 + 0.07 * pow(absf(sin(t * PI * 6.0)), 0.4)
		return R * (1.0 - 0.6 * t) * sqrt(clampf(t / 0.07, 0.0, 1.0)) * seg * (1.0 if t < 0.999 else 0.0)
	b.mat(0.3, 0.2)
	b.tube(42, 14, func(t: float) -> Vector3: return path.call(t) + Vector3(0, rad.call(t, 0.0) * 0.85 + 0.003, 0), rad,
		func(_u: float, v: float, p: Vector3) -> Color:
			var band := pow(absf(sin(v * PI * 6.0)), 6.0)
			return _nz(oc, p, 0.06, 10.0 / s).lerp(ic.lightened(0.15), (1.0 - band) * 0.35), 0.85)
	var pe: Vector3 = path.call(1.0)
	var tang: Vector3 = (pe - path.call(0.95)).normalized()
	var y := R * 0.4 * 0.85
	for sd in [-0.5, 0.5]:
		b.leaf(pe + Vector3(0, y, 0), tang.rotated(Vector3.UP, sd), s * 0.45, s * 0.3,
			_leafcol(oc.lightened(0.1), Color(0.75, 0.45, 0.4), 0.05), 0.05, 0.0, 0.0, 0.05, 0.6, 4, 5)
	b.mat(0.5, 0.1)
	for i in 5:
		var t := 0.15 + i * 0.13
		var p: Vector3 = path.call(t)
		var inward := -Vector3(p.x, 0, p.z).normalized()
		_stem([p + Vector3(0, 0.06 * s, 0), p + inward * (R * (1.0 - 0.6 * t) + 0.1 * s) + Vector3(0, 0.02 * s, 0)], 0.022 * s, 0.012 * s, oc.lightened(0.1), 3, 3)


func _tofu(s: float, oc: Color) -> void:
	b.mat(0.75, 0.6)
	b.rbox(Vector3(0, 0.5 * s, 0), Vector3(1.5 * s, 1.0 * s, 1.2 * s), 0.22, func(_u: float, _v: float, p: Vector3) -> Color:
		return _nz(oc, p, 0.04, 12.0 / s), 24, 14)


# ---------------------------------------------------------------- dairy

func _egg_profile(R: float, H: float) -> Array:
	var pts := []
	for i in 19:
		var k := float(i) / 18.0 * 2.0 - 1.0
		pts.append(Vector2(R * sqrt(maxf(0.0, 1.0 - k * k)) * (1.0 - 0.12 * k), (k + 1.0) * 0.5 * H))
	return pts


func _egg(s: float, oc: Color) -> void:
	var R := 0.72 * s
	var H := 1.9 * s
	var keep := b.xf
	b.at(Vector3(0, R * 0.95, 0), Vector3(0, 0, 90))
	b.xf = keep * b.xf * Transform3D(Basis.IDENTITY, Vector3(0, -H * 0.5, 0))
	b.mat(0.42 if oc.r < 0.97 else 0.22, 0.15, 0.25)
	_rev(_egg_profile(R, H), func(_u: float, _v: float, p: Vector3) -> Color:
		var c := _nz(oc, p, 0.04, 6.0 / s)
		if oc.r < 0.97 and MeshGen.n3(p * 60.0 / s) > 0.55:
			c = c.darkened(0.12)
		return c, 24)
	b.xf = keep


func _carton(s: float, id: String, oc: Color) -> void:
	var w := 1.1 * s
	var h := 1.65 * s
	var d := w
	var lab: Color = {"milk": Color(0.2, 0.45, 0.85), "cream": Color(0.95, 0.72, 0.25), "broth": Color(0.85, 0.45, 0.15)}.get(id, oc.darkened(0.35))
	var body := Color(0.97, 0.97, 0.95)
	if id == "broth":
		w = 1.0 * s
		d = 0.66 * s
		h = 1.9 * s
	b.mat(0.6, 0.0, 0.0)
	b.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), body, 2)
	b.box(Vector3(0, h * 0.37, 0), Vector3(w * 1.01, h * 0.5, d * 1.01), lab, 1)
	var fz := d * 0.505 + 0.003 * s
	if id == "broth":
		b.box(Vector3(0, h * 0.93, 0), Vector3(w * 1.01, h * 0.1, d * 1.01), lab.darkened(0.2), 1)
		_decal(Vector3(0, h * 0.4, fz), Vector3.BACK, w * 0.62, w * 0.62, Color(0.97, 0.95, 0.9), true)
		_decal(Vector3(0, h * 0.4, fz + 0.004 * s), Vector3.BACK, w * 0.48, w * 0.48, func(rn: float, a: float) -> Color:
			return Color(0.3, 0.55, 0.2) if rn > 0.5 and int(a * 3.0) % 3 == 0 else Color(0.8, 0.55, 0.3), true)
		b.mat(0.4, 0.0, 0.0)
		b.lathe([Vector2(0.18 * s, h - 0.01 * s), Vector2(0.18 * s, h + 0.14 * s), Vector2(0.18 * s, h + 0.14 * s), Vector2(0, h + 0.14 * s)], Color(0.95, 0.95, 0.9), 12)
		return
	_decal(Vector3(0, h * 0.4, fz), Vector3.BACK, w * 0.5, w * 0.5, body, true)
	_decal(Vector3(0, h * 0.4, fz + 0.004 * s), Vector3.BACK, w * 0.22, w * 0.3, lab.lightened(0.15), true)
	var roof := Transform3D(Basis.from_scale(Vector3(1, 0.55, 1)) * Basis.from_euler(Vector3(0, 0, PI * 0.25)), Vector3(0, h, 0))
	b.xf = roof
	b.box(Vector3.ZERO, Vector3(w * 0.7071, w * 0.7071, d * 0.999), lab, 1)
	b.xf = Transform3D.IDENTITY
	b.box(Vector3(0, h + w * 0.275 + 0.06 * s, 0), Vector3(0.06 * s, 0.14 * s, d * 0.98), body, 1)
	var cap := Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.18)), Vector3(-w * 0.2, h + w * 0.17, d * 0.1))
	b.xf = cap
	b.lathe([Vector2(0.17 * s, -0.02 * s), Vector2(0.17 * s, 0.1 * s), Vector2(0.17 * s, 0.1 * s), Vector2(0, 0.1 * s)], Color(0.97, 0.97, 0.95), 12)
	b.xf = Transform3D.IDENTITY


func _butter(s: float, oc: Color) -> void:
	var L := 2.1 * s
	var paper := Color(0.97, 0.95, 0.88)
	b.mat(0.55, 0.0, 0.0)
	b.box(Vector3(-0.2 * s, 0.45 * s, 0), Vector3(L - 0.4 * s, 0.9 * s, 1.0 * s), paper, 2)
	b.box(Vector3(-0.2 * s, 0.45 * s, 0), Vector3(0.5 * s, 0.91 * s, 1.01 * s), Color(0.85, 0.65, 0.2), 1)
	_decal(Vector3(-0.8 * s, 0.45 * s, 0.508 * s), Vector3.BACK, 0.4 * s, 0.4 * s, Color(0.2, 0.4, 0.75), true)
	b.mat(0.4, 0.15)
	b.rbox(Vector3(L * 0.5 - 0.35 * s, 0.42 * s, 0), Vector3(0.5 * s, 0.84 * s, 0.94 * s), 0.25, oc, 12, 8)


func _wedge(s: float, oc: Color, parm: bool) -> void:
	var R := 1.45 * s
	var H := (1.05 if parm else 0.9) * s
	var span := deg_to_rad(42.0 if parm else 55.0)
	var holes := []
	if not parm:
		for i in 6:
			holes.append(Vector3(rng.randf_range(0.25, 0.85), rng.randf_range(-0.4, 0.4), rng.randf_range(0.07, 0.13) * s))
	var rind := Color(0.86, 0.68, 0.32) if parm else oc.darkened(0.12)
	var hole_k := func(rn: float, th: float) -> float:
		var k := 0.0
		for hv in holes:
			var q := Vector2(cos(th) * rn * R, sin(th) * rn * R) - Vector2(cos(hv.y * span) * hv.x * R, sin(hv.y * span) * hv.x * R)
			k = maxf(k, 1.0 - q.length() / hv.z)
		return clampf(k, 0.0, 1.0)
	var keep := b.xf
	b.at(Vector3(0.5 * R, 0, 0.28 * R), Vector3(0, 150, 0))
	b.mat(0.55, 0.9 if parm else 0.3)
	b.dsolid(R, func(rn: float, th: float) -> float:
			return H * (1.0 - 0.04 * pow(rn, 12.0)) - sqrt(hole_k.call(rn, th)) * 0.09 * s,
		func(_rn: float, _th: float) -> float: return 0.0,
		func(f: int, rn: float, th: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.05, 10.0 / s)
			if f == 2 or (f == 0 and rn > (0.9 if parm else 0.95)):
				c = rind
				if parm and f == 2 and MeshGen.n3(p * 45.0 / s) > 0.35:
					c = c.darkened(0.25)
			elif f == 0:
				c = c.lerp(oc.darkened(0.25), hole_k.call(rn, th))
			elif f == 3 and not parm:
				for hv in holes:
					if Vector2(rn - hv.x, (p.y - H * (0.3 + hv.x * 0.4)) / R).length() < hv.z / R * 0.9:
						c = oc.darkened(0.3)
			return c, 30, 12, Callable(), -span * 0.5, span * 0.5)
	b.xf = keep


func _mozzarella(s: float, oc: Color) -> void:
	oc = oc.lerp(Color(0.97, 0.95, 0.88), 0.5)
	b.mat(0.2, 0.08, 0.6)
	b.blob(Vector3(0, 0.82 * s, 0), Vector3(s, 0.82 * s, s), func(_u: float, _v: float, p: Vector3) -> Color:
		return _nz(oc, p, 0.03, 6.0 / s), 24, 14, func(th: float, v: float, _d: Vector3) -> float:
			return 1.0 + 0.03 * sin(th * 2.0 + v * 4.0) + 0.12 * exp(-pow((1.0 - v) / 0.12, 2.0)))
	b.blob(Vector3(0.04 * s, 1.72 * s, 0), Vector3(0.14 * s, 0.12 * s, 0.12 * s), oc, 10, 6)


func _tub(s: float, oc: Color, ic: Color, ice: bool) -> void:
	var R := 1.0 * s
	var H := (1.0 if ice else 1.15) * s
	var lab := Color(0.9, 0.4, 0.55) if ice else Color(0.3, 0.55, 0.9)
	b.mat(0.35, 0.0, 0.0)
	var pts := [Vector2(0, 0.01 * s), Vector2(0.72 * R, 0.0), Vector2(0.74 * R, 0.04 * s), Vector2(0.95 * R, H),
		Vector2(1.0 * R, H), Vector2(1.0 * R, H + 0.04 * s), Vector2(0.94 * R, H + 0.03 * s), Vector2(0.9 * R, H * 0.3)]
	b.lathe(pts, Color(0.98, 0.98, 0.97), 36)
	var y0 := H * 0.22
	var y1 := H * 0.82
	var rr := func(y: float) -> float: return lerpf(0.74 * R, 0.95 * R, (y - 0.04 * s) / (H - 0.04 * s)) * 1.006
	b.lathe([Vector2(rr.call(y0), y0), Vector2(rr.call(y1), y1)], lab, 36)
	_sticker(rr.call(H * 0.52) * 1.004, H * 0.52, H * 0.24, func(_rn: float, _a: float) -> Color: return Color(1, 1, 1))
	_sticker(rr.call(H * 0.52) * 1.008, H * 0.52, H * 0.17, func(_rn: float, _a: float) -> Color: return ic)
	if ice:
		b.mat(0.7, 0.5, 0.3)
		for i in 3:
			var a := TAU * i / 3.0
			var c := Vector3(cos(a) * 0.4 * R, H * 0.92, sin(a) * 0.4 * R)
			b.blob(c, Vector3(0.48 * R, 0.4 * R, 0.48 * R), func(_u: float, _v: float, p: Vector3) -> Color:
				return _nz(oc, p, 0.06, 9.0 / s), 16, 10, func(th: float, v: float, _d: Vector3) -> float:
					return 1.0 + 0.06 * sin(th * 9.0 + v * 6.0) * v)
	else:
		b.mat(0.25, 0.0, 0.0, 0.6)
		b.dsolid(1.03 * R, func(rn: float, _th: float) -> float: return H + 0.06 * s + 0.03 * s * (1.0 - rn * rn),
			func(_rn: float, _th: float) -> float: return H + 0.02 * s,
			func(_f: int, _rn: float, _th: float, _p: Vector3) -> Color: return Color(0.82, 0.84, 0.88), 32, 3)
		b.mat(0.4, 0.0, 0.0)
		b.box(Vector3(1.1 * R, H + 0.05 * s, 0), Vector3(0.3 * s, 0.02 * s, 0.25 * s), lab, 1)


# ---------------------------------------------------------------- packaging

## Crisp wrap-around label band on a round body (radius R between y0..y1).
func _band(R: float, y0: float, y1: float, col, rf := Callable(), nu := 36) -> void:
	b.lathe([Vector2(R, y0), Vector2(R, y1)], col, nu, rf)


## Round sticker on the +z front of a body of radius R; cf(rn, angle) -> Color.
func _sticker(R: float, yc: float, rad: float, cf: Callable, rf := Callable()) -> void:
	b.surf(24, 4, func(u: float, v: float) -> Vector3:
		var a := u * TAU
		var r := v * rad
		var th := PI * 0.5 + r * cos(a) / R
		var y := yc + r * sin(a)
		var k := 1.0 if rf.is_null() else float(rf.call(th, 0.5, y))
		return Vector3(cos(th) * R * k, y, sin(th) * R * k),
		func(u: float, v: float, _p: Vector3) -> Color: return cf.call(v, u * TAU), true, false)


## Flat decal through c facing n: rectangle, or ellipse whose colour may be Callable(rn, angle).
func _decal(c: Vector3, n: Vector3, w: float, h: float, col, ellipse := false) -> void:
	var up := Vector3.UP if absf(n.y) < 0.9 else Vector3.BACK
	var rt := up.cross(n).normalized()
	var upv := n.cross(rt).normalized()
	if ellipse:
		var cf = col
		if col is Callable:
			cf = func(u: float, v: float, _p: Vector3) -> Color: return col.call(v, u * TAU)
		b.surf(24, 3, func(u: float, v: float) -> Vector3:
			var a := u * TAU
			return c + rt * cos(a) * v * w * 0.5 + upv * sin(a) * v * h * 0.5, cf, true, false)
	else:
		b.surf(1, 1, func(u: float, v: float) -> Vector3: return c + rt * (u - 0.5) * w + upv * (v - 0.5) * h, col, false, false)


## Standard product label on a cylinder: band, top/bottom stripes and a round picture.
func _cyl_label(R: float, y0: float, y1: float, lab: Color, stripe: Color, pic: Color, rf := Callable(), speck := Color(0, 0, 0, 0)) -> void:
	var h := y1 - y0
	b.mat(0.45, 0.0, 0.0)
	_band(R * 1.004, y0, y1, lab, rf)
	_band(R * 1.007, y0, y0 + h * 0.1, stripe, rf)
	_band(R * 1.007, y1 - h * 0.1, y1, stripe, rf)
	var yc := (y0 + y1) * 0.5
	_sticker(R * 1.01, yc, h * 0.34, func(_rn: float, _a: float) -> Color: return stripe, rf)
	_sticker(R * 1.014, yc, h * 0.27, func(rn: float, a: float) -> Color:
		if speck.a > 0.0 and rn > 0.2 and int(a * 2.5 + rn * 7.0) % 3 == 0:
			return speck
		return pic, rf)


func _bag(s: float, id: String, ic: Color) -> void:
	var w := 1.3 * s
	var h := 1.9 * s
	var d := 0.85 * s
	var paper: Color = {"flour": Color(0.95, 0.93, 0.87), "sugar": Color(0.98, 0.98, 0.98), "breadcrumbs": Color(0.76, 0.6, 0.4), "rice": Color(0.97, 0.97, 0.95)}.get(id, ic.lerp(Color(0.97, 0.95, 0.9), 0.55))
	var lab: Color = {"flour": Color(0.22, 0.42, 0.78), "sugar": Color(0.85, 0.22, 0.32), "breadcrumbs": Color(0.95, 0.58, 0.12), "rice": Color(0.2, 0.55, 0.3)}.get(id, Color.from_hsv(float(id.hash() % 360) / 360.0, 0.6, 0.75))
	var f := func(p: Vector3) -> Vector3:
		var y := p.y / h + 0.5
		var q := p
		q.x *= 1.0 + 0.05 * sin(PI * y) + 0.025 * MeshGen.n3(p * 9.0 / s)
		q.z *= (1.0 + 0.14 * sin(PI * minf(y / 0.82, 1.0))) * lerpf(1.0, 0.1, smoothstep(0.8, 1.0, y)) * (1.0 + 0.04 * MeshGen.n3(p * 7.0 / s + Vector3(5, 0, 0)))
		return q
	b.mat(0.85, 0.2, 0.0)
	b.box(Vector3(0, h * 0.5, 0), Vector3(w, h, d), func(_u: float, _v: float, p: Vector3) -> Color:
		return _nz(paper, p, 0.04, 8.0 / s).darkened(0.08 if p.y > 0.9 * h else 0.0), 12, f)
	# front label follows the bag's bulge
	var front := func(x0: float, x1: float, y0: float, y1: float, lift: float, cf) -> void:
		b.surf(6, 6, func(u: float, v: float) -> Vector3:
			var p := Vector3(lerpf(x0, x1, u), lerpf(y0, y1, v) - h * 0.5, d * 0.5)
			var q: Vector3 = f.call(p)
			return Vector3(q.x, q.y + h * 0.5, q.z + lift), cf, false, false)
	front.call(-w * 0.38, w * 0.38, h * 0.22, h * 0.62, 0.006 * s, lab)
	front.call(-w * 0.5, w * 0.5, h * 0.68, h * 0.75, 0.006 * s, lab.darkened(0.2))
	front.call(-w * 0.2, w * 0.2, h * 0.3, h * 0.54, 0.012 * s, Color(1, 1, 1))
	front.call(-w * 0.13, w * 0.13, h * 0.34, h * 0.5, 0.018 * s, func(_u: float, _v: float, p: Vector3) -> Color:
		return ic.darkened(0.15) if MeshGen.n3(p * 50.0 / s) > 0.0 else ic.darkened(0.3))


func _canister(s: float, ic: Color) -> void:
	var R := 0.85 * s
	var H := 1.85 * s
	var blue := Color(0.2, 0.35, 0.7)
	b.mat(0.6, 0.0, 0.0)
	b.lathe([Vector2(0, 0), Vector2(R, 0), Vector2(R, 0), Vector2(R, H - 0.2 * s)], Color(0.96, 0.92, 0.82), 36)
	_cyl_label(R, 0.15 * s, H - 0.3 * s, Color(0.96, 0.92, 0.82), blue, ic, Callable(), ic.darkened(0.3))
	b.mat(0.35, 0.0, 0.0)
	b.lathe([Vector2(R * 1.03, H - 0.24 * s), Vector2(R * 1.03, H), Vector2(R * 1.03, H), Vector2(0, H)], blue, 36)


func _spaghetti(s: float, oc: Color) -> void:
	var R := 0.34 * s
	var L := 2.4 * s
	var keep := b.xf
	b.xf = Transform3D(Basis.from_euler(Vector3(0, 0, PI * 0.5)), Vector3(L * 0.5, R, 0))
	b.mat(0.45, 0.2)
	b.lathe([Vector2(0, 0), Vector2(R, 0), Vector2(R, 0), Vector2(R, L), Vector2(R, L), Vector2(0, L)],
		func(_u: float, _v: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.06, 20.0 / s)
			if (p.y < 0.001 or p.y > L - 0.001) and MeshGen.n3(p * 120.0 / s) > 0.2:
				c = c.darkened(0.25)
			return c, 40, func(th: float, _t: float, _y: float) -> float: return 1.0 + 0.012 * cos(th * 60.0))
	b.mat(0.6, 0.0, 0.0)
	b.lathe([Vector2(R * 1.05, L * 0.36), Vector2(R * 1.05, L * 0.64)], func(_u: float, _v: float, p: Vector3) -> Color:
		return Color(1, 1, 1) if absf(p.y - L * 0.5) < L * 0.04 else Color(0.18, 0.35, 0.75), 40)
	b.xf = keep


func _noodle_brick(s: float, oc: Color) -> void:
	var sz := Vector3(1.7 * s, 0.6 * s, 1.25 * s)
	var wave := func(p: Vector3) -> float: return sin(p.x * 30.0 / s + 2.0 * sin(p.z * 14.0 / s))
	b.mat(0.6, 0.6)
	b.box(Vector3(0, sz.y * 0.5, 0), sz, func(_u: float, _v: float, p: Vector3) -> Color:
		var k: float = wave.call(p) if p.y > sz.y * 0.98 else sin(p.y * 40.0 / s + sin(p.x * 18.0 / s + p.z * 18.0 / s) * 2.0)
		return _sh(oc, 0.88 + 0.12 * k), 14, func(p: Vector3) -> Vector3:
			var q := p
			if p.y > sz.y * 0.49:
				q.y += 0.03 * s * wave.call(p)
			return q)


func _loaf(s: float, oc: Color, ic: Color, fresh: bool) -> void:
	var sz := Vector3(2.6 * s, 1.15 * s, 1.5 * s) if fresh else Vector3(2.4 * s, 1.25 * s, 1.35 * s)
	var hs := sz * 0.5
	var ang := deg_to_rad(55.0)
	var score := func(p: Vector3) -> float:
		if not fresh:
			return 0.0
		var x := p.x * cos(ang) + p.z * sin(ang)
		var sp := 0.55 * s
		var dd := absf(fposmod(x + sp * 0.5, sp) - sp * 0.5)
		return (1.0 - smoothstep(0.02 * s, 0.07 * s, dd)) * smoothstep(0.75 * hs.z, 0.35 * hs.z, absf(p.z)) * smoothstep(1.1 * hs.x, 0.7 * hs.x, absf(x))
	b.mat(0.75, 0.6)
	b.rbox(Vector3(0, hs.y, 0), sz, 0.6 if fresh else 0.28, func(_u: float, _v: float, p: Vector3) -> Color:
		var q := p - Vector3(0, hs.y, 0)
		var top := smoothstep(-0.2 * hs.y, 0.8 * hs.y, q.y)
		var c := oc.lerp(oc.darkened(0.2), top).lerp(oc.lightened(0.25), smoothstep(0.0, -0.9 * hs.y, q.y))
		c = _nz(c, p, 0.12, 6.0 / s)
		if fresh and q.y > 0.0 and MeshGen.n3(p * 6.0 / s) > 0.25:
			c = c.lerp(Color(0.95, 0.93, 0.88), 0.55)
		return c.lerp(ic.darkened(0.05), score.call(q) * float(q.y > 0.0)), 40, 22, func(p: Vector3) -> Vector3:
			var q := p
			if q.y > 0.0:
				q.y *= 1.0 + (0.3 if fresh else 0.22) * (1.0 - pow(q.z / hs.z, 2.0))
				q.y -= 0.08 * s * score.call(p)
			return q)


## Profile height at radius r on the upper (descending-radius) part of a lathe profile.
static func _prof_y(pts: Array, r: float) -> float:
	for i in range(pts.size() - 1, 0, -1):
		var a: Vector2 = pts[i]
		var c: Vector2 = pts[i - 1]
		if r >= a.x and r <= c.x:
			return lerpf(a.y, c.y, (r - a.x) / maxf(c.x - a.x, 1e-6))
	return (pts[0] as Vector2).y


func _sesame(pts: Array, rmax: float, n: int, sz: float) -> void:
	var keep := b.xf
	b.mat(0.5, 0.0, 0.6)
	for i in n:
		var rho := sqrt(MeshGen.h1(i * 3 + 1)) * rmax
		var ph := i * 2.39996
		var radial := Vector3(cos(ph), 0, sin(ph))
		var y := _prof_y(pts, rho)
		var tilt := atan2(_prof_y(pts, rho - 0.02 * rmax) - _prof_y(pts, rho + 0.02 * rmax), 0.04 * rmax)
		var bs := Basis(Vector3.UP.cross(radial).normalized() if rho > 0.001 else Vector3.RIGHT, -tilt) * Basis(Vector3.UP, MeshGen.h1(i) * TAU)
		b.xf = keep * Transform3D(bs, radial * rho + Vector3(0, y, 0))
		b.blob(Vector3.ZERO, Vector3(sz, sz * 0.38, sz * 0.6), Color(0.98, 0.93, 0.78), 6, 4)
	b.xf = keep


func _bun_profile(R: float) -> Array:
	return _cr([Vector2(0, 0), Vector2(0.88 * R, 0), Vector2(0.99 * R, 0.08 * R), Vector2(1.02 * R, 0.28 * R), Vector2(0.95 * R, 0.6 * R),
		Vector2(0.72 * R, 0.9 * R), Vector2(0.36 * R, 1.06 * R), Vector2(0, 1.1 * R)], 3)


func _bun(s: float, oc: Color, ic: Color) -> void:
	var R := s
	var pts := _bun_profile(R)
	b.mat(0.4, 0.35)
	_rev(pts, func(_u: float, _v: float, p: Vector3) -> Color:
		var c := oc.lerp(oc.darkened(0.15), smoothstep(0.4 * R, 1.1 * R, p.y))
		c = c.lerp(ic.lerp(oc, 0.35), smoothstep(0.32 * R, 0.18 * R, p.y))
		return _nz(c, p, 0.06, 6.0 / s), 32)
	_sesame(pts, 0.78 * R, 26, 0.075 * s)


## Burger bun halves / bread slices for stacks; built around STACK_R.
func _bun_half(_s: float, oc: Color, ic: Color, top: bool, id: String) -> void:
	var R := STACK_R
	var crumb := func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(ic, p, 0.08, 200.0)
	if id == "bagel" or id == "croissant":
		var keep := b.xf
		var k := R / (0.98 * 0.1 * S)
		b.at(Vector3.ZERO, Vector3.ZERO, Vector3(k, k * 0.5, k))
		if id == "bagel":
			_bagel(0.1 * S, oc if top else ic, ic)
		else:
			_croissant(0.1 * S, oc)
		b.xf = keep
		return
	if not id in ["bun", "brioche_bun", "english_muffin", "crumpet", "bagel"]:
		var rf := func(th: float) -> float:
			var sq := 1.0 / pow(pow(absf(cos(th)), 5.0) + pow(absf(sin(th)), 5.0), 0.2)
			return sq * (1.0 + 0.1 * pow(maxf(0.0, sin(th)), 3.0)) * 0.88
		var H := 0.22 * R
		b.mat(0.8, 0.9)
		b.dsolid(R, func(rn: float, _th: float) -> float: return H * (1.0 - 0.2 * pow(rn, 12.0)),
			func(rn: float, _th: float) -> float: return H * 0.2 * pow(rn, 12.0),
			func(f: int, rn: float, th: float, p: Vector3) -> Color:
				if f == 2 or rn > 0.93:
					return _nz(oc, p, 0.08, 80.0)
				return crumb.call(f, rn, th, p), 32, 8, rf)
		return
	b.mat(0.8, 0.9)
	if not top:
		b.dsolid(R, func(rn: float, _th: float) -> float: return 0.32 * R - 0.03 * R * pow(rn, 6.0),
			func(rn: float, _th: float) -> float: return 0.06 * R * pow(rn, 4.0),
			func(f: int, rn: float, th: float, p: Vector3) -> Color:
				return crumb.call(f, rn, th, p) if f == 0 else _nz(oc.lerp(ic, 0.3), p, 0.06, 80.0), 32, 6)
		return
	var pts := _bun_profile(R)
	var cut := 0.3 * R
	var prof := [Vector2(0, cut), Vector2(1.0 * R, cut), Vector2(1.0 * R, cut)]
	for pt in pts:
		if (pt as Vector2).y > cut:
			prof.append(pt)
	b.mat(0.4, 0.35)
	b.lathe(prof, func(_u: float, _v: float, p: Vector3) -> Color:
		if p.y < cut + 0.001:
			return _nz(ic, p, 0.08, 200.0)
		return _nz(oc.lerp(oc.darkened(0.15), smoothstep(0.4 * R, 1.1 * R, p.y)), p, 0.06, 40.0), 32)
	_sesame(pts, 0.75 * R, 24, 0.075 * R)


func _tortillas(s: float, oc: Color) -> void:
	var R := 1.25 * s
	var H := 0.035 * s
	b.mat(0.7, 0.35)
	for i in 3:
		var y0 := i * H * 1.05
		var ph := i * 1.9
		var keep := b.xf
		b.at(Vector3((i - 1) * 0.04 * s, 0, 0))
		b.dsolid(R, func(_rn: float, _th: float) -> float: return y0 + H,
			func(_rn: float, _th: float) -> float: return y0,
			func(_f: int, _rn: float, _th: float, p: Vector3) -> Color:
				var c := _nz(oc, p, 0.05, 8.0 / s)
				if MeshGen.n3(p * 18.0 / s + Vector3(ph, 0, 0)) > 0.45:
					c = c.lerp(Color(0.6, 0.4, 0.2), 0.6)
				return c, 36, 6, func(th: float) -> float: return 1.0 + 0.025 * sin(th * 7.0 + ph))
		b.xf = keep


func _nori(s: float, oc: Color) -> void:
	b.mat(0.4, 0.5)
	for i in 4:
		var keep := b.xf
		b.at(Vector3(0, 0.015 * s + i * 0.03 * s, 0), Vector3(0, i * 7.0, 0))
		b.box(Vector3.ZERO, Vector3(1.8 * s, 0.02 * s, 1.6 * s), func(_u: float, _v: float, p: Vector3) -> Color:
			return _nz(oc, p, 0.25, 30.0 / s), 4)
		b.xf = keep


func _can(s: float, id: String, ic: Color) -> void:
	var R := 0.75 * s
	var H := 1.45 * s
	var lab: Color = {"beans": Color(0.85, 0.3, 0.15), "chickpeas": Color(0.92, 0.78, 0.3), "coconut_milk": Color(0.2, 0.55, 0.35)}.get(id, Color.from_hsv(float(id.hash() % 360) / 360.0, 0.55, 0.8))
	var pic := Color(0.45, 0.3, 0.2) if id == "coconut_milk" else ic
	var pts := [Vector2(0, 0.02 * s), Vector2(0.9 * R, 0.0), Vector2(R, 0.04 * s), Vector2(R, 0.04 * s), Vector2(R, H - 0.04 * s),
		Vector2(R, H - 0.04 * s), Vector2(0.96 * R, H), Vector2(0.9 * R, H - 0.02 * s), Vector2(0.9 * R, H - 0.02 * s), Vector2(0, H - 0.03 * s)]
	b.mat(0.28, 0.0, 0.0, 0.85)
	b.lathe(_sub(pts, 0.1 * s), METAL, 36, func(_th: float, _t: float, y: float) -> float:
		return 1.0 - 0.015 * pow(absf(sin(y / H * PI * 9.0)), 6.0) * float(y < 0.15 * s or y > H - 0.15 * s))
	_cyl_label(R, 0.15 * s, H - 0.15 * s, lab, Color(0.97, 0.95, 0.9), pic, Callable(), pic.darkened(0.35))


func _salt(s: float) -> void:
	b.mat(0.12, 0.0, 0.0)
	b.lathe(_cr([Vector2(0, 0), Vector2(0.42 * s, 0), Vector2(0.45 * s, 0.06 * s), Vector2(0.42 * s, 0.9 * s), Vector2(0.39 * s, 1.0 * s)], 2),
		func(_u: float, _v: float, p: Vector3) -> Color: return _nz(Color(0.97, 0.97, 0.98), p, 0.03, 60.0 / s), 24)
	b.mat(0.25, 0.0, 0.0, 0.9)
	b.lathe(_cr([Vector2(0.41 * s, 0.96 * s), Vector2(0.42 * s, 1.15 * s), Vector2(0.3 * s, 1.32 * s), Vector2(0, 1.38 * s)], 2),
		func(u: float, _v: float, p: Vector3) -> Color:
			if p.y > 1.28 * s and absf(sin(u * TAU * 4.0)) < 0.25:
				return Color(0.1, 0.1, 0.1)
			return METAL, 24)


func _mill(s: float) -> void:
	var wood := Color(0.32, 0.2, 0.12)
	b.mat(0.35, 0.2, 0.0)
	b.lathe(_cr([Vector2(0, 0), Vector2(0.45 * s, 0), Vector2(0.48 * s, 0.12 * s), Vector2(0.38 * s, 0.55 * s), Vector2(0.32 * s, 0.95 * s),
		Vector2(0.42 * s, 1.35 * s), Vector2(0.44 * s, 1.5 * s), Vector2(0.44 * s, 1.5 * s), Vector2(0.3 * s, 1.62 * s), Vector2(0.15 * s, 1.75 * s),
		Vector2(0.09 * s, 1.9 * s), Vector2(0.13 * s, 1.98 * s), Vector2(0, 2.04 * s)], 3), func(_u: float, _v: float, p: Vector3) -> Color:
			if absf(p.y - 1.5 * s) < 0.035 * s:
				return METAL
			var g := sin(p.y * 40.0 / s + MeshGen.n3(p * 6.0 / s) * 5.0)
			return _sh(wood, 0.85 + 0.15 * g), 24)


func _spice_jar(s: float, id: String, ic: Color) -> void:
	var R := 0.5 * s
	var H := 1.35 * s
	var lid: Color = {"herbs": Color(0.2, 0.45, 0.2), "curry_powder": Color(0.75, 0.2, 0.15), "cinnamon": Color(0.15, 0.12, 0.1)}.get(id, ic.darkened(0.45))
	b.mat(0.1, 0.4, 0.0)
	b.lathe(_sub([Vector2(0, 0), Vector2(R * 0.95, 0), Vector2(R, 0.05 * s), Vector2(R, H), Vector2(R, H), Vector2(0.8 * R, H)], 0.08 * s),
		func(_u: float, _v: float, p: Vector3) -> Color:
			var c := _nz(ic, p, 0.2, 40.0 / s)
			if id == "herbs" and MeshGen.n3(p * 60.0 / s) > 0.3:
				c = c.darkened(0.35)
			return c, 24)
	b.mat(0.45, 0.0, 0.0)
	_band(R * 1.004, 0.3 * s, 0.95 * s, Color(0.97, 0.95, 0.88), Callable(), 24)
	_band(R * 1.007, 0.75 * s, 0.86 * s, lid, Callable(), 24)
	_sticker(R * 1.01, 0.52 * s, 0.17 * s, func(_rn: float, _a: float) -> Color: return ic.darkened(0.1))
	b.mat(0.35, 0.0, 0.0)
	b.lathe([Vector2(R * 1.04, H - 0.04 * s), Vector2(R * 1.04, H + 0.3 * s), Vector2(R * 1.04, H + 0.3 * s), Vector2(0, H + 0.3 * s)], lid, 30,
		func(th: float, t: float, _y: float) -> float: return 1.0 + 0.015 * cos(th * 40.0) * float(t < 0.5))


func _bottle(s: float, id: String, oc: Color) -> void:
	var pts: Array
	var cap_from := 0.0
	var lab0 := 0.0
	var lab1 := 0.0
	var R := 0.48 * s
	var lab := Color(0.97, 0.96, 0.9)
	var cap := Color(0.15, 0.45, 0.2)
	match id:
		"oil":
			pts = [Vector2(0, 0), Vector2(0.45 * s, 0), Vector2(0.48 * s, 0.06 * s), Vector2(0.48 * s, 1.45 * s), Vector2(0.36 * s, 1.85 * s),
				Vector2(0.16 * s, 2.1 * s), Vector2(0.15 * s, 2.4 * s), Vector2(0.15 * s, 2.4 * s), Vector2(0.19 * s, 2.4 * s), Vector2(0.19 * s, 2.68 * s),
				Vector2(0.19 * s, 2.68 * s), Vector2(0, 2.7 * s)]
			cap_from = 2.39 * s
			lab0 = 0.4 * s
			lab1 = 1.15 * s
		"soy_sauce":
			R = 0.51 * s
			pts = [Vector2(0, 0), Vector2(0.5 * s, 0), Vector2(0.51 * s, 0.08 * s), Vector2(0.51 * s, 0.9 * s), Vector2(0.42 * s, 1.15 * s),
				Vector2(0.24 * s, 1.35 * s), Vector2(0.22 * s, 1.45 * s), Vector2(0.22 * s, 1.45 * s), Vector2(0.27 * s, 1.45 * s), Vector2(0.26 * s, 1.62 * s),
				Vector2(0.13 * s, 1.72 * s), Vector2(0.07 * s, 1.82 * s), Vector2(0, 1.84 * s)]
			cap_from = 1.44 * s
			cap = Color(0.85, 0.12, 0.1)
			lab0 = 0.3 * s
			lab1 = 0.75 * s
		"vanilla":
			R = 0.45 * s
			pts = [Vector2(0, 0), Vector2(0.43 * s, 0), Vector2(0.45 * s, 0.05 * s), Vector2(0.45 * s, 1.0 * s), Vector2(0.3 * s, 1.25 * s),
				Vector2(0.18 * s, 1.35 * s), Vector2(0.18 * s, 1.35 * s), Vector2(0.22 * s, 1.35 * s), Vector2(0.22 * s, 1.75 * s), Vector2(0.22 * s, 1.75 * s), Vector2(0, 1.75 * s)]
			cap_from = 1.34 * s
			cap = Color(0.08, 0.08, 0.08)
			lab0 = 0.25 * s
			lab1 = 0.85 * s
		_: # maple syrup jug
			R = 0.62 * s
			pts = _cr([Vector2(0, 0), Vector2(0.55 * s, 0), Vector2(0.62 * s, 0.25 * s), Vector2(0.62 * s, 0.9 * s), Vector2(0.4 * s, 1.35 * s),
				Vector2(0.17 * s, 1.55 * s), Vector2(0.16 * s, 1.72 * s)], 2) + [Vector2(0.16 * s, 1.72 * s), Vector2(0.2 * s, 1.72 * s), Vector2(0.2 * s, 1.95 * s), Vector2(0.2 * s, 1.95 * s), Vector2(0, 1.95 * s)]
			cap_from = 1.71 * s
			cap = Color(0.8, 0.15, 0.1)
			lab0 = 0.3 * s
			lab1 = 0.8 * s
	b.mat(0.05, 0.0, 0.0)
	b.lathe(_sub(pts, 0.15 * s), func(_u: float, _v: float, p: Vector3) -> Color:
		return cap if p.y >= cap_from else _nz(oc, p, 0.05, 10.0 / s), 28)
	var pic := Color(0.75, 0.15, 0.1) if id == "maple_syrup" else oc.lightened(0.25)
	_cyl_label(R, lab0, lab1, lab, cap, pic)
	if id == "maple_syrup":
		b.mat(0.06, 0.0, 0.0)
		b.tube(14, 8, func(t: float) -> Vector3:
			var a := t * PI * 1.2 - PI * 0.1
			return Vector3(0.3 * s + sin(a) * 0.32 * s, 1.15 * s + cos(a) * 0.3 * s, 0),
			func(_t: float, _th: float) -> float: return 0.07 * s, oc)


func _squeeze(s: float, id: String, oc: Color) -> void:
	var ket := id == "ketchup"
	var R := 0.56 * s
	var pts := _cr([Vector2(0, 0), Vector2(0.48 * s, 0), Vector2(0.55 * s, 0.1 * s), Vector2(0.56 * s, 0.3 * s), Vector2(0.56 * s, 1.15 * s), Vector2(0.45 * s, 1.45 * s), Vector2(0.24 * s, 1.56 * s)], 3)
	if ket:
		pts += [Vector2(0.24 * s, 1.56 * s), Vector2(0.28 * s, 1.56 * s), Vector2(0.28 * s, 1.82 * s), Vector2(0.28 * s, 1.82 * s), Vector2(0, 1.84 * s)]
	else:
		pts += [Vector2(0.24 * s, 1.56 * s), Vector2(0.25 * s, 1.56 * s), Vector2(0.22 * s, 1.72 * s), Vector2(0.06 * s, 2.05 * s), Vector2(0, 2.08 * s)]
	var cap := Color(0.97, 0.97, 0.95) if ket else Color(0.85, 0.15, 0.12)
	var oval := func(th: float, _t: float, _y: float) -> float: return 1.0 / sqrt(pow(cos(th), 2.0) + pow(sin(th) / 0.72, 2.0))
	b.mat(0.18, 0.0, 0.0)
	b.lathe(pts, func(_u: float, _v: float, p: Vector3) -> Color:
		return cap if p.y >= 1.555 * s else _nz(oc, p, 0.04, 8.0 / s), 28, oval)
	if ket:
		_cyl_label(R, 0.35 * s, 1.0 * s, Color(0.97, 0.96, 0.92), Color(0.25, 0.55, 0.2), Color(0.85, 0.15, 0.1), oval)
	else:
		_cyl_label(R, 0.35 * s, 1.0 * s, Color(0.2, 0.3, 0.7), Color(0.97, 0.96, 0.92), Color(0.95, 0.85, 0.3), oval)


func _jar(s: float, id: String, oc: Color) -> void:
	var R := (0.75 if id == "peanut_butter" else 0.62) * s
	var H := (1.2 if id == "peanut_butter" else 1.25) * s
	var lid: Color = {"honey": Color(0.85, 0.65, 0.2), "jam": Color(0.85, 0.15, 0.15), "peanut_butter": Color(0.8, 0.15, 0.12), "sprinkles": Color(0.97, 0.97, 0.97)}.get(id, Color.from_hsv(float(id.hash() % 360) / 360.0, 0.6, 0.7))
	var hexy := id == "honey"
	var rf := func(th: float, _t: float, _y: float) -> float: return (1.0 / cos(fposmod(th, PI / 3.0) - PI / 6.0)) * 0.93 if hexy else 1.0
	var body := Color(0.97, 0.97, 0.98) if id == "sprinkles" else oc
	b.mat(0.06 if id != "peanut_butter" else 0.35, 0.0, 0.0)
	b.lathe(_sub([Vector2(0, 0), Vector2(R * 0.95, 0), Vector2(R, 0.06 * s), Vector2(R, H * 0.88), Vector2(R * 0.85, H)], 0.1 * s),
		func(_u: float, _v: float, p: Vector3) -> Color: return _nz(body, p, 0.06, 10.0 / s), 30, rf)
	if id == "sprinkles":
		b.mat(0.4, 0.0, 0.0)
		for i in 70:
			var th := MeshGen.h1(i * 3) * TAU
			var y := (0.08 + MeshGen.h1(i * 5 + 1) * 0.78) * H
			b.xf = Transform3D(Basis(Vector3.UP, -th) * Basis(Vector3.RIGHT, MeshGen.h1(i) * TAU), Vector3(cos(th) * R * 1.005, y, sin(th) * R * 1.005))
			b.rbox(Vector3.ZERO, Vector3(0.03, 0.03, 0.12) * s, 0.6, Color.from_hsv(MeshGen.h1(i * 7 + 2), 0.7, 1.0), 6, 4)
		b.xf = Transform3D.IDENTITY
		_sticker(R * 1.02, H * 0.45, H * 0.2, func(_rn: float, _a: float) -> Color: return Color(1.0, 0.5, 0.7))
	else:
		_cyl_label(R, H * 0.28, H * 0.7, Color(0.97, 0.94, 0.85), lid, oc.lightened(0.2), rf)
	b.mat(0.3, 0.0, 0.0, 0.7 if id == "honey" else 0.0)
	var lh := 0.32 * s
	b.lathe([Vector2(R * 0.92, H - 0.02 * s), Vector2(R * 0.92, H + lh), Vector2(R * 0.92, H + lh), Vector2(0, H + lh)], lid, 30,
		func(th: float, t: float, _y: float) -> float: return 1.0 + 0.012 * cos(th * 48.0) * float(t < 0.5))
	if id == "jam":
		b.mat(0.9, 0.3, 0.0)
		b.lathe(_cr([Vector2(0, H + lh + 0.02 * s), Vector2(R * 0.7, H + lh + 0.01 * s), Vector2(R * 1.0, H + lh - 0.05 * s),
			Vector2(R * 1.05, H + 0.0 * s), Vector2(R * 1.15, H - 0.2 * s)], 2), func(_u: float, _v: float, p: Vector3) -> Color:
				var chk := int(floor(p.x * 12.0 / s)) + int(floor(p.z * 12.0 / s))
				return Color(0.85, 0.12, 0.15) if chk % 2 == 0 else Color(0.97, 0.95, 0.92), 36,
			func(th: float, t: float, _y: float) -> float: return 1.0 + 0.06 * sin(th * 9.0) * t)


func _choc_bar(s: float, oc: Color) -> void:
	var L := 2.2 * s
	var W := 1.2 * s
	var T := 0.3 * s
	b.mat(0.5, 0.0, 0.0)
	b.box(Vector3(-L * 0.25, T * 0.55, 0), Vector3(L * 0.5, T * 1.1, W * 1.04), func(_u: float, _v: float, p: Vector3) -> Color:
		if absf(p.x + L * 0.25) < L * 0.06:
			return Color(0.9, 0.75, 0.3)
		return Color(0.55, 0.12, 0.2), 6)
	b.mat(0.35, 0.0, 0.0, 0.8)
	b.box(Vector3(0.03 * s, T * 0.52, 0), Vector3(0.06 * s, T * 1.04, W * 1.02), METAL, 2)
	var seg := W / 3.0
	b.mat(0.32, 0.1)
	b.box(Vector3(L * 0.25 - 0.02 * s, T * 0.5, 0), Vector3(L * 0.5, T, W), func(_u: float, _v: float, p: Vector3) -> Color:
		return _nz(oc, p, 0.05, 20.0 / s), 18, func(p: Vector3) -> Vector3:
			var q := p
			if q.y > T * 0.49:
				var gx := absf(fposmod(q.x + seg * 0.5, seg) - seg * 0.5)
				var gz := absf(fposmod(q.z + seg * 0.5, seg) - seg * 0.5)
				q.y -= 0.12 * s * (1.0 - smoothstep(0.0, 0.07 * s, minf(gx, gz)))
			return q)


func _marshmallows(s: float, oc: Color) -> void:
	var r := 0.42 * s
	var h := 0.75 * s
	var prof := _cr([Vector2(0, 0), Vector2(r * 0.85, 0), Vector2(r, h * 0.15), Vector2(r, h * 0.85), Vector2(r * 0.85, h), Vector2(0, h)], 2)
	b.mat(0.85, 0.25)
	var spots := [[Vector3(-r * 1.05, 0, -r * 0.6), false], [Vector3(r * 1.05, 0, -r * 0.6), false], [Vector3(0, 0, r * 1.2), false],
		[Vector3(0, h, -r * 0.1), true]]
	var i := 0
	for sp in spots:
		var keep := b.xf
		if sp[1]:
			b.xf = Transform3D(Basis.from_euler(Vector3(0, 0.6, PI * 0.5)), (sp[0] as Vector3) + Vector3(0, r, 0)) * Transform3D(Basis.IDENTITY, Vector3(0, -h * 0.5, 0))
		else:
			b.at(sp[0])
		var col := oc if i % 2 == 0 else Color(1.0, 0.86, 0.9)
		_rev(prof, func(_u: float, _v: float, p: Vector3) -> Color: return _nz(col, p, 0.03, 20.0 / s), 18)
		b.xf = keep
		i += 1


# ---------------------------------------------------------------- made in the kitchen

## Distance from the origin to a convex polygon along angle th.
static func _ray_poly(poly: Array, th: float) -> float:
	var d := Vector2(cos(th), sin(th))
	var best := 1e9
	for i in poly.size():
		var a: Vector2 = poly[i]
		var e: Vector2 = (poly[(i + 1) % poly.size()] as Vector2) - a
		var den := d.x * e.y - d.y * e.x
		if absf(den) < 1e-9:
			continue
		var t := (a.x * e.y - a.y * e.x) / den
		var u := (a.x * d.y - a.y * d.x) / den
		if t > 0.0 and u >= -1e-6 and u <= 1.0 + 1e-6:
			best = minf(best, t)
	return best


## Bread slice outline (square with a domed top edge).
static func _bread_rf(th: float) -> float:
	var sq := 1.0 / pow(pow(absf(cos(th)), 5.0) + pow(absf(sin(th)), 5.0), 0.2)
	return sq * (1.0 + 0.12 * pow(maxf(0.0, sin(th)), 3.0)) * 0.88


func _fried_egg(s: float) -> void:
	var R := 1.1 * s
	var o := Vector3(rng.randf() * 9.0, 0, 0)
	var H := 0.07 * s
	b.mat(0.3, 0.25)
	b.dsolid(R, func(rn: float, _th: float) -> float: return H * (1.0 - 0.6 * pow(rn, 3.0)) + 0.002,
		func(_rn: float, _th: float) -> float: return 0.0,
		func(f: int, rn: float, _th: float, p: Vector3) -> Color:
			var c := _nz(Color(0.98, 0.97, 0.94), p, 0.03, 20.0 / s)
			var crisp := smoothstep(0.78, 1.0, rn) * (0.6 + 0.4 * MeshGen.n3(p * 18.0 / s + o))
			return c.lerp(Color(0.82, 0.58, 0.3), clampf(crisp, 0.0, 1.0) * (1.0 if f != 1 else 0.6)), 40, 8,
		func(th: float) -> float: return 1.0 + 0.16 * MeshGen.n3(Vector3(cos(th), sin(th), 0) * 1.4 + o), 0.0, TAU, false)
	b.mat(0.08, 0.05, 0.5)
	b.blob(Vector3(0.12 * s, H * 0.6, 0.06 * s), Vector3(0.42 * s, 0.3 * s, 0.42 * s), func(_u: float, v: float, p: Vector3) -> Color:
		return _nz(Color(1.0, 0.68, 0.08), p, 0.05, 10.0 / s).lerp(Color(1, 0.8, 0.3), smoothstep(0.85, 1.0, v) * 0.3), 18, 10,
		func(_th: float, v: float, _d: Vector3) -> float: return 1.0 if v > 0.5 else 0.05)


func _scrambled(s: float, oc: Color) -> void:
	b.mat(0.6, 0.6)
	b.heap(12, 0.75 * s, 0.2 * s, 0.2 * s, func(i: int) -> void:
		var o := Vector3(i * 3.1, 0, 0)
		b.blob(Vector3.ZERO, Vector3(0.36, 0.3, 0.32) * s, func(_u: float, _v: float, p: Vector3) -> Color:
			var c := _nz(oc.lerp(Color(1.0, 0.8, 0.25), 0.45), p, 0.12, 14.0 / s).lerp(Color(1, 0.93, 0.65), clampf(MeshGen.n3(p * 9.0 / s + o), 0.0, 1.0) * 0.6)
			if MeshGen.n3(p * 50.0 / s + o) > 0.62:
				c = Color(0.3, 0.55, 0.2)
			return c, 14, 9, func(_th: float, _v: float, d: Vector3) -> float: return 1.0 + 0.22 * MeshGen.n3(d * 2.0 + o)), 3, 12.0)


func _dough(s: float, oc: Color, cookie: bool) -> void:
	var o := Vector3(rng.randf() * 9.0, 0, 0)
	var cy := 0.68 * s
	b.mat(0.85 if not cookie else 0.65, 0.5)
	b.blob(Vector3(0, cy, 0), Vector3(s, 0.7 * s, s), func(_u: float, _v: float, p: Vector3) -> Color:
		var c := _nz(oc, p, 0.05, 8.0 / s)
		if not cookie and MeshGen.n3(p * 7.0 / s + o) > 0.3:
			c = c.lerp(Color(1, 1, 1), 0.45)
		return c, 24, 14, func(_th: float, v: float, d: Vector3) -> float:
			return (1.0 + (0.1 if cookie else 0.03) * MeshGen.n3(d * 2.5 + o)) * (0.9 if v < 0.2 else 1.0))
	if cookie:
		b.mat(0.4, 0.1, 0.6)
		for i in 14:
			var d := Vector3(MeshGen.h1(i * 3) - 0.5, MeshGen.h1(i * 5 + 1) * 0.8, MeshGen.h1(i * 7 + 2) - 0.5).normalized()
			var keep := b.xf
			b.at(Vector3(0, cy, 0) + d * Vector3(s, 0.7 * s, s) * 0.97, Vector3(MeshGen.h1(i) * 90.0, MeshGen.h1(i + 9) * 180.0, 0))
			b.rbox(Vector3.ZERO, Vector3(0.16, 0.12, 0.14) * s, 0.5, Color(0.25, 0.14, 0.08), 6, 4)
			b.xf = keep


func _patty(s: float, oc: Color) -> void:
	var R := 1.0 * s
	var H := 0.42 * s
	var o := Vector3(rng.randf() * 9.0, 0, 0)
	b.mat(0.6, 1.3)
	b.dsolid(R, func(rn: float, th: float) -> float:
			var q := Vector3(cos(th) * rn, 0, sin(th) * rn)
			return H * (1.0 - 0.35 * pow(rn, 6.0)) + 0.03 * s * absf(MeshGen.n3(q * 6.0 + o)) + 0.018 * s * MeshGen.n3(q * 30.0 + o),
		func(rn: float, _th: float) -> float: return H * 0.15 * pow(rn, 6.0),
		func(_f: int, _rn: float, _th: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.12, 25.0 / s)
			if MeshGen.n3(p * 60.0 / s + o) > 0.5:
				c = c.lerp(Color(0.95, 0.85, 0.8), 0.6)
			return c, 56, 14, func(th: float) -> float: return 1.0 + 0.05 * MeshGen.n3(Vector3(cos(th), sin(th), 0) * 2.0 + o))
	_worms(60, R * 0.9, func(x: float, z: float) -> float: return H * (1.0 - 0.35 * pow(minf(Vector2(x, z).length() / R, 1.0), 6.0)) - 0.01 * s,
		0.045 * s, 0.13 * s, func(p: Vector3) -> Color: return _nz(oc, p, 0.15, 25.0 / s).lerp(oc.lightened(0.15), clampf(MeshGen.n3(p * 40.0 / s), 0.0, 1.0)))


func _meatballs(s: float, oc: Color) -> void:
	var r := 0.42 * s
	var spots := [Vector3(0.43, 0, 0.43), Vector3(-0.43, 0, 0.43), Vector3(0.43, 0, -0.43), Vector3(-0.43, 0, -0.43)]
	b.mat(0.55, 1.2)
	var i := 0
	for sp in spots + [Vector3(0, 0.58, 0)]:
		var o := Vector3(i * 4.0, 1.0, 0)
		b.blob((sp as Vector3) * s + Vector3(0, r, 0), Vector3.ONE * r, func(_u: float, _v: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.12, 25.0 / s)
			if MeshGen.n3(p * 60.0 / s + o) > 0.55:
				c = c.lerp(Color(0.3, 0.5, 0.2), 0.7)
			return c, 22, 14, func(_th: float, _v: float, d: Vector3) -> float: return 1.0 + 0.06 * MeshGen.n3(d * 3.0 + o) + 0.04 * MeshGen.n3(d * 10.0 + o))
		i += 1


func _mash(s: float, oc: Color) -> void:
	var R := 1.1 * s
	b.mat(0.6, 0.5)
	b.dsolid(R, func(rn: float, th: float) -> float:
			return 0.7 * s * pow(maxf(0.0, 1.0 - rn * rn), 0.8) + 0.06 * s * sin(3.0 * th + rn * 12.0) * (1.0 - rn) * rn * 2.0 + 0.002,
		func(_rn: float, _th: float) -> float: return 0.0,
		func(_f: int, _rn: float, _th: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.05, 10.0 / s)
			var n := MeshGen.n3(p * 70.0 / s)
			if n > 0.62:
				c = Color(0.15, 0.12, 0.1)
			elif n < -0.65:
				c = Color(0.3, 0.55, 0.2)
			return c, 40, 12, Callable(), 0.0, TAU, false)
	b.mat(0.2, 0.0, 0.3)
	b.rbox(Vector3(0, 0.7 * s, 0), Vector3(0.38, 0.16, 0.34) * s, 0.4, Color(1.0, 0.88, 0.4), 10, 6)


func _fries(s: float, oc: Color) -> void:
	var H := 1.25 * s
	var rs := func(th: float) -> float: return 1.0 / pow(pow(absf(cos(th)), 4.0) + pow(absf(sin(th)), 4.0), 0.25)
	var red := Color(0.82, 0.12, 0.12)
	b.mat(0.5, 0.0, 0.0)
	b.surf(28, 6, func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var r: float = rs.call(th)
		var ym := H * (1.0 + 0.14 * cos(2.0 * th))
		return Vector3(cos(th) * r * lerpf(0.55, 0.74, v) * s, v * ym, sin(th) * r * lerpf(0.38, 0.5, v) * s),
		func(u: float, v: float, _p: Vector3) -> Color:
			var dth := absf(wrapf(u * TAU - PI * 0.5, -PI, PI))
			if dth < 0.45 and v > 0.3 and v < 0.75 and absf(dth - 0.22) < 0.12:
				return Color(1.0, 0.8, 0.15)
			return red, true, false)
	b.dsolid(0.55 * s, func(_rn: float, _th: float) -> float: return 0.003,
		func(_rn: float, _th: float) -> float: return 0.0,
		func(_f: int, _rn: float, _th: float, _p: Vector3) -> Color: return red, 16, 2,
		func(th: float) -> float: return rs.call(th) * lerpf(1.0, 0.69, absf(sin(th))), 0.0, TAU, false)
	b.mat(0.55, 0.4)
	for i in 24:
		var x := (MeshGen.h1(i * 3) - 0.5) * 1.0 * s
		var z := (MeshGen.h1(i * 5 + 7) - 0.5) * 0.62 * s
		var ln := (1.25 + MeshGen.h1(i * 11) * 0.5) * s
		var keep := b.xf
		b.at(Vector3(x, 0.15 * s + ln * 0.5, z), Vector3((MeshGen.h1(i * 2) - 0.5) * 30.0, MeshGen.h1(i) * 90.0, -x / s * 18.0))
		b.rbox(Vector3.ZERO, Vector3(0.14 * s, ln, 0.14 * s), 0.25, func(_u: float, _v: float, p: Vector3) -> Color:
			return _nz(oc, p, 0.06, 20.0 / s).lerp(oc.darkened(0.3), smoothstep(0.3 * ln, 0.5 * ln, p.y)), 8, 8)
		b.xf = keep


func _chip(Rc: float, oc: Color, tri: bool, k: int) -> void:
	var poly := [Vector2(1.0, 0), Vector2(-0.5, 0.866), Vector2(-0.5, -0.866)]
	var o := Vector3(k * 2.3, 0, 0)
	b.surf(18 if not tri else 12, 5, func(u: float, v: float) -> Vector3:
		var th := u * TAU
		var r := v * Rc * (_ray_poly(poly, th) if tri else 1.0 + 0.07 * sin(3.0 * th + k))
		var x := cos(th) * r
		var z := sin(th) * r
		var y := (0.1 if not tri else 0.08) * Rc * ((x * x - z * z) / (Rc * Rc)) + (0.012 * Rc * sin(x / Rc * 9.0) if not tri else 0.0)
		return Vector3(x, y, z),
		func(_u: float, _v: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.08, 6.0 / Rc)
			var n := MeshGen.n3(p * 9.0 / Rc + o)
			if n > 0.45:
				c = c.lerp(Color(0.6, 0.38, 0.15), 0.6)
			if tri and MeshGen.n3(p * 40.0 / Rc) > 0.6:
				c = Color(1, 1, 1)
			return c, true, false)


func _chips(s: float, oc: Color, tri: bool) -> void:
	b.mat(0.45, 0.3)
	var Rc := 0.48 * s
	b.heap(12, 0.85 * s, 0.12 * s, 0.14 * s, func(i: int) -> void: _chip(Rc, oc, tri, i), 5, 35.0)


func _rice_mound(s: float, oc: Color) -> void:
	var R := 1.1 * s
	var H := 0.75 * s
	var top := func(rn: float, th: float) -> float:
		return H * pow(maxf(0.0, 1.0 - rn * rn), 0.6) + 0.02 * s * MeshGen.n3(Vector3(cos(th) * rn, 0, sin(th) * rn) * 8.0) + 0.002
	b.mat(0.5, 1.2)
	b.dsolid(R, top, func(_rn: float, _th: float) -> float: return 0.0,
		func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(oc, p, 0.04, 30.0 / s), 36, 10, Callable(), 0.0, TAU, false)
	b.mat(0.45, 0.2)
	for i in 70:
		var rn := sqrt(MeshGen.h1(i * 3 + 1)) * 0.93
		var th := i * 2.39996
		var y: float = top.call(rn, th)
		var keep := b.xf
		b.at(Vector3(cos(th) * rn * R, y, sin(th) * rn * R), Vector3(MeshGen.h1(i) * 40.0 - 20.0, MeshGen.h1(i + 3) * 180.0, rn * 40.0))
		b.blob(Vector3.ZERO, Vector3(0.1, 0.045, 0.045) * s, Color(0.99, 0.98, 0.95).lerp(oc, MeshGen.h1(i + 7) * 0.5), 6, 4)
		b.xf = keep


func _noodle_pile(s: float, oc: Color, wavy: bool) -> void:
	var R := 1.05 * s
	var H := 0.45 * s
	var mound := func(rho: float) -> float: return H * maxf(0.0, 1.0 - pow(rho / R, 2.0))
	b.mat(0.35, 0.15)
	b.dsolid(R * 0.92, func(rn: float, _th: float) -> float: return mound.call(rn * R * 0.92) * 0.9 + 0.002,
		func(_rn: float, _th: float) -> float: return 0.0,
		func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(oc, p, 0.05, 20.0 / s), 24, 6, Callable(), 0.0, TAU, false)
	var r := (0.055 if wavy else 0.045) * s
	for i in 16:
		var a0 := MeshGen.h1(i * 7) * TAU
		var pts := []
		for k in 7:
			var a := a0 + k * (0.9 + MeshGen.h1(i * 11 + k) * 0.6)
			var rho := R * (0.15 + 0.78 * MeshGen.h1(i * 13 + k * 3))
			pts.append(Vector3(cos(a) * rho, mound.call(rho) + r * (1.0 + (i % 3)), sin(a) * rho))
		b.tube(42, 5, func(t: float) -> Vector3:
			var p: Vector3 = _path(pts, t)
			if wavy:
				p += Vector3(sin(t * 60.0), 0.4 * cos(t * 47.0), cos(t * 60.0)) * 0.035 * s
			return p, func(t: float, _th: float) -> float: return r * (0.0 if t >= 1.0 or t <= 0.0 else 1.0),
			func(_u: float, _v: float, p: Vector3) -> Color: return _nz(oc, p, 0.06, 15.0 / s))


func _popcorn(s: float, oc: Color) -> void:
	var H := 1.3 * s
	b.mat(0.5, 0.0, 0.0)
	b.lathe([Vector2(0, 0), Vector2(0.6 * s, 0), Vector2(0.6 * s, 0), Vector2(0.85 * s, H), Vector2(0.85 * s, H), Vector2(0.82 * s, H), Vector2(0.58 * s, 0.05 * s)],
		func(u: float, _v: float, p: Vector3) -> Color:
			if p.y > H * 0.35 and p.y < H * 0.62 and absf(wrapf(u * TAU - PI * 0.5, -PI, PI)) < 0.5:
				return Color(0.98, 0.85, 0.25)
			return Color(0.85, 0.12, 0.12) if int(floor(u * 16.0)) % 2 == 0 else Color(0.97, 0.97, 0.95), 32)
	b.mat(0.7, 0.5)
	b.at(Vector3(0, 0, 0))
	b.heap(28, 0.72 * s, H * 0.92, 0.2 * s, func(i: int) -> void:
		var o := Vector3(i * 2.7, 0.5, 0)
		b.blob(Vector3.ZERO, Vector3.ONE * 0.22 * s, func(_u: float, v: float, p: Vector3) -> Color:
			return _nz(oc, p, 0.05, 20.0 / s).lerp(Color(0.92, 0.75, 0.35), smoothstep(0.25, 0.0, v) * 0.8), 10, 7,
			func(_th: float, _v: float, d: Vector3) -> float: return 1.0 + 0.38 * maxf(-0.3, MeshGen.n3(d * 2.2 + o))), 9, 60.0)


func _toast(s: float, oc: Color, ic: Color, french: bool) -> void:
	var R := 1.05 * s
	var H := 0.32 * s
	b.mat(0.75, 1.0)
	b.dsolid(R, func(rn: float, _th: float) -> float: return H * (1.0 - 0.18 * pow(rn, 12.0)),
		func(rn: float, _th: float) -> float: return H * 0.18 * pow(rn, 12.0),
		func(f: int, rn: float, _th: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.12, 25.0 / s)
			if french:
				c = c.lerp(ic, clampf(MeshGen.n3(p * 6.0 / s), 0.0, 1.0) * 0.6)
				if f == 0 and MeshGen.n3(p * 60.0 / s) > 0.4:
					c = Color(1, 1, 1)
			else:
				c = c.lerp(oc.darkened(0.25), clampf(MeshGen.n3(p * 8.0 / s), 0.0, 1.0) * 0.6)
			if f == 2 or rn > 0.92:
				c = oc.darkened(0.35)
			return c, 32, 8, _bread_rf)


func _grilled_cheese(s: float, oc: Color, ic: Color) -> void:
	var R := 1.05 * s
	var H := 0.26 * s
	var bread := func(y0: float) -> void:
		b.mat(0.7, 1.0)
		b.dsolid(R, func(rn: float, _th: float) -> float: return y0 + H * (1.0 - 0.15 * pow(rn, 12.0)),
			func(rn: float, _th: float) -> float: return y0 + H * 0.15 * pow(rn, 12.0),
			func(f: int, rn: float, _th: float, p: Vector3) -> Color:
				var c := _nz(oc, p, 0.15, 20.0 / s)
				return c.darkened(0.25) if f == 2 or rn > 0.93 else c, 32, 6, _bread_rf)
	bread.call(0.0)
	b.mat(0.22, 0.1)
	b.dsolid(R * 1.02, func(_rn: float, _th: float) -> float: return H + 0.08 * s,
		func(_rn: float, _th: float) -> float: return H - 0.01 * s,
		func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(ic, p, 0.05, 10.0 / s), 32, 3,
		func(th: float) -> float: return _bread_rf(th) * (1.0 + 0.07 * pow(maxf(0.0, sin(th * 5.0 + 1.0)), 6.0)))
	for i in 4:
		var th := 1.0 + i * 1.6
		var e := Vector3(cos(th), 0, sin(th)) * R * 1.02 * _bread_rf(th)
		_stem([e + Vector3(0, H + 0.04 * s, 0), e * 1.04 + Vector3(0, H - 0.05 * s, 0), e * 1.05 + Vector3(0, H - 0.12 * s - i * 0.02 * s, 0)], 0.06 * s, 0.035 * s, ic, 6, 4)
	bread.call(H + 0.08 * s)


## Pizza (whole or as `n` slices pulled slightly apart).
func _pizza(s: float, oc: Color, ic: Color, cut: bool) -> void:
	var R := 1.3 * s
	var cheese := Color(1.0, 0.82, 0.45)
	var o := Vector3(rng.randf() * 9.0, 0, 0)
	var n := 8 if cut else 1
	var gap := 0.03 if cut else 0.0
	for k in n:
		var th0 := TAU * k / n + gap
		var th1 := TAU * (k + 1) / n - gap
		if not cut:
			th0 = 0.0
			th1 = TAU
		var mid := (th0 + th1) * 0.5
		var keep := b.xf
		b.at(Vector3(cos(mid), 0, sin(mid)) * (0.05 * R if cut else 0.0))
		b.mat(0.7, 0.6)
		b.dsolid(R, func(rn: float, _th: float) -> float:
				return 0.07 * s + 0.13 * s * exp(-pow((rn - 0.92) / 0.06, 2.0)) - 0.05 * s * pow(rn, 30.0),
			func(rn: float, _th: float) -> float: return 0.02 * s * pow(rn, 8.0),
			func(f: int, rn: float, _th: float, p: Vector3) -> Color:
				if f == 0 and rn < 0.86:
					return _nz(ic, p, 0.1, 12.0 / s)
				var c := _nz(oc, p, 0.1, 10.0 / s)
				if f != 1 and MeshGen.n3(p * 14.0 / s + o) > 0.35:
					c = c.lerp(Color(0.55, 0.32, 0.12), 0.6)
				return c.lightened(0.15) if f == 3 else c, 48, 12, Callable(), th0, th1)
		b.mat(0.35, 0.4)
		b.dsolid(R * 0.8, func(rn: float, th: float) -> float:
				return 0.1 * s + 0.025 * s * (1.0 - rn * rn) + 0.015 * s * maxf(0.0, MeshGen.n3(Vector3(cos(th) * rn, 0, sin(th) * rn) * 10.0 + o)),
			func(_rn: float, _th: float) -> float: return 0.065 * s,
			func(_f: int, _rn: float, _th: float, p: Vector3) -> Color:
				var c := _nz(cheese, p, 0.06, 10.0 / s)
				var n2 := MeshGen.n3(p * 16.0 / s + o)
				if n2 > 0.3:
					c = c.lerp(Color(0.8, 0.48, 0.18), clampf((n2 - 0.3) * 2.5, 0.0, 1.0))
				if MeshGen.n3(p * 40.0 / s + o) > 0.55:
					c = c.lerp(Color(0.95, 0.55, 0.15), 0.5)
				return c, 56, 10, func(th: float) -> float: return 1.0 + 0.09 * MeshGen.n3(Vector3(cos(th), sin(th), 0) * 3.0 + o) + 0.04 * sin(th * 11.0), th0, th1)
		b.xf = keep
	if not cut:
		b.mat(0.35, 0.15)
		for i in 3:
			var a := i * 2.1 + 0.4
			var p := Vector3(cos(a), 0, sin(a)) * R * 0.38 + Vector3(0, 0.14 * s, 0)
			b.leaf(p, Vector3(cos(a + 1.5), 0.05, sin(a + 1.5)), 0.4 * s, 0.25 * s, _leafcol(Color(0.25, 0.55, 0.2), Color(0.15, 0.4, 0.12), 0.05), 0.05, 0.05, 0.3, 0.0, 0.45, 4, 5)


## Savoury fillings get a closed, domed lid with steam vents; fruit gets a lattice.
var _pie_closed := false


func _pie(s: float, oc: Color, ic: Color, cut: bool) -> void:
	var R := 1.2 * s
	var Hf := 0.62 * s
	var dome := (0.26 if _pie_closed else 0.14) * s
	var sp := 0.42 * s
	var closed := _pie_closed
	var lattice := func(p: Vector3) -> float:
		var gx := absf(fposmod(p.x + sp * 0.5, sp) - sp * 0.5)
		var gz := absf(fposmod(p.z, sp) - sp * 0.5)
		return maxf(1.0 - smoothstep(0.07 * s, 0.1 * s, gx), 1.0 - smoothstep(0.07 * s, 0.1 * s, gz))
	if not cut:
		b.mat(0.3, 0.0, 0.0, 0.8)
		b.lathe([Vector2(0, 0), Vector2(0.85 * R, 0), Vector2(1.0 * R, Hf * 0.9), Vector2(1.06 * R, Hf * 0.93)], METAL, 32)
	var n := 6 if cut else 1
	for k in n:
		var th0 := TAU * k / n + (0.035 if cut else 0.0)
		var th1 := TAU * (k + 1) / n - (0.035 if cut else 0.0)
		if not cut:
			th0 = 0.0
			th1 = TAU
		var mid := (th0 + th1) * 0.5
		var keep := b.xf
		b.at(Vector3(cos(mid), 0, sin(mid)) * (0.06 * R if cut else 0.0))
		b.mat(0.45 if closed else 0.6, 0.5)
		b.dsolid(R * 1.02, func(rn: float, th: float) -> float:
				var p := Vector3(cos(th) * rn * R, 0, sin(th) * rn * R)
				# crimped rim: a raised, fluted edge all the way round
				var rim := smoothstep(0.82, 0.9, rn) * (0.08 * s + 0.05 * s * absf(sin(th * 22.0)))
				var top := Hf + dome * (1.0 - smoothstep(0.0, 0.86, rn) * smoothstep(0.0, 0.86, rn))
				if not closed:
					top += 0.04 * s * lattice.call(p) * float(rn < 0.86)
				return top + rim - 0.12 * s * pow(rn, 40.0),
			func(rn: float, _th: float) -> float: return 0.02 * s + 0.24 * s * pow(rn, 6.0),
			func(f: int, rn: float, _th: float, p: Vector3) -> Color:
				var crust := _nz(oc, p, 0.1, 12.0 / s)
				if f == 3:
					# cut face: filling between the base and the lid
					return ic.darkened(0.15) if p.y > 0.12 * s and p.y < Hf + dome * 0.4 and rn < 0.86 else crust
				if f != 0 or rn > 0.84:
					return crust
				if closed:
					# egg-washed lid: golden in the middle, darker toward the rim
					return crust.lightened(0.08).lerp(crust.darkened(0.12), rn)
				return crust.lightened(0.1).lerp(_nz(ic, p, 0.12, 15.0 / s), 1.0 - lattice.call(p)), 48, 14, Callable(), th0, th1)
		b.xf = keep
	if closed and not cut:
		# three steam slits showing the filling, set into the dome
		var rn := 0.3
		var y := Hf + dome * (1.0 - pow(smoothstep(0.0, 0.86, rn), 2.0)) - 0.01 * s
		var keep := b.xf
		b.mat(0.7, 0.2)
		for k in 3:
			var a := TAU * k / 3.0 + 0.5
			b.at(Vector3(cos(a), 0, sin(a)) * rn * R * 1.02 + Vector3(0, y, 0), Vector3(0, -rad_to_deg(a), 0), Vector3.ONE, keep)
			b.rbox(Vector3.ZERO, Vector3(0.3 * R, 0.05 * s, 0.06 * R), 0.3, ic.darkened(0.35), 10, 6)
		b.xf = keep


func _cake(s: float, oc: Color, ic: Color, cut: bool) -> void:
	var R := 1.1 * s
	var H := 1.1 * s
	var gapa := deg_to_rad(55.0) if cut else 0.0
	var layers := func(p: Vector3, rn: float) -> Color:
		if rn > 0.94 or p.y > H * 0.9 or absf(p.y - H * 0.45) < 0.05 * s:
			return ic
		return _nz(oc, p, 0.08, 20.0 / s)
	var piece := func(th0: float, th1: float, off: Vector3) -> void:
		var keep := b.xf
		b.at(off)
		b.mat(0.45, 0.4)
		b.dsolid(R, func(rn: float, _th: float) -> float: return H - 0.06 * s * pow(rn, 20.0),
			func(_rn: float, _th: float) -> float: return 0.0,
			func(f: int, rn: float, _th: float, p: Vector3) -> Color:
				if f == 3:
					return layers.call(p, rn)
				return _nz(ic, p, 0.04, 10.0 / s), 40, 8, Callable(), th0, th1)
		b.mat(0.4, 0.3)
		var nr := 12
		for i in nr:
			var a := TAU * (i + 0.5) / nr
			if a < th0 or a > th1:
				continue
			var c := Vector3(cos(a), 0, sin(a)) * R * 0.82 + Vector3(0, H, 0)
			b.blob(c, Vector3(0.17, 0.2, 0.17) * s, func(_u: float, _v: float, p: Vector3) -> Color: return _nz(ic.lightened(0.1), p, 0.05, 20.0 / s), 12, 8,
				func(th: float, v: float, _d: Vector3) -> float: return (1.0 + 0.15 * cos(th * 6.0 + v * 8.0)) * (1.0 - 0.3 * v * v) * (0.2 if v < 0.4 else 1.0))
		b.xf = keep
	piece.call(gapa * 0.5, TAU - gapa * 0.5, Vector3.ZERO)
	if cut:
		piece.call(-gapa * 0.5 + 0.02, gapa * 0.5 - 0.02, Vector3(0.45 * R, 0, 0))
	else:
		b.mat(0.12, 0.05, 0.3)
		b.blob(Vector3(0, H + 0.2 * s, 0), Vector3.ONE * 0.2 * s, Color(0.8, 0.06, 0.12), 14, 9)
		_stem([Vector3(0, H + 0.38 * s, 0), Vector3(0.05 * s, H + 0.55 * s, 0), Vector3(0.15 * s, H + 0.65 * s, 0)], 0.025 * s, 0.02 * s, Color(0.35, 0.45, 0.2), 4)


func _muffins(s: float, oc: Color, ic: Color) -> void:
	var cup := Color(0.95, 0.55, 0.6)
	for i in 3:
		var a := TAU * i / 3.0 + 0.3
		var c := Vector3(cos(a), 0, sin(a)) * 0.75 * s
		var o := Vector3(i * 5.0, 0, 0)
		var keep := b.xf
		b.at(c)
		b.mat(0.6, 0.0, 0.0)
		b.lathe([Vector2(0, 0), Vector2(0.38 * s, 0), Vector2(0.38 * s, 0), Vector2(0.5 * s, 0.5 * s)], cup, 32,
			func(th: float, _t: float, _y: float) -> float: return 1.0 + 0.05 * absf(sin(th * 14.0)))
		b.mat(0.75, 0.8)
		b.blob(Vector3(0, 0.48 * s, 0), Vector3(0.6 * s, 0.45 * s, 0.6 * s), func(_u: float, _v: float, p: Vector3) -> Color:
			var col := _nz(oc, p, 0.1, 10.0 / s)
			if MeshGen.n3(p * 30.0 / s + o) > 0.45:
				col = ic
			return col, 18, 10, func(_th: float, v: float, d: Vector3) -> float:
				return (1.0 + 0.08 * MeshGen.n3(d * 3.0 + o)) * (0.75 if v < 0.45 else 1.0))
		b.xf = keep


func _cookie(R: float, H: float, oc: Color, ic: Color, k: int) -> void:
	var o := Vector3(k * 3.3, 0, 0)
	b.mat(0.75, 0.9)
	var top := func(rn: float, th: float) -> float:
		return H * (1.0 - 0.6 * pow(rn, 3.0)) + 0.1 * H * MeshGen.n3(Vector3(cos(th) * rn, 0, sin(th) * rn) * 5.0 + o)
	b.dsolid(R, top, func(rn: float, _th: float) -> float: return 0.15 * H * pow(rn, 3.0),
		func(_f: int, rn: float, _th: float, p: Vector3) -> Color:
			var c := _nz(oc, p, 0.12, 6.0 / R).lerp(oc.lightened(0.2), clampf(MeshGen.n3(p * 4.0 / R + o), 0.0, 1.0) * 0.5)
			return c.lerp(oc.darkened(0.25), smoothstep(0.75, 1.0, rn)), 28, 6,
		func(th: float) -> float: return 1.0 + 0.06 * MeshGen.n3(Vector3(cos(th), sin(th), 0) * 2.0 + o))
	b.mat(0.35, 0.1, 0.5)
	var keep := b.xf
	for i in 7:
		var rn := sqrt(MeshGen.h1(k * 17 + i)) * 0.75
		var th := i * 2.39996 + k
		var p := Vector3(cos(th) * rn * R, top.call(rn, th) - 0.02 * R, sin(th) * rn * R)
		b.xf = keep * Transform3D(Basis(Vector3.UP, th), p)
		b.rbox(Vector3.ZERO, Vector3(0.16, 0.12, 0.14) * R, 0.5, ic, 6, 4)
	b.xf = keep


func _cookies(s: float, oc: Color, ic: Color) -> void:
	var R := 0.62 * s
	var H := 0.16 * s
	for i in 3:
		var a := TAU * i / 3.0
		var keep := b.xf
		b.at(Vector3(cos(a), 0, sin(a)) * 0.7 * s)
		_cookie(R, H, oc, ic, i)
		b.xf = keep
	var keep := b.xf
	b.at(Vector3(0.1 * s, H * 1.1, 0.05 * s), Vector3(4, 30, -3))
	_cookie(R, H, oc, ic, 3)
	b.xf = keep


func _pancakes(s: float, oc: Color, ic: Color) -> void:
	var R := 1.0 * s
	var H := 0.19 * s
	var flavored := ic != Color(DB.ING["pancakes"][4])
	b.mat(0.65, 0.6)
	for i in 4:
		var keep := b.xf
		var o := Vector3(i * 4.0, 0, 0)
		b.at(Vector3(0.03 * s * sin(i * 2.0), i * H * 0.98, 0.03 * s * cos(i * 2.3)))
		b.dsolid(R, func(rn: float, _th: float) -> float: return H * (1.0 - 0.45 * pow(rn, 5.0)),
			func(rn: float, _th: float) -> float: return H * 0.4 * pow(rn, 5.0),
			func(f: int, rn: float, _th: float, p: Vector3) -> Color:
				var c := _nz(oc, p, 0.1, 8.0 / s)
				if f == 2 or rn > 0.88:
					c = oc.lightened(0.35)
				return c.lerp(oc.darkened(0.15), clampf(MeshGen.n3(p * 9.0 / s + o), 0.0, 1.0) * 0.4 * float(f != 2)), 36, 7,
			func(th: float) -> float: return 1.0 + 0.03 * MeshGen.n3(Vector3(cos(th), sin(th), 0) * 2.0 + o))
		b.xf = keep
	var top := 4 * H * 0.98
	var syrup := Color(0.55, 0.26, 0.06)
	var drip := func(th: float) -> float: return 0.8 + 0.22 * pow(maxf(0.0, sin(th * 5.0 + 0.5)), 4.0)
	b.mat(0.05, 0.0, 0.3)
	b.dsolid(R, func(rn: float, _th: float) -> float: return top + 0.03 * s * (1.0 - pow(rn, 4.0)),
		func(_rn: float, _th: float) -> float: return top - 0.02 * s,
		func(_f: int, _rn: float, _th: float, _p: Vector3) -> Color: return syrup, 36, 5, drip)
	for i in 5:
		var th := (PI * 0.5 - 0.5) / 5.0 + TAU * i / 5.0
		var e := Vector3(cos(th), 0, sin(th)) * R * 0.98
		var ln := (0.25 + 0.25 * MeshGen.h1(i)) * s
		_stem([e + Vector3(0, top, 0), e * 1.03 + Vector3(0, top - 0.06 * s, 0), e * 1.04 + Vector3(0, top - ln, 0)], 0.06 * s, 0.045 * s, syrup, 6, 5)
	if flavored:
		b.mat(0.4, 0.1, 0.3)
		for i in 6:
			var a := TAU * i / 6.0
			b.blob(Vector3(cos(a) * 0.4 * s, top + 0.12 * s, sin(a) * 0.4 * s), Vector3.ONE * 0.12 * s, ic, 10, 6)
	else:
		b.mat(0.2, 0.0, 0.3)
		b.rbox(Vector3(0, top + 0.1 * s, 0), Vector3(0.38, 0.17, 0.34) * s, 0.35, Color(1.0, 0.92, 0.5), 10, 6)


func _donuts(s: float, oc: Color, ic: Color) -> void:
	var Rt := 0.55 * s
	var r := 0.3 * s
	for k in 2:
		var c := Vector3((k - 0.5) * 1.75 * s, r, (k - 0.5) * 0.2 * s)
		var o := Vector3(k * 6.0, 0, 0)
		var glazed := func(t: float, th: float) -> float:
			return smoothstep(-0.25, -0.05, sin(th) + 0.18 * MeshGen.n3(Vector3(t * 14.0, 0, 0) + o))
		b.mat(0.55, 0.5)
		b.tube(40, 16, func(t: float) -> Vector3: return c + Vector3(cos(t * TAU), 0, sin(t * TAU)) * Rt,
			func(t: float, th: float) -> float: return r * (1.0 + 0.05 * glazed.call(t, th)),
			func(u: float, v: float, p: Vector3) -> Color:
				var g: float = glazed.call(v, u * TAU)
				return _nz(oc, p, 0.08, 10.0 / s).lerp(oc.lightened(0.3), smoothstep(-0.2, -0.9, sin(u * TAU)) * 0.5).lerp(ic, g))
		b.mat(0.4, 0.0, 0.0)
		var keep := b.xf
		for i in 26:
			var t := MeshGen.h1(k * 50 + i)
			var th := lerpf(0.25, PI - 0.25, MeshGen.h1(k * 50 + i + 99))
			var radial := Vector3(cos(t * TAU), 0, sin(t * TAU))
			var p := c + radial * Rt + (radial * cos(th) + Vector3.UP * sin(th)) * r * 1.06
			b.xf = keep * Transform3D(Basis(Vector3.UP, MeshGen.h1(i * 3) * TAU) * Basis(Vector3.FORWARD, -(th - PI * 0.5)), p)
			b.rbox(Vector3.ZERO, Vector3(0.14, 0.035, 0.035) * s, 0.6, Color.from_hsv(MeshGen.h1(i * 7 + k), 0.7, 1.0), 6, 4)
		b.xf = keep


func _drink(s: float, id: String, oc: Color) -> void:
	var tall := id == "milkshake"
	var H := (2.3 if tall else 1.9) * s
	var R0 := 0.5 * s
	var R1 := (0.66 if tall else 0.6) * s
	var fill := H * (0.78 if tall else 0.82)
	var base := 0.12 * s
	gl.mat(0.03, 0.0, 0.0)
	gl.lathe([Vector2(0, 0), Vector2(R0, 0), Vector2(R1, H), Vector2(R1 - 0.035 * s, H), Vector2(R0 - 0.035 * s, base), Vector2(0, base)], Color(1, 1, 1), 32)
	var rin := func(y: float) -> float: return lerpf(R0, R1, y / H) - 0.04 * s
	b.mat(0.1 if id == "juice" or id == "lemonade" else 0.4, 0.0, 0.0)
	b.lathe([Vector2(0, base + 0.002), Vector2(rin.call(base), base + 0.002), Vector2(rin.call(base), base + 0.002), Vector2(rin.call(fill), fill),
		Vector2(rin.call(fill), fill), Vector2(0, fill)], func(_u: float, _v: float, p: Vector3) -> Color:
			return _nz(oc, p, 0.05 if id != "smoothie" else 0.12, 12.0 / s).lerp(oc.lightened(0.15), clampf(p.y / fill - 0.6, 0.0, 1.0)), 28)
	b.mat(0.4, 0.0, 0.0)
	_stem([Vector3(0.12 * s, base + 0.1 * s, 0), Vector3(0.28 * s, H + 0.35 * s, 0.05 * s), Vector3(0.3 * s, H + 0.45 * s, 0.05 * s), Vector3(0.48 * s, H + 0.6 * s, 0.05 * s)],
		0.055 * s, 0.055 * s, func(_u: float, v: float, _p: Vector3) -> Color:
			return Color(0.95, 0.25, 0.35) if int(floor(v * 14.0)) % 2 == 0 else Color(1, 1, 1), 8, 18, false)
	match id:
		"milkshake":
			b.mat(0.6, 0.3, 0.0)
			b.dsolid(R1 * 0.95, func(rn: float, th: float) -> float:
					return fill + 0.65 * s * pow(1.0 - rn, 1.3) + 0.06 * s * maxf(0.0, cos(th * 8.0 + rn * 7.0)) * (1.0 - rn),
				func(_rn: float, _th: float) -> float: return fill - 0.01 * s,
				func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(Color(1, 0.98, 0.95), p, 0.03, 20.0 / s), 32, 10)
			b.mat(0.1, 0.0, 0.0)
			b.blob(Vector3(0, fill + 0.75 * s, 0), Vector3.ONE * 0.16 * s, Color(0.8, 0.05, 0.1), 12, 8)
		"lemonade", "juice":
			var fruit := Color(1.0, 0.92, 0.35) if id == "lemonade" else Color(1.0, 0.6, 0.15)
			var keep := b.xf
			b.at(Vector3(R1 - 0.05 * s, H - 0.05 * s, 0), Vector3(90, 0, 15))
			b.mat(0.35, 0.2, 0.0)
			_slice(0.42 * s, 0.07 * s, func(rn: float, th: float, p: Vector3) -> Color: return _citrus_face(rn, th, p, fruit, fruit.lightened(0.2)), fruit, Callable(), 24, 6)
			b.xf = keep
			if id == "lemonade":
				for i in 3:
					var a := TAU * i / 3.0
					gl.at(Vector3(cos(a) * 0.22 * s, fill - 0.04 * s, sin(a) * 0.22 * s), Vector3(20 * i, 30 * i, 10))
					gl.rbox(Vector3.ZERO, Vector3.ONE * 0.3 * s, 0.3, Color(1, 1, 1), 10, 6)
				gl.xf = Transform3D.IDENTITY
		"smoothie":
			b.mat(0.4, 0.2, 0.0)
			b.leaf(Vector3(-0.15 * s, fill + 0.02 * s, 0), Vector3(-1, 0.6, 0.2), 0.4 * s, 0.25 * s, _leafcol(Color(0.35, 0.65, 0.3), Color(0.2, 0.5, 0.2)), 0.1, 0.1, 0.3, 0.0, 0.45, 4, 5)


func _mug(s: float, oc: Color) -> void:
	var R := 0.75 * s
	var H := 1.5 * s
	var red := Color(0.78, 0.22, 0.18)
	b.mat(0.25, 0.0, 0.0)
	b.lathe(_cr([Vector2(0, 0.0), Vector2(0.92 * R, 0), Vector2(R, 0.06 * s), Vector2(R, H), Vector2(0.95 * R, H + 0.03 * s), Vector2(0.9 * R, H), Vector2(0.9 * R, 0.12 * s), Vector2(0, 0.12 * s)], 2),
		func(_u: float, v: float, _p: Vector3) -> Color: return red if v < 0.58 else CERAMIC, 32)
	b.tube(16, 10, func(t: float) -> Vector3:
		var a := t * PI * 1.1 - PI * 0.05
		return Vector3(R + sin(a) * 0.38 * s - 0.02 * s, H * 0.5 + cos(a) * 0.42 * s, 0),
		func(_t: float, _th: float) -> float: return 0.09 * s, red, 0.6, Vector3.FORWARD)
	b.mat(0.3, 0.2, 0.0)
	b.dsolid(0.9 * R, func(_rn: float, _th: float) -> float: return H * 0.86,
		func(_rn: float, _th: float) -> float: return H * 0.84,
		func(_f: int, rn: float, _th: float, p: Vector3) -> Color: return _nz(oc, p, 0.08, 10.0 / s).lerp(oc.lightened(0.25), smoothstep(0.86, 0.97, rn)), 32, 6)
	b.mat(0.8, 0.2, 0.6)
	for i in 4:
		var a := TAU * i / 4.0 + 0.4
		var keep := b.xf
		b.at(Vector3(cos(a) * 0.32 * s, H * 0.86 + 0.06 * s, sin(a) * 0.32 * s), Vector3(10 * i, 40 * i, 0))
		b.rbox(Vector3.ZERO, Vector3(0.22, 0.18, 0.22) * s, 0.5, Color(0.99, 0.97, 0.95), 8, 6)
		b.xf = keep


## Bowl with food in it: liquid sauce, smooth purée, thick dip, chunky salsa or whipped cream.
func _bowl_food(s: float, fill: Color, style: String, id: String) -> void:
	var R := 1.25 * s
	var H := 0.85 * s
	_bowl_shell(R, H)
	var L := 0.72 * H
	var ri := _bowl_inner_r(R, H, 0.72) + 0.01 * s
	var o := Vector3(rng.randf() * 9.0, 0, 0)
	match style:
		"liquid":
			b.mat(0.06, 0.0, 0.5)
			b.dsolid(ri, func(rn: float, th: float) -> float: return L + 0.008 * s * sin(rn * 14.0 + th),
				func(_rn: float, _th: float) -> float: return L - 0.04 * s,
				func(_f: int, rn: float, th: float, p: Vector3) -> Color:
					var c := _nz(fill, p, 0.05, 8.0 / s).lerp(fill.lightened(0.2), clampf(sin(th * 2.0 + rn * 9.0) * rn * 0.5, 0.0, 1.0))
					if id == "tomato_sauce" and MeshGen.n3(p * 60.0 / s) > 0.45:
						c = Color(0.25, 0.45, 0.15)
					return c, 40, 10)
			if id == "beaten_egg":
				b.mat(0.2, 0.0, 0.3)
				for i in 16:
					var rn := sqrt(MeshGen.h1(i)) * 0.85
					var th := i * 2.39996
					b.blob(Vector3(cos(th) * rn * ri, L, sin(th) * rn * ri), Vector3(1.0, 0.6, 1.0) * (0.04 + 0.05 * MeshGen.h1(i + 9)) * s, fill.lightened(0.45), 8, 5)
		"puree", "thick":
			b.mat(0.3 if style == "puree" else 0.55, 0.3 if style == "puree" else 1.2, 0.5)
			var hum := id == "hummus"
			b.dsolid(ri, func(rn: float, th: float) -> float:
					var h := L + 0.2 * H * (1.0 - rn * rn) + 0.05 * s * sin(th * 2.0 + rn * 12.0) * (1.0 - rn)
					if style == "thick":
						h += 0.04 * s * MeshGen.n3(Vector3(cos(th) * rn, 0, sin(th) * rn) * 7.0 + o)
					if hum:
						h -= 0.08 * s * exp(-pow((rn - 0.45) / 0.12, 2.0)) + 0.06 * s * exp(-rn * rn / 0.04)
					return h,
				func(_rn: float, _th: float) -> float: return L - 0.06 * s,
				func(_f: int, rn: float, th: float, p: Vector3) -> Color:
					var c := _nz(fill, p, 0.1, 12.0 / s)
					var n := MeshGen.n3(p * 45.0 / s + o)
					c = c.lerp(fill.lightened(0.15), clampf(sin(th * 2.0 + rn * 12.0), 0.0, 1.0) * 0.35)
					if id == "guacamole" and n > 0.45:
						c = Color(0.85, 0.2, 0.15) if MeshGen.n3(p * 20.0 / s) > 0.0 else Color(0.95, 0.95, 0.85)
					elif id == "guacamole":
						c = c.lerp(Color(0.35, 0.5, 0.15), clampf(MeshGen.n3(p * 25.0 / s), 0.0, 1.0) * 0.6)
					elif id == "pesto":
						c = c.darkened(0.15) if n > 0.2 else (Color(0.85, 0.75, 0.3) if n < -0.6 else c)
					elif hum:
						if rn < 0.2:
							c = Color(0.85, 0.7, 0.2)
						if n > 0.5:
							c = Color(0.75, 0.2, 0.1)
					elif id == "porridge":
						c = c.lerp(Color(0.85, 0.75, 0.55), clampf(MeshGen.n3(p * 70.0 / s), 0.0, 1.0))
						if n > 0.55:
							c = Color(0.55, 0.35, 0.2)
					return c, 44, 14)
		"chunks":
			b.mat(0.15, 0.1, 0.5)
			b.dsolid(ri, func(_rn: float, _th: float) -> float: return L, func(_rn: float, _th: float) -> float: return L - 0.04 * s,
				func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(fill.darkened(0.1), p, 0.1, 10.0 / s), 32, 5)
			var keep := b.xf
			b.mat(0.3, 0.2, 0.5)
			b.at(Vector3.ZERO)
			b.heap(26, ri * 0.85, L + 0.03 * s, 0.06 * s, func(i: int) -> void:
				var col: Color = [fill, fill.lightened(0.15), Color(0.95, 0.93, 0.85), Color(0.25, 0.55, 0.2), Color(0.95, 0.75, 0.2)][i % 5]
				_chunk(Vector3(0.16, 0.13, 0.15) * s, col, 0.5, 0.15, 6, 5), 4)
			b.xf = keep
		"whip":
			b.mat(0.65, 0.3, 0.3)
			b.dsolid(ri, func(rn: float, th: float) -> float:
					return L + 0.95 * H * pow(1.0 - rn, 1.2) + 0.06 * s * maxf(0.0, cos(th * 8.0 + rn * 9.0)) * (1.0 - rn),
				func(_rn: float, _th: float) -> float: return L - 0.04 * s,
				func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(fill, p, 0.02, 20.0 / s), 40, 12)


# ---------------------------------------------------------------- new bakery / treats

func _hotdog_bun(s: float, oc: Color, ic: Color) -> void:
	b.mat(0.4, 0.35)
	b.rbox(Vector3(0, 0.32 * s, 0), Vector3(2.4 * s, 0.64 * s, 0.75 * s), 0.5, func(_u: float, _v: float, p: Vector3) -> Color:
		if p.y < 0.08 * s:
			return _nz(ic, p, 0.06, 30.0 / s)
		return _nz(oc.lerp(oc.darkened(0.15), smoothstep(0.2 * s, 0.6 * s, p.y)), p, 0.05, 12.0 / s), 24, 14)


## Split hot dog bun lying open (two halves hinged along x), DOG_L long.
func _hotdog_open(oc: Color, ic: Color) -> void:
	var L := DOG_L
	var H := 0.03
	var W := 0.034
	b.mat(0.4, 0.35)
	for side in [-1.0, 1.0]:
		var keep := b.xf
		b.at(Vector3(0, H * 0.5, side * W * 0.62), Vector3(side * 28.0, 0, 0))
		b.rbox(Vector3.ZERO, Vector3(L, H, W), 0.5, func(_u: float, _v: float, p: Vector3) -> Color:
			var inner: bool = (p.z * side) < -W * 0.25
			return _nz(ic, p, 0.07, 200.0) if inner else _nz(oc, p, 0.05, 60.0), 24, 12)
		b.xf = keep


func _bagel(s: float, oc: Color, ic: Color) -> void:
	var R := 0.62 * s
	var r := 0.36 * s
	b.mat(0.35, 0.3)
	b.tube(36, 14, func(t: float) -> Vector3: return Vector3(cos(t * TAU) * R, r * 0.8, sin(t * TAU) * R),
		func(_t: float, _th: float) -> float: return r,
		func(_u: float, v: float, p: Vector3) -> Color:
			var top := clampf((p.y - r * 0.5) / r, 0.0, 1.0)
			return _nz(ic.lerp(oc, 0.4 + 0.6 * top), p, 0.06, 20.0 / s), 0.8)


func _croissant(s: float, oc: Color) -> void:
	b.mat(0.45, 0.6)
	b.tube(30, 14, func(t: float) -> Vector3:
			var a := (t - 0.5) * PI * 0.95
			return Vector3(sin(a) * 1.2 * s, 0.38 * s, -cos(a) * 0.75 * s + 0.4 * s),
		func(t: float, _th: float) -> float: return 0.4 * s * pow(sin(PI * clampf(t, 0.0, 1.0)), 0.7) + 0.04 * s,
		func(u: float, v: float, p: Vector3) -> Color:
			var ridge := pow(absf(sin(v * PI * 7.0)), 6.0)
			return _nz(oc.lerp(oc.lightened(0.35), ridge * 0.7), p, 0.06, 12.0 / s), 0.85)


## Kebab: wooden skewer through alternating meat and veg chunks.
func _skewer(s: float, oc: Color, ic: Color) -> void:
	var L := 2.6 * s
	b.mat(0.7, 0.2)
	b.tube(6, 6, func(t: float) -> Vector3: return Vector3((t - 0.5) * L, 0.22 * s, 0),
		func(_t: float, _th: float) -> float: return 0.025 * s, Color(0.78, 0.62, 0.42))
	var veg := [Color(0.85, 0.2, 0.15), Color(0.3, 0.6, 0.2), Color(0.95, 0.75, 0.6)]
	for i in 6:
		var x := (i / 5.0 - 0.5) * L * 0.75
		var meat := i % 2 == 0
		var c: Color = oc if meat else veg[(i / 2) % 3]
		b.mat(0.55 if meat else 0.3, 0.8 if meat else 0.2)
		var keep := b.xf
		b.at(Vector3(x, 0.22 * s, 0), Vector3(0, i * 37.0, 0))
		_chunk(Vector3(0.36, 0.36, 0.36) * s * (1.1 if meat else 0.9), func(_u: float, _v: float, p: Vector3) -> Color:
			return _nz(c, p, 0.12, 30.0 / s), 0.5, 0.15, 8, 6)
		b.xf = keep


func _icepop(s: float, oc: Color) -> void:
	b.mat(0.15, 0.1)
	b.rbox(Vector3(0, 0.9 * s, 0), Vector3(0.75 * s, 1.4 * s, 0.32 * s), 0.35, func(_u: float, _v: float, p: Vector3) -> Color:
		return _nz(oc, p, 0.05, 20.0 / s).lerp(oc.lightened(0.4), smoothstep(1.2 * s, 1.6 * s, p.y) * 0.4), 18, 12)
	b.mat(0.8, 0.2)
	b.rbox(Vector3(0, 0.12 * s, 0), Vector3(0.14 * s, 0.6 * s, 0.05 * s), 0.3, Color(0.85, 0.72, 0.5), 8, 6)


# ================================================================ cut states

static func _citrus_face(rn: float, th: float, p: Vector3, peel: Color, flesh: Color) -> Color:
	if rn > 0.93:
		return peel
	if rn > 0.86 or rn < 0.1 or absf(sin(th * 5.0)) < 0.16:
		return Color(0.98, 0.96, 0.88)
	return _nz(flesh.lerp(peel, 0.35), p, 0.15, 90.0).lerp(flesh.lightened(0.2), 0.5 + 0.5 * sin(rn * 40.0) * 0.4)


## Colour of a sliced cross-section for each ingredient.
func _face_fn(id: String, oc: Color, ic: Color) -> Callable:
	match id:
		"tomato":
			return func(rn: float, th: float, p: Vector3) -> Color:
				if rn > 0.9:
					return oc
				var loc := absf(wrapf(th, -PI / 3.0, PI / 3.0)) < 0.75 and rn > 0.3 and rn < 0.75
				if loc:
					var c := ic.lerp(Color(0.95, 0.75, 0.45), 0.35)
					return c.lerp(Color(0.98, 0.92, 0.6), float(MeshGen.n3(p * 300.0) > 0.4))
				return _nz(ic.darkened(0.08) if rn > 0.75 else ic.lightened(0.15), p, 0.06, 80.0)
		"cucumber", "zucchini":
			return func(rn: float, th: float, p: Vector3) -> Color:
				if rn > 0.94:
					return oc
				if rn > 0.82:
					return oc.lightened(0.45)
				var seedz := rn < 0.5 and absf(sin(th * 1.5)) > 0.35
				var c := ic.lerp(Color(0.85, 0.9, 0.7), 0.4) if seedz else ic
				if seedz and MeshGen.n3(p * 250.0) > 0.45:
					c = Color(0.97, 0.97, 0.9)
				return c
		"lemon", "lime", "orange":
			return func(rn: float, th: float, p: Vector3) -> Color: return _citrus_face(rn, th, p, oc, ic)
		"onion":
			return func(rn: float, _th: float, _p: Vector3) -> Color:
				var ring := fposmod(rn * 4.5, 1.0)
				return ic.lerp(Color(0.85, 0.75, 0.85), 0.3) if ring < 0.22 else ic
		"carrot":
			return func(rn: float, _th: float, p: Vector3) -> Color:
				return oc.darkened(0.1) if rn > 0.92 else (_nz(ic.lightened(0.12), p, 0.05, 50.0) if rn < 0.45 else oc)
		"banana":
			return func(rn: float, th: float, _p: Vector3) -> Color:
				return oc if rn > 0.93 else (Color(0.55, 0.45, 0.3) if rn < 0.15 and absf(sin(th * 1.5)) > 0.6 else ic)
		"eggplant":
			return func(rn: float, _th: float, p: Vector3) -> Color:
				if rn > 0.94:
					return oc
				return ic.darkened(0.25) if rn < 0.65 and MeshGen.n3(p * 200.0) > 0.45 else ic
		"boiled_egg", "egg":
			return func(rn: float, _th: float, _p: Vector3) -> Color: return Color(1.0, 0.75, 0.15) if rn < 0.55 else Color(0.98, 0.98, 0.96)
		"sausage", "pepperoni":
			return func(rn: float, _th: float, p: Vector3) -> Color:
				var c := _nz(ic, p, 0.12, 120.0)
				if MeshGen.n3(p * 300.0) > 0.5:
					c = Color(0.95, 0.85, 0.78)
				return oc.darkened(0.2) if rn > 0.92 else c
		"apple":
			return func(rn: float, th: float, _p: Vector3) -> Color:
				if rn > 0.94:
					return oc
				if rn < 0.32 and absf(sin(th * 2.5)) > 0.85:
					return Color(0.35, 0.2, 0.1)
				return ic.darkened(0.05) if rn < 0.32 else ic
		"avocado":
			return func(rn: float, _th: float, _p: Vector3) -> Color:
				return oc if rn > 0.95 else ic.lerp(Color(0.45, 0.65, 0.2), smoothstep(0.55, 0.95, rn))
		"strawberry":
			return func(rn: float, _th: float, _p: Vector3) -> Color:
				return oc if rn > 0.85 else ic.lerp(Color(0.98, 0.85, 0.85), smoothstep(0.6, 0.0, rn))
		"mushroom":
			return func(rn: float, _th: float, _p: Vector3) -> Color: return oc if rn > 0.93 else ic
		"potato", "ginger":
			return func(rn: float, _th: float, p: Vector3) -> Color: return oc if rn > 0.95 else _nz(ic, p, 0.05, 60.0)
	return func(rn: float, _th: float, p: Vector3) -> Color: return oc if rn > 0.92 else _nz(ic, p, 0.06, 60.0)


## Half of a fruit lying cut face up (apple, avocado, strawberry, citrus, boiled egg).
func _half(R: float, D: float, face: Callable, skin: Color, rf := Callable(), skin_k := 0.1) -> void:
	b.dsolid(R, func(rn: float, _th: float) -> float: return D,
		func(rn: float, _th: float) -> float: return D - D * sqrt(maxf(0.0, 1.0 - rn * rn)),
		func(f: int, rn: float, th: float, p: Vector3) -> Color:
			return face.call(rn, th, p) if f == 0 else _nz(skin, p, skin_k, 30.0), 40, 14, rf, 0.0, TAU, false)


## Rounded dice heap. skin colours one face of some pieces.
func _dice(n: int, sz: float, rad: float, ic: Color, skin: Color, skin_p := 0.4, elong := 1.0) -> void:
	b.heap(n, rad, sz * 0.4, sz * 0.75, func(i: int) -> void:
		var has_skin := MeshGen.h1(i * 5 + 3) < skin_p
		_chunk(Vector3(sz * elong, sz * 0.8, sz) * (0.8 + 0.4 * MeshGen.h1(i)), func(_u: float, _v: float, p: Vector3) -> Color:
			if has_skin and p.y > sz * 0.3:
				return skin
			return _nz(ic, p, 0.08, 20.0 / sz), 0.4, 0.12), 3 + n)


func _cut(id: String, shape: String, s: float, oc: Color, ic: Color, cut: int) -> void:
	if cut >= 2:
		_minced(id, shape, s, oc, ic)
		return
	var face := _face_fn(id, oc, ic)
	match id:
		"egg":
			_bowl_shell(1.1 * s, 0.75 * s)
			b.mat(0.1, 0.0, 1.0)
			var ri := _bowl_inner_r(1.1 * s, 0.75 * s, 0.5) + 0.01 * s
			b.dsolid(ri, func(_rn: float, _th: float) -> float: return 0.38 * s, func(_rn: float, _th: float) -> float: return 0.3 * s,
				func(_f: int, _rn: float, _th: float, _p: Vector3) -> Color: return Color(0.95, 0.93, 0.8), 28, 4)
			b.blob(Vector3(0.1 * s, 0.38 * s, 0), Vector3(0.4, 0.22, 0.4) * s, ic.lerp(Color(1, 0.6, 0.0), 0.3), 16, 8)
		"bread", "bread_loaf":
			b.mat(0.8, 0.9)
			_shingle(3, 0.65 * s, 0.2 * s, func(_i: int) -> void:
				b.dsolid(0.65 * s, func(_rn: float, _th: float) -> float: return 0.1 * s, func(_rn: float, _th: float) -> float: return -0.1 * s,
					func(f: int, rn: float, _th: float, p: Vector3) -> Color:
						return oc if f == 2 or rn > 0.92 else _nz(ic, p, 0.08, 40.0 / s), 30, 7, _bread_rf), 0.6)
		"bun":
			var keep := b.xf
			b.at(Vector3(-1.08 * s, 0, 0))
			_bun_half(s, oc, ic, false, id)
			b.xf = keep * Transform3D(Basis(Vector3.RIGHT, PI), Vector3(1.08 * s, 1.1 * STACK_R, 0))
			_bun_half(s, oc, ic, true, id)
			b.xf = keep
		"hot_dog_bun":
			var keep := b.xf
			b.at(Vector3.ZERO, Vector3.ZERO, Vector3.ONE * (s * 2.4 / DOG_L))
			_hotdog_open(oc, ic)
			b.xf = keep
		"bagel":
			for side in [-1.0, 1.0]:
				var keep := b.xf
				b.at(Vector3(side * 1.05 * s, 0, 0), Vector3.ZERO, Vector3(1, 0.5, 1))
				_bagel(s, ic if side < 0 else oc, ic)
				b.xf = keep
		"croissant":
			var keep := b.xf
			b.at(Vector3.ZERO, Vector3.ZERO, Vector3(1, 0.7, 1))
			_croissant(s, oc)
			b.xf = keep
		"dough":
			b.mat(0.85, 0.5)
			b.dsolid(1.5 * s, func(rn: float, _th: float) -> float: return 0.1 * s * (1.0 - 0.4 * pow(rn, 6.0)),
				func(_rn: float, _th: float) -> float: return 0.0,
				func(_f: int, _rn: float, _th: float, p: Vector3) -> Color:
					var c := _nz(oc, p, 0.04, 8.0 / s)
					return c.lerp(Color(1, 1, 1), 0.5) if MeshGen.n3(p * 9.0 / s) > 0.35 else c, 40, 6,
				func(th: float) -> float: return 1.0 + 0.05 * sin(th * 3.0) + 0.03 * sin(th * 7.0))
		"tortilla":
			b.mat(0.7, 0.35)
			for k in 6:
				var th0 := TAU * k / 6.0 + 0.04
				var th1 := TAU * (k + 1) / 6.0 - 0.04
				var keep := b.xf
				b.at(Vector3(cos((th0 + th1) * 0.5), 0, sin((th0 + th1) * 0.5)) * 0.12 * s)
				b.dsolid(1.25 * s, func(_rn: float, _th: float) -> float: return 0.035 * s, func(_rn: float, _th: float) -> float: return 0.0,
					func(_f: int, _rn: float, _th: float, p: Vector3) -> Color:
						return oc.lerp(Color(0.6, 0.4, 0.2), 0.6) if MeshGen.n3(p * 18.0 / s) > 0.45 else _nz(oc, p, 0.05, 8.0 / s), 36, 5, Callable(), th0, th1)
				b.xf = keep
		"pizza":
			_pizza(s, oc, ic, true)
		"pie":
			_pie(s, oc, ic, true)
		"cake":
			_cake(s, oc, ic, true)
		"toast":
			b.mat(0.75, 1.0)
			var hs := 0.92 * s
			for k in 2:
				var poly := [Vector2(-hs, -hs), Vector2(hs, -hs), Vector2(-hs, hs)] if k == 0 else [Vector2(hs, hs), Vector2(-hs, hs), Vector2(hs, -hs)]
				var cen: Vector2 = ((poly[0] as Vector2) + (poly[1] as Vector2) + (poly[2] as Vector2)) / 3.0
				var rel := []
				for pt in poly:
					rel.append((pt as Vector2) - cen)
				var keep := b.xf
				b.at(Vector3(cen.x * 1.25, 0, cen.y * 1.25))
				b.dsolid(1.0, func(rn: float, _th: float) -> float: return 0.32 * s * (1.0 - 0.15 * pow(rn, 12.0)),
					func(rn: float, _th: float) -> float: return 0.32 * s * 0.15 * pow(rn, 12.0),
					func(f: int, rn: float, _th: float, p: Vector3) -> Color:
						return oc.darkened(0.35) if f == 2 or rn > 0.93 else _nz(oc, p, 0.12, 25.0 / s), 30, 6,
					func(th: float) -> float: return _ray_poly(rel, th))
				b.xf = keep
		"boiled_egg":
			b.mat(0.25, 0.1, 0.4)
			for k in 2:
				var keep := b.xf
				b.at(Vector3((k - 0.5) * 1.5 * s, 0, 0), Vector3(0, 90, 0), Vector3(1.0, 1.0, 1.35))
				_half(0.68 * s, 0.6 * s, face, oc)
				b.xf = keep
		"apple", "avocado", "strawberry", "lemon", "lime", "orange":
			var R := (0.95 if id != "strawberry" else 0.8) * s
			var D := (0.8 if id != "strawberry" else 0.55) * s
			b.mat(0.3, 0.15)
			for k in 2:
				var keep := b.xf
				var sc := Vector3(1.0, 1.0, 1.25 if id == "avocado" else 1.0)
				b.at(Vector3((k - 0.5) * 2.1 * R, 0, 0), Vector3(0, 30 * k, 0), sc)
				_half(R, D, face, oc, Callable(), 0.1)
				if id == "avocado" and k == 0:
					b.mat(0.45, 0.3, 0.0)
					b.blob(Vector3(0, D, 0), Vector3.ONE * 0.38 * s, Color(0.45, 0.28, 0.15), 14, 9)
					b.mat(0.3, 0.15)
				b.xf = keep
		"tomato", "cucumber", "zucchini", "eggplant", "onion", "mozzarella", "pepperoni":
			var R := (0.75 if id != "pepperoni" else 0.36) * s
			var H := (0.15 if id != "pepperoni" else 0.08) * s
			b.mat(0.3 if id != "onion" else 0.25, 0.15)
			var rim := oc if id != "onion" else ic.darkened(0.08)
			var rf := Callable()
			if id == "tomato":
				rf = func(th: float) -> float: return 1.0 + 0.03 * cos(th * 5.0)
			_shingle(4, R, H, func(_i: int) -> void: _slice(R, H, face, rim, rf), 0.55)
		"carrot", "banana", "sausage", "chili", "scallion":
			var R: float = float({"carrot": 0.24, "banana": 0.24, "sausage": 0.3, "chili": 0.2, "scallion": 0.06}[id]) * s
			var H := R * (0.35 if id != "scallion" else 0.6)
			var n := 12 if id != "scallion" else 22
			b.mat(0.35, 0.2)
			b.heap(n, R * 3.2, H * 0.6, H * 1.1, func(_i: int) -> void:
				if id == "chili" or id == "scallion":
					b.tube(12, 6, func(t: float) -> Vector3: return Vector3(cos(t * TAU), 0, sin(t * TAU)) * R * 0.8,
						func(_t: float, _th: float) -> float: return R * 0.22, func(_u: float, _v: float, p: Vector3) -> Color: return _nz(oc, p, 0.1, 40.0 / s), 1.0 if id == "chili" else 2.0)
				else:
					_slice(R, H, face, oc, Callable(), 18, 5), 7, 18.0)
		"bell_pepper":
			b.mat(0.2, 0.1)
			b.heap(9, 0.8 * s, 0.06 * s, 0.1 * s, func(i: int) -> void:
				var a0 := MeshGen.h1(i) * 0.6
				b.tube(10, 6, func(t: float) -> Vector3: return Vector3((t - 0.5) * 1.2 * s, 0.12 * s * sin(t * PI + a0), 0.12 * s * cos(t * PI)),
					func(t: float, _th: float) -> float: return 0.11 * s * pow(sin(PI * clampf(t, 0.0, 1.0)), 0.15),
					func(u: float, _v: float, p: Vector3) -> Color: return _nz(oc if sin(u * TAU) > 0.0 else oc.lightened(0.3), p, 0.05, 20.0 / s), 0.3, Vector3.FORWARD), 11, 20.0)
		"mushroom":
			b.mat(0.5, 0.3)
			_shingle(4, 0.6 * s, 0.12 * s, func(_i: int) -> void:
				var mrf := func(th: float) -> float:
					var up := sin(th)
					return 1.0 if up > -0.1 else lerpf(1.0, 0.35, smoothstep(-0.1, -0.35, up))
				_slice(0.6 * s, 0.12 * s, face, oc, mrf, 28, 7), 0.6)
		"broccoli":
			b.mat(0.7, 1.0)
			for k in 4:
				var a := TAU * k / 4.0
				var keep := b.xf
				b.at(Vector3(cos(a), 0, sin(a)) * 0.5 * s, Vector3(cos(a) * 12.0, 0, -sin(a) * 12.0))
				_stem([Vector3(0, 0.0, 0), Vector3(0, 0.45 * s, 0)], 0.12 * s, 0.1 * s, ic, 6, 3)
				b.blob(Vector3(0, 0.6 * s, 0), Vector3(0.35, 0.3, 0.35) * s, func(_u: float, _v: float, p: Vector3) -> Color: return _nz(oc, p, 0.15, 14.0 / s), 12, 8,
					func(_th: float, _v: float, d: Vector3) -> float: return 1.0 + 0.12 * absf(MeshGen.n3(d * 3.0 + Vector3(k, 0, 0))))
				b.xf = keep
		"corn", "blueberry", "garlic":
			var r: float = float({"corn": 0.09, "blueberry": 0.42, "garlic": 0.32}[id]) * s
			b.mat(0.35 if id != "garlic" else 0.5, 0.1)
			b.heap(26 if id == "corn" else 8, r * (5.0 if id == "corn" else 3.0), r * 0.8, r * 1.4, func(_i: int) -> void:
				b.blob(Vector3.ZERO, Vector3(r, r * (0.8 if id != "garlic" else 1.3), r * (0.85 if id == "corn" else 0.75)), ic if id != "blueberry" else oc, 8, 6), 13)
		"chicken", "beef", "tofu", "ham", "salmon", "white_fish", "potato", "pumpkin", "pineapple", "mango", "ginger", "shrimp", "bacon":
			var elong := 1.6 if id == "beef" or id == "bacon" else 1.0
			var skin := oc
			if id == "chicken":
				skin = oc.lightened(0.1)
			_dice(10 if id != "bacon" else 14, (0.42 if id != "bacon" else 0.3) * s, 0.9 * s, ic if id != "bacon" else oc, skin, 0.4 if id in ["potato", "pumpkin", "pineapple", "mango", "salmon"] else 0.0, elong)
		"lettuce", "spinach", "cabbage", "basil", "herbs":
			_shreds(s, oc, ic, 20, 0.9 * s)
		"cheese", "parmesan", "butter":
			b.mat(0.45 if id != "butter" else 0.25, 0.25)
			_shingle(4, 0.62 * s, 0.1 * s, func(_i: int) -> void:
				b.rbox(Vector3.ZERO, Vector3(1.24 * s, 0.1 * s, 1.15 * s) * (Vector3(0.5, 1.2, 0.7) if id == "butter" else Vector3.ONE), 0.15,
					func(_u: float, _v: float, p: Vector3) -> Color: return _nz(oc, p, 0.04, 20.0 / s), 12, 6), 0.55)
		"chocolate":
			b.mat(0.3, 0.2)
			_dice(12, 0.35 * s, 0.8 * s, oc, oc, 0.0, 1.0)
		"ground_beef":
			_minced(id, shape, s, oc, ic)
		_:
			_dice(9, 0.5 * s, 0.9 * s, ic, oc, 0.35)


## Shredded leaves: small curled leaf flakes heaped up.
func _shreds(s: float, oc: Color, ic: Color, n: int, rad: float) -> void:
	b.mat(0.5, 0.2)
	b.heap(n, rad, 0.05 * s, 0.1 * s, func(i: int) -> void:
		b.leaf(Vector3(-0.2 * s, 0, 0), Vector3(1, 0.1, 0.2 * (MeshGen.h1(i) - 0.5)), 0.45 * s, 0.25 * s, _leafcol(ic, oc, 0.06), 0.15, 0.1, 0.5, 0.15, 0.5, 4, 4), 21, 40.0)


## Minced / grated: lots of tiny bits, or shreds for cheese & carrot.
func _minced(id: String, shape: String, s: float, oc: Color, ic: Color) -> void:
	if shape == "leafy" or shape == "herb":
		b.mat(0.5, 0.3)
		b.heap(45, 0.8 * s, 0.03 * s, 0.05 * s, func(i: int) -> void:
			_chunk(Vector3(0.14, 0.03, 0.11) * s, ic if i % 3 else oc, 0.6, 0.3, 5, 4), 31, 50.0)
		return
	if id in ["cheese", "parmesan", "carrot", "chocolate", "zucchini", "potato"]:
		b.mat(0.5 if id != "chocolate" else 0.35, 0.2)
		var col := oc if id in ["cheese", "parmesan", "chocolate", "carrot"] else ic
		b.heap(34, 0.75 * s, 0.03 * s, 0.07 * s, func(i: int) -> void:
			b.tube(4, 4, func(t: float) -> Vector3: return Vector3((t - 0.5) * 0.5 * s, 0.03 * s * sin(t * 3.0 + i), 0.04 * s * sin(t * 4.0 + i * 1.3)),
				func(t: float, _th: float) -> float: return 0.035 * s * (0.0 if t <= 0.0 or t >= 1.0 else 1.0),
				func(_u: float, _v: float, p: Vector3) -> Color: return _nz(col, p, 0.1, 30.0 / s), 0.6), 17, 60.0)
		return
	var meat := id in ["ground_beef", "beef", "chicken", "sausage", "bacon", "ham", "pepperoni", "patty", "meatballs"]
	b.mat(0.55 if meat else 0.45, 0.4)
	b.heap(40, 0.75 * s, 0.05 * s, 0.08 * s, func(i: int) -> void:
		var c := ic if i % 3 else oc
		_chunk(Vector3(0.14, 0.1, 0.12) * s * (0.8 + 0.4 * MeshGen.h1(i)), func(_u: float, _v: float, p: Vector3) -> Color: return _nz(c, p, 0.1, 40.0 / s), 0.55, 0.25, 6, 4), 41, 40.0)


# ================================================================ small pieces for combos

## One bite-sized piece of an ingredient at the current transform (toppings, soup bits, fillings).
func _piece(id: String, sz: float, oc: Color, ic: Color, k: int) -> void:
	var shape: String = DB.ING[id][2]
	if DB.is_dust(id):
		b.mat(0.9, 0.3)
		b.blob(Vector3.ZERO, Vector3(sz * 0.9, sz * 0.15, sz * 0.9), ic, 8, 4)
		return
	id = DB.LOOK.get(id, id)
	if DB.flag(id, "l") or shape in BOWLS or id in ["tomato_sauce", "salsa", "guacamole", "pesto", "hummus", "mayo", "caramel", "melted_chocolate"]:
		b.mat(0.15, 0.1)
		b.blob(Vector3.ZERO, Vector3(sz * 1.3, sz * 0.3, sz * 1.1), ic, 12, 6, func(th: float, _v: float, _d: Vector3) -> float: return 1.0 + 0.15 * sin(th * 3.0 + k))
		return
	match id:
		"pepperoni", "sausage", "tomato", "cucumber", "zucchini", "banana", "mozzarella", "eggplant", "carrot", "lemon", "lime", "orange", "boiled_egg", "egg":
			b.mat(0.35, 0.15)
			_slice(sz, sz * 0.28, _face_fn(id, oc, ic), oc, Callable(), 16, 4)
		"mushroom":
			b.mat(0.5, 0.2)
			_slice(sz, sz * 0.25, _face_fn(id, oc, ic), oc, func(th: float) -> float: return 1.0 if sin(th) > -0.1 else 0.45, 16, 4)
		"onion", "bell_pepper", "chili", "scallion":
			b.mat(0.3, 0.1)
			b.tube(12, 5, func(t: float) -> Vector3: return Vector3(cos(t * TAU) * sz * 0.8, 0, sin(t * TAU) * sz * (0.8 if id != "bell_pepper" else 0.5)),
				func(_t: float, _th: float) -> float: return sz * 0.14, (ic if id == "onion" else oc), 0.7)
		"basil", "spinach", "lettuce", "cabbage", "herbs":
			b.mat(0.4, 0.1)
			b.leaf(Vector3(-sz * 1.3, 0, 0), Vector3(1, 0.08, 0), sz * 2.6, sz * 1.7, _leafcol(ic, oc, 0.06), 0.1, 0.1, 0.3, 0.06, 0.5, 5, 6)
		"cheese", "parmesan":
			b.mat(0.4, 0.1)
			b.tube(4, 4, func(t: float) -> Vector3: return Vector3((t - 0.5) * sz * 2.2, 0.0, 0.2 * sz * sin(t * 3.0 + k)),
				func(t: float, _th: float) -> float: return sz * 0.18 * (0.0 if t <= 0.0 or t >= 1.0 else 1.0), oc, 0.7)
		"corn", "blueberry", "chickpeas", "beans", "rice", "garlic":
			b.mat(0.35, 0.1)
			b.blob(Vector3.ZERO, Vector3(sz, sz * 0.85, sz) * 0.6, oc if id == "blueberry" else ic, 8, 6)
		"fried_egg":
			b.mat(0.3, 0.1)
			b.blob(Vector3.ZERO, Vector3(sz * 1.4, sz * 0.25, sz * 1.2), Color(0.98, 0.97, 0.94), 12, 6)
			b.blob(Vector3(0, sz * 0.15, 0), Vector3(sz * 0.6, sz * 0.35, sz * 0.6), Color(1, 0.7, 0.1), 10, 6)
		"ground_beef", "patty", "meatballs":
			b.mat(0.55, 0.8)
			_chunk(Vector3(sz, sz * 0.75, sz), func(_u: float, _v: float, p: Vector3) -> Color: return _nz(oc, p, 0.15, 6.0 / sz), 0.6, 0.3, 7, 5)
		_:
			b.mat(0.45, 0.3)
			_chunk(Vector3(sz * 1.25, sz * 0.8, sz), func(_u: float, _v: float, p: Vector3) -> Color:
				return oc if p.y > sz * 0.3 and k % 2 == 0 else _nz(ic, p, 0.08, 6.0 / sz), 0.4, 0.12, 7, 5)


## Several pieces of one ingredient. mode 0: scattered on a pizza/flat top (radius 0.16),
## 1: floating in soup, 2: filling disc for a wrap end, 3: taco filling strip, 4: tossed salad.
func _bits(id: String, _cut: int, _s: float, oc: Color, ic: Color, code: int) -> void:
	var mode := code / 10
	var k := code % 10
	var keep := b.xf
	var n: int = [7, 6, 4, 7, 8][mode]
	var sz: float = [0.022, 0.024, 0.012, 0.016, 0.026][mode]
	for i in n:
		var a := i * 2.39996 + k * 0.9
		var pos: Vector3
		match mode:
			0:
				pos = Vector3(cos(a), 0, sin(a)) * 0.15 * sqrt((i + 0.5) / n)
			1:
				pos = Vector3(cos(a), 0, sin(a)) * (0.025 + 0.1 * sqrt((i + 0.5) / n))
			2:
				pos = Vector3(cos(a), 0, sin(a)) * 0.032 * sqrt((i + 0.5) / n)
			3:
				pos = Vector3((float(i) / (n - 1) - 0.5) * 0.13, 0.006 * sin(a * 3.0), 0.01 * sin(a))
			_:
				var rr := 0.095 * sqrt((i + 0.5) / n)
				pos = Vector3(cos(a) * rr, (0.095 - rr) * 0.35 + 0.004 * MeshGen.h1(i + k), sin(a) * rr)
		var tilt := 16.0 if mode != 4 else 40.0
		b.at(pos, Vector3(MeshGen.h1(i + k * 7) * tilt - tilt * 0.5, MeshGen.h1(i * 3 + k) * 360.0, MeshGen.h1(i * 5 + k) * tilt - tilt * 0.5), Vector3.ONE, keep)
		_piece(id, sz, oc, ic, i)
	b.xf = keep


## A sauce poured over a base dish: a glossy puddle that follows the base's top surface.
func _sauce_on(ic: Color, base: Dictionary) -> void:
	var bm := leaf_mesh(base)
	var bb := bm.get_aabb()
	var verts: PackedVector3Array = bm.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var G := 24
	var grid := PackedFloat32Array()
	grid.resize(G * G)
	grid.fill(-1e9)
	for p in verts:
		var gx := clampi(int((p.x - bb.position.x) / bb.size.x * G), 0, G - 1)
		var gz := clampi(int((p.z - bb.position.z) / bb.size.z * G), 0, G - 1)
		grid[gz * G + gx] = maxf(grid[gz * G + gx], p.y)
	var height := func(x: float, z: float) -> float:
		var gx := clampi(int((x - bb.position.x) / bb.size.x * G), 0, G - 1)
		var gz := clampi(int((z - bb.position.z) / bb.size.z * G), 0, G - 1)
		var h := -1e9
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				h = maxf(h, grid[clampi(gz + dz, 0, G - 1) * G + clampi(gx + dx, 0, G - 1)])
		return h if h > -1e8 else bb.position.y
	var c := bb.get_center()
	var R := minf(bb.size.x, bb.size.z) * 0.36
	b.mat(0.08, 0.05, 0.5)
	b.dsolid(R, func(rn: float, th: float) -> float:
			return height.call(c.x + cos(th) * rn * R, c.z + sin(th) * rn * R) + 0.004 * (1.0 - rn * rn) + 0.002,
		func(rn: float, th: float) -> float: return height.call(c.x + cos(th) * rn * R, c.z + sin(th) * rn * R) - 0.002,
		func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(ic, p, 0.06, 80.0), 36, 10,
		func(th: float) -> float: return 1.0 + 0.2 * pow(maxf(0.0, sin(th * 5.0 + 0.7)), 3.0) + 0.06 * sin(th * 13.0))


## Burger / sandwich layer for one leaf, sized around STACK_R with its bottom near y=0.
func _layer(id: String, cut: int, oc: Color, ic: Color) -> void:
	var R := STACK_R
	var shape: String = DB.ING[id][2]
	var real_id := id
	if DB.LOOK.has(id) and not DB.flag(id, "l") and id != "mayonnaise":
		id = DB.LOOK[id]
	match id:
		"lettuce", "spinach", "cabbage", "basil":
			b.mat(0.45, 0.3)
			b.dsolid(R * 1.12, func(rn: float, th: float) -> float: return 0.012 + 0.008 * sin(th * 9.0) * pow(rn, 2.0),
				func(rn: float, th: float) -> float: return 0.006 + 0.008 * sin(th * 9.0) * pow(rn, 2.0) - 0.004 * pow(rn, 2.0),
				func(_f: int, rn: float, th: float, p: Vector3) -> Color:
					var c := ic.lerp(oc, smoothstep(0.4, 1.0, rn))
					return c.lerp(ic.lightened(0.3), pow(absf(sin(th * 4.0)), 30.0) * 0.6), 40, 6,
				func(th: float) -> float: return 1.0 + 0.07 * sin(th * 7.0) + 0.04 * sin(th * 13.0))
		"tomato", "cucumber", "zucchini", "onion", "mozzarella", "pepperoni", "eggplant", "boiled_egg", "egg", "sausage", "avocado", "mushroom", "banana", "apple":
			var sr := R * (0.52 if id != "pepperoni" else 0.4)
			var sh := R * 0.12
			var face := _face_fn(id, oc, ic)
			var rim := oc
			if id == "avocado":
				face = func(rn: float, _th: float, _p: Vector3) -> Color: return ic.lerp(Color(0.45, 0.65, 0.2), smoothstep(0.4, 1.0, rn))
				rim = Color(0.3, 0.45, 0.15)
			b.mat(0.3, 0.15)
			var cnt := 3 if id != "pepperoni" else 5
			for i in cnt:
				var a := TAU * i / cnt + 0.3
				var keep := b.xf
				b.at(Vector3(cos(a) * R * 0.46, sh * 0.5 + i * sh * 0.7, sin(a) * R * 0.46), Vector3(0, 0, 0), Vector3(1, 1, 0.75 if id == "avocado" else 1.0))
				_slice(sr, sh, face, rim, Callable(), 22, 5)
				b.xf = keep
		"cheese", "parmesan":
			b.mat(0.3, 0.1)
			var sq := func(th: float) -> float: return 1.0 / pow(pow(absf(cos(th)), 8.0) + pow(absf(sin(th)), 8.0), 0.125)
			var droop := func(rn: float, th: float) -> float:
				var d: float = rn * sq.call(th)
				return -0.03 * pow(maxf(0.0, d - 0.85), 1.5) * 3.0
			var keep := b.xf
			b.at(Vector3.ZERO, Vector3(0, 45, 0))
			b.dsolid(R * 0.95, func(rn: float, th: float) -> float: return 0.035 + droop.call(rn, th),
				func(rn: float, th: float) -> float: return 0.026 + droop.call(rn, th),
				func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(oc, p, 0.04, 40.0), 40, 8, sq)
			b.xf = keep
		"patty", "beef", "ground_beef", "meatballs":
			b.mat(0.6, 1.3)
			b.dsolid(R * 1.02, func(rn: float, th: float) -> float: return 0.042 * (1.0 - 0.3 * pow(rn, 6.0)) + 0.003 * MeshGen.n3(Vector3(cos(th) * rn, 0, sin(th) * rn) * 6.0),
				func(rn: float, _th: float) -> float: return 0.008 * pow(rn, 6.0),
				func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(Color(DB.ING["patty"][3]), p, 0.15, 160.0), 40, 9,
				func(th: float) -> float: return 1.0 + 0.04 * sin(th * 5.0 + 1.0))
		"chicken", "salmon", "white_fish":
			b.mat(0.5, 0.9)
			var keep := b.xf
			b.at(Vector3.ZERO, Vector3.ZERO, Vector3(1.15, 1.0, 0.85))
			b.dsolid(R, func(rn: float, _th: float) -> float: return 0.03 * (1.0 - 0.45 * pow(rn, 4.0)),
				func(rn: float, _th: float) -> float: return 0.01 * pow(rn, 4.0),
				func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(oc, p, 0.1, 80.0), 36, 7,
				func(th: float) -> float: return 1.0 + 0.06 * sin(th * 3.0))
			b.xf = keep
		"bacon":
			b.mat(0.45, 0.35)
			var fat := Color(0.98, 0.88, 0.84)
			for i in 2:
				var z := (i - 0.5) * R * 0.7
				b.tube(24, 8, func(t: float) -> Vector3: return Vector3((t - 0.5) * R * 2.3, 0.008 + 0.006 * sin(t * 12.0 + i), z),
					func(t: float, _th: float) -> float: return R * 0.3 * pow(sin(PI * clampf(t, 0.0, 1.0)), 0.1),
					func(u: float, v: float, _p: Vector3) -> Color:
						var x := cos(u * TAU)
						return fat if MeshGen.n3(Vector3(x * 2.2 + i * 3.0, v * 1.8, 0)) > 0.1 or x > 0.7 else oc, 0.12)
		"ham":
			b.mat(0.4, 0.2)
			b.dsolid(R * 1.05, func(rn: float, th: float) -> float: return 0.012 + 0.008 * sin(cos(th) * rn * 6.0),
				func(rn: float, th: float) -> float: return 0.004 + 0.008 * sin(cos(th) * rn * 6.0),
				func(_f: int, rn: float, _th: float, p: Vector3) -> Color: return _nz(oc, p, 0.08, 60.0).lerp(Color(0.98, 0.9, 0.88), smoothstep(0.88, 0.96, rn)), 36, 7,
				func(th: float) -> float: return 1.0 + 0.08 * sin(th * 4.0))
		"fried_egg":
			var keep := b.xf
			b.at(Vector3.ZERO, Vector3.ZERO, Vector3.ONE * (R / (1.1 * 0.08 * S)))
			_fried_egg(0.08 * S)
			b.xf = keep
		"bell_pepper", "chili":
			b.mat(0.2, 0.1)
			for i in 3:
				var c := Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * R * 0.4
				b.tube(16, 6, func(t: float) -> Vector3: return c + Vector3(cos(t * TAU), 0, sin(t * TAU)) * R * 0.4 + Vector3(0, 0.008 + i * 0.004, 0),
					func(_t: float, _th: float) -> float: return 0.008, oc, 0.8)
		_:
			if DB.flag(real_id, "l") or shape in BOWLS or DB.is_topping(real_id) or real_id in ["mayo", "jam", "peanut_butter", "caramel", "melted_chocolate"]:
				b.mat(0.12, 0.1)
				var o := float(id.hash() % 100)
				b.dsolid(R * 0.85, func(rn: float, _th: float) -> float: return 0.008 * (1.0 - pow(rn, 4.0)) + 0.003,
					func(_rn: float, _th: float) -> float: return 0.0,
					func(_f: int, _rn: float, _th: float, p: Vector3) -> Color: return _nz(ic, p, 0.05, 60.0), 32, 4,
					func(th: float) -> float: return 1.0 + 0.18 * pow(maxf(0.0, sin(th * 5.0 + o)), 3.0))
			else:
				_fit_leaf(real_id, cut, R * 2.1, R * 0.6)


## Builds another leaf's normal model and merges it in, scaled to fit w x h with its base at y=0.
func _fit_leaf(id: String, cut: int, w: float, h: float) -> void:
	var g := Models.new(null)
	g.begin("fit|" + id)
	var d := DB.new_leaf(id)
	d["cut"] = cut
	g._gen(d, "")
	var bb := g.b.aabb()
	var k := minf(w / maxf(maxf(bb.size.x, bb.size.z), 0.001), 1.5)
	var ky := minf(k, h / maxf(bb.size.y, 0.001))
	var c := bb.get_center()
	b.append(g.b, Transform3D(Basis.from_scale(Vector3(k, ky, k)), Vector3(-c.x * k, -bb.position.y * ky, -c.z * k)))


## Tortilla shell for wraps: rolled burrito (open at +x) or folded taco.
func _wrap_shell(oc: Color, taco: bool) -> void:
	var spot := func(_u: float, _v: float, p: Vector3) -> Color:
		return oc.lerp(Color(0.62, 0.42, 0.2), 0.6) if MeshGen.n3(p * 120.0) > 0.45 else _nz(oc, p, 0.05, 50.0)
	b.mat(0.7, 0.35)
	if taco:
		var R := 0.1
		var Rf := 0.045
		b.surf(24, 10, func(u: float, v: float) -> Vector3:
			var x := (u - 0.5) * 2.0 * R
			var half := sqrt(maxf(0.0, R * R - x * x))
			var z := (v - 0.5) * 2.0 * half
			var ph := z / Rf
			return Vector3(x, Rf - Rf * cos(ph) + 0.002, Rf * sin(ph)), spot, false, false)
		return
	var L := 0.2
	var R := 0.05
	b.tube(30, 20, func(t: float) -> Vector3: return Vector3(-L * 0.5 + L * t, R + 0.002, 0),
		func(t: float, th: float) -> float:
			var r := R * (1.0 + 0.04 * sin(th * 3.0 + t * 8.0)) * sqrt(clampf(t / 0.08, 0.0, 1.0))
			return r * (1.0 + 0.06 * smoothstep(0.85, 1.0, t)), spot)


# ================================================================ combos

const BASE_SHAPES := ["pizza", "pancakes", "waffle", "cake", "cheesecake", "brownies", "steamed_rice", "cooked_quinoa",
	"cooked_couscous", "cooked_pasta", "cooked_penne", "cooked_macaroni", "cooked_noodles", "cooked_rice_noodles",
	"toast", "mashed_potato", "hash_browns", "pie", "quiche", "porridge", "overnight_oats", "dal", "tortilla_chips",
	"crackers", "fries", "sweet_potato_fries", "nori", "french_toast", "bread_loaf", "ice_cream", "frozen_yogurt",
	"yogurt", "hot_chocolate", "smoothie", "milkshake", "juice", "lemonade", "custard"]
const STACK_BASES := ["bun", "brioche_bun", "english_muffin", "bagel", "croissant", "crumpet"]


## Sandwich-like builds (buns, sliced bread, wraps) keep their sauces inside as layers.
static func has_frame(ls: Array) -> bool:
	for l in ls:
		var id: String = l["id"]
		if id in STACK_BASES or id in ["hot_dog_bun", "tortilla", "pita", "naan"] or (id in ["bread", "bread_loaf", "baguette"] and int(l.get("cut", 0)) > 0):
			return true
	return false


## Leaves drawn ON the food (seasoning, styled sauce) rather than as part of it.
static func is_top(l: Dictionary, framed: bool) -> bool:
	if framed:
		return l.get("sstyle", "") == "side"
	return l.has("sstyle") or DB.is_dust(l["id"])


func build_combo(ls: Array) -> void:
	var tops := []
	var rest := []
	var framed := has_frame(ls)
	for l in ls:
		if is_top(l, framed):
			tops.append(l)
		else:
			rest.append(l)
	if rest.is_empty():
		rest = tops
		tops = []
	_combo_body(rest)
	if not tops.is_empty():
		top_coat(tops, 1.0)


func _combo_body(ls: Array) -> void:
	if ls.size() == 1:
		_leaf(ls[0])
		return
	var stack_base := -1
	var wrap := -1
	var dog := -1
	for i in ls.size():
		var id: String = ls[i]["id"]
		var cut := int(ls[i].get("cut", 0))
		if id == "hot_dog_bun" and dog < 0:
			dog = i
		elif id in STACK_BASES or (id in ["bread", "bread_loaf"] and cut > 0):
			stack_base = i
		elif id == "baguette" and cut > 0 and dog < 0:
			dog = i
		elif id in ["tortilla", "pita", "naan"] and wrap < 0:
			wrap = i
	if dog >= 0:
		_hotdog(ls, dog)
		return
	if stack_base >= 0:
		_stack(ls, stack_base)
		return
	if wrap >= 0:
		_wrap(ls, wrap)
		return
	var liquid := 0
	for l in ls:
		var id: String = l["id"]
		if int(l.get("cut", 0)) >= 3 or DB.flag(id, "l") or (l.get("cook", "") == "boil" and not DB.flag(id, "n")):
			liquid += 1
	if liquid * 2 >= ls.size():
		_soup(ls)
		return
	_pile(ls)


func _place(m: Mesh, d, tr: Transform3D) -> MeshInstance3D:
	return _inst(m, d, tr)


## Where a filling goes in a burger: greens, tomato, meat, cheese, bacon, onion/pickle, sauce.
static func _layer_rank(l: Dictionary) -> float:
	var id: String = l["id"]
	if id in ["mayo", "mayonnaise", "aioli", "garlic_butter", "butter", "cream_cheese"]:
		return 0.5
	if DB.is_topping(id):
		return 6.5
	match DB.LOOK.get(id, id):
		"lettuce", "spinach", "cabbage", "basil": return 1.0
		"tomato", "avocado", "cucumber": return 2.0
		"cheese", "parmesan", "mozzarella", "tofu": return 4.0
		"bacon", "ham": return 5.0
		"onion", "jam": return 6.0
	if DB.ING[id][1] in ["meat", "fish", "protein"] or id in ["patty", "falafel", "fried_egg", "poached_egg", "meatballs", "hash_browns"]:
		return 3.0
	return 5.5


func _stack(ls: Array, bi: int) -> void:
	var base: Dictionary = ls[bi]
	var m := leaf_mesh(base, "bun_bot")
	var ab := m.get_aabb()
	_place(m, base, Transform3D(Basis.IDENTITY, Vector3(0, -ab.position.y, 0)))
	var y := ab.size.y
	var others := []
	for i in ls.size():
		if i != bi:
			others.append(ls[i])
	var order := range(others.size())
	order.sort_custom(func(a, c): return _layer_rank(others[a]) < _layer_rank(others[c]) \
		or (_layer_rank(others[a]) == _layer_rank(others[c]) and a < c))
	var k := 0
	for oi in order:
		var l: Dictionary = others[oi]
		var lm := leaf_mesh(l, "layer")
		var lb := lm.get_aabb()
		_place(lm, l, Transform3D(Basis(Vector3.UP, k * 0.9), Vector3(0, y - lb.position.y - lb.size.y * 0.12, 0)))
		y += lb.size.y * 0.88
		k += 1
	var tm := leaf_mesh(base, "bun_top")
	var tb := tm.get_aabb()
	_place(tm, base, Transform3D(Basis.IDENTITY, Vector3(0, y - tb.position.y - 0.002, 0)))


const DOG_L := 0.2


## Hot dog: split bun, the sausage lying in the groove, toppings along it, sauce zig-zagged on top.
func _hotdog(ls: Array, di: int) -> void:
	var bun: Dictionary = ls[di]
	var bm := leaf_mesh(bun, "dog_open")
	_place(bm, bun, Transform3D.IDENTITY)
	var bb := bm.get_aabb()
	var groove := bb.position.y + bb.size.y * 0.42
	var top := groove
	var main_done := false
	var sauces := []
	var j := 0
	for i in ls.size():
		if i == di:
			continue
		var l: Dictionary = ls[i]
		var id: String = l["id"]
		if DB.is_topping(id) and not DB.is_dust(id):
			sauces.append(l)
			continue
		if not main_done and (DB.ING[id][1] in ["meat", "fish", "protein"] or id in ["falafel", "meatballs", "patty"]):
			main_done = true
			var m := leaf_mesh(l)
			var ab := m.get_aabb()
			var long := maxf(ab.size.x, ab.size.z)
			var sc := DOG_L * 1.08 / maxf(long, 0.001)
			var basis := Basis.from_scale(Vector3.ONE * sc)
			if ab.size.z > ab.size.x:
				basis = Basis(Vector3.UP, PI * 0.5) * basis
			var tr := Transform3D(basis, Vector3.ZERO)
			var c := tr * ab.get_center()
			tr.origin = Vector3(-c.x, groove - (tr * ab.position).y - ab.size.y * sc * 0.25, -c.z)
			_place(m, l, tr)
			top = maxf(top, groove + ab.size.y * sc * 0.75)
			continue
		_place(leaf_mesh(l, "bits%d" % (30 + j % 10)), l, Transform3D(Basis.from_scale(Vector3(1.4, 1, 0.7)), Vector3(0, top - 0.004 + j * 0.004, 0)))
		j += 1
	for si in sauces.size():
		var l: Dictionary = sauces[si]
		var pts := []
		for p in 11:
			var t := float(p) / 10.0
			pts.append(Vector2((t - 0.5) * DOG_L * 0.95, (0.012 if p % 2 == 0 else -0.012) + si * 0.004))
		var g := Models.new(null)
		g.begin("dogsauce")
		g._stroke_flat(pts, top + 0.004 + si * 0.003, Color(DB.ING[l["id"]][4]), 0.0045)
		_inst(g.finish(), l)


# ---------------------------------------------------------------- toppings: seasoning & sauce ON the food

## Highest surface point grid of everything built so far under root.
func _heightmap() -> Dictionary:
	var G := 32
	var pts := PackedVector3Array()
	for c in root.get_children():
		var mi := c as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for si in mi.mesh.get_surface_count():
			for p in (mi.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
				pts.append(mi.transform * p)
	var hm := {"G": G, "ok": not pts.is_empty()}
	if pts.is_empty():
		hm.merge({"x0": -0.1, "z0": -0.1, "sx": 0.2, "sz": 0.2, "floor": 0.0, "g": PackedFloat32Array()})
		return hm
	var mn := pts[0]
	var mx := pts[0]
	for p in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	var grid := PackedFloat32Array()
	grid.resize(G * G)
	grid.fill(-1e9)
	var sx := maxf(mx.x - mn.x, 0.001)
	var sz := maxf(mx.z - mn.z, 0.001)
	for p in pts:
		var gi := clampi(int((p.z - mn.z) / sz * G), 0, G - 1) * G + clampi(int((p.x - mn.x) / sx * G), 0, G - 1)
		grid[gi] = maxf(grid[gi], p.y)
	hm.merge({"x0": mn.x, "z0": mn.z, "sx": sx, "sz": sz, "floor": mn.y, "g": grid})
	return hm


static func _hm_at(hm: Dictionary, x: float, z: float) -> float:
	var G: int = hm["G"]
	if not hm["ok"]:
		return 0.0
	var gx := int((x - hm["x0"]) / hm["sx"] * G)
	var gz := int((z - hm["z0"]) / hm["sz"] * G)
	if gx < -1 or gz < -1 or gx > G or gz > G:
		return -1e9
	var g: PackedFloat32Array = hm["g"]
	var h := -1e9
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			h = maxf(h, g[clampi(gz + dz, 0, G - 1) * G + clampi(gx + dx, 0, G - 1)])
	return h


## Draws seasonings and sauces on top of what is already built. k scales plate-space
## paths (and sizes) into this root's local space.
func top_coat(tops: Array, k: float) -> void:
	var hm := _heightmap()
	var cx: float = hm["x0"] + hm["sx"] * 0.5
	var cz: float = hm["z0"] + hm["sz"] * 0.5
	var hx: float = hm["sx"] * 0.36
	var hz: float = hm["sz"] * 0.36
	for i in tops.size():
		var l: Dictionary = tops[i]
		var id: String = l["id"]
		var col := Color(DB.ING[id][4])
		var style: String = l.get("sstyle", "dust" if DB.is_dust(id) else "drizzle")
		var g := Models.new(null)
		g.begin("top|%s|%d" % [id, i])
		g.rng.seed = i * 7919 + id.hash()
		match style:
			"dust":
				g._specks(hm, id, col, k)
			"side":
				var dip := Models.new(null)
				dip.begin("dip")
				dip._bowl_food(0.045 * k, col, "liquid" if DB.flag(id, "l") else "thick", id)
				g.b.append(dip.b, Transform3D(Basis.IDENTITY, Vector3(hm["x0"] + hm["sx"] + 0.05 * k, hm["floor"], cz)))
			"dollop":
				var y := _hm_at(hm, cx, cz)
				g.b.mat(0.15, 0.2)
				g.b.blob(Vector3(cx, y + 0.008 * k, cz), Vector3(0.022, 0.012, 0.02) * k, col, 14, 8,
					func(th: float, v: float, _d: Vector3) -> float: return 1.0 + 0.12 * sin(th * 4.0 + v * 3.0))
			_:
				var strokes := []
				if l.has("path") and not (l["path"] as Array).is_empty():
					for st in l["path"]:
						var pts := []
						for p in st:
							pts.append(Vector2(p[0], p[1]) * k)
						strokes.append(pts)
				else:
					strokes = _preset_strokes(style, cx, cz, hx, hz)
				for st in strokes:
					g._stroke_on(hm, st, col, (0.0035 if style != "spiral" else 0.003) * k)
		if not g.b.empty():
			_inst(g.finish(), l)


static func _preset_strokes(style: String, cx: float, cz: float, hx: float, hz: float) -> Array:
	var out := []
	match style:
		"zigzag":
			var pts := []
			for p in 9:
				pts.append(Vector2(cx + (p / 8.0 * 2.0 - 1.0) * hx, cz + (0.7 if p % 2 == 0 else -0.7) * hz))
			out.append(pts)
		"spiral":
			var pts := []
			for p in 40:
				var t := p / 39.0
				var a := t * TAU * 2.5
				pts.append(Vector2(cx + cos(a) * hx * (0.15 + 0.85 * t), cz + sin(a) * hz * (0.15 + 0.85 * t)))
			out.append(pts)
		_: # drizzle: three loose wavy lines
			for w in 3:
				var pts := []
				for p in 14:
					var t := p / 13.0
					pts.append(Vector2(cx + (t * 2.0 - 1.0) * hx, cz + ((w - 1) * 0.55 + 0.18 * sin(t * 9.0 + w)) * hz))
				out.append(pts)
	return out


func _specks(hm: Dictionary, id: String, col: Color, k: float) -> void:
	b.mat(0.8, 0.2)
	var n := 110 if id != "salt" else 70
	for i in n:
		var a := rng.randf() * TAU
		var r := sqrt(rng.randf()) * 0.46
		var x: float = hm["x0"] + hm["sx"] * (0.5 + cos(a) * r)
		var z: float = hm["z0"] + hm["sz"] * (0.5 + sin(a) * r)
		var y := _hm_at(hm, x, z)
		if y < -1e8:
			continue
		var c := col
		match id:
			"sprinkles": c = Color.from_hsv(rng.randf(), 0.7, 1.0)
			"black_pepper": c = Color(0.1, 0.09, 0.08).lightened(rng.randf() * 0.2)
			"salt", "sugar", "icing_sugar": c = Color(0.97, 0.97, 0.98)
			_: c = _nz(col, Vector3(x, y, z), 0.3, 300.0)
		var sz := (0.0016 + rng.randf() * 0.0016) * k
		if id == "sprinkles":
			b.rbox(Vector3(x, y + sz * 0.5, z), Vector3(sz * 3.0, sz, sz), 0.6, c, 5, 3)
		else:
			b.blob(Vector3(x, y + sz * 0.4, z), Vector3(sz, sz * 0.55, sz), c, 5, 3)


## A sauce line laid over the food's top surface.
func _stroke_on(hm: Dictionary, pts: Array, col: Color, r: float) -> void:
	if pts.size() < 2:
		if pts.size() == 1:
			var p: Vector2 = pts[0]
			b.mat(0.1, 0.1, 0.5)
			b.blob(Vector3(p.x, maxf(_hm_at(hm, p.x, p.y), hm["floor"]) + r, p.y), Vector3(r * 2.0, r, r * 2.0), col, 10, 6)
		return
	var p3 := []
	for p in pts:
		var h := _hm_at(hm, p.x, p.y)
		p3.append(Vector3(p.x, (h if h > -1e8 else hm["floor"]) + r * 0.7, p.y))
	b.mat(0.08, 0.1, 0.5)
	b.tube(maxi(6, p3.size() * 3), 6, func(t: float) -> Vector3: return _path(p3, t),
		func(t: float, _th: float) -> float: return r * clampf(minf(t, 1.0 - t) * 30.0, 0.35, 1.0),
		func(_u: float, _v: float, p: Vector3) -> Color: return _nz(col, p, 0.05, 90.0), 0.55)


## Flat sauce line at a fixed height (hot dog zig-zag).
func _stroke_flat(pts: Array, y: float, col: Color, r: float) -> void:
	var p3 := []
	for p in pts:
		p3.append(Vector3(p.x, y, p.y))
	b.mat(0.08, 0.1, 0.5)
	b.tube(p3.size() * 4, 6, func(t: float) -> Vector3: return _path(p3, t),
		func(t: float, _th: float) -> float: return r * clampf(minf(t, 1.0 - t) * 30.0, 0.35, 1.0), col, 0.55)


func _wrap(ls: Array, wi: int) -> void:
	var t: Dictionary = ls[wi]
	var taco: bool = t.get("cook", "") == "fry"
	_place(leaf_mesh(t, "taco" if taco else "wrap"), t, Transform3D.IDENTITY)
	var j := 0
	for i in ls.size():
		if i == wi:
			continue
		var l: Dictionary = ls[i]
		if taco:
			_place(leaf_mesh(l, "bits%d" % (30 + j % 10)), l, Transform3D(Basis.IDENTITY, Vector3(0, 0.062 + j * 0.01, 0)))
		else:
			var bs := Basis(Vector3.FORWARD, PI * 0.5)
			_place(leaf_mesh(l, "bits%d" % (20 + j % 10)), l, Transform3D(bs, Vector3(0.1 - 0.004 * j, 0.052, 0)))
		j += 1


func _soup(ls: Array) -> void:
	var lc := Color(0, 0, 0)
	var lw := 0.0
	for l in ls:
		var c := Models.tinted(Color(DB.ING[l["id"]][4]), l)
		var w := 2.0 if (DB.flag(l["id"], "l") or int(l.get("cut", 0)) >= 3) else 1.0
		lc += c * w
		lw += w
	lc = lc / lw
	lc.a = 1.0
	var key := "soup|" + lc.to_html(false)
	var m: ArrayMesh = _food.get(key)
	if m == null:
		var g := Models.new(null)
		g.begin(key)
		g._bowl_food(0.1 * S, lc, "liquid", "soup")
		m = g.finish()
		_food[key] = m
	_inst(m, null)
	var level := 0.72 * 0.85 * 0.1 * S
	var j := 0
	for l in ls:
		if DB.flag(l["id"], "l") or int(l.get("cut", 0)) >= 3:
			continue
		_place(leaf_mesh(l, "bits%d" % (10 + j % 10)), l, Transform3D(Basis.IDENTITY, Vector3(0, level - 0.003, 0)))
		j += 1
		if j >= 8:
			break


## Highest vertex of a mesh within r of (x, z).
static func _mesh_top(m: Mesh, x: float, z: float, r: float) -> float:
	var best := -1e9
	var r2 := r * r
	for p in (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array):
		var dx := p.x - x
		var dz := p.z - z
		if dx * dx + dz * dz <= r2 and p.y > best:
			best = p.y
	return best


const TOP_BASES := ["pizza", "pancakes", "steamed_rice", "cooked_pasta", "cooked_noodles", "toast", "french_toast",
	"porridge", "ice_cream", "yogurt", "cake", "pie", "tortilla_chips", "nori"]
const SAUCES := ["tomato_sauce", "salsa", "guacamole", "pesto", "hummus", "mayo", "ketchup", "mustard", "caramel",
	"melted_chocolate", "honey", "maple_syrup", "soy_sauce", "jam", "peanut_butter", "whipped_cream"]


static func _is_sauce(l: Dictionary) -> bool:
	var id: String = l["id"]
	return id in SAUCES or (DB.flag(id, "l") and not DB.flag(id, "n"))


func _pile(ls: Array) -> void:
	var base := -1
	var best := 999
	for i in ls.size():
		var idx := BASE_SHAPES.find(ls[i]["id"])
		if idx >= 0 and idx < best:
			best = idx
			base = i
	var solids := []
	var sauces := []
	for i in ls.size():
		if i == base:
			continue
		if base >= 0 and _is_sauce(ls[i]):
			sauces.append(ls[i])
		else:
			solids.append(ls[i])
	if base < 0:
		var toss := solids.size() > 1
		for l in solids:
			if int(l.get("cut", 0)) < 1 or DB.flag(l["id"], "i"):
				toss = false
		if toss:
			for j in solids.size():
				var l: Dictionary = solids[j]
				_place(leaf_mesh(l, "bits%d" % (40 + j % 10)), l, Transform3D(Basis(Vector3.UP, j * 1.3), Vector3(0, j * 0.007, 0)))
		else:
			_ring(solids, 0.0, 1.0)
		return
	var bl: Dictionary = ls[base]
	var bm := leaf_mesh(bl)
	var btr := Transform3D.IDENTITY
	if not bl["id"] in TOP_BASES:
		btr = _ring([bl] + solids, 0.0, 1.0)[0]
		solids = []
	else:
		_place(bm, bl, btr)
	var sv := "sauce|%s|%d" % [bl["id"], int(bl.get("cut", 0))]
	for l in sauces:
		_place(leaf_mesh(l, sv), l, btr)
	var bb := bm.get_aabb()
	if bl["id"] == "pizza" and int(bl.get("cut", 0)) == 0:
		var top := _mesh_top(bm, 0.0, 0.0, minf(bb.size.x, bb.size.z) * 0.3)
		for j in solids.size():
			var l: Dictionary = solids[j]
			_place(leaf_mesh(l, "bits%d" % (j % 10)), l, Transform3D(Basis.IDENTITY, Vector3(0, top, 0)))
		return
	# toppings sit on the base's surface, arranged so they don't overlap each other
	var n := solids.size()
	var rad := minf(bb.size.x, bb.size.z) * (0.0 if n == 1 else 0.24)
	for j in n:
		var l: Dictionary = solids[j]
		var m := leaf_mesh(l)
		var ab := m.get_aabb()
		var sc := minf(0.6, minf(bb.size.x, bb.size.z) * 0.45 / maxf(maxf(ab.size.x, ab.size.z), 0.001))
		var a := TAU * j / maxf(1, n) + 0.4
		var x := cos(a) * rad
		var z := sin(a) * rad
		var foot := maxf(ab.size.x, ab.size.z) * sc * 0.35
		var y := maxf(_mesh_top(bm, x, z, foot), bb.position.y)
		var tr := Transform3D(Basis.from_scale(Vector3.ONE * sc).rotated(Vector3.UP, a), Vector3.ZERO)
		var c := tr * ab.get_center()
		tr.origin = Vector3(x - c.x, y - (tr * ab.position).y - ab.size.y * sc * 0.12, z - c.z)
		_place(m, l, tr)


## Lays items in a ring on the plate without overlapping; returns their transforms.
func _ring(items: Array, y0: float, scale: float) -> Array:
	var n := items.size()
	var meshes := []
	var radii := []
	var total := 0.0
	for l in items:
		var m := leaf_mesh(l)
		var ab := m.get_aabb()
		meshes.append(m)
		var r := Vector2(ab.size.x, ab.size.z).length() * 0.5 * scale
		radii.append(r)
		total += r * 2.0
	var R := 0.0
	if n == 2:
		R = maxf(radii[0], radii[1]) * 1.02
	elif n > 2:
		R = total / TAU * 1.15
	var out := []
	var a := 0.0
	for j in n:
		var m: Mesh = meshes[j]
		var ab := m.get_aabb()
		if j > 0 and n > 2:
			a += (radii[j - 1] + radii[j]) / maxf(R, 0.001)
		var p := Vector3(cos(a), 0, sin(a)) * R if n > 1 else Vector3.ZERO
		if n == 2:
			p = Vector3(radii[0] if j == 1 else -radii[1], 0, 0)
		var tr := Transform3D(Basis.from_scale(Vector3.ONE * scale), Vector3.ZERO)
		var c := tr * ab.get_center()
		tr.origin = Vector3(p.x - c.x, y0 - (tr * ab.position).y, p.z - c.z)
		_place(m, items[j], tr)
		out.append(tr)
	return out


# ================================================================ particles

static func particles(kind: String) -> CPUParticles3D:
	var pt := CPUParticles3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
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
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
			curve.add_point(Vector2(0, 0.4))
			curve.add_point(Vector2(1, 1.6))
			var c := Color(1, 1, 1) if kind == "steam" else Color(0.15, 0.13, 0.12)
			g.set_color(0, Color(c, 0.35 if kind == "steam" else 0.7))
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
