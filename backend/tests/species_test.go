package tests

import (
	"testing"

	"github.com/tacklefish/backend/internal/fish"
)

func TestRarityWeightsAtZero(t *testing.T) {
	w := fish.RarityWeights(0.0)

	tests := []struct {
		rarity fish.Rarity
		want   float64
	}{
		{fish.Common, 80},
		{fish.Uncommon, 15},
		{fish.Rare, 4},
		{fish.Epic, 1},
		{fish.Legendary, 0},
	}

	for _, tt := range tests {
		if got := w[tt.rarity]; got != tt.want {
			t.Errorf("RarityWeights(0)[%s] = %f, want %f", tt.rarity, got, tt.want)
		}
	}
}

func TestRarityWeightsAtOne(t *testing.T) {
	w := fish.RarityWeights(1.0)

	tests := []struct {
		rarity fish.Rarity
		want   float64
	}{
		{fish.Common, 40},
		{fish.Uncommon, 30},
		{fish.Rare, 18},
		{fish.Epic, 8},
		{fish.Legendary, 4},
	}

	for _, tt := range tests {
		if got := w[tt.rarity]; got != tt.want {
			t.Errorf("RarityWeights(1)[%s] = %f, want %f", tt.rarity, got, tt.want)
		}
	}
}

func TestRarityWeightsClamping(t *testing.T) {
	below := fish.RarityWeights(-0.5)
	atZero := fish.RarityWeights(0.0)
	rarities := []fish.Rarity{fish.Common, fish.Uncommon, fish.Rare, fish.Epic, fish.Legendary}

	for _, r := range rarities {
		if below[r] != atZero[r] {
			t.Errorf("RarityWeights(-0.5)[%s] = %f, want %f (same as 0)", r, below[r], atZero[r])
		}
	}

	above := fish.RarityWeights(1.5)
	atOne := fish.RarityWeights(1.0)
	for _, r := range rarities {
		if above[r] != atOne[r] {
			t.Errorf("RarityWeights(1.5)[%s] = %f, want %f (same as 1)", r, above[r], atOne[r])
		}
	}
}

func TestRarityWeightsMonotonicity(t *testing.T) {
	low := fish.RarityWeights(0.0)
	high := fish.RarityWeights(1.0)

	if high[fish.Common] >= low[fish.Common] {
		t.Error("Common weight should decrease with higher timing score")
	}
	if high[fish.Rare] <= low[fish.Rare] {
		t.Error("Rare weight should increase with higher timing score")
	}
	if high[fish.Legendary] <= low[fish.Legendary] {
		t.Error("Legendary weight should increase with higher timing score")
	}
}
