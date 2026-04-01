extends Control
## Displays a fish detail card from the inventory. Same layout as the catch reveal
## but with navigation back to inventory or fishing.

@onready var fish_sprite_container: CenterContainer = %FishSpriteContainer
@onready var rarity_icon: TextureRect = %RarityIcon
@onready var species_label: Label = %SpeciesLabel
@onready var edition_label: Label = %EditionLabel
@onready var size_label: Label = %SizeLabel
@onready var color_label: Label = %ColorLabel
@onready var back_to_inventory_button: Label = %BackToInventoryButton
@onready var back_to_pond_button: Label = %BackToPondButton
@onready var release_fish_button: Label = %ReleaseFishButton
@onready var sell_fish_button: Label = %SellFishButton

var _fish_data: Dictionary = {}
var _confirm_panel: PanelContainer

func _ready() -> void:
	back_to_inventory_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_back_to_inventory()
	)
	back_to_pond_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_back_to_pond()
	)
	release_fish_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_release_pressed()
	)
	sell_fish_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_sell_pressed()
	)

	var fish_data: Variant = GameState.get_meta("selected_fish") if GameState.has_meta("selected_fish") else null
	if fish_data is Dictionary:
		_fish_data = fish_data
		_display_fish(fish_data)
	else:
		species_label.text = "No fish data"

func _display_fish(data: Dictionary) -> void:
	var rarity: String = data.get("rarity", "common")

	species_label.text = data.get("species", "Unknown")

	edition_label.text = "%d / %d" % [
		data.get("edition_number", 0),
		data.get("edition_size", 0),
	]

	size_label.text = "Size: %s" % data.get("size_variant", "normal").capitalize()
	color_label.text = "Color: %s" % data.get("color_variant", "normal").capitalize()

	var rarity_path := "res://resources/sprites/ui/rarity_%s.png" % rarity
	if ResourceLoader.exists(rarity_path):
		rarity_icon.texture = load(rarity_path)
	else:
		rarity_icon.visible = false

	_display_fish_sprite(data)

func _display_fish_sprite(data: Dictionary) -> void:
	var species: String = data.get("species", "Unknown")
	var sprite_path := "res://resources/sprites/fish/%s.png" % species.to_lower().replace(" ", "_")

	var color_variant: String = data.get("color_variant", "normal")
	var size_variant: String = data.get("size_variant", "normal")
	if not ResourceLoader.exists(sprite_path):
		sprite_path = "res://resources/sprites/fish/fish_placeholder.png"
	var sprite_size := 160.0
	match size_variant:
		"mini": sprite_size = 80.0
		"large": sprite_size = 240.0
		"giant": sprite_size = 300.0
	var texture_rect := TextureRect.new()
	texture_rect.texture = load(sprite_path)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(sprite_size * 1.6, sprite_size)
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.modulate = _color_variant_modulate(color_variant)
	fish_sprite_container.add_child(texture_rect)

static func _color_variant_modulate(color_variant: String) -> Color:
	match color_variant:
		"albino": return Color(1.5, 1.5, 1.7)
		"melanistic": return Color(0.3, 0.3, 0.35)
		"rainbow": return Color(1.2, 0.7, 1.1)
		"neon": return Color(0.6, 1.5, 0.8)
		_: return Color.WHITE

func _on_release_pressed() -> void:
	if _confirm_panel != null:
		return
	_show_release_confirm()

