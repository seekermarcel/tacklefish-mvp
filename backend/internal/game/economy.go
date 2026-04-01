package game

var catchShells = map[string]int{
	"common":    2,
	"uncommon":  5,
	"rare":      12,
	"epic":      30,
	"legendary": 75,
}

var sellPrice = map[string]int{
	"common":    5,
	"uncommon":  10,
	"rare":      25,
	"epic":      50,
	"legendary": 100,
}

// MarketTaxRate is the fraction of the sale price removed from the economy.
const MarketTaxRate = 0.10

// ShellsForCatch returns the shells awarded for catching a fish of the given rarity.
func ShellsForCatch(rarity string) int {
	return catchShells[rarity]
}

// SellPrice returns the shell reward for quick-selling a fish of the given rarity.
func SellPrice(rarity string) int {
	return sellPrice[rarity]
}

// MarketTax returns the tax amount and the seller payout for a given sale price.
func MarketTax(price int) (tax int, sellerPayout int) {
	tax = int(float64(price) * MarketTaxRate)
	if tax < 1 && price > 0 {
		tax = 1
	}
	sellerPayout = price - tax
	return
}
