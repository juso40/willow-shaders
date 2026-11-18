extends MaterialParameterControl
## Picker uses sRGB. The numeric dialog exposes unclamped linear RGBA game values.

@onready var value_picker: ColorPickerButton = %Value
@onready var raw_dialog: AcceptDialog = %RawDialog
@onready var fields: Array[SpinBox] = [%R, %G, %B, %A]

func _ready() -> void:
	super._ready()
	value_picker.color_changed.connect(commit)
	for i in range(fields.size()): fields[i].value_changed.connect(_on_raw_changed.bind(i))

func display_value(value: Variant) -> void:
	if not value is Vector4: return
	var raw: Vector4 = value
	value_picker.color = Color(raw.x, raw.y, raw.z, raw.w).linear_to_srgb()
	for i in range(fields.size()): fields[i].set_value_no_signal(raw[i])

func _on_raw_pressed() -> void:
	raw_dialog.title = str(parameter) + ": linear RGBA"
	raw_dialog.popup_centered()

func _on_raw_changed(component_value: float, component: int) -> void:
	if not instance: return
	var raw := instance.get_vector_parameter_value(parameter)
	raw[component] = component_value
	commit(raw)
