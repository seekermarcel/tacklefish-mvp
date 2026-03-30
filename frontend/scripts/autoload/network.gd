extends Node
## HTTP client singleton. Wraps all backend API calls with auth header injection
## and automatic token refresh on 401.

const BASE_URL := "http://localhost:8080"

signal request_completed(result: Dictionary)

var _http: HTTPRequest

func _ready() -> void:
	_http = HTTPRequest.new()
	add_child(_http)

## Register or re-authenticate with the backend. Called on every launch.
func register() -> Dictionary:
	var body := JSON.stringify({"device_id": Auth.device_id})
	var result := await _do_request("/auth/register", HTTPClient.METHOD_POST, body, false)
	if result.status == 200:
		Auth.token = result.data.get("token", "")
		GameState.player_id = result.data.get("player_id", 0)
	return result

## Refresh an expired JWT using the stored device ID.
func refresh_token() -> bool:
	var body := JSON.stringify({"device_id": Auth.device_id})
	var result := await _do_request("/auth/refresh", HTTPClient.METHOD_POST, body, false)
	if result.status == 200:
		Auth.token = result.data.get("token", "")
		GameState.player_id = result.data.get("player_id", 0)
		return true
	return false

## Catch a fish. Sends the timing score from the minigame.
func catch_fish(timing_score: float) -> Dictionary:
	var body := JSON.stringify({"timing_score": timing_score})
	return await _do_request("/fish/catch", HTTPClient.METHOD_POST, body)

## Get remaining edition counts for all species in the pool.
func get_pool() -> Dictionary:
	return await _do_request("/fish/pool", HTTPClient.METHOD_GET)

## Get the player's inventory with pagination.
func get_inventory(limit: int = 20, offset: int = 0) -> Dictionary:
	var url := "/player/inventory?limit=%d&offset=%d" % [limit, offset]
	return await _do_request(url, HTTPClient.METHOD_GET)

## Get details for a single fish by ID.
func get_fish_detail(fish_id: int) -> Dictionary:
	return await _do_request("/player/inventory/%d" % fish_id, HTTPClient.METHOD_GET)

## Generate a new backup code (replaces any existing code).
func generate_transfer_code() -> Dictionary:
	return await _do_request("/auth/transfer-code", HTTPClient.METHOD_POST)

## Get the existing backup code (or null if none exists).
func get_transfer_code() -> Dictionary:
	return await _do_request("/auth/transfer-code", HTTPClient.METHOD_GET)

## Claim an account using a backup code from a previous install.
func claim_transfer_code(device_id: String, code: String) -> Dictionary:
	var body := JSON.stringify({"device_id": device_id, "transfer_code": code})
	var result := await _do_request("/auth/transfer", HTTPClient.METHOD_POST, body, false)
	if result.status == 200:
		Auth.token = result.data.get("token", "")
		GameState.player_id = result.data.get("player_id", 0)
	return result

## Internal: perform an HTTP request with optional auth and auto-retry on 401.
func _do_request(path: String, method: int, body: String = "", use_auth: bool = true) -> Dictionary:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if use_auth and Auth.has_token():
		headers.append("Authorization: Bearer %s" % Auth.token)

	var url := BASE_URL + path
	var error := _http.request(url, headers, method, body)
	if error != OK:
		return {"status": 0, "data": {"error": "HTTP request failed"}}

	var response: Array = await _http.request_completed
	var result := _parse_response(response)

	# Auto-refresh on 401 and retry once.
	if result.status == 401 and use_auth:
		var refreshed := await refresh_token()
		if refreshed:
			headers[headers.size() - 1] = "Authorization: Bearer %s" % Auth.token
			error = _http.request(url, headers, method, body)
			if error != OK:
				return {"status": 0, "data": {"error": "Retry request failed"}}
			response = await _http.request_completed
			result = _parse_response(response)

	return result

func _parse_response(response: Array) -> Dictionary:
	var response_code: int = response[1]
	var response_body: PackedByteArray = response[3]
	var body_text := response_body.get_string_from_utf8()

	var data: Variant = {}
	if not body_text.is_empty():
		var json := JSON.new()
		if json.parse(body_text) == OK:
			data = json.data
		else:
			data = {"raw": body_text}

	return {"status": response_code, "data": data}
