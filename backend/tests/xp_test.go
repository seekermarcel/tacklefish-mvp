package tests

import (
	"testing"

	"github.com/tacklefish/backend/internal/game"
)

func TestXPForCatch(t *testing.T) {
	tests := []struct {
		rarity string
		want   int
	}{
		{"common", 10},
		{"uncommon", 20},
		{"rare", 50},
		{"epic", 100},
		{"legendary", 250},
		{"unknown", 0},
	}
	for _, tt := range tests {
		t.Run(tt.rarity, func(t *testing.T) {
			got := game.XPForCatch(tt.rarity)
			if got != tt.want {
				t.Errorf("XPForCatch(%q) = %d, want %d", tt.rarity, got, tt.want)
			}
		})
	}
}

func TestXPForRelease(t *testing.T) {
	tests := []struct {
		rarity string
		want   int
	}{
		{"common", 5},
		{"uncommon", 10},
		{"rare", 25},
		{"epic", 50},
		{"legendary", 100},
		{"unknown", 0},
	}
	for _, tt := range tests {
		t.Run(tt.rarity, func(t *testing.T) {
			got := game.XPForRelease(tt.rarity)
			if got != tt.want {
				t.Errorf("XPForRelease(%q) = %d, want %d", tt.rarity, got, tt.want)
			}
		})
	}
}

func TestLevelFromXP(t *testing.T) {
	tests := []struct {
		xp   int
		want int
	}{
		{0, 1},
		{50, 1},
		{99, 1},
		{100, 2},
		{299, 2},
		{300, 3},
		{600, 4},
		{1000, 5},
		{5500, 10},
		{99999, 10},
	}
	for _, tt := range tests {
		got := game.LevelFromXP(tt.xp)
		if got != tt.want {
			t.Errorf("LevelFromXP(%d) = %d, want %d", tt.xp, got, tt.want)
		}
	}
}

func TestXPForNextLevel(t *testing.T) {
	tests := []struct {
		level int
		want  int
	}{
		{1, 100},
		{2, 300},
		{9, 5500},
		{10, -1}, // max level
	}
	for _, tt := range tests {
		got := game.XPForNextLevel(tt.level)
		if got != tt.want {
			t.Errorf("XPForNextLevel(%d) = %d, want %d", tt.level, got, tt.want)
		}
	}
}

func TestShellsForCatch(t *testing.T) {
	tests := []struct {
		rarity string
		want   int
	}{
		{"common", 2},
		{"uncommon", 5},
		{"rare", 12},
		{"epic", 30},
		{"legendary", 75},
		{"unknown", 0},
	}
	for _, tt := range tests {
		t.Run(tt.rarity, func(t *testing.T) {
			got := game.ShellsForCatch(tt.rarity)
			if got != tt.want {
				t.Errorf("ShellsForCatch(%q) = %d, want %d", tt.rarity, got, tt.want)
			}
		})
	}
}

func TestMarketTax(t *testing.T) {
	tests := []struct {
		price      int
		wantTax    int
		wantPayout int
	}{
		{100, 10, 90},
		{50, 5, 45},
		{10, 1, 9},
		{5, 1, 4},     // minimum tax of 1
		{1, 1, 0},     // minimum tax of 1, seller gets 0
		{1000, 100, 900},
	}
	for _, tt := range tests {
		tax, payout := game.MarketTax(tt.price)
		if tax != tt.wantTax || payout != tt.wantPayout {
			t.Errorf("MarketTax(%d) = (%d, %d), want (%d, %d)", tt.price, tax, payout, tt.wantTax, tt.wantPayout)
		}
	}
}

func TestSellPrice(t *testing.T) {
	tests := []struct {
		rarity string
		want   int
	}{
		{"common", 5},
		{"uncommon", 10},
		{"rare", 25},
		{"epic", 50},
		{"legendary", 100},
		{"unknown", 0},
	}
	for _, tt := range tests {
		t.Run(tt.rarity, func(t *testing.T) {
			got := game.SellPrice(tt.rarity)
			if got != tt.want {
				t.Errorf("SellPrice(%q) = %d, want %d", tt.rarity, got, tt.want)
			}
		})
	}
}
