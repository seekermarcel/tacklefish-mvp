extends Control
## Main menu scene. Auto-registers with the backend on load.

# Point of interest in the source image (normalized 0-1).
# The fisher is roughly centered horizontally, ~70% down.
const BG_FOCUS := Vector2(0.5, 0.70)

@onready var background: AnimatedSprite2D = $Background
@onready var start_button: TextureButton = %StartButton
@onready var exit_button: TextureButton = %ExitButton
@onready var status_label: Label = %StatusLabel

func _get_frame_size() -> Vector2:
	var frames := background.sprite_frames
	var tex := frames.get_frame_texture("default", 0)
	return Vector2(tex.get_size())

func _ready() -> void:
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_fit_background()
	get_tree().root.size_changed.connect(_fit_background)
	AudioManager.play_music()
	AudioManager.play_sounds()
	_auto_register()

func _fit_background() -> void:
	var viewport_size := get_viewport_rect().size
	var tex_size := _get_frame_size()
	# Scale to cover the full viewport.
	var scale_factor := maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
	background.scale = Vector2(scale_factor, scale_factor)
	# Center the image.
	var scaled_size := tex_size * scale_factor
	var offset := (viewport_size - scaled_size) * 0.5
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
	AudioManager.play_sfx_start_game()
	start_button.disabled = true
	exit_button.disabled = true

	var viewport_size := get_viewport_rect().size
	var tex_size := _get_frame_size()

	# Zoom into the fisher + fade UI + iris close all at once (1.0s).
	var zoom_target_scale := background.scale * 2.5
	var focus_in_scaled := BG_FOCUS * tex_size * zoom_target_scale.x
	var zoom_target_pos := viewport_size * 0.5 - focus_in_scaled

	SceneTransition.prepare_close(Vector2(0.5, 0.5))

	var tween := create_tween().set_parallel(true)
	tween.tween_property(background, "scale", zoom_target_scale, 1.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(background, "position", zoom_target_pos, 1.0) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property($CenterContainer, "modulate:a", 0.0, 0.3) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	tween.tween_property(
		SceneTransition._shader_material, "shader_parameter/radius", 0.0, 1.0
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tween.finished

	# Brief black, then scene change + iris open (1.0s).
	await get_tree().create_timer(0.1).timeout
	await SceneTransition.iris_open_with_scene("res://scenes/fishing/fishing.tscn", 1.0)

func _on_exit_pressed() -> void:
	get_tree().quit()
