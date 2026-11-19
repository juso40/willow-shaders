class_name MaterialPreviewStage
extends Node3D
## Preview geometry and display settings are separate from the editable MIC.

signal meshes_changed(meshes: Array[MeshInstance3D])
signal settings_changed
const SHAPES := ["Custom", "Plane", "Cube", "Sphere"]
@export var plane: QuadMesh
@export var cube: BoxMesh
@export var sphere: SphereMesh
var shape := "Custom"
var subject: Node3D
var custom_model: Node3D
var diagnostics := PreviewDiagnostics.new()
var _wireframe := PreviewWireframe.new()
@onready var custom_mount: Node3D = %CustomMount
@onready var primitive: MeshInstance3D = %Primitive
@onready var model_root: Node3D = %ModelRoot
@onready var orbit: PreviewOrbitCamera = %OrbitCamera
@onready var pivot: Node3D = %Pivot

func _ready() -> void:
	primitive.set_instance_shader_parameter("bl_no_vertex_weights", true)

func set_material(value: ShaderMaterial, mic: UnrealMaterialInterface = null) -> void:
	diagnostics.set_source(value, mic)
	_refresh_display()

func set_view_mode(id: int) -> void:
	if not diagnostics.supports(id): return
	diagnostics.mode = id
	_refresh_display()

func set_view_texture(name: String) -> void:
	if name not in diagnostics.names: return
	diagnostics.texture_name = name
	_refresh_display()

func _refresh_display() -> void:
	if diagnostics.mode == 2: _wireframe.apply(meshes())
	else: _wireframe.restore()
	var material := diagnostics.material_for(get_viewport())
	if diagnostics.profile and diagnostics.profile.uses_three_uv_sets and material is ShaderMaterial:
		if material == diagnostics.source or material == diagnostics.family_display:
			material.set_shader_parameter("bl_primitive_uv", shape != "Custom")
			for node in meshes():
				var box := node.get_aabb()
				var center := box.get_center()
				node.set_instance_shader_parameter("bl_player_bounds", Vector4(center.x, center.y, center.z, box.size.length() * 0.5))
	if subject: MaterialLibrary.apply_to_tree(subject, material)
	settings_changed.emit()

func set_subject(node: Node3D) -> void:
	_wireframe.restore()
	if custom_model:
		custom_mount.remove_child(custom_model)
		custom_model.queue_free()
	custom_model = node
	if node:
		custom_mount.add_child(node)
		for part in _meshes_of(node):
			var array_mesh := part.mesh as ArrayMesh
			if not array_mesh: continue
			var has_colors := false
			for surface in range(array_mesh.get_surface_count()):
				if array_mesh.surface_get_format(surface) & Mesh.ARRAY_FORMAT_COLOR:
					has_colors = true
					break
			part.set_instance_shader_parameter("bl_no_vertex_weights", not has_colors)
	set_shape("Custom")

func set_shape(value: String) -> void:
	if value not in SHAPES: return
	_wireframe.restore()
	shape = value
	custom_mount.visible = shape == "Custom"
	primitive.visible = not custom_mount.visible
	primitive.mesh = {"Plane": plane, "Cube": cube, "Sphere": sphere}.get(shape)
	subject = custom_model if shape == "Custom" else primitive
	model_root.position = Vector3.ZERO
	pivot.rotation = Vector3.ZERO
	_refresh_display()
	meshes_changed.emit(meshes())
	frame_subject()

func meshes() -> Array[MeshInstance3D]:
	return _meshes_of(subject)

func _meshes_of(node: Node3D) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if not node: return result
	if node is MeshInstance3D and node.mesh: result.append(node)
	for mesh: MeshInstance3D in node.find_children("*", "MeshInstance3D", true, false):
		if mesh.mesh: result.append(mesh)
	return result

func frame_subject() -> void:
	var bounds := AABB()
	var first := true
	for mesh in meshes():
		if not mesh.is_visible_in_tree(): continue
		var box: AABB = model_root.global_transform.affine_inverse() * mesh.global_transform * mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first: return
	model_root.position = -bounds.get_center()
	var size := get_viewport().get_visible_rect().size
	orbit.fit_radius(bounds.size.length() * 0.5, size.x / maxf(size.y, 1.0), shape == "Plane")

func _visibility_of(node: Node3D) -> Dictionary:
	var visibility := {}
	for mesh in _meshes_of(node): visibility[str(node.get_path_to(mesh))] = mesh.visible
	return visibility

func capture_view() -> Dictionary:
	return {"shape": shape, "display_mode": diagnostics.mode, "view_texture": diagnostics.texture_name,
		"custom_visibility": _visibility_of(custom_model), "yaw": orbit.yaw, "pitch": orbit.pitch, "distance": orbit.distance,
		"offset": [orbit.look_pos.x, orbit.look_pos.y, orbit.look_pos.z], "visibility": _visibility_of(subject),
		"model_offset": [model_root.position.x, model_root.position.y, model_root.position.z],
		"fov": orbit.fov, "keep_aspect": orbit.keep_aspect}

func restore_view(view: Dictionary) -> void:
	set_shape(view.get("shape", "Custom"))
	set_view_texture(view.get("view_texture", ""))
	var id: int = view.get("display_mode", 0)
	set_view_mode(id if diagnostics.supports(id) else 0)
	for mesh in _meshes_of(custom_model):
		mesh.visible = view.get("custom_visibility", {}).get(str(custom_model.get_path_to(mesh)), true)
	for mesh in meshes():
		mesh.visible = view.get("visibility", {}).get(str(subject.get_path_to(mesh)), true)
	orbit.fov = view.get("fov", orbit.fov)
	orbit.keep_aspect = view.get("keep_aspect", orbit.keep_aspect)
	frame_subject()
	var model_offset: Array = view.get("model_offset", [model_root.position.x, model_root.position.y, model_root.position.z])
	model_root.position = Vector3(model_offset[0], model_offset[1], model_offset[2])
	orbit.yaw = view.get("yaw", orbit.yaw)
	orbit.pitch = view.get("pitch", orbit.pitch)
	orbit.distance = view.get("distance", orbit.distance)
	var offset: Array = view.get("offset", [0, 0, 0])
	orbit.look_pos = Vector3(offset[0], offset[1], offset[2])
	orbit._update_transform()
