class_name UI
extends CanvasLayer
## All 2D interface: HUD, prompts, pantry, recipe book, review cards, menus.

const ACCENT := Color(1.0, 0.72, 0.3)
const GOOD := Color(0.45, 0.95, 0.55)
const BAD := Color(1.0, 0.45, 0.4)

var game: Node
var theme := Theme.new()
var root := Control.new()
var hud := Control.new()
var look_lbl: Label
var sub_lbl: Label
var keys_lbl: RichTextLabel
var held_lbl: Label
var toast_lbl: Label
var info_lbl: Label
var timer_lbl: Label
var money_lbl: Label
var orders_box: VBoxContainer
var help_lbl: Label
var modal := ""
var panels := {}
var pantry_grid: GridContainer
var pantry_tab := 0
var pantry_search: LineEdit
var tab_buttons: Array = []
var book_text: RichTextLabel
var book_search: LineEdit
var book_title: Label
var card: PanelContainer
var card_vbox: VBoxContainer
var confetti: CPUParticles2D
var menu_stats: Label
var results_lbl: Label
var _icons := {}
var _toast_tw: Tween
var _card_tw: Tween


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
	_build_pantry()
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
	hue.colors = PackedColorArray([Color(1, 0.3, 0.4), Color(1, 0.85, 0.2), Color(0.3, 0.9, 0.5), Color(0.3, 0.6, 1), Color(0.9, 0.4, 1)])
	confetti.color_initial_ramp = hue
	root.add_child(confetti)


# ================================================================ theme & helpers

