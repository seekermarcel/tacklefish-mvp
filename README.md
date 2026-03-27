# Tacklefish

A casual mobile fishing game where every fish is a unique, numbered collectible. Catch, collect, and trade fish in a player-driven economy -- think Stardew Valley meets trading cards, but with fish.

## The Concept

You cast, you wait, you catch. Every fish has a limited global edition -- some exist 1,000 times, legendaries maybe only 10. Each catch gets a random edition number, random traits (size, color), and a rarity tier. Once all copies of a species are caught, it's gone from the wild.

Short sessions. No competitive pressure. Just the thrill of the next catch.

## Repository Structure

```
tacklefish/
  backend/             -- Go API server (auth, catching, inventory)
  docs/                -- Game design document, MVP plan
  references/          -- Original concept document (German)
  docker-compose.yml   -- Run the backend with Docker
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

### Documentation

- [Game Design Document](docs/game-design-document.md) -- full game design with mechanics, economy, and technical architecture
- [MVP Plan](docs/mvp.md) -- scoped MVP with team roles, TODOs, and success criteria

## Team

- 2 developers
- 1 designer

## Status

Early development -- backend MVP is functional, Godot client is next.
