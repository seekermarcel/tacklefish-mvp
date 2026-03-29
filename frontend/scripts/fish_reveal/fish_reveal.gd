extends Control
## Displays the caught fish with species, rarity, edition, and traits.

const RARITY_COLORS := {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.30, 0.69, 0.31),
	"rare": Color(0.13, 0.59, 0.95),
	"epic": Color(0.61, 0.15, 0.69),
	"legendary": Color(1.0, 0.60, 0.0),
}

@onready var fish_sprite_container: CenterContainer = %FishSpriteContainer
@onready var species_label: Label = %SpeciesLabel
@onready var rarity_label: Label = %RarityLabel
@onready var edition_label: Label = %EditionLabel
@onready var size_label: Label = %SizeLabel
@onready var color_label: Label = %ColorLabel
@onready var cast_again_button: Button = %CastAgainButton
@onready var inventory_button: Button = %InventoryButton

func _ready() -> void:
	cast_again_button.pressed.connect(_on_cast_again)
	inventory_button.pressed.connect(_on_inventory)

	var fish_data: Variant = GameState.get_meta("last_catch") if GameState.has_meta("last_catch") else null
	if fish_data is Dictionary:
		_display_fish(fish_data)
	else:
		species_label.text = "No fish data"

func _display_fish(data: Dictionary) -> void:
	var rarity: String = data.get("rarity", "common")
	var rarity_color: Color = RARITY_COLORS.get(rarity, RARITY_COLORS["common"])

	species_label.text = data.get("species", "Unknown")
	species_label.add_theme_color_override("font_color", rarity_color)

	rarity_label.text = rarity.to_upper()
	rarity_label.add_theme_color_override("font_color", rarity_color)

	edition_label.text = "#%d / %d" % [
		data.get("edition_number", 0),
		data.get("edition_size", 0),
	]

	size_label.text = "Size: %s" % data.get("size_variant", "normal").capitalize()
	color_label.text = "Color: %s" % data.get("color_variant", "normal").capitalize()

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
	else:
		fish_sprite_container.visible = false

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
