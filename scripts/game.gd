extends Node3D
## Root controller: builds the world, runs Sandbox and Dinner Rush modes,
## judges served dishes and keeps the save file.

const SAVE_PATH := "user://cook_save.json"
const SHIFT := 300.0
const MAX_MISSES := 3
const MAX_ORDERS := 4

var sfx: Sfx
var ui: UI
var player: Player
var kitchen: Kitchen
var items: Node3D
var clock: Node3D
var menu_cam := Camera3D.new()
var mode := "menu"
var save := {"found": {}, "best": 0, "served": 0}
var money := 0
var served := 0
var misses := 0
var streak := 0
var shift_left := 0.0
var orders: Array = []
var next_order := 0.0
var shake := 0.0
var menu_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	DB.init()
	_inputs()
	sfx = Sfx.new()
	add_child(sfx)
	items = Node3D.new()
	items.name = "Items"
	add_child(items)
	process_mode = Node.PROCESS_MODE_ALWAYS
	items.process_mode = Node.PROCESS_MODE_PAUSABLE
	kitchen = Kitchen.new(self)
	kitchen.build()
	kitchen.root.process_mode = Node.PROCESS_MODE_PAUSABLE
	player = Player.new()
	player.game = self
	add_child(player)
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(menu_cam)
	ui = UI.new()
	ui.game = self
	add_child(ui)
	_load()
	show_menu()


func _inputs() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"interact": [KEY_E], "use": [KEY_F], "throw": [KEY_Q], "book": [KEY_TAB],
		"pause": [KEY_ESCAPE, KEY_P], "sprint": [KEY_SHIFT],
	}
	for a in keys:
		if not InputMap.has_action(a):
			InputMap.add_action(a)
		for k in keys[a]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(a, ev)
	var lmb := InputEventMouseButton.new()
	lmb.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("interact", lmb)
	var rmb := InputEventMouseButton.new()
	rmb.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("use", rmb)


# ================================================================ modes

func show_menu() -> void:
	mode = "menu"
	get_tree().paused = false
	player.enabled = false
	menu_cam.current = true
	_clear_world()
	ui.show_menu("Recipes discovered: %d / %d     Best Dinner Rush: $%d     Dishes served: %d" % [
		save["found"].size(), DB.recipe_count(), save["best"], save["served"]])
	ui.refresh_orders([])
	_spawn_showcase()


func start(m: String) -> void:
	ui.close_modal()
	ui.hide_menu()
	get_tree().paused = false
	streak = 0
	_clear_world()
	mode = m
	money = 0
	served = 0
	misses = 0
	orders.clear()
	ui.refresh_orders(orders)
	shift_left = SHIFT
	next_order = 1.5
	player.position = Vector3(0, 0.05, 2.3)
	player.rotation = Vector3.ZERO
	player.cam.rotation = Vector3(-0.25, 0, 0)
	player.velocity = Vector3.ZERO
	player.cam.current = true
	player.enabled = true
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	ui.show_hud(true)
	for x in [-0.6, 0.0, 0.6]:
		var p := Plate.new()
		items.add_child(p)
		p.global_position = Vector3(x, Kitchen.TOP + 0.02, 0.6)
	if m == "sandbox":
		ui.toast("Sandbox! Grab ingredients from the Fridge or Pantry and invent something.")
	else:
		ui.toast("Dinner Rush! Read the tickets, cook, plate and serve at the hatch.")
	sfx.play("fanfare", -6.0)


func _clear_world() -> void:
	player.drop_held()
	for c in items.get_children():
		c.queue_free()
	for st in kitchen.stations:
		var s: Station = st
		for c in s.contents:
			c.queue_free()
		s.contents.clear()
		s.done_once = false
		s.running = false
		s.work = 0
		s._hide_bar()
		s._heat(false)
		if s.loop:
			s.loop.stop()


