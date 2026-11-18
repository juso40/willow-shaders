class_name MaterialPreviewToolbar
extends VBoxContainer

@onready var object_picker: OptionButton = %ObjectPicker
@onready var view_picker: OptionButton = %ViewPicker
@onready var texture_picker: OptionButton = %TexturePicker
var stage: MaterialPreviewStage
var _menu_signature: Array = []
var _texture_labels: Array = []

func bind_stage(value: MaterialPreviewStage) -> void:
	stage = value
	for shape in MaterialPreviewStage.SHAPES: object_picker.add_item(shape)
	object_picker.item_selected.connect(func(index): stage.set_shape(object_picker.get_item_text(index)))
	view_picker.item_selected.connect(func(index): stage.set_view_mode(view_picker.get_item_id(index)))
	texture_picker.item_selected.connect(func(index): stage.set_view_texture(texture_picker.get_item_metadata(index)))
	stage.settings_changed.connect(refresh)
	refresh()

func refresh() -> void:
	var debug := stage.diagnostics
	object_picker.select(MaterialPreviewStage.SHAPES.find(stage.shape))
	if _menu_signature != debug.groups:
		_menu_signature = debug.groups
		view_picker.clear()
		for group in debug.groups: _add_group(group.title, group.entries)
	view_picker.select(view_picker.get_item_index(debug.mode))
	%TextureRow.visible = debug.uses_texture_picker()
	if not %TextureRow.visible: return
	var labels: Array = []
	for name in debug.names: labels.append(name if debug.images.get(name) else name + " (no image)")
	if labels != _texture_labels:
		_texture_labels = labels
		texture_picker.clear()
		for i in range(labels.size()):
			texture_picker.add_item(labels[i])
			texture_picker.set_item_metadata(i, debug.names[i])
	texture_picker.select(debug.names.find(debug.texture_name))

func _add_group(title: String, entries: Dictionary) -> void:
	view_picker.add_separator(title)
	for id: int in entries: view_picker.add_item(entries[id], id)
