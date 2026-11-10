class_name Batch
extends RefCounted
## Merges static MeshInstance3D descendants of a node into one mesh per
## (material, vertex format). Cuts hundreds of draw calls to a handful.
## Nodes with meta "nobatch" (and everything below them) are left alone.


static func merge(root: Node3D) -> int:
	var groups := {}
	var originals: Array = []
	var inv := root.global_transform.affine_inverse()
	_collect(root, root, inv, groups, originals)
	var merged := 0
	for key in groups:
		var g: Dictionary = groups[key]
		if (g["count"] as int) < 2:
			continue
		var st: SurfaceTool = g["st"]
		var mesh := st.commit()
		mesh.surface_set_material(0, g["mat"])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.cast_shadow = g["shadow"]
		mi.set_meta("nobatch", true)
		root.add_child(mi)
		merged += 1
		for src in g["nodes"]:
			(src as MeshInstance3D).set_meta("merged", true)
	for o in originals:
		var mi := o as MeshInstance3D
		if mi.has_meta("merged"):
			mi.queue_free()
	return merged


static func _collect(node: Node, root: Node3D, inv: Transform3D, groups: Dictionary, originals: Array) -> void:
	for c in node.get_children():
		if c.has_meta("nobatch"):
			continue
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.visible and mi.mesh != null and mi.get_child_count() == 0:
				_add(mi, inv, groups, originals)
		if c is Node3D and not (c is Label3D) and not (c is GPUParticles3D) and not (c is CPUParticles3D):
			_collect(c, root, inv, groups, originals)


static func _add(mi: MeshInstance3D, inv: Transform3D, groups: Dictionary, originals: Array) -> void:
	var mesh := mi.mesh
	if mesh.get_surface_count() != 1:
		return
	var mat: Material = mi.material_override
	if mat == null:
		mat = mi.get_surface_override_material(0)
	if mat == null:
		mat = mesh.surface_get_material(0)
	if mat == null or mat is ShaderMaterial and (mat as ShaderMaterial).shader and String((mat as ShaderMaterial).shader.code).contains("instance uniform"):
		return
	var fmt := (mesh as ArrayMesh).surface_get_format(0) & 0xFF if mesh is ArrayMesh else -1
	var key := "%d|%d|%d" % [mat.get_instance_id(), fmt, int(mi.cast_shadow)]
	if not groups.has(key):
		var st := SurfaceTool.new()
		groups[key] = {"st": st, "mat": mat, "count": 0, "nodes": [], "shadow": mi.cast_shadow}
	var g: Dictionary = groups[key]
	(g["st"] as SurfaceTool).append_from(mesh, 0, inv * mi.global_transform)
	g["count"] = int(g["count"]) + 1
	(g["nodes"] as Array).append(mi)
	originals.append(mi)
