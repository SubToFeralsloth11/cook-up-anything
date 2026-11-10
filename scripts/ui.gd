class_name UI
extends CanvasLayer
## All 2D interface: HUD, prompts, order tickets, recipe book, review cards, menus.

const ACCENT := Color(1.0, 0.74, 0.36)
const GOOD := Color(0.47, 0.9, 0.55)
const BAD := Color(1.0, 0.45, 0.4)
const INK := Color(0.16, 0.12, 0.09)
const WHERE := "Where things are:  Produce - market crates by the door   |   Meat, fish & dairy - glass fridge   |   Dry goods, bread & sauces - pantry shelves   |   Spices - shelf by the blender"

static var _fonts := {}

var game: Node
var theme := Theme.new()
var root := Control.new()
var hud := Control.new()
var look_lbl: Label
var sub_lbl: Label
var keys_box: HBoxContainer
var held_lbl: Label
var toast_lbl: Label
var info_lbl: Label
var timer_lbl: Label
var money_lbl: Label
var orders_box: VBoxContainer
var cross: Control
var modal := ""
var panels := {}
var book_text: RichTextLabel
var book_search: LineEdit
var book_title: Label
var card: PanelContainer
var card_vbox: VBoxContainer
var confetti: CPUParticles2D
var menu_stats: Label
var results_lbl: Label
var quality_buttons: Array = []
var _toast_tw: Tween
var _card_tw: Tween
var _prompt_key := ""


# ================================================================ fonts

static func _sys(key: String, names: Array, weight: int, italic := false) -> Font:
	if not _fonts.has(key):
		var f := SystemFont.new()
		f.font_names = PackedStringArray(names)
		f.font_weight = weight
		f.font_italic = italic
		f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
		f.hinting = TextServer.HINTING_LIGHT
		f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
		_fonts[key] = f
	return _fonts[key]


static func body_font() -> Font:
	return _sys("body", ["Avenir Next", "Helvetica Neue", "Segoe UI", "Roboto", "Arial"], 500)


static func bold_font() -> Font:
	return _sys("bold", ["Avenir Next", "Helvetica Neue", "Segoe UI", "Roboto", "Arial"], 700)


static func title_font() -> Font:
	return _sys("title", ["Futura", "Avenir Next Condensed", "Avenir Next", "Segoe UI Black", "Arial Black"], 800)


static func hand_font() -> Font:
	return _sys("hand", ["Chalkboard SE", "Bradley Hand", "Marker Felt", "Segoe Print", "Comic Sans MS"], 400)


static func mono_font() -> Font:
	return _sys("mono", ["Courier New", "Menlo", "Consolas", "Courier"], 600)


# ================================================================ setup

func _ready() -> void:
	layer = 5
	_make_theme()
	root.theme = theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	_build_hud()
	_build_card()
	_build_book()
	_build_menu()
	_build_pause()
	_build_results()
	confetti = CPUParticles2D.new()
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 160
	confetti.lifetime = 2.6
	confetti.explosiveness = 0.9
	confetti.direction = Vector2(0, -1)
	confetti.spread = 75
	confetti.initial_velocity_min = 350
	confetti.initial_velocity_max = 750
	confetti.gravity = Vector2(0, 700)
	confetti.angular_velocity_min = -500
	confetti.angular_velocity_max = 500
	confetti.scale_amount_min = 5
	confetti.scale_amount_max = 10
	var hue := Gradient.new()
	hue.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	hue.colors = PackedColorArray([Color(1, 0.35, 0.4), Color(1, 0.82, 0.3), Color(0.35, 0.85, 0.55), Color(0.35, 0.6, 1), Color(0.9, 0.45, 1)])
	confetti.color_initial_ramp = hue
	root.add_child(confetti)


func _style(bg: Color, radius := 12, border := Color(0, 0, 0, 0), bw := 0, pad := 14) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = pad
	s.content_margin_right = pad
	s.content_margin_top = pad * 0.7
	s.content_margin_bottom = pad * 0.7
	s.anti_aliasing = true
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s


