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
