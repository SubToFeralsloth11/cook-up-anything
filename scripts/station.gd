class_name Station
extends StaticBody3D
## Every kitchen appliance. Local frame: origin on the surface it stands on,
## front faces +Z (towards the cook).

const NAMES := {"fridge": "Fridge", "pantry": "Pantry", "trash": "Bin", "sink": "Sink",
	"board": "Chopping Board", "bowl": "Mixing Bowl", "blender": "Blender", "pan": "Frying Pan",
	"pot": "Pot", "fryer": "Deep Fryer", "oven": "Oven", "plates": "Plates", "serve": "Serving Hatch"}
const CAP := {"sink": 3, "board": 1, "bowl": 8, "blender": 6, "pan": 6, "pot": 8, "fryer": 4, "oven": 6}
const SPREAD := {"sink": 0.11, "bowl": 0.06, "blender": 0.025, "pan": 0.08, "pot": 0.06, "fryer": 0.08, "oven": 0.12}
const ITEM_SCALE := {"bowl": 0.75, "blender": 0.55, "pot": 0.7, "fryer": 0.85}
const METHOD := {"pan": "fry", "pot": "boil", "fryer": "deepfry", "oven": "bake"}
const CHOPS := 4
const WHISKS := 6
const BLEND_TIME := 2.4
const WASH_TIME := 1.8

var kind := ""
var game: Node
var contents: Array = []
var hold := Node3D.new()
var method := ""
var done_once := false
var work := 0
var running := false
var run_t := 0.0
var t := 0.0
var toss_t := 0.0
var warn_t := 0.0
var door_open := false
var door_close_t := 0.0

var bar: Node3D
var bar_fill: MeshInstance3D
var bar_mat: StandardMaterial3D
var label: Label3D
var loop: AudioStreamPlayer3D
var fx := {}
var knife: Node3D
var whisk: Node3D
var door: Node3D
var lid: Node3D
var jar: Node3D
var liquid_mat: StandardMaterial3D
var flame: MeshInstance3D
var glow: OmniLight3D
var pan_node: Node3D


func _ready() -> void:
	method = METHOD.get(kind, "")
	add_to_group("station")
	add_child(hold)
	call("_build_" + kind)
	if CAP.has(kind):
		_make_bar(_bar_height())


func _bar_height() -> float:
	match kind:
		"oven": return 0.25
		"blender": return 0.55
		"fryer": return 0.6
		"pot": return 0.5
	return 0.42


func title() -> String:
	return NAMES[kind]


# ================================================================ visuals

func _box_col(size: Vector3, center: Vector3) -> void:
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.position = center
	add_child(c)


func _make_bar(y: float) -> void:
	bar = Node3D.new()
	bar.position.y = y
	add_child(bar)
	var bgm := StandardMaterial3D.new()
	bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bgm.albedo_color = Color(0.05, 0.05, 0.08, 0.75)
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bgm.no_depth_test = true
	bgm.render_priority = 10
	Models.solid(bar, "box", bgm, Vector3.ZERO, Vector3(0.32, 0.045, 0.004))
	bar_mat = StandardMaterial3D.new()
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.no_depth_test = true
	bar_mat.render_priority = 11
	bar_fill = Models.solid(bar, "box", bar_mat, Vector3(0, 0, 0.003), Vector3(0.3, 0.03, 0.004))
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.pixel_size = 0.0014
	label.outline_size = 12
	label.no_depth_test = true
	label.position.y = y + 0.07
	label.render_priority = 12
	label.outline_render_priority = 11
	add_child(label)
	bar.visible = false
	label.visible = false


func _set_bar(p: float, col: Color, text: String) -> void:
	if bar == null:
		return
	bar.visible = true
	p = clampf(p, 0.0, 1.0)
	bar_fill.scale.x = maxf(0.001, 0.3 * p)
	bar_fill.position.x = -0.15 + 0.15 * p
	bar_mat.albedo_color = col
	label.visible = text != ""
	label.text = text
	label.modulate = col.lightened(0.3)


func _hide_bar() -> void:
	if bar:
		bar.visible = false
		label.visible = false


func _particles(n: String, pos: Vector3, emitting := true) -> CPUParticles3D:
	var p := Models.particles(n)
	p.position = pos
	p.emitting = emitting
	add_child(p)
	fx[n] = p
	return p


func _steel() -> StandardMaterial3D:
	return Models.smat(Color(0.78, 0.8, 0.83), 0.25, 0.85)


func _tube_mat(c: Color, rough := 0.3, metal := 0.8) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _tube(parent: Node3D, mat: Material, pos: Vector3, scl: Vector3) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = 0.5
	c.bottom_radius = 0.5
	c.height = 1.0
	c.cap_top = false
	c.radial_segments = 20
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)
	return mi


