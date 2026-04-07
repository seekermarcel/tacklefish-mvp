# Frontend Client Transfer Document

This document gives the frontend Claude instance everything it needs to build the Godot client and connect it to the Tacklefish backend.

---

## 1. Project Context

Tacklefish is a casual mobile fishing game. The player casts a line, plays a timing minigame, and catches unique numbered fish. The backend handles all game logic (rarity rolls, edition assignment, trait generation). The client is responsible for the fishing UX, displaying results, and managing the player's inventory.

**Read these before starting:**
- `docs/mvp.md` -- MVP scope, what to build, what to skip
- `docs/game-design-document.md` -- Full GDD for deeper context

**Current MVP scope for the client:**
1. Fishing minigame (cast power bar, wait for bite, bite reaction, fish-fighting minigame)
2. Fish reveal screen (species, edition number, rarity, traits)
3. Simple inventory (scrollable list + detail view)
4. Auto-auth on first launch (no login screen)
5. 1 zone only (Village Pond)
6. 12 fish species

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
frontend/
  project.godot
  scenes/
    fishing/
      fishing.tscn              -- Main gameplay scene (cast, wait, bite, minigame)
    fish_reveal/
      fish_reveal.tscn          -- Post-catch reveal screen
    inventory/
      inventory.tscn            -- Collection book with search/filter/pagination
    fish_detail/
      fish_detail.tscn          -- Detailed view of a single fish
    main_menu/
      main_menu.tscn            -- Animated title screen with auto-auth
  scripts/
    autoload/
      game_state.gd             -- Player state singleton
      network.gd                -- HTTP client singleton (API calls)
      auth.gd                   -- Device ID + JWT management
      scene_transition.gd       -- Iris wipe shader transitions
      audio_manager.gd          -- Music, ambient sounds, and SFX
    fishing/
      fishing.gd                -- Cast -> wait -> bite -> minigame -> catch flow
      minigame_overlay.gd       -- Fish-fighting minigame (joystick + circle arena)
    fish_reveal/
      fish_reveal.gd            -- Reveal screen logic
    inventory/
      inventory.gd              -- Collection book with search/filter/pagination
    fish_detail/
      fish_detail.gd            -- Fish detail view logic
    main_menu/
      main_menu.gd              -- Auto-register, zoom + iris wipe transition
  resources/
    fonts/
      pixel.ttf                 -- Custom pixel art font
    sprites/
      fish/                     -- Per-species sprites (loaded by name: catfish.png, chub.png, etc.)
      environment/              -- Animated backgrounds (spritesheets), bobber, fishing rod
      minigame/                 -- Minigame background and fish sprites
      ui/                       -- Wooden buttons, progress bar frame/fill, inventory/market icons
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

### 4.2 Backup Code Endpoints

#### `POST /auth/transfer-code` (Protected)

Generate a new backup code for the authenticated player. Replaces any previously generated code.

**Response (200):**
```json
{
  "transfer_code": "ABCD-EFGH-JKLM"
}
```

**Notes:**
- Code is 12 alphanumeric characters (displayed as `XXXX-XXXX-XXXX`)
- Alphabet excludes `0`, `O`, `1`, `I` to avoid visual confusion
- Generating a new code invalidates the previous one

#### `GET /auth/transfer-code` (Protected)

Retrieve the player's existing backup code, or `null` if none exists.

**Response (200):**
```json
{
  "transfer_code": "ABCD-EFGH-JKLM"
}
```

Or if no code has been generated:
```json
{
  "transfer_code": null
}
```

#### `POST /auth/transfer` (Public -- no token needed)

Claim an account on a new device using a backup code. This transfers the account (including all fish) to the new device.

**Request:**
```json
{
  "device_id": "550e8400-e29b-41d4-a716-446655440000",
  "transfer_code": "ABCD-EFGH-JKLM"
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
- `400` -- Missing `device_id` or invalid code format (not 12 characters after stripping dashes)
- `404` -- Code does not match any account

**Notes:**
- Dashes are stripped and input is uppercased automatically, so `abcd-efgh-jklm` works
- The code is reusable -- the same code can restore the account on multiple devices
- If the device was already auto-registered as a new player, that empty player is deleted and **any fish it owned are released back into the edition pool** (their edition numbers become available for catching again)
- After a successful claim, the client should update `Auth.token` and `GameState.player_id` with the returned values

### 4.3 Fish Endpoints (Protected -- token required)

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
  - If the player has a backup code: POST /auth/transfer { device_id, transfer_code }
  - This transfers the old account to the new device (all fish preserved)
  - The auto-registered empty player is deleted and its fish released to the pool
  - If no backup code exists: account is unrecoverable, starts as a new player
```

