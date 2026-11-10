class_name Station
extends StaticBody3D
## Every kitchen appliance. Local frame: origin on the surface it stands on,
## front faces +Z (towards the cook). Static parts are merged after building;
## anything animated lives under a node tagged "nobatch".

const NAMES := {"trash": "Bin", "sink": "Sink", "board": "Chopping Board", "bowl": "Mixing Bowl",
	"blender": "Blender", "pan": "Frying Pan", "pot": "Pot", "fryer": "Deep Fryer", "oven": "Oven",
	"plates": "Plates", "serve": "Serving Pass", "grill": "Grill", "microwave": "Microwave",
	"toaster": "Toaster", "fridge": "Fridge & Freezer"}
## How many things each station holds; NO_LIMIT = as much as you like (it piles up).
const NO_LIMIT := -1
const CAP := {"sink": 6, "board": 1, "bowl": NO_LIMIT, "blender": 16, "pan": 10, "pot": NO_LIMIT, "fryer": 8, "oven": 12,
	"grill": 10, "microwave": 6, "toaster": 2, "fridge": 24}
## Items in one ring before the next ring piles on top.
const RING := 6
const SPREAD := {"sink": 0.1, "bowl": 0.07, "blender": 0.03, "pan": 0.075, "pot": 0.065, "fryer": 0.07, "oven": 0.13,
	"grill": 0.1, "microwave": 0.07, "toaster": 0.0, "fridge": 0.1}
const ITEM_SCALE := {"bowl": 0.8, "blender": 0.55, "pot": 0.62, "fryer": 0.75, "pan": 0.85, "sink": 0.9,
	"grill": 0.85, "microwave": 0.6, "toaster": 0.7, "fridge": 0.6}
const METHOD := {"pan": "fry", "pot": "boil", "fryer": "deepfry", "oven": "bake", "grill": "grill",
	"microwave": "microwave", "toaster": "toast", "fridge": "chill"}
## What fits in a toaster slot.
const TOASTABLE := ["bread", "bread_loaf", "baguette", "bun", "brioche_bun", "bagel", "english_muffin", "crumpet",
	"waffle", "croissant", "pita", "naan", "toast", "hot_dog_bun", "tortilla"]
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
var pending_style := ""
var popped := false
var frozen_once := false

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
var flame: Node3D
var glow: Light3D
var pan_node: Node3D


func _ready() -> void:
	method = METHOD.get(kind, "")
	add_to_group("station")
	hold.set_meta("nobatch", true)
	add_child(hold)
	call("_build_" + kind)
	if CAP.has(kind):
		_make_bar(_bar_height())
	Batch.merge(self)
	for part in [door, knife, whisk, lid, jar, pan_node, flame]:
		if part:
			Batch.merge(part)


func _bar_height() -> float:
	match kind:
		"oven": return 0.12
		"blender": return 0.6
		"fryer": return 0.55
		"pot": return 0.48
		"sink": return 0.42
		"microwave": return 0.48
		"toaster": return 0.36
		"fridge": return 0.72
		"grill": return 0.36
	return 0.38


func title() -> String:
	return NAMES[kind]


# ================================================================ build helpers

func _box_col(size: Vector3, center: Vector3) -> void:
	var c := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	c.shape = b
	c.position = center
	add_child(c)


