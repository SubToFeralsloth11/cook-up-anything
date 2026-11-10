class_name Source
extends StaticBody3D
## A physical, bottomless supply of one ingredient sitting on a shelf, crate or
## rack. Look at it and grab: you get a fresh copy in your hand.

var id := ""
var slot := Vector3(0.16, 0.16, 0.16) # space available (w, h, d)
var display: Node3D
var tag: Label3D


func _ready() -> void:
	add_to_group("source")
	collision_layer = 1
	var col := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = slot
	col.shape = box
	col.position.y = slot.y / 2
	add_child(col)
	display = Node3D.new()
	display.set_meta("nobatch", true)
	add_child(display)
	var holder := Node3D.new()
	display.add_child(holder)
	var leaf := DB.new_leaf(id)
	leaf["washed"] = true
	var b := Models.new(holder)
	b.build(leaf)
	var aabb := b._bounds()
	var fit := minf(1.0, minf(slot.x * 0.92 / maxf(aabb.size.x, 0.01), minf(slot.y * 0.95 / maxf(aabb.size.y, 0.01), slot.z * 0.92 / maxf(aabb.size.z, 0.01))))
	holder.scale = Vector3.ONE * fit
	holder.position = Vector3(-aabb.get_center().x * fit, -aabb.position.y * fit + 0.002, -aabb.get_center().z * fit)
	for mi in holder.find_children("*", "GeometryInstance3D", true, false):
		(mi as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tag = Label3D.new()
	tag.text = DB.ING[id][0]
	tag.font_size = 32
	tag.pixel_size = 0.0011
	tag.outline_size = 0
	tag.modulate = Color(0.12, 0.1, 0.08)
	tag.position = Vector3(0, 0.012, slot.z / 2 + 0.006)
	tag.visibility_range_end = 3.2
	tag.font = UI.body_font()
	add_child(tag)
	var card := MeshInstance3D.new()
	card.mesh = Models.mesh("box")
	card.material_override = Tex.mat("paper")
	card.position = tag.position + Vector3(0, 0, -0.003)
	card.scale = Vector3(minf(slot.x * 0.95, 0.03 + tag.text.length() * 0.0105), 0.022, 0.002)
	add_child(card)


func title() -> String:
	return DB.ING[id][0]


func pop() -> void:
	display.scale = Vector3.ONE * 0.8
	var tw := create_tween()
	tw.tween_property(display, "scale", Vector3.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
