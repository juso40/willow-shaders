class_name MaterialPreviewPane
extends VBoxContainer

signal drop_target_selected

const IDLE_HINT := "Drop a GLB model here\nor press Import model"

@onready var viewport: SubViewport = %Viewport
@onready var stage: MaterialPreviewStage = %Stage
var _pending_model := false

func _ready() -> void:
	%Toolbar.bind_stage(stage)
	stage.meshes_changed.connect(_update_drop_hint)
	_update_drop_hint()

func _update_drop_hint(_meshes: Array = []) -> void:
	if _pending_model: return
	%DropHint.text = IDLE_HINT
	%DropHint.visible = stage.subject == null

func set_status(message: String) -> void:
	%Status.text = message

func set_pending_model(filename: String) -> void:
	_pending_model = not filename.is_empty()
	%DropFlash.visible = _pending_model
	%ViewportContainer.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _pending_model else Control.CURSOR_ARROW
	if _pending_model:
		%DropHint.text = "Click the 3D view to load\n" + filename
		%DropHint.visible = true
	else:
		_update_drop_hint()

func _on_preview_input(event: InputEvent) -> void:
	if _pending_model and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		set_pending_model("")
		drop_target_selected.emit()
		return
	if event is InputEventMouseButton and event.pressed: %ViewportContainer.grab_focus()
	stage.orbit.handle_input(event)
