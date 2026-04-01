package player

import (
	"database/sql"
	"encoding/json"
	"net/http"
	"strconv"

	"github.com/tacklefish/backend/internal/auth"
	"github.com/tacklefish/backend/internal/game"
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
	err := h.DB.QueryRow(`SELECT COUNT(*) FROM fish_instances WHERE owner_id = ? AND sold_at IS NULL`, claims.PlayerID).Scan(&total)
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
		WHERE fi.owner_id = ? AND fi.sold_at IS NULL
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
		WHERE fi.id = ? AND fi.owner_id = ? AND fi.sold_at IS NULL
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

type releaseResponse struct {
	Released bool `json:"released"`
	XPEarned int  `json:"xp_earned"`
	TotalXP  int  `json:"total_xp"`
	Level    int  `json:"level"`
}

func (h *Handler) Release(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	idStr := r.PathValue("id")
	fishID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, `{"error":"invalid fish id"}`, http.StatusBadRequest)
		return
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	// Verify ownership and get rarity.
	var rarity string
	err = tx.QueryRow(`
		SELECT fs.rarity
		FROM fish_instances fi
		JOIN fish_species fs ON fs.id = fi.species_id
		WHERE fi.id = ? AND fi.owner_id = ? AND fi.sold_at IS NULL
	`, fishID, claims.PlayerID).Scan(&rarity)
	if err == sql.ErrNoRows {
		http.Error(w, `{"error":"fish not found"}`, http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Delete the fish instance.
	if _, err := tx.Exec(`DELETE FROM fish_instances WHERE id = ?`, fishID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Award XP and update release counter.
	xpEarned := game.XPForRelease(rarity)
	if _, err := tx.Exec(`UPDATE players SET xp = xp + ?, total_released = total_released + 1 WHERE id = ?`,
		xpEarned, claims.PlayerID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Read back the new XP total.
	var totalXP int
	if err := tx.QueryRow(`SELECT xp FROM players WHERE id = ?`, claims.PlayerID).Scan(&totalXP); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(releaseResponse{
		Released: true,
		XPEarned: xpEarned,
		TotalXP:  totalXP,
		Level:    game.LevelFromXP(totalXP),
	})
}

type sellResponse struct {
	Sold        bool `json:"sold"`
	ShellsEarned int  `json:"shells_earned"`
	TotalShells  int  `json:"total_shells"`
}

type profileResponse struct {
	PlayerID          int64  `json:"player_id"`
	XP                int    `json:"xp"`
	Level             int    `json:"level"`
	XPNextLevel       int    `json:"xp_next_level"`
	Shells            int    `json:"shells"`
	TotalCaught       int    `json:"total_caught"`
	TotalReleased     int    `json:"total_released"`
	CurrentCollection int    `json:"current_collection"`
	CreatedAt         string `json:"created_at"`
}

func (h *Handler) Profile(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var p profileResponse
	err := h.DB.QueryRow(`
		SELECT id, xp, shells, total_caught, total_released, created_at
		FROM players WHERE id = ?
	`, claims.PlayerID).Scan(&p.PlayerID, &p.XP, &p.Shells, &p.TotalCaught, &p.TotalReleased, &p.CreatedAt)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	err = h.DB.QueryRow(`SELECT COUNT(*) FROM fish_instances WHERE owner_id = ? AND sold_at IS NULL`,
		claims.PlayerID).Scan(&p.CurrentCollection)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	p.Level = game.LevelFromXP(p.XP)
	p.XPNextLevel = game.XPForNextLevel(p.Level)

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(p)
}

func (h *Handler) Sell(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	idStr := r.PathValue("id")
	fishID, err := strconv.ParseInt(idStr, 10, 64)
	if err != nil {
		http.Error(w, `{"error":"invalid fish id"}`, http.StatusBadRequest)
		return
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	// Verify ownership, not already sold, and get rarity.
	var rarity string
	err = tx.QueryRow(`
		SELECT fs.rarity
		FROM fish_instances fi
		JOIN fish_species fs ON fs.id = fi.species_id
		WHERE fi.id = ? AND fi.owner_id = ? AND fi.sold_at IS NULL
	`, fishID, claims.PlayerID).Scan(&rarity)
	if err == sql.ErrNoRows {
		http.Error(w, `{"error":"fish not found"}`, http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Soft-delete: mark as sold (edition stays consumed).
	if _, err := tx.Exec(`UPDATE fish_instances SET sold_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?`, fishID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Award shells.
	shellsEarned := game.SellPrice(rarity)
	if _, err := tx.Exec(`UPDATE players SET shells = shells + ? WHERE id = ?`,
		shellsEarned, claims.PlayerID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	var totalShells int
	if err := tx.QueryRow(`SELECT shells FROM players WHERE id = ?`, claims.PlayerID).Scan(&totalShells); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(sellResponse{
		Sold:         true,
		ShellsEarned: shellsEarned,
		TotalShells:  totalShells,
	})
}
