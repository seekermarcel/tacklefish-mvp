extends Control
## Marketplace scene with Browse and My Listings tabs.

const PIXEL_FONT := preload("res://resources/fonts/pixel.ttf")
const PAGE_SIZE := 20
const RARITY_COLORS := {
	"common": Color(0.62, 0.62, 0.62),
	"uncommon": Color(0.30, 0.69, 0.31),
	"rare": Color(0.13, 0.59, 0.95),
	"epic": Color(0.61, 0.15, 0.69),
	"legendary": Color(1.0, 0.60, 0.0),
}

var browse_tab_button: Button
var my_listings_tab_button: Button
var filter_row: HBoxContainer
var sort_button: Button
var scroll_container: ScrollContainer
var listings_container: VBoxContainer
var load_more_button: Button
var status_label: Label
var back_button: Button
var shells_label: Label

enum Tab { BROWSE, MY_LISTINGS }
var _current_tab: Tab = Tab.BROWSE
var _browse_offset: int = 0
var _browse_total: int = 0
var _current_rarity: String = ""
var _current_sort: String = "newest"
var _confirm_panel: PanelContainer

func _ready() -> void:
	_build_ui()
	_setup_rarity_filters()
	_update_shells_display()
	_switch_tab(Tab.BROWSE)

func _build_ui() -> void:
	# Dark background
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.14, 0.2)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	# Main layout
	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	vbox.offset_left = 16.0
	vbox.offset_top = 50.0
	vbox.offset_right = -16.0
	vbox.offset_bottom = -40.0
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	# Header row
	var header := HBoxContainer.new()
	header.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_theme_constant_override("separation", 16)
	vbox.add_child(header)

	var title_label := Label.new()
	title_label.text = "Market"
	title_label.add_theme_color_override("font_color", Color(0.96, 0.94, 0.87))
	title_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.04))
	title_label.add_theme_constant_override("outline_size", 8)
	title_label.add_theme_font_override("font", PIXEL_FONT)
	title_label.add_theme_font_size_override("font_size", 28)
	header.add_child(title_label)

	shells_label = Label.new()
	shells_label.text = "0 Shells"
	shells_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	shells_label.add_theme_color_override("font_outline_color", Color(0.06, 0.05, 0.04))
	shells_label.add_theme_constant_override("outline_size", 4)
	shells_label.add_theme_font_override("font", PIXEL_FONT)
	shells_label.add_theme_font_size_override("font_size", 20)
	header.add_child(shells_label)

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	tab_bar.add_theme_constant_override("separation", 40)
	vbox.add_child(tab_bar)

	browse_tab_button = Button.new()
	browse_tab_button.text = "Browse"
	browse_tab_button.flat = true
	browse_tab_button.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	browse_tab_button.add_theme_font_override("font", PIXEL_FONT)
	browse_tab_button.add_theme_font_size_override("font_size", 22)
	browse_tab_button.pressed.connect(func(): _switch_tab(Tab.BROWSE))
	tab_bar.add_child(browse_tab_button)

	my_listings_tab_button = Button.new()
	my_listings_tab_button.text = "My Listings"
	my_listings_tab_button.flat = true
	my_listings_tab_button.add_theme_color_override("font_color", Color(0.6, 0.58, 0.52))
	my_listings_tab_button.add_theme_font_override("font", PIXEL_FONT)
	my_listings_tab_button.add_theme_font_size_override("font_size", 22)
	my_listings_tab_button.pressed.connect(func(): _switch_tab(Tab.MY_LISTINGS))
	tab_bar.add_child(my_listings_tab_button)

	# Filter row
	filter_row = HBoxContainer.new()
	filter_row.alignment = BoxContainer.ALIGNMENT_CENTER
	filter_row.add_theme_constant_override("separation", 6)
	vbox.add_child(filter_row)

	sort_button = Button.new()
	sort_button.text = "Newest"
	sort_button.add_theme_font_override("font", PIXEL_FONT)
	sort_button.add_theme_font_size_override("font_size", 14)
	sort_button.pressed.connect(_cycle_sort)
	filter_row.add_child(sort_button)

	# Scrollable listings
	scroll_container = ScrollContainer.new()
	scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll_container.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll_container.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	vbox.add_child(scroll_container)

	listings_container = VBoxContainer.new()
	listings_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	listings_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	listings_container.add_theme_constant_override("separation", 8)
	scroll_container.add_child(listings_container)

	# Load more button
	load_more_button = Button.new()
	load_more_button.text = "Load More"
	load_more_button.visible = false
	load_more_button.add_theme_font_override("font", PIXEL_FONT)
	load_more_button.add_theme_font_size_override("font_size", 18)
	load_more_button.pressed.connect(_on_load_more)
	vbox.add_child(load_more_button)

	# Status label
	status_label = Label.new()
	status_label.text = "Loading..."
	status_label.visible = false
	status_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	status_label.add_theme_font_override("font", PIXEL_FONT)
	status_label.add_theme_font_size_override("font_size", 16)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(status_label)

	# Back button
	back_button = Button.new()
	back_button.text = "Back to Pond"
	back_button.flat = true
	back_button.add_theme_color_override("font_color", Color(0.96, 0.94, 0.87))
	back_button.add_theme_font_override("font", PIXEL_FONT)
	back_button.add_theme_font_size_override("font_size", 20)
	back_button.pressed.connect(func(): SceneTransition.iris_to("res://scenes/fishing/fishing.tscn"))
	vbox.add_child(back_button)

