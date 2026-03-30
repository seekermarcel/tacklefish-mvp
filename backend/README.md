# Tacklefish Backend

Go API server for the Tacklefish mobile fishing game. Handles authentication, fish catching with the edition system, and player inventory.

## Tech Stack

- **Go 1.25** -- standard library HTTP server, no framework
- **SQLite** (WAL mode) -- single-file database via `mattn/go-sqlite3`
- **JWT** -- device-based auth via `golang-jwt/jwt/v5`
- **Docker** -- multi-stage build, Alpine-based runtime

## Quick Start

### Docker (recommended)

```bash
# From the repo root
docker compose build
docker compose up -d
```

Server starts on `http://localhost:8080`.

Set a JWT secret for non-local use:

```bash
JWT_SECRET=your-secret-here docker compose up
```

### Local

Requires Go 1.25+ and a C compiler (for SQLite CGo bindings).

```bash
cd backend
go build -o tacklefish ./cmd/server/
./tacklefish
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `ADDR` | `:8080` | Listen address |
| `DB_PATH` | `./tacklefish.db` | SQLite database file path |
| `JWT_SECRET` | `change-me-in-production` | Secret for signing JWT tokens |

## API Reference

### Public Endpoints

#### `GET /health`

Health check.

```bash
curl http://localhost:8080/health
```

```json
{"status": "ok"}
```

#### `POST /auth/register`

Register a new device or re-authenticate an existing one. Returns a JWT valid for 24 hours.

```bash
curl -X POST http://localhost:8080/auth/register \
  -d '{"device_id": "550e8400-e29b-41d4-a716-446655440000"}'
```

```json
{
  "token": "eyJhbG...",
  "player_id": 1
}
```

#### `POST /auth/refresh`

Refresh an expired JWT using the original device ID.

```bash
curl -X POST http://localhost:8080/auth/refresh \
  -d '{"device_id": "550e8400-e29b-41d4-a716-446655440000"}'
```

```json
{
  "token": "eyJhbG...",
  "player_id": 1
}
```

### Protected Endpoints

All protected endpoints require the `Authorization: Bearer <token>` header.

#### `POST /fish/catch`

Catch a fish. Send a `timing_score` between 0.0 (worst) and 1.0 (perfect). Higher scores increase the chance of rarer fish. Rate limited to **1 catch per 3 seconds** per player.

```bash
curl -X POST http://localhost:8080/fish/catch \
  -H "Authorization: Bearer <token>" \
  -d '{"timing_score": 0.85}'
```

```json
{
  "id": 1,
  "species": "Obsidian Pufferfish",
  "rarity": "epic",
  "edition_number": 15,
  "edition_size": 30,
  "size_variant": "mini",
  "color_variant": "normal"
}
```

If all fish in every pool are depleted:

```json
{"result": "miss", "reason": "all fish depleted"}
```

If rate limited (called again within 3 seconds):

```
HTTP 429 Too Many Requests
Retry-After: 3
```

```json
{"error": "too many requests", "retry_after_seconds": 3}
```

#### `GET /fish/pool`

Get remaining edition counts for all species.

```bash
curl http://localhost:8080/fish/pool \
  -H "Authorization: Bearer <token>"
```

```json
[
  {"id": 1, "name": "Perch", "rarity": "common", "edition_size": 1000, "remaining": 997},
  {"id": 10, "name": "Golden Primeval Perch", "rarity": "legendary", "edition_size": 10, "remaining": 10}
]
```

#### `GET /player/inventory`

Get the authenticated player's fish collection. Supports pagination.

| Param | Default | Description |
|-------|---------|-------------|
| `limit` | 20 | Items per page (max 100) |
| `offset` | 0 | Skip N items |

```bash
curl "http://localhost:8080/player/inventory?limit=10&offset=0" \
  -H "Authorization: Bearer <token>"
```

```json
{
  "fish": [
    {
      "id": 1,
      "species": "Carp",
      "rarity": "common",
      "edition_number": 442,
      "edition_size": 800,
      "size_variant": "normal",
      "color_variant": "albino",
      "caught_at": "2026-03-27T09:20:17Z"
    }
  ],
  "total": 1,
  "offset": 0,
  "limit": 10
}
```

#### `GET /player/inventory/{id}`

Get details for a single fish owned by the authenticated player.

```bash
curl http://localhost:8080/player/inventory/1 \
  -H "Authorization: Bearer <token>"
