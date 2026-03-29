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
  project.godot                              -- Project config (720x1280 portrait, mobile renderer)
  scenes/
    main_menu/main_menu.tscn                 -- Animated title screen with play/exit buttons
    fishing/fishing.tscn                     -- Core gameplay: tap-anywhere fishing
    fish_reveal/fish_reveal.tscn             -- Post-catch reveal: species, rarity, edition, traits
    inventory/inventory.tscn                 -- Collection book with search, filters, fish cards
  scripts/
    autoload/
      game_state.gd                          -- Player state singleton (player_id, inventory, pool)
      auth.gd                                -- Device UUID generation + persistence, JWT storage
      network.gd                             -- HTTP client wrapping all API calls
      scene_transition.gd                    -- Iris wipe transition (shader-based)
    main_menu/main_menu.gd                   -- Auto-register, zoom + iris transition to fishing
    fishing/fishing.gd                       -- Cast -> wait -> timing -> catch flow
    fish_reveal/fish_reveal.gd               -- Display caught fish with rarity colors
    inventory/inventory.gd                   -- Collection book with search/filter/pagination
  resources/
    fonts/
      pixel.ttf                              -- Pixel art font for all UI text
      pixel_font_license.txt                 -- Font license
    sprites/
      environment/
        title_background_sheet.png           -- Animated title screen (14 frames, sprite sheet)
        title_background.tres                -- SpriteFrames resource for title animation
        fishing_background.png               -- Village Pond scene (pixel art, 800x800)
        start_background.jpg                 -- Legacy start background (unused)
      fish/                                  -- Fish sprites (not yet created)
      ui/
        button_play.png                      -- Wooden play button (title screen)
        button_exit.png                      -- Wooden exit button (title screen)
        icon_market_wood.png                 -- Wooden market button (fishing screen)
        icon_inventory_wood.png              -- Wooden inventory button (fishing screen)
        progress_bar_frame.png               -- Wooden progress bar track
        progress_bar_fill.png                -- Golden progress bar fill (unused, fill is ColorRect)
        icon_inventory.svg                   -- Legacy SVG inventory icon (unused)
        icon_market.svg                      -- Legacy SVG market icon (unused)
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
Title Screen (animated background)
  |-- Auto-registers with backend on load
  |-- Play button -> zoom into fisher + iris wipe close -> fishing scene
  |-- Exit button -> quit
  v
Fishing Scene (Village Pond)
  |-- Tap anywhere to cast (wooden power bar appears)
  |-- Tap anywhere to lock cast power (higher power = shorter wait)
  |-- Random wait for a bite (2-6s based on cast power)
  |-- Bite alert: "!" appears, tap quickly to react (5s timeout or fish escapes)
  |-- Reaction time determines timing_score (faster = better)
  |-- Fishing minigame overlay
  |-- POST /fish/catch { timing_score } -> server decides fish
  |-- All scene transitions use iris wipe
  v
Fish Reveal Screen
  |-- Species name (color-coded by rarity)
  |-- Edition number (#47 / 1000)
  |-- Size + color traits
  |-- "Cast Again" -> iris wipe -> fishing
  |-- "View Inventory" -> iris wipe -> inventory
  v
Collection Book (Inventory)
  |-- Search bar (filter by species name)
  |-- Rarity filter buttons (All, Common, Uncommon, Rare, Epic, Legendary)
  |-- 2-column grid of fish cards with rarity-colored borders
  |-- Each card: placeholder sprite, species, edition, rarity badge, traits
  |-- Pagination with "Load More"
  |-- "Back" -> iris wipe -> fishing
```

## Scene Transitions

The `SceneTransition` autoload provides an Animal Crossing-style iris wipe:

```gdscript
# Full transition: close iris -> change scene -> open iris
await SceneTransition.iris_to("res://scenes/fishing/fishing.tscn")

# Or control each phase separately:
SceneTransition.prepare_close(Vector2(0.5, 0.5))  # Set up overlay (no visible change)
await SceneTransition.iris_close(Vector2(0.5, 0.5), 1.0)  # Close
await SceneTransition.iris_open_with_scene("res://scenes/...", 1.0)  # Change + open
```

The title screen uses a custom transition: zoom into the fisher + iris close simultaneously (1.0s), then iris open on the fishing scene (1.0s).

## Input

All gameplay input is tap-anywhere (via `_unhandled_input`). Non-interactive UI nodes use `mouse_filter = MOUSE_FILTER_IGNORE` so taps pass through to the script.

Bottom bar buttons on the fishing screen:
- **Market** (bottom-left, wooden icon) -- no function yet (post-MVP)
- **Inventory** (bottom-right, wooden icon) -- iris wipe to collection book

## Art Style

- Pixel art with nearest-neighbor filtering (`texture_filter = 0`)
- Pixel font for all text with dark outlines for readability
- Wooden UI elements (buttons, progress bars) matching Stardew Valley aesthetic
- Rarity colors: gray (common), green (uncommon), blue (rare), purple (epic), gold (legendary)

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

- Fish sprites and color variants (currently using colored rectangles as placeholders)
- Fish detail view (tap inventory card for full details)
- Sound effects (cast splash, reel, catch chime, rare catch fanfare)
- Game feel tuning (bar speeds, zone sizes, wait times)
- Cast power affects wait time (higher = shorter wait) but could also influence rarity
