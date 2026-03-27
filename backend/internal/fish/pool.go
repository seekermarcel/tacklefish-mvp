package fish

import (
	"database/sql"
	"fmt"
	"math/rand/v2"
)

type SpeciesInfo struct {
	ID          int64  `json:"id"`
	Name        string `json:"name"`
	Rarity      Rarity `json:"rarity"`
	EditionSize int    `json:"edition_size"`
	Remaining   int    `json:"remaining"`
}

// PoolStatus returns remaining edition counts for all species in a zone.
func PoolStatus(db *sql.DB, zone int) ([]SpeciesInfo, error) {
	rows, err := db.Query(`
		SELECT
			fs.id, fs.name, fs.rarity, fs.edition_size,
			fs.edition_size - COUNT(fi.id) AS remaining
		FROM fish_species fs
		LEFT JOIN fish_instances fi ON fi.species_id = fs.id
		WHERE fs.zone = ?
		GROUP BY fs.id
		ORDER BY fs.id
	`, zone)
	if err != nil {
		return nil, fmt.Errorf("query pool: %w", err)
	}
	defer rows.Close()

	var species []SpeciesInfo
	for rows.Next() {
		var s SpeciesInfo
		if err := rows.Scan(&s.ID, &s.Name, &s.Rarity, &s.EditionSize, &s.Remaining); err != nil {
			return nil, fmt.Errorf("scan pool: %w", err)
		}
		species = append(species, s)
	}
	return species, rows.Err()
}

// PickSpecies selects a random species of the given rarity that still has copies left.
func PickSpecies(db *sql.DB, rarity Rarity, zone int) (*SpeciesInfo, error) {
	rows, err := db.Query(`
		SELECT
			fs.id, fs.name, fs.rarity, fs.edition_size,
			fs.edition_size - COUNT(fi.id) AS remaining
		FROM fish_species fs
		LEFT JOIN fish_instances fi ON fi.species_id = fs.id
		WHERE fs.rarity = ? AND fs.zone = ?
		GROUP BY fs.id
		HAVING remaining > 0
	`, string(rarity), zone)
	if err != nil {
		return nil, fmt.Errorf("query species: %w", err)
	}
	defer rows.Close()

	var candidates []SpeciesInfo
	for rows.Next() {
		var s SpeciesInfo
		if err := rows.Scan(&s.ID, &s.Name, &s.Rarity, &s.EditionSize, &s.Remaining); err != nil {
			return nil, fmt.Errorf("scan species: %w", err)
		}
		candidates = append(candidates, s)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	if len(candidates) == 0 {
		return nil, nil // no copies left for this rarity
	}

	pick := candidates[rand.IntN(len(candidates))]
	return &pick, nil
}

// AssignEditionNumber picks a random unused edition number for a species.
func AssignEditionNumber(db *sql.DB, speciesID int64, editionSize int) (int, error) {
	// Get all taken numbers for this species.
	rows, err := db.Query(`SELECT edition_number FROM fish_instances WHERE species_id = ?`, speciesID)
	if err != nil {
		return 0, fmt.Errorf("query taken numbers: %w", err)
	}
	defer rows.Close()

	taken := make(map[int]bool)
	for rows.Next() {
		var n int
		if err := rows.Scan(&n); err != nil {
			return 0, fmt.Errorf("scan number: %w", err)
		}
		taken[n] = true
	}
	if err := rows.Err(); err != nil {
		return 0, err
	}

	// Build pool of available numbers.
	available := make([]int, 0, editionSize-len(taken))
	for i := 1; i <= editionSize; i++ {
		if !taken[i] {
			available = append(available, i)
		}
	}

	if len(available) == 0 {
		return 0, fmt.Errorf("no edition numbers left for species %d", speciesID)
	}

	return available[rand.IntN(len(available))], nil
}
