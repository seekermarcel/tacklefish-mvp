extends Control
## Main menu scene. Auto-registers with the backend on load.

# Point of interest in the source image (normalized 0-1).
# The angler is at roughly 75% across, 80% down in the 320x320 image.
const BG_FOCUS := Vector2(0.75, 0.80)

@onready var background: Sprite2D = $Background
@onready var start_button: Button = %StartButton
@onready var exit_button: Button = %ExitButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_fit_background()
	get_tree().root.size_changed.connect(_fit_background)
	_auto_register()

func _fit_background() -> void:
	var viewport_size := get_viewport_rect().size
	var tex_size := Vector2(background.texture.get_size())
	# Scale to cover the full viewport.
	var scale_factor := maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
	background.scale = Vector2(scale_factor, scale_factor)
	# Offset so the focus point lands at the viewport center.
	var scaled_size := tex_size * scale_factor
	var focus_pixel := BG_FOCUS * scaled_size
	var viewport_center := viewport_size * 0.5
	var offset := viewport_center - focus_pixel
	# Clamp so we don't show empty space at edges.
	offset.x = clampf(offset.x, viewport_size.x - scaled_size.x, 0.0)
	offset.y = clampf(offset.y, viewport_size.y - scaled_size.y, 0.0)
	background.position = offset

func _auto_register() -> void:
	status_label.text = "Connecting..."
	var result := await Network.register()
	if result.status == 200:
		status_label.text = "Player #%d" % GameState.player_id
		start_button.disabled = false
	else:
		status_label.text = "Connection failed. Check backend."

func _on_start_pressed() -> void:
	start_button.disabled = true
	exit_button.disabled = true

	# Calculate where the angler is on screen (UV coordinates for the iris).
	var viewport_size := get_viewport_rect().size
	var tex_size := Vector2(background.texture.get_size())
	var angler_screen := background.position + BG_FOCUS * tex_size * background.scale
	var angler_uv := angler_screen / viewport_size

	# Zoom into the angler.
	var zoom_target_scale := background.scale * 2.5
	var zoom_target_pos := viewport_size * 0.5 - BG_FOCUS * tex_size * zoom_target_scale.x

	var zoom_tween := create_tween().set_parallel(true)
	zoom_tween.tween_property(background, "scale", zoom_target_scale, 0.8) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	zoom_tween.tween_property(background, "position", zoom_target_pos, 0.8) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	# Fade out the UI while zooming.
	var ui_container := $CenterContainer
	zoom_tween.tween_property(ui_container, "modulate:a", 0.0, 0.4) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)

	await zoom_tween.finished

	# Iris wipe centered on screen — the zoom already put the angler at center.
	await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn", Vector2(0.5, 0.5))

func _on_exit_pressed() -> void:
	get_tree().quit()