func _dyn(parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.set_meta("nobatch", true)
	(parent if parent else self).add_child(n)
	return n


func _s(parent: Node3D, kind_: String, mat, pos: Vector3, scl: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	return Models.solid(parent, kind_, mat, pos, scl, rot)


func _tube(parent: Node3D, mat: Material, pos: Vector3, top_r: float, bot_r: float, h: float, segs := 28) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = top_r
	c.bottom_radius = bot_r
	c.height = h
	c.cap_top = false
	c.radial_segments = segs
	var mi := MeshInstance3D.new()
	mi.mesh = c
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _make_bar(y: float) -> void:
	bar = _dyn()
	bar.position.y = y
	var bgm := StandardMaterial3D.new()
	bgm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bgm.albedo_color = Color(0.03, 0.03, 0.05, 0.7)
	bgm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bgm.no_depth_test = true
	bgm.render_priority = 10
	var bg := Models.solid(bar, "box", bgm, Vector3.ZERO, Vector3(0.3, 0.032, 0.002))
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bar_mat = StandardMaterial3D.new()
	bar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar_mat.no_depth_test = true
	bar_mat.render_priority = 11
	bar_fill = Models.solid(bar, "box", bar_mat, Vector3(0, 0, 0.002), Vector3(0.29, 0.022, 0.002))
	bar_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font = UI.body_font()
	label.font_size = 40
	label.pixel_size = 0.0013
	label.outline_size = 10
	label.outline_modulate = Color(0, 0, 0, 0.8)
	label.no_depth_test = true
	label.position.y = y + 0.055
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
	bar_fill.scale.x = maxf(0.001, 0.29 * p)
	bar_fill.position.x = -0.145 + 0.145 * p
	bar_mat.albedo_color = col
	label.visible = text != ""
	if label.text != text:
		label.text = text
	label.modulate = col.lightened(0.35)


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


static var _two := {}


static func two_sided(n: String) -> StandardMaterial3D:
	if not _two.has(n):
		var m := Tex.mat(n).duplicate() as StandardMaterial3D
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_two[n] = m
	return _two[n]


# ================================================================ builds

func _build_trash() -> void:
	var steel := two_sided("steel")
	_tube(self, steel, Vector3(0, 0.33, 0), 0.19, 0.18, 0.62)
	_s(self, "cyl", Tex.mat("steel"), Vector3(0, 0.02, 0), Vector3(0.37, 0.04, 0.37))
	_s(self, "cyl", Tex.mat("black"), Vector3(0, 0.6, 0), Vector3(0.36, 0.012, 0.36))
	_s(self, "box", Tex.mat("black"), Vector3(0, 0.03, 0.2), Vector3(0.12, 0.02, 0.06))
	lid = _dyn()
	lid.position = Vector3(0, 0.64, -0.19)
	_s(lid, "cyl", Tex.mat("steel"), Vector3(0, 0.0, 0.19), Vector3(0.39, 0.03, 0.39))
	_s(lid, "hemi", Tex.mat("steel"), Vector3(0, 0.015, 0.19), Vector3(0.39, 0.06, 0.39))
	_box_col(Vector3(0.4, 0.68, 0.4), Vector3(0, 0.34, 0))


func _build_sink() -> void:
	# Cabinet built hollow so the basin sinks into the counter.
	var base := _dyn()
	base.remove_meta("nobatch")
	base.position.y = -Kitchen.TOP
	var cab := Tex.mat("cabinet")
	var L := 0.9
	var Dp := Kitchen.DEPTH
	var front := (Dp - 0.04) / 2 - 0.02
	_s(base, "box", cab, Vector3(-L / 2 + 0.01, 0.48, -0.02), Vector3(0.02, 0.76, Dp - 0.04))
	_s(base, "box", cab, Vector3(L / 2 - 0.01, 0.48, -0.02), Vector3(0.02, 0.76, Dp - 0.04))
	_s(base, "box", Tex.mat("black"), Vector3(0, 0.05, -0.05), Vector3(L - 0.02, 0.1, Dp - 0.12))
	_s(base, "box", cab, Vector3(0, 0.5, -0.3), Vector3(L, 0.8, 0.02))
	Kitchen._shaker(base, cab, Vector3(0, 0.5, front), Vector2(L - 0.006, 0.76), 0.06)
	_s(base, "box", Tex.mat("brass"), Vector3(0, 0.76, front + 0.03), Vector3(0.22, 0.012, 0.012))
	# countertop with a 60 x 40 cm cut-out
	var top := Tex.mat("marble")
	var y := Kitchen.TOP - 0.02
	var hw := 0.3
	var hd := 0.2
	_s(base, "box", top, Vector3(-(L / 2 + hw) / 2, y, 0), Vector3(L / 2 - hw + 0.01, 0.04, Dp + 0.04))
	_s(base, "box", top, Vector3((L / 2 + hw) / 2, y, 0), Vector3(L / 2 - hw + 0.01, 0.04, Dp + 0.04))
	_s(base, "box", top, Vector3(0, y, -(Dp / 2 + 0.02 + hd) / 2 - 0.0), Vector3(hw * 2, 0.04, Dp / 2 + 0.02 - hd))
	_s(base, "box", top, Vector3(0, y, (Dp / 2 + 0.02 + hd) / 2), Vector3(hw * 2, 0.04, Dp / 2 + 0.02 - hd))
	# stainless basin
	var steel := two_sided("steel")
	var bd := 0.2
	var by := Kitchen.TOP - 0.04 - bd / 2
	_s(base, "box", steel, Vector3(0, by - bd / 2, 0), Vector3(hw * 2, 0.01, hd * 2))
	_s(base, "box", steel, Vector3(-hw, by, 0), Vector3(0.01, bd, hd * 2))
	_s(base, "box", steel, Vector3(hw, by, 0), Vector3(0.01, bd, hd * 2))
	_s(base, "box", steel, Vector3(0, by, -hd), Vector3(hw * 2, bd, 0.01))
	_s(base, "box", steel, Vector3(0, by, hd), Vector3(hw * 2, bd, 0.01))
	_s(base, "cyl", Tex.mat("chrome"), Vector3(0, by - bd / 2 + 0.006, 0), Vector3(0.06, 0.004, 0.06))
	_s(base, "cyl", Tex.mat("black"), Vector3(0, by - bd / 2 + 0.009, 0), Vector3(0.03, 0.002, 0.03))
	# gooseneck tap
	var chrome := Tex.mat("chrome")
	var tz := -0.25
	_s(self, "cyl", chrome, Vector3(0, 0.02, tz), Vector3(0.06, 0.04, 0.06))
	_s(self, "cyl", chrome, Vector3(0, 0.2, tz), Vector3(0.03, 0.36, 0.03))
	for i in 7:
		var a := PI * i / 6.0
		_s(self, "sphere", chrome, Vector3(0, 0.38 + sin(a) * 0.07, tz + 0.07 - cos(a) * 0.07), Vector3.ONE * 0.032)
	_s(self, "cyl", chrome, Vector3(0, 0.34, tz + 0.14), Vector3(0.03, 0.08, 0.03))
	_s(self, "box", chrome, Vector3(0.05, 0.08, tz), Vector3(0.012, 0.012, 0.07), Vector3(-25, 0, 0))
	# soap dispenser
	_s(self, "cyl", Tex.mat("glass"), Vector3(0.36, 0.08, tz + 0.02), Vector3(0.06, 0.16, 0.06))
	_s(self, "cyl", Color(0.55, 0.75, 0.45), Vector3(0.36, 0.06, tz + 0.02), Vector3(0.05, 0.11, 0.05))
	_s(self, "cyl", chrome, Vector3(0.36, 0.18, tz + 0.02), Vector3(0.02, 0.05, 0.02))
	_particles("water", Vector3(0, 0.29, tz + 0.14), false)
	hold.position = Vector3(0, -bd - 0.035, 0.0)
	loop = game.sfx.loop_player("water", self, -8.0)
	_box_col(Vector3(0.6, 0.12, 0.4), Vector3(0, -0.04, 0))
	_box_col(Vector3(L, Kitchen.TOP - 0.25, Dp), Vector3(0, -Kitchen.TOP / 2 - 0.12, 0))


func _build_board() -> void:
	var wood := Tex.mat("butcher")
	_s(self, "box", wood, Vector3(0, 0.02, 0), Vector3(0.48, 0.04, 0.32))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_s(self, "cyl", Tex.mat("rubber"), Vector3(sx * 0.2, 0.003, sz * 0.12), Vector3(0.03, 0.006, 0.03))
	knife = _dyn()
	knife.position = Vector3(0.18, 0.06, -0.08)
	var blade := _s(knife, "prism", Tex.mat("steel"), Vector3(-0.12, -0.012, 0.0), Vector3(0.24, 0.003, 0.05), Vector3(90, 0, 0))
	blade.rotation_degrees = Vector3(90, 0, 0)
	_s(knife, "box", Tex.mat("steel"), Vector3(-0.1, 0.005, 0), Vector3(0.2, 0.012, 0.003))
	_s(knife, "box", Tex.mat("walnut"), Vector3(0.06, 0.0, 0), Vector3(0.12, 0.026, 0.02))
	for i in 3:
		_s(knife, "cyl", Tex.mat("brass"), Vector3(0.02 + i * 0.035, 0.0, 0.0), Vector3(0.006, 0.022, 0.006), Vector3(90, 0, 0))
	knife.rotation_degrees = Vector3(0, 35, -22)
	hold.position = Vector3(-0.04, 0.04, 0.02)
	_box_col(Vector3(0.48, 0.25, 0.32), Vector3(0, 0.12, 0))


func _build_bowl() -> void:
	var steel := two_sided("steel")
	_tube(self, steel, Vector3(0, 0.075, 0), 0.2, 0.1, 0.15, 36)
	_s(self, "cyl", Tex.mat("steel"), Vector3(0, 0.003, 0), Vector3(0.2, 0.006, 0.2))
	_s(self, "torus", Tex.mat("steel"), Vector3(0, 0.15, 0), Vector3(0.41, 0.06, 0.41))
	whisk = _dyn()
	whisk.position = Vector3(0.09, 0.03, 0)
	_s(whisk, "cyl", Tex.mat("walnut"), Vector3(0.0, 0.3, 0), Vector3(0.024, 0.15, 0.024))
	for i in 4:
		_s(whisk, "torus", Tex.mat("chrome"), Vector3(0, 0.14, 0), Vector3(0.08, 0.004 * 25, 0.2), Vector3(0, i * 45, 90))
	whisk.rotation_degrees = Vector3(0, 0, 22)
	hold.position.y = 0.035
	_box_col(Vector3(0.42, 0.35, 0.42), Vector3(0, 0.17, 0))


func _build_blender() -> void:
	var black := Tex.mat("black")
	_s(self, "box", black, Vector3(0, 0.07, 0), Vector3(0.19, 0.14, 0.19))
	_s(self, "cyl", Tex.mat("chrome"), Vector3(0, 0.07, 0.097), Vector3(0.05, 0.012, 0.05), Vector3(90, 0, 0))
	_s(self, "cyl", Color(0.9, 0.2, 0.15), Vector3(0.06, 0.03, 0.097), Vector3(0.012, 0.004, 0.012), Vector3(90, 0, 0))
	_s(self, "cyl", black, Vector3(0, 0.15, 0), Vector3(0.15, 0.02, 0.15))
	jar = _dyn()
	jar.position.y = 0.16
	var glass := Tex.mat("glass").duplicate() as StandardMaterial3D
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	_tube(jar, glass, Vector3(0, 0.15, 0), 0.085, 0.065, 0.3, 24)
	_s(jar, "cyl", black, Vector3(0, 0.305, 0), Vector3(0.18, 0.025, 0.18))
	_s(jar, "cyl", Tex.mat("chrome"), Vector3(0, 0.33, 0), Vector3(0.05, 0.02, 0.05))
	_s(jar, "box", Tex.mat("chrome"), Vector3(0, 0.02, 0), Vector3(0.1, 0.004, 0.015), Vector3(0, 30, 10))
	_s(jar, "box", Tex.mat("chrome"), Vector3(0, 0.02, 0), Vector3(0.1, 0.004, 0.015), Vector3(0, -60, -10))
	_s(jar, "box", black, Vector3(0.1, 0.17, 0), Vector3(0.02, 0.2, 0.04))
	hold.position.y = 0.17
	loop = game.sfx.loop_player("blender", self, -6.0)
	_box_col(Vector3(0.24, 0.52, 0.24), Vector3(0, 0.26, 0))


func _burner() -> void:
	var iron := Tex.mat("cast_iron")
	_s(self, "cyl", Tex.mat("black"), Vector3(0, 0.0, 0), Vector3(0.12, 0.02, 0.12))
	_s(self, "cyl", Tex.mat("steel_dark"), Vector3(0, 0.012, 0), Vector3(0.085, 0.012, 0.085))
	for a in [0, 90]:
		_s(self, "box", iron, Vector3(0, 0.03, 0), Vector3(0.34, 0.016, 0.016), Vector3(0, a, 0))
	_s(self, "torus", iron, Vector3(0, 0.03, 0), Vector3(0.3, 0.06, 0.3))
	flame = _dyn()
	flame.position.y = 0.022
	var blue := Models.glow_mat(Color(0.3, 0.5, 1.0), 3.0)
	blue.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blue.albedo_color = Color(0.4, 0.6, 1.0, 0.7)
	for i in 14:
		var a := TAU * i / 14.0
		var cone := _s(flame, "cone", blue, Vector3(cos(a) * 0.045, 0.012, sin(a) * 0.045), Vector3(0.012, 0.025, 0.012), Vector3(sin(a) * 30, 0, -cos(a) * 30))
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	flame.visible = false
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.35)
	l.omni_range = 0.8
	l.light_energy = 0.0
	l.position.y = 0.08
	l.set_meta("nobatch", true)
	add_child(l)
	glow = l


func _build_pan() -> void:
	_burner()
	pan_node = _dyn()
	pan_node.position.y = 0.038
	var iron := two_sided("cast_iron")
	_tube(pan_node, iron, Vector3(0, 0.025, 0), 0.135, 0.12, 0.045, 32)
	_s(pan_node, "cyl", Tex.mat("cast_iron"), Vector3(0, 0.004, 0), Vector3(0.24, 0.008, 0.24))
	_s(pan_node, "torus", Tex.mat("cast_iron"), Vector3(0, 0.047, 0), Vector3(0.275, 0.05, 0.275))
	_s(pan_node, "box", Tex.mat("cast_iron"), Vector3(0.23, 0.045, 0), Vector3(0.2, 0.016, 0.035), Vector3(0, 0, 10))
	_s(pan_node, "box", Tex.mat("walnut"), Vector3(0.36, 0.062, 0), Vector3(0.1, 0.022, 0.03), Vector3(0, 0, 10))
	hold.position.y = 0.05
	_particles("sizzle", Vector3(0, 0.07, 0), false)
	_particles("smoke", Vector3(0, 0.12, 0), false)
	loop = game.sfx.loop_player("sizzle", self, -5.0)
	_box_col(Vector3(0.36, 0.25, 0.36), Vector3(0.0, 0.12, 0))


func _build_pot() -> void:
	_burner()
	var steel := two_sided("steel")
	_tube(self, steel, Vector3(0, 0.145, 0), 0.14, 0.14, 0.21, 32)
	_s(self, "cyl", Tex.mat("steel"), Vector3(0, 0.042, 0), Vector3(0.28, 0.008, 0.28))
	_s(self, "torus", Tex.mat("steel"), Vector3(0, 0.25, 0), Vector3(0.29, 0.04, 0.29))
	for sx in [-1, 1]:
		_s(self, "torus", Tex.mat("steel"), Vector3(sx * 0.16, 0.22, 0), Vector3(0.07, 0.12, 0.05), Vector3(90, 90, 0))
	liquid_mat = StandardMaterial3D.new()
	liquid_mat.albedo_color = Color(0.55, 0.68, 0.75, 0.75)
	liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid_mat.roughness = 0.02
	liquid_mat.metallic_specular = 1.0
	var water := _s(self, "cyl", liquid_mat, Vector3(0, 0.19, 0), Vector3(0.275, 0.004, 0.275))
	water.set_meta("nobatch", true)
	hold.position.y = 0.16
	_particles("steam", Vector3(0, 0.27, 0), false)
	_particles("bubbles", Vector3(0, 0.19, 0), false)
	loop = game.sfx.loop_player("boil", self, -4.0)
	_box_col(Vector3(0.36, 0.34, 0.36), Vector3(0, 0.17, 0))


func _build_fryer() -> void:
	var steel := Tex.mat("steel")
	var w := 0.36
	var d := 0.42
	var h := 0.3
	_s(self, "box", steel, Vector3(0, 0.1, 0), Vector3(w, 0.2, d))
	for sx in [-1, 1]:
		_s(self, "box", steel, Vector3(sx * (w / 2 - 0.01), 0.25, 0), Vector3(0.02, 0.1, d))
	_s(self, "box", steel, Vector3(0, 0.25, -d / 2 + 0.01), Vector3(w, 0.1, 0.02))
	_s(self, "box", steel, Vector3(0, 0.25, d / 2 - 0.01), Vector3(w, 0.1, 0.02))
	_s(self, "box", Tex.mat("black"), Vector3(0, 0.1, d / 2 + 0.002), Vector3(w - 0.04, 0.14, 0.004))
	_s(self, "cyl", Tex.mat("chrome"), Vector3(-0.08, 0.1, d / 2 + 0.01), Vector3(0.04, 0.015, 0.04), Vector3(90, 0, 0))
	var ready_led := _s(self, "sphere", Models.glow_mat(Color(1.0, 0.4, 0.1), 3.0), Vector3(0.1, 0.12, d / 2 + 0.006), Vector3.ONE * 0.012)
	ready_led.set_meta("nobatch", true)
	for sx in [-1, 1]:
		_s(self, "cyl", Tex.mat("black"), Vector3(sx * 0.15, 0.005, sx * 0.18), Vector3(0.03, 0.01, 0.03))
	liquid_mat = StandardMaterial3D.new()
	liquid_mat.albedo_color = Color(0.78, 0.55, 0.12, 0.92)
	liquid_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	liquid_mat.roughness = 0.02
	liquid_mat.metallic_specular = 1.0
	liquid_mat.emission_enabled = true
	liquid_mat.emission = Color(0.9, 0.5, 0.1)
	liquid_mat.emission_energy_multiplier = 0.0
	var oil := _s(self, "box", liquid_mat, Vector3(0, 0.255, 0), Vector3(w - 0.04, 0.004, d - 0.04))
	oil.set_meta("nobatch", true)
	# basket rim + handle
	var wire := two_sided("chrome")
	_s(self, "box", wire, Vector3(0, 0.29, d / 2 - 0.04), Vector3(w - 0.07, 0.008, 0.008))
	_s(self, "box", Tex.mat("black"), Vector3(0, 0.33, d / 2 + 0.03), Vector3(0.03, 0.025, 0.14), Vector3(-20, 0, 0))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.7, 0.3)
	l.omni_range = 0.6
	l.light_energy = 0.0
	l.position.y = 0.4
	l.set_meta("nobatch", true)
	add_child(l)
	glow = l
	hold.position.y = 0.24
	_particles("bubbles", Vector3(0, 0.26, 0), false)
	_particles("sizzle", Vector3(0, 0.27, 0), false)
	_particles("smoke", Vector3(0, 0.33, 0), false)
	(fx["bubbles"] as CPUParticles3D).color_ramp.set_color(0, Color(1, 0.85, 0.45, 0.9))
	loop = game.sfx.loop_player("fryer", self, -5.0)
	_box_col(Vector3(w, 0.36, d), Vector3(0, 0.18, 0))


