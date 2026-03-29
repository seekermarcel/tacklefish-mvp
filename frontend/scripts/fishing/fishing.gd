extends Control
## Main fishing scene. Manages the cast -> wait -> timing -> catch flow.
## Tap anywhere to cast/lock. Bottom corner buttons for inventory and market.

enum Phase { IDLE, CASTING, WAITING, TIMING, SENDING }

var current_phase: Phase = Phase.IDLE

# Cast bar state
var cast_position: float = 0.0
var cast_direction: float = 1.0
const CAST_SPEED: float = 1.5

# Timing minigame state
var timing_position: float = 0.0
const TIMING_SPEED: float = 1.0
var zone_start: float = 0.0
var zone_end: float = 0.0

@onready var cast_panel: PanelContainer = %CastPanel
@onready var cast_bar: ProgressBar = %CastBar

@onready var wait_panel: PanelContainer = %WaitPanel
@onready var wait_label: Label = %WaitLabel

@onready var timing_panel: PanelContainer = %TimingPanel
@onready var timing_bar: ProgressBar = %TimingBar
@onready var timing_zone_label: Label = %TimingZoneLabel

@onready var status_label: Label = %StatusLabel
@onready var market_button: TextureButton = %MarketButton
@onready var inventory_button: TextureButton = %InventoryButton

func _ready() -> void:
	inventory_button.pressed.connect(_on_inventory_pressed)
	# Market button has no function yet.
	_show_idle()

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
		Phase.TIMING:
			_on_catch()

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
			cast_bar.value = cast_position * 100.0
		Phase.TIMING:
			timing_position += TIMING_SPEED * delta
			if timing_position > 1.0:
				timing_position = 0.0
			timing_bar.value = timing_position * 100.0

func _show_idle() -> void:
	current_phase = Phase.IDLE
	cast_panel.visible = false
	wait_panel.visible = false
	timing_panel.visible = false
	status_label.text = "Tap anywhere to cast!"

func _start_casting() -> void:
	current_phase = Phase.CASTING
	cast_panel.visible = true
	cast_position = 0.0
	cast_direction = 1.0
	status_label.text = "Tap to lock power!"

func _lock_cast() -> void:
	_start_waiting()

func _start_waiting() -> void:
	current_phase = Phase.WAITING
	cast_panel.visible = false
	wait_panel.visible = true
	status_label.text = "Waiting for a bite..."

	var wait_time := randf_range(2.0, 6.0)
	await get_tree().create_timer(wait_time).timeout

	if current_phase == Phase.WAITING:
		_start_timing()

func _start_timing() -> void:
	current_phase = Phase.TIMING
	wait_panel.visible = false
	timing_panel.visible = true

	# Random zone position and width.
	var zone_width := randf_range(0.10, 0.25)
	zone_start = randf_range(0.10, 0.80 - zone_width)
	zone_end = zone_start + zone_width

	timing_position = 0.0
	timing_zone_label.text = "Zone: %d%% - %d%%" % [int(zone_start * 100), int(zone_end * 100)]
	status_label.text = "Tap anywhere to catch!"

func _on_catch() -> void:
	current_phase = Phase.SENDING

	var timing_score := _calculate_timing_score()
	status_label.text = "Score: %.0f%% - Reeling in..." % (timing_score * 100.0)

	var result := await Network.catch_fish(timing_score)

	if result.status == 200:
		var data: Dictionary = result.data
		if data.has("result") and data["result"] == "miss":
			status_label.text = "No fish! %s" % data.get("reason", "")
			await get_tree().create_timer(2.0).timeout
			_show_idle()
		else:
			GameState.set_meta("last_catch", data)
			await SceneTransition.iris_to("res://scenes/fish_reveal/fish_reveal.tscn")
	elif result.status == 429:
		var retry_after: int = result.data.get("retry_after_seconds", 3)
		status_label.text = "Too fast! Wait %ds..." % retry_after
		await get_tree().create_timer(retry_after).timeout
		_show_idle()
	else:
		status_label.text = "Error: %s" % result.data.get("error", "Unknown error")
		await get_tree().create_timer(2.0).timeout
		_show_idle()

func _calculate_timing_score() -> float:
	var score: float
	if timing_position >= zone_start and timing_position <= zone_end:
		var zone_center := (zone_start + zone_end) / 2.0
		var zone_half := (zone_end - zone_start) / 2.0
		var distance_from_center := absf(timing_position - zone_center) / zone_half
		score = 0.5 + 0.5 * (1.0 - distance_from_center)
	else:
		var distance_to_zone := minf(
			absf(timing_position - zone_start),
			absf(timing_position - zone_end)
		)
		score = maxf(0.0, 0.3 - distance_to_zone)
	return clampf(snappedf(score, 0.01), 0.0, 1.0)

func _on_inventory_pressed() -> void:
	await SceneTransition.iris_to("res://scenes/inventory/inventory.tscn")
