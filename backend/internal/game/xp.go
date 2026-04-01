package game

var catchXP = map[string]int{
	"common":    10,
	"uncommon":  20,
	"rare":      50,
	"epic":      100,
	"legendary": 250,
}

var releaseXP = map[string]int{
	"common":    5,
	"uncommon":  10,
	"rare":      25,
	"epic":      50,
	"legendary": 100,
}

var levelThresholds = []int{0, 100, 300, 600, 1000, 1500, 2200, 3000, 4000, 5500}

// XPForCatch returns the XP awarded for catching a fish of the given rarity.
func XPForCatch(rarity string) int {
	return catchXP[rarity]
}

// XPForRelease returns the XP awarded for releasing a fish of the given rarity.
func XPForRelease(rarity string) int {
	return releaseXP[rarity]
}

// LevelFromXP returns the player level for a given XP total.
func LevelFromXP(xp int) int {
	level := 1
	for i, threshold := range levelThresholds {
		if xp >= threshold {
			level = i + 1
		}
	}
	return level
}

// XPForNextLevel returns the XP threshold for the next level.
// Returns -1 if the player is at max level.
func XPForNextLevel(level int) int {
	if level >= len(levelThresholds) {
		return -1
	}
	return levelThresholds[level]
}
