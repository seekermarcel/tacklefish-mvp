extends Node
## Global game state singleton. Holds player info and current session data.

const VERSION := "dev"

var player_id: int = 0
var inventory: Array = []
var pool: Array = []
var xp: int = 0
var level: int = 0
var shells: int = 0
var total_caught: int = 0
var total_released: int = 0

signal inventory_updated
signal pool_updated

func clear() -> void:
	player_id = 0
	inventory.clear()
	pool.clear()
	xp = 0
	level = 0
	shells = 0
	total_caught = 0
	total_released = 0