```

Returns 404 if the fish doesn't exist or belongs to another player.

## Project Structure

```
backend/
  cmd/server/
    main.go                -- Entry point, route wiring, middleware
  internal/
    auth/
      handler.go           -- Register & refresh endpoints
      jwt.go               -- Token generation & validation
      middleware.go         -- Bearer token middleware
      ratelimit.go         -- Per-player rate limiting
    fish/
      handler.go           -- Catch & pool endpoints
      pool.go              -- Edition pool queries, number assignment
      species.go           -- Rarity weights, timing-to-rarity math
      traits.go            -- Size & color variant rolling
    player/
      handler.go           -- Inventory endpoints
    db/
      sqlite.go            -- DB connection, migration runner
  migrations/
    001_init.sql           -- Schema (players, fish_species, fish_instances)
    002_seed_species.sql   -- 12 MVP fish species
    embed.go               -- Embeds .sql files into the binary
  tests/
    helpers_test.go        -- Shared test DB setup and helpers
    species_test.go        -- Rarity weight tests
    traits_test.go         -- Size & color roll tests
    pool_test.go           -- Edition pool and number assignment tests
    stress_test.go         -- Concurrent pool depletion (100 workers)
  Dockerfile               -- Multi-stage build
  .dockerignore
```

## Database

SQLite with WAL mode enabled. The schema is applied automatically on startup.

Tables:
- **players** -- device ID, creation timestamp
- **fish_species** -- name, rarity, edition size, zone
- **fish_instances** -- caught fish with species, owner, edition number, traits

Edition numbers are enforced unique per species via `UNIQUE(species_id, edition_number)`.

## Game Mechanics

### Rarity Rolling

The `timing_score` shifts drop weights toward rarer tiers:

| Rarity | Score 0.0 | Score 1.0 |
|--------|-----------|-----------|
| Common | 80% | 40% |
| Uncommon | 15% | 30% |
| Rare | 4% | 18% |
| Epic | 1% | 8% |
| Legendary | 0% | 4% |

If the rolled rarity has no copies left, the system falls back to the next more common tier.

### Edition Numbers

Assigned randomly from the remaining pool -- catching first doesn't guarantee a low number. Once all copies of a species are caught, it's gone from the wild.

### Traits

Each fish gets independent random rolls for size and color:

- **Size**: normal (70%), large (15%), mini (10%), giant (5%)
- **Color**: normal (80%), albino (7%), melanistic (6%), rainbow (4%), neon (3%)

## Testing

```bash
cd backend

make test              # Run all tests
make coverage          # Run tests with per-function coverage report
make coverage-html     # Generate HTML coverage report (coverage.html)
```

Or without Make:

```bash
go test ./tests/ -v                                                        # Run all tests
go test ./tests/ -v -run "Stress"                                          # Only stress tests
go test ./tests/ -coverprofile=coverage.out -coverpkg=github.com/tacklefish/backend/internal/...  # Coverage
go tool cover -func=coverage.out                                           # Per-function report
go tool cover -html=coverage.out -o coverage.html                          # HTML report
```

### Coverage: 83.3%

| Package | Function | Coverage |
|---------|----------|----------|
| `auth` | GenerateToken | 100% |
| `auth` | ValidateToken | 80% |
| `auth` | Register | 78% |
| `auth` | Refresh | 67% |
| `auth` | Middleware | 100% |
| `auth` | GetClaims | 100% |
| `auth` | newRateLimiter | 100% |
| `auth` | allow | 100% |
| `auth` | RateLimitMiddleware | 86% |
| `fish` | Catch | 82% |
| `fish` | Pool | 67% |
| `fish` | rollRarity | 92% |
| `fish` | pickWithFallback | 92% |
| `fish` | PoolStatus | 82% |
| `fish` | PickSpecies | 81% |
| `fish` | AssignEditionNumber | 84% |
| `fish` | RarityWeights | 100% |
| `fish` | lerp / clamp | 100% |
| `fish` | RollSize | 100% |
| `fish` | RollColor | 100% |
| `player` | Inventory | 69% |
| `player` | FishDetail | 79% |

### Test Files (39 tests)

| File | Tests |
|------|-------|
| `auth_test.go` | JWT generate/validate, register/refresh handlers, middleware (valid/missing/bad/invalid token), rate limiter (allow/block/cooldown) |
| `handler_test.go` | Catch (success, invalid timing, no claims, pool depleted), pool status, inventory (list, pagination, empty), fish detail (success, not found, wrong owner, invalid ID) |
| `species_test.go` | Rarity weights at 0.0 and 1.0, clamping, monotonicity |
| `traits_test.go` | Valid variant returns, distribution sanity checks (100K rolls) |
| `pool_test.go` | Pool status tracking, depletion returns nil, edition number assignment + exhaustion |
| `stress_test.go` | 100 concurrent workers depleting 200-copy pool, multi-species concurrent depletion |
