class_name MaterialParameterEditor
extends VBoxContainer
## Shader-independent typed inspector. Masters define rows, parents/leaf resolve values.
## UI composition stays authored. Variable rows instantiate typed scenes.

var instance: MaterialInstanceConstant
var _texture_drag := false
var _drag_hover: TextureParameterControl
@onready var tabs: TabContainer = %Tabs
@onready var master_label: Label = %Master
@onready var search: LineEdit = %Search
@onready var overrides: CheckBox = %Overrides
@onready var textures: MaterialParameterGroup = %Textures
@onready var scalars: MaterialParameterGroup = %Scalars
@onready var vectors: MaterialParameterGroup = %Vectors
@onready var masks: MaterialParameterGroup = %Masks
@onready var switches: MaterialParameterGroup = %Switches
var current_tab: int:
	get: return tabs.current_tab
	set(value): tabs.current_tab = value

func _ready() -> void:
	search.text_changed.connect(func(_text): _apply_filters())
	overrides.toggled.connect(func(_pressed): _apply_filters())

func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_BEGIN: _begin_texture_drag()
	elif what == NOTIFICATION_DRAG_END: _end_texture_drag()

func _begin_texture_drag() -> void:
	var data: Variant = get_viewport().gui_get_drag_data()
	if not (data is Dictionary and data.has("texture_image")): return
	_texture_drag = true
	# Every other texture parameter is a valid target while the drag is active.
	for row in controls():
		if row is TextureParameterControl: row.set_drop_hint(row.slot_can_drop_data(data))

func _end_texture_drag() -> void:
	if not _texture_drag: return
	_texture_drag = false
	_drag_hover = null
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_ARROW)
	for row in controls():
		if row is TextureParameterControl: row.set_drop_hint(false)

func _input(event: InputEvent) -> void:
	if not _texture_drag or not (event is InputEventMouseMotion): return
	var row := texture_control_at(event.position)
	var valid := row != null and row.slot_can_drop_data(get_viewport().gui_get_drag_data()) and row.slot_has_point(event.position)
	_drag_hover = row
	DisplayServer.cursor_set_shape(DisplayServer.CURSOR_CAN_DROP if valid else DisplayServer.CURSOR_FORBIDDEN)

func groups() -> Array[MaterialParameterGroup]:
	return [textures, scalars, vectors, masks, switches]

func controls() -> Array[MaterialParameterControl]:
	var result: Array[MaterialParameterControl] = []
	for group in groups(): result.append_array(group.controls())
	return result

func control_for(name: String, property: StringName = &"") -> MaterialParameterControl:
	for group in groups():
		if property == &"" or group.parameter_property == property:
			var row := group.control_for(name)
			if row: return row
	return null

func bind_instance(value: MaterialInstanceConstant) -> void:
	if instance and instance.changed.is_connected(_reconcile): instance.changed.disconnect(_reconcile)
	instance = value
	_reconcile()
	if instance: instance.changed.connect(_reconcile)

func _reconcile() -> void:
	for group in groups(): group.reconcile(instance)
	var master := MaterialParameterCatalog.master_for(instance)
	if master:
		master_label.text = ("Master: " if master is UnrealMaterial else "Root MIC (master unavailable): ") + master.source_object
		var paths: PackedStringArray = []
		for entry in instance.inheritance_chain():
			var identity := entry.source_object if not entry.source_object.is_empty() else "Unnamed MIC"
			paths.append(identity + (" [editable child]" if entry == instance else ""))
		master_label.tooltip_text = "Inheritance: base → edited instance\n" + "\n→ ".join(paths)
	else:
		master_label.text = "Master: none"
		master_label.tooltip_text = ""
	_apply_filters()

func set_filter(query: String, local_only := false) -> void:
	search.text = query
	overrides.set_pressed_no_signal(local_only)
	_apply_filters()

func set_color_view(enabled: bool) -> void:
	for row in controls():
		if row.has_method("set_color_view"): row.set_color_view(enabled)

func _apply_filters() -> void:
	var query := search.text.strip_edges().to_lower()
	var shown: Array[int] = []
	for group in groups(): shown.append(group.apply_filter(query, overrides.button_pressed))
	var filtering := not query.is_empty() or overrides.button_pressed
	for i in range(3):
		var total := groups()[i].controls().size()
		var count := "%d/%d" % [shown[i], total] if filtering else str(total)
		tabs.set_tab_title(i, "%s (%s)" % [["Textures", "Scalars", "Vectors"][i], count])
	var static_shown := shown[3] + shown[4]
	var static_total := groups()[3].controls().size() + groups()[4].controls().size()
	tabs.set_tab_title(3, "Static (%s)" % ("%d/%d" % [static_shown, static_total] if filtering else str(static_total)))
	# A global search should lead to results, not strand the user on an empty tab.
	var tab_counts: Array[int] = [shown[0], shown[1], shown[2], static_shown]
	if filtering and tab_counts[tabs.current_tab] == 0:
		for i in range(4):
			if tab_counts[i] > 0:
				tabs.current_tab = i
				break

func texture_control_at(position: Vector2) -> TextureParameterControl:
	for row in controls():
		if row is TextureParameterControl and row.is_visible_in_tree() and row.get_global_rect().has_point(position):
			return row
	return null

func arm_texture_targets(active: bool) -> void:
	if active: current_tab = 0
	for row in controls():
		if row is TextureParameterControl: row.set_drop_hint(active)

func get_tab_count() -> int:
	return tabs.get_tab_count()

func get_tab_title(index: int) -> String:
	return tabs.get_tab_title(index)
