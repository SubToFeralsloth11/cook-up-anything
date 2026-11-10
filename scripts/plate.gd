class_name Plate
extends RigidBody3D
## A plate. No limit on how much goes on it. Fillings go into the bun/bread/wrap they were
## plated with (a second bun starts a second burger); sides like fries sit next to it.

var items: Array = [] # food data dicts
var fit := 1.0
var food_root: Node3D
var tints: Array = []
var bottom := 0.0
var _name := ""

static var _plate_mesh: ArrayMesh


## One-draw-call plate: glazed ceramic with a blue rim band.
static func plate_mesh() -> ArrayMesh:
	if _plate_mesh:
		return _plate_mesh
	var b := MeshGen.new()
	b.mat(0.12, 0.0, 0.0)
	var blue := Color(0.35, 0.62, 0.88)
	var white := Color(0.97, 0.97, 0.95)
	var pts := Models._cr([Vector2(0, 0.004), Vector2(0.1, 0.0), Vector2(0.115, 0.0), Vector2(0.12, 0.006), Vector2(0.13, 0.012),
		Vector2(0.17, 0.022), Vector2(0.18, 0.028), Vector2(0.176, 0.031), Vector2(0.165, 0.026), Vector2(0.13, 0.017),
		Vector2(0.11, 0.014), Vector2(0, 0.014)], 2)
	b.lathe(pts, func(_u: float, _v: float, p: Vector3) -> Color:
		var r := Vector2(p.x, p.z).length()
		return blue if r > 0.168 and p.y > 0.022 else white, 48)
	_plate_mesh = ArrayMesh.new()
	b.commit(_plate_mesh, Models.food_material())
	return _plate_mesh


func _init() -> void:
	collision_layer = 2
	collision_mask = 3
	mass = 0.6
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	continuous_cd = true
	angular_damp = 4.0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.05
	physics_material_override = pm
	var col := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.17
	cs.height = 0.04
	col.shape = cs
	col.position.y = 0.02
	add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = plate_mesh()
	add_child(mi)
	add_to_group("plate")


func leaves() -> Array:
	var out := []
	for d in items:
		out.append_array(DB.leaves(d))
	return out


func add_data(d: Dictionary) -> void:
	DB.portion(d)
	items.append(d)
	rebuild()
	if food_root:
		food_root.scale = Vector3.ONE * fit * 1.25
		var tw := create_tween()
		tw.tween_property(food_root, "scale", Vector3.ONE * fit, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func clear() -> void:
	items.clear()
	rebuild()


func rebuild() -> void:
	if food_root:
		remove_child(food_root)
		food_root.queue_free()
		food_root = null
	_name = ""
	tints = []
	if items.is_empty():
		return
	food_root = Node3D.new()
	food_root.position.y = 0.018
	add_child(food_root)
	var all := leaves()
	var tops := []
	var body := []
	var framed := Models.has_frame(all)
	for l in all:
		if all.size() > 1 and Models.is_top(l, framed):
			tops.append(l)
		else:
			body.append(l)
	if body.is_empty():
		body = tops
		tops = []
	var b := Models.new(food_root)
	_serve(b, body)
	tints = b.tints
	# keep big piles within the plate
	var aabb := b._bounds()
	var w := maxf(aabb.size.x, aabb.size.z)
	var side := 0.0
	for l in tops:
		if l.get("sstyle", "") == "side":
			side = 0.11
	fit = minf(1.0, (0.32 - side) / maxf(w, 0.001))
	food_root.scale = Vector3.ONE * fit
	food_root.position.x = -side * 0.5
	if not tops.is_empty():
		var tb := Models.new(food_root)
		tb.top_coat(tops, 1.0 / fit)
		tints.append_array(tb.tints)


## Finished foods built inside a bun or wrap rather than served beside it.
const FILLINGS := ["patty", "falafel", "fried_egg", "poached_egg", "scrambled_eggs", "meatballs", "hash_browns"]
const SERVE_GAP := 0.02


## Builds each serving and lines them up side by side across the plate.
func _serve(b: Models, body: Array) -> void:
	var groups := servings(body)
	var x := 0.0
	for g: Array in groups:
		var start := food_root.get_child_count()
		b.build(g[0] if g.size() == 1 else {"id": "mix", "parts": g})
		if groups.size() == 1:
			return
		var bb := _bounds_from(start)
		var shift := Vector3(x - bb.position.x, 0.0, -bb.get_center().z)
		for i in range(start, food_root.get_child_count()):
			(food_root.get_child(i) as Node3D).position += shift
		x += bb.size.x + SERVE_GAP
	var centre := Vector3((x - SERVE_GAP) * 0.5, 0.0, 0.0)
	for c in food_root.get_children():
		(c as Node3D).position -= centre


func _bounds_from(start: int) -> AABB:
	var out := AABB()
	for i in range(start, food_root.get_child_count()):
		var mi := food_root.get_child(i) as MeshInstance3D
		if mi == null:
			continue
		var bb: AABB = mi.transform * mi.get_aabb()
		out = bb if i == start else out.merge(bb)
	return out


## Splits plated leaves into servings. Without a bun/bread/wrap it's one dish (a pile, soup...).
## Otherwise each frame takes the fillings plated after it (fillings plated before the first
## frame go in the first), and sides (fries, mash, rice, pasta...) become their own serving.
static func servings(body: Array) -> Array:
	if not Models.has_frame(body):
		return [body]
	var groups := []
	var early := []
	var sides := []
	for l: Dictionary in body:
		if Models.has_frame([l]):
			groups.append(early + [l] if groups.is_empty() else [l])
			early = []
		elif is_side(l):
			sides.append(l)
		elif groups.is_empty():
			early.append(l)
		else:
			(groups[-1] as Array).append(l)
	if not sides.is_empty():
		groups.append(sides)
	return groups


## Served next to a sandwich rather than inside it.
static func is_side(l: Dictionary) -> bool:
	var id: String = l["id"]
	if id == "mix" or id in FILLINGS or DB.is_topping(id):
		return false
	return DB.ING[id][1] in ["made", "grain", "sweet"]



func display_name() -> String:
	if items.is_empty():
		return "Empty Plate"
	if _name == "":
		_name = DB.identify(leaves())["name"]
	return _name


func set_carried(on: bool) -> void:
	freeze = on
	collision_layer = 0 if on else 2
	collision_mask = 0 if on else 3
	if not on:
		sleeping = false
