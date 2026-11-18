class_name MaterialSourceSelector
extends VBoxContainer

signal material_selected(value: MaterialInstanceConstant)
signal import_requested

func show_selection(material: UnrealMaterialInterface) -> void:
	%Selection.text = material.source_object if material else "No material selected"

func _on_browser_selected(instance: MaterialInstanceConstant) -> void:
	material_selected.emit(instance)

func _on_import_pressed() -> void:
	import_requested.emit()
