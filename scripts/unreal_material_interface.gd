@tool
class_name UnrealMaterialInterface
extends Resource
## Game data only. MICs and base Materials share named, typed parameter storage.
## All vector values are raw linear FLinearColor/data components, never sRGB.

@export var Parent: UnrealMaterialInterface:
	set(value):
		if value == self or (value and self in value.inheritance_chain()):
			push_error("Material parent cycle rejected: " + source_object)
			return
		if Parent and Parent.changed.is_connected(_on_parent_changed): Parent.changed.disconnect(_on_parent_changed)
		Parent = value
		if Parent: Parent.changed.connect(_on_parent_changed)
		emit_changed()
@export var source_object: String
@export var unreal_class: String
@export var parent_object_path: String
@export var shader: Shader:
	set(value):
		shader = value
		emit_changed()
@export var ScalarParameterValues: Dictionary[String, float] = {}:
	set(value):
		ScalarParameterValues = value
		emit_changed()
@export var VectorParameterValues: Dictionary[String, Vector4] = {}:
	set(value):
		VectorParameterValues = value
		emit_changed()
@export var TextureParameterValues: Dictionary[String, Texture2D] = {}:
	set(value):
		TextureParameterValues = value
		emit_changed()
@export_group("Texture identities / editor provenance")
@export var texture_object_paths: Dictionary[String, String] = {}:
	set(value):
		texture_object_paths = value
		emit_changed()
@export var texture_object_classes: Dictionary[String, String] = {}
@export_multiline var notes: String
@export_group("Original static parameters / shader binding aliases")
@export var static_component_masks: Dictionary[String, Vector4] = {}:
	set(value):
		static_component_masks = value
		emit_changed()
@export var static_switches: Dictionary[String, bool] = {}:
	set(value):
		static_switches = value
		emit_changed()
@export var static_parameter_bindings: Dictionary[String, String] = {}

# Read/API compatibility for older callers. These aliases are not serialized.
var parent: UnrealMaterialInterface:
	get: return Parent
	set(value): Parent = value
var scalar_parameters: Dictionary[String, float]:
	get: return ScalarParameterValues
	set(value):
		ScalarParameterValues.assign(value)
		_discard_legacy_keys(ScalarParameterValues)
		emit_changed()
var vector_parameters: Dictionary[String, Vector4]:
	get: return VectorParameterValues
	set(value):
		VectorParameterValues.merge(value, true)
		_discard_legacy_keys(VectorParameterValues)
		emit_changed()
var texture_parameters: Dictionary[String, Texture2D]:
	get: return TextureParameterValues
	set(value):
		TextureParameterValues.assign(value)
		_discard_legacy_keys(TextureParameterValues)
		emit_changed()

func _on_parent_changed() -> void:
	emit_changed()

func inheritance_chain() -> Array[UnrealMaterialInterface]:
	var chain: Array[UnrealMaterialInterface] = []
	var cursor: UnrealMaterialInterface = self
	while cursor:
		if cursor in chain:
			push_error("Material parent cycle: " + source_object)
			return []
		chain.push_front(cursor)
		cursor = cursor.Parent
	return chain

func resolved_values(property: StringName) -> Dictionary:
	var result: Dictionary = {}
	for entry in inheritance_chain(): result.merge(entry.get(property), true)
	return result

func get_scalar_parameter_value(name: String, fallback := 0.0) -> float:
	return float(resolved_values(&"ScalarParameterValues").get(name, fallback))

func set_scalar_parameter_value(name: String, value: float) -> void:
	ScalarParameterValues[name] = value
	emit_changed()

func get_vector_parameter_value(name: String, fallback := Vector4.ZERO) -> Vector4:
	return resolved_values(&"VectorParameterValues").get(name, fallback)

func set_vector_parameter_value(name: String, value: Vector4) -> void:
	VectorParameterValues[name] = value
	emit_changed()

func get_texture_parameter_value(name: String) -> Texture2D:
	return resolved_values(&"TextureParameterValues").get(name)

func set_texture_parameter_value(name: String, value: Texture2D) -> void:
	TextureParameterValues[name] = value
	emit_changed()

func game_parameters() -> Dictionary:
	return {"scalar": resolved_values(&"ScalarParameterValues"),
		"vector": resolved_values(&"VectorParameterValues"), "texture": resolved_texture_paths()}

func resolved_texture_paths() -> Dictionary[String, String]:
	var result: Dictionary[String, String] = {}
	result.assign(resolved_values(&"texture_object_paths"))
	return result

func resolved_static_masks() -> Dictionary:
	return resolved_values(&"static_component_masks")

func resolved_static_switches() -> Dictionary:
	return resolved_values(&"static_switches")

func resolved_shader() -> Shader:
	var result: Shader
	for entry in inheritance_chain():
		if entry.shader: result = entry.shader
	return result

func resolved_parameters(target_shader: Shader = null) -> Dictionary:
	return MaterialShaderAdapter.matching_parameters(self, target_shader if target_shader else resolved_shader())

func create_shader_material(target_shader: Shader = null) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = target_shader if target_shader else resolved_shader()
	apply_to_material(result)
	return result

func apply_to_material(target: ShaderMaterial) -> void:
	MaterialShaderAdapter.apply(self, target)

func set_shader_parameter(name: String, value: Variant) -> void:
	# UI compatibility only. Named game setters above always take RAW game values.
	if name.begins_with("bl_"): return
	if value is Color:
		var linear: Color = value.srgb_to_linear()
		set_vector_parameter_value(name, Vector4(linear.r, linear.g, linear.b, linear.a))
	elif value is Vector4: set_vector_parameter_value(name, value)
	elif value is Texture2D: set_texture_parameter_value(name, value)
	elif value is bool:
		static_switches[name] = value
		emit_changed()
	else: set_scalar_parameter_value(name, float(value))

func set_texture_binding(name: String, value: Texture2D, object_path: String, object_class := "Texture2D") -> void:
	texture_object_paths[name] = object_path
	texture_object_classes[name] = object_class
	set_texture_parameter_value(name, value)

func set_static_component_mask(name: String, value: Vector4) -> void:
	static_component_masks[name] = Vector4(float(value.x != 0), float(value.y != 0), float(value.z != 0), float(value.w != 0))
	emit_changed()

func has_local_override(name: String, category := "dynamic") -> bool:
	if category == "static_mask": return static_component_masks.has(name)
	if category == "static_switch": return static_switches.has(name)
	for parameters in [ScalarParameterValues, VectorParameterValues, TextureParameterValues, texture_object_paths]:
		if parameters.has(name): return true
	return false

func clear_override(name: String, category := "dynamic") -> void:
	if category == "static_mask": static_component_masks.erase(name)
	elif category == "static_switch": static_switches.erase(name)
	else:
		for parameters in [ScalarParameterValues, VectorParameterValues, TextureParameterValues, texture_object_paths, texture_object_classes]: parameters.erase(name)
	emit_changed()

func _discard_legacy_keys(parameters: Dictionary) -> void:
	MaterialLegacyMigration.migrate_statics(self, parameters)
	for name: String in parameters.keys():
		if name.begins_with("bl_") or name == "sw_FlipDecalOnRightSide": parameters.erase(name)

func _set(property: StringName, value: Variant) -> bool:
	if property == &"color_parameters" and value is Dictionary:
		for name: String in value:
			if name.begins_with("bl_"): continue
			var color: Color = value[name]
			VectorParameterValues[name] = Vector4(color.r, color.g, color.b, color.a)
		return true
	if property == &"port_parameters" and value is Dictionary:
		MaterialLegacyMigration.migrate_statics(self, value)
		return true
	return false
