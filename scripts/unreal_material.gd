@tool
class_name UnrealMaterial
extends UnrealMaterialInterface
## Base UE Material. Named expression defaults are stored as game data. Missing
## cooked arithmetic is not represented as a recovered shader graph.

@export_group("Preview diagnostics")
@export var debug_profile: MaterialDebugProfile:
	set(value):
		if debug_profile and debug_profile.changed.is_connected(emit_changed): debug_profile.changed.disconnect(emit_changed)
		debug_profile = value
		if debug_profile: debug_profile.changed.connect(emit_changed)
		emit_changed()

func _init() -> void:
	unreal_class = "Material"
