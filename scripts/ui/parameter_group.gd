class_name MaterialParameterGroup
extends VBoxContainer
## Reconciles variable data rows using authored typed-control scenes.
## Static layout belongs to parameter_group.tscn, not this factory.


const SCALAR = preload("res://scenes/ui/parameters/scalar_parameter.tscn")
const VECTOR = preload("res://scenes/ui/parameters/vector_parameter.tscn")
const TEXTURE = preload("res://scenes/ui/parameters/texture_parameter.tscn")
const MASK = preload("res://scenes/ui/parameters/static_mask_parameter.tscn")
const SWITCH = preload("res://scenes/ui/parameters/toggle_parameter.tscn")

@export var parameter_property: StringName = &"ScalarParameterValues"
var _rows: Dictionary[String, MaterialParameterControl] = {}
var _names: Array[String] = []

func _ready() -> void:
	%Heading.text = parameter_property

func scene_for() -> PackedScene:
	match parameter_property:
		&"TextureParameterValues": return TEXTURE
		&"VectorParameterValues": return VECTOR
		&"static_component_masks": return MASK
		&"static_switches": return SWITCH
	return SCALAR

func reconcile(source: MaterialInstanceConstant) -> void:
	_names = MaterialParameterCatalog.names_for(source, parameter_property)
	for name: String in _rows.keys():
		if name not in _names or _rows[name].get_meta("editor_scene") != scene_for().resource_path:
			var row := _rows[name]
			row.bind_instance(null)
			%Rows.remove_child(row)
			row.queue_free()
			_rows.erase(name)
	for index in range(_names.size()):
		var name := _names[index]
		if not _rows.has(name):
			var scene := scene_for()
			var row := scene.instantiate() as MaterialParameterControl
			row.parameter = name
			row.caption = name
			row.parameter_property = parameter_property
			if parameter_property == &"static_switches": row.parameter_category = "static_switch"
			row.set_meta("editor_scene", scene.resource_path)
			%Rows.add_child(row)
			_rows[name] = row
		var row := _rows[name]
		%Rows.move_child(row, index)
		if row.instance != source: row.bind_instance(source)

func controls() -> Array[MaterialParameterControl]:
	var result: Array[MaterialParameterControl] = []
	for name in _names: result.append(_rows[name])
	return result

func control_for(name: String) -> MaterialParameterControl:
	return _rows.get(name)

func apply_filter(query: String, overrides_only: bool) -> int:
	var shown := 0
	for name in _names:
		var row := _rows[name]
		var matches := query.is_empty() or query in name.to_lower()
		var local := row.instance and MaterialParameterCatalog.has_value(row.instance, parameter_property, name)
		row.visible = matches and (not overrides_only or local)
		if row.visible: shown += 1
	%Heading.text = "%s  ·  %d / %d" % [parameter_property, shown, _names.size()]
	%Empty.visible = shown == 0
	%Empty.text = "No matching parameters." if not _names.is_empty() else "No parameters of this type in the material chain."
	return shown
