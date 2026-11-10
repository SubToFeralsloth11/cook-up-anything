extends SceneTree
# Throwaway benchmark: busy kitchen, vsync off, prints avg FPS + draw calls, saves screenshots.

var main: Node


func put(st: Station, id: String, cut := 0) -> void:
	var l := DB.new_leaf(id)
	l["cut"] = cut
	l["washed"] = true
	var f := Food.make(l)
	main.items.add_child(f)
	st.add_food(f)


func _init() -> void:
	_go.call_deferred()


func measure(label: String, secs: float) -> void:
	var frames := 0
	var t0 := Time.get_ticks_usec()
	while Time.get_ticks_usec() - t0 < secs * 1000000.0:
		await process_frame
		frames += 1
	var dt := (Time.get_ticks_usec() - t0) / 1000000.0
	var dc := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var ob := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
	print("BENCH %s fps=%.1f frame_ms=%.2f draw_calls=%d objects=%d" % [label, frames / dt, dt * 1000.0 / frames, dc, ob])


func shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("/tmp/bench_%s.png" % n)


func _go() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 30:
		await process_frame
	main.start("sandbox")
	put(main._station("pan"), "chicken", 1)
	put(main._station("pan"), "bell_pepper", 1)
	put(main._station("pan"), "onion", 1)
	put(main._station("pot"), "pasta")
	put(main._station("pot"), "tomato")
	put(main._station("pot"), "carrot", 1)
	put(main._station("fryer"), "potato", 1)
	put(main._station("oven"), "dough")
	put(main._station("board"), "carrot", 1)
	put(main._station("sink"), "lettuce")
	put(main._station("bowl"), "flour")
	put(main._station("bowl"), "egg", 1)
	for i in 12:
		var f := Food.make(DB.new_leaf(["tomato", "apple", "cheese", "bread", "banana", "corn"][i % 6]))
		main.items.add_child(f)
		f.global_position = Vector3(-1.0 + (i % 6) * 0.4, 1.1, 0.1 + (i / 6) * 0.4)
	var pl: Player = main.player
	pl.position = Vector3(0.2, 0.05, 2.0)
	pl.cam.rotation.x = -0.3
	for i in 60:
		await process_frame
	await measure("overview", 3.0)
	await shot("overview")
	pl.position = Vector3(-3.4, 0.05, -0.6)
	pl.rotation.y = PI / 2
	pl.cam.rotation.x = -0.5
	for i in 30:
		await process_frame
	await measure("stove", 2.0)
	await shot("stove")
	pl.position = Vector3(-1.0, 0.05, -2.6)
	pl.rotation.y = 0.0
	pl.cam.rotation.x = -0.6
	for i in 30:
		await process_frame
	await shot("back")
	pl.position = Vector3(-3.6, 0.05, 1.0)
	pl.rotation.y = PI / 2
	pl.cam.rotation.x = -0.75
	main._station("oven").door_open = false
	for i in 30:
		await process_frame
	await shot("oven")
	quit()
