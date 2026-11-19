class_name GameTextureExtractor
extends Node
## Desktop only. Search by leaf name, but accept only the exact uncooked identity.

signal notice(message: String)
signal image_ready(identity: String, texture: Texture2D)
signal finished(found: int, requested: int)

const CACHE := "user://game_texture_cache/"
const BATCH_SIZE := 20
const TIMEOUT_MS := 120000
var _serial := 0
var _pid := -1


static func executable(override_path: String) -> String:
	if not override_path.is_empty():
		return override_path if (
			override_path.is_absolute_path() and FileAccess.file_exists(override_path)
		) else ""
	var windows := OS.has_feature("windows")
	for folder in OS.get_environment("PATH").split(";" if windows else ":", false):
		for name in ["umodel", "ueviewer"]:
			var candidate := folder.trim_prefix('"').trim_suffix('"').path_join(
				name + (".exe" if windows else "")
			)
			if candidate.is_absolute_path() and FileAccess.file_exists(candidate):
				return candidate
	return ""


static func eligible(identity: String) -> bool:
	return (
		not identity.is_empty() and not identity.contains(":")
		and not identity.get_extension().begins_with("-")
		and identity == GameTextureReference.parse(identity)
	)


static func missing_slots(mic: MaterialInstanceConstant) -> Dictionary:
	var slots := { }
	if not mic:
		return slots
	var paths := mic.resolved_texture_paths()
	var kinds := mic.resolved_values(&"texture_object_classes")
	var images := mic.resolved_values(&"TextureParameterValues")
	for slot: String in paths:
		if kinds.get(slot) == "Texture2D" and images.get(slot) == null and eligible(paths[slot]):
			slots[slot] = paths[slot]
	return slots


static func search_scopes(game_dir: String) -> Array:
	var root := game_dir.replace("\\", "/").simplify_path().trim_suffix("/")
	if not root.is_absolute_path():
		return []
	var core := root.path_join("WillowGame/CookedPCConsole")
	if not DirAccess.dir_exists_absolute(core):
		core = root
		var willow := core.get_base_dir()
		if (
			core.get_file().to_lower() == "cookedpcconsole"
			and willow.get_file().to_lower() == "willowgame"
		):
			var install := willow.get_base_dir()
			if DirAccess.dir_exists_absolute(install.path_join("DLC")):
				root = install
	if not FileAccess.file_exists(core.path_join("WillowGame.upk")):
		return []
	var scopes := [
		[core, "Startup.upk", "Startup.upk"],
		[core, "WillowGame.upk", "WillowGame.upk"],
		[core, "**.upk", "base-game packages"],
	]
	if root != core:
		scopes.append([root, "**.upk", "installation packages (including installed DLC)"])
	return scopes


func cancel() -> void:
	_serial += 1
	if _pid > 0 and OS.is_process_running(_pid):
		OS.kill(_pid)
	_pid = -1


func _exit_tree() -> void:
	cancel()


func extract(identities: Array, game_dir: String, override_path: String) -> void:
	cancel()
	if not OS.has_feature("pc"):
		return
	var serial := _serial
	var pending: Array[String] = []
	for id: String in identities:
		if eligible(id) and not pending.has(id):
			pending.append(id)
	var total := pending.size()
	if total == 0:
		notice.emit("No missing Texture2D previews with game references.")
		finished.emit(0, 0)
		return
	var scopes := search_scopes(game_dir)
	if scopes.is_empty():
		notice.emit("Enter the Borderlands 2 installation or its CookedPCConsole directory.")
		return
	if DirAccess.make_dir_recursive_absolute(CACHE) != OK:
		notice.emit("Cannot create local texture cache.")
		return
	for id: String in pending.duplicate():
		if _load_cached(id):
			pending.erase(id)
	if not pending.is_empty():
		var tool := executable(override_path)
		if tool.is_empty():
			notice.emit(
				"UModel not found. Install it on PATH or enter the absolute executable path."
			)
			return
		for scope: Array in scopes:
			if pending.is_empty():
				break
			if (
				scope[1] != "**.upk"
				and not FileAccess.file_exists(str(scope[0]).path_join(scope[1]))
			):
				continue
			var queue := pending.duplicate()
			for start in range(0, queue.size(), BATCH_SIZE):
				var batch := queue.slice(start, start + BATCH_SIZE)
				var ok := await _search(serial, tool, scope, batch, pending)
				if serial != _serial or not ok:
					return
	var found := total - pending.size()
	var message := "Game textures: %d of %d exact images loaded." % [found, total]
	if not pending.is_empty():
		message += " No usable DDS, TGA or PNG at the requested object path: " + ", ".join(pending)
	notice.emit(message)
	finished.emit(found, total)


