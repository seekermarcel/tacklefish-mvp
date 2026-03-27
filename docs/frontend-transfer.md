# Frontend Client Transfer Document

This document gives the frontend Claude instance everything it needs to build the Godot client and connect it to the Tacklefish backend.

---

## 1. Project Context

Tacklefish is a casual mobile fishing game. The player casts a line, plays a timing minigame, and catches unique numbered fish. The backend handles all game logic (rarity rolls, edition assignment, trait generation). The client is responsible for the fishing UX, displaying results, and managing the player's inventory.

**Read these before starting:**
- `docs/mvp.md` -- MVP scope, what to build, what to skip
- `docs/game-design-document.md` -- Full GDD for deeper context

**Current MVP scope for the client:**
1. Fishing minigame (cast power bar, wait for bite, timing minigame)
2. Fish reveal screen (species, edition number, rarity, traits)
3. Simple inventory (scrollable list + detail view)
4. Auto-auth on first launch (no login screen)
5. 1 zone only (Village Pond)
6. 10 fish species

**Out of scope:** Marketplace, seasons, cosmetics, multiple zones, aquarium, codex, daily quests.

---

## 2. Tech Stack

- **Engine:** Godot 4.x
- **Language:** GDScript (primary)
- **Target:** Mobile (Android / iOS), desktop for testing
- **Backend URL:** `http://localhost:8080` (Docker: `docker compose up` from repo root)

---

## 3. Recommended Project Structure

```
tacklefish-client/
  project.godot
  scenes/
    fishing/
      fishing.tscn              -- Main gameplay scene
      cast_bar.tscn             -- Power bar UI component
      catch_minigame.tscn       -- Timing minigame overlay
    fish_reveal/
      fish_reveal.tscn          -- Post-catch reveal screen
    inventory/
      inventory.tscn            -- Simple scrollable fish list
      fish_detail.tscn          -- Single fish detail view
    main_menu/
      main_menu.tscn            -- Start screen (auto-auth on load)
  scripts/
    autoload/
      game_state.gd             -- Player state singleton
      network.gd                -- HTTP client singleton (API calls)
      auth.gd                   -- Device ID + JWT management
    fishing/
      cast_controller.gd        -- Power bar logic
      bite_controller.gd        -- Wait timer, bite detection
      catch_minigame.gd         -- Timing indicator logic
    fish/
      fish_data.gd              -- Fish resource class
    ui/
      fish_card.gd              -- Reusable fish display widget
  resources/
    fish_species/               -- 10 species definitions (.tres)
    sprites/
      fish/                     -- 10 fish sprites + color variants
      ui/                       -- Buttons, bars, backgrounds
      environment/              -- Pond background, water, bobber
```

---

## 4. Backend API Reference

Base URL: `http://localhost:8080`

All request/response bodies are JSON. All protected endpoints require:
```
Authorization: Bearer <jwt_token>
```

Errors always return:
```json
{"error": "description of what went wrong"}
```

### 4.1 Auth Endpoints (Public -- no token needed)

#### `POST /auth/register`

Register a device or re-authenticate an existing one. Call this on first launch and whenever you need a fresh token.

**Request:**
```json
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "player_id": 1
}
```

**Errors:**
- `400` -- `device_id` missing or empty
- `500` -- Server error

**Notes:**
- `device_id` should be a UUID v4 generated once on first launch
- Store it persistently in `user://device_id` so it survives app restarts
- Calling register with an existing device_id returns the same player_id (idempotent)
- The JWT token expires after **24 hours**

#### `POST /auth/refresh`

Get a new JWT using the stored device ID. Use when a request returns 401.

**Request:**
```json
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000"
}
```

