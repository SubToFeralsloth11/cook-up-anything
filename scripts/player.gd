class_name Player
extends CharacterBody3D
## First-person cook: walk, look, grab/place (E / left click), use (F / right click),
## throw (Q).

const SPEED := 3.2
const SPRINT := 5.0
const REACH := 2.4
const EYE := 1.64
const HAND := Vector3(0.26, -0.25, -0.55)

var game: Node
var cam := Camera3D.new()
var hand := Node3D.new()
var held: RigidBody3D = null
var enabled := false
var sensitivity := 0.0024
var bob_t := 0.0
var target := {}
var _sway := Vector2.ZERO
var _step_phase := 0.0
var _hand_pull := 0.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.28
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)
	cam.position.y = EYE
	cam.fov = 72.0
	cam.near = 0.02
	add_child(cam)
	hand.position = HAND
	cam.add_child(hand)


func _unhandled_input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := e as InputEventMouseMotion
		rotation.y -= m.relative.x * sensitivity
		cam.rotation.x = clampf(cam.rotation.x - m.relative.y * sensitivity, -1.45, 1.4)
		_sway += m.relative * 0.00035
	elif e.is_action_pressed("interact"):
		interact()
	elif e.is_action_pressed("use"):
		use()
	elif e.is_action_pressed("throw"):
		throw()


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	var dir := Vector3.ZERO
	if enabled:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (transform.basis * Vector3(input.x, 0, input.y)).normalized()
	var spd := SPRINT if Input.is_action_pressed("sprint") else SPEED
	velocity.x = lerpf(velocity.x, dir.x * spd, 10.0 * delta)
	velocity.z = lerpf(velocity.z, dir.z * spd, 10.0 * delta)
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z).length()
	if flat > 0.3 and is_on_floor():
		bob_t += delta * flat * 2.4
		var phase := floorf(bob_t / PI)
		if phase != _step_phase:
			_step_phase = phase
			game.sfx.play("footstep", -16.0 + minf(flat, 5.0), 0.12)
	var bob := minf(flat / SPEED, 1.0)
	cam.position.y = lerpf(cam.position.y, EYE + sin(bob_t * 2.0) * 0.018 * bob, 10.0 * delta)
	cam.position.x = cos(bob_t) * 0.012 * bob
	_sway = _sway.lerp(Vector2.ZERO, 8.0 * delta)
	if enabled:
		target = _ray()
		game.ui.update_prompt(self)
	# pull the held item back when facing something close, so it never clips into walls
	var dist: float = target.get("dist", 9.0)
	var want := clampf(0.75 - dist, 0.0, 0.32)
	_hand_pull = lerpf(_hand_pull, want, 12.0 * delta)
	hand.position = HAND + Vector3(-_sway.x, _sway.y + sin(bob_t * 2.0) * 0.008 * bob, _hand_pull)
	if held:
		held.position = held.position.lerp(Vector3.ZERO, 14.0 * delta)
		held.rotation.y = lerp_angle(held.rotation.y, 0.4, 8.0 * delta)


func _ray() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var from := cam.global_position
	var to := from - cam.global_transform.basis.z * REACH
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 2)
	if held:
		q.exclude = [held.get_rid()]
	var hit := space.intersect_ray(q)
	if hit.is_empty():
		return {}
	var n: Node = hit["collider"]
	var kind := "wall"
	if n is Food:
		kind = "food"
	elif n is Plate:
		kind = "plate"
	elif n is Station:
		kind = "station"
	elif n is Source:
		kind = "source"
	elif n.has_meta("surface"):
		kind = "surface"
	return {"node": n, "kind": kind, "pos": hit["position"], "normal": hit["normal"],
		"dist": from.distance_to(hit["position"])}


# ------------------------------------------------------------------ actions

func hold(b: RigidBody3D) -> void:
	held = b
	b.set_carried(true)
	if b.get_parent():
		b.reparent(hand, true)
	else:
		hand.add_child(b)
	b.scale = Vector3.ONE
	if b is Food:
		(b as Food).pop(1.12)
	game.sfx.play("pop", -6.0)


func release() -> RigidBody3D:
	var b := held
	held = null
	return b


