# Tacklefish Economy Balancing

This document describes how the in-game economy works, why it's designed this way, and how to tune it.

## Core Principle

**Catching is earning.** Players should never need to destroy fish to make money. Every catch awards both XP and Shells, making sustainable play the default. Destructive actions (quick-sell) exist as a choice, not a necessity.

## Currency: Shells

Shells are the universal currency. They flow through the economy via three channels:

| Channel | Shells In | Shells Out | Fish Impact |
|---------|-----------|------------|-------------|
| Catching | Yes (small, per catch) | -- | Fish created |
| Quick-Sell | Yes (moderate, one-time) | -- | Edition permanently destroyed |
| Marketplace | -- | Yes (10% tax on sales) | Fish transfers between players |
| Release | -- | -- | Edition returns to pool |

**Shells are created** when players catch or quick-sell fish.
**Shells are destroyed** only via marketplace tax (10% of every sale vanishes).

## Reward Tables

### Catching a Fish

Every successful catch awards both XP and Shells. This is the primary income source.

| Rarity | XP | Shells |
|--------|----|--------|
| Common | 10 | 2 |
| Uncommon | 20 | 5 |
| Rare | 50 | 12 |
| Epic | 100 | 30 |
| Legendary | 250 | 75 |

### Quick-Selling a Fish

Permanently removes the fish and its edition number from the game. The edition can never be caught again.

| Rarity | Shells |
|--------|--------|
| Common | 5 |
| Uncommon | 10 |
| Rare | 25 |
| Epic | 50 |
| Legendary | 100 |

The quick-sell premium over a catch reward is intentionally small:

| Rarity | Catch Shells | Quick-Sell | Premium |
|--------|-------------|------------|---------|
| Common | 2 | 5 | +3 |
| Uncommon | 5 | 10 | +5 |
| Rare | 12 | 25 | +13 |
| Epic | 30 | 50 | +20 |
| Legendary | 75 | 100 | +25 |

This means quick-selling a common fish gives only 3 more Shells than you already earned by catching it. The small premium discourages destroying fish for profit while still giving players a way to clean up unwanted catches.

### Releasing a Fish

Returns the edition to the catchable pool. Awards XP but no Shells. This is the "generous" option.

| Rarity | XP |
|--------|-----|
| Common | 5 |
| Uncommon | 10 |
| Rare | 25 |
| Epic | 50 |
| Legendary | 100 |

### Marketplace Tax

10% of every marketplace sale is removed from the economy. The buyer pays full price, the seller receives 90%.

- Fish listed at 100 Shells: buyer pays 100, seller receives 90, 10 Shells destroyed
- Fish listed at 50 Shells: buyer pays 50, seller receives 45, 5 Shells destroyed
- Minimum tax: 1 Shell (even on a 1-Shell listing)

## Player Decision Matrix

When a player has a fish they don't want to keep, they have three options:

| Action | Shells Earned | XP Earned | Edition | Best For |
|--------|--------------|-----------|---------|----------|
| Release | 0 | 5-100 | Returns to pool | XP grinding, helping the community |
| Quick-Sell | 5-100 | 0 | Gone forever | Quick cash, don't care about pool |
| List on Market | Potentially much more | 0 | Transfers to buyer | Maximum profit, fish survives |

The marketplace is the economically optimal choice for valuable fish -- a rare fish might sell for 200+ Shells on the market vs. 25 from quick-sell, and the edition survives.

## XP and Leveling

XP is earned from catching and releasing fish. It is not tied to Shells in any way.

| Level | XP Threshold |
|-------|-------------|
| 1 | 0 |
| 2 | 100 |
| 3 | 300 |
| 4 | 600 |
| 5 | 1,000 |
| 6 | 1,500 |
| 7 | 2,200 |
| 8 | 3,000 |
| 9 | 4,000 |
| 10 | 5,500 |

## Self-Balancing Properties

The economy has built-in feedback loops:

1. **Catch income prevents pool pressure.** Since catching itself earns Shells, players don't need to quick-sell to afford marketplace purchases. This dramatically reduces the rate of edition destruction.

2. **Marketplace tax scales with activity.** More trading means more Shells removed. If the economy inflates (too many Shells), marketplace prices rise, which means more tax per transaction, which removes more Shells.

3. **Scarcity drives marketplace value.** As editions get scarcer (from quick-sells), remaining fish become more valuable on the marketplace, incentivizing listing over quick-selling.

4. **Quick-sell has diminishing appeal.** The quick-sell premium (3-25 Shells above catch reward) becomes less relevant as players accumulate wealth from catches and marketplace trading.

## Edition Pool Sizes (MVP)

| Species | Rarity | Edition Size |
|---------|--------|-------------|
| Perch | Common | 1,000 |
| Carp | Common | 800 |
| Chub | Common | 600 |
| Brook Trout | Uncommon | 400 |
| Moonbass | Uncommon | 300 |
| Catfish | Uncommon | 250 |
| Ice Trout | Rare | 150 |
| Night Eel | Rare | 100 |
| Cichlid | Rare | 150 |
| Obsidian Pufferfish | Epic | 30 |
| Golden Primeval Perch | Legendary | 10 |
| Unifish | Legendary | 10 |
| Old Shoe | Legendary | 2 |

Total editions across all species: 3,802

Quick-selling removes editions permanently. Releasing returns them. The marketplace transfers them without destroying them.

## Tuning Knobs

If the economy needs adjustment, these are the levers:

| Knob | File | Effect |
|------|------|--------|
| Catch Shell rewards | `backend/internal/game/economy.go` (`catchShells`) | More = faster earning, less pressure to quick-sell |
| Quick-sell prices | `backend/internal/game/economy.go` (`sellPrice`) | Lower = less incentive to destroy fish |
| Market tax rate | `backend/internal/game/economy.go` (`MarketTaxRate`) | Higher = stronger Shells sink |
| Catch XP rewards | `backend/internal/game/xp.go` (`catchXP`) | Affects leveling speed |
| Release XP rewards | `backend/internal/game/xp.go` (`releaseXP`) | Higher = more incentive to return editions |
| Level thresholds | `backend/internal/game/xp.go` (`levelThresholds`) | Steeper = slower progression |
| Edition sizes | `backend/migrations/002_seed_species.sql` | Larger = more headroom before depletion |
| Price limits | `backend/internal/market/handler.go` (price validation) | Currently 1-99,999 |

## Future Considerations

These are not implemented but could help if the economy needs more sinks or sources:

- **Consumable lures** -- buy lures that boost rare fish chance for N casts (Shells sink)
- **Zone unlock fees** -- pay Shells to access new fishing zones (Shells sink)
- **Cosmetics** -- rods, bobbers, card frames purchasable with Shells (Shells sink)
- **Daily catch bonus** -- double XP/Shells on first catch of the day (engagement + income smoothing)
- **Edition respawn timer** -- quick-sold editions regenerate after N days (pool recovery, use with caution as it undermines scarcity)
