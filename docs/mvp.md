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
| Fishing minigame (cast, wait, catch) | The core mechanic -- must feel good |
| 1 zone (Village Pond) | Enough to test the loop |
| 10 fish species (3 common, 3 uncommon, 2 rare, 1 epic, 1 legendary) | Tests the rarity system without needing hundreds of assets |
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
| Audio / music | Placeholder SFX only |

---

## 2. MVP Architecture

### Client (Godot)

```
tacklefish-client/
  project.godot
  scenes/
    fishing/
      fishing.tscn          -- Main gameplay scene
      cast_bar.tscn          -- Power bar UI component
      catch_minigame.tscn    -- Timing minigame overlay
    fish_reveal/
      fish_reveal.tscn       -- Post-catch reveal screen
    inventory/
      inventory.tscn         -- Simple scrollable fish list
      fish_detail.tscn       -- Single fish detail view
    main_menu/
      main_menu.tscn         -- Start screen (auto-auth on load)
  scripts/
    autoload/
      game_state.gd          -- Player state singleton
      network.gd             -- HTTP client singleton (API calls)
      auth.gd                -- Device ID + JWT management
    fishing/
      cast_controller.gd     -- Power bar logic
      bite_controller.gd     -- Wait timer, bite detection
      catch_minigame.gd      -- Timing indicator logic
    fish/
      fish_data.gd           -- Fish resource class
    ui/
      fish_card.gd           -- Reusable fish display widget
  resources/
    fish_species/            -- 10 species definitions (.tres)
    sprites/
      fish/                  -- 10 fish sprites + color variants
      ui/                    -- Buttons, bars, backgrounds
      environment/           -- Pond background, water, bobber
```

### Backend (Go)

```
tacklefish-server/
  cmd/
    server/
      main.go                -- Entry point, starts HTTP server
  internal/
    auth/
      handler.go             -- POST /auth/register, /auth/refresh
      jwt.go                 -- JWT creation and validation
      middleware.go           -- Auth middleware for protected routes
    fish/
      handler.go             -- POST /fish/catch (validate + assign)
      pool.go                -- Edition pool management
      traits.go              -- Trait rolling logic
      species.go             -- Species definitions and rarity
    player/
      handler.go             -- GET /player/inventory
      model.go               -- Player data model
    db/
      sqlite.go              -- DB init, migrations, connection
      queries.go             -- SQL queries
  migrations/
    001_init.sql             -- Players, fish_species, fish_instances, edition_pools
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

- [ ] **Dev A:** Initialize Godot 4.x project with folder structure from Section 2
- [ ] **Dev A:** Set up Godot MCP server connection for Claude Code assisted development
- [ ] **Dev B:** Initialize Go module (`go mod init`), create folder structure from Section 2
- [ ] **Dev B:** Write `001_init.sql` migration and DB init code with WAL mode
- [ ] **Dev B:** Seed fish_species table with 10 MVP species
- [ ] **Designer:** Decide art style (propose 2-3 fish concepts for team vote)

### Phase 1 -- Auth & Skeleton (Day 3-5)

Backend:
- [ ] **Dev B:** Implement `POST /auth/register` -- accept device_id, create player, return JWT
- [ ] **Dev B:** Implement `POST /auth/refresh` -- validate device_id, issue new JWT
- [ ] **Dev B:** Implement JWT middleware for protected routes
- [ ] **Dev B:** Add basic request logging and error handling

Client:
- [ ] **Dev A:** Create `auth.gd` autoload -- generate UUID on first launch, store in `user://`
- [ ] **Dev A:** Create `network.gd` autoload -- HTTP client with JWT header injection
- [ ] **Dev A:** Implement auto-registration on first launch (call `/auth/register`)
- [ ] **Dev A:** Create `main_menu.tscn` -- simple start screen with "Fish!" button

Design:
- [ ] **Designer:** Finalize art style based on team vote
- [ ] **Designer:** Create pond background (water, bank, sky)
- [ ] **Designer:** Start fish sprites (prioritize 3 common fish first)

### Phase 2 -- Fishing Mechanic (Day 6-12)

Client (core mechanic -- this is the most important phase):
- [ ] **Dev A:** Build `fishing.tscn` -- pond background, water, bobber, cast button
- [ ] **Dev A:** Implement cast power bar (`cast_bar.tscn`) -- filling/emptying loop, tap to lock
- [ ] **Dev A:** Implement bite wait phase -- random timer (2-10s), bobber dip animation
- [ ] **Dev A:** Build timing minigame (`catch_minigame.tscn`) -- moving indicator, target zone
- [ ] **Dev A:** Send timing score to backend on catch attempt
- [ ] **Dev A:** Handle miss (fish escapes) -- return to idle state
- [ ] **Dev A:** Use Godot MCP + Claude Code to iterate on game feel (bar speed, zone size, timing windows)

