extends SceneTree
## Throwaway: draw calls for ~80 raw ingredient displays.

func _init() -> void:
	DB.init()
	_go.call_deferred()


func _info() -> String:
	return "draws=%d objects=%d prims=%d" % [
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
		RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)]


func _go() -> void:
	root.size = Vector2i(1280, 720)
	var world := Node3D.new()
	root.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, 35, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var cam := Camera3D.new()
	world.add_child(cam)
	cam.position = Vector3(0, 1.4, 2.6)
	cam.look_at(Vector3(0, 0.4, 0))
	for i in 10:
		await process_frame
	print("baseline ", _info())
	var ids := []
	for id in DB.ING:
		if not DB.flag(id, "i"):
			ids.append(id)
	var t0 := Time.get_ticks_usec()
	var n := 0
	for k in 80:
		var id: String = ids[k % ids.size()]
		var node := Node3D.new()
		node.position = Vector3((k % 10 - 4.5) * 0.3, 0.1 + (k / 10) * 0.12, -(k / 10) * 0.05)
		node.scale = Vector3.ONE * 0.5
		world.add_child(node)
		var l := DB.new_leaf(id)
		l["washed"] = true
		Models.new(node).build(l)
		n += 1
	print("built %d displays in %.1f ms" % [n, (Time.get_ticks_usec() - t0) / 1000.0])
	for i in 10:
		await process_frame
	print("80 displays ", _info())
	sun.shadow_enabled = false
	for i in 6:
		await process_frame
	print("80 displays, no shadows ", _info())
	var t1 := Time.get_ticks_usec()
	var made := 0
	for id in DB.ING:
		if DB.flag(id, "i"):
			Models.leaf_mesh(DB.new_leaf(id))
			made += 1
	print("made dishes: %d meshes in %.1f ms" % [made, (Time.get_ticks_usec() - t1) / 1000.0])
	var t2 := Time.get_ticks_usec()
	var cuts := 0
	for id in DB.ING:
		for c in range(1, DB.cut_max(id) + 1):
			var l := DB.new_leaf(id)
			l["cut"] = c
			Models.leaf_mesh(l)
			cuts += 1
	print("cut states: %d meshes in %.1f ms" % [cuts, (Time.get_ticks_usec() - t2) / 1000.0])
	quit()
