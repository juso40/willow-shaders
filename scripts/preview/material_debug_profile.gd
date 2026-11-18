@tool
class_name MaterialDebugProfile
extends Resource
## Optional presentation metadata shared by all descendants of a base material.
## IDs below 30 belong to the common views. Other IDs are local to this profile.

const FIRST_VIEW := 30
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
