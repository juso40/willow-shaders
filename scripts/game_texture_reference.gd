class_name GameTextureReference
extends RefCounted
## Syntax only: a valid identity is not proof the game asset exists locally.
const CLASSES = ["Texture2D", "TextureCube", "TextureMovie"]

static func object_class(text: String, fallback := "Texture2D") -> String:
	var value := text.strip_edges()
	for kind: String in CLASSES:
		if value.begins_with(kind + "'") and value.ends_with("'"): return kind
	return fallback

static func parse(text: String) -> String:
	var value := text.strip_edges()
	for kind: String in CLASSES:
		if value.begins_with(kind + "'") and value.ends_with("'"):
			value = value.substr(kind.length() + 1, value.length() - kind.length() - 2)
			break
	var regex := RegEx.new()
	regex.compile("^[A-Za-z0-9_-]+([.:][A-Za-z0-9_-]+)+$")
	return value if regex.search(value) else ""

static func literal(path: String, kind := "Texture2D") -> String:
	return kind + "'" + path + "'"
