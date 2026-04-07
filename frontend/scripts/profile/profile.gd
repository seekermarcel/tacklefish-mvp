extends Control
## Player profile screen showing XP, level, and collection stats.

@onready var player_id_label: Label = %PlayerIDLabel
@onready var level_label: Label = %LevelLabel
@onready var xp_label: Label = %XPLabel
@onready var xp_bar: ProgressBar = %XPBar
@onready var shells_label: Label = %ShellsLabel
@onready var total_caught_label: Label = %TotalCaughtLabel
@onready var total_released_label: Label = %TotalReleasedLabel
@onready var collection_label: Label = %CollectionLabel
@onready var back_button: Label = %BackButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	back_button.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_on_back_pressed()
	)
	_load_profile()

func _load_profile() -> void:
	status_label.text = "Loading..."
	status_label.visible = true

	var result := await Network.get_profile()
	status_label.visible = false

	if result.status != 200:
		status_label.text = "Failed to load profile"
		status_label.visible = true
		return

	var data: Dictionary = result.data

	var player_id: int = data.get("player_id", 0)
	var xp: int = data.get("xp", 0)
	var level: int = data.get("level", 1)
	var xp_next: int = data.get("xp_next_level", -1)
	var total_caught: int = data.get("total_caught", 0)
	var total_released: int = data.get("total_released", 0)
	var shells: int = data.get("shells", 0)
	var current_collection: int = data.get("current_collection", 0)

	# Update GameState cache.
	GameState.xp = xp
	GameState.level = level
	GameState.shells = shells
	GameState.total_caught = total_caught
	GameState.total_released = total_released

	player_id_label.text = "Player #%d" % player_id
	level_label.text = "Level %d" % level
	shells_label.text = "Shells: %d" % shells
	total_caught_label.text = "Total Caught: %d" % total_caught
	total_released_label.text = "Total Released: %d" % total_released
	collection_label.text = "Collection: %d" % current_collection

	if xp_next > 0:
		# Find current level threshold for bar calculation.
		var level_thresholds := [0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500]
		var current_threshold: int = 0
		if level - 1 < level_thresholds.size():
			current_threshold = level_thresholds[level - 1]
		var progress_in_level: int = xp - current_threshold
		var level_range: int = xp_next - current_threshold
		xp_bar.max_value = level_range
		xp_bar.value = progress_in_level
		xp_label.text = "%d / %d XP" % [xp, xp_next]
	else:
		xp_bar.max_value = 1
		xp_bar.value = 1
		xp_label.text = "%d XP (MAX)" % xp

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_on_back_pressed()

func _on_back_pressed() -> void:
	await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")