func interact() -> void:
	var tk: String = target.get("kind", "")
	var node = target.get("node")
	if held == null:
		match tk:
			"food", "plate":
				hold(node)
			"source":
				_grab(node)
			"station":
				_station_empty_hand(node)
		return
	match tk:
		"station":
			_station_holding(node)
		"source":
			var src: Source = node
			if held is Food and (held as Food).data.get("id") == src.id and int((held as Food).data.get("cut", 0)) == 0 and not (held as Food).data.get("cooked", false):
				release().queue_free()
				src.pop()
				game.sfx.play_at("place", src.global_position, -6.0)
			else:
				game.toast("Your hands are full")
		"plate":
			if held is Food:
				var p: Plate = node
				var hf: Food = held
				if is_topping(hf) and not p.items.is_empty():
					if DB.is_dust(hf.data["id"]):
						var l := topping_leaf(hf)
						l["sstyle"] = "dust"
						p.add_data(l)
						game.sfx.play_at("whisk", p.global_position, -6.0)
						game.toast("Sprinkled %s over it" % DB.ING[hf.data["id"]][0])
					else:
						game.ui.open_sauce_menu(p, hf)
					return
				var f := release()
				p.add_data((f as Food).data)
				f.queue_free()
				game.sfx.play_at("plate", p.global_position, -6.0)
			else:
				_place_on_surface()
		"food":
			var tf: Food = node
			if held is Plate:
				var p: Plate = held
				p.add_data(tf.data)
				tf.queue_free()
				game.sfx.play("plate", -8.0)
			elif is_topping(held):
				var l := topping_leaf(held)
				l["sstyle"] = "dust" if DB.is_dust(l["id"]) else "drizzle"
				tf.data = DB.merge([tf.data, l], "top")
				tf.rebuild()
				tf.mark_changed()
				tf.pop(1.1)
				game.sfx.play_at("whisk" if l["sstyle"] == "dust" else "splash", tf.global_position, -8.0)
			else:
				# put one food onto another: they become one assembled thing (bun + sausage = hot dog)
				var f := release() as Food
				DB.portion(f.data)
				tf.data = DB.merge([tf.data, f.data], "stack")
				f.queue_free()
				tf.rebuild()
				tf.mark_changed()
				tf.pop(1.15)
				game.sfx.play_at("plate", tf.global_position, -8.0)
				game.float_text(tf.global_position + Vector3(0, 0.25, 0), tf.display_name(), Color(1, 0.9, 0.6))
		"surface":
			_place_on_surface()
		_:
			game.toast("Can't put that there")


func _grab(src: Source) -> void:
	var f := Food.make(DB.new_leaf(src.id))
	game.items.add_child(f)
	f.global_position = src.global_position + Vector3(0, 0.08, 0)
	src.pop()
	hold(f)


func _station_empty_hand(st: Station) -> void:
	match st.kind:
		"plates":
			var p := Plate.new()
			game.items.add_child(p)
			p.global_position = st.global_position + Vector3(0, 0.15, 0)
			hold(p)
			game.sfx.play_at("plate", st.global_position, -4.0)
		"trash", "serve":
			game.toast(st.status_text())
		_:
			var f := st.take()
			if f:
				hold(f)
				f.set_carried(true)
			else:
				game.toast("The %s is empty" % st.title())


func _station_holding(st: Station) -> void:
	match st.kind:
		"trash":
			st.bump()
			game.sfx.play_at("whoosh", st.global_position, -4.0)
			if held is Plate and not (held as Plate).items.is_empty():
				(held as Plate).clear()
				game.toast("Plate scraped clean")
			else:
				release().queue_free()
		"plates":
			if held is Plate and (held as Plate).items.is_empty():
				release().queue_free()
				game.sfx.play_at("plate", st.global_position, -4.0)
			else:
				game.toast("Serve or bin that first")
		"serve":
			var b := release()
			game.serve(b)
		_:
			if held is Plate:
				var p: Plate = held
				var datas := st.take_all_data()
				if datas.is_empty():
					game.toast("Nothing to scoop out")
					return
				for d in datas:
					p.add_data(d)
				game.sfx.play("plate", -8.0)
				return
			var f: Food = held
			if is_topping(held) and not st.contents.is_empty() and st.kind in ["pan", "pot", "fryer", "oven", "grill", "microwave", "bowl", "blender", "fridge"]:
				# pour / sprinkle some in, keep the bottle
				if st.is_full():
					game.toast("The %s is full" % st.title())
					return
				var pf := Food.make(topping_leaf(f))
				game.items.add_child(pf)
				pf.global_position = f.global_position
				st.add_food(pf)
				return
			var why := st.accepts(f)
			if why != "":
				game.toast(why)
				game.sfx.play("buzz", -14.0)
				return
			release()
			st.add_food(f)


## Is the held thing something you pour, squeeze or sprinkle (and keep holding)?
func is_topping(b: RigidBody3D) -> bool:
	if not b is Food:
		return false
	var id: String = (b as Food).data["id"]
	return id != "mix" and DB.is_topping(id)


## A serving of the held topping (the bottle/jar stays in your hand).
func topping_leaf(b: Food) -> Dictionary:
	var l: Dictionary = b.data.duplicate(true)
	if DB.is_pack(l["id"]):
		l["portion"] = true
	return l


func _place_on_surface() -> void:
	var n: Vector3 = target.get("normal", Vector3.UP)
	if n.y < 0.6:
		game.toast("Find a flat spot")
		return
	var b := release()
	b.reparent(game.items, true)
	var bottom: float = b.get("bottom")
	b.global_rotation = Vector3(0, rotation.y, 0)
	b.global_position = (target["pos"] as Vector3) + Vector3(0, -bottom + 0.004, 0)
	b.set_carried(false)
	b.linear_velocity = Vector3.ZERO
	if b is Food:
		(b as Food).pop(1.08)
	var surf := "plate" if b is Plate else "place_wood"
	game.sfx.play_at(surf, b.global_position, -4.0)


func use() -> void:
	if target.get("kind", "") == "station":
		var why: String = (target["node"] as Station).use()
		if why != "":
			game.toast(why)


func throw() -> void:
	if held == null:
		return
	var b := release()
	b.reparent(game.items, true)
	b.set_carried(false)
	b.linear_velocity = -cam.global_transform.basis.z * 5.5 + Vector3.UP * 1.2 + velocity
	b.angular_velocity = Vector3(0, randf_range(-8, 8), 0)
	game.sfx.play("whoosh", -8.0)


func drop_held() -> void:
	if held:
		release().queue_free()
