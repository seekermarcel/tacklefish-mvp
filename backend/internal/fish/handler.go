package fish

import (
	"database/sql"
	"encoding/json"
	"math/rand/v2"
	"net/http"

	"github.com/tacklefish/backend/internal/auth"
)

type Handler struct {
	DB *sql.DB
}

type catchRequest struct {
	TimingScore float64 `json:"timing_score"`
}

type CaughtFish struct {
	ID            int64        `json:"id"`
	Species       string       `json:"species"`
	Rarity        Rarity       `json:"rarity"`
	EditionNumber int          `json:"edition_number"`
	EditionSize   int          `json:"edition_size"`
	SizeVariant   SizeVariant  `json:"size_variant"`
	ColorVariant  ColorVariant `json:"color_variant"`
}

func (h *Handler) Catch(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var req catchRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.TimingScore < 0 || req.TimingScore > 1 {
		http.Error(w, `{"error":"timing_score must be between 0 and 1"}`, http.StatusBadRequest)
		return
	}

	// Roll rarity based on timing score.
	rarity := rollRarity(req.TimingScore)

	// Pick a species of that rarity with copies remaining.
	// If none left, fall back to more common tiers.
	species, err := pickWithFallback(h.DB, rarity, 1)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	if species == nil {
		w.Header().Set("Content-Type", "application/json")
		w.WriteHeader(http.StatusOK)
		json.NewEncoder(w).Encode(map[string]string{"result": "miss", "reason": "all fish depleted"})
		return
	}

	// Assign a random edition number.
	editionNum, err := AssignEditionNumber(h.DB, species.ID, species.EditionSize)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Roll traits.
	size := RollSize()
	color := RollColor()

	// Persist the catch.
	result, err := h.DB.Exec(`
		INSERT INTO fish_instances (species_id, owner_id, edition_number, size_variant, color_variant)
		VALUES (?, ?, ?, ?, ?)
	`, species.ID, claims.PlayerID, editionNum, string(size), string(color))
	if err != nil {
		http.Error(w, `{"error":"failed to save catch"}`, http.StatusInternalServerError)
		return
	}

	fishID, _ := result.LastInsertId()

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(CaughtFish{
		ID:            fishID,
		Species:       species.Name,
		Rarity:        species.Rarity,
		EditionNumber: editionNum,
		EditionSize:   species.EditionSize,
		SizeVariant:   size,
		ColorVariant:  color,
	})
}

func (h *Handler) Pool(w http.ResponseWriter, r *http.Request) {
	pool, err := PoolStatus(h.DB, 1) // MVP: zone 1 only
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(pool)
}

// rollRarity picks a rarity tier using weighted random selection.
func rollRarity(timingScore float64) Rarity {
	weights := RarityWeights(timingScore)
	total := 0.0
	for _, w := range weights {
		total += w
	}

	roll := rand.Float64() * total
	cumulative := 0.0

	// Order matters: check from rarest to most common.
	order := []Rarity{Legendary, Epic, Rare, Uncommon, Common}
	for _, r := range order {
		cumulative += weights[r]
		if roll < cumulative {
			return r
		}
	}
	return Common
}

// pickWithFallback tries the target rarity, then falls back to more common tiers.
func pickWithFallback(db *sql.DB, target Rarity, zone int) (*SpeciesInfo, error) {
	fallbackOrder := []Rarity{Legendary, Epic, Rare, Uncommon, Common}

	// Find the index of the target rarity and try from there downward (more common).
	startIdx := 0
	for i, r := range fallbackOrder {
		if r == target {
			startIdx = i
			break
		}
	}

	for i := startIdx; i < len(fallbackOrder); i++ {
		species, err := PickSpecies(db, fallbackOrder[i], zone)
		if err != nil {
			return nil, err
		}
		if species != nil {
			return species, nil
		}
	}

	return nil, nil // everything depleted
}
