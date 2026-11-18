class_name MeshPartsPanel
extends VBoxContainer

const PART_TOGGLE = preload("res://scenes/ui/mesh_part_toggle.tscn")

@onready var parts: VBoxContainer = %PartRows

func show_meshes(meshes: Array[MeshInstance3D]) -> void:
	for child in parts.get_children():
		parts.remove_child(child)
		child.queue_free()
	for mesh in meshes:
		var toggle = PART_TOGGLE.instantiate()
		parts.add_child(toggle)
		toggle.bind_mesh(mesh)
