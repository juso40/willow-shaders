class_name MaterialParameterPanel
extends VBoxContainer
## Reusable composite: binds typed parameter editors anywhere in its scene tree.

func bind_instance(instance: MaterialInstanceConstant) -> void:
	for child in find_children("*", "", true, false):
		if child is MaterialParameterControl: child.bind_instance(instance)
