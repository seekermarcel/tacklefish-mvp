package player

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/tacklefish/backend/internal/auth"
)

type Handler struct {
	DB *sql.DB
}

type FishSummary struct {
	ID            int64  `json:"id"`
	Species       string `json:"species"`
	Rarity        string `json:"rarity"`
	EditionNumber int    `json:"edition_number"`
	EditionSize   int    `json:"edition_size"`
	SizeVariant   string `json:"size_variant"`
	ColorVariant  string `json:"color_variant"`
	CaughtAt      string `json:"caught_at"`
}

type inventoryResponse struct {
	Fish   []FishSummary `json:"fish"`
	Total  int           `json:"total"`
	Offset int           `json:"offset"`
	Limit  int           `json:"limit"`
}

func (h *Handler) Inventory(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	offset, _ := strconv.Atoi(r.URL.Query().Get("offset"))
	limit, _ := strconv.Atoi(r.URL.Query().Get("limit"))
	if limit <= 0 || limit > 100 {
		limit = 20
	}
	if offset < 0 {
		offset = 0
	}

	// Get total count.
	var total int
	err := h.DB.QueryRow(`SELECT COUNT(*) FROM fish_instances WHERE owner_id = ?`, claims.PlayerID).Scan(&total)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Get paginated fish.
	rows, err := h.DB.Query(`
		SELECT
			fi.id, fs.name, fs.rarity, fi.edition_number, fs.edition_size,
			fi.size_variant, fi.color_variant, fi.caught_at
		FROM fish_instances fi
		JOIN fish_species fs ON fs.id = fi.species_id
		WHERE fi.owner_id = ?
		ORDER BY fi.caught_at DESC
		LIMIT ? OFFSET ?
	`, claims.PlayerID, limit, offset)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	fish := make([]FishSummary, 0)
	for rows.Next() {
		var f FishSummary
		if err := rows.Scan(&f.ID, &f.Species, &f.Rarity, &f.EditionNumber, &f.EditionSize, &f.SizeVariant, &f.ColorVariant, &f.CaughtAt); err != nil {
			http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
			return
		}
		fish = append(fish, f)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(inventoryResponse{
		Fish:   fish,
		Total:  total,
		Offset: offset,
		Limit:  limit,
	})
}

func (h *Handler) FishDetail(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	// Extract fish ID from path: /player/inventory/{id}
	idStr := r.PathValue("id")
	fishID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, `{"error":"invalid fish id"}`, http.StatusBadRequest)
		return
	}

	var f FishSummary
	err = h.DB.QueryRow(`
		SELECT
			fi.id, fs.name, fs.rarity, fi.edition_number, fs.edition_size,
			fi.size_variant, fi.color_variant, fi.caught_at
		FROM fish_instances fi
		JOIN fish_species fs ON fs.id = fi.species_id
		WHERE fi.id = ? AND fi.owner_id = ?
	`, fishID, claims.PlayerID).Scan(&f.ID, &f.Species, &f.Rarity, &f.EditionNumber, &f.EditionSize, &f.SizeVariant, &f.ColorVariant, &f.CaughtAt)
	if err == sql.ErrNoRows {
		http.Error(w, `{"error":"fish not found"}`, http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(f)
}