func _build_oven() -> void:
	# A full gas range: stainless body, cooktop, control panel, oven below.
	var steel := Tex.mat("steel")
	var enamel := Tex.tinted("cast_iron", Color(0.08, 0.08, 0.09))
	var w := 0.9
	var d := 0.64
	var y0 := -Kitchen.TOP
	# shell
	for sx in [-1, 1]:
		_s(self, "box", steel, Vector3(sx * (w / 2 - 0.02), y0 + Kitchen.TOP / 2, 0), Vector3(0.04, Kitchen.TOP, d))
	_s(self, "box", steel, Vector3(0, y0 + 0.05, 0), Vector3(w, 0.1, d - 0.04))
	_s(self, "box", Tex.mat("black"), Vector3(0, y0 + 0.05, d / 2 - 0.05), Vector3(w - 0.08, 0.08, 0.01))
	_s(self, "box", steel, Vector3(0, -0.02, 0), Vector3(w, 0.04, d))
	_s(self, "box", steel, Vector3(0, -0.1, d / 2 - 0.03), Vector3(w, 0.12, 0.06))
	for i in 5:
		_s(self, "cyl", Tex.mat("black"), Vector3(-0.3 + i * 0.15, -0.1, d / 2 + 0.01), Vector3(0.045, 0.03, 0.045), Vector3(90, 0, 0))
		_s(self, "box", Tex.mat("chrome"), Vector3(-0.3 + i * 0.15, -0.1, d / 2 + 0.027), Vector3(0.006, 0.03, 0.004))
	# cavity
	var cy0 := y0 + 0.12
	var cy1 := -0.17
	var ch := cy1 - cy0
	_s(self, "box", enamel, Vector3(0, cy0 + ch / 2, -d / 2 + 0.03), Vector3(w - 0.08, ch, 0.02))
	_s(self, "box", enamel, Vector3(0, cy0, 0), Vector3(w - 0.08, 0.02, d - 0.06))
	_s(self, "box", enamel, Vector3(0, cy1, 0), Vector3(w - 0.08, 0.02, d - 0.06))
	for sx in [-1, 1]:
		_s(self, "box", enamel, Vector3(sx * (w / 2 - 0.05), cy0 + ch / 2, 0), Vector3(0.02, ch, d - 0.06))
	# rack
	var rack_y := cy0 + 0.12
	for i in 7:
		_s(self, "cyl", Tex.mat("chrome"), Vector3(0, rack_y, -0.24 + i * 0.08), Vector3(0.006, w - 0.12, 0.006), Vector3(0, 0, 90))
	var heat := Models.glow_mat(Color(1.0, 0.35, 0.08), 0.0)
	liquid_mat = heat
	var element := _s(self, "torus", heat, Vector3(0, cy0 + 0.02, 0), Vector3(0.5, 0.03, 0.45))
	element.set_meta("nobatch", true)
	# front frame around the door opening
	_s(self, "box", steel, Vector3(0, cy1 + 0.0, d / 2 - 0.01), Vector3(w, 0.04, 0.02))
	# door (hinged at the bottom)
	door = _dyn()
	door.position = Vector3(0, cy0 - 0.02, d / 2 + 0.01)
	var dh := ch + 0.02
	_s(door, "box", steel, Vector3(0, dh / 2, 0.012), Vector3(w - 0.02, dh, 0.024))
	var glass := Tex.mat("glass").duplicate() as StandardMaterial3D
	glass.albedo_color = Color(0.1, 0.08, 0.06, 0.45)
	_s(door, "box", glass, Vector3(0, dh / 2, 0.026), Vector3(w - 0.22, dh - 0.16, 0.004))
	for sx in [-1, 1]:
		_s(door, "box", Tex.mat("chrome"), Vector3(sx * 0.3, dh - 0.035, 0.055), Vector3(0.016, 0.016, 0.06))
	_s(door, "cyl", Tex.mat("chrome"), Vector3(0, dh - 0.035, 0.085), Vector3(0.018, 0.64, 0.018), Vector3(0, 0, 90))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.55, 0.25)
	l.omni_range = 0.9
	l.light_energy = 0.0
	l.position = Vector3(0, cy0 + ch / 2, 0.1)
	l.set_meta("nobatch", true)
	add_child(l)
	glow = l
	hold.position = Vector3(0, rack_y + 0.006, 0.0)
	_particles("smoke", Vector3(0, -0.15, d / 2 + 0.05), false)
	loop = game.sfx.loop_player("hum", self, -10.0)
	_box_col(Vector3(w, Kitchen.TOP - 0.2, d), Vector3(0, y0 + (Kitchen.TOP - 0.2) / 2 + 0.06, 0))