func _update_shells_display() -> void:
	shells_label.text = "%d Shells" % GameState.shells

func _setup_rarity_filters() -> void:
	# Remove all children except sort_button.
	for child in filter_row.get_children():
		if child != sort_button:
			child.queue_free()

	var rarities := ["", "common", "uncommon", "rare", "epic", "legendary"]
	var labels := ["All", "Common", "Uncommon", "Rare", "Epic", "Legendary"]

	for i in rarities.size():
		var btn := Button.new()
		btn.text = labels[i]
		btn.add_theme_font_size_override("font_size", 14)
		btn.add_theme_font_override("font", PIXEL_FONT)
		var rarity_val := rarities[i]
		btn.pressed.connect(func(): _on_rarity_filter(rarity_val))
		filter_row.add_child(btn)
		filter_row.move_child(btn, filter_row.get_child_count() - 2) # before sort button

func _on_rarity_filter(rarity: String) -> void:
	_current_rarity = rarity
	_browse_offset = 0
	_clear_listings()
	_load_browse()

func _cycle_sort() -> void:
	match _current_sort:
		"newest": _current_sort = "price_asc"
		"price_asc": _current_sort = "price_desc"
		_: _current_sort = "newest"

	var sort_labels := {"newest": "Newest", "price_asc": "Price ^", "price_desc": "Price v"}
	sort_button.text = sort_labels.get(_current_sort, "Sort")
	_browse_offset = 0
	_clear_listings()
	_load_browse()

func _switch_tab(tab: Tab) -> void:
	_current_tab = tab
	_clear_listings()

	var active_color := Color(1.0, 0.85, 0.4)
	var inactive_color := Color(0.6, 0.58, 0.52)

	browse_tab_button.add_theme_color_override("font_color", active_color if tab == Tab.BROWSE else inactive_color)
	my_listings_tab_button.add_theme_color_override("font_color", active_color if tab == Tab.MY_LISTINGS else inactive_color)

	filter_row.visible = (tab == Tab.BROWSE)

	if tab == Tab.BROWSE:
		_browse_offset = 0
		_load_browse()
	else:
		_load_my_listings()

func _clear_listings() -> void:
	for child in listings_container.get_children():
		child.queue_free()
	load_more_button.visible = false
	status_label.visible = false

func _load_browse() -> void:
	status_label.text = "Loading..."
	status_label.visible = true

	var result := await Network.browse_listings(PAGE_SIZE, _browse_offset, _current_rarity, _current_sort)
	status_label.visible = false

	if result.status != 200:
		status_label.text = "Failed to load listings"
		status_label.visible = true
		return

	var data: Dictionary = result.data
	var listings: Array = data.get("listings", [])
	_browse_total = data.get("total", 0)

	if listings.is_empty() and _browse_offset == 0:
		status_label.text = "No listings found"
		status_label.visible = true
		return

	for listing in listings:
		_add_browse_listing_row(listing)

	_browse_offset += listings.size()
	load_more_button.visible = (_browse_offset < _browse_total)

func _load_my_listings() -> void:
	status_label.text = "Loading..."
	status_label.visible = true

	var result := await Network.my_listings()
	status_label.visible = false

	if result.status != 200:
		status_label.text = "Failed to load listings"
		status_label.visible = true
		return

	var listings: Array = result.data.get("listings", [])

	if listings.is_empty():
		status_label.text = "No active listings"
		status_label.visible = true
		return

	for listing in listings:
		_add_my_listing_row(listing)

func _on_load_more() -> void:
	_load_browse()

