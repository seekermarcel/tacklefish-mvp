extends Control
## Displays the caught fish on a card with species, rarity icon, edition, and traits.
## Plays a rarity-based celebration effect before revealing the card.

const PIXEL_FONT := preload("res://resources/fonts/pixel.ttf")

@onready var _vbox: VBoxContainer = $VBox
@onready var caught_label: Label = %CaughtLabel
@onready var fish_sprite_container: CenterContainer = %FishSpriteContainer
@onready var rarity_icon: TextureRect = %RarityIcon
@onready var species_label: Label = %SpeciesLabel
@onready var edition_label: Label = %EditionLabel
@onready var size_label: Label = %SizeLabel
@onready var color_label: Label = %ColorLabel
@onready var cast_again_button: Label = %CastAgainButton
@onready var inventory_button: Label = %InventoryButton

func _ready() -> void:
	caught_label.text = tr("You caught a...")
	cast_again_button.text = tr("Cast Again")
	inventory_button.text = tr("View Inventory")

	cast_again_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_cast_again()
	)
	inventory_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_inventory()
	)

	var fish_data: Variant = GameState.get_meta("last_catch") if GameState.has_meta("last_catch") else null
	if not fish_data is Dictionary:
		species_label.text = tr("No fish data")
		return

	var rarity: String = fish_data.get("rarity", "common")

	# Hide card for dramatic rarities — revealed after celebration.
	if rarity in ["epic", "legendary"]:
		_vbox.modulate.a = 0.0

	await _play_celebration(rarity)

	AudioManager.play_sfx_fish_caught()
	_display_fish(fish_data)

	# Fade the card in for dramatic rarities.
	if rarity in ["epic", "legendary"]:
		var t := create_tween()
		t.tween_property(_vbox, "modulate:a", 1.0, 0.4).set_ease(Tween.EASE_OUT)
		await t.finished

# --- Celebration effects ---

func _play_celebration(rarity: String) -> void:
	match rarity:
		"rare":
			await _flash(Color(0.13, 0.59, 0.95, 0.65), 0.5)
		"epic":
			await _flash(Color(0.55, 0.10, 0.65, 0.85), 0.18)
			await _flash(Color(0.55, 0.10, 0.65, 0.60), 0.45)
			await _shake(7.0, 0.5)
		"legendary":
			await _flash(Color(0.0, 0.0, 0.0, 0.92), 0.25)
			await _text_burst("LEGENDARY!", Color(1.0, 0.85, 0.15))
			await _flash(Color(1.0, 0.72, 0.0, 0.90), 0.12)
			await _flash(Color(1.0, 0.72, 0.0, 0.75), 0.12)
			await _flash(Color(1.0, 0.72, 0.0, 0.55), 0.30)
			await _shake(13.0, 0.65)

func _flash(color: Color, duration: float) -> void:
	var overlay := ColorRect.new()
	overlay.color = color
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	var t := create_tween()
	t.tween_property(overlay, "modulate:a", 0.0, duration)
	await t.finished
	overlay.free()

func _shake(strength: float, duration: float) -> void:
	var steps := int(duration / 0.04)
	var original := position
	for i in steps:
		position = original + Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength) * 0.5
		)
		await get_tree().process_frame
		await get_tree().process_frame
	position = original

func _text_burst(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", 80)
	lbl.add_theme_color_override("font_color", color)
	lbl.add_theme_color_override("font_outline_color", Color(0.08, 0.04, 0.0))
	lbl.add_theme_constant_override("outline_size", 10)
	lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	lbl.add_theme_constant_override("shadow_offset_x", 5)
	lbl.add_theme_constant_override("shadow_offset_y", 5)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.pivot_offset = get_viewport_rect().size / 2.0
	lbl.scale = Vector2(0.15, 0.15)
	lbl.modulate.a = 0.0
	add_child(lbl)

	# Zoom in + fade in
	var t1 := create_tween().set_parallel(true)
	t1.tween_property(lbl, "scale", Vector2(1.05, 1.05), 0.38) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t1.tween_property(lbl, "modulate:a", 1.0, 0.22)
	await t1.finished

	# Hold
	await get_tree().create_timer(0.32).timeout

	# Fade out
	var t2 := create_tween()
	t2.tween_property(lbl, "modulate:a", 0.0, 0.22)
	await t2.finished

	lbl.free()

# --- Display ---

func _display_fish(data: Dictionary) -> void:
	var rarity: String = data.get("rarity", "common")

	species_label.text = tr(data.get("species", "Unknown"))

	edition_label.text = "%d / %d" % [
		data.get("edition_number", 0),
		data.get("edition_size", 0),
	]

	size_label.text = tr("Size: %s") % tr(data.get("size_variant", "normal"))
	color_label.text = tr("Color: %s") % tr(data.get("color_variant", "normal"))

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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")

func _on_cast_again() -> void:
	await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")

func _on_inventory() -> void:
	await SceneTransition.iris_to("res://scenes/inventory/inventory.tscn")
