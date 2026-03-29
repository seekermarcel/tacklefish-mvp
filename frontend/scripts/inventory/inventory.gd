extends Control
## Collection book — displays caught fish as cards with search and filters.

const RARITY_COLORS := {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.30, 0.69, 0.31),
	"rare": Color(0.13, 0.59, 0.95),
	"epic": Color(0.61, 0.15, 0.69),
	"legendary": Color(1.0, 0.60, 0.0),
}

const RARITY_BG := {
	"common": Color(0.25, 0.25, 0.25, 0.9),
	"uncommon": Color(0.12, 0.28, 0.12, 0.9),
	"rare": Color(0.08, 0.18, 0.35, 0.9),
	"epic": Color(0.25, 0.08, 0.30, 0.9),
	"legendary": Color(0.35, 0.22, 0.05, 0.9),
}

# Placeholder fish shapes — simple colored silhouettes per species.
const FISH_PLACEHOLDER_COLORS := {
	"Perch": Color(0.6, 0.75, 0.4),
	"Carp": Color(0.7, 0.55, 0.3),
	"Sunfish": Color(1.0, 0.8, 0.2),
	"Brook Trout": Color(0.5, 0.7, 0.6),
	"Moonbass": Color(0.4, 0.4, 0.75),
	"Catfish": Color(0.5, 0.45, 0.4),
	"Ice Trout": Color(0.6, 0.85, 0.95),
	"Night Eel": Color(0.2, 0.2, 0.35),
	"Obsidian Pufferfish": Color(0.15, 0.15, 0.2),
	"Golden Primeval Perch": Color(1.0, 0.85, 0.3),
}

const PAGE_SIZE := 50

var all_fish: Array = []
var filtered_fish: Array = []
var current_offset: int = 0
var total_fish: int = 0
var active_rarity_filter: String = ""
var search_query: String = ""

@onready var fish_grid: GridContainer = %FishGrid
@onready var count_label: Label = %CountLabel
@onready var load_more_button: Button = %LoadMoreButton
@onready var back_button: Button = %BackButton
@onready var search_input: LineEdit = %SearchInput
@onready var filter_container: HBoxContainer = %FilterContainer
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	load_more_button.pressed.connect(_load_more)
	load_more_button.visible = false
	search_input.text_changed.connect(_on_search_changed)
	_setup_filters()
	_load_all_fish()

func _setup_filters() -> void:
	var all_button := _create_filter_button("All", "")
	all_button.button_pressed = true
	filter_container.add_child(all_button)

	for rarity in ["common", "uncommon", "rare", "epic", "legendary"]:
		var button := _create_filter_button(rarity.capitalize(), rarity)
		filter_container.add_child(button)

func _create_filter_button(label_text: String, rarity: String) -> Button:
	var button := Button.new()
	button.text = label_text
	button.toggle_mode = true
	button.custom_minimum_size = Vector2(0, 36)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	if rarity != "":
		var color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)
		button.add_theme_font_size_override("font_size", 13)
	else:
		button.add_theme_font_size_override("font_size", 13)

	button.pressed.connect(func(): _on_filter_pressed(rarity, button))
	return button

func _on_filter_pressed(rarity: String, pressed_button: Button) -> void:
	active_rarity_filter = rarity
	# Unpress all other filter buttons.
	for child in filter_container.get_children():
		if child is Button and child != pressed_button:
			child.button_pressed = false
	pressed_button.button_pressed = true
	_apply_filters()

func _on_search_changed(new_text: String) -> void:
	search_query = new_text.strip_edges().to_lower()
	_apply_filters()

func _apply_filters() -> void:
	filtered_fish.clear()
	for fish_data in all_fish:
		var species: String = fish_data.get("species", "")
		var rarity: String = fish_data.get("rarity", "")

		if active_rarity_filter != "" and rarity != active_rarity_filter:
			continue
		if search_query != "" and species.to_lower().find(search_query) == -1:
			continue

		filtered_fish.append(fish_data)

	_rebuild_grid()

