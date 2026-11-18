class_name MaterialParameterCatalog
extends RefCounted
## Shader-independent parameter discovery. Root defaults define the interface.
## Ancestor/leaf-only values remain visible rather than being silently dropped.

const DYNAMIC_PROPERTIES: Array[StringName] = [
	&"TextureParameterValues", &"ScalarParameterValues", &"VectorParameterValues",
]

static func master_for(source: UnrealMaterialInterface) -> UnrealMaterialInterface:
	if not source: return null
	var chain := source.inheritance_chain()
	for entry in chain:
		if entry is UnrealMaterial: return entry
	return chain[0] if not chain.is_empty() else null

static func names_for(source: UnrealMaterialInterface, property: StringName) -> Array[String]:
	var names: Dictionary = {}
	if source:
		for entry in source.inheritance_chain():
			for name: String in entry.get(property): names[name] = true
			if property == &"TextureParameterValues":
				for name: String in entry.texture_object_paths: names[name] = true
	var result: Array[String] = []
	result.assign(names.keys())
	result.sort()
	return result

static func has_value(source: UnrealMaterialInterface, property: StringName, name: String) -> bool:
	return source.get(property).has(name) or (property == &"TextureParameterValues" and source.texture_object_paths.has(name))

static func value_source(source: UnrealMaterialInterface, property: StringName, name: String) -> UnrealMaterialInterface:
	var chain := source.inheritance_chain()
	chain.reverse()
	for entry in chain:
		if has_value(entry, property, name): return entry
	return null

static func definition_source(source: UnrealMaterialInterface, property: StringName, name: String) -> UnrealMaterialInterface:
	for entry in source.inheritance_chain():
		if has_value(entry, property, name): return entry
	return null
