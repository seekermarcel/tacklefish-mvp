extends Control
## Main fishing scene. Manages the cast -> wait -> timing -> catch flow.

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
@onready var cast_button: Button = %CastButton

@onready var wait_panel: PanelContainer = %WaitPanel
@onready var wait_label: Label = %WaitLabel

@onready var timing_panel: PanelContainer = %TimingPanel
@onready var timing_bar: ProgressBar = %TimingBar
@onready var timing_zone_label: Label = %TimingZoneLabel
@onready var catch_button: Button = %CatchButton

@onready var status_label: Label = %StatusLabel
@onready var back_button: Button = %BackButton

func _ready() -> void:
	cast_button.pressed.connect(_on_cast_pressed)
	catch_button.pressed.connect(_on_catch_pressed)
	back_button.pressed.connect(_on_back_pressed)
	_show_idle()

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
	cast_panel.visible = true
	wait_panel.visible = false
	timing_panel.visible = false
	cast_button.text = "Cast Line"
	cast_button.disabled = false
	status_label.text = "Tap to cast!"

func _on_cast_pressed() -> void:
	if current_phase == Phase.IDLE:
		_start_casting()
	elif current_phase == Phase.CASTING:
		_lock_cast()

func _start_casting() -> void:
	current_phase = Phase.CASTING
	cast_position = 0.0
	cast_direction = 1.0
	cast_button.text = "Lock Cast"
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
	status_label.text = "Tap CATCH when the bar is in the zone!"

func _on_catch_pressed() -> void:
	if current_phase != Phase.TIMING:
		return

	current_phase = Phase.SENDING
	catch_button.disabled = true

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
			# Navigate to fish reveal scene with fish data.
			GameState.set_meta("last_catch", data)
			get_tree().change_scene_to_file("res://scenes/fish_reveal/fish_reveal.tscn")
	elif result.status == 429:
		var retry_after: int = result.data.get("retry_after_seconds", 3)
		status_label.text = "Too fast! Wait %ds..." % retry_after
		await get_tree().create_timer(retry_after).timeout
		_show_idle()
	else:
		status_label.text = "Error: %s" % result.data.get("error", "Unknown error")
		await get_tree().create_timer(2.0).timeout
		_show_idle()

	catch_button.disabled = false

func _calculate_timing_score() -> float:
	var score: float
	if timing_position >= zone_start and timing_position <= zone_end:
		# Inside the zone: 0.5 - 1.0 based on proximity to center.
		var zone_center := (zone_start + zone_end) / 2.0
		var zone_half := (zone_end - zone_start) / 2.0
		var distance_from_center := absf(timing_position - zone_center) / zone_half
		score = 0.5 + 0.5 * (1.0 - distance_from_center)
	else:
		# Outside: 0.0 - 0.3 based on distance from zone edge.
		var distance_to_zone := minf(
			absf(timing_position - zone_start),
			absf(timing_position - zone_end)
		)
		score = maxf(0.0, 0.3 - distance_to_zone)
	return clampf(snappedf(score, 0.01), 0.0, 1.0)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
