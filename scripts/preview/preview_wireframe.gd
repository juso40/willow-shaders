class_name PreviewWireframe
extends RefCounted
## Draw actual triangle edges on renderers that do not support polygon line mode.
## Share the line mesh for repeated instances and restore the untouched originals.

var originals: Dictionary[MeshInstance3D, Mesh] = {}
var line_meshes: Dictionary[Mesh, ArrayMesh] = {}

func apply(nodes: Array[MeshInstance3D]) -> void:
	for node in nodes:
		if originals.has(node): continue
		var mesh := node.mesh
		if not line_meshes.has(mesh): line_meshes[mesh] = _lines(mesh)
		originals[node] = mesh
		_swap_mesh(node, line_meshes[mesh])

func restore() -> void:
	for node in originals: _swap_mesh(node, originals[node])
	originals.clear()
	line_meshes.clear()

func _swap_mesh(node: MeshInstance3D, mesh: Mesh) -> void:
	var weights := PackedFloat32Array()
	for i in range(node.get_blend_shape_count()): weights.append(node.get_blend_shape_value(i))
	node.mesh = mesh
	for i in range(weights.size()): node.set_blend_shape_value(i, weights[i])

func _lines(mesh: Mesh) -> ArrayMesh:
	var result := ArrayMesh.new()
	if mesh is ArrayMesh:
		result.blend_shape_mode = mesh.blend_shape_mode
		for b in range(mesh.get_blend_shape_count()): result.add_blend_shape(mesh.get_blend_shape_name(b))
	for surface in range(mesh.get_surface_count()):
		var arrays := mesh.surface_get_arrays(surface)
		var type := Mesh.PRIMITIVE_TRIANGLES
		var flags := 0
		if mesh is ArrayMesh:
			type = mesh.surface_get_primitive_type(surface)
			# Retain custom vertex formats and skin weights, but let Godot infer the
			# new surface's channels and indices rather than reuse its compression.
			var format: int = mesh.surface_get_format(surface)
			flags = format & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS
			for shift in [Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM2_SHIFT, Mesh.ARRAY_FORMAT_CUSTOM3_SHIFT]:
				flags |= format & (Mesh.ARRAY_FORMAT_CUSTOM_MASK << shift)
		if type in [Mesh.PRIMITIVE_TRIANGLES, Mesh.PRIMITIVE_TRIANGLE_STRIP]:
			var indices := PackedInt32Array()
			if arrays[Mesh.ARRAY_INDEX] != null: indices = arrays[Mesh.ARRAY_INDEX]
			var count: int = arrays[Mesh.ARRAY_VERTEX].size() if indices.is_empty() else indices.size()
			var step := 3 if type == Mesh.PRIMITIVE_TRIANGLES else 1
			var lines := PackedInt32Array()
			for i in range(0, count - 2, step):
				var a := i if indices.is_empty() else indices[i]
				var b := i + 1 if indices.is_empty() else indices[i + 1]
				var c := i + 2 if indices.is_empty() else indices[i + 2]
				lines.append(a)
				lines.append(b)
				lines.append(b)
				lines.append(c)
				lines.append(c)
				lines.append(a)
			arrays[Mesh.ARRAY_INDEX] = lines
			type = Mesh.PRIMITIVE_LINES
		result.add_surface_from_arrays(type, arrays, mesh.surface_get_blend_shape_arrays(surface), {}, flags)
	return result