func _make_theme() -> void:
	theme.default_font = body_font()
	theme.default_font_size = 18
	theme.set_stylebox("panel", "PanelContainer", _style(Color(0.08, 0.07, 0.07, 0.94), 16, Color(1, 1, 1, 0.07), 1, 20))
	var normal := _style(Color(1, 1, 1, 0.06), 10, Color(1, 1, 1, 0.12), 1)
	theme.set_stylebox("normal", "Button", normal)
	theme.set_stylebox("hover", "Button", _style(ACCENT, 10))
	theme.set_stylebox("pressed", "Button", _style(ACCENT.darkened(0.2), 10))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), 10, ACCENT, 2))
	theme.set_color("font_color", "Button", Color(0.95, 0.93, 0.9))
	theme.set_color("font_hover_color", "Button", INK)
	theme.set_color("font_pressed_color", "Button", INK)
	theme.set_font("font", "Button", bold_font())
	theme.set_stylebox("normal", "LineEdit", _style(Color(1, 1, 1, 0.07), 10))
	theme.set_stylebox("focus", "LineEdit", _style(Color(1, 1, 1, 0.1), 10, ACCENT, 2))
	theme.set_stylebox("background", "ProgressBar", _style(Color(0, 0, 0, 0.18), 4, Color(0, 0, 0, 0), 0, 0))
	theme.set_stylebox("fill", "ProgressBar", _style(GOOD, 4, Color(0, 0, 0, 0), 0, 0))


func _label(text: String, size := 18, col := Color(1, 1, 1), font: Font = null, outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if font:
		l.add_theme_font_override("font", font)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable, size := 20, min_w := 280) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 50)
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		game.sfx.play("click")
		cb.call())
	b.mouse_entered.connect(func(): game.sfx.play("click", -16.0))
	return b


func _center_panel(n: String, min_size: Vector2) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.5)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.add_child(cc)
	var pc := PanelContainer.new()
	pc.custom_minimum_size = min_size
	cc.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pc.add_child(v)
	dim.visible = false
	panels[n] = dim
	return v


# ================================================================ HUD

func _build_hud() -> void:
	cross = Crosshair.new()
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cross)
	var mid := VBoxContainer.new()
	mid.set_anchors_preset(Control.PRESET_CENTER)
	mid.position = Vector2(-450, 26)
	mid.custom_minimum_size = Vector2(900, 0)
	mid.add_theme_constant_override("separation", 2)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mid)
	look_lbl = _label("", 24, Color(1, 1, 1), bold_font(), 7)
	look_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(look_lbl)
	sub_lbl = _label("", 16, Color(1, 0.92, 0.8), body_font(), 6)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(sub_lbl)
	keys_box = HBoxContainer.new()
	keys_box.alignment = BoxContainer.ALIGNMENT_CENTER
	keys_box.add_theme_constant_override("separation", 18)
	keys_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(keys_box)
	held_lbl = _label("", 19, ACCENT, bold_font(), 7)
	held_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	held_lbl.position = Vector2(-450, -84)
	held_lbl.custom_minimum_size = Vector2(900, 30)
	held_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(held_lbl)
	toast_lbl = _label("", 21, Color(1, 1, 1), bold_font(), 8)
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER)
	toast_lbl.position = Vector2(-450, 150)
	toast_lbl.custom_minimum_size = Vector2(900, 30)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_lbl.modulate.a = 0.0
	hud.add_child(toast_lbl)
	var help := _label("E / Left click  grab & place      F / Right click  chop, whisk, blend      Q  throw      Tab  recipes      Shift  run      Esc  pause", 13, Color(1, 1, 1, 0.55), body_font(), 4)
	help.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help.position = Vector2(18, -30)
	hud.add_child(help)
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-400, 16)
	tr.custom_minimum_size = Vector2(384, 0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tr)
	money_lbl = _label("", 34, Color(0.62, 0.95, 0.62), title_font(), 8)
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(money_lbl)
	timer_lbl = _label("", 22, Color(1, 1, 1), bold_font(), 7)
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(timer_lbl)
	info_lbl = _label("", 15, Color(1, 1, 1, 0.8), body_font(), 5)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(info_lbl)
	orders_box = VBoxContainer.new()
	orders_box.position = Vector2(16, 16)
	orders_box.add_theme_constant_override("separation", 10)
	orders_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(orders_box)
	hud.visible = false


