class_name MaterialParameterControl
extends HBoxContainer
## Base class for scene-backed, typed game-data controls. No shader dependency.

@export var parameter: StringName
@export_enum("dynamic", "static_mask", "static_switch") var parameter_category := "dynamic"
@export var parameter_property: StringName = &"ScalarParameterValues"
@export var caption := "Parameter"
var instance: MaterialInstanceConstant

func _ready() -> void:
	%Caption.text = caption
	%Caption.tooltip_text = parameter

func value_property() -> StringName:
	if parameter_category == "static_mask": return &"static_component_masks"
	if parameter_category == "static_switch": return &"static_switches"
	return parameter_property

func bind_instance(value: MaterialInstanceConstant) -> void:
	if instance and instance.changed.is_connected(refresh): instance.changed.disconnect(refresh)
	instance = value
	if instance: instance.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not instance: return
	display_value(instance.resolved_values(value_property()).get(str(parameter)))
	var local := MaterialParameterCatalog.has_value(instance, value_property(), parameter)
	%Inherit.disabled = not local
	%Inherit.tooltip_text = "Local override: restore parent value" if local else "Inherited value, no local override"
	var owner := MaterialParameterCatalog.value_source(instance, value_property(), parameter)
	var definition := MaterialParameterCatalog.definition_source(instance, value_property(), parameter)
	var master := MaterialParameterCatalog.master_for(instance)
	%State.text = "Local" if local else ("Master" if owner == master else "Parent")
	var origin := owner.source_object if owner else "Unresolved"
	var declaration := definition.source_object if definition else "Unknown"
	var detail := "%s\n%s\nDefined by: %s\nValue from: %s" % [parameter, value_property(), declaration, origin]
	if master and not MaterialParameterCatalog.has_value(master, value_property(), parameter):
		detail += "\nInstance-only parameter: absent from root defaults, preserved from the chain."
	%Caption.tooltip_text = detail
	%State.tooltip_text = detail

func display_value(_value: Variant) -> void:
	pass

func _on_inherit() -> void:
	if not instance: return
	# Reset only this typed dictionary, including when names collide across types.
	instance.get(value_property()).erase(str(parameter))
	if value_property() == &"TextureParameterValues":
		instance.texture_object_paths.erase(str(parameter))
		instance.texture_object_classes.erase(str(parameter))
	instance.emit_changed()

func commit(value: Variant) -> void:
	if not instance: return
	match value_property():
		&"static_component_masks": instance.set_static_component_mask(parameter, value)
		&"static_switches":
			instance.static_switches[str(parameter)] = bool(value)
			instance.emit_changed()
		&"ScalarParameterValues": instance.set_scalar_parameter_value(parameter, float(value))
		&"VectorParameterValues":
			if value is Color:
				var raw: Color = value.srgb_to_linear()
				value = Vector4(raw.r, raw.g, raw.b, raw.a)
			instance.set_vector_parameter_value(parameter, value)
		&"TextureParameterValues": instance.set_texture_parameter_value(parameter, value)
