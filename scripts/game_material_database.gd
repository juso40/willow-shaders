class_name GameMaterialDatabase
extends RefCounted
## Discovery only. Values and inheritance live in the typed game resources.

const MANIFEST_PATH = "res://presets/game/manifest.json"
var manifest: Dictionary = {}

func _init() -> void:
	if FileAccess.file_exists(MANIFEST_PATH):
		manifest = JSON.parse_string(FileAccess.get_file_as_string(MANIFEST_PATH))

func material_for(object_path: String) -> UnrealMaterialInterface:
	var entry: Dictionary = manifest.get("objects", {}).get(object_path, {})
	if entry.is_empty(): return null
	return load(entry.resource) as UnrealMaterialInterface

func instance_for(object_path: String) -> MaterialInstanceConstant:
	return material_for(object_path) as MaterialInstanceConstant

func object_paths(unreal_class := "MaterialInstanceConstant") -> PackedStringArray:
	var result := PackedStringArray()
	for path: String in manifest.get("objects", {}):
		if manifest.objects[path]["class"] == unreal_class: result.append(path)
	return result
