class_name MaterialDumpExporter
extends RefCounted
## Game-facing, GUID-free property text. Does not upload/import textures into UE3.

static func export_dump(instance: UnrealMaterialInterface) -> Dictionary:
	var data := instance.game_parameters()
	var texture_classes := instance.resolved_values(&"texture_object_classes")
	var lines: PackedStringArray = []
	for kind: String in ["scalar", "vector", "texture"]:
		var names: Array = data[kind].keys()
		names.sort()
		for index in range(names.size()):
			var name: String = names[index]
			var value: Variant = data[kind][name]
			var field: String
			var encoded: String
			if kind == "scalar":
				field = "ScalarParameterValues"
				encoded = "%.9f" % float(value)
			elif kind == "vector":
				field = "VectorParameterValues"
				var v := Vector4(value.r, value.g, value.b, value.a) if value is Color else value as Vector4
				encoded = "(R=%.9f,G=%.9f,B=%.9f,A=%.9f)" % [v.x, v.y, v.z, v.w]
			else:
				field = "TextureParameterValues"
				var texture_class: String = texture_classes.get(name, "Texture2D")
				var path := GameTextureReference.parse(str(value))
				if str(value).is_empty(): encoded = "None"
				elif path.is_empty() or not texture_class.is_valid_identifier():
					return {"error": "Give %s a valid game texture object name before exporting." % name}
				else: encoded = "%s'%s'" % [texture_class, path]
			lines.append('%s(%d)=(ParameterName="%s",ParameterValue=%s)' % [field, index, name, encoded])
	return {"error": "", "text": "\n".join(lines) + "\n"}
