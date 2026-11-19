class_name MaterialSidebar
extends ScrollContainer

signal open_state_requested
signal save_state_requested
signal export_dump_requested
signal reset_requested

@onready var source: MaterialSourceSelector = %Source
@onready var editor: MaterialParameterEditor = %Editor
@onready var parts: MeshPartsPanel = %Parts
@onready var game_textures: GameTextureSettings = %GameTextures

func bind_instance(instance: MaterialInstanceConstant) -> void:
	editor.bind_instance(instance)
	%ExportDump.disabled = instance == null
	%Reset.disabled = instance == null

func _on_open_state() -> void: open_state_requested.emit()
func _on_save_state() -> void: save_state_requested.emit()
func _on_export_dump() -> void: export_dump_requested.emit()
func _on_reset() -> void: reset_requested.emit()
