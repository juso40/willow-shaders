extends MaterialParameterControl

@export var choices := PackedStringArray()

func _ready() -> void:
	super._ready()
	for choice in choices: %Value.add_item(choice)
	%Value.item_selected.connect(commit)

func display_value(value: Variant) -> void:
	if value != null: %Value.select(int(value))