func _load_cached(id: String) -> bool:
	var path := CACHE.path_join(id + ".res")
	if not FileAccess.file_exists(path):
		return false
	var texture := ResourceLoader.load(path, "ImageTexture") as ImageTexture
	if not texture:
		return false
	image_ready.emit(id, texture)
	return true


func _import_export(path: String, id: String) -> bool:
	var image := Image.new()
	var error := image.load_dds_from_buffer(FileAccess.get_file_as_bytes(path)) if path.get_extension() == "dds" else image.load(
		path
	)
	if error != OK or image.is_empty():
		return false
	if image.is_compressed() and image.decompress() != OK:
		return false
	if not image.has_mipmaps():
		image.generate_mipmaps()
	var texture := ImageTexture.create_from_image(image)
	texture.resource_name = id
	var dest := CACHE.path_join(id + ".res")
	var temp := CACHE.path_join("%s.%d.tmp.res" % [id, OS.get_process_id()])
	if ResourceSaver.save(texture, temp, ResourceSaver.FLAG_COMPRESS) != OK:
		return false
	if DirAccess.rename_absolute(temp, dest) != OK:
		DirAccess.remove_absolute(temp)
		return false
	texture.take_over_path(dest)
	image_ready.emit(id, texture)
	return true


func _search(
	serial: int,
	tool: String,
	scope: Array,
	batch: Array[String],
	pending: Array[String],
) -> bool:
	while not batch.is_empty():
		var temp := DirAccess.create_temp("bl2-umodel")
		if not temp:
			notice.emit("Cannot create a temporary UModel export directory.")
			return false
		var out := temp.get_current_dir()
		var log_path := out.path_join("export.log")
		var args := PackedStringArray(
			[
				"-export",
				"-dds",
				"-uncook",
				"-groups",
				"-path=" + str(scope[0]),
				"-out=" + out,
				"-log=" + log_path,
			]
		)
		var leaves: Array[String] = []
		for id: String in batch:
			var leaf := id.get_extension()
			if not leaves.has(leaf):
				leaves.append(leaf)
		for i in range(1, leaves.size()):
			args.append("-obj=" + leaves[i])
		args.append_array(PackedStringArray([scope[1], leaves[0], "Texture2D"]))
		notice.emit("Searching %s for %d game texture(s)…" % [scope[2], leaves.size()])
		_pid = OS.create_process(tool, args)
		if _pid <= 0:
			notice.emit("Cannot start UModel. Check the executable path and permissions.")
			return false
		var started := Time.get_ticks_msec()
		while OS.is_process_running(_pid):
			await get_tree().create_timer(0.1).timeout
			if serial != _serial:
				return false
			if Time.get_ticks_msec() - started > TIMEOUT_MS:
				cancel()
				notice.emit("UModel timed out. No incomplete exports were used.")
				return false
		var code := OS.get_process_exit_code(_pid)
		_pid = -1
		if code != 0:
			# UModel aborts the entire batch on the first missing name, before exporting.
			var log_text := FileAccess.get_file_as_string(log_path) if FileAccess.file_exists(
				log_path
			) else ""
			var removed := false
			for id: String in batch.duplicate():
				if log_text.contains('Export "%s" was not found' % id.get_extension()):
					batch.erase(id)
					removed = true
			if removed:
				continue
			notice.emit(
				"UModel failed (exit %d) searching %s. Check the tool and installation."
				% [code, scope[2]]
			)
			return false
		for id: String in batch:
			var stem := out.path_join(id.replace(".", "/"))
			# -dds is a preference. Inspect only this object's files from this run.
			for extension in [".dds", ".tga", ".png"]:
				var path := stem + str(extension)
				if FileAccess.file_exists(path) and _import_export(path, id):
					pending.erase(id)
					break
		return true
	return true
