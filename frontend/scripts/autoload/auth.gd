extends Node
## Handles device ID persistence and JWT token management.

const DEVICE_ID_PATH := "user://device_id"

var device_id: String = ""
var token: String = ""

func _ready() -> void:
	_load_or_create_device_id()

func _load_or_create_device_id() -> void:
	if FileAccess.file_exists(DEVICE_ID_PATH):
		var file := FileAccess.open(DEVICE_ID_PATH, FileAccess.READ)
		device_id = file.get_as_text().strip_edges()
		file.close()
	if device_id.is_empty():
		device_id = _generate_uuid_v4()
		var file := FileAccess.open(DEVICE_ID_PATH, FileAccess.WRITE)
		file.store_string(device_id)
		file.close()
	print("Device ID: ", device_id)

func _generate_uuid_v4() -> String:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var hex := ""
	for i in 16:
		var byte := rng.randi_range(0, 255)
		if i == 6:
			byte = (byte & 0x0F) | 0x40  # version 4
		elif i == 8:
			byte = (byte & 0x3F) | 0x80  # variant 1
		hex += "%02x" % byte
	return "%s-%s-%s-%s-%s" % [
		hex.substr(0, 8),
		hex.substr(8, 4),
		hex.substr(12, 4),
		hex.substr(16, 4),
		hex.substr(20, 12),
	]

func has_token() -> bool:
	return not token.is_empty()