**Response (200):**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIs...",
  "player_id": 1
}
```

**Errors:**
- `401` -- Device ID not found (never registered)

### 4.2 Fish Endpoints (Protected -- token required)

#### `POST /fish/catch`

Send the player's timing score from the minigame. The server rolls rarity, picks a species, assigns an edition number, rolls traits, and returns the caught fish. **Rate limited to 1 catch per 3 seconds per player.**

**Request:**
```json
{
  "timing_score": 0.85
}
```

`timing_score` is a float between `0.0` (worst) and `1.0` (perfect). The client must compute this from the minigame and send the raw value. **The server decides everything else** -- the client does not choose the fish.

**Response -- successful catch (200):**
```json
{
  "id": 42,
  "species": "Ice Trout",
  "rarity": "rare",
  "edition_number": 73,
  "edition_size": 150,
  "size_variant": "large",
  "color_variant": "albino"
}
```

**Response -- all pools depleted (200):**
```json
{
  "result": "miss",
  "reason": "all fish depleted"
}
```

**Response -- rate limited (429):**
```json
{"error": "too many requests", "retry_after_seconds": 3}
```
The response includes a `Retry-After: 3` header.

**Errors:**
- `400` -- `timing_score` missing or outside 0-1 range
- `401` -- Invalid/missing token
- `429` -- Rate limited (more than 1 catch per 3 seconds)
- `500` -- Server error

**Notes:**
- The client should check for the `"result": "miss"` key to distinguish a miss from a catch
- Higher timing scores increase the chance of rarer fish but don't guarantee them
- On `429`, the client should wait at least 3 seconds before retrying. The fishing minigame naturally takes longer than 3 seconds, so this should rarely trigger in normal play -- it mainly prevents automated abuse

#### `GET /fish/pool`

Get remaining edition counts for all species. Useful for displaying "X left in the wild" on UI.

**Response (200):**
```json
[
  {
    "id": 1,
    "name": "Perch",
    "rarity": "common",
    "edition_size": 1000,
    "remaining": 997
  },
  {
    "id": 10,
    "name": "Golden Primeval Perch",
    "rarity": "legendary",
    "edition_size": 10,
    "remaining": 10
  }
]
```

### 4.3 Player Endpoints (Protected -- token required)

#### `GET /player/inventory`

Get the player's caught fish. Paginated, ordered by most recently caught first.

**Query params:**
| Param | Type | Default | Max | Description |
|-------|------|---------|-----|-------------|
| `limit` | int | 20 | 100 | Items per page |
| `offset` | int | 0 | -- | Skip N items |

**Response (200):**
```json
{
  "fish": [
    {
      "id": 42,
      "species": "Ice Trout",
      "rarity": "rare",
      "edition_number": 73,
      "edition_size": 150,
      "size_variant": "large",
      "color_variant": "albino",
      "caught_at": "2026-03-27T09:20:17Z"
    }
  ],
  "total": 1,
  "offset": 0,
  "limit": 20
}
```

**Notes:**
- `fish` is an empty array `[]` when the player has no fish, never `null`
- `caught_at` is always UTC in ISO 8601 format

#### `GET /player/inventory/{id}`

Get a single fish by its ID. Only returns fish owned by the authenticated player.

**Response (200):**
```json
{
  "id": 42,
  "species": "Ice Trout",
  "rarity": "rare",
  "edition_number": 73,
  "edition_size": 150,
  "size_variant": "large",
  "color_variant": "albino",
  "caught_at": "2026-03-27T09:20:17Z"
}
```

**Errors:**
- `400` -- Invalid ID format
- `404` -- Fish not found or not owned by this player

---

## 5. Auth Flow Implementation Guide

The client should implement auth as a Godot autoload (`auth.gd`):

```
First Launch:
  1. Generate UUID v4
  2. Save to user://device_id
  3. POST /auth/register { device_id }
  4. Store JWT in memory (not on disk)
  5. Store player_id in GameState

Subsequent Launches:
  1. Load device_id from user://device_id
  2. POST /auth/register { device_id }  (same endpoint, idempotent)
  3. Store JWT in memory
  4. Store player_id in GameState

On 401 Response:
  1. Load device_id from user://device_id
  2. POST /auth/refresh { device_id }
  3. Update stored JWT
  4. Retry the failed request

Lost Device ID (app uninstalled):
  - Account is unrecoverable (future feature: account linking)
  - Generate new UUID, register as a new player
```

---

## 6. Core Game Flow (Client Responsibilities)

```
Main Menu
  |
  v
Fishing Scene
  |
  +-- Cast Phase: Power bar fills/empties on loop. Player taps to lock distance.
  |   (Client-only -- no server call)
  |
  +-- Wait Phase: Random timer 2-10 seconds. Bobber floats. On bite: bobber dips.
  |   (Client-only -- no server call)
  |
  +-- Minigame Phase: Moving indicator, player taps to stop in target zone.
  |   Client computes timing_score (0.0-1.0) based on how close to center.
  |
  +-- Send: POST /fish/catch { timing_score }
  |
  +-- Receive: Fish data OR miss
  |
  v
Fish Reveal Screen (if catch)
  |-- Display: species name, rarity badge, "Exemplar 73 / 150", size, color
  |-- "Keep" button --> adds to local state, navigate to Fishing or Inventory
  |
  v
Inventory (accessible from menu)
  |-- GET /player/inventory?limit=20&offset=0
  |-- Scrollable list with fish thumbnails
  |-- Tap --> GET /player/inventory/{id} --> Fish Detail view
