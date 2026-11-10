extends SceneTree
## Throwaway: renders contact sheets of food models to /tmp/food_*.png

var world: Node3D
var cam: Camera3D
var holder: Node3D


func leaf(id: String, cut := 0, cook := "", br := 0.0, ch := 0.0, washed := true) -> Dictionary:
	var l := DB.new_leaf(id)
	l["washed"] = washed
	l["cut"] = cut
	if cook != "":
		l["cook"] = cook
		l["cooked"] = true
	l["br"] = br
	l["ch"] = ch
	return l


func _init() -> void:
	DB.init()
	_go.call_deferred()


func _setup() -> void:
	world = Node3D.new()
	root.add_child(world)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.34, 0.38)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.75, 0.8)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.light_energy = 1.3
	sun.shadow_enabled = true
	world.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-30, -140, 0)
	fill.light_energy = 0.35
	world.add_child(fill)
	cam = Camera3D.new()
	world.add_child(cam)
	cam.current = true


func _sheet(name: String, items: Array, cols: int) -> void:
	if holder:
		holder.queue_free()
	holder = Node3D.new()
	world.add_child(holder)
	var cell := 0.5
	var rows := int(ceil(items.size() / float(cols)))
	for i in items.size():
		var it: Array = items[i]
		var n := Node3D.new()
		holder.add_child(n)
		var x := (i % cols - (cols - 1) * 0.5) * cell
		var z := (i / cols - (rows - 1) * 0.5) * cell
		var inner := Node3D.new()
		n.add_child(inner)
		var d: Dictionary = it[1]
		var aabb: AABB
		if it.size() > 2 and it[2] == "plate":
			var p := Plate.new()
			p.freeze = true
			inner.add_child(p)
			for part in d["parts"]:
				p.add_data(part)
			p.food_root.scale = Vector3.ONE * p.fit
			aabb = AABB(Vector3(-0.18, 0, -0.18), Vector3(0.36, 0.12, 0.36))
		else:
			var b := Models.new(inner)
			b.build(d)
			aabb = b._bounds()
		var k := cell * 0.6 / maxf(maxf(aabb.size.x, aabb.size.z), aabb.size.y * 1.6)
		inner.scale = Vector3.ONE * k
		inner.position = Vector3(-aabb.get_center().x * k, -aabb.position.y * k, -aabb.get_center().z * k)
		n.position = Vector3(x, 0, z)
		var lb := Label3D.new()
		lb.text = it[0]
		lb.font_size = 40
		lb.pixel_size = 0.0012
		lb.rotation_degrees = Vector3(-90, 0, 0)
		lb.position = Vector3(0, 0.001, cell * 0.36)
		lb.modulate = Color(1, 1, 1)
		lb.outline_size = 6
		n.add_child(lb)
	var w := cols * cell
	var h := rows * cell
	cam.position = Vector3.ZERO
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.rotation_degrees = Vector3(-32, 0, 0)
	cam.position = Vector3(0, 0, 0) + cam.global_transform.basis.z * 10.0 + Vector3(0, 0.12, 0)
	cam.size = maxf(h * sin(deg_to_rad(32.0)) + 0.45, w / 1.5 + 0.05)
	for i in 6:
		await process_frame
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("/tmp/food_%s.png" % name)
	print("saved ", name)


func _go() -> void:
	root.size = Vector2i(1800, 1200)
	_setup()
	var ids: Array = DB.ING.keys()
	var close := []
	for id in ["potato", "patty", "orange", "bread_loaf", "ground_beef", "lettuce"]:
		close.append([id, leaf(id)])
	await _sheet("close", close, 3)
	var raw := []
	for id in ids:
		raw.append([id, leaf(id)])
	var per := 24
	for k in int(ceil(raw.size() / float(per))):
		await _sheet("raw%d" % k, raw.slice(k * per, (k + 1) * per), 6)
	var cuts := []
	for id in ids:
		if DB.cut_max(id) >= 1 and not DB.flag(id, "i"):
			cuts.append([id + " c1", leaf(id, 1)])
	for id in ["pizza", "cake", "pie", "toast", "bread_loaf"]:
		cuts.append([id + " c1", leaf(id, 1)])
	for k in int(ceil(cuts.size() / float(per))):
		await _sheet("cut%d" % k, cuts.slice(k * per, (k + 1) * per), 6)
	var misc := []
	for id in ["tomato", "garlic", "cheese", "carrot", "chicken", "onion", "parmesan", "chocolate", "apple", "basil", "beef", "potato"]:
		misc.append([id + " c2", leaf(id, 2)])
	for id in ["tomato", "potato", "apple", "mango"]:
		misc.append([id + " c3", leaf(id, 3)])
	for id in ["potato", "carrot", "tomato", "mushroom"]:
		misc.append([id + " dirty", leaf(id, 0, "", 0.0, 0.0, false)])
	for id in ["chicken", "beef", "bacon", "sausage", "salmon", "shrimp", "patty", "egg"]:
		misc.append([id + " cooked", leaf(id, 0, "fry", 0.75)])
	for id in ["chicken", "beef", "bread", "potato"]:
		misc.append([id + " burnt", leaf(id, 0, "fry", 1.0, 1.0)])
	await _sheet("states", misc, 6)
	var pat := leaf("patty", 0, "fry", 0.8)
	var plates := [
		["burger", {"parts": [leaf("bun"), pat, leaf("cheese", 1), leaf("lettuce", 1), leaf("tomato", 1)]}, "plate"],
		["sandwich", {"parts": [leaf("bread", 1), leaf("ham"), leaf("cheese", 1), leaf("lettuce")]}, "plate"],
		["pizza+", {"parts": [leaf("pizza"), leaf("pepperoni", 1), leaf("mushroom", 1), leaf("basil")]}, "plate"],
		["soup", {"parts": [leaf("broth"), leaf("carrot", 1, "boil", 0.1), leaf("potato", 1, "boil", 0.1), leaf("onion", 1, "boil")]}, "plate"],
		["rice+", {"parts": [leaf("steamed_rice"), leaf("chicken", 1, "fry", 0.7), leaf("broccoli", 1, "boil")]}, "plate"],
		["pancakes", {"parts": [leaf("pancakes"), leaf("blueberry"), leaf("strawberry", 1)]}, "plate"],
		["taco", {"parts": [leaf("tortilla", 0, "fry", 0.4), leaf("ground_beef", 0, "fry", 0.8), leaf("lettuce", 1), leaf("cheese", 2)]}, "plate"],
		["burrito", {"parts": [leaf("tortilla"), leaf("beans"), leaf("rice"), leaf("chicken", 1, "fry", 0.6)]}, "plate"],
		["salad", {"parts": [leaf("lettuce", 1), leaf("tomato", 1), leaf("cucumber", 1)]}, "plate"],
		["steak dinner", {"parts": [leaf("beef", 0, "fry", 0.8), leaf("mashed_potato"), leaf("broccoli", 1, "boil")]}, "plate"],
		["eggs toast", {"parts": [leaf("toast"), leaf("fried_egg"), leaf("bacon", 0, "fry", 0.7)]}, "plate"],
		["pasta", {"parts": [leaf("cooked_pasta"), leaf("tomato_sauce"), leaf("basil")]}, "plate"],
	]
	await _sheet("plates", plates, 4)
	quit()
