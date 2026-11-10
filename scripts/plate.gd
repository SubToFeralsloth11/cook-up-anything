class_name Plate
extends RigidBody3D
## A plate. Everything added becomes part of one combined dish model.

const MAX_ITEMS := 12

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


func can_add() -> bool:
	return leaves().size() < MAX_ITEMS


func add_data(d: Dictionary) -> void:
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
	var b := Models.new(food_root)
	if items.size() == 1:
		b.build(items[0])
	else:
		b.build({"id": "mix", "parts": leaves()})
	tints = b.tints
	# keep big piles within the plate
	var aabb := b._bounds()
	var w := maxf(aabb.size.x, aabb.size.z)
	fit = minf(1.0, 0.32 / maxf(w, 0.001))
	food_root.scale = Vector3.ONE * fit


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