func _build_fridge() -> void:
	var body := Color(0.55, 0.82, 0.86)
	Models.solid(self, "box", body, Vector3(0, 0.95, 0), Vector3(0.85, 1.9, 0.7), Vector3.ZERO, 0.3)
	door = Node3D.new()
	door.position = Vector3(-0.42, 0, 0.36)
	add_child(door)
	Models.solid(door, "box", body.lightened(0.1), Vector3(0.42, 1.25, 0.02), Vector3(0.83, 1.15, 0.05), Vector3.ZERO, 0.25)
	Models.solid(door, "box", body.lightened(0.1), Vector3(0.42, 0.35, 0.02), Vector3(0.83, 0.62, 0.05), Vector3.ZERO, 0.25)
	Models.solid(door, "box", _steel(), Vector3(0.75, 1.2, 0.07), Vector3(0.03, 0.5, 0.03))
	Models.solid(door, "box", _steel(), Vector3(0.75, 0.45, 0.07), Vector3(0.03, 0.3, 0.03))
	var cols := [Color(1, 0.4, 0.4), Color(1, 0.85, 0.3), Color(0.5, 0.8, 0.4), Color(0.6, 0.5, 1)]
	for i in 4:
		Models.solid(door, "cyl", cols[i], Vector3(0.2 + i * 0.12, 1.45 + (i % 2) * 0.1, 0.06), Vector3(0.06, 0.02, 0.06), Vector3(90, 0, 0), 0.3)
	_box_col(Vector3(0.85, 1.9, 0.75), Vector3(0, 0.95, 0))


func _build_pantry() -> void:
	var wood := Color(0.62, 0.42, 0.25)
	for x in [-0.48, 0.48]:
		Models.solid(self, "box", wood, Vector3(x, 1.0, 0), Vector3(0.04, 2.0, 0.45))
	Models.solid(self, "box", wood.darkened(0.2), Vector3(0, 1.0, -0.21), Vector3(0.96, 2.0, 0.03))
	var ids := ["flour", "sugar", "rice", "pasta", "oats", "beans", "chickpeas", "honey", "jam", "oil", "soy_sauce",
		"ketchup", "salt", "black_pepper", "cinnamon", "curry_powder", "nori", "noodles", "peanut_butter", "maple_syrup"]
	var i := 0
	for s in 5:
		var y := 0.1 + s * 0.42
		Models.solid(self, "box", wood, Vector3(0, y, 0), Vector3(0.92, 0.03, 0.42))
		if s == 0:
			continue
		for j in 5:
			var n := Node3D.new()
			n.position = Vector3(-0.36 + j * 0.18, y + 0.015, 0.0)
			add_child(n)
			Models.new(n).build(DB.new_leaf(ids[i % ids.size()]))
			i += 1
	_box_col(Vector3(0.96, 2.0, 0.45), Vector3(0, 1.0, 0))


func _build_trash() -> void:
	Models.solid(self, "cyl", Color(0.3, 0.55, 0.35), Vector3(0, 0.3, 0), Vector3(0.42, 0.6, 0.42), Vector3.ZERO, 0.4)
	Models.solid(self, "torus", Color(0.25, 0.45, 0.3), Vector3(0, 0.6, 0), Vector3(0.44, 0.2, 0.44))
	lid = Node3D.new()
	lid.position = Vector3(0, 0.62, -0.21)
	add_child(lid)
	Models.solid(lid, "cyl", Color(0.35, 0.6, 0.4), Vector3(0, 0.0, 0.21), Vector3(0.44, 0.03, 0.44))
	Models.solid(lid, "box", Color(0.9, 0.9, 0.9), Vector3(0, 0.03, 0.38), Vector3(0.1, 0.03, 0.03))
	_box_col(Vector3(0.44, 0.65, 0.44), Vector3(0, 0.32, 0))


func _build_sink() -> void:
	Models.solid(self, "box", _steel(), Vector3(0, 0.005, 0), Vector3(0.7, 0.01, 0.55))
	Models.solid(self, "box", Models.smat(Color(0.35, 0.37, 0.4), 0.3, 0.7), Vector3(0, 0.007, 0.02), Vector3(0.55, 0.01, 0.4))
	Models.solid(self, "cyl", Models.smat(Color(0.15, 0.15, 0.15)), Vector3(0, 0.012, 0.02), Vector3(0.05, 0.005, 0.05))
	var tap := Node3D.new()
	tap.position = Vector3(0, 0, -0.24)
	add_child(tap)
	Models.solid(tap, "cyl", _steel(), Vector3(0, 0.17, 0), Vector3(0.035, 0.34, 0.035))
	Models.solid(tap, "cyl", _steel(), Vector3(0, 0.34, 0.08), Vector3(0.03, 0.18, 0.03), Vector3(90, 0, 0))
	Models.solid(tap, "cyl", _steel(), Vector3(0, 0.31, 0.16), Vector3(0.03, 0.07, 0.03))
	for x in [-0.09, 0.09]:
		Models.solid(tap, "cyl", Models.smat(Color(0.9, 0.3, 0.3) if x < 0 else Color(0.3, 0.5, 0.95), 0.3), Vector3(x, 0.05, 0.02), Vector3(0.04, 0.05, 0.04))
	_particles("water", Vector3(0, 0.27, -0.08), false)
	hold.position = Vector3(0, 0.012, 0.03)
	loop = game.sfx.loop_player("water", self, -10.0)
	_box_col(Vector3(0.7, 0.35, 0.55), Vector3(0, 0.17, 0))


