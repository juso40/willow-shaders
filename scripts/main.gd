extends Control
## Connects the material, preview, file and state components.

signal state_applied
@export var reopen_last_state := true
@onready var session: MaterialEditorSession = %Session
@onready var sidebar: MaterialSidebar = %Sidebar
@onready var preview: MaterialPreviewPane = %Preview
@onready var files: MaterialFiles = %Files
@onready var browser_drop: BrowserImageDrop = %BrowserDrop
@onready var layout: HSplitContainer = %Layout
var _load_serial := 0
var _pending: Dictionary = {}

func _ready() -> void:
	sidebar.source.material_selected.connect(session.select_material)
	sidebar.source.import_requested.connect(files.request_import)
	sidebar.reset_requested.connect(session.reset)
	sidebar.export_dump_requested.connect(func():
		if _validate_textures(): files.request_dump_export(session.instance))
	sidebar.open_state_requested.connect(files.request_state_open)
	sidebar.save_state_requested.connect(files.request_state_save)
	files.state_save_requested.connect(save_state)
	session.selection_changed.connect(sidebar.source.show_selection)
	session.instance_changed.connect(sidebar.bind_instance)
	session.material_changed.connect(func(material): preview.stage.set_material(material, session.instance))
	preview.stage.meshes_changed.connect(sidebar.parts.show_meshes)
	preview.drop_target_selected.connect(_resolve_pending_model)
	files.model_loaded.connect(_show_model)
	files.state_loaded.connect(_apply_state)
	files.notice.connect(preview.set_status)
	get_window().files_dropped.connect(handle_drop)
	browser_drop.link_dropped.connect(_offer_browser_image)
	browser_drop.notice.connect(preview.set_status)
	session.instance_changed.connect(func(_instance): _clear_pending())
	sidebar.bind_instance(null)
	if reopen_last_state: _restore_last_state.call_deferred()

func _restore_last_state() -> void:
	var path := MaterialEditorSettings.last_state_path()
	if path.is_empty(): return
	if FileAccess.file_exists(path): files.load_state(path)
	else: preview.set_status("Last state file is unavailable")

func _show_model(model: Node3D) -> void:
	_load_serial += 1
	preview.stage.set_subject(model)

func _validate_textures() -> bool:
	for row in sidebar.editor.controls():
		if row is TextureParameterControl and not row.validate_pending_path():
			preview.set_status("Correct the texture object path before saving or exporting")
			return false
	return true

func capture_state() -> MaterialEditorState:
	var state := MaterialEditorState.new()
	state.material = session.instance
	state.model_bytes = files.model_bytes
	state.model_name = files.model_name
	state.view = preview.stage.capture_view()
	state.inspector = {"tab": sidebar.editor.current_tab, "query": sidebar.editor.search.text,
		"local_only": sidebar.editor.overrides.button_pressed, "split": layout.split_offset,
		"scroll": sidebar.scroll_vertical}
	return state

func save_state(path: String) -> bool:
	if not _validate_textures(): return false
	return files.save_state(capture_state(), path)

func _apply_state(state: MaterialEditorState, model: Node3D) -> void:
	_load_serial += 1
	var serial := _load_serial
	session.open_instance(state.material)
	preview.stage.set_subject(model)
	layout.split_offset = state.inspector.get("split", layout.split_offset)
	sidebar.editor.set_filter(state.inspector.get("query", ""), state.inspector.get("local_only", false))
	sidebar.editor.current_tab = state.inspector.get("tab", 0)
	# Restore camera after the imported geometry and inspector finish layout.
	for frame in range(3): await get_tree().process_frame
	if serial != _load_serial: return
	preview.stage.restore_view(state.view)
	sidebar.parts.show_meshes(preview.stage.meshes())
	sidebar.set_deferred("scroll_vertical", state.inspector.get("scroll", 0))
	state_applied.emit()

