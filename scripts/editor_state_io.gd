class_name MaterialEditorStateIO
extends RefCounted
## Document I/O through the engine resource format. One file, embedded sub-resources.

const MAX_MATERIALS := 64
const MAX_ENTRY_BYTES := 268435456

static func save_state(state: MaterialEditorState, path: String) -> String:
	var chain: Array[UnrealMaterialInterface] = []
	if state.material:
		chain = state.material.inheritance_chain()
		if chain.is_empty() or chain.size() > MAX_MATERIALS: return "Invalid material chain"
	var copy := _detach(state, chain)
	var destination := ProjectSettings.globalize_path(path)
	# Keep the target extension on the temporary file, the saver picks its format from it.
	var temporary := "%s.%d.tmp.%s" % [destination.get_basename(), Time.get_ticks_usec(), destination.get_extension()]
	var flags := ResourceSaver.FLAG_COMPRESS if path.get_extension().to_lower() == "res" else 0
	var error := ResourceSaver.save(copy, temporary, flags)
	if error == OK: error = DirAccess.rename_absolute(temporary, destination)
	if error != OK:
		DirAccess.remove_absolute(temporary)
		return "Cannot save state: " + error_string(error)
	return ""

static func load_state(path: String) -> Dictionary:
	var state := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE) as MaterialEditorState
	if state == null: return {"error": "Not a material editor state: " + path.get_file()}
	var message := validate_state(state)
	if not message.is_empty(): return {"error": message}
	_restore_registered_debug_views(state)
	var model: Node3D
	if not state.model_bytes.is_empty():
		var imported := MaterialModelImporter.from_buffer(state.model_bytes, false)
		if not imported.error.is_empty(): return {"error": imported.error}
		model = imported.model
	return {"state": state, "model": model, "error": ""}

static func _restore_registered_debug_views(state: MaterialEditorState) -> void:
	# Version 1 had no profile. Later documents can get additive views if their
	# embedded profile still matches the registered base, shader and old labels.
	var legacy := state.format_version == 1
	state.format_version = MaterialEditorState.FORMAT_VERSION
	var base := MaterialParameterCatalog.master_for(state.material) as UnrealMaterial
	if not base or not base.shader or (not legacy and not base.debug_profile): return
	const REGISTRY := "res://presets/shader_profiles.json"
	if not FileAccess.file_exists(REGISTRY): return
	var registry: Variant = JSON.parse_string(FileAccess.get_file_as_string(REGISTRY))
	if not registry is Dictionary: return
	var registration: Dictionary = registry.get(base.source_object, {})
	var path: String = registration.get("debug_profile", "")
	if registration.get("shader") != base.shader.resource_path or path.is_empty() or not ResourceLoader.exists(path): return
	var registered := load(path) as MaterialDebugProfile
	if not registered: return
	var embedded := base.debug_profile
	if not embedded:
		base.debug_profile = registered
		return
	if embedded.shader != registered.shader or embedded.section != registered.section or embedded.provides_unlit != registered.provides_unlit: return
	for id: int in embedded.views:
		if registered.views.get(id) != embedded.views[id]: return
	if embedded.views.size() < registered.views.size(): base.debug_profile = registered

static func validate_state(state: MaterialEditorState) -> String:
	if state.format_version not in [1, MaterialEditorState.FORMAT_VERSION]: return "Unsupported state version"
	if state.material and state.material.inheritance_chain().size() > MAX_MATERIALS: return "State material chain is too long"
	if state.model_bytes.size() > MAX_ENTRY_BYTES: return "State model is too large"
	if not _valid_view(state.view) or not _valid_inspector(state.inspector): return "Invalid view state"
	return ""