func _build_plates() -> void:
	var ceramic := Tex.mat("ceramic")
	var rim := Models.smat(Color(0.2, 0.36, 0.6), 0.2)
	for i in 8:
		_s(self, "cyl", ceramic, Vector3(0, 0.009 + i * 0.018, 0), Vector3(0.3, 0.012, 0.3))
		_s(self, "torus", ceramic, Vector3(0, 0.016 + i * 0.018, 0), Vector3(0.33, 0.07, 0.33))
		_s(self, "torus", rim, Vector3(0, 0.0185 + i * 0.018, 0), Vector3(0.318, 0.02, 0.318))
	_box_col(Vector3(0.34, 0.2, 0.34), Vector3(0, 0.1, 0))


func _build_serve() -> void:
	var steel := Tex.mat("steel")
	_s(self, "box", steel, Vector3(0, 0.015, 0), Vector3(1.0, 0.03, 0.5))
	# heat lamps
	for sx in [-0.25, 0.25]:
		_s(self, "cyl", Tex.mat("black"), Vector3(sx, 0.75, -0.05), Vector3(0.012, 0.5, 0.012))
		_s(self, "cone", Tex.mat("steel"), Vector3(sx, 0.52, -0.05), Vector3(0.16, 0.1, 0.16))
		_s(self, "sphere", Models.glow_mat(Color(1.0, 0.35, 0.12), 4.0), Vector3(sx, 0.47, -0.05), Vector3.ONE * 0.06)
	var heat := OmniLight3D.new()
	heat.light_color = Color(1.0, 0.45, 0.2)
	heat.omni_range = 0.9
	heat.light_energy = 0.8
	heat.position = Vector3(0, 0.4, 0)
	heat.set_meta("nobatch", true)
	add_child(heat)
	# bell
	_s(self, "cyl", Tex.mat("black"), Vector3(0.38, 0.04, 0.15), Vector3(0.1, 0.02, 0.1))
	_s(self, "hemi", Tex.mat("chrome"), Vector3(0.38, 0.05, 0.15), Vector3(0.09, 0.09, 0.09))
	_s(self, "cyl", Tex.mat("chrome"), Vector3(0.38, 0.1, 0.15), Vector3(0.01, 0.03, 0.01))
	# ticket rail with paper tickets
	_s(self, "box", Tex.mat("steel"), Vector3(0, 0.98, -0.18), Vector3(1.0, 0.03, 0.02))
	for i in 3:
		_s(self, "box", Tex.mat("paper"), Vector3(-0.3 + i * 0.25, 0.9, -0.17), Vector3(0.09, 0.14, 0.002), Vector3(0, 0, (i - 1) * 5))
	hold.position = Vector3(-0.1, 0.03, 0.0)
	_particles("confetti", Vector3(0, 0.2, 0.1), false)
	_box_col(Vector3(1.0, 0.35, 0.5), Vector3(0, 0.17, 0))