# Desktop file drags do not report where the file was released. The payload is
# delivered once on button release, while the pointer position has been frozen
# since the compositor grabbed it. The application therefore arms a matching
# zone and the user confirms the target with one click.
func handle_drop(paths: PackedStringArray) -> void:
	_clear_pending()
	if paths.size() != 1:
		preview.set_status("Drop one model, state file or texture at a time")
		return
	var path: String = paths[0]
	var url := BrowserImageDrop.image_url(path)
	if not url.is_empty():
		_offer_browser_image(url)
		return
	if not FileAccess.file_exists(path):
		preview.set_status("No readable file or image URL. Drag the original image or save it first.")
		return
	var is_state := path.get_extension().to_lower() in ["res", "tres"]
	if OS.has_feature("web"):
		# Godot unlinks browser drops when files_dropped returns. Keep a copy
		# for the confirmation click (or for reopening a state after reload).
		var directory := WebFiles.OPENED if is_state else WebFiles.DROPPED
		var staged := directory.path_join(path.get_file().validate_filename())
		if DirAccess.make_dir_recursive_absolute(directory) != OK or DirAccess.copy_absolute(path, staged) != OK:
			preview.set_status("Cannot read dropped file: " + path.get_file())
			return
		path = staged
	if is_state:
		files.load_state(path)
		return
	_begin_drop(path)

func _offer_browser_image(url: String) -> void:
	_clear_pending()
	if url.is_empty():
		preview.set_status(BrowserImageDrop.NO_IMAGE)
		return
	_pending = {"kind": "browser_image", "url": url}
	sidebar.editor.arm_texture_targets(true)
	preview.set_status("Image from %s: click a texture slot to import. Right-click cancels." % BrowserImageDrop.label(url))

func _begin_drop(path: String) -> void:
	var kind := "model" if path.get_extension().to_lower() == "glb" else "image"
	_pending = {"kind": kind, "path": path}
	if kind == "model":
		preview.set_pending_model(path.get_file())
		preview.set_status("%s: click the 3D view to load it. Right-click cancels." % path.get_file())
	else:
		sidebar.editor.arm_texture_targets(true)
		preview.set_status("%s: click a texture parameter to use it as that image. Right-click cancels." % path.get_file())

func _resolve_pending_model() -> void:
	if _pending.is_empty() or _pending.kind != "model": return
	files.import_model(_pending.path)
	_clear_pending()

func _cancel_pending() -> void:
	_clear_pending()
	preview.set_status("Drop cancelled")

func _clear_pending() -> void:
	browser_drop.cancel()
	if OS.has_feature("web") and _pending.has("path"): DirAccess.remove_absolute(_pending.path)
	_pending = {}
	preview.set_pending_model("")
	sidebar.editor.arm_texture_targets(false)

func _input(event: InputEvent) -> void:
	if _pending.is_empty(): return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_cancel_pending()
		return
	if not (event is InputEventMouseButton) or not event.pressed: return
	if event.button_index == MOUSE_BUTTON_RIGHT:
		get_viewport().set_input_as_handled()
		_cancel_pending()
		return
	if event.button_index != MOUSE_BUTTON_LEFT or _pending.kind not in ["image", "browser_image"]: return
	var row := sidebar.editor.texture_control_at(event.position)
	if not row: return
	get_viewport().set_input_as_handled()
	if _pending.kind == "browser_image":
		if not row.validate_pending_path():
			preview.set_status("Correct the texture object path before importing the image")
			return
		var url: String = _pending.url
		_clear_pending()
		preview.set_status("Loading image from " + BrowserImageDrop.label(url))
		browser_drop.load_image(url, _assign_browser_image.bind(weakref(row), session.instance))
		return
	var path: String = _pending.path
	if row.import_image(path):
		preview.set_status("Loaded image: " + path.get_file())
	else:
		preview.set_status("Cannot import " + path.get_file())
	_clear_pending()

func _assign_browser_image(texture: Texture2D, target: WeakRef, source: MaterialInstanceConstant) -> void:
	var row := target.get_ref() as TextureParameterControl
	if not row or not source or row.instance != source or source != session.instance: return
	if not row.validate_pending_path():
		preview.set_status("Image not applied: the texture object path is invalid")
		return
	source.set_texture_parameter_value(row.parameter, texture)
	preview.set_status("Loaded browser image: " + str(row.parameter))
