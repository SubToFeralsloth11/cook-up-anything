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
	var ceramic := Models.smat(Color(0.98, 0.98, 0.96), 0.2)
	Models.solid(self, "cyl", ceramic, Vector3(0, 0.008, 0), Vector3(0.3, 0.016, 0.3))
	Models.solid(self, "torus", ceramic, Vector3(0, 0.02, 0), Vector3(0.36, 0.08, 0.36))
	Models.solid(self, "torus", Models.smat(Color(0.35, 0.65, 0.9), 0.3), Vector3(0, 0.024, 0), Vector3(0.355, 0.03, 0.355))
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
