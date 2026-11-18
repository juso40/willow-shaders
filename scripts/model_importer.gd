class_name MaterialModelImporter
extends RefCounted
## Godot imports and exports geometry. Imported appearance, lights and cameras are discarded.

static func from_buffer(bytes: PackedByteArray, canonicalize := true) -> Dictionary:
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	state.create_animations = false
	state.handle_binary_image = GLTFState.HANDLE_BINARY_DISCARD_TEXTURES
	var error := document.append_from_buffer(bytes, "", state)
	if error != OK: return {"error": "Model import failed: " + error_string(error)}
	var model := document.generate_scene(state) as Node3D
	if not model: return {"error": "No model in GLB"}
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	if model is MeshInstance3D: meshes.push_front(model)
	if meshes.is_empty():
		model.free()
		return {"error": "No meshes in GLB"}
	for node in model.find_children("*", "", true, false):
		if node is Camera3D or node is Light3D or node is WorldEnvironment:
			var replacement := Node3D.new()
			replacement.name = node.name
			if node is Node3D: replacement.transform = node.transform
			node.replace_by(replacement)
			node.free()
	for mesh: MeshInstance3D in meshes:
		mesh.material_override = null
		for surface in range(mesh.get_surface_override_material_count()): mesh.set_surface_override_material(surface, null)
		if mesh.mesh:
			for surface in range(mesh.mesh.get_surface_count()): mesh.mesh.surface_set_material(surface, null)
	if not canonicalize: return {"model": model, "bytes": bytes, "error": ""}
	# Re-export the cleaned model so saved states do not retain the discarded images.
	var clean_document := GLTFDocument.new()
	var clean_state := GLTFState.new()
	error = clean_document.append_from_scene(model, clean_state)
	if error != OK:
		model.free()
		return {"error": "Cannot prepare model: " + error_string(error)}
	var clean_bytes := clean_document.generate_buffer(clean_state)
	if clean_bytes.is_empty():
		model.free()
		return {"error": "Cannot prepare model"}
	model.free()
	# Use the canonical tree immediately so saved mesh paths match on reopening.
	return from_buffer(clean_bytes, false)
