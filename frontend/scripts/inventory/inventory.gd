extends Control
## Displays the player's fish collection with pagination.

const RARITY_COLORS := {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.30, 0.69, 0.31),
	"rare": Color(0.13, 0.59, 0.95),
	"epic": Color(0.61, 0.15, 0.69),
	"legendary": Color(1.0, 0.60, 0.0),
}

const PAGE_SIZE := 20

var current_offset: int = 0
var total_fish: int = 0

@onready var fish_list: VBoxContainer = %FishList
@onready var count_label: Label = %CountLabel
@onready var load_more_button: Button = %LoadMoreButton
@onready var back_button: Button = %BackButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	load_more_button.pressed.connect(_load_more)
	load_more_button.visible = false
	_load_inventory()

func _load_inventory() -> void:
	status_label.text = "Loading..."
	current_offset = 0

	# Clear existing entries.
	for child in fish_list.get_children():
		child.queue_free()

	var result := await Network.get_inventory(PAGE_SIZE, 0)
	if result.status != 200:
		status_label.text = "Failed to load inventory"
		return

	var data: Dictionary = result.data
	total_fish = data.get("total", 0)
	count_label.text = "(%d fish)" % total_fish
	status_label.text = ""

	var fish_array: Array = data.get("fish", [])
	for fish_data in fish_array:
		_add_fish_entry(fish_data)

	current_offset = fish_array.size()
	load_more_button.visible = current_offset < total_fish

func _load_more() -> void:
	var result := await Network.get_inventory(PAGE_SIZE, current_offset)
	if result.status != 200:
		return

	var data: Dictionary = result.data
	var fish_array: Array = data.get("fish", [])
	for fish_data in fish_array:
		_add_fish_entry(fish_data)

	current_offset += fish_array.size()
	load_more_button.visible = current_offset < total_fish

func _add_fish_entry(data: Dictionary) -> void:
	var entry := PanelContainer.new()
	var hbox := HBoxContainer.new()
	entry.add_child(hbox)

	var rarity: String = data.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])

	var name_label := Label.new()
	name_label.text = data.get("species", "Unknown")
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(name_label)

	var edition_label := Label.new()
	edition_label.text = "#%d/%d" % [data.get("edition_number", 0), data.get("edition_size", 0)]
	hbox.add_child(edition_label)

	var traits_label := Label.new()
	traits_label.text = "%s %s" % [
		data.get("size_variant", ""),
		data.get("color_variant", ""),
	]
	hbox.add_child(traits_label)

	fish_list.add_child(entry)

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/fishing/fishing.tscn")
