extends Node
## Global game state singleton. Holds player info and current session data.

var player_id: int = 0
var inventory: Array = []
var pool: Array = []

signal inventory_updated
signal pool_updated

func clear() -> void:
	player_id = 0
	inventory.clear()
	pool.clear()
