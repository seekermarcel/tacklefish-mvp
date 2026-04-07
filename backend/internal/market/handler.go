package market

import (
	"database/sql"
	"encoding/json"
	"fmt"
	"net/http"
	"strconv"

	"github.com/tacklefish/backend/internal/auth"
	"github.com/tacklefish/backend/internal/game"
)

type Handler struct {
	DB *sql.DB
}

type createRequest struct {
	FishID int64 `json:"fish_id"`
	Price  int   `json:"price"`
}

type createResponse struct {
	ListingID int64 `json:"listing_id"`
	FishID    int64 `json:"fish_id"`
	Price     int   `json:"price"`
}

type fishInfo struct {
	ID            int64  `json:"id"`
	Species       string `json:"species"`
	Rarity        string `json:"rarity"`
	EditionNumber int    `json:"edition_number"`
	EditionSize   int    `json:"edition_size"`
	SizeVariant   string `json:"size_variant"`
	ColorVariant  string `json:"color_variant"`
}

type listingItem struct {
	ListingID int64    `json:"listing_id"`
	Price     int      `json:"price"`
	SellerID  int64    `json:"seller_id"`
	CreatedAt string   `json:"created_at"`
	Fish      fishInfo `json:"fish"`
}

type browseResponse struct {
	Listings []listingItem `json:"listings"`
	Total    int           `json:"total"`
	Offset   int           `json:"offset"`
	Limit    int           `json:"limit"`
}

type buyResponse struct {
	Bought          bool     `json:"bought"`
	ShellsSpent     int      `json:"shells_spent"`
	RemainingShells int      `json:"remaining_shells"`
	Fish            fishInfo `json:"fish"`
}

