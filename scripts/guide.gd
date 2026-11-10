class_name Guide
extends Node3D
## Teach-me mode: turns a recipe into an ordered list of steps and points big
## green arrows at where to go next (the shelf to grab from, the station to put
## it in, the plate, the serving pass). Steps tick over on their own when the
## player does them; N / B skip forward and back, X stops.

const GREEN := Color(0.25, 1.0, 0.4)
const TRAIL := 18
const TRAIL_GAP := 0.45

var game: Node
var steps: Array = []
var idx := 0
var title := ""
var _t := 0.0
var _snap := 0
var _held_at_start: Object = null
var _arrow: Node3D
var _trail: Array = []
var _panel: PanelContainer
var _head: Label
var _count: Label
var _text: Label
var _pointer: Pointer
var _sources := {}


func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = GREEN
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.no_depth_test = true
	mat.render_priority = 10
	_arrow = Node3D.new()
	add_child(_arrow)
	var shaft := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.04
	sm.bottom_radius = 0.04
	sm.height = 0.24
	shaft.mesh = sm
	shaft.position.y = 0.28
	_arrow.add_child(shaft)
	var head := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.11
	hm.bottom_radius = 0.0
	hm.height = 0.18
	head.mesh = hm
	head.position.y = 0.09
	_arrow.add_child(head)
	for mi in [shaft, head]:
		(mi as MeshInstance3D).material_override = mat
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0
	cm.bottom_radius = 0.08
	cm.height = 0.16
	cm.radial_segments = 3
	for i in TRAIL:
		var c := MeshInstance3D.new()
		c.mesh = cm
		c.material_override = mat
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(c)
		_trail.append(c)
	_build_hud()
	visible = false