## Plates of food around the island so the menu backdrop looks delicious.
func _spawn_showcase() -> void:
	var dishes := [
		["bun", "patty", "cheese", "lettuce", "tomato"],
		["pizza", "pepperoni"],
		["cake"],
		["cooked_pasta", "tomato_sauce", "meatballs"],
		["pancakes", "strawberry"],
	]
	var xs := [-1.0, -0.5, 0.0, 0.5, 1.0]
	for i in dishes.size():
		var p := Plate.new()
		items.add_child(p)
		p.position = Vector3(xs[i], Kitchen.TOP + 0.01, 0.35 + (0.15 if i % 2 == 0 else -0.15))
		p.freeze = true
		for id in dishes[i]:
			var l := DB.new_leaf(id)
			l["washed"] = true
			if id in ["patty", "meatballs"]:
				l["cooked"] = true
				l["cook"] = "fry"
				l["br"] = 1.0
			if id == "tomato":
				l["cut"] = 1
			if id == "cake":
				l["flavor"] = "strawberry"
			p.items.append(l)
		p.rebuild()


func on_modal(open: bool) -> void:
	player.enabled = not open and mode != "menu"
	get_tree().paused = open and (mode == "sandbox" or mode == "orders")
	if not open and mode != "menu":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	get_tree().paused = false


func _unhandled_input(e: InputEvent) -> void:
	if mode == "menu" or mode == "results":
		if e.is_action_pressed("pause") and ui.modal != "":
			ui.close_modal()
		return
	if e.is_action_pressed("pause"):
		if ui.modal != "":
			ui.close_modal()
		else:
			ui.open_modal("pause")
	elif e.is_action_pressed("book"):
		if ui.modal == "book":
			ui.close_modal()
		elif ui.modal == "":
			ui.open_book()
	elif e is InputEventMouseButton and e.pressed and ui.modal == "" and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ================================================================ loop

func _process(delta: float) -> void:
	if clock:
		var tm := Time.get_time_dict_from_system()
		(clock.get_node("Hour") as Node3D).rotation.z = -TAU * ((tm["hour"] % 12) + tm["minute"] / 60.0) / 12.0
		(clock.get_node("Minute") as Node3D).rotation.z = -TAU * tm["minute"] / 60.0
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 0.05)
		player.cam.h_offset = randf_range(-shake, shake)
		player.cam.v_offset = randf_range(-shake, shake)
	if mode == "menu":
		menu_t += delta * 0.12
		menu_cam.position = Vector3(sin(menu_t) * 2.4, 1.75, 0.35 + cos(menu_t) * 2.4)
		menu_cam.look_at(Vector3(0, 1.0, 0.35), Vector3.UP)
		return
	if mode == "sandbox":
		ui.set_status("Sandbox", "Discovered %d / %d" % [save["found"].size(), DB.recipe_count()],
			"Dishes served: %d" % served)
		return
	if mode != "orders" or ui.modal != "":
		return
	shift_left -= delta
	next_order -= delta
	if (next_order <= 0.0 and orders.size() < MAX_ORDERS) or orders.is_empty():
		_new_order()
		next_order = maxf(14.0, 30.0 - served * 1.2)
	var changed := false
	for o in orders.duplicate():
		o["time"] -= delta
		if o["time"] <= 0.0:
			orders.erase(o)
			misses += 1
			changed = true
			sfx.play("buzz")
			ui.toast("A customer left hungry! (%d / %d misses)" % [misses, MAX_MISSES])
			cam_shake(0.02)
	if changed:
		ui.refresh_orders(orders)
	ui.update_order_bars(orders)
	var secs := maxi(0, int(shift_left))
	ui.set_status("$%d" % money, "%d:%02d" % [secs / 60, secs % 60],
		"Served %d   Misses %d / %d" % [served, misses, MAX_MISSES])
	if shift_left <= 0.0 or misses >= MAX_MISSES:
		_end_shift()