func (h *Handler) CreateListing(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var req createRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}
	if req.Price < 1 || req.Price > 99999 {
		http.Error(w, `{"error":"price must be between 1 and 99999"}`, http.StatusBadRequest)
		return
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	// Verify fish ownership and availability.
	var fishID int64
	err = tx.QueryRow(`
		SELECT fi.id FROM fish_instances fi
		WHERE fi.id = ? AND fi.owner_id = ? AND fi.sold_at IS NULL AND fi.listing_id IS NULL
	`, req.FishID, claims.PlayerID).Scan(&fishID)
	if err == sql.ErrNoRows {
		http.Error(w, `{"error":"fish not found or already listed"}`, http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Create the listing.
	result, err := tx.Exec(`INSERT INTO market_listings (fish_id, seller_id, price) VALUES (?, ?, ?)`,
		req.FishID, claims.PlayerID, req.Price)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	listingID, _ := result.LastInsertId()

	// Lock the fish.
	if _, err := tx.Exec(`UPDATE fish_instances SET listing_id = ? WHERE id = ?`, listingID, req.FishID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusCreated)
	json.NewEncoder(w).Encode(createResponse{
		ListingID: listingID,
		FishID:    req.FishID,
		Price:     req.Price,
	})
}

func (h *Handler) BrowseListings(w http.ResponseWriter, r *http.Request) {
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

	rarity := r.URL.Query().Get("rarity")
	sort := r.URL.Query().Get("sort")

	// Build WHERE clause.
	where := `ml.sold_at IS NULL AND ml.cancelled_at IS NULL AND ml.seller_id != ?`
	args := []any{claims.PlayerID}

	if rarity != "" {
		where += ` AND fs.rarity = ?`
		args = append(args, rarity)
	}

	// Count total.
	var total int
	countQuery := fmt.Sprintf(`
		SELECT COUNT(*)
		FROM market_listings ml
		JOIN fish_instances fi ON fi.id = ml.fish_id
		JOIN fish_species fs ON fs.id = fi.species_id
		WHERE %s
	`, where)
	if err := h.DB.QueryRow(countQuery, args...).Scan(&total); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Sort order.
	orderBy := "ml.created_at DESC"
	switch sort {
	case "price_asc":
		orderBy = "ml.price ASC, ml.created_at DESC"
	case "price_desc":
		orderBy = "ml.price DESC, ml.created_at DESC"
	}

	selectQuery := fmt.Sprintf(`
		SELECT
			ml.id, ml.price, ml.seller_id, ml.created_at,
			fi.id, fs.name, fs.rarity, fi.edition_number, fs.edition_size,
			fi.size_variant, fi.color_variant
		FROM market_listings ml
		JOIN fish_instances fi ON fi.id = ml.fish_id
		JOIN fish_species fs ON fs.id = fi.species_id
		WHERE %s
		ORDER BY %s
		LIMIT ? OFFSET ?
	`, where, orderBy)
	args = append(args, limit, offset)

	rows, err := h.DB.Query(selectQuery, args...)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	listings := make([]listingItem, 0)
	for rows.Next() {
		var l listingItem
		if err := rows.Scan(
			&l.ListingID, &l.Price, &l.SellerID, &l.CreatedAt,
			&l.Fish.ID, &l.Fish.Species, &l.Fish.Rarity, &l.Fish.EditionNumber, &l.Fish.EditionSize,
			&l.Fish.SizeVariant, &l.Fish.ColorVariant,
		); err != nil {
			http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
			return
		}
		listings = append(listings, l)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(browseResponse{
		Listings: listings,
		Total:    total,
		Offset:   offset,
		Limit:    limit,
	})
}

func (h *Handler) MyListings(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	rows, err := h.DB.Query(`
		SELECT
			ml.id, ml.price, ml.seller_id, ml.created_at,
			fi.id, fs.name, fs.rarity, fi.edition_number, fs.edition_size,
			fi.size_variant, fi.color_variant
		FROM market_listings ml
		JOIN fish_instances fi ON fi.id = ml.fish_id
		JOIN fish_species fs ON fs.id = fi.species_id
		WHERE ml.seller_id = ? AND ml.sold_at IS NULL AND ml.cancelled_at IS NULL
		ORDER BY ml.created_at DESC
	`, claims.PlayerID)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	listings := make([]listingItem, 0)
	for rows.Next() {
		var l listingItem
		if err := rows.Scan(
			&l.ListingID, &l.Price, &l.SellerID, &l.CreatedAt,
			&l.Fish.ID, &l.Fish.Species, &l.Fish.Rarity, &l.Fish.EditionNumber, &l.Fish.EditionSize,
			&l.Fish.SizeVariant, &l.Fish.ColorVariant,
		); err != nil {
			http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
			return
		}
		listings = append(listings, l)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"listings": listings})
}

func (h *Handler) BuyListing(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	listingID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.Error(w, `{"error":"invalid listing id"}`, http.StatusBadRequest)
		return
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	// Load listing.
	var fishID, sellerID int64
	var price int
	err = tx.QueryRow(`
		SELECT fish_id, seller_id, price FROM market_listings
		WHERE id = ? AND sold_at IS NULL AND cancelled_at IS NULL
	`, listingID).Scan(&fishID, &sellerID, &price)
	if err == sql.ErrNoRows {
		http.Error(w, `{"error":"listing not found"}`, http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Can't buy your own listing.
	if sellerID == claims.PlayerID {
		http.Error(w, `{"error":"cannot buy your own listing"}`, http.StatusBadRequest)
		return
	}

	// Check buyer has enough shells.
	var buyerShells int
	tx.QueryRow(`SELECT shells FROM players WHERE id = ?`, claims.PlayerID).Scan(&buyerShells)
	if buyerShells < price {
		http.Error(w, `{"error":"insufficient shells"}`, http.StatusBadRequest)
		return
	}

	// Calculate tax.
	tax, sellerPayout := game.MarketTax(price)

	// Deduct full price from buyer.
	if _, err := tx.Exec(`UPDATE players SET shells = shells - ? WHERE id = ?`, price, claims.PlayerID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Credit seller (price minus tax). Tax is removed from the economy.
	_ = tax // tax Shells vanish — intentional sink
	if _, err := tx.Exec(`UPDATE players SET shells = shells + ? WHERE id = ?`, sellerPayout, sellerID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Transfer fish ownership and unlock from listing.
	if _, err := tx.Exec(`UPDATE fish_instances SET owner_id = ?, listing_id = NULL WHERE id = ?`,
		claims.PlayerID, fishID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Mark listing as sold.
	if _, err := tx.Exec(`UPDATE market_listings SET sold_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now'), buyer_id = ? WHERE id = ?`,
		claims.PlayerID, listingID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Read fish info for response.
	var f fishInfo
	tx.QueryRow(`
		SELECT fi.id, fs.name, fs.rarity, fi.edition_number, fs.edition_size, fi.size_variant, fi.color_variant
		FROM fish_instances fi JOIN fish_species fs ON fs.id = fi.species_id
		WHERE fi.id = ?
	`, fishID).Scan(&f.ID, &f.Species, &f.Rarity, &f.EditionNumber, &f.EditionSize, &f.SizeVariant, &f.ColorVariant)

	var remainingShells int
	tx.QueryRow(`SELECT shells FROM players WHERE id = ?`, claims.PlayerID).Scan(&remainingShells)

	if err := tx.Commit(); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(buyResponse{
		Bought:          true,
		ShellsSpent:     price,
		RemainingShells: remainingShells,
		Fish:            f,
	})
}

func (h *Handler) EditPrice(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	listingID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.Error(w, `{"error":"invalid listing id"}`, http.StatusBadRequest)
		return
	}

	var req struct {
		Price int `json:"price"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}
	if req.Price < 1 || req.Price > 99999 {
		http.Error(w, `{"error":"price must be between 1 and 99999"}`, http.StatusBadRequest)
		return
	}

	result, err := h.DB.Exec(`
		UPDATE market_listings SET price = ?
		WHERE id = ? AND seller_id = ? AND sold_at IS NULL AND cancelled_at IS NULL
	`, req.Price, listingID, claims.PlayerID)
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	rows, _ := result.RowsAffected()
	if rows == 0 {
		http.Error(w, `{"error":"listing not found"}`, http.StatusNotFound)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{"listing_id": listingID, "price": req.Price})
}

func (h *Handler) CancelListing(w http.ResponseWriter, r *http.Request) {
	claims := auth.GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	listingID, err := strconv.ParseInt(r.PathValue("id"), 10, 64)
	if err != nil {
		http.Error(w, `{"error":"invalid listing id"}`, http.StatusBadRequest)
		return
	}

	tx, err := h.DB.Begin()
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	defer tx.Rollback()

	// Verify ownership and active status.
	var fishID int64
	err = tx.QueryRow(`
		SELECT fish_id FROM market_listings
		WHERE id = ? AND seller_id = ? AND sold_at IS NULL AND cancelled_at IS NULL
	`, listingID, claims.PlayerID).Scan(&fishID)
	if err == sql.ErrNoRows {
		http.Error(w, `{"error":"listing not found"}`, http.StatusNotFound)
		return
	}
	if err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	// Cancel and unlock fish.
	if _, err := tx.Exec(`UPDATE market_listings SET cancelled_at = strftime('%Y-%m-%dT%H:%M:%SZ', 'now') WHERE id = ?`, listingID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}
	if _, err := tx.Exec(`UPDATE fish_instances SET listing_id = NULL WHERE id = ?`, fishID); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	if err := tx.Commit(); err != nil {
		http.Error(w, `{"error":"internal server error"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]bool{"cancelled": true})
}
