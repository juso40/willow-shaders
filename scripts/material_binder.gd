@tool
class_name MaterialBinder
extends Node3D
## Reusable GLB adapter. Assign a MIC resource (preferred) or a ShaderMaterial.
## Only instance overrides are modified. Imported Mesh resources stay untouched.

@export var material_instance: MaterialInstanceConstant:
	set(value):
		if material_instance and material_instance.changed.is_connected(_queue_apply):
			material_instance.changed.disconnect(_queue_apply)
		material_instance = value
		if material_instance: material_instance.changed.connect(_queue_apply)
		_queue_apply()
@export var material: ShaderMaterial:
	set(value):
		material = value
		_queue_apply()
@export var recursive_apply := true
@export_tool_button("Apply to mesh children") var apply_action = apply_material
var _derived_material: ShaderMaterial

func _ready() -> void:
	if recursive_apply: apply_material()

func _queue_apply() -> void:
	if is_inside_tree(): call_deferred("apply_material")

func apply_material() -> void:
	var active := material
	if material_instance:
		if not _derived_material: _derived_material = ShaderMaterial.new()
		material_instance.apply_to_material(_derived_material)
		active = _derived_material
	if active == null: return
	for child in get_children():
		if recursive_apply: MaterialLibrary.apply_to_tree(child, active)
		elif child is MeshInstance3D: child.material_override = active
