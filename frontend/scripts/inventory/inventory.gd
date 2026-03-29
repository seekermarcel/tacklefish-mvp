extends Control
## Collection book — displays caught fish as cards inside a book with sleeve-style cropping.

const RARITY_COLORS := {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.30, 0.69, 0.31),
	"rare": Color(0.13, 0.59, 0.95),
	"epic": Color(0.61, 0.15, 0.69),
	"legendary": Color(1.0, 0.60, 0.0),
}

const RARITY_BG := {
	"common": Color(0.35, 0.30, 0.25, 0.85),
	"uncommon": Color(0.25, 0.35, 0.22, 0.85),
	"rare": Color(0.22, 0.28, 0.40, 0.85),
	"epic": Color(0.35, 0.22, 0.38, 0.85),
	"legendary": Color(0.40, 0.32, 0.18, 0.85),
}

const FISH_PLACEHOLDER_COLORS := {
	"Perch": Color(0.6, 0.75, 0.4),
	"Carp": Color(0.7, 0.55, 0.3),
	"Chub": Color(0.65, 0.7, 0.45),
	"Brook Trout": Color(0.5, 0.7, 0.6),
	"Moonbass": Color(0.4, 0.4, 0.75),
	"Catfish": Color(0.5, 0.45, 0.4),
	"Ice Trout": Color(0.6, 0.85, 0.95),
	"Night Eel": Color(0.2, 0.2, 0.35),
	"Obsidian Pufferfish": Color(0.15, 0.15, 0.2),
	"Golden Primeval Perch": Color(1.0, 0.85, 0.3),
}

const PIXEL_FONT := preload("res://resources/fonts/pixel.ttf")
const CARD_TEXTURE := preload("res://resources/sprites/ui/fish_card.png")
const PAGE_SIZE := 50
const CARD_HEIGHT := 420

const RARITY_ICONS := {
	"common": preload("res://resources/sprites/ui/rarity_common.png"),
	"uncommon": preload("res://resources/sprites/ui/rarity_uncommon.png"),
	"rare": preload("res://resources/sprites/ui/rarity_rare.png"),
	"epic": preload("res://resources/sprites/ui/rarity_epic.png"),
	"legendary": preload("res://resources/sprites/ui/rarity_legendary.png"),
}

var all_fish: Array = []
var filtered_fish: Array = []
var current_offset: int = 0
var total_fish: int = 0
var active_rarity_filter: String = ""
var search_query: String = ""
var search_visible: bool = false

@onready var content_container: MarginContainer = %ContentContainer
@onready var fish_grid: GridContainer = %FishGrid
@onready var count_label: Label = %CountLabel
@onready var load_more_button: Button = %LoadMoreButton
@onready var back_button: Button = %BackButton
@onready var search_button: Button = %SearchButton
@onready var search_panel: PanelContainer = %SearchPanel
@onready var search_input: LineEdit = %SearchInput
@onready var filter_container: HBoxContainer = %FilterContainer
@onready var status_label: Label = %StatusLabel
@onready var opening_anim: AnimatedSprite2D = %OpeningAnim
@onready var closing_anim: AnimatedSprite2D = %ClosingAnim

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	search_button.pressed.connect(_toggle_search)
	load_more_button.pressed.connect(_load_more)
	search_input.text_changed.connect(_on_search_changed)

	# Style the search panel to match book aesthetic.
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.82, 0.72, 0.55, 0.95)
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel_style.content_margin_left = 8
	panel_style.content_margin_right = 8
	panel_style.content_margin_top = 6
	panel_style.content_margin_bottom = 6
	panel_style.border_width_left = 2
	panel_style.border_width_right = 2
	panel_style.border_width_top = 2
	panel_style.border_width_bottom = 2
	panel_style.border_color = Color(0.5, 0.38, 0.25, 0.8)
	search_panel.add_theme_stylebox_override("panel", panel_style)

	_setup_filters()
	_play_opening()

func _play_opening() -> void:
	AudioManager.play_sfx_collection_open()
	content_container.visible = false
	back_button.visible = false
	search_button.visible = false
	count_label.visible = false

	# Scale animation to fill viewport.
	var viewport_size := get_viewport_rect().size
	var frame_tex := opening_anim.sprite_frames.get_frame_texture("default", 0)
	var tex_size := Vector2(frame_tex.get_size())
	var scale_factor := maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
	opening_anim.scale = Vector2(scale_factor, scale_factor)
	var scaled_size := tex_size * scale_factor
	opening_anim.position = (viewport_size - scaled_size) * 0.5

	opening_anim.visible = true
	opening_anim.play("default")
	await opening_anim.animation_finished
	opening_anim.visible = false

	# Show content.
	content_container.visible = true
	back_button.visible = true
	search_button.visible = true
	count_label.visible = true
	_load_all_fish()

