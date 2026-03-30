# Tacklefish - MVP Plan

**Goal:** A playable vertical slice that proves the core loop is fun.
**Team:** 2 developers (Dev A, Dev B), 1 designer
**Tools:** Godot 4.x, Godot MCP, Claude Code, Go backend
**Target:** Playable build on Android (or desktop for testing)

---

## 1. MVP Scope

The MVP includes **only** what is needed to validate the core game loop and the edition system. Everything else is cut.

### In Scope

| Feature | Why it's in the MVP |
|---------|-------------------|
| Fishing minigame (cast, wait, bite reaction, fish fight, catch) | The core mechanic -- must feel good |
| 1 zone (Village Pond) | Enough to test the loop |
| 12 fish species (3 common, 3 uncommon, 3 rare, 1 epic, 2 legendary) | Tests the rarity system without needing hundreds of assets |
| Edition system with numbered fish | The unique selling point -- must be validated |
| Fish inventory (simple list) | Player needs to see what they caught |
| Fish reveal screen | The dopamine moment -- species, number, traits |
| Basic trait system (size + color variant only) | Proves variation works without full trait matrix |
| Device ID auth + JWT | Needed for server-side fish assignment |
| Go backend with SQLite | Authoritative catch validation and edition tracking |
| Basic UI (cast button, inventory, fish detail) | Functional, not polished |

### Out of Scope (Post-MVP)

| Feature | Why it's cut |
|---------|-------------|
| Marketplace / trading | Complex -- validate the catch loop first |
| Real-money economy | Legal complexity, not needed for fun validation |
| Seasons | Content system, not core mechanic |
| Zones 2-6 | One zone is enough to test |
| Aquarium display | Nice-to-have, not core |
| Fish codex | Reference feature, not core |
| Daily quests | Retention mechanic, not core |
| Cosmetics / skins | Monetization layer, not core |
| Weather / time-of-day modifiers | Complexity for later |
| Valkey cache layer | SQLite alone is fine for MVP scale |
| ~~Audio / music~~ | ~~Placeholder SFX only~~ (implemented: background music, ambient sounds, SFX for cast/reel/catch/collection) |

---

## 2. MVP Architecture

### Client (Godot)

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
    main_menu/
      main_menu.tscn            -- Animated title screen with auto-auth
  scripts/
    autoload/
      game_state.gd             -- Player state singleton
      network.gd                -- HTTP client singleton (API calls)
      auth.gd                   -- Device ID + JWT management
      scene_transition.gd       -- Iris wipe shader transitions
    fishing/
      fishing.gd                -- Cast -> wait -> bite -> minigame -> catch flow
      minigame_overlay.gd       -- Fish-fighting minigame (joystick + circle arena)
    fish_reveal/
      fish_reveal.gd            -- Reveal screen logic
    inventory/
      inventory.gd              -- Collection book with search/filter/pagination
    main_menu/
      main_menu.gd              -- Auto-register, zoom + iris wipe transition
  resources/
    fonts/pixel.ttf             -- Custom pixel art font
    sprites/
      fish/                     -- Per-species sprites (catfish.png, chub.png, etc.)
      environment/              -- Animated backgrounds, bobber, fishing rod
      minigame/                 -- Minigame background and fish sprites
      ui/                       -- Wooden buttons, progress bar, icons
```

### Backend (Go)

```
backend/
  cmd/
    server/
      main.go                -- Entry point, route wiring, middleware chain
  internal/
    auth/
      handler.go             -- POST /auth/register, /auth/refresh
      jwt.go                 -- JWT creation and validation
      middleware.go           -- Auth middleware for protected routes
      ratelimit.go           -- Per-player rate limiting
    fish/
      handler.go             -- POST /fish/catch, GET /fish/pool
      pool.go                -- Edition pool queries, number assignment
      traits.go              -- Size & color variant rolling
      species.go             -- Rarity weights, timing-to-rarity math
    player/
      handler.go             -- GET /player/inventory, /player/inventory/{id}
    db/
      sqlite.go              -- DB connection, migration runner
  migrations/
    001_init.sql             -- Schema (players, fish_species, fish_instances)
    002_seed_species.sql     -- 12 MVP fish species
    embed.go                 -- Embeds .sql files into the binary
  tests/                     -- All tests (unit, handler, stress)
  Dockerfile
  go.mod
  go.sum
