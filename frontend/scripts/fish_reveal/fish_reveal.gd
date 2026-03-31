extends Control
## Displays the caught fish on a card with species, rarity icon, edition, and traits.

@onready var fish_sprite_container: CenterContainer = %FishSpriteContainer
@onready var rarity_icon: TextureRect = %RarityIcon
@onready var species_label: Label = %SpeciesLabel
@onready var edition_label: Label = %EditionLabel
@onready var size_label: Label = %SizeLabel
@onready var color_label: Label = %ColorLabel
@onready var cast_again_button: Label = %CastAgainButton
@onready var inventory_button: Label = %InventoryButton

func _ready() -> void:
	cast_again_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_cast_again()
	)
	inventory_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_inventory()
	)

	AudioManager.play_sfx_fish_caught()
	var fish_data: Variant = GameState.get_meta("last_catch") if GameState.has_meta("last_catch") else null
	if fish_data is Dictionary:
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

	# Load rarity icon
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
	if not ResourceLoader.exists(sprite_path):
		sprite_path = "res://resources/sprites/fish/fish_placeholder.png"
	var texture_rect := TextureRect.new()
	texture_rect.texture = load(sprite_path)
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_rect.custom_minimum_size = Vector2(200, 200)
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

func _on_cast_again() -> void:
	await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")

func _on_inventory() -> void:
	await SceneTransition.iris_to("res://scenes/inventory/inventory.tscn")