func _play_closing(next_scene: String) -> void:
	AudioManager.play_sfx_collection_close()
	content_container.visible = false
	back_button.visible = false
	search_button.visible = false
	count_label.visible = false
	search_panel.visible = false

	# Scale animation to fill viewport.
	var viewport_size := get_viewport_rect().size
	var frame_tex := closing_anim.sprite_frames.get_frame_texture("default", 0)
	var tex_size := Vector2(frame_tex.get_size())
	var scale_factor := maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
	closing_anim.scale = Vector2(scale_factor, scale_factor)
	var scaled_size := tex_size * scale_factor
	closing_anim.position = (viewport_size - scaled_size) * 0.5

	closing_anim.visible = true
	closing_anim.play("default")
	await closing_anim.animation_finished

	await SceneTransition.iris_to(next_scene)

func _toggle_search() -> void:
	search_visible = not search_visible
	search_panel.visible = search_visible
	if search_visible:
		search_input.grab_focus()

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
	button.custom_minimum_size = Vector2(0, 30)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.add_theme_font_override("font", PIXEL_FONT)
	button.add_theme_font_size_override("font_size", 11)

	if rarity != "":
		var color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
		button.add_theme_color_override("font_color", color)
		button.add_theme_color_override("font_pressed_color", Color.WHITE)

	button.pressed.connect(func(): _on_filter_pressed(rarity, button))
	return button

func _on_filter_pressed(rarity: String, pressed_button: Button) -> void:
	active_rarity_filter = rarity
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
	status_label.text = "Loading..."
	all_fish.clear()
	current_offset = 0

	var result := await Network.get_inventory(PAGE_SIZE, 0)
	if result.status != 200:
		status_label.text = "Failed to load"
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

	count_label.text = "%d / %d" % [filtered_fish.size(), total_fish]

	for fish_data in filtered_fish:
		fish_grid.add_child(_create_fish_card(fish_data))

