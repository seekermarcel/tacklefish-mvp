# Tacklefish - Game Design Document

**Version:** 1.0
**Engine:** Godot 4.x
**Platform:** Mobile (Android / iOS)
**Genre:** Casual Fishing & Trading
**Target Release:** TBD

---

## 1. Vision

Tacklefish is a relaxed mobile fishing game with a Stardew Valley-like feel, designed for short sessions (5-15 minutes). The core hook: every fish is a unique, numbered collectible with a limited global edition. Players catch, collect, trade, and sell fish in a player-driven economy.

### Elevator Pitch

> You cast, you wait, you catch -- every fish is unique and numbered.
> Some exist 1,000 times worldwide, legendaries maybe only 10.
> Collect, trade, or sell -- and chase the one fish you still need.

### Target Audience

- Casual gamers, 14-35 years old
- Short daily sessions (5-15 min) during commutes, breaks, downtime
- Collector personality: enjoys completionism, rarities, trading
- No competitive pressure -- a relaxing experience

---

## 2. Core Game Loop

```
1. Cast Line        --> Hold-and-release power bar determines cast distance
2. Wait & Observe   --> Fish approaches the bait (ambient waiting phase)
3. Timing Minigame  --> Keep needle in zone / tap at the right moment
4. Catch Fish       --> Rarity & quality depend on timing precision
5. Reveal Fish Pass --> Species, edition number, size, pattern, traits
6. Decide           --> Keep / Trade / Sell / Release
7. Cast Again       --> Loop restarts
```

### Cast Mechanic

- A power bar fills and empties on loop
- Player taps to lock in cast distance
- Longer casts reach deeper water with rarer fish pools
- Upgraded rods increase maximum cast distance

### Timing Minigame

- A moving indicator must be stopped inside a shrinking target zone
- Better timing = higher quality catch (size, traits, rarity bonus)
- Different fish species have different minigame patterns (speed, zone size)
- Rare fish have faster, smaller zones -- harder to land perfectly

### Bite Mechanics

- After casting, a random wait timer runs (2-15 seconds)
- Visual and haptic cues signal a bite (bobber dip, vibration)
- Player must react within a short window or the fish escapes
- Bait type influences wait time and species probability

---

## 3. Edition System

The central feature that drives the entire economy. Every fish species exists in a fixed, limited global edition shared across all players.

### Rarity Tiers

| Tier | Edition Size | Drop Rate | Example |
|------|-------------|-----------|---------|
| Common | 500 - 1,000 | 60% | Perch, Carp |
| Uncommon | 200 - 499 | 25% | Moonbass, Brook Trout |
| Rare | 50 - 199 | 10% | Ice Trout, Night Eel |
| Epic | 11 - 49 | 4% | Obsidian Pufferfish |
| Legendary | 1 - 10 | 1% | Golden Primeval Perch |
| Unique | 1 | < 0.1% | ??? |

### Numbering Rules

- Edition numbers are assigned **randomly** from the remaining pool at catch time
- Fishing first does **not** guarantee a low number -- prevents first-mover advantage
- Each number exists exactly once per species per season
- Numbers are permanently bound to the caught instance

### Pool Depletion

- When all copies of a species are caught, it can only be acquired via the marketplace
- The season system periodically refills pools (see Section 4)
- A global counter per species shows remaining copies in the wild

---

## 4. Season System

Seasons refill fish pools on a regular cycle while preserving the value of earlier catches.

### Season Structure

| Aspect | Season 1 (First Edition) | Season 2+ |
|--------|--------------------------|-----------|
| Badge | S1 First Edition badge | S2, S3... badge |
| Pool | Fresh full pool | Fresh full pool |
| Prestige | Highest -- never obtainable again | Lower, but still collectible |
| Market Value | Appreciates over time | Standard value |

### Season Parameters

- **Duration:** TBD (candidate: 3 months)
- Each season introduces new exclusive fish species
- Seasonal events (e.g., holiday-themed fish)
- Previous season fish retain their badge permanently
- Season pass with cosmetic rewards (no gameplay advantages)

