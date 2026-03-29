extends Control
## Displays a fish detail card from the inventory. Same layout as the catch reveal
## but with navigation back to inventory or fishing.

@onready var fish_sprite_container: CenterContainer = %FishSpriteContainer
@onready var rarity_icon: TextureRect = %RarityIcon
@onready var species_label: Label = %SpeciesLabel
@onready var edition_label: Label = %EditionLabel
@onready var size_label: Label = %SizeLabel
@onready var color_label: Label = %ColorLabel
@onready var back_to_inventory_button: Button = %BackToInventoryButton
@onready var back_to_pond_button: Button = %BackToPondButton

func _ready() -> void:
	back_to_inventory_button.pressed.connect(_on_back_to_inventory)
	back_to_pond_button.pressed.connect(_on_back_to_pond)

	var fish_data: Variant = GameState.get_meta("selected_fish") if GameState.has_meta("selected_fish") else null
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

	var rarity_path := "res://resources/sprites/ui/rarity_%s.png" % rarity
	if ResourceLoader.exists(rarity_path):
		rarity_icon.texture = load(rarity_path)
	else:
		rarity_icon.visible = false

	_display_fish_sprite(data)

func _display_fish_sprite(data: Dictionary) -> void:
	var species: String = data.get("species", "Unknown")
	var sprite_path := "res://resources/sprites/fish/%s.png" % species.to_lower().replace(" ", "_")

	if ResourceLoader.exists(sprite_path):
		var color_variant: String = data.get("color_variant", "normal")
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

func _on_back_to_inventory() -> void:
	await SceneTransition.iris_to("res://scenes/inventory/inventory.tscn")

func _on_back_to_pond() -> void:
	await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")