func _style(bg: Color, radius := 14, border := Color(0, 0, 0, 0), bw := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	if bw > 0:
		s.border_color = border
		s.set_border_width_all(bw)
	return s


func _make_theme() -> void:
	theme.default_font_size = 18
	theme.set_stylebox("panel", "PanelContainer", _style(Color(0.09, 0.08, 0.12, 0.93), 18, Color(1, 1, 1, 0.08), 2))
	theme.set_stylebox("normal", "Button", _style(Color(0.22, 0.2, 0.3), 12))
	theme.set_stylebox("hover", "Button", _style(Color(0.95, 0.6, 0.25), 12))
	theme.set_stylebox("pressed", "Button", _style(Color(0.8, 0.45, 0.15), 12))
	theme.set_stylebox("focus", "Button", _style(Color(0, 0, 0, 0), 12, Color(1, 0.8, 0.4), 2))
	theme.set_color("font_hover_color", "Button", Color(0.1, 0.05, 0.0))
	theme.set_color("font_pressed_color", "Button", Color(0.1, 0.05, 0.0))
	theme.set_stylebox("normal", "LineEdit", _style(Color(0.16, 0.15, 0.22), 10))
	theme.set_stylebox("focus", "LineEdit", _style(Color(0.2, 0.18, 0.28), 10, ACCENT, 2))
	theme.set_stylebox("background", "ProgressBar", _style(Color(0, 0, 0, 0.5), 6))
	theme.set_stylebox("fill", "ProgressBar", _style(GOOD, 6))
	theme.set_constant("outline_size", "Label", 0)


func _label(text: String, size := 18, col := Color(1, 1, 1), outline := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if outline > 0:
		l.add_theme_constant_override("outline_size", outline)
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _button(text: String, cb: Callable, size := 20, min_w := 280) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(min_w, 52)
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(func():
		game.sfx.play("click")
		cb.call())
	b.mouse_entered.connect(func(): game.sfx.play("click", -14.0))
	return b


func _center_panel(n: String, min_size: Vector2) -> VBoxContainer:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
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


func icon(id: String) -> Texture2D:
	if _icons.has(id):
		return _icons[id]
	var n := 44
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var oc := Color(DB.ING[id][3])
	var ic := Color(DB.ING[id][4])
	var c := Vector2(n / 2.0, n / 2.0)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
			var col := Color(0, 0, 0, 0)
			if d < n / 2.0 - 1:
				col = oc
				if d > n / 2.0 - 4:
					col = oc.darkened(0.35)
				elif Vector2(x, y).distance_to(c + Vector2(-6, -6)) < 8:
					col = ic.lightened(0.25)
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_icons[id] = tex
	return tex


# ================================================================ HUD

func _build_hud() -> void:
	var cross := ColorRect.new()
	cross.color = Color(1, 1, 1, 0.85)
	cross.size = Vector2(6, 6)
	cross.set_anchors_preset(Control.PRESET_CENTER)
	cross.position = Vector2(-3, -3)
	cross.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cross)
	var mid := VBoxContainer.new()
	mid.set_anchors_preset(Control.PRESET_CENTER)
	mid.position = Vector2(-400, 22)
	mid.custom_minimum_size = Vector2(800, 0)
	mid.alignment = BoxContainer.ALIGNMENT_BEGIN
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(mid)
	look_lbl = _label("", 24, Color(1, 1, 1), 8)
	look_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mid.add_child(look_lbl)
	sub_lbl = _label("", 16, Color(1, 0.9, 0.75), 6)
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mid.add_child(sub_lbl)
	keys_lbl = RichTextLabel.new()
	keys_lbl.bbcode_enabled = true
	keys_lbl.fit_content = true
	keys_lbl.scroll_active = false
	keys_lbl.custom_minimum_size = Vector2(800, 30)
	keys_lbl.add_theme_font_size_override("normal_font_size", 18)
	keys_lbl.add_theme_constant_override("outline_size", 6)
	keys_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	keys_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(keys_lbl)
	held_lbl = _label("", 20, ACCENT, 8)
	held_lbl.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	held_lbl.position = Vector2(-400, -92)
	held_lbl.custom_minimum_size = Vector2(800, 30)
	held_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_child(held_lbl)
	toast_lbl = _label("", 22, Color(1, 1, 1), 8)
	toast_lbl.set_anchors_preset(Control.PRESET_CENTER)
	toast_lbl.position = Vector2(-400, 120)
	toast_lbl.custom_minimum_size = Vector2(800, 30)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.modulate.a = 0.0
	hud.add_child(toast_lbl)
	help_lbl = _label("[E / Left-click] Grab & place     [F / Right-click] Chop, whisk, blend     [Q] Throw     [Tab] Recipe book     [Shift] Run     [Esc] Pause", 14, Color(1, 1, 1, 0.7), 5)
	help_lbl.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	help_lbl.position = Vector2(16, -34)
	hud.add_child(help_lbl)
	# top right status
	var tr := VBoxContainer.new()
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.position = Vector2(-380, 14)
	tr.custom_minimum_size = Vector2(364, 0)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(tr)
	money_lbl = _label("", 34, Color(0.6, 1.0, 0.6), 10)
	money_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(money_lbl)
	timer_lbl = _label("", 24, Color(1, 1, 1), 8)
	timer_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(timer_lbl)
	info_lbl = _label("", 16, Color(1, 1, 1, 0.85), 6)
	info_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tr.add_child(info_lbl)
	orders_box = VBoxContainer.new()
	orders_box.position = Vector2(14, 14)
	orders_box.add_theme_constant_override("separation", 8)
	orders_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(orders_box)
	hud.visible = false


func show_hud(on: bool) -> void:
	hud.visible = on


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
		"food":
			var fd: Food = node
			title = fd.display_name()
			if fd.needs_wash():
				sub = "Muddy - wash it in the sink"
			e = "Pick up" if held == null else ("Add to plate" if held is Plate else "Place here")
		"plate":
			var pl: Plate = node
			title = pl.display_name()
			if held == null:
				e = "Pick up plate"
			elif held is Food:
				e = "Add to plate"
			else:
				e = "Place here"
		"station":
			var st: Station = node
			title = st.title()
			sub = st.status_text()
			if held == null:
				match st.kind:
					"fridge", "pantry": e = "Open"
					"plates": e = "Take a plate"
					"trash", "serve": e = ""
					_: e = "Take out" if not st.contents.is_empty() and not st.running else ""
			elif held is Food:
				match st.kind:
					"trash": e = "Bin it"
					"fridge", "pantry": e = "Put it back"
					"serve": e = "Serve it!"
					"plates": e = ""
					_:
						var why := st.accepts(held)
						if why == "":
							e = "Put in"
						else:
							sub = why
			else:
				match st.kind:
					"trash": e = "Scrape plate"
					"serve": e = "Serve it!"
					"plates": e = "Put plate back" if (held as Plate).items.is_empty() else ""
					"fridge", "pantry": e = ""
					_: e = "Scoop onto plate" if not st.contents.is_empty() else ""
			f = st.use_label()
		"surface":
			if held:
				e = "Place"
	look_lbl.text = title
	sub_lbl.text = sub
	var parts := []
	if e != "":
		parts.append("[color=#ffb84d][E][/color] " + e)
	if f != "":
		parts.append("[color=#7ec8ff][F][/color] " + f)
	if held:
		parts.append("[color=#aaaaaa][Q][/color] Throw")
	keys_lbl.text = "[center]" + "     ".join(parts) + "[/center]"
	if held:
		var hn: String = held.call("display_name")
		var dirty := held is Food and (held as Food).needs_wash()
		held_lbl.text = "Holding: " + hn + ("  (muddy)" if dirty else "")
	else:
		held_lbl.text = ""


func toast(msg: String) -> void:
	toast_lbl.text = msg
	if _toast_tw:
		_toast_tw.kill()
	toast_lbl.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(1.6)
	_toast_tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.5)


