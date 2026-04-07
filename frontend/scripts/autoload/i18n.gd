extends Node
## Localization manager. Registers translations at runtime and persists language preference.
## Supports "en" (English) and "de" (German).

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LANG := "en"

signal language_changed(locale: String)

var _current_lang: String = DEFAULT_LANG

func _ready() -> void:
	_register_translations()
	_apply_lang(_load_lang())

func _register_translations() -> void:
	# English — only variant keys that are lowercase and would otherwise fall back incorrectly.
	var en := Translation.new()
	en.locale = "en"
	var en_msgs := {
		"common": "Common", "uncommon": "Uncommon", "rare": "Rare",
		"epic": "Epic", "legendary": "Legendary",
		"normal": "Normal", "mini": "Mini", "large": "Large", "giant": "Giant",
		"albino": "Albino", "melanistic": "Melanistic", "rainbow": "Rainbow", "neon": "Neon",
	}
	for src: String in en_msgs:
		en.add_message(src, en_msgs[src])
	TranslationServer.add_translation(en)

	# German
	var de := Translation.new()
	de.locale = "de"
	var de_msgs := {
		# Settings
		"Settings": "Einstellungen",
		"Player ID": "Spieler-ID",
		"Copy": "Kopieren",
		"Paste & Apply": "Einfügen & Anwenden",
		"Copied!": "Kopiert!",
		"Applied! Reconnecting...": "Gesetzt! Verbinde neu...",
		"Music": "Musik",
		"Sound": "Sound",
		"ON": "AN",
		"OFF": "AUS",
		"Language": "Sprache",
		"Check Pools": "Pools ansehen",
		"Available Fish": "Verfügbare Fische",
		"Close": "Schliessen",
		"Back": "Zurück",
		"Loading pools...": "Lade Pools...",
		"Failed to load pools": "Pools laden fehlgeschlagen",
		"remaining": "verbleibend",
		# UI strings
		"Connecting...": "Verbinde...",
		"Connection failed. Check backend.": "Verbindung fehlgeschlagen.",
		"Player #%d": "Spieler #%d",
		"Tap anywhere to cast!": "Tippe zum Auswerfen!",
		"Cast Power": "Wurfkraft",
		"Waiting...": "Warte...",
		"Waiting for a bite...": "Warte auf Biss...",
		"BITE!": "BISS!",
		"It got away!": "Entkommen!",
		"You caught a...": "Du hast gefangen...",
		"Cast Again": "Nochmal werfen",
		"View Inventory": "Sammlung ansehen",
		"Back to Collection": "Zur Sammlung",
		"Back to Pond": "Zum Teich",
		"Load More": "Mehr laden",
		"Search species...": "Art suchen...",
		"No fish data": "Keine Fischdaten",
		"Unknown": "Unbekannt",
		"Loading...": "Lade...",
		"Failed to load": "Laden fehlgeschlagen",
		"All": "Alle",
		"Color: %s": "Farbe: %s",
		"Size: %s": "Grösse: %s",
		# Rarity
		"common": "Gewöhnlich", "uncommon": "Ungewöhnlich", "rare": "Selten",
		"epic": "Episch", "legendary": "Legendär",
		# Size variants
		"normal": "Normal", "mini": "Klein", "large": "Gross", "giant": "Riesig",
		# Color variants
		"albino": "Albino", "melanistic": "Melanistisch", "rainbow": "Regenbogen", "neon": "Neon",
		# Fish species
		"Perch": "Barsch",
		"Carp": "Karpfen",
		"Chub": "Döbel",
		"Brook Trout": "Bachforelle",
		"Moonbass": "Mondbass",
		"Catfish": "Wels",
		"Ice Trout": "Eisforelle",
		"Night Eel": "Nachtaal",
		"Obsidian Pufferfish": "Obsidian-Kugelfisch",
		"Golden Primeval Perch": "Goldener Urbarsch",
		"Buntbarsch": "Buntbarsch",
		"Unifish": "Unifisch",
	}
	for src: String in de_msgs:
		de.add_message(src, de_msgs[src])
	TranslationServer.add_translation(de)

func set_language(locale: String) -> void:
	_apply_lang(locale)
	_save_lang(locale)

func get_language() -> String:
	return _current_lang

func _apply_lang(locale: String) -> void:
	_current_lang = locale
	TranslationServer.set_locale(locale)
	language_changed.emit(locale)

func _save_lang(locale: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("locale", "language", locale)
	cfg.save(SETTINGS_PATH)

func _load_lang() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		return cfg.get_value("locale", "language", DEFAULT_LANG)
	return DEFAULT_LANG