class Crosshair:
	extends Control
	var active := false

	func _draw() -> void:
		if active:
			draw_arc(Vector2.ZERO, 9.0, 0, TAU, 32, Color(1, 0.8, 0.45, 0.95), 2.0, true)
			draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 1, 0.95))
		else:
			draw_circle(Vector2.ZERO, 2.5, Color(1, 1, 1, 0.75))


func show_hud(on: bool) -> void:
	hud.visible = on


func _key_chip(key: String, text: String, col: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 7)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", _style(col, 6, Color(0, 0, 0, 0.35), 1, 7))
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(_label(key, 14, INK, bold_font()))
	h.add_child(pc)
	h.add_child(_label(text, 18, Color(1, 1, 1), bold_font(), 6))
	return h


func update_prompt(p: Player) -> void:
	var t: Dictionary = p.target
	var held: RigidBody3D = p.held
	var title := ""
	var sub := ""
	var e := ""
	var f := ""
	var kind: String = t.get("kind", "")
	var node = t.get("node")
	match kind:
		"source":
			var src: Source = node
			title = src.title()
			if held == null:
				e = "Grab"
			elif held is Food and (held as Food).data.get("id") == src.id and (held as Food).data.get("cut", 0) == 0 and not (held as Food).data.get("cooked", false):
				e = "Put back"
			else:
				sub = "Hands full"
		"food":
			var fd: Food = node
			title = fd.display_name()
			if fd.needs_wash():
				sub = "Muddy - rinse it in the sink"
			e = "Pick up" if held == null else ("Add to plate" if held is Plate else "Place")
		"plate":
			var pl: Plate = node
			title = pl.display_name()
			e = "Pick up plate" if held == null else ("Add to plate" if held is Food else "Place")
		"station":
			var st: Station = node
			title = st.title()
			sub = st.status_text()
			if held == null:
				match st.kind:
					"plates": e = "Take a plate"
					"trash", "serve": e = ""
					_: e = "Take out" if not st.contents.is_empty() and not st.running else ""
			elif held is Food:
				match st.kind:
					"trash": e = "Bin it"
					"serve": e = "Serve"
					"plates": e = ""
					_:
						var why := st.accepts(held)
						if why == "":
							e = "Put in"
						else:
							sub = why
			else:
				match st.kind:
					"trash": e = "Scrape plate" if not (held as Plate).items.is_empty() else "Bin plate"
					"serve": e = "Serve"
					"plates": e = "Put plate back" if (held as Plate).items.is_empty() else ""
					_: e = "Scoop onto plate" if not st.contents.is_empty() else ""
			f = st.use_label()
		"surface":
			if held:
				e = "Place"
	(cross as Crosshair).active = e != "" or f != ""
	cross.queue_redraw()
	if look_lbl.text != title:
		look_lbl.text = title
	if sub_lbl.text != sub:
		sub_lbl.text = sub
	var key := e + "|" + f + "|" + str(held != null)
	if key != _prompt_key:
		_prompt_key = key
		for c in keys_box.get_children():
			c.queue_free()
		if e != "":
			keys_box.add_child(_key_chip("E", e, ACCENT))
		if f != "":
			keys_box.add_child(_key_chip("F", f, Color(0.55, 0.8, 1.0)))
		if held:
			keys_box.add_child(_key_chip("Q", "Throw", Color(0.8, 0.8, 0.8)))
	var hn := ""
	if held:
		hn = "Holding  " + String(held.call("display_name"))
		if held is Food and (held as Food).needs_wash():
			hn += "  (muddy)"
	if held_lbl.text != hn:
		held_lbl.text = hn


func toast(msg: String) -> void:
	toast_lbl.text = msg
	if _toast_tw:
		_toast_tw.kill()
	toast_lbl.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(2.0)
	_toast_tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.5)


