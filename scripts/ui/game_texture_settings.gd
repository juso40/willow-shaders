class_name GameTextureSettings
extends VBoxContainer

signal refresh_requested
signal configuration_changed
@onready var enabled: CheckBox = %AutoExtract
@onready var executable_path: LineEdit = %UmodelPath
@onready var game_directory: LineEdit = %GameDirectory
@onready var status_label: Label = %ExtractionStatus
@onready var refresh: Button = %ExtractNow
@onready var open_cache: Button = %OpenCache

func _ready() -> void:
	visible = OS.has_feature("pc")
	if not visible: return
	var config := ConfigFile.new()
	config.load(MaterialEditorSettings.PATH)
	executable_path.text = str(config.get_value("umodel", "executable", ""))
	game_directory.text = str(config.get_value("umodel", "game_directory", ""))
	if game_directory.text.is_empty(): game_directory.text = _steam_game_directory()
	enabled.set_pressed_no_signal(bool(config.get_value("umodel", "enabled", false)))
	refresh.disabled = not enabled.button_pressed
	if executable_path.text.is_empty():
		var detected := GameTextureExtractor.executable("")
		if not detected.is_empty(): executable_path.placeholder_text = "Found on PATH: " + detected
	enabled.toggled.connect(_toggle)
	for field in [executable_path, game_directory]:
		field.focus_exited.connect(_save_paths)
		field.text_submitted.connect(func(_text: String): get_viewport().gui_release_focus())
	refresh.pressed.connect(func(): refresh_requested.emit())
	open_cache.pressed.connect(_open_cache_folder)

func _open_cache_folder() -> void:
	var path := ProjectSettings.globalize_path(GameTextureExtractor.CACHE)
	var error := DirAccess.make_dir_recursive_absolute(path)
	if error == OK: error = OS.shell_show_in_file_manager(path, true)
	if error != OK: status_label.text = "Cannot open %s: %s" % [path, error_string(error)]

static func _steam_game_directory() -> String:
	var home := OS.get_environment("HOME")
	var roots := [OS.get_environment("ProgramFiles(x86)").path_join("Steam")] if OS.has_feature("windows") else [home.path_join(".local/share/Steam"), home.path_join(".steam/steam"), home.path_join("Library/Application Support/Steam")]
	var libraries := roots.duplicate()
	for folder: String in roots:
		var vdf := folder.path_join("steamapps/libraryfolders.vdf")
		if not FileAccess.file_exists(vdf): continue
		for line in FileAccess.get_file_as_string(vdf).split("\n"):
			var parts := line.strip_edges().split('"')
			if parts.size() >= 5 and parts[1] == "path": libraries.append(parts[3].replace("\\\\", "/"))
	for folder: String in libraries:
		var path := folder.path_join("steamapps/common/Borderlands 2")
		if path.is_absolute_path() and FileAccess.file_exists(path.path_join("WillowGame/CookedPCConsole/WillowGame.upk")): return path
	return ""

func _toggle(on: bool) -> void:
	refresh.disabled = not on
	_store()
	configuration_changed.emit()
	if on: refresh_requested.emit()

func _save_paths() -> void:
	var config := ConfigFile.new()
	config.load(MaterialEditorSettings.PATH)
	if config.get_value("umodel", "executable", "") == executable_path.text.strip_edges() and config.get_value("umodel", "game_directory", "") == game_directory.text.strip_edges(): return
	_store()
	configuration_changed.emit()

func _store() -> void:
	var config := ConfigFile.new()
	config.load(MaterialEditorSettings.PATH)
	config.set_value("umodel", "enabled", enabled.button_pressed)
	config.set_value("umodel", "executable", executable_path.text.strip_edges())
	config.set_value("umodel", "game_directory", game_directory.text.strip_edges())
	if config.save(MaterialEditorSettings.PATH) != OK: status_label.text = "Could not save extraction preferences."