func _build_board() -> void:
	var wood := Color(0.82, 0.62, 0.38)
	Models.solid(self, "box", wood, Vector3(0, 0.015, 0), Vector3(0.48, 0.03, 0.32), Vector3.ZERO, 0.7)
	Models.solid(self, "box", wood.darkened(0.15), Vector3(0, 0.031, 0), Vector3(0.46, 0.002, 0.3), Vector3.ZERO, 0.7)
	knife = Node3D.new()
	knife.position = Vector3(0.2, 0.05, -0.06)
	add_child(knife)
	Models.solid(knife, "box", _steel(), Vector3(-0.13, 0.0, 0.02), Vector3(0.22, 0.05, 0.004))
	Models.solid(knife, "box", Models.smat(Color(0.2, 0.15, 0.12), 0.5), Vector3(0.04, 0.0, 0.02), Vector3(0.11, 0.025, 0.02))
	knife.rotation_degrees = Vector3(0, 35, -25)
	hold.position = Vector3(-0.04, 0.031, 0.02)
	_box_col(Vector3(0.48, 0.25, 0.32), Vector3(0, 0.12, 0))


func _build_bowl() -> void:
	var bowl := _tube_mat(Color(0.95, 0.55, 0.45), 0.25, 0.1)
	var c := CylinderMesh.new()
	c.top_radius = 0.2
	c.bottom_radius = 0.11
	c.height = 0.15
	c.cap_top = false
	c.radial_segments = 24
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = bowl
	mi.position.y = 0.075
	add_child(mi)
	Models.solid(self, "torus", Color(0.95, 0.55, 0.45), Vector3(0, 0.15, 0), Vector3(0.41, 0.12, 0.41), Vector3.ZERO, 0.25)
	whisk = Node3D.new()
	whisk.position = Vector3(0, 0.05, 0)
	add_child(whisk)
	Models.solid(whisk, "cyl", Models.smat(Color(0.9, 0.35, 0.3), 0.4), Vector3(0.0, 0.3, 0), Vector3(0.025, 0.16, 0.025))
	for i in 3:
		Models.solid(whisk, "torus", _steel(), Vector3(0, 0.13, 0), Vector3(0.09, 0.14, 0.1), Vector3(0, i * 60, 90))
	whisk.rotation_degrees = Vector3(0, 0, 25)
	whisk.position = Vector3(0.09, 0.03, 0)
	hold.position.y = 0.03
	_box_col(Vector3(0.42, 0.35, 0.42), Vector3(0, 0.17, 0))


func _build_blender() -> void:
	Models.solid(self, "box", Color(0.2, 0.22, 0.25), Vector3(0, 0.07, 0), Vector3(0.2, 0.14, 0.2), Vector3.ZERO, 0.35)
	Models.solid(self, "cyl", Color(0.95, 0.3, 0.3), Vector3(0, 0.07, 0.1), Vector3(0.04, 0.01, 0.04), Vector3(90, 0, 0))
	jar = Node3D.new()
	jar.position.y = 0.14
	add_child(jar)
	_tube(jar, Models.glass_mat(Color(0.8, 0.95, 1.0, 0.22)), Vector3(0, 0.15, 0), Vector3(0.19, 0.3, 0.19))
	Models.solid(jar, "cyl", Color(0.2, 0.22, 0.25), Vector3(0, 0.31, 0), Vector3(0.2, 0.03, 0.2))
	Models.solid(jar, "box", _steel(), Vector3(0, 0.02, 0), Vector3(0.12, 0.005, 0.02))
	hold.position.y = 0.16
	loop = game.sfx.loop_player("blender", self, -8.0)
	_box_col(Vector3(0.24, 0.5, 0.24), Vector3(0, 0.25, 0))


func _burner() -> void:
	Models.solid(self, "torus", Color(0.12, 0.12, 0.12), Vector3(0, 0.01, 0), Vector3(0.3, 0.2, 0.3), Vector3.ZERO, 0.6)
	flame = Models.solid(self, "torus", Models.glow_mat(Color(0.35, 0.55, 1.0), 2.0), Vector3(0, 0.015, 0), Vector3(0.2, 0.15, 0.2))
	flame.visible = false
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.6, 0.3)
	glow.omni_range = 0.9
	glow.light_energy = 0.0
	glow.position.y = 0.1
	add_child(glow)