### Seasonal Content Examples

- Winter: Ice Crystal Carp, Frost Eel
- Summer: Sunfire Bass, Coral Shrimp
- Halloween: Phantom Catfish, Skeleton Pike
- New zones may unlock with new seasons

---

## 5. Zones & Fish Pools

Fish are distributed across zones unlocked through player progression. Later zones contain more species and higher rarities.

| Zone | Name | Fish Species | Unlock Condition | Biome Features |
|------|------|-------------|-----------------|----------------|
| 1 | Village Pond | ~200 | Start | Freshwater basics, tutorials |
| 2 | Coastal Bay | ~300 | Level 10 | Saltwater fish, first rares |
| 3 | Mangrove Swamp | ~350 | Level 20 | Exotic species, night fish |
| 4 | Glacier Lake | ~350 | Level 30 | Ice fish, time-of-day gating |
| 5 | Volcano Reef | ~400 | Level 45 | Legendary deep-sea fish |
| 6 | ??? | ~400 | Level 60 | Secret zone, unknown species |

### Environmental Modifiers

- **Time of Day:** Some fish only appear at dawn, noon, dusk, or night (synced to real-world clock)
- **Weather:** Rain, storm, fog, clear skies affect active fish pools
- **Moon Phase:** Follows real-world lunar cycle; certain legendaries only appear during full/new moon
- **Seasonal:** Zone pools rotate with the season system

---

## 6. Fish Variations & Traits

Every caught fish receives randomly rolled traits. No two fish are identical.

| Trait | Variants | Value Impact |
|-------|----------|-------------|
| Color Variant | Albino, Melanistic, Rainbow, Neon | High |
| Size | Mini, Normal, Large, Giant | Moderate |
| Pattern | Spotted, Striped, Marbled, Plain | Moderate |
| Sheen | Matte, Glossy, Luminous | High |
| Accessory | Hat, Glasses, Scar, Crown | Very High |
| Low Number | e.g., #3 / 1,000 | Prestige |
| First Edition | S1 Badge | Long-term value |

### Trait Probability

- Most catches are Normal size, Plain pattern, Matte sheen
- Special traits have independent roll chances (e.g., 5% Glossy, 1% Luminous)
- Accessories are the rarest cosmetic trait (< 1%)
- Multiple rare traits can stack, making some fish extremely valuable

---

## 7. Economy & Marketplace

### Dual Currency System

| | Coins (In-Game) | Real Money |
|--|-----------------|------------|
| **Earned by** | Fishing, trading, daily quests | Selling fish on marketplace |
| **Spent on** | Bait, rod skins, aquarium decor | Player-to-player fish purchases |
| **Gameplay advantage** | None | None -- ever |

### Marketplace

- Players list fish for sale in coins or real money
- **10% transaction fee** on every sale (game revenue)
- Seller receives 90% of the sale price
- Fully asynchronous -- no real-time pressure
- Counter-offers supported for coin trades
- Search and filter by species, rarity, traits, edition number, price

### Pay-to-Win Protection

- Real money can **only** buy fish that other players caught and listed
- No direct purchases from the developer/store for fish
- Coins buy comfort and cosmetics only -- never better catch rates
- Every fish in the game was caught by a real player

### Anti-Inflation Mechanics

- **Aquarium slots are limited** -- forces selling instead of hoarding (expandable with coins)
- **Bait is consumable** -- constant coin sink
- **Release mechanic** -- releasing a fish returns it to the wild pool, player gets a small coin reward
- **Seasonal rotation** -- not all fish available at all times
- **Marketplace listing fee** -- small coin cost to list items

---

## 8. Progression System

### Player Level

- XP earned from catching fish, completing collections, daily quests
- Leveling unlocks new zones, rod slots, aquarium expansions
- No level-gated catch advantages -- just access to new areas

### Aquarium