---

## 6. Core Game Flow (Client Responsibilities)

```
Main Menu
  |
  v
Fishing Scene
  |
  +-- Cast Phase: Power bar oscillates. Player taps to lock power.
  |   Higher power = shorter wait time. (Client-only -- no server call)
  |
  +-- Wait Phase: Random timer 2-6s (affected by cast power). Bobber appears
  |   on water after rod throw animation. (Client-only -- no server call)
  |
  +-- Bite Phase: "BITE!" text pulses on screen. 5-second reaction window.
  |   Player taps to react. Reaction time -> timing_score (0.0-1.0).
  |   No tap within 5s = fish escapes, back to idle. (Client-only)
  |
  +-- Minigame Phase: Full-screen overlay with circle arena and swimming fish.
  |   Player uses virtual joystick (appears at touch point) to keep fish in circle.
  |   10s in circle = caught. 2s outside = fish escapes. (Client-only)
  |
  +-- Send: POST /fish/catch { timing_score }
  |
  +-- Receive: Fish data OR miss
  |
  v
Fish Reveal Screen (if catch)
  |-- Display: species name, rarity badge, "Exemplar 73 / 150", size, color
  |-- Fish sprite loaded from res://resources/sprites/fish/{species_name}.png
  |-- "Cast Again" button --> returns to Fishing
  |-- "View Inventory" button --> navigates to Inventory
  |
  v
Inventory (accessible from fishing scene bottom bar)
  |-- GET /player/inventory?limit=50&offset=0
  |-- 2-column grid of fish cards with rarity-colored borders
  |-- Search bar + rarity filter buttons
  |-- Fish sprites loaded by name convention, fallback to colored placeholders
  |-- Load More pagination
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

### MVP Fish Species (12)

| ID | Name | Rarity | Edition Size |
|----|------|--------|-------------|
| 1 | Perch | common | 1,000 |
| 2 | Carp | common | 800 |
| 3 | Chub | common | 600 |
| 4 | Brook Trout | uncommon | 400 |
| 5 | Moonbass | uncommon | 300 |
| 6 | Catfish | uncommon | 250 |
| 7 | Ice Trout | rare | 150 |
| 8 | Night Eel | rare | 100 |
| 9 | Obsidian Pufferfish | epic | 30 |
| 10 | Golden Primeval Perch | legendary | 10 |
| 11 | Buntbarsch | rare | 150 |
| 12 | Unifish | legendary | 10 |

---

## 8. Timing Score Calculation

The backend expects a float from `0.0` to `1.0`. The timing score is derived from the player's **bite reaction time**:

```
When "BITE!" appears, a 5-second countdown starts.
Player taps the screen as fast as possible.

timing_score = 1.0 - (reaction_time_seconds / 5.0)

Clamp to 0.0 - 1.0, snap to 0.01 precision.
```

A score of `1.0` means an instant reaction. A score of `0.0` means the player took the full 5 seconds (and the fish would have escaped). If the player doesn't tap within 5 seconds, no server call is made -- the fish escapes.

After the bite reaction, the player must also win the **fish-fighting minigame** (keep fish in circle for 10 seconds using a virtual joystick). If the fish escapes the circle, no server call is made. The minigame difficulty is random per catch and does not affect the timing_score.

The backend uses the timing score to weight rarity rolls:

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
network.generate_transfer_code() -> { transfer_code }
network.get_transfer_code() -> { transfer_code }
network.claim_transfer_code(device_id: String, code: String) -> { token, player_id }
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
9. **Backup code restore releases fish.** When a player claims a backup code on a device that was already auto-registered, the auto-registered player is deleted and any fish it owned are returned to the edition pool. This ensures no editions are permanently lost.