Backend:
- [ ] **Dev B:** Implement `POST /fish/catch` -- full catch flow:
  - [ ] Validate timing_score (0.0 - 1.0)
  - [ ] Roll rarity tier based on score (better score = better odds)
  - [ ] Select random species from rolled tier
  - [ ] Check edition pool for remaining copies
  - [ ] Assign random edition number from remaining pool
  - [ ] Roll size and color traits
  - [ ] Insert fish_instance and return full fish data
- [ ] **Dev B:** Implement `GET /fish/pool` -- return remaining counts per species
- [ ] **Dev B:** Write tests for catch logic (rarity distribution, pool depletion, edge cases)

Design:
- [ ] **Designer:** Deliver all 10 fish sprites (base color)
- [ ] **Designer:** Create color variants for each fish (albino, melanistic, rainbow, neon = 4 variants per fish)
- [ ] **Designer:** Design bobber, cast bar, and minigame indicator sprites
- [ ] **Designer:** Design the target zone visual for the timing minigame

### Phase 3 -- Fish Reveal & Inventory (Day 13-18)

Client:
- [ ] **Dev A:** Build fish reveal screen (`fish_reveal.tscn`):
  - [ ] Fish sprite (correct species + color variant)
  - [ ] Edition number display ("Exemplar 47 / 1000")
  - [ ] Rarity badge (color-coded: common/uncommon/rare/epic/legendary)
  - [ ] Size and color trait labels
  - [ ] "Keep" button (adds to inventory, returns to fishing)
- [ ] **Dev A:** Build inventory screen (`inventory.tscn`):
  - [ ] Scrollable list of caught fish (sprite thumbnail, name, edition number)
  - [ ] Tap to open fish detail view
- [ ] **Dev A:** Build fish detail view (`fish_detail.tscn`):
  - [ ] Full fish sprite, all traits, caught timestamp
- [ ] **Dev A:** Implement navigation: Main Menu -> Fishing -> Reveal -> (Inventory | Fishing)

Backend:
- [ ] **Dev B:** Implement `GET /player/inventory` -- return all fish for authenticated player
- [ ] **Dev B:** Implement `GET /player/inventory/:id` -- return single fish detail
- [ ] **Dev B:** Add pagination to inventory endpoint (offset + limit)

Design:
- [ ] **Designer:** Design fish reveal screen layout (the "unboxing" moment)
- [ ] **Designer:** Design rarity badge icons (5 tiers)
- [ ] **Designer:** Design inventory list item layout
- [ ] **Designer:** Design fish detail card layout

### Phase 4 -- Polish & Playtest (Day 19-24)

- [ ] **Dev A:** Add placeholder SFX (cast splash, reel, catch chime, rare catch fanfare)
- [ ] **Dev A:** Add screen transitions (fade/slide between scenes)
- [ ] **Dev A:** Add bobber animation (idle float, dip on bite)
- [ ] **Dev A:** Add fish sprite animation on reveal (bounce/shimmer)
- [ ] **Dev A:** Tune minigame difficulty per rarity tier via Godot MCP + Claude Code
- [ ] **Dev B:** Add rate limiting on `/fish/catch` (max 1 catch per 3 seconds)
- [ ] **Dev B:** Add basic error responses (pool empty, invalid timing, server errors)
- [ ] **Dev B:** Stress test: simulate 100 players depleting a fish pool
- [ ] **Designer:** Final polish pass on all sprites and UI elements
- [ ] **Designer:** Create app icon and splash screen
- [ ] **ALL:** Playtest session -- each team member plays 30+ minutes
- [ ] **ALL:** Collect feedback: is the cast-wait-catch loop fun? Is the reveal exciting?
- [ ] **ALL:** Prioritize and fix top 5 issues from playtest

### Phase 5 -- Build & Deploy (Day 25-28)

- [ ] **Dev A:** Export Android APK from Godot (or desktop build for easier testing)
- [ ] **Dev B:** Dockerize Go backend (single container with SQLite volume mount)
- [ ] **Dev B:** Deploy backend to a cheap VPS (Hetzner, Fly.io, or similar)
- [ ] **Dev A:** Point client `network.gd` at deployed backend URL
- [ ] **ALL:** End-to-end test on real device / real server
- [ ] **ALL:** Share APK with 5-10 friends for external feedback

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

## 7. MVP Fish Species (10)

| # | Name | Rarity | Edition Size | Notes |
|---|------|--------|-------------|-------|
| 1 | Perch | Common | 1,000 | Starter fish, easy catch |
| 2 | Carp | Common | 800 | Slow bite, wide timing zone |
| 3 | Sunfish | Common | 600 | Quick bite, small but forgiving zone |
| 4 | Brook Trout | Uncommon | 400 | Moderate difficulty |
| 5 | Moonbass | Uncommon | 300 | Only bites at dusk (future: MVP ignores time) |
| 6 | Catfish | Uncommon | 250 | Long wait time, wide zone |
| 7 | Ice Trout | Rare | 150 | Fast indicator, small zone |
| 8 | Night Eel | Rare | 100 | Very fast indicator |
| 9 | Obsidian Pufferfish | Epic | 30 | Tiny zone, tricky timing |
| 10 | Golden Primeval Perch | Legendary | 10 | Smallest zone, fastest indicator |
