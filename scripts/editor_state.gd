class_name MaterialEditorState
extends Resource
## A material document with embedded imported content and preview state.

const FORMAT_VERSION := 2

@export var format_version := FORMAT_VERSION
@export var material: MaterialInstanceConstant
@export var model_bytes := PackedByteArray()
@export var model_name := ""
@export var view: Dictionary = {}
@export var inspector: Dictionary = {}