func _add_browse_listing_row(listing: Dictionary) -> void:
	var row := _create_listing_row(listing)

	var fish_data: Dictionary = listing.get("fish", {})
	var price: int = listing.get("price", 0)
	var listing_id: int = listing.get("listing_id", 0)

	var buy_btn := Button.new()
	buy_btn.text = "Buy %d" % price
	buy_btn.add_theme_font_size_override("font_size", 16)
	buy_btn.add_theme_font_override("font", PIXEL_FONT)
	buy_btn.custom_minimum_size = Vector2(120, 40)
	buy_btn.pressed.connect(func(): _on_buy_pressed(listing_id, price, fish_data))
	row.add_child(buy_btn)

	listings_container.add_child(row)

func _add_my_listing_row(listing: Dictionary) -> void:
	var row := _create_listing_row(listing)

	var listing_id: int = listing.get("listing_id", 0)

	var btn_box := VBoxContainer.new()
	btn_box.custom_minimum_size = Vector2(100, 0)

	var edit_btn := Button.new()
	edit_btn.text = "Edit"
	edit_btn.add_theme_font_size_override("font_size", 14)
	edit_btn.add_theme_font_override("font", PIXEL_FONT)
	edit_btn.pressed.connect(func(): _on_edit_pressed(listing_id))
	btn_box.add_child(edit_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 14)
	cancel_btn.add_theme_font_override("font", PIXEL_FONT)
	cancel_btn.pressed.connect(func(): _on_cancel_pressed(listing_id))
	btn_box.add_child(cancel_btn)

	row.add_child(btn_box)
	listings_container.add_child(row)

func _create_listing_row(listing: Dictionary) -> HBoxContainer:
	var fish_data: Dictionary = listing.get("fish", {})
	var price: int = listing.get("price", 0)
	var species: String = fish_data.get("species", "Unknown")
	var rarity: String = fish_data.get("rarity", "common")
	var edition_num: int = fish_data.get("edition_number", 0)
	var edition_size: int = fish_data.get("edition_size", 0)
	var color_variant: String = fish_data.get("color_variant", "normal")
	var size_variant: String = fish_data.get("size_variant", "normal")

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 80)
	row.add_theme_constant_override("separation", 12)

	# Fish sprite.
	var sprite_path := "res://resources/sprites/fish/%s.png" % species.to_lower().replace(" ", "_")
	if not ResourceLoader.exists(sprite_path):
		sprite_path = "res://resources/sprites/fish/fish_placeholder.png"
	var tex_rect := TextureRect.new()
	tex_rect.texture = load(sprite_path)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tex_rect.custom_minimum_size = Vector2(70, 70)
	tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	row.add_child(tex_rect)

	# Info column.
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = species
	name_label.add_theme_font_size_override("font_size", 18)
	name_label.add_theme_color_override("font_color", RARITY_COLORS.get(rarity, Color.WHITE))
	name_label.add_theme_font_override("font", PIXEL_FONT)
	info.add_child(name_label)

	var detail_label := Label.new()
	detail_label.text = "#%d/%d  %s  %s" % [edition_num, edition_size, size_variant.capitalize(), color_variant.capitalize()]
	detail_label.add_theme_font_size_override("font_size", 12)
	detail_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.65))
	detail_label.add_theme_font_override("font", PIXEL_FONT)
	info.add_child(detail_label)

	var price_label := Label.new()
	price_label.text = "%d Shells" % price
	price_label.add_theme_font_size_override("font_size", 16)
	price_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4))
	price_label.add_theme_font_override("font", PIXEL_FONT)
	info.add_child(price_label)

	row.add_child(info)
	return row

# --- Dialogs ---

func _on_buy_pressed(listing_id: int, price: int, fish_data: Dictionary) -> void:
	if _confirm_panel != null:
		return
	var species: String = fish_data.get("species", "this fish")
	_show_confirm("Buy %s for %d Shells?" % [species, price], "Yes, buy", func():
		_do_buy(listing_id)
	)

func _do_buy(listing_id: int) -> void:
	var result := await Network.buy_listing(listing_id)
	if result.status == 200:
		var spent: int = result.data.get("shells_spent", 0)
		GameState.shells = result.data.get("remaining_shells", GameState.shells)
		_show_feedback("+1 Fish  -%d Shells" % spent, Color(0.4, 1.0, 0.5))
		await get_tree().create_timer(1.0).timeout
		_dismiss_confirm()
		_update_shells_display()
		_switch_tab(Tab.BROWSE)
	else:
		var err: String = result.data.get("error", "Purchase failed")
		_show_feedback(err, Color(1.0, 0.4, 0.4))
		await get_tree().create_timer(1.5).timeout
		_dismiss_confirm()

