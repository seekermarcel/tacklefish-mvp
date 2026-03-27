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
- `references/Tacklefish_Konzept.docx` -- Original concept document (German)

## Repository Structure

```
backend/               -- Go API server
  cmd/server/          -- Entry point
  internal/auth/       -- Device ID + JWT auth
  internal/fish/       -- Catch logic, edition pools, traits, rarity
  internal/player/     -- Inventory endpoints
  internal/db/         -- SQLite connection and migrations
  migrations/          -- SQL schema and seed data
docs/                  -- Design documents
references/            -- Source material
docker-compose.yml     -- Run backend via Docker
```

## Running the Backend

```bash
# Docker (recommended)
docker compose up

# Local
cd backend && go build -o tacklefish ./cmd/server/ && ./tacklefish
```

Server runs on `http://localhost:8080`. See `backend/README.md` for full API docs.

## Code Conventions

### Go (Backend)

- Standard library HTTP server -- no frameworks (no Gin, no Echo, no Chi)
- `net/http` ServeMux with method patterns (e.g., `"POST /fish/catch"`)
- All game state validation is server-side (client is untrusted)
- SQL migrations are embedded via `embed.FS` in `migrations/embed.go`
- Use `internal/` packages -- nothing is exported outside the module
- Error responses are JSON: `{"error": "message"}`
- Environment config via `os.Getenv` with sensible defaults, no config files

### Godot (Client) -- Not Yet Started

- GDScript as the primary language
- Singletons in `scripts/autoload/` for global state, networking, auth
- Scenes organized by feature in `scenes/`
- Fish species defined as Godot resources (`.tres`) in `resources/fish_species/`

## Technical Decisions

These have been decided and should not be changed without discussion:

- **Go** for the backend, not Node.js or Rust
- **SQLite** for storage, not PostgreSQL (migration path exists if needed)
- **SQLite BLOBs** for file storage (avatars, screenshots), not S3
- **Valkey** for caching (when needed), not Redis (licensing reasons)
- **Device ID + JWT** for auth, not OAuth (keep it simple)
- **Godot 4.x** with GDScript, not Unity or Unreal
- **No pay-to-win** -- real money only buys fish from other players, never gameplay advantages

## Git Workflow

- Never commit or push unless specifically told to
- Keep commits focused and descriptive
- No force pushes to main

## MVP Focus

The current phase is MVP (see `docs/mvp.md`). Only these features matter right now:

1. Fishing minigame (cast, wait, catch)
2. 1 zone (Village Pond), 10 fish species
3. Edition system with numbered fish
4. Fish reveal screen
5. Simple inventory
6. Device ID auth + Go backend

Everything else (marketplace, seasons, cosmetics, multiple zones) is post-MVP.