func set_status(money: String, timer: String, info: String) -> void:
	if money_lbl.text != money:
		money_lbl.text = money
	if timer_lbl.text != timer:
		timer_lbl.text = timer
	if info_lbl.text != info:
		info_lbl.text = info


# ================================================================ orders (paper tickets)

func refresh_orders(orders: Array) -> void:
	for c in orders_box.get_children():
		c.queue_free()
	var paper := _style(Color(0.98, 0.96, 0.9), 3, Color(0, 0, 0, 0.12), 1, 12)
	paper.shadow_color = Color(0, 0, 0, 0.35)
	paper.shadow_size = 6
	paper.shadow_offset = Vector2(2, 3)
	var n := 1
	for o in orders:
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(320, 0)
		pc.add_theme_stylebox_override("panel", paper)
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 1)
		pc.add_child(v)
		v.add_child(_label("ORDER #%02d" % (int(o.get("num", n))), 12, Color(0.45, 0.4, 0.35), mono_font()))
		var name_l := _label(DB.display_name(o["k"]).to_upper(), 19, INK, mono_font())
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.custom_minimum_size = Vector2(296, 0)
		v.add_child(name_l)
		var lines: Array = DB.recipe_lines(o["k"])
		for line in lines[0]:
			var ll := _label("- " + line, 13, Color(0.25, 0.22, 0.2), mono_font())
			ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			ll.custom_minimum_size = Vector2(296, 0)
			v.add_child(ll)
		for h in lines[1]:
			var hl := _label("  " + h, 12, Color(0.45, 0.33, 0.55), mono_font())
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.custom_minimum_size = Vector2(296, 0)
			v.add_child(hl)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = 1.0
		bar.value = 1.0
		v.add_child(bar)
		o["bar"] = bar
		o["panel"] = pc
		o["tone"] = -1
		orders_box.add_child(pc)
		pc.modulate.a = 0.0
		pc.position.x = -40
		var tw := pc.create_tween()
		tw.tween_property(pc, "modulate:a", 1.0, 0.25)
		n += 1


var _fills := {}


func update_order_bars(orders: Array) -> void:
	for o in orders:
		if not o.has("bar") or not is_instance_valid(o["bar"]):
			continue
		var bar: ProgressBar = o["bar"]
		var r: float = o["time"] / o["total"]
		bar.value = r
		var tone := 0 if r > 0.5 else (1 if r > 0.25 else 2)
		if tone != int(o["tone"]):
			o["tone"] = tone
			if not _fills.has(tone):
				_fills[tone] = _style([GOOD, ACCENT, BAD][tone], 4, Color(0, 0, 0, 0), 0, 0)
			bar.add_theme_stylebox_override("fill", _fills[tone])
		if tone == 2:
			(o["panel"] as Control).modulate = Color(1, 0.82, 0.8) if fmod(Time.get_ticks_msec() / 250.0, 2.0) < 1.0 else Color(1, 1, 1)


# ================================================================ review card

func _build_card() -> void:
	card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.position = Vector2(-290, 84)
	card.custom_minimum_size = Vector2(580, 0)
	var st := _style(Color(0.99, 0.97, 0.92, 0.98), 18, ACCENT, 3, 22)
	st.shadow_color = Color(0, 0, 0, 0.4)
	st.shadow_size = 18
	card.add_theme_stylebox_override("panel", st)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_vbox = VBoxContainer.new()
	card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)
	card.visible = false
	root.add_child(card)