```

---

## 7. Data Types & Enums

These are the exact string values the backend sends. Use them for mapping sprites, colors, and UI labels.

### Rarity Tiers

| Value | Display Name | UI Color (suggestion) |
|-------|-------------|----------------------|
| `"common"` | Common | White / Gray |
| `"uncommon"` | Uncommon | Green |
| `"rare"` | Rare | Blue |
| `"epic"` | Epic | Purple |
| `"legendary"` | Legendary | Gold |

### Size Variants

| Value | Display Name |
|-------|-------------|
| `"mini"` | Mini |
| `"normal"` | Normal |
| `"large"` | Large |
| `"giant"` | Giant |

### Color Variants

| Value | Display Name | Visual Hint |
|-------|-------------|-------------|
| `"normal"` | Normal | Base sprite colors |
| `"albino"` | Albino | White/pale tint |
| `"melanistic"` | Melanistic | Dark/black tint |
| `"rainbow"` | Rainbow | Multi-color shimmer |
| `"neon"` | Neon | Bright glow effect |

### MVP Fish Species (10)

| ID | Name | Rarity | Edition Size |
|----|------|--------|-------------|
| 1 | Perch | common | 1,000 |
| 2 | Carp | common | 800 |
| 3 | Sunfish | common | 600 |
| 4 | Brook Trout | uncommon | 400 |
| 5 | Moonbass | uncommon | 300 |
| 6 | Catfish | uncommon | 250 |
| 7 | Ice Trout | rare | 150 |
| 8 | Night Eel | rare | 100 |
| 9 | Obsidian Pufferfish | epic | 30 |
| 10 | Golden Primeval Perch | legendary | 10 |

---

## 8. Timing Score Calculation

The backend expects a float from `0.0` to `1.0`. The client decides how to compute this. Suggested approach:

```
Target zone has a center point.
Indicator moves across the bar.
Player taps to stop.

timing_score = 1.0 - (distance_from_center / max_possible_distance)

Clamp to 0.0 - 1.0.
```

A score of `1.0` means a perfect hit (center of zone). A score of `0.0` means the player was as far from the zone as possible.

The backend uses this score to weight rarity rolls:

| Rarity | Score 0.0 | Score 1.0 |
|--------|-----------|-----------|
| Common | ~80% | ~40% |
| Uncommon | ~15% | ~30% |
| Rare | ~4% | ~18% |
| Epic | ~1% | ~8% |
| Legendary | ~0% | ~4% |

The client does NOT need to replicate this logic. Just send the score and display what comes back.

---

## 9. Network Singleton Pattern

The `network.gd` autoload should wrap all HTTP calls. Suggested interface:

```gdscript
# All methods return via signals or await
network.register(device_id: String) -> { token, player_id }
network.refresh(device_id: String) -> { token, player_id }
network.catch_fish(timing_score: float) -> CatchResult
network.get_pool() -> Array[PoolEntry]
network.get_inventory(limit: int, offset: int) -> InventoryResult
network.get_fish_detail(fish_id: int) -> FishDetail
```

- Use `HTTPRequest` node for async HTTP calls
- Set `Authorization: Bearer <token>` header on all protected calls
- On any `401` response: auto-refresh token and retry once
- On `429` response: wait `retry_after_seconds` before retrying (catch rate limit)
- Backend returns `Content-Type: application/json` on all responses

---

## 10. Running the Backend for Development

```bash
# From the repo root
docker compose up

# Server is now at http://localhost:8080
# Verify with:
curl http://localhost:8080/health
# --> {"status":"ok"}
```

To reset all data (wipe fish, players, start fresh):

```bash
docker compose down -v    # -v removes the data volume
docker compose up
```

---

## 11. Important Gotchas

1. **The client never decides which fish is caught.** It only sends `timing_score`. The server decides rarity, species, edition number, and traits.
2. **Edition numbers are globally unique per species.** Two players cannot have the same edition number for the same species.
3. **Pools can deplete.** When all 1,000 Perch are caught worldwide, no more can be caught. The catch endpoint returns `{"result": "miss"}`.
4. **JWT expires in 24 hours.** Always handle 401 by refreshing and retrying.
5. **There is no "miss" from bad timing.** Every catch attempt that reaches the server returns a fish (unless pools are empty). Timing only affects rarity odds.
6. **The fish `id` is the database row ID**, not the edition number. Use `id` for API calls, display `edition_number` / `edition_size` to the player.
7. **`caught_at` is UTC.** Convert to local time for display if needed.
8. **Catch endpoint is rate limited** to 1 request per 3 seconds per player. Returns `429` with `Retry-After: 3` header if called too fast. The natural fishing loop (cast -> wait -> minigame) takes longer than 3 seconds, so this won't affect normal gameplay.
