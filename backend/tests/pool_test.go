package tests

import (
	"testing"

	"github.com/tacklefish/backend/internal/fish"
)

func TestPoolStatus(t *testing.T) {
	db := setupMemoryDB(t)

	speciesID := seedSpecies(t, db, "Test Perch", fish.Common, 100)

	pool, err := fish.PoolStatus(db, 1)
	if err != nil {
		t.Fatal("pool status:", err)
	}
	if len(pool) != 1 {
		t.Fatalf("expected 1 species, got %d", len(pool))
	}
	if pool[0].Remaining != 100 {
		t.Errorf("expected 100 remaining, got %d", pool[0].Remaining)
	}

	catchFish(t, db, speciesID, 1)
	catchFish(t, db, speciesID, 2)
	catchFish(t, db, speciesID, 3)

	pool, err = fish.PoolStatus(db, 1)
	if err != nil {
		t.Fatal("pool status after catch:", err)
	}
	if pool[0].Remaining != 97 {
		t.Errorf("expected 97 remaining, got %d", pool[0].Remaining)
	}
}

func TestPickSpeciesReturnsNilWhenDepleted(t *testing.T) {
	db := setupMemoryDB(t)

	speciesID := seedSpecies(t, db, "Tiny Fish", fish.Common, 2)

	catchFish(t, db, speciesID, 1)
	catchFish(t, db, speciesID, 2)

	species, err := fish.PickSpecies(db, fish.Common, 1)
	if err != nil {
		t.Fatal("pick species:", err)
	}
	if species != nil {
		t.Errorf("expected nil (depleted), got %+v", species)
	}
}

func TestAssignEditionNumber(t *testing.T) {
	db := setupMemoryDB(t)

	speciesID := seedSpecies(t, db, "Numbered Fish", fish.Common, 5)

	seen := make(map[int]bool)
	for i := 0; i < 5; i++ {
		num, err := fish.AssignEditionNumber(db, speciesID, 5)
		if err != nil {
			t.Fatal("assign edition:", err)
		}
		if num < 1 || num > 5 {
			t.Errorf("edition number %d out of range [1, 5]", num)
		}
		if seen[num] {
			t.Errorf("duplicate edition number: %d", num)
		}
		seen[num] = true
		catchFish(t, db, speciesID, num)
	}

	if len(seen) != 5 {
		t.Errorf("expected 5 unique numbers, got %d", len(seen))
	}

	_, err := fish.AssignEditionNumber(db, speciesID, 5)
	if err == nil {
		t.Error("expected error when pool is exhausted")
	}
}

func TestAssignEditionNumberRange(t *testing.T) {
	db := setupMemoryDB(t)

	speciesID := seedSpecies(t, db, "Range Fish", fish.Common, 1000)

	for i := 0; i < 100; i++ {
		num, err := fish.AssignEditionNumber(db, speciesID, 1000)
		if err != nil {
			t.Fatal("assign edition:", err)
		}
		if num < 1 || num > 1000 {
			t.Fatalf("edition number %d out of range [1, 1000]", num)
		}
		catchFish(t, db, speciesID, num)
	}
}
