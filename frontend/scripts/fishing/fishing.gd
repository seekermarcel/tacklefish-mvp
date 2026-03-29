extends Control
## Main fishing scene. Manages the cast -> wait -> bite -> minigame -> catch flow.
## Tap anywhere to cast/lock/react. Bottom corner buttons for inventory and market.

enum Phase { IDLE, CASTING, WAITING, BITE, MINIGAME, SENDING }

var current_phase: Phase = Phase.IDLE

# Cast bar state
var cast_position: float = 0.0
var cast_direction: float = 1.0
const CAST_SPEED: float = 1.5
var cast_power: float = 0.0

# Bite reaction state
var bite_time: float = 0.0
const BITE_TIMEOUT: float = 5.0
var pending_timing_score: float = 0.0
var bite_tween: Tween = null

# Idle hint state
const IDLE_HINT_DELAY: float = 5.0
var idle_timer: float = 0.0
var has_cast_before: bool = false
var status_tween: Tween = null

@onready var cast_bar: TextureRect = %CastBar
@onready var cast_fill: ColorRect = %CastBar.get_node("Fill")

@onready var wait_panel: PanelContainer = %WaitPanel
@onready var wait_label: Label = %WaitLabel

@onready var background: AnimatedSprite2D = $Background
@onready var fishing_rod: AnimatedSprite2D = %FishingRod
@onready var bobber: AnimatedSprite2D = %Bobber
@onready var status_label: Label = %StatusLabel
@onready var bite_label: Label = %BiteLabel
@onready var minigame_overlay = %MinigameOverlay
@onready var market_button: TextureButton = %MarketButton
@onready var inventory_button: TextureButton = %InventoryButton

func _ready() -> void:
	inventory_button.pressed.connect(_on_inventory_pressed)
	minigame_overlay.fish_caught.connect(_on_fish_caught)
	minigame_overlay.fish_escaped.connect(_on_fish_escaped)
	_fit_background()
	get_tree().root.size_changed.connect(_fit_background)
	_show_idle()

func _fit_background() -> void:
	var viewport_size := get_viewport_rect().size
	var frames := background.sprite_frames
	var tex := frames.get_frame_texture("default", 0)
	var tex_size := Vector2(tex.get_size())
	var scale_factor := maxf(viewport_size.x / tex_size.x, viewport_size.y / tex_size.y)
	background.scale = Vector2(scale_factor, scale_factor)
	var scaled_size := tex_size * scale_factor
	var offset := (viewport_size - scaled_size) * 0.5
	background.position = offset

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_tap()
	elif event is InputEventScreenTouch and event.pressed:
		_handle_tap()

func _handle_tap() -> void:
	match current_phase:
		Phase.IDLE:
			_start_casting()
		Phase.CASTING:
			_lock_cast()
		Phase.BITE:
			_on_bite_tap()

func _process(delta: float) -> void:
	match current_phase:
		Phase.CASTING:
			cast_position += CAST_SPEED * cast_direction * delta
			if cast_position >= 1.0:
				cast_position = 1.0
				cast_direction = -1.0
			elif cast_position <= 0.0:
				cast_position = 0.0
				cast_direction = 1.0
			cast_fill.anchor_right = 0.02 + cast_position * 0.96
		Phase.IDLE:
			if not status_label.visible:
				idle_timer += delta
				if idle_timer >= IDLE_HINT_DELAY:
					status_label.text = "Tap anywhere to cast!"
					status_label.modulate = Color(1, 1, 1, 0)
					status_label.visible = true
					if status_tween:
						status_tween.kill()
					status_tween = create_tween()
					status_tween.tween_property(status_label, "modulate:a", 1.0, 0.8)

func _show_idle() -> void:
	current_phase = Phase.IDLE
	cast_bar.visible = false
	wait_panel.visible = false
	bite_label.visible = false
	minigame_overlay.visible = false
	bobber.visible = false
	bobber.stop()
	fishing_rod.play("idle")
	idle_timer = 0.0
	if not has_cast_before:
		status_label.text = "Tap anywhere to cast!"
		status_label.modulate = Color(1, 1, 1, 0)
		status_label.visible = true
		if status_tween:
			status_tween.kill()
		status_tween = create_tween()
		status_tween.tween_property(status_label, "modulate:a", 1.0, 0.8)
	else:
		status_label.visible = false

