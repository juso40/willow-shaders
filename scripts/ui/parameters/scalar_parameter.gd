extends MaterialParameterControl

@export var minimum := 0.0
@export var maximum := 1.0
@export var step := 0.000001

func _ready() -> void:
	super._ready()
	%Value.min_value = minimum
	%Value.max_value = maximum
	%Value.step = step
	%Value.value_changed.connect(commit)

func display_value(value: Variant) -> void:
	if value != null: %Value.set_value_no_signal(float(value))
