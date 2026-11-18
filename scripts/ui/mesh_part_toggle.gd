extends CheckBox

var mesh: MeshInstance3D

func bind_mesh(value: MeshInstance3D) -> void:
	mesh = value
	text = mesh.name
	set_pressed_no_signal(mesh.visible)

func _on_toggled(enabled: bool) -> void:
	if is_instance_valid(mesh): mesh.visible = enabled