func set_status(money: String, timer: String, info: String) -> void:
	money_lbl.text = money
	timer_lbl.text = timer
	info_lbl.text = info


# ================================================================ orders

func refresh_orders(orders: Array) -> void:
	for c in orders_box.get_children():
		c.queue_free()
	for o in orders:
		var pc := PanelContainer.new()
		pc.custom_minimum_size = Vector2(330, 0)
		pc.add_theme_stylebox_override("panel", _style(Color(1.0, 0.97, 0.88, 0.95), 12))
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 2)
		pc.add_child(v)
		var name_l := _label(DB.display_name(o["k"]), 20, Color(0.25, 0.12, 0.05))
		v.add_child(name_l)
		var lines: Array = DB.recipe_lines(o["k"])
		for line in lines[0]:
			v.add_child(_label("- " + line, 13, Color(0.3, 0.25, 0.2)))
		for h in lines[1]:
			var hl := _label("  " + h, 12, Color(0.45, 0.35, 0.6))
			hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			hl.custom_minimum_size = Vector2(300, 0)
			v.add_child(hl)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.max_value = 1.0
		bar.value = 1.0
		v.add_child(bar)
		o["bar"] = bar
		o["panel"] = pc
		orders_box.add_child(pc)
		pc.scale = Vector2(0.6, 0.6)
		pc.pivot_offset = Vector2(0, 0)
		var tw := pc.create_tween()
		tw.tween_property(pc, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func update_order_bars(orders: Array) -> void:
	for o in orders:
		if not o.has("bar") or not is_instance_valid(o["bar"]):
			continue
		var bar: ProgressBar = o["bar"]
		var r: float = o["time"] / o["total"]
		bar.value = r
		var col := GOOD if r > 0.5 else (ACCENT if r > 0.25 else BAD)
		bar.add_theme_stylebox_override("fill", _style(col, 6))
		if r < 0.25:
			(o["panel"] as Control).modulate = Color(1, 0.85, 0.85) if fmod(Time.get_ticks_msec() / 250.0, 2.0) < 1.0 else Color(1, 1, 1)


# ================================================================ review card

func _build_card() -> void:
	card = PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER_TOP)
	card.position = Vector2(-280, 90)
	card.custom_minimum_size = Vector2(560, 0)
	card.add_theme_stylebox_override("panel", _style(Color(1.0, 0.97, 0.9, 0.97), 22, ACCENT, 4))
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
		var nl := _label("NEW RECIPE DISCOVERED!", 22, Color(0.85, 0.35, 0.1))
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(nl)
	var name_l := _label(j["name"], 34, Color(0.2, 0.1, 0.05))
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_vbox.add_child(name_l)
	var stars := Stars.new()
	stars.value = j["stars"]
	stars.custom_minimum_size = Vector2(0, 46)
	card_vbox.add_child(stars)
	for n in j["notes"]:
		var bad: bool = String(n).contains("RAW") or String(n).contains("charcoal") or String(n).contains("dirt")
		var l := _label(n, 17, Color(0.75, 0.2, 0.15) if bad else Color(0.3, 0.45, 0.25))
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(l)
	if reward != "":
		var r := _label(reward, 24, Color(0.15, 0.6, 0.25))
		r.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		card_vbox.add_child(r)
	card.visible = true
	card.pivot_offset = Vector2(280, 60)
	card.scale = Vector2(0.4, 0.4)
	card.modulate.a = 1.0
	if _card_tw:
		_card_tw.kill()
	_card_tw = create_tween()
	_card_tw.tween_property(card, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_card_tw.tween_interval(3.6)
	_card_tw.tween_property(card, "modulate:a", 0.0, 0.5)
	_card_tw.tween_callback(func(): card.visible = false)
	if is_new or j["stars"] >= 4.5:
		var vp := root.get_viewport_rect().size
		confetti.position = Vector2(vp.x / 2, vp.y * 0.45)
		confetti.restart()


class Stars:
	extends Control
	var value := 0.0

	func _draw() -> void:
		var r := 20.0
		var total := 5 * r * 2.3
		var x0 := (size.x - total) / 2 + r
		for i in 5:
			var c := Vector2(x0 + i * r * 2.3, size.y / 2)
			var pts := PackedVector2Array()
			for k in 10:
				var a := -PI / 2 + k * PI / 5
				var rr := r if k % 2 == 0 else r * 0.45
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, Color(0.8, 0.78, 0.72))
			var fill := clampf(value - i, 0.0, 1.0)
			if fill > 0.0:
				var clip := PackedVector2Array()
				for p in pts:
					clip.append(p)
				if fill < 1.0:
					var cut_x := c.x - r + 2 * r * fill
					var rect := PackedVector2Array([Vector2(c.x - r - 1, c.y - r - 1), Vector2(cut_x, c.y - r - 1), Vector2(cut_x, c.y + r + 1), Vector2(c.x - r - 1, c.y + r + 1)])
					var res := Geometry2D.intersect_polygons(pts, rect)
					for poly in res:
						draw_colored_polygon(poly, Color(1.0, 0.75, 0.15))
				else:
					draw_colored_polygon(pts, Color(1.0, 0.75, 0.15))
				draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0.75, 0.45, 0.05), 2.0, true)


