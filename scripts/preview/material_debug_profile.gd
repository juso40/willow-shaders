@tool
class_name MaterialDebugProfile
extends Resource
## Optional presentation metadata shared by all descendants of a base material.
## IDs below 30 belong to the common views. Other IDs are local to this profile.

const FIRST_VIEW := 30
## Profiles whose decal and pattern need TEXCOORD_1 and TEXCOORD_2 respectively.
@export var uses_three_uv_sets := false
## Sampler uniform -> cooked Texture2D object. These are not MIC parameters.
@export var fixed_texture_paths: Dictionary[String, String] = {}
## Sampler uniform -> ordered face identities from the cooked TextureCube export.
@export var fixed_cube_faces: Dictionary[String, PackedStringArray] = {}

func fixed_image_paths() -> Array[String]:
	var paths: Array[String] = []
	paths.assign(fixed_texture_paths.values())
	for faces: PackedStringArray in fixed_cube_faces.values(): paths.append_array(faces)
	return paths

@export var section := "Material":
	set(value):
		section = value
		emit_changed()
@export var shader: Shader:
	set(value):
		shader = value
		emit_changed()
@export var views: Dictionary[int, String] = {}:
	set(value):
		views = value
		emit_changed()
## Use this shader with diagnostic_view = 1 for the common Unlit entry.
@export var provides_unlit := false:
	set(value):
		provides_unlit = value
		emit_changed()

func menu_entries() -> Dictionary[int, String]:
	var result: Dictionary[int, String] = {}
	for id in views:
		if id >= FIRST_VIEW and not views[id].strip_edges().is_empty(): result[id] = views[id]
	return result
