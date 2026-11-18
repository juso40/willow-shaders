class_name TextureDropSlot
extends TextureRect
## Thumbnail slot of a texture parameter row.
## Clicking opens the image picker, dragging moves the image to another parameter.

var row: TextureParameterControl

func _get_drag_data(_position: Vector2) -> Variant:
	var data: Variant = row.slot_drag_data() if row else null
	if not data is Dictionary: return null
	var preview := TextureRect.new()
	preview.texture = data.texture_image
	preview.custom_minimum_size = Vector2(44, 44)
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	set_drag_preview(preview)
	return data

func _can_drop_data(_position: Vector2, data: Variant) -> bool:
	return row != null and row.slot_can_drop_data(data)

func _drop_data(_position: Vector2, data: Variant) -> void:
	if row: row.slot_drop_data(data)

func _gui_input(event: InputEvent) -> void:
	if row: row.slot_gui_input(event)
