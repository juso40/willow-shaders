extends MaterialParameterControl

func _ready() -> void:
	super._ready()
	%Value.toggled.connect(commit)

func display_value(value: Variant) -> void:
	if value != null: %Value.set_pressed_no_signal(bool(value))