func show_card(j: Dictionary, is_new: bool, reward: String) -> void:
	for c in card_vbox.get_children():
		c.queue_free()
	if is_new:
		var nl := _label("NEW RECIPE DISCOVERED", 16, Color(0.8, 0.36, 0.12), bold_font())
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(nl)
	var name_l := _label(j["name"], 32, INK, title_font())
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(name_l)
	var stars := Stars.new()
	stars.value = j["stars"]
	stars.custom_minimum_size = Vector2(0, 46)
	card_vbox.add_child(stars)
	for n in j["notes"]:
		var bad: bool = String(n).contains("RAW") or String(n).contains("charcoal") or String(n).contains("dirt")
		var l := _label(n, 16, Color(0.72, 0.2, 0.15) if bad else Color(0.3, 0.42, 0.25), body_font())
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(l)
	if reward != "":
		var r := _label(reward, 22, Color(0.15, 0.52, 0.25), bold_font())
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		card_vbox.add_child(r)
	card.visible = true
	card.pivot_offset = Vector2(290, 60)
	card.scale = Vector2(0.6, 0.6)
	card.modulate.a = 0.0
	if _card_tw:
		_card_tw.kill()
	_card_tw = create_tween()
	_card_tw.set_parallel(true)
	_card_tw.tween_property(card, "scale", Vector2.ONE, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_card_tw.tween_property(card, "modulate:a", 1.0, 0.2)
	_card_tw.chain().tween_interval(3.8)
	_card_tw.chain().tween_property(card, "modulate:a", 0.0, 0.5)
	_card_tw.chain().tween_callback(func(): card.visible = false)
	if is_new or j["stars"] >= 4.5:
		var vp := root.get_viewport_rect().size
		confetti.position = Vector2(vp.x / 2, vp.y * 0.45)
		confetti.restart()


class Stars:
	extends Control
	var value := 0.0

	func _draw() -> void:
		var r := 19.0
		var gap := r * 2.4
		var x0 := (size.x - gap * 4) / 2
		for i in 5:
			var c := Vector2(x0 + i * gap, size.y / 2)
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2 + k * PI / 5
				var rr := r if k % 2 == 0 else r * 0.46
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, Color(0.86, 0.83, 0.77))
			var fill := clampf(value - i, 0.0, 1.0)
			if fill >= 1.0:
				draw_colored_polygon(pts, Color(1.0, 0.72, 0.15))
			elif fill > 0.0:
				var cut_x := c.x - r + 2 * r * fill
				var rect := PackedVector2Array([Vector2(c.x - r - 1, c.y - r - 1), Vector2(cut_x, c.y - r - 1), Vector2(cut_x, c.y + r + 1), Vector2(c.x - r - 1, c.y + r + 1)])
				for poly in Geometry2D.intersect_polygons(pts, rect):
					draw_colored_polygon(poly, Color(1.0, 0.72, 0.15))


# ================================================================ recipe book

func _build_book() -> void:
	var v := _center_panel("book", Vector2(1000, 650))
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	book_title = _label("Recipe Book", 30, ACCENT, title_font())
	book_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(book_title)
	book_search = LineEdit.new()
	book_search.placeholder_text = "Search dishes or ingredients"
	book_search.custom_minimum_size = Vector2(300, 42)
	book_search.text_changed.connect(func(_s): _fill_book())
	head.add_child(book_search)
	head.add_child(_button("Close", close_modal, 17, 110))
	var where := _label(WHERE, 13, Color(1, 1, 1, 0.6))
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(where)
	v.add_child(_label("Everything here can be cooked, but you can combine ANYTHING and the kitchen will name what you invent.", 14, Color(1, 0.9, 0.75, 0.8)))
	book_text = RichTextLabel.new()
	book_text.bbcode_enabled = true
	book_text.custom_minimum_size = Vector2(0, 500)
	book_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book_text.add_theme_font_override("normal_font", body_font())
	book_text.add_theme_font_override("bold_font", bold_font())
	book_text.add_theme_font_size_override("normal_font_size", 15)
	book_text.add_theme_font_size_override("bold_font_size", 20)
	v.add_child(book_text)


func _fill_book() -> void:
	var found: Dictionary = game.save["found"]
	var n := DB.recipe_count()
	book_title.text = "Recipe Book   %d / %d" % [found.size(), n]
	var q := book_search.text.strip_edges().to_lower()
	var out := ""
	for k in n:
		var nm := DB.display_name(k)
		var lines: Array = DB.recipe_lines(k)
		var body := "   +   ".join(lines[0])
		if q != "" and not nm.to_lower().contains(q) and not body.to_lower().contains(q):
			continue
		var got := found.has(str(k))
		out += "[b][color=%s]%s[/color][/b]%s\n" % ["#8fe39a" if got else "#ffd08a", nm, "   [color=#8fe39a][font_size=13]COOKED[/font_size][/color]" if got else ""]
		out += "[color=#ece4d6]%s[/color]\n" % body
		for h in lines[1]:
			out += "[color=#b8a8e8][font_size=13]      %s[/font_size][/color]\n" % h
		out += "\n"
	book_text.text = out