func _build_pan() -> void:
	_burner()
	pan_node = Node3D.new()
	pan_node.position.y = 0.03
	add_child(pan_node)
	var dark := _tube_mat(Color(0.16, 0.16, 0.18), 0.35, 0.4)
	_tube(pan_node, dark, Vector3(0, 0.025, 0), Vector3(0.36, 0.05, 0.36))
	Models.solid(pan_node, "cyl", Color(0.12, 0.12, 0.14), Vector3(0, 0.003, 0), Vector3(0.36, 0.006, 0.36), Vector3.ZERO, 0.35, 0.4)
	Models.solid(pan_node, "box", Color(0.15, 0.1, 0.08), Vector3(0.32, 0.04, 0), Vector3(0.26, 0.025, 0.04), Vector3(0, 0, 8))
	hold.position.y = 0.04
	_particles("sizzle", Vector3(0, 0.06, 0), false)
	_particles("smoke", Vector3(0, 0.1, 0), false)
	loop = game.sfx.loop_player("sizzle", self, -6.0)
	_box_col(Vector3(0.5, 0.3, 0.42), Vector3(0.05, 0.15, 0))


func _build_pot() -> void:
	_burner()
	var steel := _tube_mat(Color(0.72, 0.74, 0.78), 0.25, 0.85)
	_tube(self, steel, Vector3(0, 0.13, 0), Vector3(0.34, 0.24, 0.34))
	Models.solid(self, "cyl", Color(0.6, 0.62, 0.66), Vector3(0, 0.015, 0), Vector3(0.34, 0.01, 0.34), Vector3.ZERO, 0.3, 0.8)
	for x in [-0.19, 0.19]:
		Models.solid(self, "box", Color(0.2, 0.2, 0.2), Vector3(x, 0.22, 0), Vector3(0.05, 0.02, 0.08))
	liquid_mat = StandardMaterial3D.new()
	liquid_mat.albedo_color = Color(0.55, 0.75, 0.95, 0.85)
	liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid_mat.roughness = 0.05
	Models.solid(self, "cyl", liquid_mat, Vector3(0, 0.2, 0), Vector3(0.32, 0.01, 0.32))
	hold.position.y = 0.17
	_particles("steam", Vector3(0, 0.3, 0), false)
	_particles("bubbles", Vector3(0, 0.2, 0), false)
	loop = game.sfx.loop_player("boil", self, -5.0)
	_box_col(Vector3(0.42, 0.4, 0.42), Vector3(0, 0.2, 0))


func _build_fryer() -> void:
	Models.solid(self, "box", Models.smat(Color(0.7, 0.72, 0.75), 0.3, 0.8), Vector3(0, 0.14, 0), Vector3(0.42, 0.28, 0.38))
	Models.solid(self, "box", Color(0.1, 0.1, 0.1), Vector3(0, 0.2, 0.192), Vector3(0.3, 0.05, 0.01))
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.7, 0.3)
	glow.omni_range = 0.7
	glow.light_energy = 0.0
	glow.position.y = 0.4
	add_child(glow)
	liquid_mat = StandardMaterial3D.new()
	liquid_mat.albedo_color = Color(0.92, 0.7, 0.2, 0.9)
	liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid_mat.roughness = 0.05
	liquid_mat.emission_enabled = true
	liquid_mat.emission = Color(0.9, 0.55, 0.1)
	liquid_mat.emission_energy_multiplier = 0.0
	Models.solid(self, "box", liquid_mat, Vector3(0, 0.282, 0), Vector3(0.36, 0.005, 0.3))
	var basket := _tube_mat(Color(0.5, 0.5, 0.52), 0.4, 0.8)
	Models.solid(self, "box", basket, Vector3(0, 0.33, -0.15), Vector3(0.3, 0.012, 0.012))
	Models.solid(self, "box", Models.smat(Color(0.15, 0.15, 0.15)), Vector3(0, 0.38, -0.2), Vector3(0.04, 0.12, 0.03), Vector3(-30, 0, 0))
	hold.position.y = 0.27
	_particles("bubbles", Vector3(0, 0.29, 0), false)
	_particles("sizzle", Vector3(0, 0.3, 0), false)
	_particles("smoke", Vector3(0, 0.35, 0), false)
	(fx["bubbles"] as CPUParticles3D).color_ramp.set_color(0, Color(1, 0.85, 0.4, 0.9))
	loop = game.sfx.loop_player("fryer", self, -6.0)
	_box_col(Vector3(0.42, 0.45, 0.38), Vector3(0, 0.22, 0))