func _new_order() -> void:
	var cap := 4 + int(served * 0.7)
	var pool := []
	var active := []
	for o in orders:
		active.append(o["k"])
	for k in DB.recipe_count():
		if DB.difficulty(k) <= cap and not active.has(k):
			pool.append(k)
	if pool.is_empty():
		return
	var k: int = pool[_rng.randi() % pool.size()]
	var total := 50.0 + DB.difficulty(k) * 9.0
	orders.append({"k": k, "time": total, "total": total})
	ui.refresh_orders(orders)
	sfx.play("bell", -4.0)


func _end_shift() -> void:
	mode = "results"
	player.enabled = false
	var best: bool = money > int(save["best"])
	if best:
		save["best"] = money
	_save()
	ui.show_hud(false)
	var stars := clampi(served / 2, 0, 5)
	ui.show_results("Earned: $%d%s\nDishes served: %d\nCustomers missed: %d\n\n%s" % [
		money, "   NEW BEST!" if best else "", served, misses,
		["Rough night...", "Not bad, chef!", "Solid shift!", "The critics are talking!", "Sensational!", "LEGENDARY KITCHEN!"][stars]])
	sfx.play("fanfare")


# ================================================================ actions

func pick_ingredient(id: String) -> void:
	if player.held:
		player.drop_held()
	var f := Food.make(DB.new_leaf(id))
	items.add_child(f)
	f.global_position = player.hand.global_position
	player.hold(f)
	ui.close_modal()


func serve(b: RigidBody3D) -> void:
	var ls: Array = (b as Plate).leaves() if b is Plate else DB.leaves((b as Food).data)
	if ls.is_empty():
		player.hold(b)
		toast("There's nothing on that plate!")
		return
	var j := DB.judge(ls)
	var k: int = j["recipe"]
	var is_new: bool = k >= 0 and not save["found"].has(str(k))
	if is_new:
		save["found"][str(k)] = true
	save["served"] = int(save["served"]) + 1
	served += 1
	var reward := ""
	if mode == "orders":
		var hit = null
		for o in orders:
			if o["k"] == k:
				hit = o
				break
		if hit != null:
			streak += 1
			var tip := int(10.0 * hit["time"] / hit["total"])
			var pay := 8 + DB.difficulty(k) * 2 + int(j["stars"] * 2.0) + tip
			var bonus := 0
			if streak >= 2:
				bonus = int(pay * 0.15 * mini(streak - 1, 5))
			money += pay + bonus
			orders.erase(hit)
			ui.refresh_orders(orders)
			reward = "+$%d  (tip $%d)" % [pay, tip]
			if bonus > 0:
				reward += "\nSTREAK x%d!  +$%d bonus" % [streak, bonus]
			sfx.play("cash")
		else:
			streak = 0
			var pay := int(j["stars"])
			money += pay
			reward = "Nobody ordered that... a walk-in bought it! +$%d" % pay
			served -= 1
	if is_new:
		sfx.play("fanfare")
	elif j["stars"] >= 4.0:
		sfx.play("sparkle")
	ui.show_card(j, is_new, reward)
	var hatch := _station("serve")
	hatch.bump()
	sfx.play("bell")
	# fly the dish out through the hatch
	b.reparent(items, true)
	b.set_carried(true)
	b.global_position = hatch.hold.global_position
	var tw := b.create_tween()
	tw.tween_property(b, "global_position", hatch.global_position + Vector3(0.9, 0.3, 0), 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(b, "scale", Vector3.ONE * 0.2, 0.6)
	tw.tween_callback(b.queue_free)
	_save()


func _station(kind: String) -> Station:
	for s in kitchen.stations:
		if (s as Station).kind == kind:
			return s
	return null


func toast(msg: String) -> void:
	ui.toast(msg)


func float_text(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.pixel_size = 0.0016
	l.outline_size = 14
	l.modulate = col
	l.no_depth_test = true
	l.render_priority = 20
	l.outline_render_priority = 19
	add_child(l)
	l.global_position = pos
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "global_position", pos + Vector3(0, 0.4, 0), 1.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)


func cam_shake(a: float) -> void:
	shake = maxf(shake, a)


# ================================================================ save

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if data is Dictionary:
		for key in save:
			if data.has(key):
				save[key] = data[key]


func _save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(save))
