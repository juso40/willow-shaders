class_name MaterialFiles
extends Node
## File dialogs and document I/O. State is captured by the application controller.

signal model_loaded(model: Node3D)
signal state_loaded(state: MaterialEditorState, model: Node3D)
signal state_save_requested(path: String)
signal notice(message: String)
var model_bytes := PackedByteArray()
var model_name := ""
var _pending_dump := ""

func _ready() -> void:
	if not OS.has_feature("web"): return
	# The engine's save dialog browses the sandboxed virtual filesystem. user://
	# is its persistent space, and WebFiles.download_file also hands the result
	# to the browser as a download.
	(%StateSaveDialog as FileDialog).access = FileDialog.ACCESS_USERDATA
	%StateSaveDialog.current_file = "material_state.res"
	(%DumpDialog as FileDialog).access = FileDialog.ACCESS_USERDATA

func request_import() -> void:
	if OS.has_feature("web"):
		WebFiles.pick_file(".glb", WebFiles.PICKED, import_model)
		return
	%ImportDialog.popup_centered_ratio(0.75)

func request_state_open() -> void:
	if OS.has_feature("web"):
		WebFiles.pick_file(".res,.tres", WebFiles.OPENED, load_state)
		return
	%OpenStateDialog.popup_centered_ratio(0.75)

func request_state_save() -> void: %StateSaveDialog.popup_centered_ratio(0.75)

func import_model(path: String) -> void:
	if path.get_extension().to_lower() != "glb":
		notice.emit("Choose a GLB file")
		return
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		notice.emit("Cannot open %s: %s" % [path.get_file(), error_string(FileAccess.get_open_error())])
		return
	var size := file.get_length()
	if size > MaterialEditorStateIO.MAX_ENTRY_BYTES:
		notice.emit("%s exceeds the 256 MiB model limit" % path.get_file())
		return
	var bytes := file.get_buffer(size)
	if bytes.is_empty() or bytes.size() != size:
		notice.emit("Cannot read model: " + path.get_file())
		return
	var result := MaterialModelImporter.from_buffer(bytes)
	if not result.error.is_empty():
		notice.emit("%s: %s" % [path.get_file(), result.error])
		return
	model_bytes = result.bytes
	model_name = path.get_file()
	model_loaded.emit(result.model)
	notice.emit("Loaded model: " + model_name)

func load_state(path: String) -> void:
	var result := MaterialEditorStateIO.load_state(path)
	if not result.error.is_empty():
		notice.emit(result.error)
		return
	var state: MaterialEditorState = result.state
	model_bytes = state.model_bytes
	model_name = state.model_name
	state_loaded.emit(state, result.model)
	_report_success(path)

func save_state(state: MaterialEditorState, path: String) -> bool:
	var error := MaterialEditorStateIO.save_state(state, path)
	if not error.is_empty():
		notice.emit(error)
		return false
	if OS.has_feature("web"):
		WebFiles.download_file(path, "text/plain" if path.get_extension().to_lower() == "tres" else "application/octet-stream")
	_report_success(path)
	return true

func _report_success(path: String) -> void:
	var error := MaterialEditorSettings.remember_state(path)
	notice.emit(path.get_file() if error == OK else "State saved or opened, but startup settings could not be saved")

func request_dump_export(instance: MaterialInstanceConstant) -> void:
	if not instance: return
	var result := MaterialDumpExporter.export_dump(instance)
	if not result.error.is_empty():
		notice.emit(result.error)
		return
	_pending_dump = result.text
	%DumpDialog.current_file = "parameters.txt"
	%DumpDialog.popup_centered_ratio(0.75)

func save_dump(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		notice.emit("Cannot save parameters: " + error_string(FileAccess.get_open_error()))
		return
	file.store_string(_pending_dump)
	file.close()
	if OS.has_feature("web"):
		WebFiles.download_file(path, "text/plain")
		notice.emit("Saved and downloaded " + path.get_file())
		return
	notice.emit(path.get_file())

func _on_state_save_selected(path: String) -> void:
	state_save_requested.emit(path)
