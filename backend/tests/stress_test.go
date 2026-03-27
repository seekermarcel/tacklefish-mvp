package tests

import (
	"sync"
	"testing"

	"github.com/tacklefish/backend/internal/fish"
)

// TestStressPoolDepletion simulates 100 concurrent players depleting a fish pool of 200.
// Verifies no duplicate edition numbers and all numbers are assigned exactly once.
func TestStressPoolDepletion(t *testing.T) {
	db := setupFileDB(t)

	const editionSize = 200
	const numWorkers = 100

	speciesID := seedSpecies(t, db, "Stress Fish", fish.Common, editionSize)

	type result struct {
		editionNum int
		err        error
	}

	results := make(chan result, editionSize*2)
	var wg sync.WaitGroup

	for w := 0; w < numWorkers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				num, err := fish.AssignEditionNumber(db, speciesID, editionSize)
				if err != nil {
					results <- result{err: err}
					return
				}

				_, insertErr := db.Exec(
					`INSERT INTO fish_instances (species_id, owner_id, edition_number, size_variant, color_variant) VALUES (?, 1, ?, 'normal', 'normal')`,
					speciesID, num,
				)
				if insertErr != nil {
					continue // Race condition on same number, retry.
				}

				results <- result{editionNum: num}
			}
		}()
	}

	wg.Wait()
	close(results)

	seen := make(map[int]int)
	catches := 0
	exhausted := 0

	for r := range results {
		if r.err != nil {
			exhausted++
			continue
		}
		seen[r.editionNum]++
		catches++
	}

	for num, count := range seen {
		if count > 1 {
			t.Errorf("edition number %d was assigned %d times", num, count)
		}
	}

	if catches != editionSize {
		t.Errorf("expected %d total catches, got %d", editionSize, catches)
	}

	for i := 1; i <= editionSize; i++ {
		if seen[i] == 0 {
			t.Errorf("edition number %d was never assigned", i)
		}
	}

	pool, err := fish.PoolStatus(db, 1)
	if err != nil {
		t.Fatal("pool status:", err)
	}
	for _, s := range pool {
		if s.ID == speciesID && s.Remaining != 0 {
			t.Errorf("expected 0 remaining, got %d", s.Remaining)
		}
	}

	t.Logf("Stress test complete: %d catches, %d pool-exhausted exits, %d unique numbers",
		catches, exhausted, len(seen))
}

// TestStressMultiSpeciesDepletion tests concurrent catching across 3 species.
func TestStressMultiSpeciesDepletion(t *testing.T) {
	db := setupFileDB(t)

	type speciesDef struct {
		name        string
		rarity      fish.Rarity
		editionSize int
		id          int64
	}

	species := []speciesDef{
		{"Stress Common", fish.Common, 50, 0},
		{"Stress Rare", fish.Rare, 20, 0},
		{"Stress Epic", fish.Epic, 10, 0},
	}

	for i := range species {
		species[i].id = seedSpecies(t, db, species[i].name, species[i].rarity, species[i].editionSize)
	}

	const numWorkers = 50
	var wg sync.WaitGroup

	type catchResult struct {
		speciesIdx int
		editionNum int
	}

	results := make(chan catchResult, 200)

	for w := 0; w < numWorkers; w++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for {
				caught := false
				for i, s := range species {
					num, err := fish.AssignEditionNumber(db, s.id, s.editionSize)
					if err != nil {
						continue
					}

					_, insertErr := db.Exec(
						`INSERT INTO fish_instances (species_id, owner_id, edition_number, size_variant, color_variant) VALUES (?, 1, ?, 'normal', 'normal')`,
						s.id, num,
					)
					if insertErr != nil {
						continue
					}

					results <- catchResult{speciesIdx: i, editionNum: num}
					caught = true
					break
				}
				if !caught {
					return
				}
			}
		}()
	}

	wg.Wait()
	close(results)

	perSpecies := make([]map[int]bool, len(species))
	for i := range perSpecies {
		perSpecies[i] = make(map[int]bool)
	}

	for r := range results {
		if perSpecies[r.speciesIdx][r.editionNum] {
			t.Errorf("duplicate: species %q, edition %d", species[r.speciesIdx].name, r.editionNum)
		}
		perSpecies[r.speciesIdx][r.editionNum] = true
	}

	totalCatches := 0
	for i, s := range species {
		count := len(perSpecies[i])
		totalCatches += count
		t.Logf("Species %q: %d/%d caught", s.name, count, s.editionSize)

		if count != s.editionSize {
			t.Errorf("species %q: expected %d catches, got %d", s.name, s.editionSize, count)
		}
	}

	t.Logf("Total: %d catches across %d species", totalCatches, len(species))
}
