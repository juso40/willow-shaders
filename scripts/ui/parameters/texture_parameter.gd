class_name TextureParameterControl
extends MaterialParameterControl
## Image preview and independent exported game identity.

@onready var summary_preview: TextureRect = %Preview
@onready var game_path: LineEdit = %GamePath
const BORDER_COLOR := Color(0.3, 0.34, 0.4, 1.0)
const HINT_COLOR := Color(0.4, 0.85, 0.5, 1.0)
const WEB_IMAGE_ACCEPT := ".png,.jpg,.jpeg,.webp,.bmp,.tga,.svg"
var _invalid_path := false
var _slot_dragged := false

func _ready() -> void:
	super._ready()
	%PreviewPanel.add_theme_stylebox_override("panel", _frame_style(BORDER_COLOR, 1))
	%Preview.row = self

static func _frame_style(color: Color, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.set_corner_radius_all(4)
	style.set_border_width_all(width)
	style.border_color = color
	return style

func set_drop_hint(active: bool) -> void:
	if not is_inside_tree(): return
	%PreviewPanel.add_theme_stylebox_override("panel", _frame_style(HINT_COLOR if active else BORDER_COLOR, 2 if active else 1))

func slot_drag_data() -> Variant:
	if not instance: return null
	var texture: Texture2D = instance.get_texture_parameter_value(str(parameter))
	if texture == null: return null
	_slot_dragged = true
	return {"texture_image": texture, "from_parameter": str(parameter)}

func slot_can_drop_data(data: Variant) -> bool:
	return instance != null and data is Dictionary and data.has("texture_image") and str(data.from_parameter) != str(parameter)

func slot_drop_data(data: Variant) -> void:
	if slot_can_drop_data(data): instance.set_texture_parameter_value(parameter, data.texture_image)

func slot_has_point(position: Vector2) -> bool:
	return %Preview.get_global_rect().has_point(position)

func slot_gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton) or event.button_index != MOUSE_BUTTON_LEFT: return
	if event.pressed: _slot_dragged = false
	elif not _slot_dragged: _on_load_pressed()

func bind_instance(value: MaterialInstanceConstant) -> void:
	game_path.release_focus()
	_invalid_path = false
	super.bind_instance(value)

func _on_inherit() -> void:
	_invalid_path = false
	super._on_inherit()
	if instance: _show_game_path()

func display_value(value: Variant) -> void:
	summary_preview.texture = value as Texture2D
	if not game_path.has_focus() and not _invalid_path: _show_game_path()

func _show_game_path() -> void:
	var paths := instance.resolved_texture_paths()
	var path: String = paths.get(str(parameter), "")
	if path.is_empty():
		game_path.text = "None" if paths.has(str(parameter)) else ""
	else:
		var kind: String = instance.resolved_values(&"texture_object_classes").get(str(parameter), "Texture2D")
		game_path.text = GameTextureReference.literal(path, kind if not kind.is_empty() else "Texture2D")

func set_game_path(text: String) -> bool:
	if not instance: return false
	var stripped := text.strip_edges()
	var explicit_none := stripped.nocasecmp_to("None") == 0
	var path := GameTextureReference.parse(stripped) if not explicit_none and not stripped.is_empty() else ""
	_invalid_path = path.is_empty() and not explicit_none and not stripped.is_empty()
	if _invalid_path: return false
	var name := str(parameter)
	var paths := instance.resolved_texture_paths()
	var current_kind: String = instance.resolved_values(&"texture_object_classes").get(name, "")
	var kind := "" if path.is_empty() else GameTextureReference.object_class(stripped, current_kind if not current_kind.is_empty() else "Texture2D")
	# Editing the identity alone must not select, replace or pin an inherited image.
	if path != paths.get(name, "") or (paths.has(name) and kind != current_kind) or (explicit_none and not paths.has(name)):
		instance.texture_object_paths[name] = path
		instance.texture_object_classes[name] = kind
		instance.emit_changed()
	if not game_path.has_focus(): _show_game_path()
	return true

func validate_pending_path() -> bool:
	return set_game_path(game_path.text)

func import_image(path: String) -> bool:
	if not validate_pending_path(): return false
	var result := TextureAssetImporter.import_image(path)
	if not result.error.is_empty():
		return false
	instance.set_texture_parameter_value(parameter, result.texture)

	return true

func _on_load_pressed() -> void:
	if OS.has_feature("web"):
		WebFiles.pick_file(WEB_IMAGE_ACCEPT, WebFiles.PICKED, _on_image_selected)
		return
	%ImageDialog.popup_centered_ratio(0.75)

func _on_image_selected(path: String) -> bool:
	return import_image(path)

func _on_path_changed() -> void:
	if game_path.has_focus(): set_game_path(game_path.text)

func _on_path_focus_exited() -> void:
	validate_pending_path()

func _on_clear_pressed() -> void:
	if not instance: return
	_invalid_path = false
	game_path.text = "None"
	instance.set_texture_binding(str(parameter), null, "", "")

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return instance != null and data is Dictionary and data.get("files") is PackedStringArray and data.files.size() == 1

func _drop_data(_position: Vector2, data: Variant) -> void:
	import_image(data.files[0])
