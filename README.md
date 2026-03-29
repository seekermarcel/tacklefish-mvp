# Tacklefish

A casual mobile fishing game where every fish is a unique, numbered collectible. Catch, collect, and trade fish in a player-driven economy -- think Stardew Valley meets trading cards, but with fish.

## The Concept

You cast, you wait, you catch. Every fish has a limited global edition -- some exist 1,000 times, legendaries maybe only 10. Each catch gets a random edition number, random traits (size, color), and a rarity tier. Once all copies of a species are caught, it's gone from the wild.

Short sessions. No competitive pressure. Just the thrill of the next catch.

## Repository Structure

```
tacklefish/
  backend/             -- Go API server (auth, catching, inventory)
  frontend/            -- Godot 4.x game client (GDScript)
  testing-frontend/    -- Browser-based test client (HTML/JS)
  docs/                -- Game design document, MVP plan
  references/          -- Original concept document (German)
  docker-compose.yml   -- Run backend + testing frontend with Docker
```

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Game Client | Godot 4.x (GDScript) |
| Backend | Go, standard library HTTP server |
| Database | SQLite (WAL mode) |
| Cache (future) | Valkey |
| Auth | Device ID + JWT |
| Infrastructure | Docker |

## Getting Started

### Run the backend

```bash
docker compose up
```

The API server starts on `http://localhost:8080`. See [backend/README.md](backend/README.md) for full API documentation.
The testing frontend starts on `http://localhost:3000`.

### Run the Godot client

Open `frontend/` in Godot 4.6+ and press F5. Requires the backend running on `localhost:8080`.

The client connects automatically -- no login screen. It generates a device UUID on first launch, registers with the backend, and you can start fishing immediately.

### Run the tests

```bash
cd backend
go test ./tests/ -v
```

### Documentation

- [Game Design Document](docs/game-design-document.md) -- full game design with mechanics, economy, and technical architecture
- [MVP Plan](docs/mvp.md) -- scoped MVP with team roles, TODOs, and success criteria
- [Frontend Transfer Document](docs/frontend-transfer.md) -- API contract and integration guide for the Godot client

## Team

- 2 developers
- 1 designer

## Git Hooks

The repo uses a pre-commit hook that runs backend tests when backend code is changed. It's set up automatically via `.githooks/`. On a fresh clone:

```bash
git config core.hooksPath .githooks
```

## Status

Early development -- backend MVP is complete (all endpoints, rate limiting, tests). Godot client has initial scaffolding with working fishing flow (cast, wait, timing minigame, catch, reveal, inventory). Still needs art assets, polish, and game feel tuning.