func open_book() -> void:
	book_search.text = ""
	_fill_book()
	open_modal("book")


# ================================================================ menus

func _build_menu() -> void:
	var dim := Control.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var grad := TextureRect.new()
	var g := Gradient.new()
	g.set_color(0, Color(0.04, 0.03, 0.03, 0.9))
	g.set_color(1, Color(0.04, 0.03, 0.03, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.custom_minimum_size = Vector2(820, 0)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	dim.add_child(grad)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(80, -260)
	v.add_theme_constant_override("separation", 12)
	dim.add_child(v)
	v.add_child(_label("COOK UP", 84, Color(1.0, 0.78, 0.4), title_font(), 0))
	var t2 := _label("ANYTHING", 84, Color(1.0, 0.5, 0.36), title_font(), 0)
	v.add_child(t2)
	v.add_child(_label("Every ingredient. Every combination. Your kitchen.", 20, Color(1, 1, 1, 0.8), body_font()))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	v.add_child(sp)
	v.add_child(_button("Sandbox   -   cook whatever you like", func(): game.start("sandbox"), 21, 440))
	v.add_child(_button("Dinner Rush   -   serve the orders", func(): game.start("orders"), 21, 440))
	v.add_child(_button("Recipe Book", open_book, 21, 440))
	var qb := _button("", func(): game.toggle_quality(), 21, 440)
	quality_buttons.append(qb)
	v.add_child(qb)
	v.add_child(_button("Quit", func(): get_tree().quit(), 21, 440))
	menu_stats = _label("", 16, Color(1, 1, 1, 0.65), body_font())
	v.add_child(menu_stats)
	panels["menu"] = dim
	dim.visible = false


func _build_pause() -> void:
	var v := _center_panel("pause", Vector2(440, 0))
	var t := _label("Paused", 38, ACCENT, title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("Resume", close_modal, 21, 380))
	v.add_child(_button("Recipe Book", open_book, 21, 380))
	var qb := _button("", func(): game.toggle_quality(), 21, 380)
	quality_buttons.append(qb)
	v.add_child(qb)
	v.add_child(_button("Main Menu", func(): game.show_menu(), 21, 380))
	v.add_child(_button("Quit", func(): get_tree().quit(), 21, 380))


func set_quality_label(high: bool) -> void:
	for b in quality_buttons:
		(b as Button).text = "Graphics:  %s" % ("High" if high else "Fast")


func _build_results() -> void:
	var v := _center_panel("results", Vector2(540, 0))
	var t := _label("Shift Over", 44, ACCENT, title_font())
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	results_lbl = _label("", 21, Color(1, 1, 1), body_font())
	results_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(results_lbl)
	v.add_child(_button("Another shift", func(): game.start("orders"), 21, 480))
	v.add_child(_button("Sandbox", func(): game.start("sandbox"), 21, 480))
	v.add_child(_button("Main Menu", func(): game.show_menu(), 21, 480))


func show_results(text: String) -> void:
	results_lbl.text = text
	open_modal("results")


func show_menu(stats: String) -> void:
	for k in panels:
		(panels[k] as Control).visible = false
	modal = ""
	menu_stats.text = stats
	panels["menu"].visible = true
	hud.visible = false
	card.visible = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func hide_menu() -> void:
	panels["menu"].visible = false


# ================================================================ modal plumbing

func open_modal(n: String) -> void:
	if modal != "" and modal != n:
		(panels[modal] as Control).visible = false
	modal = n
	(panels[n] as Control).visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game.on_modal(true)


func close_modal() -> void:
	if modal == "":
		return
	(panels[modal] as Control).visible = false
	modal = ""
	if panels["menu"].visible:
		return
	game.on_modal(false)