static func _detach(state: MaterialEditorState, chain: Array[UnrealMaterialInterface]) -> MaterialEditorState:
	# Unpathed copies serialize as embedded sub-resources, so the file needs no
	# external corpus, texture cache or model on reopening.
	var copy := MaterialEditorState.new()
	copy.format_version = state.format_version
	copy.model_bytes = state.model_bytes
	copy.model_name = state.model_name
	copy.view = state.view.duplicate(true)
	copy.inspector = state.inspector.duplicate(true)
	var previous: UnrealMaterialInterface
	for index in range(chain.size()):
		var clone := _clone_material(chain[index])
		if index > 0: clone.Parent = previous
		previous = clone
	copy.material = previous as MaterialInstanceConstant
	return copy

static func _clone_material(entry: UnrealMaterialInterface) -> UnrealMaterialInterface:
	var clone: UnrealMaterialInterface = UnrealMaterial.new() if entry is UnrealMaterial else MaterialInstanceConstant.new()
	clone.source_object = entry.source_object
	clone.resource_name = entry.resource_name
	clone.unreal_class = entry.unreal_class
	clone.parent_object_path = entry.parent_object_path
	clone.notes = entry.notes
	clone.shader = entry.shader
	if entry is UnrealMaterial and entry.debug_profile:
		clone.debug_profile = entry.debug_profile.duplicate()
	for name: String in entry.ScalarParameterValues: clone.ScalarParameterValues[name] = entry.ScalarParameterValues[name]
	for name: String in entry.VectorParameterValues: clone.VectorParameterValues[name] = entry.VectorParameterValues[name]
	for name: String in entry.static_component_masks: clone.static_component_masks[name] = entry.static_component_masks[name]
	for name: String in entry.static_switches: clone.static_switches[name] = entry.static_switches[name]
	for name: String in entry.texture_object_paths: clone.texture_object_paths[name] = entry.texture_object_paths[name]
	for name: String in entry.texture_object_classes: clone.texture_object_classes[name] = entry.texture_object_classes[name]
	for name: String in entry.static_parameter_bindings: clone.static_parameter_bindings[name] = entry.static_parameter_bindings[name]
	for name: String in entry.TextureParameterValues:
		var texture: Texture2D = entry.TextureParameterValues[name]
		clone.TextureParameterValues[name] = null if texture == null else _embedded_texture(texture)
	return clone

static func _embedded_texture(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null or image.is_empty(): return texture
	var fresh := ImageTexture.create_from_image(image)
	fresh.resource_name = texture.resource_name
	return fresh

static func _number(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value))

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	return _number(value) and value == floor(value) and value >= minimum and value <= maximum

static func _vector(value: Variant, size: int) -> bool:
	if not value is Array or value.size() != size: return false
	for component in value:
		if not _number(component): return false
	return true

static func _valid_view(view: Variant) -> bool:
	if not view is Dictionary: return false
	for key in ["yaw", "pitch", "distance"]:
		if view.has(key) and not _number(view[key]): return false
	if view.has("distance") and (view.distance < 0.05 or view.distance > 1e9): return false
	if view.has("pitch") and absf(view.pitch) > PI * 0.49: return false
	if view.has("offset") and not _vector(view.offset, 3): return false
	if view.has("model_offset") and not _vector(view.model_offset, 3): return false
	if view.has("fov") and (not _number(view.fov) or view.fov < 1 or view.fov > 179): return false
	if view.has("keep_aspect") and not _integer(view.keep_aspect, 0, 1): return false
	if view.get("shape", "Custom") not in MaterialPreviewStage.SHAPES: return false
	if not view.get("view_texture", "") is String or not view.get("display_mode", 0) is int: return false
	for field in ["visibility", "custom_visibility"]:
		var visibility: Variant = view.get(field, {})
		if not visibility is Dictionary: return false
		for key in visibility:
			if not key is String or not visibility[key] is bool: return false
	return true

static func _valid_inspector(inspector: Variant) -> bool:
	if not inspector is Dictionary: return false
	if not _integer(inspector.get("tab", 0), 0, 3): return false
	if not inspector.get("query", "") is String or not inspector.get("local_only", false) is bool: return false
	return _integer(inspector.get("split", 600), -10000, 10000) and _integer(inspector.get("scroll", 0), 0, 1000000)
