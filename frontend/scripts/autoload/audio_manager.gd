extends Node
## Centralized audio manager. Handles background music and sound effects.

# Music streams
var _music_stream: AudioStream = preload("res://resources/audio/music/background_soundtrack.mp3")
var _sounds_stream: AudioStream = preload("res://resources/audio/music/background_sounds.mp3")

# SFX streams
var _sfx_cast: AudioStream = preload("res://resources/audio/sfx/cast.mp3")
var _sfx_reel_in: AudioStream = preload("res://resources/audio/sfx/reel_in.mp3")
var _sfx_fish_caught: AudioStream = preload("res://resources/audio/sfx/fish_caught.wav")
var _sfx_collection_open: AudioStream = preload("res://resources/audio/sfx/collection_open.wav")
var _sfx_collection_close: AudioStream = preload("res://resources/audio/sfx/collection_close.wav")
var _sfx_start_game: AudioStream = preload("res://resources/audio/sfx/start_game.wav")

# Players
var _music_player: AudioStreamPlayer
var _sounds_player: AudioStreamPlayer
var _sfx_player: AudioStreamPlayer
var _reel_player: AudioStreamPlayer

func _ready() -> void:
	# Set up audio buses: Music (quiet) and SFX (full volume).
	var music_bus_idx := AudioServer.get_bus_index("Music")
	if music_bus_idx == -1:
		AudioServer.add_bus()
		music_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(music_bus_idx, "Music")
		AudioServer.set_bus_volume_db(music_bus_idx, -18.0)

	var sfx_bus_idx := AudioServer.get_bus_index("SFX")
	if sfx_bus_idx == -1:
		AudioServer.add_bus()
		sfx_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx_bus_idx, "SFX")
		AudioServer.set_bus_volume_db(sfx_bus_idx, 0.0)

	var sounds_bus_idx := AudioServer.get_bus_index("Sounds")
	if sounds_bus_idx == -1:
		AudioServer.add_bus()
		sounds_bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sounds_bus_idx, "Sounds")
		AudioServer.set_bus_volume_db(sounds_bus_idx, -24.0)

	# Enable looping on streams that need it.
	_music_stream.loop = true
	_sounds_stream.loop = true
	_sfx_reel_in.loop = true

	# Music player (background music, never interrupted).
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = &"Music"
	add_child(_music_player)

	# Background sounds player (ambient sounds, even quieter than music).
	_sounds_player = AudioStreamPlayer.new()
	_sounds_player.bus = &"Sounds"
	add_child(_sounds_player)

	# One-shot SFX player.
	_sfx_player = AudioStreamPlayer.new()
	_sfx_player.bus = &"SFX"
	add_child(_sfx_player)

	# Dedicated reel-in player (loops independently of one-shot SFX).
	_reel_player = AudioStreamPlayer.new()
	_reel_player.bus = &"SFX"
	add_child(_reel_player)

func play_music() -> void:
	if _music_player.playing:
		return
	_music_player.stream = _music_stream
	_music_player.play()

func stop_music() -> void:
	_music_player.stop()

func play_sounds() -> void:
	if _sounds_player.playing:
		return
	_sounds_player.stream = _sounds_stream
	_sounds_player.play()

func stop_sounds() -> void:
	_sounds_player.stop()

func play_sfx_cast() -> void:
	_sfx_player.stream = _sfx_cast
	_sfx_player.play()

func play_sfx_start_game() -> void:
	_sfx_player.stream = _sfx_start_game
	_sfx_player.play()

func play_sfx_fish_caught() -> void:
	_sfx_player.stream = _sfx_fish_caught
	_sfx_player.play()

func play_sfx_collection_open() -> void:
	_sfx_player.stream = _sfx_collection_open
	_sfx_player.play()

func play_sfx_collection_close() -> void:
	_sfx_player.stream = _sfx_collection_close
	_sfx_player.play()

func play_reel_in() -> void:
	_reel_player.stream = _sfx_reel_in
	_reel_player.play()

func stop_reel_in() -> void:
	_reel_player.stop()
