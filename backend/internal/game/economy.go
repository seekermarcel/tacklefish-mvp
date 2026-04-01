package game

var sellPrice = map[string]int{
	"common":    5,
	"uncommon":  10,
	"rare":      25,
	"epic":      50,
	"legendary": 100,
}

// SellPrice returns the shell reward for selling a fish of the given rarity.
func SellPrice(rarity string) int {
	return sellPrice[rarity]
}