func _show_release_confirm() -> void:
	_confirm_panel = PanelContainer.new()
	_confirm_panel.anchors_preset = Control.PRESET_FULL_RECT
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	_confirm_panel.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.anchor_left = 0.1
	vbox.anchor_right = 0.9
	vbox.anchor_top = 0.3
	vbox.anchor_bottom = 0.7
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.add_child(vbox)

	var species_name: String = _fish_data.get("species", "this fish")
	var rarity: String = _fish_data.get("rarity", "common")
	var xp_map := {"common": 5, "uncommon": 10, "rare": 25, "epic": 50, "legendary": 100}
	var xp_reward: int = xp_map.get(rarity, 5)

	var msg := Label.new()
	msg.text = "Release %s?\nYou will earn %d XP." % [species_name, xp_reward]
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(0.96, 0.94, 0.87))
	var pixel_font = load("res://resources/fonts/pixel.ttf")
	if pixel_font:
		msg.add_theme_font_override("font", pixel_font)
	vbox.add_child(msg)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var confirm_button := Button.new()
	confirm_button.text = "Yes, release"
	confirm_button.add_theme_font_size_override("font_size", 20)
	if pixel_font:
		confirm_button.add_theme_font_override("font", pixel_font)
	confirm_button.pressed.connect(_on_release_confirmed)
	vbox.add_child(confirm_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.add_theme_font_size_override("font_size", 18)
	if pixel_font:
		cancel_button.add_theme_font_override("font", pixel_font)
	cancel_button.pressed.connect(func():
		_confirm_panel.queue_free()
		_confirm_panel = null
	)
	vbox.add_child(cancel_button)

	add_child(_confirm_panel)

func _on_release_confirmed() -> void:
	var fish_id: int = _fish_data.get("id", 0)
	if fish_id == 0:
		return

	var result := await Network.release_fish(fish_id)
	if result.status == 200:
		var xp_earned: int = result.data.get("xp_earned", 0)
		GameState.xp = result.data.get("total_xp", GameState.xp)
		GameState.level = result.data.get("level", GameState.level)
		GameState.total_released += 1

		# Brief XP feedback before navigating back.
		if _confirm_panel:
			for child in _confirm_panel.get_children():
				child.queue_free()
			var feedback := Label.new()
			feedback.text = "+%d XP" % xp_earned
			feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			feedback.add_theme_font_size_override("font_size", 32)
			feedback.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
			var pixel_font = load("res://resources/fonts/pixel.ttf")
			if pixel_font:
				feedback.add_theme_font_override("font", pixel_font)
			_confirm_panel.add_child(feedback)

		await get_tree().create_timer(1.0).timeout
		await SceneTransition.iris_to("res://scenes/inventory/inventory.tscn")
	else:
		if _confirm_panel:
			_confirm_panel.queue_free()
			_confirm_panel = null

func _on_sell_pressed() -> void:
	if _confirm_panel != null:
		return
	_show_sell_confirm()

func _show_sell_confirm() -> void:
	_confirm_panel = PanelContainer.new()
	_confirm_panel.anchors_preset = Control.PRESET_FULL_RECT
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	_confirm_panel.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.add_child(vbox)

	var species_name: String = _fish_data.get("species", "this fish")
	var rarity: String = _fish_data.get("rarity", "common")
	var sell_map := {"common": 5, "uncommon": 10, "rare": 25, "epic": 50, "legendary": 100}
	var sell_price: int = sell_map.get(rarity, 1)

	var pixel_font = load("res://resources/fonts/pixel.ttf")

	var msg := Label.new()
	msg.text = "Sell %s for %d Shells?\nThis edition will be gone forever." % [species_name, sell_price]
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(0.96, 0.94, 0.87))
	if pixel_font:
		msg.add_theme_font_override("font", pixel_font)
	vbox.add_child(msg)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var confirm_button := Button.new()
	confirm_button.text = "Yes, sell"
	confirm_button.add_theme_font_size_override("font_size", 20)
	if pixel_font:
		confirm_button.add_theme_font_override("font", pixel_font)
	confirm_button.pressed.connect(_on_sell_confirmed)
	vbox.add_child(confirm_button)

	var cancel_button := Button.new()
	cancel_button.text = "Cancel"
	cancel_button.add_theme_font_size_override("font_size", 18)
	if pixel_font:
		cancel_button.add_theme_font_override("font", pixel_font)
	cancel_button.pressed.connect(func():
		_confirm_panel.queue_free()
		_confirm_panel = null
	)
	vbox.add_child(cancel_button)

	add_child(_confirm_panel)

func _on_sell_confirmed() -> void:
	var fish_id: int = _fish_data.get("id", 0)
	if fish_id == 0:
		return

	var result := await Network.sell_fish(fish_id)
	if result.status == 200:
		var shells_earned: int = result.data.get("shells_earned", 0)
		GameState.shells = result.data.get("total_shells", GameState.shells)

		if _confirm_panel:
			for child in _confirm_panel.get_children():
				child.queue_free()
			var feedback := Label.new()
			feedback.text = "+%d Shells" % shells_earned
			feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			feedback.add_theme_font_size_override("font_size", 32)
			feedback.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
			var pixel_font = load("res://resources/fonts/pixel.ttf")
			if pixel_font:
				feedback.add_theme_font_override("font", pixel_font)
			_confirm_panel.add_child(feedback)

		await get_tree().create_timer(1.0).timeout
		await SceneTransition.iris_to("res://scenes/inventory/inventory.tscn")
	else:
		if _confirm_panel:
			_confirm_panel.queue_free()
			_confirm_panel = null

func _on_back_to_inventory() -> void:
	await SceneTransition.iris_to("res://scenes/inventory/inventory.tscn")

func _on_back_to_pond() -> void:
	await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")
