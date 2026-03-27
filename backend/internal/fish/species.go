package fish

// Rarity tiers and their base drop weights.
// Timing score shifts the distribution toward rarer tiers.
type Rarity string

const (
	Common    Rarity = "common"
	Uncommon  Rarity = "uncommon"
	Rare      Rarity = "rare"
	Epic      Rarity = "epic"
	Legendary Rarity = "legendary"
)

// RarityWeights returns drop weights for each rarity tier
// adjusted by timing score (0.0 = worst, 1.0 = perfect).
//
// Base weights (score=0): common 80, uncommon 15, rare 4, epic 1, legendary 0
// Perfect weights (score=1): common 40, uncommon 30, rare 18, epic 8, legendary 4
func RarityWeights(timingScore float64) map[Rarity]float64 {
	t := clamp(timingScore, 0, 1)
	return map[Rarity]float64{
		Common:    lerp(80, 40, t),
		Uncommon:  lerp(15, 30, t),
		Rare:      lerp(4, 18, t),
		Epic:      lerp(1, 8, t),
		Legendary: lerp(0, 4, t),
	}
}

func lerp(a, b, t float64) float64 {
	return a + (b-a)*t
}

func clamp(v, lo, hi float64) float64 {
	if v < lo {
		return lo
	}
	if v > hi {
		return hi
	}
	return v
}