func _on_edit_pressed(listing_id: int) -> void:
	if _confirm_panel != null:
		return
	_show_price_input("New price:", func(new_price: int):
		_do_edit_price(listing_id, new_price)
	)

func _do_edit_price(listing_id: int, new_price: int) -> void:
	var result := await Network.edit_listing_price(listing_id, new_price)
	if result.status == 200:
		_show_feedback("Price updated", Color(0.4, 1.0, 0.5))
		await get_tree().create_timer(0.8).timeout
		_dismiss_confirm()
		_switch_tab(Tab.MY_LISTINGS)
	else:
		_dismiss_confirm()

func _on_cancel_pressed(listing_id: int) -> void:
	if _confirm_panel != null:
		return
	_show_confirm("Cancel this listing?\nThe fish returns to your inventory.", "Yes, cancel", func():
		_do_cancel(listing_id)
	)

func _do_cancel(listing_id: int) -> void:
	var result := await Network.cancel_listing(listing_id)
	if result.status == 200:
		_show_feedback("Listing cancelled", Color(0.4, 1.0, 0.5))
		await get_tree().create_timer(0.8).timeout
		_dismiss_confirm()
		_switch_tab(Tab.MY_LISTINGS)
	else:
		_dismiss_confirm()

func _show_confirm(message: String, confirm_text: String, on_confirm: Callable) -> void:
	_confirm_panel = PanelContainer.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	_confirm_panel.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.add_child(vbox)

	var msg := Label.new()
	msg.text = message
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(0.96, 0.94, 0.87))
	msg.add_theme_font_override("font", PIXEL_FONT)
	vbox.add_child(msg)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 20)
	vbox.add_child(spacer)

	var confirm_btn := Button.new()
	confirm_btn.text = confirm_text
	confirm_btn.add_theme_font_size_override("font_size", 20)
	confirm_btn.add_theme_font_override("font", PIXEL_FONT)
	confirm_btn.pressed.connect(on_confirm)
	vbox.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.add_theme_font_override("font", PIXEL_FONT)
	cancel_btn.pressed.connect(_dismiss_confirm)
	vbox.add_child(cancel_btn)

	add_child(_confirm_panel)

func _show_price_input(message: String, on_confirm: Callable) -> void:
	_confirm_panel = PanelContainer.new()
	_confirm_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_confirm_panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var stylebox := StyleBoxFlat.new()
	stylebox.bg_color = Color(0.0, 0.0, 0.0, 0.7)
	_confirm_panel.add_theme_stylebox_override("panel", stylebox)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	_confirm_panel.add_child(vbox)

	var msg := Label.new()
	msg.text = message
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 20)
	msg.add_theme_color_override("font_color", Color(0.96, 0.94, 0.87))
	msg.add_theme_font_override("font", PIXEL_FONT)
	vbox.add_child(msg)

	var price_input := LineEdit.new()
	price_input.placeholder_text = "1 - 99999"
	price_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	price_input.add_theme_font_size_override("font_size", 22)
	price_input.add_theme_font_override("font", PIXEL_FONT)
	price_input.custom_minimum_size = Vector2(200, 40)
	vbox.add_child(price_input)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	vbox.add_child(spacer)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.add_theme_font_size_override("font_size", 20)
	confirm_btn.add_theme_font_override("font", PIXEL_FONT)
	confirm_btn.pressed.connect(func():
		var price_text: String = price_input.text.strip_edges()
		if not price_text.is_valid_int():
			return
		var price: int = price_text.to_int()
		if price < 1 or price > 99999:
			return
		on_confirm.call(price)
	)
	vbox.add_child(confirm_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.add_theme_font_size_override("font_size", 18)
	cancel_btn.add_theme_font_override("font", PIXEL_FONT)
	cancel_btn.pressed.connect(_dismiss_confirm)
	vbox.add_child(cancel_btn)

	add_child(_confirm_panel)

func _show_feedback(text: String, color: Color) -> void:
	if _confirm_panel:
		for child in _confirm_panel.get_children():
			child.queue_free()
		var feedback := Label.new()
		feedback.text = text
		feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		feedback.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		feedback.add_theme_font_size_override("font_size", 28)
		feedback.add_theme_color_override("font_color", color)
		feedback.add_theme_font_override("font", PIXEL_FONT)
		_confirm_panel.add_child(feedback)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _confirm_panel != null:
			_dismiss_confirm()
		else:
			await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")

func _dismiss_confirm() -> void:
	if _confirm_panel:
		_confirm_panel.queue_free()
		_confirm_panel = null
