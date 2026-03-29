# Tacklefish - Claude Code Instructions

## Project Overview

Tacklefish is a casual mobile fishing game where every fish is a unique, numbered collectible with limited global editions. Players catch, collect, and trade fish in a player-driven economy.

- **Game Client:** Godot 4.x with GDScript
- **Backend:** Go (standard library HTTP server, no framework)
- **Database:** SQLite with WAL mode (`mattn/go-sqlite3`)
- **Auth:** Device ID + JWT (`golang-jwt/jwt/v5`)
- **Cache (future):** Valkey (not Redis)
- **Infrastructure:** Docker + Docker Compose
- **Team:** 2 developers, 1 designer

## Key Documents

- `docs/game-design-document.md` -- Full GDD with mechanics, economy, tech architecture
- `docs/mvp.md` -- Scoped MVP plan with team roles, TODOs, success criteria
- `docs/frontend-transfer.md` -- API contract and integration guide for the Godot client
- `references/Tacklefish_Konzept.docx` -- Original concept document (German)

## Repository Structure

```
backend/               -- Go API server
  cmd/server/          -- Entry point
  internal/auth/       -- Device ID + JWT auth, rate limiting
  internal/fish/       -- Catch logic, edition pools, traits, rarity
  internal/player/     -- Inventory endpoints
  internal/db/         -- SQLite connection and migrations
  migrations/          -- SQL schema and seed data
  tests/               -- All backend tests (unit, distribution, stress)
frontend/              -- Godot 4.x game client
  scenes/              -- Scene files organized by feature
    main_menu/         -- Start screen with auto-auth
    fishing/           -- Cast bar, wait phase, timing minigame
    fish_reveal/       -- Post-catch reveal screen
    inventory/         -- Scrollable fish collection
  scripts/
    autoload/          -- Singletons: GameState, Auth, Network
    main_menu/         -- Main menu logic
    fishing/           -- Fishing flow controller
    fish_reveal/       -- Reveal screen logic
    inventory/         -- Inventory list + pagination
  resources/           -- Fish species, sprites, UI assets
testing-frontend/      -- Browser-based test client (HTML/JS/nginx)
docs/                  -- Design documents
references/            -- Source material
docker-compose.yml     -- Run backend + testing frontend via Docker
```

## Running the Project

```bash
# Backend + testing frontend via Docker (recommended)
docker compose up

# Backend locally
cd backend && go build -o tacklefish ./cmd/server/ && ./tacklefish

# Godot client -- open in Godot editor, press F5 to run
# Requires backend running on http://localhost:8080
```

Backend runs on `http://localhost:8080`. See `backend/README.md` for full API docs.
Testing frontend runs on `http://localhost:3000`.

## Code Conventions

### Go (Backend)

- Standard library HTTP server -- no frameworks (no Gin, no Echo, no Chi)
- `net/http` ServeMux with method patterns (e.g., `"POST /fish/catch"`)
- All game state validation is server-side (client is untrusted)
- SQL migrations are embedded via `embed.FS` in `migrations/embed.go`
- Use `internal/` packages -- nothing is exported outside the module
- Error responses are JSON: `{"error": "message"}`
- Environment config via `os.Getenv` with sensible defaults, no config files
- Rate limiting via in-memory per-player tracking (`internal/auth/ratelimit.go`)
- Tests live in `backend/tests/` (external test package), run with `go test ./tests/ -v`

### Godot (Client)

- **Godot 4.6** with GDScript, mobile renderer
- Portrait orientation (720x1280 viewport, canvas_items stretch)
- 3 autoload singletons registered in `project.godot`:
  - `GameState` -- player ID, inventory, pool data
  - `Auth` -- device UUID generation/persistence, JWT token storage
  - `Network` -- HTTP client wrapping all API calls, auto-refresh on 401, rate limit handling
- Scenes organized by feature in `scenes/`, scripts in matching `scripts/` subdirectories
- Scenes use `unique_name_in_owner` (`%NodeName`) for node references
- All game logic is server-side -- client only sends `timing_score` and displays results
- Fish species defined as Godot resources (`.tres`) in `resources/fish_species/` (not yet created)

## Technical Decisions

These have been decided and should not be changed without discussion:

- **Go** for the backend, not Node.js or Rust
- **SQLite** for storage, not PostgreSQL (migration path exists if needed)
- **SQLite BLOBs** for file storage (avatars, screenshots), not S3
- **Valkey** for caching (when needed), not Redis (licensing reasons)
- **Device ID + JWT** for auth, not OAuth (keep it simple)
- **Godot 4.x** with GDScript, not Unity or Unreal
- **No pay-to-win** -- real money only buys fish from other players, never gameplay advantages

## Testing Rules

- **Every new important function must have a test.** When adding functions to `internal/`, also write tests in `backend/tests/` in the same session.
- Tests use the external test package pattern (`package tests`) with shared helpers in `helpers_test.go`.
- Use `httptest` for handler tests, inject auth claims via `requestWithClaims()` helper.
- Run `make coverage` after adding tests to verify coverage doesn't drop below 83%.
- Coverage is measured with `-coverpkg=github.com/tacklefish/backend/internal/...` to track all internal packages.

## Git Workflow

- Never commit or push unless specifically told to
- Keep commits focused and descriptive
- No force pushes to main
- Pre-commit hook runs backend tests automatically when backend code is staged. Hooks live in `.githooks/` (tracked in git, set via `git config core.hooksPath .githooks`)

## MVP Focus

The current phase is MVP (see `docs/mvp.md`). Only these features matter right now:

1. Fishing minigame (cast, wait, catch)
2. 1 zone (Village Pond), 10 fish species
3. Edition system with numbered fish
4. Fish reveal screen
5. Simple inventory
6. Device ID auth + Go backend

Everything else (marketplace, seasons, cosmetics, multiple zones) is post-MVP.
