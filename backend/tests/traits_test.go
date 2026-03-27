package tests

import (
	"testing"

	"github.com/tacklefish/backend/internal/fish"
)

func TestRollSizeReturnsValidVariants(t *testing.T) {
	valid := map[fish.SizeVariant]bool{
		fish.SizeMini: true, fish.SizeNormal: true, fish.SizeLarge: true, fish.SizeGiant: true,
	}

	for i := 0; i < 1000; i++ {
		s := fish.RollSize()
		if !valid[s] {
			t.Fatalf("RollSize() returned invalid variant: %q", s)
		}
	}
}

func TestRollColorReturnsValidVariants(t *testing.T) {
	valid := map[fish.ColorVariant]bool{
		fish.ColorNormal: true, fish.ColorAlbino: true, fish.ColorMelanistic: true,
		fish.ColorRainbow: true, fish.ColorNeon: true,
	}

	for i := 0; i < 1000; i++ {
		c := fish.RollColor()
		if !valid[c] {
			t.Fatalf("RollColor() returned invalid variant: %q", c)
		}
	}
}

func TestRollSizeDistribution(t *testing.T) {
	counts := map[fish.SizeVariant]int{}
	n := 100_000

	for i := 0; i < n; i++ {
		counts[fish.RollSize()]++
	}

	if counts[fish.SizeNormal] < n/2 {
		t.Errorf("Normal size should be most common, got %d/%d", counts[fish.SizeNormal], n)
	}
	if counts[fish.SizeGiant] > n/10 {
		t.Errorf("Giant size should be rare, got %d/%d", counts[fish.SizeGiant], n)
	}
}

func TestRollColorDistribution(t *testing.T) {
	counts := map[fish.ColorVariant]int{}
	n := 100_000

	for i := 0; i < n; i++ {
		counts[fish.RollColor()]++
	}

	if counts[fish.ColorNormal] < n/2 {
		t.Errorf("Normal color should be most common, got %d/%d", counts[fish.ColorNormal], n)
	}
	if counts[fish.ColorNeon] > n/10 {
		t.Errorf("Neon color should be rare, got %d/%d", counts[fish.ColorNeon], n)
	}
}
