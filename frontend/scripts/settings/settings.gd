extends Control
## Settings scene. Music, SFX, language, and pool viewer.

const PIXEL_FONT := preload("res://resources/fonts/pixel.ttf")

const RARITY_COLORS := {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.30, 0.69, 0.31),
	"rare": Color(0.13, 0.59, 0.95),
	"epic": Color(0.61, 0.15, 0.69),
	"legendary": Color(1.0, 0.60, 0.0),
}

var _music_btn: Button
var _sfx_btn: Button
var _pool_overlay: Control
var _pool_list: VBoxContainer
var _pool_status: Label
var _id_input: LineEdit
var _id_status: Label

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.13, 0.10, 0.07)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Back button — top left
	var back_btn := Button.new()
	back_btn.text = tr("Back")
	back_btn.add_theme_font_override("font", PIXEL_FONT)
	back_btn.add_theme_font_size_override("font_size", 16)
	back_btn.custom_minimum_size = Vector2(100, 48)
	back_btn.position = Vector2(16, 16)
	back_btn.pressed.connect(_on_back)
	add_child(back_btn)

	# Title
	var title := Label.new()
	title.text = tr("Settings")
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

	# Scrollable content
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 32.0
	scroll.offset_right = -32.0
	scroll.offset_top = 100.0
	scroll.offset_bottom = -32.0
	add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 24)
	scroll.add_child(vbox)

	# --- Audio section ---
	vbox.add_child(_section_label(tr("Music")))
	var music_row := _row()
	music_row.add_child(_row_label(tr("Music")))
	_music_btn = _toggle_button(AudioManager.is_music_enabled())
	_music_btn.pressed.connect(_on_music_toggle)
	music_row.add_child(_music_btn)
	vbox.add_child(music_row)

	var sfx_row := _row()
	sfx_row.add_child(_row_label(tr("Sound")))
	_sfx_btn = _toggle_button(AudioManager.is_sfx_enabled())
	_sfx_btn.pressed.connect(_on_sfx_toggle)
	sfx_row.add_child(_sfx_btn)
	vbox.add_child(sfx_row)

	vbox.add_child(_divider())

	# --- Language section ---
	vbox.add_child(_section_label(tr("Language")))
	var lang_row := _row()
	lang_row.add_child(_row_label(tr("Language")))
	var lang_buttons := HBoxContainer.new()
	lang_buttons.add_theme_constant_override("separation", 8)
	for locale: String in ["en", "de"]:
		var btn := Button.new()
		btn.text = locale.to_upper()
		btn.toggle_mode = true
		btn.button_pressed = (I18n.get_language() == locale)
		btn.custom_minimum_size = Vector2(64, 44)
		btn.add_theme_font_override("font", PIXEL_FONT)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_language_pressed.bind(locale))
		lang_buttons.add_child(btn)
	lang_row.add_child(lang_buttons)
	vbox.add_child(lang_row)

	vbox.add_child(_divider())

	# --- Player ID section ---
	vbox.add_child(_section_label(tr("Player ID")))

	# Show current device ID with copy button
	var id_row := _row()
	_id_input = LineEdit.new()
	_id_input.text = Auth.device_id
	_id_input.editable = true
	_id_input.add_theme_font_override("font", PIXEL_FONT)
	_id_input.add_theme_font_size_override("font_size", 11)
	_id_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_id_input.custom_minimum_size = Vector2(0, 44)
	id_row.add_child(_id_input)

	var copy_btn := Button.new()
	copy_btn.text = tr("Copy")
	copy_btn.add_theme_font_override("font", PIXEL_FONT)
	copy_btn.add_theme_font_size_override("font_size", 14)
	copy_btn.custom_minimum_size = Vector2(80, 44)
	copy_btn.pressed.connect(_on_copy_id.bind(copy_btn))
	id_row.add_child(copy_btn)
	vbox.add_child(id_row)

	var apply_btn := Button.new()
	apply_btn.text = tr("Paste & Apply")
	apply_btn.add_theme_font_override("font", PIXEL_FONT)
	apply_btn.add_theme_font_size_override("font_size", 14)
	apply_btn.custom_minimum_size = Vector2(0, 44)
	apply_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	apply_btn.pressed.connect(_on_apply_id)
	vbox.add_child(apply_btn)

	_id_status = Label.new()
	_id_status.add_theme_font_override("font", PIXEL_FONT)
	_id_status.add_theme_font_size_override("font_size", 13)
	_id_status.add_theme_color_override("font_color", Color(0.4, 0.8, 0.4))
	_id_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_id_status.visible = false
	vbox.add_child(_id_status)

	vbox.add_child(_divider())

	# --- Pool section ---
	vbox.add_child(_section_label(tr("Check Pools")))
	var pool_btn := Button.new()
	pool_btn.text = tr("Check Pools")
	pool_btn.add_theme_font_override("font", PIXEL_FONT)
	pool_btn.add_theme_font_size_override("font_size", 18)
	pool_btn.custom_minimum_size = Vector2(0, 56)
	pool_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pool_btn.pressed.connect(_on_pool_pressed)
	vbox.add_child(pool_btn)

	# --- Pool overlay (full-screen, hidden) ---
	_build_pool_overlay()