- Personal display for collected fish
- Limited slots (expandable via coins)
- Decoratable with earned/purchased cosmetics
- Visitors can view other players' aquariums

### Fish Codex

- Encyclopedia of all fish species
- Tracks caught/uncaught, best specimen, trait variants seen
- Completion milestones reward cosmetics and titles
- Per-zone and per-rarity completion trackers

### Daily Quests

- "Catch 3 uncommon fish"
- "Sell a fish on the marketplace"
- "Catch a fish in Zone 3"
- Reward: coins, XP, occasional rare bait

---

## 9. Monetization

### Revenue Streams

1. **Marketplace transaction fee** (10% on every trade)
2. **Season Pass** -- cosmetic rewards track (optional purchase)
3. **Cosmetic Shop** -- rod skins, bobber effects, aquarium decorations
4. **Aquarium Themes** -- visual themes for the aquarium display

### What Money Cannot Buy

- Fish directly from the game (only from other players)
- Better catch rates or rarity boosts
- Exclusive gameplay content
- Faster progression or XP boosts

---

## 10. Technical Architecture

### Engine & Platform

- **Engine:** Godot 4.x (GDScript primary, C# where performance-critical)
- **Platforms:** Android, iOS (Godot's mobile export pipeline)
- **Rendering:** Godot 2D renderer with sprite-based visuals

### Client Architecture

```
tacklefish/
  project.godot
  scenes/
    main_menu/          -- Title screen, settings, account
    fishing/            -- Core fishing gameplay scene
    aquarium/           -- Player's fish collection display
    marketplace/        -- Browse, buy, sell interface
    codex/              -- Fish encyclopedia
    zone_select/        -- World map / zone picker
  scripts/
    autoload/           -- Singletons (GameState, NetworkManager, AudioManager)
    fishing/            -- Cast, bite, minigame logic
    fish/               -- Fish data, trait generation, edition tracking
    economy/            -- Wallet, transactions, pricing
    ui/                 -- Shared UI components
  resources/
    fish_data/          -- Fish species definitions (.tres)
    sprites/            -- Fish sprites, UI elements, environments
    audio/              -- SFX, ambient loops, music
    shaders/            -- Water effects, glow, weather
  addons/               -- Third-party Godot plugins
```

### Backend Architecture

The edition system and marketplace require authoritative server-side logic.

```
Backend Services:

  API Gateway
    |
    +-- Auth Service          -- Device ID registration, token issuing
    +-- Fish Pool Service     -- Global edition tracking, number assignment
    +-- Catch Service         -- Validates catches, rolls traits, assigns numbers
    +-- Marketplace Service   -- Listings, transactions, escrow
    +-- Player Service        -- Inventory, aquarium, progression
    +-- Season Service        -- Season timers, pool resets, badge assignment
    +-- Event Service         -- Daily quests, seasonal events

  Storage
    +-- SQLite                -- Single-file DB: players, fish registry, marketplace, analytics
    +-- BLOB columns          -- Player avatars, aquarium screenshots stored inline
    +-- Valkey                -- Fish pool counters, session tokens, rate limiting
```

### Key Technical Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Engine | Godot 4.x | Open source, lightweight, strong 2D, mobile-friendly |
| Primary Language | GDScript | Native Godot language, fast iteration, team familiarity |
| Networking | HTTPS REST API | Async marketplace fits request/response model |
| Real-time needs | WebSocket (optional) | Only if live notifications or live trading added later |
| Backend Language | Go | Fast, lightweight, great concurrency, easy to deploy as single binary |
| Database | SQLite | Single-file DB, zero ops, sufficient for early scale, easy backups |
| File Storage | SQLite BLOB | Avatars and screenshots stored inline -- no extra infrastructure |
| Cache Layer | Valkey | Redis-compatible (BSD licensed), used for pool counters, sessions, rate limiting |
| Auth | Device ID + JWT | UUID generated on first launch, JWT tokens for API auth, zero friction |

### Auth Flow

```
1. First Launch   --> Client generates a UUID v4 (device ID)
2. Register       --> POST /auth/register { device_id } --> server returns JWT
3. Subsequent     --> Client sends JWT in Authorization header
4. Token Refresh  --> POST /auth/refresh { device_id } --> new JWT
5. Account Link   --> Optional future addition (email, Google sign-in)
```

- No login screen -- player starts immediately
- Device ID stored in Godot's `user://` persistent storage
- JWT expires after 24h, auto-refreshed by the client
- If device ID is lost (app uninstall), account is unrecoverable unless linked (future feature)

### SQLite Considerations

- Single `tacklefish.db` file for all relational data (players, fish registry, marketplace, transactions)
- Player avatars and aquarium screenshots stored as BLOBs (typically < 500KB each)
- WAL mode enabled for concurrent read performance
- Go driver: `mattn/go-sqlite3` (CGo) or `modernc.org/sqlite` (pure Go, easier cross-compilation)
- Backup strategy: periodic file copy of the `.db` file
- Migration path: if scale demands it, SQLite can be replaced with PostgreSQL later -- SQL stays largely the same

### Security Considerations

- All catch validation is server-side (client sends timing input, server determines outcome)
- Edition number assignment happens exclusively on the server
- Marketplace transactions use server-side escrow
- Rate limiting on all API endpoints via Valkey counters
- Anti-cheat: server validates all game state transitions
- Device ID is not trusted blindly -- JWT must be valid for all authenticated requests

---

## 11. Art Direction

**Style:** TBD -- candidates under consideration:

| Style | Pros | Cons |
|-------|------|------|
| Chibi Pixel Art | Nostalgic, performant, fast to produce | May feel generic |
| Illustrative / Hand-drawn | Unique identity, warm aesthetic | Slower production, harder to scale |
| Vector / Flat Design | Clean on all resolutions, modern feel | Less character |

### Visual Priorities

- Fish must be instantly recognizable and visually distinct
- Trait variations (color, sheen, accessories) must be clearly visible at small sizes
- UI must be thumb-friendly and readable on small screens
- Water and ambient effects should feel relaxing (gentle waves, lighting)
- Zones must have distinct visual identities

---

## 12. Audio Design

- **Ambient:** Zone-specific soundscapes (pond crickets, ocean waves, swamp frogs, wind)
- **Music:** Lo-fi / acoustic background tracks, non-intrusive, loopable
- **SFX:** Satisfying cast, splash, reel, and catch sounds
- **Haptics:** Vibration feedback on bite, catch, rare fish reveal
- **UI Sounds:** Subtle taps, confirmation chimes, marketplace notifications

---

## 13. Open Questions

| # | Question | Options | Status |
|---|----------|---------|--------|
| 1 | Season duration | 3 months / 6 months / 1 year | Open |
| 2 | Total fish species at launch | Start with ~500 or full ~2,000 | Open |
| 3 | Battle Pass vs marketplace-only monetization | Both / marketplace only | Open |
| 4 | PvP elements (fishing tournaments, leaderboards) | Include / keep purely relaxed | Open |
| 5 | Free-to-play vs paid app | F2P with marketplace / one-time purchase | Open |
| 6 | Real-money marketplace legal requirements | Age verification, regional laws, app store rules | Needs legal review |
| 7 | Backend language/framework | **Go** | Decided |
| 8 | Art style | Pixel art / illustrative / vector | Open |

---

## 14. Next Steps

1. **Fish Design** -- Define first 50-100 species with names, rarity, zone, trait pools
2. **Art Direction** -- Produce concept art in 2-3 candidate styles, decide on direction
3. **Prototype** -- Build the core fishing minigame in Godot (cast, wait, catch loop)
4. **Backend Spike** -- Prototype the edition pool service and number assignment
5. **Marketplace Design** -- Wireframe the trading UI and transaction flow
6. **Legal Review** -- Clarify real-money marketplace regulations per target market
7. **Backend Setup** -- Initialize Go project, set up SQLite schema, Valkey connection, basic API skeleton
