class_name MaterialEditorSettings
extends RefCounted

const PATH = "user://settings.cfg"

static func last_state_path() -> String:
	var settings := ConfigFile.new()
	if settings.load(PATH) != OK: return ""
	return str(settings.get_value("session", "last_state", ""))

static func remember_state(path: String) -> Error:
	var settings := ConfigFile.new()
	settings.load(PATH)
	settings.set_value("session", "last_state", ProjectSettings.globalize_path(path))
	return settings.save(PATH)
