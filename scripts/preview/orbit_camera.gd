class_name PreviewOrbitCamera
extends Camera3D
## Orbits target (or the world origin). The owning viewport routes input here.

signal frame_requested

@export var sensitivity := 0.008
@export var target: Node3D

var yaw := 1.2
var pitch := 0.12
var distance := 2.0
## World-space framing offset relative to target. Panning does not move target.
var look_pos: Vector3 = Vector3.ZERO


func _process(_delta: float) -> void:
	_update_transform()


func fit_radius(radius: float, aspect: float, front_view := false) -> void:
	var safe_aspect := maxf(aspect, 0.001)
	# Projection.get_fovy uses the vertical-to-horizontal aspect ratio.
	var limiting_fov := Projection.get_fovy(fov, 1.0 / maxf(safe_aspect, 1.0)) if keep_aspect == KEEP_WIDTH else Projection.get_fovy(fov, minf(safe_aspect, 1.0))
	# A sphere's angular radius determines framing distance. Keep the preview margin.
	distance = maxf(radius, 0.1) / sin(deg_to_rad(limiting_fov * 0.5)) * 1.12
	yaw = 0.0 if front_view else 1.2
	pitch = 0.12
	look_pos = Vector3.ZERO
	_update_transform()


func handle_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			yaw -= event.relative.x * sensitivity
			pitch = clampf(pitch + event.relative.y * sensitivity, -PI * 0.49, PI * 0.49)
		elif event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			var center := get_viewport().get_visible_rect().size * 0.5
			look_pos += project_position(center - event.relative, distance) - project_position(center, distance)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			distance *= 0.9
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			distance *= 1.1
		distance = clampf(distance, 0.05, 500.0)
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F:
		frame_requested.emit()
	_update_transform()


func _update_transform() -> void:
	var center := look_pos
	if is_instance_valid(target) and target != self:
		center += target.global_position
	global_position = center + Basis.from_euler(Vector3(-pitch, yaw, 0.0)) * Vector3.BACK * distance
	look_at(center, Vector3.UP)