func _build_grill() -> void:
	# Countertop griddle grill: black body, ridged cast-iron plate, glowing coals underneath.
	var iron := Tex.mat("cast_iron")
	var w := 0.56
	var d := 0.38
	_s(self, "box", Tex.mat("black"), Vector3(0, 0.05, 0), Vector3(w, 0.1, d))
	_s(self, "box", Tex.mat("steel"), Vector3(0, 0.1, d / 2 - 0.02), Vector3(w, 0.04, 0.04))
	for i in 2:
		_s(self, "cyl", Tex.mat("black"), Vector3(-0.18 + i * 0.36, 0.06, d / 2 + 0.01), Vector3(0.04, 0.02, 0.04), Vector3(90, 0, 0))
	var heat := Models.glow_mat(Color(1.0, 0.35, 0.08), 0.0)
	liquid_mat = heat
	var coals := _s(self, "box", heat, Vector3(0, 0.105, -0.02), Vector3(w - 0.08, 0.01, d - 0.1))
	coals.set_meta("nobatch", true)
	for i in 11:
		_s(self, "box", iron, Vector3(-w / 2 + 0.05 + i * (w - 0.1) / 10.0, 0.125, -0.02), Vector3(0.016, 0.02, d - 0.08))
	_s(self, "box", iron, Vector3(0, 0.117, -d / 2 + 0.03), Vector3(w - 0.06, 0.03, 0.02))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.25)
	l.omni_range = 0.7
	l.light_energy = 0.0
	l.position.y = 0.2
	l.set_meta("nobatch", true)
	add_child(l)
	glow = l
	hold.position = Vector3(0, 0.135, -0.02)
	_particles("sizzle", Vector3(0, 0.16, 0), false)
	_particles("smoke", Vector3(0, 0.2, 0), false)
	loop = game.sfx.loop_player("sizzle", self, -7.0)
	_box_col(Vector3(w, 0.2, d), Vector3(0, 0.1, 0))


func _build_microwave() -> void:
	var w := 0.5
	var h := 0.3
	var d := 0.36
	var steel := Tex.mat("steel")
	var black := Tex.mat("black")
	_s(self, "box", steel, Vector3(0, h - 0.01, 0), Vector3(w, 0.02, d))
	_s(self, "box", steel, Vector3(0, 0.01, 0), Vector3(w, 0.02, d))
	_s(self, "box", steel, Vector3(-w / 2 + 0.01, h / 2, 0), Vector3(0.02, h, d))
	_s(self, "box", steel, Vector3(w / 2 - 0.01, h / 2, 0), Vector3(0.02, h, d))
	_s(self, "box", steel, Vector3(0, h / 2, -d / 2 + 0.01), Vector3(w, h, 0.02))
	_s(self, "box", black, Vector3(w / 2 - 0.07, h / 2, 0), Vector3(0.12, h - 0.03, d - 0.02))
	for i in 6:
		_s(self, "box", Tex.mat("chrome"), Vector3(w / 2 - 0.07, 0.24 - i * 0.03, d / 2 - 0.005), Vector3(0.06, 0.012, 0.004))
	var inside := Tex.tinted("plaster", Color(0.92, 0.9, 0.85))
	_s(self, "box", inside, Vector3(-0.07, h / 2, -d / 2 + 0.025), Vector3(w - 0.17, h - 0.05, 0.01))
	_s(self, "cyl", Tex.mat("glass"), Vector3(-0.07, 0.03, 0.0), Vector3(0.26, 0.008, 0.26))
	door = _dyn()
	door.position = Vector3(-w / 2 + 0.005, h / 2, d / 2 + 0.005)
	var glass := Tex.mat("glass").duplicate() as StandardMaterial3D
	glass.albedo_color = Color(0.08, 0.08, 0.08, 0.5)
	_s(door, "box", black, Vector3((w - 0.14) / 2, 0, 0), Vector3(w - 0.14, h - 0.02, 0.02))
	_s(door, "box", glass, Vector3((w - 0.14) / 2, 0, 0.012), Vector3(w - 0.22, h - 0.09, 0.004))
	_s(door, "box", Tex.mat("chrome"), Vector3(w - 0.17, 0, 0.03), Vector3(0.015, h - 0.1, 0.02))
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.9, 0.6)
	l.omni_range = 0.4
	l.light_energy = 0.0
	l.position = Vector3(-0.07, h - 0.06, 0)
	l.set_meta("nobatch", true)
	add_child(l)
	glow = l
	hold.position = Vector3(-0.07, 0.04, 0.0)
	loop = game.sfx.loop_player("hum", self, -8.0)
	_box_col(Vector3(w, h, d), Vector3(0, h / 2, 0))


