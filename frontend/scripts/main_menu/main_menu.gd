extends Control
## Main menu scene. Auto-registers with the backend on load.

@onready var fish_button: Button = %FishButton
@onready var inventory_button: Button = %InventoryButton
@onready var status_label: Label = %StatusLabel

func _ready() -> void:
	fish_button.disabled = true
	inventory_button.disabled = true
	fish_button.pressed.connect(_on_fish_pressed)
	inventory_button.pressed.connect(_on_inventory_pressed)
	_auto_register()

func _auto_register() -> void:
	status_label.text = "Connecting..."
	var result := await Network.register()
	if result.status == 200:
		status_label.text = "Player #%d" % GameState.player_id
		fish_button.disabled = false
		inventory_button.disabled = false
	else:
		status_label.text = "Connection failed. Check backend."

func _on_fish_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/fishing/fishing.tscn")

func _on_inventory_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/inventory/inventory.tscn")
