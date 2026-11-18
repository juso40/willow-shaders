class_name GameMaterialBrowser
extends ConfirmationDialog
## Lazy, searchable full-identity MIC picker. Only the selected resource is loaded.
signal instance_selected(instance: MaterialInstanceConstant)
const PAGE_LIMIT := 200
var database: GameMaterialDatabase
var _paths := PackedStringArray()
var _shown := PackedStringArray()
@onready var search: LineEdit = %Search
@onready var results: ItemList = %Results
@onready var count_label: Label = %Count
@onready var search_delay: Timer = %SearchDelay

func _ready() -> void:
	get_ok_button().text = "Open MIC"
	get_ok_button().disabled = true
	confirmed.connect(_open_selected)
	search.text_changed.connect(func(_text): search_delay.start())
	search_delay.timeout.connect(refresh_results)
	results.item_selected.connect(func(_index): get_ok_button().disabled = false)
	results.item_activated.connect(func(_index): _open_selected())

func open_browser() -> void:
	if not database:
		database = GameMaterialDatabase.new()
		_paths = database.object_paths()
		_paths.sort()
	refresh_results()
	popup_centered_ratio(0.8)
	search.grab_focus()

func refresh_results() -> void:
	var query := search.text.strip_edges().to_lower()
	_shown.clear()
	results.clear()
	get_ok_button().disabled = true
	var matches := 0
	for path in _paths:
		if not query.is_empty() and query not in path.to_lower(): continue
		matches += 1
		if _shown.size() < PAGE_LIMIT:
			_shown.append(path)
			results.add_item(path)
	count_label.text = "%d matches / %d MICs · showing %d. Refine the search to narrow the list." % [matches, _paths.size(), _shown.size()]
	if _paths.is_empty(): count_label.text = "No converted MIC database found. Run tools/convert_material_instances.py first."

func _open_selected() -> void:
	var selected := results.get_selected_items()
	if selected.is_empty() or not database: return
	var instance := database.instance_for(_shown[selected[0]])
	if not instance:
		count_label.text = "Could not load the selected MIC resource."
		return
	instance_selected.emit(instance)
	hide()