func _start_casting() -> void:
	current_phase = Phase.CASTING
	has_cast_before = true
	cast_bar.visible = true
	cast_position = 0.0
	cast_direction = 1.0
	if status_tween:
		status_tween.kill()
	status_label.text = "Cast Power"
	status_label.modulate = Color.WHITE
	status_label.visible = true

func _lock_cast() -> void:
	cast_power = cast_position
	fishing_rod.play("throw")
	fishing_rod.animation_finished.connect(_on_rod_throw_finished)
	_start_waiting()

func _on_rod_throw_finished() -> void:
	if fishing_rod.animation != &"throw":
		return
	fishing_rod.animation_finished.disconnect(_on_rod_throw_finished)
	fishing_rod.play("waiting")
	bobber.visible = true
	bobber.play("idle")

func _start_waiting() -> void:
	current_phase = Phase.WAITING
	cast_bar.visible = false
	wait_panel.visible = false
	status_label.text = "Waiting..."
	status_label.modulate = Color.WHITE
	status_label.visible = true

	var wait_time := lerpf(6.0, 2.0, cast_power) + randf_range(-0.5, 0.5)
	wait_time = maxf(wait_time, 1.0)
	await get_tree().create_timer(wait_time).timeout

	if current_phase == Phase.WAITING:
		_start_bite()

func _start_bite() -> void:
	current_phase = Phase.BITE
	wait_panel.visible = false
	status_label.visible = false

	bite_label.visible = true
	bite_label.scale = Vector2.ONE
	bite_label.modulate = Color.WHITE
	bite_time = Time.get_ticks_msec() / 1000.0

	# Pulse animation
	if bite_tween:
		bite_tween.kill()
	bite_tween = create_tween().set_loops()
	bite_tween.tween_property(bite_label, "scale", Vector2(1.15, 1.15), 0.3)
	bite_tween.tween_property(bite_label, "scale", Vector2(1.0, 1.0), 0.3)

	# 5s timeout
	await get_tree().create_timer(BITE_TIMEOUT).timeout
	if current_phase == Phase.BITE:
		if bite_tween:
			bite_tween.kill()
		bite_label.visible = false
		bobber.visible = false
		bobber.stop()
		fishing_rod.play("idle")
		_show_got_away()

func _on_bite_tap() -> void:
	var reaction_time := (Time.get_ticks_msec() / 1000.0) - bite_time
	pending_timing_score = clampf(snappedf(1.0 - (reaction_time / BITE_TIMEOUT), 0.01), 0.0, 1.0)
	if bite_tween:
		bite_tween.kill()
	bite_label.visible = false
	status_label.visible = false
	_start_minigame()

func _start_minigame() -> void:
	current_phase = Phase.MINIGAME
	minigame_overlay.visible = true
	minigame_overlay.start_minigame()

func _on_fish_caught() -> void:
	minigame_overlay.visible = false
	bobber.visible = false
	bobber.stop()
	fishing_rod.play("idle")
	_on_catch()

func _on_fish_escaped() -> void:
	minigame_overlay.visible = false
	bobber.visible = false
	bobber.stop()
	fishing_rod.play("idle")
	_show_got_away()

func _show_got_away() -> void:
	if status_tween:
		status_tween.kill()
	status_label.text = "It got away!"
	status_label.modulate = Color.WHITE
	status_label.visible = true
	await get_tree().create_timer(2.0).timeout
	status_tween = create_tween()
	status_tween.tween_property(status_label, "modulate:a", 0.0, 1.0)
	await status_tween.finished
	status_label.visible = false
	_show_idle()

func _on_catch() -> void:
	current_phase = Phase.SENDING
	status_label.visible = false

	var result := await Network.catch_fish(pending_timing_score)

	if result.status == 200:
		var data: Dictionary = result.data
		if data.has("result") and data["result"] == "miss":
			await get_tree().create_timer(2.0).timeout
			_show_idle()
		else:
			GameState.set_meta("last_catch", data)
			await SceneTransition.iris_to("res://scenes/fish_reveal/fish_reveal.tscn")
	elif result.status == 429:
		var retry_after: int = result.data.get("retry_after_seconds", 3)
		await get_tree().create_timer(retry_after).timeout
		_show_idle()
	else:
		await get_tree().create_timer(2.0).timeout
		_show_idle()

func _on_inventory_pressed() -> void:
	await SceneTransition.iris_to("res://scenes/inventory/inventory.tscn")
