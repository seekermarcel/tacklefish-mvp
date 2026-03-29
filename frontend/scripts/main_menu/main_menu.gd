extends Control
## Main menu scene. Auto-registers with the backend on load.

@onready var start_button: Button = %StartButton
@onready var exit_button: Button = %ExitButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	start_button.disabled = true
	start_button.pressed.connect(_on_start_pressed)
	exit_button.pressed.connect(_on_exit_pressed)
	_auto_register()

func _auto_register() -> void:
	status_label.text = "Connecting..."
	var result := await Network.register()
	if result.status == 200:
		status_label.text = "Player #%d" % GameState.player_id
		start_button.disabled = false
	else:
		status_label.text = "Connection failed. Check backend."

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/fishing/fishing.tscn")

func _on_exit_pressed() -> void:
	get_tree().quit()
