class_name WebFiles
extends RefCounted
## Bridge browser-selected files into the path-based importers. Nothing is uploaded.

const OPENED := "user://opened" # State paths must survive a reload for "reopen last state".
const PICKED := "/tmp/material-picker"
const DROPPED := "/tmp/material-drop"

# Keep the JS callbacks alive while a picker or FileReader is outstanding.
static var _active: WebFiles
var _input: JavaScriptObject
var _reader: JavaScriptObject
var _callbacks: Array[JavaScriptObject] = []
var _selected: Callable
var _directory: String
var _accept: PackedStringArray
var _name: String

static func pick_file(accept: String, directory: String, selected: Callable) -> void:
	if not OS.has_feature("web"): return
	_active = WebFiles.new()
	_active._open(accept, directory, selected)

func _open(accept: String, directory: String, selected: Callable) -> void:
	_directory = directory
	_accept = accept.split(",")
	_selected = selected
	var document := JavaScriptBridge.get_interface("document")
	_input = document.createElement("input")
	_input.type = "file"
	_input.accept = accept
	_listen(_input, "change", _on_change)
	_listen(_input, "cancel", _on_cancel)
	# Open synchronously from the button press, while the browser permits it.
	_input.click()

func _listen(target: JavaScriptObject, event: String, method: Callable) -> void:
	var callback := JavaScriptBridge.create_callback(method)
	_callbacks.append(callback)
	target.addEventListener(event, callback)

func _on_cancel(_args: Array) -> void:
	_active = null

func _on_change(_args: Array) -> void:
	var source: JavaScriptObject = _input.files.item(0)
	if not source:
		_active = null
		return
	_name = String(source.name).get_file().validate_filename()
	var extension := "." + _name.get_extension().to_lower()
	if not _accept.has(extension):
		_fail("Choose a file of type " + ", ".join(_accept))
		return
	if extension == ".glb" and source.size > MaterialEditorStateIO.MAX_ENTRY_BYTES:
		_fail(_name + " exceeds the 256 MiB model limit")
		return
	_reader = JavaScriptBridge.create_object("FileReader")
	_listen(_reader, "load", _on_load)
	_listen(_reader, "error", _on_error)
	_reader.readAsArrayBuffer(source)

func _on_error(_args: Array) -> void:
	_fail("Cannot read " + _name)

func _fail(message: String) -> void:
	OS.alert(message, "File import")
	_active = null

func _on_load(_args: Array) -> void:
	var path := _directory.path_join(_name)
	var bytes := JavaScriptBridge.js_buffer_to_packed_byte_array(_reader.result)
	if DirAccess.make_dir_recursive_absolute(_directory) != OK:
		_fail("Cannot create the import directory")
		return
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file or not file.store_buffer(bytes):
		_fail("Cannot store " + _name)
		return
	file.close()
	bytes.clear()
	if _selected.is_valid(): _selected.call(path)
	if _directory == PICKED: DirAccess.remove_absolute(path)
	_active = null

static func download_file(path: String, mime: String) -> void:
	JavaScriptBridge.download_buffer(FileAccess.get_file_as_bytes(path), path.get_file(), mime)
