extends SceneTree
## Headless checks: `godot --headless --path . -s res://tests/run_tests.gd`

var failures := 0


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
		print("FAIL: ", msg)


func leaf(id: String, cut := 0, cook := "") -> Dictionary:
	var l := DB.new_leaf(id)
	l["washed"] = true
	l["cut"] = cut
	if cook != "":
		l["cook"] = cook
		l["cooked"] = true
		l["prog"] = 1.1
		l["pm"] = cook
	return l


## Builds a leaf that satisfies a parsed spec using its first alternative.
func satisfy(sp: Dictionary) -> Dictionary:
	var alt: Dictionary = sp["alts"][0]
	var id: String = alt["id"]
	if alt["any"]:
		id = "tomato"
	elif id == "":
		var cat: String = alt["cats"][0]
		for k in DB.ING:
			if DB.ING[k][1] == cat and not DB.flag(k, "i"):
				id = k
				break
	var cut: int = alt["cut"]
	var cook := ""
	if not (sp["m"] as Array).is_empty():
		cook = sp["m"][0]
	elif sp["any_cook"]:
		cook = "fry"
	var l := leaf(id, mini(cut, 3), "" if cook in DB.COLD else cook)
	if cook in DB.COLD:
		l["cold"] = cook
	l["style"] = alt["style"]
	if alt["coat"]:
		l["coat"] = "crumb"
	return l