func _build_hud() -> void:
	var ui: UI = game.ui
	_pointer = Pointer.new()
	_pointer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.hud.add_child(_pointer)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override("panel", ui._style(Color(0.05, 0.12, 0.07, 0.9), 14, Color(GREEN, 0.6), 2, 16))
	_panel.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_panel.position = Vector2(18, -60)
	_panel.custom_minimum_size = Vector2(340, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.hud.add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	_panel.add_child(v)
	_head = ui._label("", 15, Color(GREEN, 0.9), UI.bold_font())
	v.add_child(_head)
	_count = ui._label("", 13, Color(1, 1, 1, 0.6))
	v.add_child(_count)
	_text = ui._label("", 20, Color(1, 1, 1), UI.bold_font())
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(320, 0)
	v.add_child(_text)
	v.add_child(ui._label("N  next      B  back      X  stop", 13, Color(1, 1, 1, 0.5)))
	_panel.visible = false


func active() -> bool:
	return not steps.is_empty()


# ================================================================ planning

## Guide through cooking recipe k from scratch.
func teach(k: int) -> void:
	_index_sources()
	var plan := []
	for sp in DB.recipe(k)["specs"]:
		var alt := _pick(sp)
		if alt.is_empty():
			continue
		_prepare(plan, alt, sp, 0)
		plan.append({"do": "plate", "text": "Put it on a plate"})
	plan.append({"do": "serve", "text": "Take the plate to the Serving Pass"})
	_begin("Teaching: " + DB.display_name(k), plan)


## Point at the shelf/crate/fridge spot where an ingredient lives.
func show_where(id: String) -> void:
	_index_sources()
	if not _sources.has(id):
		game.toast("%s is made in the kitchen, not kept on a shelf" % DB.ING[id][0])
		return
	_begin("Finding: " + DB.ING[id][0], [{"do": "grab", "id": id, "text": "%s is here - grab it" % DB.ING[id][0]}])


func stop() -> void:
	steps.clear()
	visible = false
	_panel.visible = false
	_pointer.target_on = false
	_pointer.queue_redraw()


func _begin(t: String, plan: Array) -> void:
	title = t
	steps = plan
	idx = 0
	visible = true
	_panel.visible = true
	_enter()
	game.sfx.play("bell", -8.0)


func _index_sources() -> void:
	_sources.clear()
	for s in game.kitchen.sources:
		if not _sources.has((s as Source).id):
			_sources[(s as Source).id] = s


func _pick(sp: Dictionary) -> Dictionary:
	for alt in sp["alts"]:
		var id: String = alt["id"]
		if id != "" and (_sources.has(id) or DB._how.has(id)):
			return alt
	for alt in sp["alts"]:
		for id in _sources:
			if alt["any"] or (alt["cats"] as Array).has(DB.ING[id][1]):
				var a: Dictionary = alt.duplicate()
				a["id"] = id
				return a
	return {}


static func station_for(method: String) -> String:
	match method:
		"mix": return "bowl"
		"blend": return "blender"
		"freeze": return "fridge"
	for k in Station.METHOD:
		if Station.METHOD[k] == method:
			return k
	return "pan"


## How to make an intermediate: the dedicated appliance if there is one
## (toast in the toaster), otherwise the book's usual rule.
static func _rule_for(id: String) -> Array:
	for r in DB.RULES:
		if r[2] == id and r[0] == id:
			return r
	return DB._how[id]


## Steps that end with the ingredient (prepared as the spec asks) in your hand.
func _prepare(plan: Array, alt: Dictionary, sp: Dictionary, depth: int) -> void:
	var id: String = alt["id"]
	var nm: String = DB.ING[id][0]
	if _sources.has(id):
		plan.append({"do": "grab", "id": id, "text": "Grab the " + nm})
	elif DB._how.has(id) and depth < 4:
		var r := _rule_for(id)
		var kind := station_for(r[0])
		var slot := {}
		for s in r[1]:
			var sp2 := DB.parse(s)
			var a2 := _pick(sp2)
			if a2.is_empty():
				continue
			_prepare(plan, a2, sp2, depth + 1)
			plan.append({"do": "put", "kind": kind, "slot": slot, "text": "Put it in the " + Station.NAMES[kind]})
		var verb: String = {"mix": "Press F to whisk it into ", "blend": "Press F to blend it into "}.get(r[0], "Wait while it turns into ")
		plan.append({"do": "work", "kind": kind, "slot": slot, "how": r[0], "out": id, "text": verb + nm})
		plan.append({"do": "take", "kind": kind, "slot": slot, "text": "Take the %s out (E)" % nm})
	else:
		plan.append({"do": "note", "text": "Find some " + nm})
	if _sources.has(id) and DB.flag(id, "d"):
		var ws := {}
		plan.append({"do": "put", "kind": "sink", "slot": ws, "text": "Put it in the Sink to wash it"})
		plan.append({"do": "work", "kind": "sink", "slot": ws, "how": "wash", "text": "Wait for it to be washed"})
		plan.append({"do": "take", "kind": "sink", "slot": ws, "text": "Take it out of the Sink"})
	var cut := int(alt["cut"])
	if cut > 0:
		var bs := {}
		var word: String = DB.CUT_VERB.get(DB.cut_word(id, cut), "chop")
		if alt["style"] != "":
			word = {"slice": "slice", "dice": "dice", "free": "cut"}[alt["style"]]
		if cut >= 3:
			word = "blend"
		plan.append({"do": "put", "kind": "board", "slot": bs, "text": "Put it on a Chopping Board"})
		plan.append({"do": "work", "kind": "board", "slot": bs, "how": "cut", "cut": mini(cut, DB.cut_max(id)),
			"text": "Press F to %s it%s" % [word, " (pick %s)" % alt["style"] if alt["style"] != "" else ""]})
		plan.append({"do": "take", "kind": "board", "slot": bs, "text": "Pick it up off the board"})
	if alt["coat"]:
		var cs := {}
		plan.append({"do": "put", "kind": "bowl", "slot": cs, "text": "Put it in the Mixing Bowl"})
		plan.append({"do": "grab", "id": "breadcrumbs", "text": "Grab the Breadcrumbs"})
		plan.append({"do": "put", "kind": "bowl", "slot": cs, "text": "Add them to the Mixing Bowl"})
		plan.append({"do": "work", "kind": "bowl", "slot": cs, "how": "coat", "text": "Press F to bread it"})
		plan.append({"do": "take", "kind": "bowl", "slot": cs, "text": "Take it out of the bowl"})
	var methods: Array = sp["m"]
	if not sp["raw"] and (sp["any_cook"] or not methods.is_empty()):
		var m: String = methods[0] if not methods.is_empty() else "fry"
		var kind := station_for(m)
		var ks := {}
		plan.append({"do": "put", "kind": kind, "slot": ks, "text": "Put it in the " + Station.NAMES[kind]})
		plan.append({"do": "work", "kind": kind, "slot": ks, "how": m,
			"text": "Wait until it's done (bar goes green) - don't let it burn"})
		plan.append({"do": "take", "kind": kind, "slot": ks, "text": "Take it out (E)"})


# ================================================================ running

func _process(delta: float) -> void:
	if steps.is_empty():
		return
	if game.mode != "sandbox" and game.mode != "orders":
		stop()
		return
	_t += delta
	if _is_done(steps[idx]):
		_advance(1)
		if steps.is_empty():
			return
	var pos = _target_pos_for(steps[idx])
	_pointer.target_on = pos != null
	if pos == null:
		_arrow.visible = false
		for c in _trail:
			(c as Node3D).visible = false
		_pointer.queue_redraw()
		return
	var p: Vector3 = pos
	_arrow.visible = true
	_arrow.global_position = p + Vector3(0, 0.08 + absf(sin(_t * 4.0)) * 0.1, 0)
	_arrow.rotation.y = _t * 2.0
	# grow with distance so it reads from across the kitchen, shrink up close
	var far := clampf(p.distance_to(game.player.cam.global_position) / 2.5, 0.6, 1.8)
	_arrow.scale = Vector3.ONE * far * (1.0 + 0.08 * sin(_t * 8.0))
	_layout_trail(p)
	_pointer.cam = game.player.cam
	_pointer.target = p + Vector3(0, 0.2, 0)
	_pointer.queue_redraw()


func _layout_trail(p: Vector3) -> void:
	var from: Vector3 = game.player.global_position
	var to := Vector3(p.x, 0.0, p.z)
	from.y = 0.0
	var d := to - from
	var dist := d.length()
	if dist < 0.9:
		for c in _trail:
			(c as Node3D).visible = false
		return
	var dir := d / dist
	var rot := Basis.looking_at(dir, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2) * Basis.from_scale(Vector3(1.0, 1.0, 0.3))
	var shift := fmod(_t * 0.9, TRAIL_GAP)
	for i in TRAIL:
		var c: MeshInstance3D = _trail[i]
		var along := 0.5 + i * TRAIL_GAP + shift
		c.visible = along < dist - 0.4
		if c.visible:
			c.global_transform = Transform3D(rot, from + dir * along + Vector3(0, 0.03, 0))


func _advance(by: int) -> void:
	idx += by
	if idx >= steps.size():
		game.toast("Done! That's how you make it." if steps.size() > 1 else "Got it!")
		game.sfx.play("fanfare", -8.0)
		stop()
		return
	idx = maxi(idx, 0)
	_enter()
	if by > 0:
		game.sfx.play("pop", -10.0)


func skip(by: int) -> void:
	if active():
		_advance(by)


func on_served() -> void:
	if active() and steps[idx]["do"] == "serve":
		_advance(1)


func _enter() -> void:
	var s: Dictionary = steps[idx]
	_head.text = title
	_count.text = "Step %d of %d" % [idx + 1, steps.size()]
	_text.text = s["text"]
	_held_at_start = game.player.held
	_snap = 0
	match s["do"]:
		"put":
			var st := _station(s)
			_snap = st.contents.size() if st else 0
		"plate":
			_snap = _plate_leaves()


func _station(s: Dictionary) -> Station:
	var slot: Dictionary = s.get("slot", {})
	if slot.has("st") and is_instance_valid(slot["st"]):
		return slot["st"]
	var best: Station = null
	var bd := INF
	for st in game.kitchen.stations:
		var station: Station = st
		if station.kind != s["kind"]:
			continue
		var d := station.global_position.distance_to(game.player.global_position)
		if s["do"] == "put" and not station.contents.is_empty() and station.kind == "board":
			d += 100.0
		if d < bd:
			bd = d
			best = station
	return best


func _plates() -> Array:
	var out := []
	for c in game.items.get_children():
		if c is Plate and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _plate_leaves() -> int:
	var n := 0
	for p in _plates():
		n += (p as Plate).leaves().size()
	return n


func _is_done(s: Dictionary) -> bool:
	var held: RigidBody3D = game.player.held
	match s["do"]:
		"grab":
			return held is Food and _has_leaf((held as Food).data, s["id"])
		"take":
			return held is Food and held != _held_at_start
		"put":
			var st := _station(s)
			if st and st.contents.size() > _snap:
				s["slot"]["st"] = st
				return true
			_snap = st.contents.size() if st else 0
			return false
		"plate":
			return _plate_leaves() > _snap
		"work":
			return _work_done(s)
	return false


func _work_done(s: Dictionary) -> bool:
	var st := _station(s)
	if st == null or st.contents.is_empty():
		return false
	match s["how"]:
		"wash":
			for c in st.contents:
				if (c as Food).needs_wash():
					return false
			return true
		"cut":
			for c in st.contents:
				if int((c as Food).data.get("cut", 0)) >= int(s["cut"]):
					return true
			return false
		"coat":
			for c in st.contents:
				for l in DB.leaves((c as Food).data):
					if String(l.get("coat", "")) != "":
						return true
			return false
		"mix", "blend":
			if st.running:
				return false
			for c in st.contents:
				if _has_leaf((c as Food).data, s.get("out", "")):
					return true
			return false
	if st.done_once or st.frozen_once:
		return true
	for c in st.contents:
		if s.has("out") and _has_leaf((c as Food).data, s["out"]):
			return true
	return false


func _has_leaf(d: Dictionary, id: String) -> bool:
	if d.get("id", "") == id:
		return true
	for l in DB.leaves(d):
		if l.get("id", "") == id:
			return true
	return false


## Where the arrow points for this step (null = nowhere in particular).
func _target_pos_for(s: Dictionary) -> Variant:
	match s["do"]:
		"grab":
			var src: Source = _sources.get(s["id"])
			if src:
				return src.global_position + Vector3(0, src.slot.y + 0.05, 0)
		"put", "work", "take":
			var st := _station(s)
			if st:
				return st.global_position + Vector3(0, st._bar_height() + 0.25, 0)
		"plate":
			var held: RigidBody3D = game.player.held
			if held is Plate:
				return null
			var best: Plate = null
			var most := -1
			for p in _plates():
				var n := (p as Plate).leaves().size()
				if n > most:
					most = n
					best = p
			if best:
				return best.global_position + Vector3(0, 0.12, 0)
			var ps := game._station("plates") as Station
			return ps.global_position + Vector3(0, 0.4, 0)
		"serve":
			var sv := game._station("serve") as Station
			return sv.global_position + Vector3(0, 0.45, 0)
	return null


## Green edge-of-screen arrow when the target is off screen or behind you.
class Pointer extends Control:
	var cam: Camera3D
	var target := Vector3.ZERO
	var target_on := false

	func _draw() -> void:
		if not target_on or cam == null:
			return
		var vp := get_viewport_rect().size
		var behind := cam.is_position_behind(target)
		var sp := cam.unproject_position(target)
		var margin := 60.0
		var rect := Rect2(Vector2(margin, margin), vp - Vector2(margin, margin) * 2)
		if not behind and rect.has_point(sp):
			return
		var c := vp / 2
		var d := sp - c
		if behind:
			d = -d
			if d.length() < 1.0:
				d = Vector2(0, 1)
		var s := minf(absf((rect.size.x / 2) / maxf(absf(d.x), 0.001)), absf((rect.size.y / 2) / maxf(absf(d.y), 0.001)))
		var p := c + d * s
		var dir := d.normalized()
		var side := Vector2(-dir.y, dir.x)
		var pts := PackedVector2Array([p + dir * 26, p - dir * 14 + side * 22, p - dir * 14 - side * 22])
		draw_colored_polygon(pts, Color(0.25, 1.0, 0.4, 0.95))
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), Color(0, 0.25, 0.05, 0.9), 3.0, true)
