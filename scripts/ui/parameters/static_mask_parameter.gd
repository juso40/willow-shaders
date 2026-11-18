extends MaterialParameterControl
## UE static component masks are four Boolean selectors, not fractional gains.

@onready var title: Label = %Title
@onready var channels: Array[CheckBox] = [%R, %G, %B, %A]

func _ready() -> void:
	super._ready()
	title.hide()
	for channel in channels: channel.toggled.connect(_on_channel_toggled)

func display_value(value: Variant) -> void:
	if not value is Vector4: return
	for i in range(channels.size()): channels[i].set_pressed_no_signal(value[i] != 0.0)

func _on_channel_toggled(_enabled: bool) -> void:
	commit(Vector4(float(channels[0].button_pressed), float(channels[1].button_pressed),
		float(channels[2].button_pressed), float(channels[3].button_pressed)))