func _build_toaster() -> void:
	var steel := Tex.mat("chrome")
	_s(self, "box", steel, Vector3(0, 0.1, 0), Vector3(0.28, 0.18, 0.17))
	_s(self, "box", Tex.mat("black"), Vector3(0, 0.005, 0), Vector3(0.3, 0.01, 0.19))
	for sz in [-0.035, 0.035]:
		_s(self, "box", Tex.mat("black"), Vector3(0, 0.19, sz), Vector3(0.2, 0.004, 0.028))
	_s(self, "box", Tex.mat("black"), Vector3(0.15, 0.13, 0), Vector3(0.02, 0.025, 0.03))
	var heat := Models.glow_mat(Color(1.0, 0.4, 0.1), 0.0)
	liquid_mat = heat
	for sz in [-0.035, 0.035]:
		var e := _s(self, "box", heat, Vector3(0, 0.192, sz), Vector3(0.18, 0.002, 0.022))
		e.set_meta("nobatch", true)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.5, 0.2)
	l.omni_range = 0.4
	l.light_energy = 0.0
	l.position.y = 0.25
	l.set_meta("nobatch", true)
	add_child(l)
	glow = l
	hold.position = Vector3(0, 0.16, 0)
	loop = game.sfx.loop_player("hum", self, -12.0)
	_box_col(Vector3(0.3, 0.2, 0.19), Vector3(0, 0.1, 0))


func _build_fridge() -> void:
	# Countertop fridge-freezer with a glass door and a frosty blue light.
	var w := 0.5
	var h := 0.56
	var d := 0.44
	var white := Tex.tinted("plaster", Color(0.95, 0.96, 0.97))
	_s(self, "box", white, Vector3(0, h - 0.015, 0), Vector3(w, 0.03, d))
	_s(self, "box", white, Vector3(0, 0.015, 0), Vector3(w, 0.03, d))
	_s(self, "box", white, Vector3(-w / 2 + 0.015, h / 2, 0), Vector3(0.03, h, d))
	_s(self, "box", white, Vector3(w / 2 - 0.015, h / 2, 0), Vector3(0.03, h, d))
	_s(self, "box", Tex.mat("fridge_inside"), Vector3(0, h / 2, -d / 2 + 0.015), Vector3(w, h, 0.03))
	_s(self, "box", Tex.mat("glass"), Vector3(0, 0.2, 0), Vector3(w - 0.06, 0.008, d - 0.06))
	_s(self, "box", Models.glow_mat(Color(0.6, 0.85, 1.0), 1.5), Vector3(0, h - 0.035, 0), Vector3(w - 0.1, 0.006, 0.04))
	door = _dyn()
	door.position = Vector3(-w / 2, h / 2, d / 2 + 0.01)
	_s(door, "box", Tex.mat("glass_fridge"), Vector3(w / 2, 0, 0), Vector3(w, h, 0.016))
	_s(door, "box", Tex.mat("chrome"), Vector3(w - 0.04, 0, 0.025), Vector3(0.016, h * 0.6, 0.02))
	var cold := OmniLight3D.new()
	cold.light_color = Color(0.75, 0.9, 1.0)
	cold.omni_range = 0.6
	cold.light_energy = 0.6
	cold.position = Vector3(0, h - 0.1, 0.05)
	cold.set_meta("nobatch", true)
	add_child(cold)
	hold.position = Vector3(0, 0.21, 0)
	_particles("steam", Vector3(0, 0.3, d / 2), false)
	_box_col(Vector3(w, h, d), Vector3(0, h / 2, 0))



# ================================================================ interaction

func accepts(f: Food) -> String:
	if not CAP.has(kind):
		return ""
	if kind == "blender" and running:
		return "Wait for the blender!"
	if is_full():
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
		"toaster":
			if f.data["id"] == "mix" or not f.data["id"] in TOASTABLE:
				return "Only bread and bakes fit in the toaster"
			if f.data["id"] in ["bread", "bread_loaf", "baguette"] and int(f.data.get("cut", 0)) == 0:
				return "Slice it first - a whole loaf won't fit"
	return ""


func add_food(f: Food) -> void:
	if not kind in ["sink", "board"] and DB.is_pack(f.data["id"]) and not f.data.get("portion", false):
		DB.portion(f.data)
		f.rebuild()
		f.mark_changed()
	pending_style = ""
	popped = false
	frozen_once = false
	f.reparent(hold, true)
	f.set_carried(true)
	contents.append(f)
	done_once = false
	work = 0
	_layout()
	f.pop(1.15)
	var at := global_position
	match kind:
		"pot", "fryer":
			game.sfx.play_at("splash", at, -2.0)
			if kind == "fryer":
				game.sfx.play_at("sizzle_hit", at, -2.0)
		"sink":
			game.sfx.play_at("splash", at, -6.0)
		"pan":
			game.sfx.play_at("sizzle_hit", at, -2.0)
			(fx["sizzle"] as CPUParticles3D).restart()
		"oven", "microwave", "fridge":
			_swing_door(true)
			game.sfx.play_at("place_wood", at, -4.0)
		"toaster":
			game.sfx.play_at("click", at, -2.0)
			for c in contents:
				var tw := (c as Food).create_tween()
				tw.tween_property(c, "position:y", -0.06, 0.25).set_delay(0.15)
		"grill":
			game.sfx.play_at("sizzle_hit", at, -2.0)
		"board":
			game.sfx.play_at("place_wood", at, -2.0)
		_:
			game.sfx.play_at("place_metal", at, -3.0)


func is_full() -> bool:
	var cap: int = CAP[kind]
	return cap != NO_LIMIT and contents.size() >= cap


