class_name Food
extends RigidBody3D
## A physical piece of food. `data` is a DB food dictionary.

var data: Dictionary
var model: Node3D
var tints: Array = []
var bottom := 0.0
var shape := CollisionShape3D.new()
var _name := ""


static func make(d: Dictionary) -> Food:
	var f := Food.new()
	f.data = d
	f.rebuild()
	return f


func _init() -> void:
	collision_layer = 2
	collision_mask = 3
	mass = 0.4
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	continuous_cd = true
	angular_damp = 4.0
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var pm := PhysicsMaterial.new()
	pm.friction = 1.0
	pm.bounce = 0.15
	physics_material_override = pm
	add_child(shape)
	add_to_group("food")


func rebuild() -> void:
	if model:
		remove_child(model)
		model.queue_free()
	model = Node3D.new()
	add_child(model)
	var b := Models.new(model)
	b.build(data)
	tints = b.tints
	var aabb := b._bounds()
	var box := BoxShape3D.new()
	box.size = Vector3(maxf(aabb.size.x, 0.05), maxf(aabb.size.y, 0.04), maxf(aabb.size.z, 0.05))
	shape.shape = box
	shape.position = aabb.get_center()
	bottom = aabb.position.y
	_name = ""


func refresh_tint() -> void:
	for t in tints:
		(t[0] as StandardMaterial3D).albedo_color = Models.tinted(t[1], t[2])


func display_name() -> String:
	if _name == "":
		_name = DB.food_name(data)
	return _name


func mark_changed() -> void:
	_name = ""


func needs_wash() -> bool:
	for l in DB.leaves(data):
		if DB.flag(l["id"], "d") and not l.get("washed", false):
			return true
	return false


func pop(amount := 1.3) -> void:
	if model == null:
		return
	model.scale = Vector3.ONE * amount
	var tw := create_tween()
	tw.tween_property(model, "scale", Vector3.ONE, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func set_carried(on: bool) -> void:
	freeze = on
	collision_layer = 0 if on else 2
	collision_mask = 0 if on else 3
	if not on:
		sleeping = false