```

### SQLite Schema (MVP)

```sql
CREATE TABLE players (
    id          INTEGER PRIMARY KEY,
    device_id   TEXT UNIQUE NOT NULL,
    created_at  DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE fish_species (
    id          INTEGER PRIMARY KEY,
    name        TEXT NOT NULL,
    rarity      TEXT NOT NULL,       -- common, uncommon, rare, epic, legendary
    edition_size INTEGER NOT NULL,
    zone        INTEGER DEFAULT 1
);

CREATE TABLE fish_instances (
    id              INTEGER PRIMARY KEY,
    species_id      INTEGER NOT NULL REFERENCES fish_species(id),
    owner_id        INTEGER REFERENCES players(id),
    edition_number  INTEGER NOT NULL,
    size_variant    TEXT NOT NULL,     -- mini, normal, large, giant
    color_variant   TEXT NOT NULL,     -- normal, albino, melanistic, rainbow, neon
    caught_at       DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(species_id, edition_number)
);
```

### API Endpoints (MVP)

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/auth/register` | Send device_id, receive JWT |
| POST | `/auth/refresh` | Refresh expired JWT |
| POST | `/fish/catch` | Send timing score, receive fish (or miss) |
| GET | `/fish/pool` | Get remaining edition counts per species |
| GET | `/player/inventory` | Get player's caught fish list |
| GET | `/player/inventory/:id` | Get single fish detail |

### Catch Flow (Client <-> Server)

```
Client                              Server
  |                                    |
  |-- Player casts (power bar)         |
  |-- Wait for bite (2-6s)             |
  |-- "BITE!" appears                  |
  |-- Player taps (reaction time)      |
  |-- timing_score = 1.0 - (reaction / 5.0)
  |-- Fish-fighting minigame starts    |
  |-- Player keeps fish in circle 10s  |
  |                                    |
  |-- POST /fish/catch ------------->  |
  |   { timing_score: 0.82 }          |
  |                                    |-- Validate JWT
  |                                    |-- Roll rarity based on timing_score
  |                                    |-- Pick species from zone pool
  |                                    |-- Check edition pool (copies left?)
  |                                    |-- Assign random edition number
  |                                    |-- Roll traits (size, color)
  |                                    |-- INSERT fish_instance
  |                                    |-- Return fish data
  |  <-- 200 OK ----------------------|
  |   { species: "Perch",             |
  |     edition: "347/1000",           |
  |     size: "large",                 |
  |     color: "albino" }             |
  |                                    |
  |-- Show fish reveal screen          |
```

**Note:** If the player fails to tap within 5s on bite, or the fish escapes the circle during the minigame, no server call is made and the player returns to idle.

---

## 3. Team Roles

### Dev A -- Client (Godot + Godot MCP)

Builds all Godot scenes, game mechanics, and UI. Uses **Godot MCP** with Claude Code to scaffold scenes, generate GDScript, and iterate on game feel.

### Dev B -- Backend (Go + Claude Code)

Builds the Go API server, SQLite schema, auth system, and catch logic. Uses **Claude Code** to generate Go boilerplate, write SQL migrations, and implement API handlers.

### Designer

Creates fish sprites (10 species + color variants), UI mockups, pond background, and the visual identity for the fish reveal screen. Delivers assets as PNG/SVG into the `resources/sprites/` directory.

---

## 4. TODO List

### Phase 0 -- Project Setup (Day 1-2)

- [x] **Dev A:** Initialize Godot 4.x project with folder structure from Section 2
- [x] **Dev A:** Set up Godot MCP server connection for Claude Code assisted development
- [x] **Dev B:** Initialize Go module (`go mod init`), create folder structure from Section 2
- [x] **Dev B:** Write `001_init.sql` migration and DB init code with WAL mode
- [x] **Dev B:** Seed fish_species table with 10 MVP species
- [x] **Designer:** Decide art style (propose 2-3 fish concepts for team vote)

### Phase 1 -- Auth & Skeleton (Day 3-5)

Backend:
- [x] **Dev B:** Implement `POST /auth/register` -- accept device_id, create player, return JWT
- [x] **Dev B:** Implement `POST /auth/refresh` -- validate device_id, issue new JWT
- [x] **Dev B:** Implement JWT middleware for protected routes
- [x] **Dev B:** Add basic request logging and error handling

Client:
- [x] **Dev A:** Create `auth.gd` autoload -- generate UUID on first launch, store in `user://`
- [x] **Dev A:** Create `network.gd` autoload -- HTTP client with JWT header injection
- [x] **Dev A:** Implement auto-registration on first launch (call `/auth/register`)
- [x] **Dev A:** Create `main_menu.tscn` -- simple start screen with "Fish!" button

Design:
- [x] **Designer:** Finalize art style based on team vote (pixel art, Stardew Valley aesthetic)
- [x] **Designer:** Create pond background (pixel art forest pond scene)
- [x] **Designer:** Start fish sprites (prioritize 3 common fish first)

### Phase 2 -- Fishing Mechanic (Day 6-12)

Client (core mechanic -- this is the most important phase):
- [x] **Dev A:** Build `fishing.tscn` -- pond background, water, bobber, cast button
- [x] **Dev A:** Implement cast power bar -- filling/emptying loop, tap to lock (inline in fishing.tscn)
- [x] **Dev A:** Implement bite wait phase -- random timer (2-6s, cast power affects duration)
- [x] **Dev A:** Implement bite reaction -- "BITE!" alert with 5s timeout, reaction time = timing score
- [x] **Dev A:** Build fish-fighting minigame overlay (joystick + circle arena, keep fish in circle 10s)
- [x] **Dev A:** Send timing score to backend on catch attempt
- [x] **Dev A:** Handle miss (pool depleted) -- return to idle state
- [x] **Dev A:** Use Godot MCP + Claude Code to iterate on game feel (bar speed, zone size, timing windows)

Backend:
- [x] **Dev B:** Implement `POST /fish/catch` -- full catch flow:
  - [x] Validate timing_score (0.0 - 1.0)
  - [x] Roll rarity tier based on score (better score = better odds)
  - [x] Select random species from rolled tier
  - [x] Check edition pool for remaining copies
  - [x] Assign random edition number from remaining pool
  - [x] Roll size and color traits
  - [x] Insert fish_instance and return full fish data
- [x] **Dev B:** Implement `GET /fish/pool` -- return remaining counts per species
- [x] **Dev B:** Write tests for catch logic (rarity distribution, pool depletion, edge cases)

Design:
- [ ] **Designer:** Deliver all 12 fish sprites (base color) -- 9/12 done (missing: Moonbass, Ice Trout, Golden Primeval Perch)
- [x] **Designer:** Create color variants for each fish (albino, melanistic, rainbow, neon = 4 variants per fish)
- [x] **Designer:** Design cast bar and progress bar sprites (wooden pixel art)
- [x] **Designer:** Design bobber and minigame indicator sprites

### Phase 3 -- Fish Reveal & Inventory (Day 13-18)

Client:
- [x] **Dev A:** Build fish reveal screen (`fish_reveal.tscn`):
  - [x] Fish sprite (correct species + color variant) with color modulation
  - [x] Edition number display ("#47 / 1000")
  - [x] Rarity badge (color-coded: common/uncommon/rare/epic/legendary)
  - [x] Size and color trait labels
  - [x] "Cast Again" button (returns to fishing)
- [x] **Dev A:** Build inventory as collection book (`inventory.tscn`):
  - [x] 2-column grid of fish cards with rarity-colored borders
  - [x] Search bar (filter by species name)
  - [x] Rarity filter buttons (All, Common, Uncommon, Rare, Epic, Legendary)
  - [x] Placeholder fish sprites (colored rectangles per species/variant)
  - [x] Tap to open fish detail view
- [x] **Dev A:** Build fish detail view (`fish_detail.tscn`):
  - [x] Full fish sprite, all traits, caught timestamp
- [x] **Dev A:** Implement navigation: Main Menu -> Fishing -> Reveal -> (Inventory | Fishing)

Backend:
- [x] **Dev B:** Implement `GET /player/inventory` -- return all fish for authenticated player
- [x] **Dev B:** Implement `GET /player/inventory/:id` -- return single fish detail
- [x] **Dev B:** Add pagination to inventory endpoint (offset + limit)

Design:
- [x] **Designer:** Design fish reveal screen layout (the "unboxing" moment)
- [x] **Designer:** Design rarity badge icons (5 tiers)
- [x] **Designer:** Design inventory list item layout
- [x] **Designer:** Design fish detail card layout

### Phase 4 -- Polish & Playtest (Day 19-24)

- [x] **Dev A:** Add SFX and music (cast, reel, catch chime, background soundtrack, ambient sounds)
- [x] **Dev A:** Add screen transitions (Animal Crossing iris wipe on all scene changes)
- [x] **Dev A:** Add bobber animation (idle float, appears after rod throw animation)
- [ ] **Dev A:** Add fish sprite animation on reveal (bounce/shimmer)
- [x] **Dev A:** Tune minigame difficulty per rarity tier via Godot MCP + Claude Code
- [x] **Dev B:** Add rate limiting on `/fish/catch` (max 1 catch per 3 seconds)
- [x] **Dev B:** Add basic error responses (pool empty, invalid timing, server errors)
- [x] **Dev B:** Stress test: simulate 100 players depleting a fish pool
- [x] **Designer:** Final polish pass on all sprites and UI elements
- [x] **Designer:** Create app icon and splash screen
- [x] **ALL:** Playtest session -- each team member plays 30+ minutes
- [x] **ALL:** Collect feedback: is the cast-wait-catch loop fun? Is the reveal exciting?
- [x] **ALL:** Prioritize and fix top 5 issues from playtest

### Phase 5 -- Build & Deploy (Day 25-28)

- [x] **Dev A:** Export Android APK via GitHub Actions CI/CD pipeline
- [x] **Dev B:** Dockerize Go backend (single container with SQLite volume mount)
- [x] **Dev B:** Deploy backend to a cheap VPS (Hetzner, Fly.io, or similar)
- [x] **Dev A:** Point client `network.gd` at deployed backend URL (injected via CI secret BACKEND_URL)
- [x] **ALL:** End-to-end test on real device / real server
- [x] **ALL:** Share APK with 5-10 friends for external feedback

---

## 5. Claude Code + Godot MCP Workflow

### How Dev A Uses Godot MCP

The [Godot MCP](https://github.com/pechaut78/godot-mcp) server connects Claude Code directly to the running Godot editor. This enables:

| Capability | How to use it |
|-----------|---------------|
| **Create scenes** | Ask Claude Code to generate `.tscn` scene trees via MCP |
| **Write GDScript** | Claude Code writes scripts and attaches them to nodes |
| **Modify nodes** | Adjust node properties (position, scale, colors) live in the editor |
| **Iterate on feel** | "Make the power bar 20% faster" -- Claude Code adjusts values via MCP |
| **Debug** | Read node state, inspect signals, trace issues through MCP |

**Typical workflow:**
```
1. Dev A describes what they need in Claude Code
2. Claude Code generates the scene/script via Godot MCP
3. Dev A playtests in Godot
4. Dev A describes what to change
5. Claude Code adjusts via MCP
6. Repeat until it feels right
```

### How Dev B Uses Claude Code

| Task | Prompt pattern |
|------|---------------|
| **Generate handlers** | "Create the /fish/catch POST handler in Go that does X, Y, Z" |
| **Write SQL** | "Write the migration for the fish_instances table with these constraints" |
| **Write tests** | "Write table-driven tests for the rarity roll function" |
| **Debug** | "This endpoint returns 500, here's the error -- fix it" |
| **Boilerplate** | "Set up the Go HTTP server with middleware chain and SQLite init" |

---

## 6. MVP Success Criteria

The MVP is successful if:

1. **The loop is fun** -- Playtesters want to "cast one more time" without being told to
2. **The reveal feels rewarding** -- Catching a rare fish or low edition number creates excitement
3. **Edition numbers matter** -- Playtesters notice and care about their fish's number and rarity
4. **It works end-to-end** -- Client talks to server, fish are persisted, edition pools deplete correctly
5. **10-minute sessions feel natural** -- Players can pick up and put down without friction

If these are validated, the next phase adds the marketplace and a second zone.

---

## 7. MVP Fish Species (12)

| # | Name | Rarity | Edition Size | Sprite | Notes |
|---|------|--------|-------------|--------|-------|
| 1 | Perch | Common | 1,000 | Done | Starter fish, easy catch |
| 2 | Carp | Common | 800 | Done | Slow bite, wide timing zone |
| 3 | Chub | Common | 600 | Done | Quick bite, forgiving minigame |
| 4 | Brook Trout | Uncommon | 400 | Done | Moderate difficulty |
| 5 | Moonbass | Uncommon | 300 | **Missing** | Only bites at dusk (future: MVP ignores time) |
| 6 | Catfish | Uncommon | 250 | Done | Long wait time |
| 7 | Ice Trout | Rare | 150 | **Missing** | Harder minigame difficulty |
| 8 | Night Eel | Rare | 100 | Done | Very challenging |
| 9 | Buntbarsch | Rare | 150 | Done | Cichlid, colorful tropical fish |
| 10 | Obsidian Pufferfish | Epic | 30 | Done | Tricky to land |
| 11 | Golden Primeval Perch | Legendary | 10 | **Missing** | Hardest to catch |
| 12 | Unifish | Legendary | 10 | Done | Mythical unicorn fish |
