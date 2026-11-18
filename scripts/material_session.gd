class_name MaterialEditorSession
extends Node
## Editable material data and its optional shader preview.

signal material_changed(value: ShaderMaterial)
signal instance_changed(value: MaterialInstanceConstant)
signal selection_changed(value: UnrealMaterialInterface)

var source: UnrealMaterialInterface
var instance: MaterialInstanceConstant
var preview_material: ShaderMaterial

func select_material(value: UnrealMaterialInterface) -> void:
	if value == null: return
	var edited := MaterialInstanceConstant.new()
	edited.Parent = value
	edited.source_object = value.source_object
	edited.resource_name = value.resource_name
	open_instance(edited)

func open_instance(value: MaterialInstanceConstant) -> void:
	if instance and instance.changed.is_connected(_refresh_material):
		instance.changed.disconnect(_refresh_material)
	instance = value
	source = value.Parent if value else null
	preview_material = value.create_shader_material() if value else null
	if instance: instance.changed.connect(_refresh_material)
	selection_changed.emit(source)
	instance_changed.emit(instance)
	_refresh_material()

func _refresh_material() -> void:
	if instance:
		preview_material.shader = instance.resolved_shader()
		instance.apply_to_material(preview_material)
	material_changed.emit(preview_material)

func reset() -> void:
	if source: select_material(source)
