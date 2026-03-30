extends PanelContainer
## Settings popup with backup code generation and account recovery.

signal closed

var _code_label: Label
var _code_input: LineEdit
var _status_label: Label
var _generate_button: Button
var _claim_button: Button
var _close_button: Button

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	# Fill most of the screen width with padding
	set_anchors_preset(Control.PRESET_CENTER)
	anchor_left = 0.05
	anchor_right = 0.95
	anchor_top = 0.15
	anchor_bottom = 0.85
	grow_horizontal = Control.GROW_DIRECTION_BOTH
	grow_vertical = Control.GROW_DIRECTION_BOTH

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	margin.add_child(vbox)

	# Title
	var title := Label.new()
	title.text = "Backup Code"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 32)
	vbox.add_child(title)

	# Current code display
	_code_label = Label.new()
	_code_label.text = "Loading..."
	_code_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_label.add_theme_font_size_override("font_size", 28)
	_code_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vbox.add_child(_code_label)

	# Generate button
	_generate_button = Button.new()
	_generate_button.text = "Generate New Code"
	_generate_button.pressed.connect(_on_generate_pressed)
	vbox.add_child(_generate_button)

	# Separator
	vbox.add_child(HSeparator.new())

	# Restore section
	var restore_label := Label.new()
	restore_label.text = "Restore Account"
	restore_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	restore_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(restore_label)

	_code_input = LineEdit.new()
	_code_input.placeholder_text = "Enter backup code (XXXX-XXXX-XXXX)"
	_code_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_code_input.max_length = 14
	vbox.add_child(_code_input)

	_claim_button = Button.new()
	_claim_button.text = "Restore"
	_claim_button.pressed.connect(_on_claim_pressed)
	vbox.add_child(_claim_button)

	# Status
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.add_theme_font_size_override("font_size", 18)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(_status_label)

	# Close button
	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.pressed.connect(_on_close_pressed)
	vbox.add_child(_close_button)

	# Load existing code if authenticated
	if Auth.has_token():
		_load_existing_code()
	else:
		_code_label.text = "No code yet"
		_generate_button.visible = false

func _load_existing_code() -> void:
	var result := await Network.get_transfer_code()
	if result.status == 200:
		var code = result.data.get("transfer_code")
		if code == null:
			_code_label.text = "No code yet"
		else:
			_code_label.text = str(code)
	else:
		_code_label.text = "Could not load code"

func _on_generate_pressed() -> void:
	_generate_button.disabled = true
	_status_label.text = "Generating..."
	var result := await Network.generate_transfer_code()
	_generate_button.disabled = false
	if result.status == 200:
		_code_label.text = result.data.get("transfer_code", "???")
		_status_label.text = "Save this code! You need it to restore your account."
	else:
		_status_label.text = "Failed to generate code."

func _on_claim_pressed() -> void:
	var code := _code_input.text.strip_edges()
	if code.is_empty():
		_status_label.text = "Please enter a backup code."
		return

	_claim_button.disabled = true
	_status_label.text = "Restoring..."
	var result := await Network.claim_transfer_code(Auth.device_id, code)
	_claim_button.disabled = false

	if result.status == 200:
		_status_label.text = "Account restored! Player #%d" % GameState.player_id
		# Reload existing code for display
		_load_existing_code()
	elif result.status == 404:
		_status_label.text = "Invalid code. Please check and try again."
	elif result.status == 400:
		_status_label.text = "Wrong code format. Use XXXX-XXXX-XXXX."
	else:
		_status_label.text = "Restore failed. Check your connection."

func _on_close_pressed() -> void:
	closed.emit()
	queue_free()