func _build_pool_overlay() -> void:
	_pool_overlay = Control.new()
	_pool_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pool_overlay.visible = false
	add_child(_pool_overlay)

	var overlay_bg := ColorRect.new()
	overlay_bg.color = Color(0.08, 0.06, 0.04, 0.95)
	overlay_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pool_overlay.add_child(overlay_bg)

	# Header
	var header := Label.new()
	header.text = tr("Available Fish")
	header.add_theme_font_override("font", PIXEL_FONT)
	header.add_theme_font_size_override("font_size", 28)
	header.add_theme_color_override("font_color", Color(0.96, 0.94, 0.87))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.anchor_left = 0.0
	header.anchor_right = 1.0
	header.offset_top = 24.0
	header.offset_bottom = 72.0
	_pool_overlay.add_child(header)

	# Close button
	var close_btn := Button.new()
	close_btn.text = tr("Close")
	close_btn.add_theme_font_override("font", PIXEL_FONT)
	close_btn.add_theme_font_size_override("font_size", 16)
	close_btn.custom_minimum_size = Vector2(100, 48)
	close_btn.position = Vector2(16, 16)
	close_btn.pressed.connect(func(): _pool_overlay.visible = false)
	_pool_overlay.add_child(close_btn)

	# Status label (shown while loading)
	_pool_status = Label.new()
	_pool_status.add_theme_font_override("font", PIXEL_FONT)
	_pool_status.add_theme_font_size_override("font_size", 16)
	_pool_status.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	_pool_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pool_status.anchor_left = 0.0
	_pool_status.anchor_right = 1.0
	_pool_status.offset_top = 80.0
	_pool_status.offset_bottom = 120.0
	_pool_overlay.add_child(_pool_status)

	# Scrollable list
	var scroll := ScrollContainer.new()
	scroll.anchor_left = 0.0
	scroll.anchor_right = 1.0
	scroll.anchor_top = 0.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 24.0
	scroll.offset_right = -24.0
	scroll.offset_top = 90.0
	scroll.offset_bottom = -24.0
	_pool_overlay.add_child(scroll)

	_pool_list = VBoxContainer.new()
	_pool_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pool_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_pool_list)

func _on_pool_pressed() -> void:
	_pool_overlay.visible = true
	_load_pool()

func _load_pool() -> void:
	for child in _pool_list.get_children():
		child.free()
	_pool_status.text = tr("Loading pools...")
	_pool_status.visible = true

	var result := await Network.get_pool()
	_pool_status.visible = false

	if result.status != 200:
		_pool_status.text = tr("Failed to load pools")
		_pool_status.visible = true
		return

	var species_list: Array = result.data if result.data is Array else []
	for entry: Dictionary in species_list:
		_pool_list.add_child(_pool_row(entry))

func _pool_row(entry: Dictionary) -> Control:
	var name: String = entry.get("name", "")
	var rarity: String = entry.get("rarity", "common")
	var remaining: int = entry.get("remaining", 0)
	var edition_size: int = entry.get("edition_size", 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var name_lbl := Label.new()
	name_lbl.text = tr(name)
	name_lbl.add_theme_font_override("font", PIXEL_FONT)
	name_lbl.add_theme_font_size_override("font_size", 15)
	name_lbl.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.WHITE))
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(name_lbl)

	var count_lbl := Label.new()
	count_lbl.text = "%d / %d" % [remaining, edition_size]
	count_lbl.add_theme_font_override("font", PIXEL_FONT)
	count_lbl.add_theme_font_size_override("font_size", 15)
	count_lbl.add_theme_color_override("font_color", Color(0.75, 0.70, 0.60))
	count_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(count_lbl)

	return row

func _on_copy_id(btn: Button) -> void:
	DisplayServer.clipboard_set(Auth.device_id)
	var original := btn.text
	btn.text = tr("Copied!")
	await get_tree().create_timer(1.5).timeout
	btn.text = original

func _on_apply_id() -> void:
	var new_id := _id_input.text.strip_edges()
	if new_id.is_empty() or new_id == Auth.device_id:
		return
	# Save new device ID and re-register.
	Auth.device_id = new_id
	var file := FileAccess.open("user://device_id", FileAccess.WRITE)
	file.store_string(new_id)
	file.close()
	_id_status.text = tr("Applied! Reconnecting...")
	_id_status.visible = true
	await Network.register()
	await SceneTransition.iris_to("res://scenes/main_menu/main_menu.tscn")

func _on_music_toggle() -> void:
	var enabled := not AudioManager.is_music_enabled()
	AudioManager.set_music_enabled(enabled)
	_music_btn.text = tr("ON") if enabled else tr("OFF")

func _on_sfx_toggle() -> void:
	var enabled := not AudioManager.is_sfx_enabled()
	AudioManager.set_sfx_enabled(enabled)
	_sfx_btn.text = tr("ON") if enabled else tr("OFF")

func _on_language_pressed(locale: String) -> void:
	if I18n.get_language() == locale:
		return
	I18n.set_language(locale)
	# Return to main menu so it reloads with the new language.
	SceneTransition.iris_to("res://scenes/main_menu/main_menu.tscn")

func _on_back() -> void:
	await SceneTransition.iris_to("res://scenes/main_menu/main_menu.tscn")

# --- Helpers ---

func _section_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.30))
	return lbl

func _row_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_override("font", PIXEL_FONT)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.92, 0.88, 0.78))
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return lbl

func _toggle_button(enabled: bool) -> Button:
	var btn := Button.new()
	btn.text = tr("ON") if enabled else tr("OFF")
	btn.add_theme_font_override("font", PIXEL_FONT)
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(80, 48)
	return btn

func _row() -> HBoxContainer:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_theme_constant_override("separation", 16)
	hbox.custom_minimum_size = Vector2(0, 56)
	return hbox

func _divider() -> Control:
	var line := ColorRect.new()
	line.color = Color(0.35, 0.28, 0.18, 0.6)
	line.custom_minimum_size = Vector2(0, 2)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line