func _init() -> void:
	DB.init()
	# every named recipe must be recognisable from ingredients that satisfy it
	for k in DB.recipe_count():
		var rec := DB.recipe(k)
		var ls := []
		var used := {}
		for sp in rec["specs"]:
			var l := satisfy(sp)
			# category specs repeated (e.g. 3 x #fruit) need distinct leaves
			if used.has(l["id"]) and not (sp["alts"][0]["cats"] as Array).is_empty():
				for kid in DB.ING:
					if DB.ING[kid][1] == sp["alts"][0]["cats"][0] and not used.has(kid) and not DB.flag(kid, "i"):
						var nl := leaf(kid, l["cut"], l["cook"])
						nl["coat"] = l["coat"]
						nl["style"] = l["style"]
						nl["cold"] = l["cold"]
						l = nl
						break
			used[l["id"]] = true
			ls.append(l)
		var info := DB.identify(ls)
		check(info["recipe"] >= 0, "recipe not reachable: %s -> got '%s'" % [rec["name"], info["name"]])
	# transformation rules
	var r := DB.apply_rules("mix", [leaf("flour"), leaf("egg", 1), leaf("milk")])
	check(r["made"].size() == 1 and r["made"][0]["id"] == "batter", "flour+egg+milk should mix into batter")
	r = DB.apply_rules("bake", [leaf("dough"), leaf("tomato_sauce"), leaf("mozzarella"), leaf("pepperoni")])
	check(r["made"][0]["id"] == "pizza" and r["rest"].size() == 1, "dough+sauce+mozzarella should bake into pizza")
	var pizza_leaves: Array = r["made"] + r["rest"]
	check(DB.identify(pizza_leaves)["name"] == "Pepperoni Pizza", "pizza + pepperoni should be Pepperoni Pizza, got " + DB.identify(pizza_leaves)["name"])
	r = DB.apply_rules("deepfry", [leaf("potato", 1)])
	check(r["made"][0]["id"] == "fries", "chopped potato should deep fry into fries")
	r = DB.apply_rules("blend", [leaf("strawberry"), leaf("banana"), leaf("milk")])
	check(r["made"][0]["id"] == "smoothie", "fruit + milk should blend into a smoothie")
	check(DB.food_name(r["made"][0]).ends_with("Smoothie"), "smoothie flavour name")
	r = DB.apply_rules("bake", [leaf("cake_batter"), leaf("chocolate")])
	check(DB.identify(r["made"])["name"] == "Chocolate Cake", "cake batter + chocolate -> Chocolate Cake, got " + DB.identify(r["made"])["name"])
	# random combinations always get a sensible, non-empty name and a rating
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var ids := DB.ING.keys()
	var methods := ["", "fry", "boil", "bake", "deepfry"]
	for i in 600:
		var ls := []
		for j in rng.randi_range(1, 7):
			ls.append(leaf(ids[rng.randi() % ids.size()], rng.randi_range(0, 2), methods[rng.randi() % methods.size()]))
		var jd := DB.judge(ls)
		check(String(jd["name"]).length() > 2 and not String(jd["name"]).contains("{}"), "bad name for combo: " + str(jd["name"]))
		check(jd["stars"] >= 0.5 and jd["stars"] <= 5.0, "stars out of range")
	# raw chicken is penalised, cooked is not
	var raw := DB.judge([leaf("chicken")])
	var cooked := DB.judge([leaf("chicken", 0, "bake")])
	check(cooked["stars"] > raw["stars"], "cooked chicken should beat raw chicken")
	check(cooked["name"] == "Roast Chicken", "baked chicken is Roast Chicken, got " + cooked["name"])
	# breading: diced chicken + breadcrumbs (+ egg wash) -> coated pieces -> nuggets when fried
	var dc := leaf("chicken_breast", 1)
	dc["style"] = "dice"
	var co := DB.coat([dc, leaf("breadcrumbs"), leaf("beaten_egg")])
	check(co["coated"].size() == 1 and co["rest"].is_empty(), "breadcrumbs + egg wash coat the chicken and are used up")
	var nug: Dictionary = co["coated"][0]
	nug["cook"] = "deepfry"
	nug["cooked"] = true
	check(DB.identify([nug])["name"] == "Chicken Nuggets", "breaded diced chicken deep-fried = nuggets, got " + DB.identify([nug])["name"])
	# hot dogs need a hot dog bun; a burger bun with a sausage is not a hot dog
	check(DB.identify([leaf("hot_dog_bun"), leaf("frankfurter", 0, "grill")])["name"] == "Hot Dog", "hot dog bun + cooked frank = Hot Dog")
	check(DB.identify([leaf("bun"), leaf("sausage", 0, "fry")])["name"] != "Hot Dog", "burger bun + sausage is not a hot dog")
	# fridge: cream + sugar freezes into ice cream
	var fr := DB.apply_rules("freeze", [leaf("cream"), leaf("sugar"), leaf("strawberry")])
	check(not fr["made"].is_empty() and fr["made"][0]["id"] == "ice_cream", "cream + sugar + fruit freezes into ice cream")
	# sweet + savoury nonsense is marked down vs a sensible off-menu dish
	check(DB.judge([leaf("sprinkles"), leaf("salmon", 0, "fry"), leaf("ketchup")])["stars"] < DB.judge([leaf("salmon", 0, "fry"), leaf("lemon"), leaf("spinach", 0, "fry")])["stars"], "nonsense combos score below sensible ones")
	_runtime.call_deferred()