# ================================================================ pantry

func _build_pantry() -> void:
	var v := _center_panel("pantry", Vector2(1040, 620))
	var head := HBoxContainer.new()
	v.add_child(head)
	var t := _label("What are we cooking?", 30, ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	pantry_search = LineEdit.new()
	pantry_search.placeholder_text = "Search ingredients..."
	pantry_search.custom_minimum_size = Vector2(280, 40)
	pantry_search.text_changed.connect(func(_s): _fill_pantry())
	head.add_child(pantry_search)
	head.add_child(_button("Close", close_modal, 18, 110))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for i in DB.TABS.size():
		var b := _button(DB.TABS[i][0], func():
			pantry_tab = i
			pantry_search.text = ""
			_fill_pantry(), 17, 150)
		b.toggle_mode = true
		tabs.add_child(b)
		tab_buttons.append(b)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(0, 470)
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(sc)
	pantry_grid = GridContainer.new()
	pantry_grid.columns = 5
	pantry_grid.add_theme_constant_override("h_separation", 8)
	pantry_grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(pantry_grid)


func _fill_pantry() -> void:
	for c in pantry_grid.get_children():
		c.queue_free()
	for i in tab_buttons.size():
		(tab_buttons[i] as Button).set_pressed_no_signal(i == pantry_tab)
	var q := pantry_search.text.strip_edges().to_lower()
	var cats: Array = DB.TABS[pantry_tab][1]
	for id in DB.ING:
		var ing: Array = DB.ING[id]
		if DB.flag(id, "i"):
			continue
		if q != "":
			if not String(ing[0]).to_lower().contains(q):
				continue
		elif not cats.has(ing[1]):
			continue
		var b := Button.new()
		b.text = ing[0]
		b.icon = icon(id)
		b.custom_minimum_size = Vector2(192, 58)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 17)
		var pick_id: String = id
		b.pressed.connect(func(): game.pick_ingredient(pick_id))
		b.mouse_entered.connect(func(): game.sfx.play("click", -14.0))
		pantry_grid.add_child(b)


func open_pantry(tab: int) -> void:
	pantry_tab = tab
	pantry_search.text = ""
	_fill_pantry()
	open_modal("pantry")


# ================================================================ recipe book

