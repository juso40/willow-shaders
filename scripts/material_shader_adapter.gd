class_name MaterialShaderAdapter
extends RefCounted
## Game-data to GPU boundary. Exact shader-name matching with no
## parameter allowlist or sRGB conversion in stored game resources.

static func matching_parameters(source: UnrealMaterialInterface, shader: Shader) -> Dictionary:
	var result: Dictionary = {}
	if not shader: return result
	var scalars := source.resolved_values(&"ScalarParameterValues")
	var vectors := source.resolved_values(&"VectorParameterValues")
	var textures := source.resolved_values(&"TextureParameterValues")
	var switches := source.resolved_static_switches()
	var masks: Dictionary = {}
	var bindings := source.resolved_values(&"static_parameter_bindings")
	var source_masks := source.resolved_static_masks()
	for name: String in source_masks:
		masks[bindings.get(name, name)] = source_masks[name]
	for uniform: Dictionary in shader.get_shader_uniform_list():
		var name := str(uniform.name)
		match int(uniform.type):
			TYPE_FLOAT, TYPE_INT:
				if scalars.has(name): result[name] = int(scalars[name]) if uniform.type == TYPE_INT else scalars[name]
			TYPE_BOOL:
				if switches.has(name): result[name] = switches[name]
			TYPE_OBJECT:
				if textures.has(name) and (textures[name] == null or uniform.hint_string == "Texture2D"):
					result[name] = textures[name]
			TYPE_COLOR, TYPE_VECTOR4, TYPE_VECTOR3, TYPE_VECTOR2:
				if not vectors.has(name) and not masks.has(name): continue
				var value: Vector4 = vectors.get(name, masks.get(name, Vector4.ZERO))
				match int(uniform.type):
					TYPE_COLOR: result[name] = Color(value.x, value.y, value.z, value.w).linear_to_srgb()
					TYPE_VECTOR3: result[name] = Vector3(value.x, value.y, value.z)
					TYPE_VECTOR2: result[name] = Vector2(value.x, value.y)
					_: result[name] = value
	return result

static func apply(source: UnrealMaterialInterface, target: ShaderMaterial) -> void:
	# An explicitly selected shader wins. Otherwise inherit the base material's.
	if not target.shader: target.shader = source.resolved_shader()
	var parameters := matching_parameters(source, target.shader)
	for name: String in target.get_meta("bl2_parameter_names", PackedStringArray()):
		if not parameters.has(name): target.set_shader_parameter(name, null)
	for name: String in parameters: target.set_shader_parameter(name, parameters[name])
	target.set_meta("bl2_parameter_names", PackedStringArray(parameters.keys()))
	target.set_meta("bl2_source", source.source_object)
	target.set_meta("bl2_parent_chain", source.inheritance_chain().map(func(entry): return entry.source_object))
	target.set_meta("bl2_reconstruction", source.notes)
	target.resource_name = source.resource_name
