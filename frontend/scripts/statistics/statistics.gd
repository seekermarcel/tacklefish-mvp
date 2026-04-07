extends Control
## Statistics screen. Fetches the full inventory and computes collection stats.

const PIXEL_FONT := preload("res://resources/fonts/pixel.ttf")
const TOTAL_SPECIES := 12

const RARITY_ORDER := ["common", "uncommon", "rare", "epic", "legendary"]
const RARITY_COLORS := {
	"common":    Color(0.62, 0.62, 0.62),
	"uncommon":  Color(0.30, 0.69, 0.31),
	"rare":      Color(0.13, 0.59, 0.95),
	"epic":      Color(0.61, 0.15, 0.69),
	"legendary": Color(1.0,  0.60, 0.0),
}

var _content: VBoxContainer
var _status: Label

func _ready() -> void:
	_build_ui()
	_load_stats()

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.10, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Back button
	var back_btn := Button.new()
	back_btn.text = tr("Back")
	back_btn.add_theme_font_override("font", PIXEL_FONT)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.custom_minimum_size = Vector2(100, 48)
	back_btn.position = Vector2(16, 16)
	back_btn.pressed.connect(func(): SceneTransition.iris_to("res://scenes/settings/settings.tscn"))
	add_child(back_btn)

	# Title
	var title := Label.new()
	title.text = tr("Statistics")
	title.add_theme_font_override("font", PIXEL_FONT)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(0.96, 0.94, 0.87))
	title.add_theme_color_override("font_outline_color", Color(0.12, 0.10, 0.08))
	title.add_theme_constant_override("outline_size", 6)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.anchor_left = 0.0
	title.anchor_right = 1.0
	title.offset_top = 24.0
	title.offset_bottom = 80.0
	add_child(title)

	# Status label (loading / error)
	_status = Label.new()
	_status.add_theme_font_override("font", PIXEL_FONT)
	_status.add_theme_font_size_override("font_size", 18)
	_status.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_status.anchor_left = 0.0
	_status.anchor_right = 1.0
	_status.anchor_top = 0.3
	_status.anchor_bottom = 0.7
	add_child(_status)

	# Scrollable stats content (hidden until loaded)
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 32.0
	scroll.offset_right = -32.0
	scroll.offset_top = 100.0
	scroll.offset_bottom = -24.0
	scroll.visible = false
	add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 20)
	scroll.add_child(_content)

	# Store scroll ref so we can show it after loading
	_content.set_meta("scroll", scroll)

func _load_stats() -> void:
	_status.text = tr("Loading stats...")
	_status.visible = true

	# Paginate through all fish (backend caps limit at 100).
	var all_fish: Array = []
	var offset := 0
	var total := 1  # will be set after first response

	while offset < total:
		var result := await Network.get_inventory(100, offset)
		if result.status != 200:
			_status.text = tr("Failed to load")
			return
		var data: Dictionary = result.data
		total = data.get("total", 0)
		var page: Array = data.get("fish", [])
		all_fish.append_array(page)
		offset += page.size()
		if page.is_empty():
			break

	_status.visible = false

	if all_fish.is_empty():
		_status.text = tr("No fish caught yet")
		_status.visible = true
		return

	var stats := _compute(all_fish)
	_populate(stats)

	var scroll: ScrollContainer = _content.get_meta("scroll")
	scroll.visible = true

func _compute(fish: Array) -> Dictionary:
	var rarity_counts := {}
	var species_counts := {}
	var species_set := {}
	var best_rarity_rank := -1
	var best_rarity_fish: Dictionary = {}
	var best_edition_fish: Dictionary = {}
	var variant_count := 0

	for f: Dictionary in fish:
		var species: String = f.get("species", "")
		var rarity: String  = f.get("rarity", "common")
		var edition: int    = f.get("edition_number", 0)
		var color: String   = f.get("color_variant", "normal")

		species_set[species] = true
		rarity_counts[rarity] = rarity_counts.get(rarity, 0) + 1
		species_counts[species] = species_counts.get(species, 0) + 1

		var rank: int = RARITY_ORDER.find(rarity)
		if rank > best_rarity_rank:
			best_rarity_rank = rank
			best_rarity_fish = f

		if best_edition_fish.is_empty() or edition < best_edition_fish.get("edition_number", 999999):
			best_edition_fish = f

		if color != "normal":
			variant_count += 1

	# Most caught species
	var top_species := ""
	var top_count := 0
	for sp: String in species_counts:
		if species_counts[sp] > top_count:
			top_count = species_counts[sp]
			top_species = sp

	return {
		"total": fish.size(),
		"species_count": species_set.size(),
		"rarity_counts": rarity_counts,
		"best_rarity_fish": best_rarity_fish,
		"best_edition_fish": best_edition_fish,
		"top_species": top_species,
		"top_count": top_count,
		"variant_count": variant_count,
	}

func _populate(s: Dictionary) -> void:
	# --- Total & species ---
	_content.add_child(_stat_row(tr("Total Caught"), "%d" % s.total))
	_content.add_child(_stat_row(
		tr("Species Collected"),
		"%d / %d" % [s.species_count, TOTAL_SPECIES]
	))

	_content.add_child(_divider())

	# --- Rarity breakdown ---
	_content.add_child(_section_label(tr("By Rarity")))
	var counts: Dictionary = s.rarity_counts
	for rarity: String in RARITY_ORDER:
		var n: int = counts.get(rarity, 0)
		var color: Color = RARITY_COLORS.get(rarity, Color.WHITE)
		_content.add_child(_stat_row(tr(rarity), "%d" % n, color))

	_content.add_child(_divider())

	# --- Highlights ---
	_content.add_child(_section_label(tr("Most Caught")))
	var top: String = s.top_species
	_content.add_child(_stat_row(
		tr(top) if not top.is_empty() else "—",
		"%d %s" % [s.top_count, tr("times")]
	))

	_content.add_child(_divider())

	_content.add_child(_section_label(tr("Rarest Catch")))
	var best: Dictionary = s.best_rarity_fish
	if not best.is_empty():
		var r: String = best.get("rarity", "")
		_content.add_child(_stat_row(
			tr(best.get("species", "")),
			tr(r),
			RARITY_COLORS.get(r, Color.WHITE)
		))

	_content.add_child(_divider())

	_content.add_child(_section_label(tr("Most Exclusive")))
	var excl: Dictionary = s.best_edition_fish
	if not excl.is_empty():
		_content.add_child(_stat_row(
			tr(excl.get("species", "")),
			tr("Edition #%d") % excl.get("edition_number", 0)
		))

	_content.add_child(_divider())

	_content.add_child(_stat_row(
		tr("Special Variants"),
		"%d" % s.variant_count
	))

# --- UI helpers ---

func _stat_row(label: String, value: String, label_color: Color = Color(0.92, 0.88, 0.78)) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.custom_minimum_size = Vector2(0, 48)
	row.add_theme_constant_override("separation", 12)

	var lbl := Label.new()
	lbl.text = label
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", label_color)
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lbl)

	var val := Label.new()
	val.text = value
	val.add_theme_font_override("font", PIXEL_FONT)
	val.add_theme_font_size_override("font_size", 18)
	val.add_theme_color_override("font_color", Color(0.96, 0.94, 0.87))
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	val.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(val)

	return row

func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.30))
	return lbl

func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.35, 0.28, 0.18, 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line