func _create_fish_card(data: Dictionary) -> Control:
	var rarity: String = data.get("rarity", "common")
	var species: String = data.get("species", "Unknown")
	var size_variant: String = data.get("size_variant", "normal")
	var color_variant: String = data.get("color_variant", "normal")
	var rarity_color: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])

	# Card wrapper — clips children so the overflowing texture is cropped,
	# replicating the detail scene's CardAnchor + CardTexture overflow approach.
	var card_wrapper := Control.new()
	card_wrapper.custom_minimum_size = Vector2(0, CARD_HEIGHT)
	card_wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_wrapper.clip_children = Control.CLIP_CHILDREN_AND_DRAW
	card_wrapper.mouse_filter = Control.MOUSE_FILTER_STOP
	card_wrapper.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_card_pressed(data)
	)

	# Card texture background — overflows the wrapper just like the detail scene.
	# Detail scene: CardAnchor 480x880, texture offsets -48,-216,+72,+104.
	# Proportional overflow ratios: L=-0.10, T=-0.245, R=+0.15, B=+0.118.
	var card_bg := TextureRect.new()
	card_bg.texture = CARD_TEXTURE
	card_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	card_bg.stretch_mode = TextureRect.STRETCH_SCALE
	card_bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	card_bg.anchor_left = -0.10
	card_bg.anchor_top = -0.245
	card_bg.anchor_right = 1.15
	card_bg.anchor_bottom = 1.118
	card_bg.offset_left = 0
	card_bg.offset_top = 0
	card_bg.offset_right = 0
	card_bg.offset_bottom = 0
	card_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_wrapper.add_child(card_bg)

	# Anchor positions derived from pixel analysis of fish_card.png (528x960).
	# Texture rendered with overflow anchors (-0.10, -0.245, 1.15, 1.118).
	# Formula: anchor = -0.2455 + (tex_y / 960) * 1.3636
	#
	# Texture zones (dark brown bars where text sits):
	#   Blue water:  0.067 - 0.379  (fish sprite)
	#   Bar 1:       0.465 - 0.541  (species name)
	#   Bar 2:       0.595 - 0.641  (color variant)
	#   Bar 3:       0.681 - 0.726  (size variant)
	#   Bar 4:       0.749 - 0.837  (edition number)
	#   Bar 5:       0.862 - 0.933  (rarity icon)

	# 1. Fish sprite (inside blue water area).
	var sprite_container := CenterContainer.new()
	_anchor_rect(sprite_container, 0.10, 0.08, 0.90, 0.37)
	sprite_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_wrapper.add_child(sprite_container)

	var sprite_path := "res://resources/sprites/fish/%s.png" % species.to_lower().replace(" ", "_")
	if ResourceLoader.exists(sprite_path):
		var texture_rect := TextureRect.new()
		texture_rect.texture = load(sprite_path)
		texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var base_size := 85.0
		match size_variant:
			"mini": base_size = 65.0
			"large": base_size = 100.0
			"giant": base_size = 110.0
		texture_rect.custom_minimum_size = Vector2(base_size * 1.6, base_size)
		texture_rect.modulate = _color_variant_modulate(color_variant)
		sprite_container.add_child(texture_rect)
	else:
		var fish_sprite := ColorRect.new()
		var fish_color: Color = FISH_PLACEHOLDER_COLORS.get(species, Color(0.5, 0.5, 0.5))
		match color_variant:
			"albino": fish_color = fish_color.lightened(0.6)
			"melanistic": fish_color = fish_color.darkened(0.6)
			"rainbow": fish_color = Color(0.9, 0.5, 0.8)
			"neon":
				fish_color = fish_color.lightened(0.3)
				fish_color.s = 1.0
		var base_size := 55.0
		match size_variant:
			"mini": base_size = 42.0
			"large": base_size = 65.0
			"giant": base_size = 72.0
		fish_sprite.color = fish_color
		fish_sprite.custom_minimum_size = Vector2(base_size * 1.6, base_size)
		sprite_container.add_child(fish_sprite)

	# 2. Species name (centered on dark bar 1: 0.465-0.541).
	var name_label := Label.new()
	name_label.text = species
	name_label.add_theme_color_override("font_color", rarity_color)
	name_label.add_theme_font_override("font", PIXEL_FONT)
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_rect(name_label, 0.10, 0.465, 0.90, 0.541)
	card_wrapper.add_child(name_label)

	# 3. Color variant (centered on dark bar 2: 0.595-0.641).
	var color_label := Label.new()
	color_label.text = "Color: %s" % color_variant.capitalize()
	color_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
	color_label.add_theme_font_override("font", PIXEL_FONT)
	color_label.add_theme_font_size_override("font_size", 8)
	color_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	color_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	color_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_rect(color_label, 0.10, 0.595, 0.90, 0.641)
	card_wrapper.add_child(color_label)

	# 4. Size variant (centered on dark bar 3: 0.681-0.726).
	var size_label := Label.new()
	size_label.text = "Size: %s" % size_variant.capitalize()
	size_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
	size_label.add_theme_font_override("font", PIXEL_FONT)
	size_label.add_theme_font_size_override("font_size", 8)
	size_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	size_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	size_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_rect(size_label, 0.10, 0.681, 0.90, 0.726)
	card_wrapper.add_child(size_label)

	# 5. Edition number (centered on dark bar 4: 0.749-0.837).
	var edition_label := Label.new()
	edition_label.text = "#%d / %d" % [data.get("edition_number", 0), data.get("edition_size", 0)]
	edition_label.add_theme_color_override("font_color", Color(0.85, 0.78, 0.65))
	edition_label.add_theme_font_override("font", PIXEL_FONT)
	edition_label.add_theme_font_size_override("font_size", 10)
	edition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	edition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	edition_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor_rect(edition_label, 0.10, 0.749, 0.90, 0.837)
	card_wrapper.add_child(edition_label)

	# 6. Rarity icon (centered on dark bar 5: 0.862-0.933).
	var rarity_tex: Texture2D = RARITY_ICONS.get(rarity)
	if rarity_tex:
		var rarity_icon := TextureRect.new()
		rarity_icon.texture = rarity_tex
		rarity_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rarity_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rarity_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rarity_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_anchor_rect(rarity_icon, 0.35, 0.862, 0.65, 0.933)
		card_wrapper.add_child(rarity_icon)

	return card_wrapper

static func _anchor_rect(node: Control, left: float, top: float, right: float, bottom: float) -> void:
	node.anchor_left = left
	node.anchor_top = top
	node.anchor_right = right
	node.anchor_bottom = bottom
	node.offset_left = 0
	node.offset_top = 0
	node.offset_right = 0
	node.offset_bottom = 0

static func _color_variant_modulate(color_variant: String) -> Color:
	match color_variant:
		"albino": return Color(1.5, 1.5, 1.7)
		"melanistic": return Color(0.3, 0.3, 0.35)
		"rainbow": return Color(1.2, 0.7, 1.1)
		"neon": return Color(0.6, 1.5, 0.8)
		_: return Color.WHITE

func _on_card_pressed(data: Dictionary) -> void:
	GameState.set_meta("selected_fish", data)
	_play_closing("res://scenes/fish_detail/fish_detail.tscn")

func _on_back() -> void:
	_play_closing("res://scenes/fishing/fishing.tscn")