func _build_book() -> void:
	var v := _center_panel("book", Vector2(980, 640))
	var head := HBoxContainer.new()
	v.add_child(head)
	book_title = _label("Recipe Book", 30, ACCENT)
	book_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(book_title)
	book_search = LineEdit.new()
	book_search.placeholder_text = "Search dishes or ingredients..."
	book_search.custom_minimum_size = Vector2(300, 40)
	book_search.text_changed.connect(func(_s): _fill_book())
	head.add_child(book_search)
	head.add_child(_button("Close", close_modal, 18, 110))
	v.add_child(_label("Every dish below can be made, but you can also combine ANYTHING: the kitchen names whatever you invent.", 15, Color(1, 1, 1, 0.75)))
	book_text = RichTextLabel.new()
	book_text.bbcode_enabled = true
	book_text.custom_minimum_size = Vector2(0, 520)
	book_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	book_text.add_theme_font_size_override("normal_font_size", 16)
	book_text.add_theme_font_size_override("bold_font_size", 20)
	v.add_child(book_text)


func _fill_book() -> void:
	var found: Dictionary = game.save["found"]
	var n := DB.recipe_count()
	book_title.text = "Recipe Book  -  %d / %d discovered" % [found.size(), n]
	var q := book_search.text.strip_edges().to_lower()
	var out := ""
	for k in n:
		var nm := DB.display_name(k)
		var lines: Array = DB.recipe_lines(k)
		var body := "  |  ".join(lines[0])
		if q != "" and not nm.to_lower().contains(q) and not body.to_lower().contains(q):
			continue
		var got := found.has(str(k))
		var col := "#7CFC9A" if got else "#ffd27f"
		out += "[b][color=%s]%s%s[/color][/b]\n" % [col, nm, "   (made it!)" if got else ""]
		out += "[color=#e8e0d0]%s[/color]\n" % body
		for h in lines[1]:
			out += "[color=#b9a6ff]   %s[/color]\n" % h
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
	g.set_color(0, Color(0.05, 0.03, 0.08, 0.92))
	g.set_color(1, Color(0.05, 0.03, 0.08, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill_to = Vector2(1, 0)
	grad.texture = gt
	grad.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	grad.custom_minimum_size = Vector2(760, 0)
	grad.size = Vector2(760, 720)
	grad.stretch_mode = TextureRect.STRETCH_SCALE
	dim.add_child(grad)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	v.position = Vector2(70, -250)
	v.add_theme_constant_override("separation", 14)
	dim.add_child(v)
	var t := _label("COOK UP", 76, Color(1.0, 0.75, 0.3), 16)
	v.add_child(t)
	var t2 := _label("ANYTHING", 76, Color(1.0, 0.45, 0.35), 16)
	t2.position.y = -20
	v.add_child(t2)
	v.add_child(_label("A kitchen where every combination makes something.", 20, Color(1, 1, 1, 0.85), 6))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 14)
	v.add_child(sp)
	v.add_child(_button("Sandbox  -  cook whatever you want", func(): game.start("sandbox"), 22, 420))
	v.add_child(_button("Dinner Rush  -  serve the orders", func(): game.start("orders"), 22, 420))
	v.add_child(_button("Recipe Book", open_book, 22, 420))
	v.add_child(_button("Quit", func(): get_tree().quit(), 22, 420))
	menu_stats = _label("", 17, Color(1, 1, 1, 0.75), 6)
	v.add_child(menu_stats)
	panels["menu"] = dim
	dim.visible = false


func _build_pause() -> void:
	var v := _center_panel("pause", Vector2(420, 0))
	var t := _label("Paused", 36, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(_button("Resume", close_modal, 22, 360))
	v.add_child(_button("Recipe Book", open_book, 22, 360))
	v.add_child(_button("Main Menu", func(): game.show_menu(), 22, 360))
	v.add_child(_button("Quit", func(): get_tree().quit(), 22, 360))


func _build_results() -> void:
	var v := _center_panel("results", Vector2(520, 0))
	var t := _label("Shift Over!", 42, ACCENT)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	results_lbl = _label("", 22, Color(1, 1, 1))
	results_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(results_lbl)
	v.add_child(_button("Another shift!", func(): game.start("orders"), 22, 460))
	v.add_child(_button("Sandbox", func(): game.start("sandbox"), 22, 460))
	v.add_child(_button("Main Menu", func(): game.show_menu(), 22, 460))


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