func _load_all_fish() -> void:
	status_label.text = "Loading collection..."
	all_fish.clear()
	current_offset = 0

	var result := await Network.get_inventory(PAGE_SIZE, 0)
	if result.status != 200:
		status_label.text = "Failed to load collection"
		return

	var data: Dictionary = result.data
	total_fish = data.get("total", 0)
	all_fish = data.get("fish", [])
	current_offset = all_fish.size()
	status_label.text = ""

	_apply_filters()
	load_more_button.visible = current_offset < total_fish

func _load_more() -> void:
	var result := await Network.get_inventory(PAGE_SIZE, current_offset)
	if result.status != 200:
		return

	var data: Dictionary = result.data
	var fish_array: Array = data.get("fish", [])
	all_fish.append_array(fish_array)
	current_offset += fish_array.size()
	load_more_button.visible = current_offset < total_fish

	_apply_filters()

func _rebuild_grid() -> void:
	for child in fish_grid.get_children():
		child.queue_free()

	count_label.text = "%d / %d fish" % [filtered_fish.size(), total_fish]

	for fish_data in filtered_fish:
		fish_grid.add_child(_create_fish_card(fish_data))

func _create_fish_card(data: Dictionary) -> PanelContainer:
	var rarity: String = data.get("rarity", "common")
	var species: String = data.get("species", "Unknown")
	var rarity_color: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])
	var bg_color: Color = RARITY_BG.get(rarity, RARITY_BG["common"])

	# Card container.
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = rarity_color
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	card.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	card.add_child(vbox)

	# Placeholder fish sprite.
	var sprite_container := CenterContainer.new()
	sprite_container.custom_minimum_size = Vector2(0, 80)
	vbox.add_child(sprite_container)

	var fish_sprite := ColorRect.new()
	var fish_color: Color = FISH_PLACEHOLDER_COLORS.get(species, Color(0.5, 0.5, 0.5))

	# Apply color variant tint.
	var color_variant: String = data.get("color_variant", "normal")
	match color_variant:
		"albino":
			fish_color = fish_color.lightened(0.6)
		"melanistic":
			fish_color = fish_color.darkened(0.6)
		"rainbow":
			fish_color = Color(0.9, 0.5, 0.8)
		"neon":
			fish_color = fish_color.lightened(0.3)
			fish_color.s = 1.0

	# Size based on size_variant.
	var base_size := 40.0
	var size_variant: String = data.get("size_variant", "normal")
	match size_variant:
		"mini":
			base_size = 28.0
		"large":
			base_size = 52.0
		"giant":
			base_size = 64.0

	fish_sprite.color = fish_color
	fish_sprite.custom_minimum_size = Vector2(base_size * 1.6, base_size)
	# Round the placeholder a bit using a clip.
	sprite_container.add_child(fish_sprite)

	# Species name.
	var name_label := Label.new()
	name_label.text = species
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.add_theme_font_size_override("font_size", 14)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(name_label)

	# Edition number.
	var edition_label := Label.new()
	edition_label.text = "#%d / %d" % [data.get("edition_number", 0), data.get("edition_size", 0)]
	edition_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
	edition_label.add_theme_font_size_override("font_size", 12)
	edition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(edition_label)

	# Rarity badge.
	var rarity_label := Label.new()
	rarity_label.text = rarity.to_upper()
	rarity_label.add_theme_color_override("font_color", rarity_color)
	rarity_label.add_theme_font_size_override("font_size", 10)
	rarity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(rarity_label)

	# Traits row.
	var traits_hbox := HBoxContainer.new()
	traits_hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_child(traits_hbox)

	var size_label := Label.new()
	size_label.text = size_variant.capitalize()
	size_label.add_theme_font_size_override("font_size", 10)
	size_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	traits_hbox.add_child(size_label)

	var sep := Label.new()
	sep.text = " | "
	sep.add_theme_font_size_override("font_size", 10)
	sep.add_theme_color_override("font_color", Color(0.4, 0.4, 0.4))
	traits_hbox.add_child(sep)

	var color_label := Label.new()
	color_label.text = color_variant.capitalize()
	color_label.add_theme_font_size_override("font_size", 10)
	color_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	traits_hbox.add_child(color_label)

	return card

func _on_back() -> void:
	await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")