func _build_oven() -> void:
	# Built into the counter: body below the top surface, controls on top.
	var body := Color(0.92, 0.45, 0.35)
	Models.solid(self, "box", body, Vector3(0, -0.46, 0), Vector3(0.7, 0.9, 0.66), Vector3.ZERO, 0.35)
	Models.solid(self, "box", Models.smat(Color(0.82, 0.8, 0.76), 0.3), Vector3(0, -0.01, 0), Vector3(0.72, 0.04, 0.72))
	Models.solid(self, "box", Color(0.12, 0.1, 0.1), Vector3(0, -0.48, 0.05), Vector3(0.6, 0.55, 0.6))
	var inner := Models.glow_mat(Color(1.0, 0.45, 0.15), 0.0)
	Models.solid(self, "box", inner, Vector3(0, -0.48, -0.24), Vector3(0.56, 0.5, 0.01))
	liquid_mat = inner
	Models.solid(self, "box", _steel(), Vector3(0, -0.6, 0.05), Vector3(0.56, 0.01, 0.5))
	for i in 3:
		Models.solid(self, "cyl", Color(0.15, 0.15, 0.15), Vector3(-0.2 + i * 0.2, -0.08, 0.34), Vector3(0.05, 0.03, 0.05), Vector3(90, 0, 0))
	door = Node3D.new()
	door.position = Vector3(0, -0.78, 0.34)
	add_child(door)
	Models.solid(door, "box", body.lightened(0.08), Vector3(0, 0.29, 0.015), Vector3(0.66, 0.58, 0.03), Vector3.ZERO, 0.3)
	var glass := Models.glass_mat(Color(0.2, 0.15, 0.1, 0.35))
	Models.solid(door, "box", glass, Vector3(0, 0.3, 0.032), Vector3(0.44, 0.3, 0.005))
	Models.solid(door, "box", _steel(), Vector3(0, 0.53, 0.07), Vector3(0.48, 0.025, 0.025))
	glow = OmniLight3D.new()
	glow.light_color = Color(1.0, 0.55, 0.25)
	glow.omni_range = 1.1
	glow.light_energy = 0.0
	glow.position = Vector3(0, -0.4, 0.25)
	add_child(glow)
	hold.position = Vector3(0, -0.595, 0.05)
	_particles("smoke", Vector3(0, 0.02, 0.3), false)
	loop = game.sfx.loop_player("hum", self, -10.0)
	_box_col(Vector3(0.7, 0.9, 0.7), Vector3(0, -0.45, 0.0))


func _build_plates() -> void:
	for i in 6:
		var n := Node3D.new()
		n.position.y = i * 0.022
		add_child(n)
		var ceramic := Models.smat(Color(0.98, 0.98, 0.96), 0.2)
		Models.solid(n, "cyl", ceramic, Vector3(0, 0.008, 0), Vector3(0.3, 0.016, 0.3))
		Models.solid(n, "torus", Models.smat(Color(0.35, 0.65, 0.9), 0.3), Vector3(0, 0.018, 0), Vector3(0.355, 0.03, 0.355))
	_box_col(Vector3(0.36, 0.2, 0.36), Vector3(0, 0.08, 0))


func _build_serve() -> void:
	Models.solid(self, "box", Color(0.95, 0.85, 0.55), Vector3(0, 0.02, 0), Vector3(1.0, 0.04, 0.45), Vector3.ZERO, 0.4)
	Models.solid(self, "hemi", Models.smat(Color(0.95, 0.8, 0.3), 0.15, 0.9), Vector3(0.38, 0.04, 0.1), Vector3(0.12, 0.12, 0.12))
	Models.solid(self, "cyl", Color(0.2, 0.2, 0.2), Vector3(0.38, 0.1, 0.1), Vector3(0.02, 0.04, 0.02))
	Models.solid(self, "box", _steel(), Vector3(0, 0.62, -0.1), Vector3(1.0, 0.02, 0.03))
	var sign := Label3D.new()
	sign.text = "ORDER UP!"
	sign.font_size = 96
	sign.pixel_size = 0.0022
	sign.outline_size = 18
	sign.modulate = Color(1, 0.85, 0.3)
	sign.position = Vector3(0, 0.82, -0.05)
	add_child(sign)
	hold.position = Vector3(-0.1, 0.04, 0.0)
	_particles("confetti", Vector3(0, 0.2, 0.1), false)
	_box_col(Vector3(1.0, 0.35, 0.45), Vector3(0, 0.17, 0))


# ================================================================ interaction

func accepts(f: Food) -> String:
	if not CAP.has(kind):
		return ""
	if kind == "blender" and running:
		return "Wait for the blender!"
	if contents.size() >= CAP[kind]:
		return "The %s is full" % title()
	match kind:
		"sink":
			if not f.needs_wash():
				return "That's already clean"
		"board":
			if f.data["id"] == "mix":
				return "Can't chop a mixture"
			if DB.cut_max(f.data["id"]) <= int(f.data.get("cut", 0)):
				return "Can't chop that any more"
	return ""


func add_food(f: Food) -> void:
	f.reparent(hold, true)
	f.set_carried(true)
	f.scale = Vector3.ONE * ITEM_SCALE.get(kind, 1.0)
	contents.append(f)
	done_once = false
	work = 0
	_layout()
	f.pop(1.15)
	match kind:
		"pot", "fryer", "sink":
			game.sfx.play("splash", -4.0)
		"pan":
			game.sfx.play("place", -2.0)
			(fx["sizzle"] as CPUParticles3D).restart()
		"oven":
			_swing_door(true)
		_:
			game.sfx.play("place", -2.0)