func _runtime() -> void:
	var had_save := FileAccess.file_exists("user://cook_save.json")
	var old_save := FileAccess.get_file_as_string("user://cook_save.json") if had_save else ""
	var main: Node = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.start("sandbox")
	await process_frame
	var pan: Station = main._station("pan")
	var chicken := Food.make(DB.new_leaf("chicken"))
	main.items.add_child(chicken)
	check(pan.accepts(chicken) == "", "pan should accept chicken")
	pan.add_food(chicken)
	var steps := 0
	while not pan.done_once and steps < 2000:
		pan._tick_cook(0.05)
		steps += 1
	check(pan.done_once, "chicken should finish cooking in the pan")
	var l: Dictionary = DB.leaves((pan.contents[0] as Food).data)[0]
	check(l["cooked"] and l["cook"] == "fry" and not l["burnt"], "chicken should be fried, not burnt")
	for i in 400:
		pan._tick_cook(0.05)
	check(DB.leaves((pan.contents[0] as Food).data)[0]["burnt"], "chicken left on the heat should burn")
	# whisk dough and chop a tomato through real stations
	var board: Station = main._station("board")
	var dough_bits := [Food.make(DB.new_leaf("flour"))]
	var bowl: Station = main._station("bowl")
	for f in dough_bits:
		main.items.add_child(f)
		bowl.add_food(f)
	for i in Station.WHISKS:
		bowl.use()
	check((bowl.contents[0] as Food).data["id"] == "dough", "whisking flour should make dough")
	var tomato := Food.make(DB.new_leaf("tomato"))
	main.items.add_child(tomato)
	check(board.accepts(tomato) == "", "board takes tomato")
	board.add_food(tomato)
	board.choose_style("slice")
	for i in Station.CHOPS - 1:
		board.use()
	check(int(tomato.data["cut"]) == 1 and tomato.data["style"] == "slice", "4 slice chops should slice the tomato")
	var plate := Plate.new()
	main.items.add_child(plate)
	plate.add_data(DB.new_leaf("bun"))
	var patty := DB.new_leaf("patty")
	patty["cooked"] = true
	patty["cook"] = "fry"
	plate.add_data(patty)
	plate.add_data(DB.new_leaf("cheese"))
	check(plate.display_name() == "Cheeseburger", "plate should read Cheeseburger, got " + plate.display_name())
	main.serve(plate)
	check(main.save["found"].size() >= 1, "serving a named dish records a discovery")
	# full player flow: market crate -> sink -> board -> fryer -> plate -> serve
	var pl: Player = main.player
	var crate: Source = null
	for s in main.kitchen.sources:
		if s.id == "potato":
			crate = s
	pl.target = {"kind": "source", "node": crate}
	pl.interact()
	check(pl.held is Food and (pl.held as Food).data["id"] == "potato", "grabbing from the potato crate puts a potato in hand")
	var ids := {}
	for s in main.kitchen.sources:
		ids[s.id] = true
	for id in DB.ING:
		if not DB.flag(id, "i"):
			check(ids.has(id), "ingredient %s has a place in the kitchen" % id)
	var sink: Station = main._station("sink")
	pl.target = {"kind": "station", "node": sink}
	pl.interact()
	check(sink.contents.size() == 1 and pl.held == null, "potato goes into the sink")
	for i in 60:
		sink._tick_sink(0.05)
	check(not (sink.contents[0] as Food).needs_wash(), "sink washes the potato")
	pl.interact()
	check(pl.held is Food, "take the potato back out")
	var board2: Station = null
	for s in main.kitchen.stations:
		if s.kind == "board" and s.contents.is_empty():
			board2 = s
	pl.target = {"kind": "station", "node": board2}
	pl.interact()
	board2.choose_style("dice")
	for i in Station.CHOPS - 1:
		pl.use()
	pl.interact()
	check(pl.held is Food and int((pl.held as Food).data["cut"]) == 1, "chopped potato in hand")
	var fryer: Station = main._station("fryer")
	pl.target = {"kind": "station", "node": fryer}
	pl.interact()
	var n := 0
	while not fryer.done_once and n < 1000:
		fryer._tick_cook(0.05)
		n += 1
	check((fryer.contents[0] as Food).data["id"] == "fries", "fryer turns diced potato into fries")
	pl.target = {"kind": "station", "node": main._station("plates")}
	pl.interact()
	check(pl.held is Plate, "plates station hands out a plate")
	pl.target = {"kind": "station", "node": fryer}
	pl.interact()
	check((pl.held as Plate).leaves().size() == 1 and fryer.contents.is_empty(), "fries scooped onto the plate")
	var before: int = main.served
	pl.target = {"kind": "station", "node": main._station("serve")}
	pl.interact()
	check(pl.held == null and main.served == before + 1, "serving hands the plate over")
	await create_timer(0.2).timeout
	if had_save:
		var f := FileAccess.open("user://cook_save.json", FileAccess.WRITE)
		f.store_string(old_save)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://cook_save.json"))
	print("TESTS DONE failures=%d" % failures)
	quit(1 if failures > 0 else 0)
