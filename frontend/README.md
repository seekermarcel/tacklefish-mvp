# Tacklefish Frontend

Godot 4.6 game client for the Tacklefish mobile fishing game. Connects to the Go backend for all game logic -- the client handles the fishing UX, displays results, and manages navigation.

## Requirements

- **Godot 4.6+** (with GDScript)
- **Backend running** on `http://localhost:8080` (see root `docker compose up`)

## Quick Start

1. Start the backend: `docker compose up` from the repo root
2. Open this directory in Godot 4.6+
3. Press F5 to run

The client auto-registers with the backend on launch -- no login screen.

## Project Structure

```
frontend/
  project.godot                          -- Project config (720x1280 portrait, mobile renderer)
  scenes/
    main_menu/main_menu.tscn             -- Start screen with background art, Start/Exit buttons
    fishing/fishing.tscn                 -- Core gameplay: cast, wait, timing minigame
    fish_reveal/fish_reveal.tscn         -- Post-catch reveal: species, rarity, edition, traits
    inventory/inventory.tscn             -- Scrollable fish collection with pagination
  scripts/
    autoload/
      game_state.gd                      -- Player state singleton (player_id, inventory, pool)
      auth.gd                            -- Device UUID generation + persistence, JWT storage
      network.gd                         -- HTTP client wrapping all API calls
      scene_transition.gd                -- Iris wipe transition (shader-based)
    main_menu/main_menu.gd               -- Auto-register, zoom + iris transition to fishing
    fishing/fishing.gd                   -- Cast -> wait -> timing -> catch flow
    fish_reveal/fish_reveal.gd           -- Display caught fish with rarity colors
    inventory/inventory.gd               -- Paginated fish list from backend
  resources/
    sprites/
      environment/start_background.jpg   -- Pixel art pond scene (start screen)
      fish/                              -- Fish sprites (not yet created)
      ui/
        icon_inventory.svg               -- Bag icon for inventory button
        icon_market.svg                  -- Shop icon for market button
```

## Autoloads

| Singleton | File | Purpose |
|-----------|------|---------|
| `GameState` | `game_state.gd` | Player ID, inventory data, pool data |
| `Auth` | `auth.gd` | Device UUID (persisted to `user://device_id`), JWT token in memory |
| `Network` | `network.gd` | All HTTP calls to backend, auto-refresh on 401, rate limit handling |
| `SceneTransition` | `scene_transition.gd` | Iris wipe shader overlay, reusable from any scene |

## Game Flow

```
Main Menu
  |-- Auto-registers with backend on load
  |-- "Start" -> zoom into angler + iris wipe close
  v
Fishing Scene (Village Pond)
  |-- Tap anywhere to cast (power bar appears)
  |-- Tap anywhere to lock cast power
  |-- Random wait (2-6s) for a bite
  |-- Timing minigame: tap anywhere when bar is in the zone
  |-- POST /fish/catch { timing_score } -> server decides fish
  v
Fish Reveal Screen
  |-- Species name (color-coded by rarity)
  |-- Edition number (#47 / 1000)
  |-- Size + color traits
  |-- "Cast Again" -> back to fishing
  |-- "View Inventory" -> inventory screen
  v
Inventory Screen
  |-- Paginated list from GET /player/inventory
  |-- "Back" -> returns to fishing
```

## Scene Transitions

The `SceneTransition` autoload provides an Animal Crossing-style iris wipe:

```gdscript
# Full transition: close iris -> change scene -> open iris
await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")

# Or control each phase separately:
SceneTransition.prepare_close(Vector2(0.5, 0.5))  # Set up overlay
await SceneTransition.iris_close(Vector2(0.5, 0.5), 1.0)  # Close
await SceneTransition.iris_open_with_scene("res://scenes/...", 1.0)  # Change + open
```

## Input

All gameplay input is tap-anywhere (via `_unhandled_input`). The only explicit buttons are:

- **Market** (bottom-left, square icon) -- no function yet
- **Inventory** (bottom-right, square icon) -- navigates to inventory
- **Catch button** during timing phase was removed; tapping anywhere works

Non-interactive UI nodes use `mouse_filter = MOUSE_FILTER_IGNORE` so taps pass through to the script.

## Backend Connection

The client connects to `http://localhost:8080` (hardcoded in `network.gd`). All game state validation is server-side -- the client only sends `timing_score` (0.0-1.0) and displays whatever the server returns.

Auth flow:
1. First launch: generate UUID, save to `user://device_id`, POST `/auth/register`
2. Subsequent launches: load UUID, POST `/auth/register` (idempotent)
3. On 401: auto-refresh via POST `/auth/refresh`, retry request
4. On 429: display cooldown timer, retry after wait

## Display Settings

- **Viewport:** 720x1280 (portrait)
- **Stretch mode:** canvas_items
- **Stretch aspect:** expand
- **Renderer:** mobile
- **Orientation:** portrait

## What's Missing (MVP TODOs)

- Fish sprites and color variants (art assets)
- Fish detail view (tap inventory item for full details)
- Bobber and fishing line visuals
- Custom cast bar / timing bar art (currently default ProgressBar)
- Sound effects
- Screen transitions between fishing/inventory/reveal
- Game feel tuning (bar speeds, zone sizes)
