class_name Player
extends CharacterBody3D
## First-person cook: walk, look, grab/place (E / left click), use (F / right click),
## throw (Q).

const SPEED := 3.4
const SPRINT := 5.2
const REACH := 2.4
const EYE := 1.62

var game: Node
var cam := Camera3D.new()
var hand := Node3D.new()
var held: RigidBody3D = null
var enabled := false
var sensitivity := 0.0025
var bob_t := 0.0
var target := {}
var _sway := Vector2.ZERO


func _ready() -> void:
	collision_layer = 4
	collision_mask = 1
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)
	cam.position.y = EYE
	cam.fov = 75.0
	cam.near = 0.03
	add_child(cam)
	hand.position = Vector3(0.28, -0.26, -0.55)
	cam.add_child(hand)


func _unhandled_input(e: InputEvent) -> void:
	if not enabled:
		return
	if e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var m := e as InputEventMouseMotion
		rotation.y -= m.relative.x * sensitivity
		cam.rotation.x = clampf(cam.rotation.x - m.relative.y * sensitivity, -1.45, 1.4)
		_sway += m.relative * 0.0004
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
	velocity.x = lerpf(velocity.x, dir.x * spd, 12.0 * delta)
	velocity.z = lerpf(velocity.z, dir.z * spd, 12.0 * delta)
	move_and_slide()
	var flat := Vector2(velocity.x, velocity.z).length()
	if flat > 0.3 and is_on_floor():
		bob_t += delta * flat * 2.6
	cam.position.y = lerpf(cam.position.y, EYE + sin(bob_t * 2.0) * 0.025 * minf(flat, 1.0), 10.0 * delta)
	cam.position.x = cos(bob_t) * 0.015 * minf(flat, 1.0)
	_sway = _sway.lerp(Vector2.ZERO, 8.0 * delta)
	hand.position = Vector3(0.28 - _sway.x, -0.26 + _sway.y + sin(bob_t * 2.0) * 0.01, -0.55)
	if held:
		held.position = held.position.lerp(Vector3.ZERO, 14.0 * delta)
		held.rotation.y = lerp_angle(held.rotation.y, 0.4, 8.0 * delta)
	if enabled:
		target = _ray()
		game.ui.update_prompt(self)


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
	var kind := "surface"
	if n is Food:
		kind = "food"
	elif n is Plate:
		kind = "plate"
	elif n is Station:
		kind = "station"
	elif not n.has_meta("surface"):
		kind = "wall"
	return {"node": n, "kind": kind, "pos": hit["position"], "normal": hit["normal"]}


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
		(b as Food).pop(1.15)
	game.sfx.play("pop", -4.0)


func release() -> RigidBody3D:
	var b := held
	held = null
	return b


func interact() -> void:
	var tk: String = target.get("kind", "")
	var node = target.get("node")
	if held == null:
		match tk:
			"food":
				hold(node)
			"plate":
				hold(node)
			"station":
				_station_empty_hand(node)
		return
	match tk:
		"station":
			_station_holding(node)
		"plate":
			if held is Food:
				var p: Plate = node
				if not p.can_add():
					game.toast("That plate is piled high enough!")
					return
				var f := release()
				p.add_data((f as Food).data)
				f.queue_free()
				game.sfx.play("place")
			else:
				_place_on_surface()
		"food":
			if held is Plate:
				var p: Plate = held
				if not p.can_add():
					game.toast("That plate is piled high enough!")
					return
				p.add_data((node as Food).data)
				node.queue_free()
				game.sfx.play("place")
			else:
				_place_on_surface()
		"surface":
			_place_on_surface()
		_:
			game.toast("Can't put that there")


func _station_empty_hand(st: Station) -> void:
	match st.kind:
		"fridge", "pantry":
			st.bump()
			game.ui.open_pantry(0 if st.kind == "fridge" else 3)
		"plates":
			var p := Plate.new()
			game.items.add_child(p)
			p.global_position = st.global_position + Vector3(0, 0.15, 0)
			hold(p)
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
			game.sfx.play("whoosh")
			if held is Plate and not (held as Plate).items.is_empty():
				(held as Plate).clear()
				game.toast("Plate scraped clean")
			else:
				release().queue_free()
		"fridge", "pantry":
			if held is Food:
				st.bump()
				release().queue_free()
				game.sfx.play("whoosh", -6.0)
			else:
				game.toast("Plates go on the counter")
		"plates":
			if held is Plate and (held as Plate).items.is_empty():
				release().queue_free()
				game.sfx.play("place")
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
				game.sfx.play("place")
				return
			var f: Food = held
			var why := st.accepts(f)
			if why != "":
				game.toast(why)
				game.sfx.play("buzz", -10.0)
				return
			release()
			st.add_food(f)


func _place_on_surface() -> void:
	var n: Vector3 = target.get("normal", Vector3.UP)
	if n.y < 0.6:
		game.toast("Find a flat spot")
		return
	var b := release()
	b.reparent(game.items, true)
	var bottom: float = b.get("bottom")
	b.global_rotation = Vector3(0, rotation.y, 0)
	b.global_position = (target["pos"] as Vector3) + Vector3(0, -bottom + 0.01, 0)
	b.set_carried(false)
	b.linear_velocity = Vector3.ZERO
	if b is Food:
		(b as Food).pop(1.12)
	game.sfx.play("place")


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
	game.sfx.play("whoosh", -6.0)


func drop_held() -> void:
	if held:
		release().queue_free()