func _layout() -> void:
	var n := contents.size()
	var r: float = SPREAD.get(kind, 0.0)
	for i in n:
		var f: Food = contents[i]
		var target := Vector3.ZERO
		if n > 1:
			var a := TAU * i / n
			target = Vector3(cos(a) * r, 0.0, sin(a) * r)
		var tw := f.create_tween()
		tw.set_parallel(true)
		tw.tween_property(f, "position", target, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(f, "rotation", Vector3(0, f.rotation.y, 0), 0.2)


## Should taking from this station merge the contents into one dish?
func _merges() -> bool:
	return contents.size() > 1 and done_once and method != ""


func take() -> Node3D:
	if contents.is_empty() or (kind == "blender" and running):
		return null
	var f: Food
	if _merges():
		var datas := []
		for c in contents:
			datas.append(c.data)
			c.queue_free()
		contents.clear()
		f = Food.make(DB.merge(datas, method))
		add_child(f)
		f.global_position = hold.global_position
	else:
		f = contents.pop_back()
	done_once = false
	if kind == "oven":
		_swing_door(true)
	_layout()
	_after_change()
	return f


## Empties everything for scooping onto a plate.
func take_all_data() -> Array:
	if contents.is_empty() or (kind == "blender" and running):
		return []
	var datas := []
	for c in contents:
		datas.append(c.data)
		c.queue_free()
	var merged := _merges()
	contents.clear()
	done_once = false
	if kind == "oven":
		_swing_door(true)
	_after_change()
	if merged:
		return [DB.merge(datas, method)]
	return datas


func _after_change() -> void:
	if contents.is_empty():
		_hide_bar()
		_heat(false)


func use() -> String:
	match kind:
		"board":
			return _chop()
		"bowl":
			return _whisk()
		"blender":
			if contents.is_empty():
				return "Put something in the blender first"
			if running:
				return ""
			running = true
			run_t = 0.0
			loop.play()
			game.sfx.play("click")
			return ""
		"trash":
			return ""
	return ""


func use_label() -> String:
	match kind:
		"board":
			return "Chop" if not contents.is_empty() else ""
		"bowl":
			return "Whisk / mix" if not contents.is_empty() else ""
		"blender":
			return "Blend!" if not contents.is_empty() and not running else ""
	return ""


func _chop() -> String:
	if contents.is_empty():
		return "Put something on the board"
	var f: Food = contents[0]
	var cut: int = f.data.get("cut", 0)
	if cut >= DB.cut_max(f.data["id"]):
		return "Can't chop that any more"
	work += 1
	game.sfx.play("chop", 0.0, 0.15)
	var tw := knife.create_tween()
	knife.rotation_degrees = Vector3(0, 35, -25)
	tw.tween_property(knife, "rotation_degrees", Vector3(0, 35, 5), 0.06)
	tw.tween_property(knife, "rotation_degrees", Vector3(0, 35, -25), 0.12)
	var bits := Models.particles("burst")
	bits.amount = 10
	bits.lifetime = 0.5
	bits.initial_velocity_max = 1.2
	bits.scale_amount_max = 0.02
	var col := Color(DB.ING[f.data["id"]][4])
	bits.color_ramp.set_color(0, col)
	bits.color_ramp.set_color(1, Color(col, 0.0))
	bits.position = hold.position + Vector3(0, 0.05, 0)
	add_child(bits)
	bits.emitting = true
	get_tree().create_timer(1.2).timeout.connect(bits.queue_free)
	f.pop(1.08)
	game.cam_shake(0.006)
	if work >= CHOPS:
		work = 0
		f.data["cut"] = cut + 1
		f.rebuild()
		f.pop(1.25)
		game.sfx.play("pop")
		game.float_text(global_position + Vector3(0, 0.3, 0), f.display_name(), Color(0.6, 0.9, 1.0))
	_set_bar(float(work) / CHOPS, Color(0.4, 0.75, 1.0), "Chop!" if work > 0 else "")
	return ""


func _whisk() -> String:
	if contents.is_empty():
		return "Put ingredients in the bowl"
	work += 1
	game.sfx.play("whisk", 0.0, 0.2)
	var tw := whisk.create_tween()
	tw.tween_property(whisk, "rotation_degrees:y", whisk.rotation_degrees.y + 140.0, 0.15)
	var tw2 := hold.create_tween()
	tw2.tween_property(hold, "rotation_degrees:y", hold.rotation_degrees.y + 90.0, 0.2).set_trans(Tween.TRANS_SINE)
	for c in contents:
		(c as Food).pop(1.06)
	if work >= WHISKS:
		work = 0
		var datas := []
		for c in contents:
			datas.append(c.data)
		var res := DB.apply_rules("mix", datas)
		var items: Array = res["made"] + res["rest"]
		var merged := DB.merge(items, "mix")
		_replace([merged])
		game.sfx.play("sparkle")
		_burst("sparkle")
		game.float_text(global_position + Vector3(0, 0.35, 0), (contents[0] as Food).display_name(), Color(1, 0.9, 0.5))
		_hide_bar()
		return ""
	_set_bar(float(work) / WHISKS, Color(1.0, 0.75, 0.4), "Whisk!")
	return ""


func _replace(datas: Array) -> void:
	for c in contents:
		c.queue_free()
	contents.clear()
	for d in datas:
		var f := Food.make(d)
		hold.add_child(f)
		f.set_carried(true)
		f.scale = Vector3.ONE * ITEM_SCALE.get(kind, 1.0)
		contents.append(f)
		f.pop(1.4)
	_layout()


func _burst(n: String) -> void:
	var p := Models.particles(n)
	p.position = hold.position + Vector3(0, 0.1, 0)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(2.5).timeout.connect(p.queue_free)


func _swing_door(open: bool) -> void:
	if door == null:
		return
	door_open = open
	if open:
		door_close_t = 0.9
	var tw := door.create_tween()
	if kind == "oven":
		tw.tween_property(door, "rotation_degrees:x", 75.0 if open else 0.0, 0.3).set_trans(Tween.TRANS_BACK)
	else:
		tw.tween_property(door, "rotation_degrees:y", -100.0 if open else 0.0, 0.3).set_trans(Tween.TRANS_BACK)
	if not open:
		game.sfx.play("place", -6.0)


func bump() -> void:
	## Little reaction animation for fridge/pantry/trash/plates use.
	match kind:
		"fridge":
			_swing_door(true)
		"trash":
			var tw := lid.create_tween()
			tw.tween_property(lid, "rotation_degrees:x", -70.0, 0.12)
			tw.tween_property(lid, "rotation_degrees:x", 0.0, 0.35).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		"serve":
			(fx["confetti"] as CPUParticles3D).restart()


# ================================================================ simulation

func _process(delta: float) -> void:
	t += delta
	if bar and bar.visible:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var away := bar.global_position * 2.0 - cam.global_position
			if not away.is_equal_approx(bar.global_position):
				bar.look_at(away, Vector3.UP)
	if door and door_open:
		door_close_t -= delta
		if door_close_t <= 0.0:
			_swing_door(false)
	match kind:
		"sink":
			_tick_sink(delta)
		"blender":
			_tick_blender(delta)
		"pan", "pot", "fryer", "oven":
			_tick_cook(delta)


func _tick_sink(delta: float) -> void:
	var dirty := []
	for c in contents:
		if (c as Food).needs_wash():
			dirty.append(c)
	var on := not dirty.is_empty()
	(fx["water"] as CPUParticles3D).emitting = on
	if on and not loop.playing:
		loop.play()
	elif not on and loop.playing:
		loop.stop()
	if not on:
		if not contents.is_empty():
			_set_bar(1.0, Color(0.5, 0.9, 1.0), "Clean!")
		else:
			_hide_bar()
		return
	var lowest := 9.0
	for c in dirty:
		var f: Food = c
		var w: float = f.data.get("wash_t", 0.0) + delta
		f.data["wash_t"] = w
		f.position.y = sin(t * 8.0 + w) * 0.01
		f.rotation.y += delta * 2.0
		lowest = minf(lowest, w)
		if w >= WASH_TIME:
			for l in DB.leaves(f.data):
				l["washed"] = true
			f.data.erase("wash_t")
			f.refresh_tint()
			f.mark_changed()
			f.pop(1.3)
			game.sfx.play("sparkle", -6.0)
			_burst("sparkle")
	_set_bar(lowest / WASH_TIME, Color(0.4, 0.85, 1.0), "Washing...")


func _tick_blender(delta: float) -> void:
	if not running:
		jar.position.x = 0.0
		return
	run_t += delta
	jar.position.x = sin(t * 70.0) * 0.004
	hold.rotation.y += delta * 30.0
	for c in contents:
		(c as Food).position.y = absf(sin(t * 25.0 + c.get_index())) * 0.05
	_set_bar(run_t / BLEND_TIME, Color(0.95, 0.5, 0.85), "Blending!")
	if run_t >= BLEND_TIME:
		running = false
		loop.stop()
		var datas := []
		for c in contents:
			datas.append(c.data)
		var res := DB.apply_rules("blend", datas)
		var rest: Array = res["rest"]
		for d in rest:
			for l in DB.leaves(d):
				l["cut"] = 3
		var all: Array = res["made"] + rest
		_replace([DB.merge(all, "blend")])
		hold.rotation.y = 0.0
		game.sfx.play("ding")
		_burst("sparkle")
		game.float_text(global_position + Vector3(0, 0.6, 0), (contents[0] as Food).display_name(), Color(1, 0.6, 0.9))
		_hide_bar()


func _heat(on: bool) -> void:
	if flame:
		flame.visible = on
	if glow:
		glow.light_energy = (0.55 + sin(t * 20.0) * 0.08) if on else 0.0
	if loop:
		if on and not loop.playing:
			loop.play()
		elif not on and loop.playing:
			loop.stop()
	for k in ["sizzle", "steam", "bubbles"]:
		if fx.has(k):
			(fx[k] as CPUParticles3D).emitting = on
	if kind == "oven":
		liquid_mat.emission_energy_multiplier = 1.5 if on else 0.0
	if kind == "fryer":
		liquid_mat.emission_energy_multiplier = 0.6 if on else 0.0
	if not on and fx.has("smoke"):
		(fx["smoke"] as CPUParticles3D).emitting = false


func _tick_cook(delta: float) -> void:
	if contents.is_empty() or (kind == "oven" and door_open):
		_heat(false)
		return
	_heat(true)
	var min_p := 99.0
	var max_p := 0.0
	var any_burnt := false
	var can_burn: bool = DB.CAN_BURN[method]
	for c in contents:
		var f: Food = c
		var changed := false
		for l in DB.leaves(f.data):
			var id: String = l["id"]
			if l.get("pm", "") != method:
				l["pm"] = method
				l["prog"] = 0.0
			var p: float = l["prog"] + delta / DB.cook_time(l, method)
			if not can_burn:
				p = minf(p, 1.4)
			l["prog"] = p
			if not DB.flag(id, "n"):
				var ing: Array = DB.ING[id]
				var target: float = 1.0 if ing.size() > 7 else DB.BROWN[method]
				l["br"] = maxf(l.get("br", 0.0), target * minf(p, 1.0))
			if can_burn and p > 1.45:
				l["ch"] = maxf(l.get("ch", 0.0), (p - 1.45) / 0.55)
			if can_burn and p >= 2.0 and not l.get("burnt", false):
				l["burnt"] = true
				changed = true
			if p >= 1.0 and not (l.get("cooked", false) and l.get("cook", "") == method):
				l["cook"] = method
				l["cooked"] = true
				changed = true
			min_p = minf(min_p, p)
			max_p = maxf(max_p, p)
			any_burnt = any_burnt or l.get("burnt", false)
		f.refresh_tint()
		if changed:
			f.mark_changed()
	_animate_cooking(delta)
	if min_p >= 1.0 and not done_once:
		done_once = true
		_transform()
	# status
	if fx.has("smoke"):
		(fx["smoke"] as CPUParticles3D).emitting = can_burn and max_p > 1.45
	if any_burnt:
		_set_bar(1.0, Color(0.25, 0.22, 0.2), "BURNT!")
	elif max_p > 1.45 and can_burn:
		var flash := Color(1, 0.2, 0.15) if fmod(t, 0.4) < 0.2 else Color(1, 0.55, 0.1)
		_set_bar((max_p - 1.45) / 0.55, flash, "Burning! Take it out!")
		warn_t -= delta
		if warn_t <= 0.0:
			warn_t = 0.45
			game.sfx.play("beep", -8.0, 0.0)
	elif min_p >= 1.0:
		_set_bar(1.0, Color(0.35, 0.95, 0.45), "Ready!")
	else:
		_set_bar(min_p, Color(1.0, 0.8, 0.3), _verb() + " %d%%" % int(min_p * 100))


func _verb() -> String:
	return {"fry": "Frying", "boil": "Boiling", "bake": "Baking", "deepfry": "Frying"}[method]


func _animate_cooking(delta: float) -> void:
	match kind:
		"pan":
			toss_t += delta
			if toss_t > 2.6:
				toss_t = 0.0
				for c in contents:
					var f: Food = c
					var tw := f.create_tween()
					var y0 := 0.0
					tw.tween_property(f, "position:y", y0 + 0.14 + randf() * 0.06, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
					tw.parallel().tween_property(f, "rotation:y", f.rotation.y + PI, 0.36)
					tw.tween_property(f, "position:y", y0, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				var ptw := pan_node.create_tween()
				ptw.tween_property(pan_node, "rotation_degrees:z", -6.0, 0.1)
				ptw.tween_property(pan_node, "rotation_degrees:z", 0.0, 0.25).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				(fx["sizzle"] as CPUParticles3D).restart()
		"pot", "fryer":
			var i := 0
			for c in contents:
				var f: Food = c
				f.position.y = sin(t * 3.0 + i * 1.7) * 0.012
				f.rotation.y += delta * 0.4
				i += 1
			if kind == "pot":
				var avg := Color(0, 0, 0)
				var p := 0.0
				for c in contents:
					var d: Dictionary = (c as Food).data
					var l: Dictionary = DB.leaves(d)[0]
					avg += Models.tinted(Color(DB.ING[l["id"]][4]), l)
					p = maxf(p, l.get("prog", 0.0))
				avg /= contents.size()
				liquid_mat.albedo_color = Color(0.55, 0.75, 0.95, 0.85).lerp(Color(avg, 0.95), clampf(p, 0.0, 1.0) * 0.7)


func _transform() -> void:
	var datas := []
	for c in contents:
		datas.append(c.data)
	var res := DB.apply_rules(method, datas)
	if not (res["made"] as Array).is_empty():
		_replace(res["made"] + res["rest"])
		var f: Food = contents[0]
		game.float_text(global_position + Vector3(0, 0.45, 0), f.display_name() + "!", Color(1, 0.85, 0.4))
		_burst("sparkle")
		game.sfx.play("sparkle", -4.0)
	game.sfx.play("ding", -3.0)


func status_text() -> String:
	if contents.is_empty():
		match kind:
			"fridge": return "Fresh ingredients"
			"pantry": return "Dry goods, sauces & sweets"
			"plates": return "Grab a plate"
			"trash": return "Throw stuff away"
			"serve": return "Serve a dish here"
		return "Empty"
	var names := []
	for c in contents:
		names.append((c as Food).display_name())
	return ", ".join(names)