func _layout() -> void:
	var n := contents.size()
	var per := mini(n, RING)
	var r: float = SPREAD.get(kind, 0.0)
	var base: float = ITEM_SCALE.get(kind, 1.0)
	var sc := base if n <= 1 else base * clampf(1.2 / sqrt(per), 0.45, 1.0)
	if per > 3:
		r *= 1.15
	for i in n:
		var f: Food = contents[i]
		# full rings pile up in layers, each turned a little so they sit in the gaps
		var layer := i / RING
		var cnt := mini(RING, n - layer * RING)
		var target := Vector3(0.0, layer * 0.035 * sc, 0.0)
		if cnt > 1:
			var a := TAU * (i % RING) / cnt + 0.4 + layer * 0.5
			target += Vector3(cos(a) * r, 0.0, sin(a) * r)
		var tw := f.create_tween()
		tw.set_parallel(true)
		tw.tween_property(f, "position", target, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(f, "rotation", Vector3(0, f.rotation.y, 0), 0.2)
		tw.tween_property(f, "scale", Vector3.ONE * sc, 0.2)


## Should taking from this station merge the contents into one dish?
func _merges() -> bool:
	return contents.size() > 1 and done_once and method != "" and not kind in ["fridge", "toaster"]


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
	pending_style = ""
	popped = false
	frozen_once = false
	if kind in ["oven", "microwave", "fridge"]:
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
			game.sfx.play_at("click", global_position)
			return ""
	return ""


func use_label() -> String:
	match kind:
		"board":
			if contents.is_empty():
				return ""
			var f: Food = contents[0]
			if int(f.data.get("cut", 0)) == 0 and DB.has_styles(f.data["id"]) and pending_style == "":
				return "Cut (choose how)"
			return {"slice": "Slice", "dice": "Dice", "mince": "Mince"}.get(pending_style, "Chop")
		"bowl":
			return "Whisk / Bread" if not contents.is_empty() else ""
		"blender":
			return "Blend" if not contents.is_empty() and not running else ""
	return ""


## Called by the cut menu. "free" opens the hand-cut pad.
func choose_style(style: String) -> void:
	if contents.is_empty():
		return
	if style == "free":
		game.ui.open_free_cut(self, contents[0])
		return
	pending_style = style
	work = 0
	_chop()


## Knife animation + chop sound + bits (shared by every cutting mode).
func knife_chop() -> void:
	if contents.is_empty():
		return
	var f: Food = contents[0]
	game.sfx.play_at("chop", global_position, 0.0, 0.15)
	var tw := knife.create_tween()
	knife.rotation_degrees = Vector3(0, 35, -22)
	tw.tween_property(knife, "rotation_degrees", Vector3(0, 35, 4), 0.06)
	tw.tween_property(knife, "rotation_degrees", Vector3(0, 35, -22), 0.14)
	var bits := Models.particles("burst")
	bits.amount = 10
	bits.lifetime = 0.5
	bits.initial_velocity_max = 1.1
	bits.scale_amount_max = 0.016
	var col := Color(DB.ING[f.data["id"]][4])
	bits.color_ramp.set_color(0, col)
	bits.color_ramp.set_color(1, Color(col, 0.0))
	bits.position = hold.position + Vector3(0, 0.05, 0)
	add_child(bits)
	bits.emitting = true
	get_tree().create_timer(1.2).timeout.connect(bits.queue_free)
	f.pop(1.06)
	game.cam_shake(0.004)


## Applies a finished hand cut: `pieces` chunks (lots of strokes = minced).
func apply_free_cut(pieces: int) -> void:
	if contents.is_empty() or pieces < 2:
		return
	var f: Food = contents[0]
	if pieces >= 18:
		f.data["cut"] = 2
		f.data["style"] = ""
	else:
		f.data["cut"] = 1
		f.data["style"] = "slice" if pieces <= 3 and DB.LOOK.get(f.data["id"], f.data["id"]) in ["bread", "baguette"] else "free"
		f.data["pieces"] = pieces
	_finish_cut(f)


func _finish_cut(f: Food) -> void:
	work = 0
	pending_style = ""
	f.rebuild()
	f.mark_changed()
	f.pop(1.2)
	game.sfx.play_at("pop", global_position, -4.0)
	game.float_text(global_position + Vector3(0, 0.3, 0), f.display_name(), Color(0.7, 0.9, 1.0))
	_hide_bar()


func _chop() -> String:
	if contents.is_empty():
		return "Put something on the board"
	var f: Food = contents[0]
	var cut: int = f.data.get("cut", 0)
	if cut >= DB.cut_max(f.data["id"]):
		return "Can't chop that any more"
	if cut == 0 and DB.has_styles(f.data["id"]) and pending_style == "":
		game.ui.open_cut_menu(self)
		return ""
	work += 1
	knife_chop()
	var need := CHOPS * (2 if pending_style == "mince" else 1)
	if work >= need:
		match pending_style:
			"slice", "dice":
				f.data["cut"] = 1
				f.data["style"] = pending_style
			"mince":
				f.data["cut"] = 2
				f.data["style"] = ""
			_:
				f.data["cut"] = cut + 1
				f.data["style"] = ""
		_finish_cut(f)
		return ""
	_set_bar(float(work) / need, Color(0.45, 0.75, 1.0), String(use_label()))
	return ""


func _whisk() -> String:
	if contents.is_empty():
		return "Put ingredients in the bowl"
	work += 1
	game.sfx.play_at("whisk", global_position, 0.0, 0.2)
	var tw := whisk.create_tween()
	tw.tween_property(whisk, "rotation_degrees:y", whisk.rotation_degrees.y + 140.0, 0.15)
	var tw2 := hold.create_tween()
	tw2.tween_property(hold, "rotation_degrees:y", hold.rotation_degrees.y + 90.0, 0.2).set_trans(Tween.TRANS_SINE)
	for c in contents:
		(c as Food).pop(1.05)
	if work >= WHISKS:
		work = 0
		var datas := []
		for c in contents:
			datas.append(c.data)
		var co := DB.coat(datas)
		if not (co["coated"] as Array).is_empty():
			# breading station: coated pieces stay separate, leftovers mix as usual
			var res2 := DB.apply_rules("mix", co["rest"])
			var left: Array = res2["made"] + res2["rest"]
			_replace(co["coated"] + ([DB.merge(left, "mix")] if not left.is_empty() else []))
		else:
			var res := DB.apply_rules("mix", datas)
			var items: Array = res["made"] + res["rest"]
			_replace([DB.merge(items, "mix")])
		game.sfx.play_at("sparkle", global_position, -4.0)
		_burst("sparkle")
		game.float_text(global_position + Vector3(0, 0.35, 0), (contents[0] as Food).display_name(), Color(1, 0.9, 0.55))
		_hide_bar()
		return ""
	_set_bar(float(work) / WHISKS, Color(1.0, 0.75, 0.4), "Whisk")
	return ""


func _replace(datas: Array) -> void:
	for c in contents:
		c.queue_free()
	contents.clear()
	for d in datas:
		var f := Food.make(d)
		hold.add_child(f)
		f.set_carried(true)
		contents.append(f)
		f.pop(1.3)
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
	var side := kind in ["microwave", "fridge"]
	tw.tween_property(door, "rotation_degrees:y" if side else "rotation_degrees:x", (-100.0 if side else 80.0) if open else 0.0, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if not open:
		game.sfx.play_at("door_close", global_position, -4.0)
	else:
		game.sfx.play_at("door_open", global_position, -6.0)


func bump() -> void:
	match kind:
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
		"pan", "pot", "fryer", "oven", "grill", "microwave", "toaster":
			_tick_cook(delta)
		"fridge":
			_tick_cold(delta)


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
		_hide_bar()
		return
	var lowest := 9.0
	for c in dirty:
		var f: Food = c
		var w: float = f.data.get("wash_t", 0.0) + delta
		f.data["wash_t"] = w
		f.position.y = sin(t * 8.0 + w) * 0.008
		f.rotation.y += delta * 2.0
		lowest = minf(lowest, w)
		if w >= WASH_TIME:
			for l in DB.leaves(f.data):
				l["washed"] = true
			f.data.erase("wash_t")
			f.refresh_tint()
			f.mark_changed()
			f.pop(1.2)
			game.sfx.play_at("sparkle", global_position, -8.0)
			_burst("sparkle")
	_set_bar(lowest / WASH_TIME, Color(0.4, 0.85, 1.0), "Washing")


func _tick_blender(delta: float) -> void:
	if not running:
		jar.position.x = 0.0
		return
	run_t += delta
	jar.position.x = sin(t * 70.0) * 0.003
	hold.rotation.y += delta * 30.0
	for c in contents:
		(c as Food).position.y = absf(sin(t * 25.0 + c.get_index())) * 0.04
	_set_bar(run_t / BLEND_TIME, Color(0.95, 0.5, 0.85), "Blending")
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
		game.sfx.play_at("ding", global_position, -4.0)
		_burst("sparkle")
		game.float_text(global_position + Vector3(0, 0.6, 0), (contents[0] as Food).display_name(), Color(1, 0.65, 0.9))
		_hide_bar()


func _heat(on: bool) -> void:
	if flame:
		flame.visible = on
	if glow:
		glow.light_energy = (0.5 + sin(t * 20.0) * 0.06) if on else 0.0
	if loop:
		if on and not loop.playing:
			loop.play()
		elif not on and loop.playing:
			loop.stop()
	for k in ["sizzle", "steam", "bubbles"]:
		if fx.has(k):
			(fx[k] as CPUParticles3D).emitting = on
	if kind == "oven":
		liquid_mat.emission_energy_multiplier = 2.5 if on else 0.0
	if kind == "fryer":
		liquid_mat.emission_energy_multiplier = 0.25 if on else 0.0
	if kind in ["grill", "toaster"]:
		liquid_mat.emission_energy_multiplier = 2.2 if on else 0.0
	if not on and fx.has("smoke"):
		(fx["smoke"] as CPUParticles3D).emitting = false


func _tick_cook(delta: float) -> void:
	if contents.is_empty() or (kind in ["oven", "microwave"] and door_open):
		_heat(false)
		return
	if kind == "toaster" and popped:
		_heat(false)
		_set_bar(1.0, Color(0.4, 0.95, 0.5), "Popped!")
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
		if kind == "toaster":
			popped = true
			game.sfx.play_at("pop", global_position, 0.0)
			for c in contents:
				var tw := (c as Food).create_tween()
				tw.tween_property(c, "position:y", 0.09, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
				tw.tween_property(c, "position:y", 0.05, 0.2)
	if fx.has("smoke"):
		(fx["smoke"] as CPUParticles3D).emitting = can_burn and max_p > 1.45
	if any_burnt:
		_set_bar(1.0, Color(0.25, 0.22, 0.2), "Burnt")
	elif max_p > 1.45 and can_burn:
		var flash := Color(1, 0.25, 0.15) if fmod(t, 0.4) < 0.2 else Color(1, 0.55, 0.15)
		_set_bar((max_p - 1.45) / 0.55, flash, "Burning - take it off!")
		warn_t -= delta
		if warn_t <= 0.0:
			warn_t = 0.45
			game.sfx.play_at("beep", global_position, -10.0, 0.0)
	elif min_p >= 1.0:
		_set_bar(1.0, Color(0.4, 0.95, 0.5), "Ready")
	else:
		_set_bar(min_p, Color(1.0, 0.78, 0.35), "%s %d%%" % [_verb(), int(min_p * 100)])


func _verb() -> String:
	return {"fry": "Frying", "boil": "Boiling", "bake": "Baking", "deepfry": "Frying", "grill": "Grilling",
		"microwave": "Zapping", "toast": "Toasting"}[method]


## Fridge: chills, then (if left in) freezes. Never burns.
func _tick_cold(delta: float) -> void:
	if contents.is_empty() or door_open:
		_hide_bar()
		return
	var min_p := 99.0
	for c in contents:
		var f: Food = c
		var changed := false
		for l in DB.leaves(f.data):
			if l.get("pm", "") != "chill":
				l["pm"] = "chill"
				l["prog"] = 0.0
			var p: float = minf(l["prog"] + delta / DB.cook_time(l, "chill"), 2.05)
			l["prog"] = p
			var want: String = "freeze" if p >= 2.0 else ("chill" if p >= 1.0 else l.get("cold", ""))
			if want != l.get("cold", ""):
				l["cold"] = want
				changed = true
			min_p = minf(min_p, p)
		if changed:
			f.mark_changed()
	if min_p >= 1.0 and not done_once:
		done_once = true
		_cold_rules("chill")
	if min_p >= 2.0 and not frozen_once:
		frozen_once = true
		_cold_rules("freeze")
	if min_p >= 2.0:
		_set_bar(1.0, Color(0.6, 0.85, 1.0), "Frozen")
	elif min_p >= 1.0:
		_set_bar(min_p - 1.0, Color(0.55, 0.8, 1.0), "Chilled - freezing %d%%" % int((min_p - 1.0) * 100))
	else:
		_set_bar(min_p, Color(0.7, 0.9, 1.0), "Chilling %d%%" % int(min_p * 100))


func _cold_rules(m: String) -> void:
	var datas := []
	for c in contents:
		datas.append(c.data)
	var res := DB.apply_rules(m, datas)
	if not (res["made"] as Array).is_empty():
		_replace(res["made"] + res["rest"])
		for c in contents:
			for l in DB.leaves((c as Food).data):
				l["pm"] = "chill"
				l["prog"] = 2.05 if m == "freeze" else 1.0
		game.float_text(global_position + Vector3(0, 0.5, 0), (contents[0] as Food).display_name(), Color(0.7, 0.9, 1.0))
		_burst("sparkle")
		game.sfx.play_at("sparkle", global_position, -4.0)
	game.sfx.play_at("ding", global_position, -6.0)


func _animate_cooking(delta: float) -> void:
	match kind:
		"pan":
			toss_t += delta
			if toss_t > 2.8:
				toss_t = 0.0
				for c in contents:
					var f: Food = c
					var tw := f.create_tween()
					tw.tween_property(f, "position:y", 0.1 + randf() * 0.05, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
					tw.parallel().tween_property(f, "rotation:y", f.rotation.y + PI, 0.36)
					tw.tween_property(f, "position:y", 0.0, 0.18).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				var ptw := pan_node.create_tween()
				ptw.tween_property(pan_node, "rotation_degrees:z", -5.0, 0.1)
				ptw.tween_property(pan_node, "rotation_degrees:z", 0.0, 0.3).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
				(fx["sizzle"] as CPUParticles3D).restart()
				game.sfx.play_at("sizzle_hit", global_position, -8.0)
		"microwave":
			hold.rotation.y += delta * 1.4
		"grill":
			toss_t += delta
			if toss_t > 3.2:
				toss_t = 0.0
				for c in contents:
					var f: Food = c
					var tw := f.create_tween()
					tw.tween_property(f, "position:y", 0.06, 0.14)
					tw.parallel().tween_property(f, "rotation:z", f.rotation.z + PI, 0.28)
					tw.tween_property(f, "position:y", 0.0, 0.14)
					tw.tween_property(f, "rotation:z", 0.0, 0.0)
				(fx["sizzle"] as CPUParticles3D).restart()
				game.sfx.play_at("sizzle_hit", global_position, -8.0)
		"pot", "fryer":
			var i := 0
			for c in contents:
				var f: Food = c
				f.position.y = sin(t * 3.0 + i * 1.7) * 0.008
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
				liquid_mat.albedo_color = Color(0.55, 0.68, 0.75, 0.75).lerp(Color(avg, 0.95), clampf(p, 0.0, 1.0) * 0.7)


func _transform() -> void:
	var datas := []
	for c in contents:
		datas.append(c.data)
	var res := DB.apply_rules(method, datas)
	if not (res["made"] as Array).is_empty():
		_replace(res["made"] + res["rest"])
		var f: Food = contents[0]
		game.float_text(global_position + Vector3(0, 0.45, 0), f.display_name(), Color(1, 0.85, 0.45))
		_burst("sparkle")
		game.sfx.play_at("sparkle", global_position, -4.0)
	game.sfx.play_at("ding", global_position, -4.0)


func status_text() -> String:
	if contents.is_empty():
		match kind:
			"plates": return "Grab a clean plate"
			"trash": return "Throw things away"
			"serve": return "Serve finished dishes here"
		return "Empty"
	var names := []
	for c in contents:
		names.append((c as Food).display_name())
	return ", ".join(names)
