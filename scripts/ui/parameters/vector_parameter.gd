extends MaterialParameterControl

@export var component_labels := PackedStringArray(["R", "G", "B", "A"])
var _syncing := false
@onready var color_value: ColorPickerButton = %ColorValue
@onready var fields: Array[SpinBox] = [%R, %G, %B, %A]
@onready var labels: Array[Label] = [%RLabel, %GLabel, %BLabel, %ALabel]

func _ready() -> void:
	super._ready()
	for i in range(fields.size()):
		labels[i].text = component_labels[i]
		fields[i].value_changed.connect(_on_value_changed.bind(i))
	color_value.color_changed.connect(_on_color_changed)

func display_value(value: Variant) -> void:
	if not value is Vector4: return
	var raw: Vector4 = value
	_syncing = true
	for i in range(fields.size()): fields[i].set_value_no_signal(raw[i])
	color_value.color = Color(raw.x, raw.y, raw.z, raw.w).linear_to_srgb()
	_syncing = false

func set_color_view(enabled: bool) -> void:
	color_value.visible = enabled

func _on_value_changed(component_value: float, component: int) -> void:
	if _syncing or not instance: return
	var raw := instance.get_vector_parameter_value(parameter)
	raw[component] = component_value
	commit(raw)

func _on_color_changed(value: Color) -> void:
	if not _syncing: commit(value)
