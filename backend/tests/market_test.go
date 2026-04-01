package tests

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/tacklefish/backend/internal/fish"
	"github.com/tacklefish/backend/internal/market"
	"github.com/tacklefish/backend/internal/player"
)

// --- CreateListing ---

func TestCreateListingSuccess(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Market Fish", fish.Rare, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings", `{"fish_id":1,"price":50}`, 1)
	w := httptest.NewRecorder()
	handler.CreateListing(w, req)

	if w.Code != http.StatusCreated {
		t.Fatalf("status = %d, want 201; body = %s", w.Code, w.Body.String())
	}

	var resp struct {
		ListingID int64 `json:"listing_id"`
		FishID    int64 `json:"fish_id"`
		Price     int   `json:"price"`
	}
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.ListingID == 0 {
		t.Error("expected non-zero listing_id")
	}
	if resp.FishID != fishID {
		t.Errorf("fish_id = %d, want %d", resp.FishID, fishID)
	}
	if resp.Price != 50 {
		t.Errorf("price = %d, want 50", resp.Price)
	}

	// Fish should have listing_id set.
	var listingID *int64
	db.QueryRow(`SELECT listing_id FROM fish_instances WHERE id = ?`, fishID).Scan(&listingID)
	if listingID == nil || *listingID != resp.ListingID {
		t.Error("expected listing_id to be set on fish_instances")
	}
}

func TestCreateListingInvalidPrice(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Price Fish", fish.Common, 100)
	catchFishForPlayer(t, db, speciesID, 1, 1)

	handler := &market.Handler{DB: db}

	for _, price := range []string{`{"fish_id":1,"price":0}`, `{"fish_id":1,"price":100000}`} {
		req := requestWithClaims("POST", "/market/listings", price, 1)
		w := httptest.NewRecorder()
		handler.CreateListing(w, req)
		if w.Code != http.StatusBadRequest {
			t.Errorf("price %s: status = %d, want 400", price, w.Code)
		}
	}
}

func TestCreateListingNotOwned(t *testing.T) {
	db := setupMemoryDB(t)
	seedPlayer(t, db, "player2", 0)
	speciesID := seedSpecies(t, db, "Not Mine", fish.Common, 100)
	catchFishForPlayer(t, db, speciesID, 1, 1) // owned by player 1

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings", `{"fish_id":1,"price":10}`, 2)
	w := httptest.NewRecorder()
	handler.CreateListing(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404", w.Code)
	}
}

func TestCreateListingAlreadyListed(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Double List", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 25)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings", `{"fish_id":1,"price":30}`, 1)
	w := httptest.NewRecorder()
	handler.CreateListing(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (already listed)", w.Code)
	}
}

func TestCreateListingAlreadySold(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Sold Fish", fish.Common, 100)
	catchFishForPlayer(t, db, speciesID, 1, 1)
	db.Exec(`UPDATE fish_instances SET sold_at = '2026-01-01T00:00:00Z' WHERE id = 1`)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings", `{"fish_id":1,"price":10}`, 1)
	w := httptest.NewRecorder()
	handler.CreateListing(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (already sold)", w.Code)
	}
}

// --- BrowseListings ---

func TestBrowseListingsExcludesOwn(t *testing.T) {
	db := setupMemoryDB(t)
	player2 := seedPlayer(t, db, "player2", 100)
	speciesID := seedSpecies(t, db, "Browse Fish", fish.Common, 100)

	// Player 1 lists a fish.
	fish1 := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fish1, 1, 20)

	// Player 2 lists a fish.
	fish2 := catchFishForPlayer(t, db, speciesID, 2, player2)
	createListing(t, db, fish2, player2, 30)

	handler := &market.Handler{DB: db}

	// Browse as player 1 -- should only see player 2's listing.
	req := requestWithClaims("GET", "/market/listings", "", 1)
	w := httptest.NewRecorder()
	handler.BrowseListings(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}

	var resp struct {
		Listings []struct {
			SellerID int64 `json:"seller_id"`
		} `json:"listings"`
		Total int `json:"total"`
	}
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.Total != 1 {
		t.Errorf("total = %d, want 1", resp.Total)
	}
	if len(resp.Listings) == 1 && resp.Listings[0].SellerID == 1 {
		t.Error("browse should exclude own listings")
	}
}

func TestBrowseListingsExcludesSoldAndCancelled(t *testing.T) {
	db := setupMemoryDB(t)
	player2 := seedPlayer(t, db, "player2", 100)
	speciesID := seedSpecies(t, db, "Filter Fish", fish.Common, 100)

	// Active listing.
	fish1 := catchFishForPlayer(t, db, speciesID, 1, player2)
	createListing(t, db, fish1, player2, 20)

	// Sold listing.
	fish2 := catchFishForPlayer(t, db, speciesID, 2, player2)
	lid2 := createListing(t, db, fish2, player2, 30)
	db.Exec(`UPDATE market_listings SET sold_at = '2026-01-01T00:00:00Z' WHERE id = ?`, lid2)

	// Cancelled listing.
	fish3 := catchFishForPlayer(t, db, speciesID, 3, player2)
	lid3 := createListing(t, db, fish3, player2, 40)
	db.Exec(`UPDATE market_listings SET cancelled_at = '2026-01-01T00:00:00Z' WHERE id = ?`, lid3)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("GET", "/market/listings", "", 1)
	w := httptest.NewRecorder()
	handler.BrowseListings(w, req)

	var resp struct {
		Total int `json:"total"`
	}
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.Total != 1 {
		t.Errorf("total = %d, want 1 (only active listing)", resp.Total)
	}
}

func TestBrowseListingsRarityFilter(t *testing.T) {
	db := setupMemoryDB(t)
	player2 := seedPlayer(t, db, "player2", 0)
	commonID := seedSpecies(t, db, "Common Fish", fish.Common, 100)
	rareID := seedSpecies(t, db, "Rare Fish", fish.Rare, 100)

	fish1 := catchFishForPlayer(t, db, commonID, 1, player2)
	createListing(t, db, fish1, player2, 10)
	fish2 := catchFishForPlayer(t, db, rareID, 1, player2)
	createListing(t, db, fish2, player2, 50)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("GET", "/market/listings?rarity=rare", "", 1)
	w := httptest.NewRecorder()
	handler.BrowseListings(w, req)

	var resp struct {
		Total int `json:"total"`
	}
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.Total != 1 {
		t.Errorf("total = %d, want 1 (rare only)", resp.Total)
	}
}

// --- BuyListing ---

func TestBuyListingSuccess(t *testing.T) {
	db := setupMemoryDB(t)
	// Player 1 (seller) has a fish. Player 2 (buyer) has shells.
	db.Exec(`UPDATE players SET shells = 0 WHERE id = 1`) // seller starts with 0
	player2 := seedPlayer(t, db, "buyer", 100)

	speciesID := seedSpecies(t, db, "Buy Fish", fish.Rare, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	listingID := createListing(t, db, fishID, 1, 50)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings/1/buy", "", player2)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.BuyListing(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body = %s", w.Code, w.Body.String())
	}

	var resp struct {
		Bought          bool `json:"bought"`
		ShellsSpent     int  `json:"shells_spent"`
		RemainingShells int  `json:"remaining_shells"`
	}
	json.NewDecoder(w.Body).Decode(&resp)
	if !resp.Bought {
		t.Error("expected bought=true")
	}
	if resp.ShellsSpent != 50 {
		t.Errorf("shells_spent = %d, want 50", resp.ShellsSpent)
	}
	if resp.RemainingShells != 50 {
		t.Errorf("remaining_shells = %d, want 50", resp.RemainingShells)
	}

	// Fish should now be owned by player 2 with no listing_id.
	var ownerID int64
	var lid *int64
	db.QueryRow(`SELECT owner_id, listing_id FROM fish_instances WHERE id = ?`, fishID).Scan(&ownerID, &lid)
	if ownerID != player2 {
		t.Errorf("owner_id = %d, want %d", ownerID, player2)
	}
	if lid != nil {
		t.Error("listing_id should be NULL after purchase")
	}

	// Seller should have received shells.
	var sellerShells int
	db.QueryRow(`SELECT shells FROM players WHERE id = 1`).Scan(&sellerShells)
	if sellerShells != 50 {
		t.Errorf("seller shells = %d, want 50", sellerShells)
	}

	// Listing should be marked sold.
	var soldAt *string
	db.QueryRow(`SELECT sold_at FROM market_listings WHERE id = ?`, listingID).Scan(&soldAt)
	if soldAt == nil {
		t.Error("listing sold_at should be set")
	}
}

func TestBuyListingInsufficientShells(t *testing.T) {
	db := setupMemoryDB(t)
	player2 := seedPlayer(t, db, "poor-buyer", 10) // only 10 shells

	speciesID := seedSpecies(t, db, "Expensive Fish", fish.Epic, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 50)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings/1/buy", "", player2)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.BuyListing(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400 (insufficient shells)", w.Code)
	}
}

func TestBuyOwnListing(t *testing.T) {
	db := setupMemoryDB(t)
	db.Exec(`UPDATE players SET shells = 100 WHERE id = 1`)

	speciesID := seedSpecies(t, db, "Own Fish", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 10)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings/1/buy", "", 1)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.BuyListing(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400 (can't buy own)", w.Code)
	}
}

func TestBuyAlreadySoldListing(t *testing.T) {
	db := setupMemoryDB(t)
	player2 := seedPlayer(t, db, "buyer", 100)

	speciesID := seedSpecies(t, db, "Gone Fish", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 10)
	db.Exec(`UPDATE market_listings SET sold_at = '2026-01-01T00:00:00Z' WHERE id = 1`)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings/1/buy", "", player2)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.BuyListing(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (already sold)", w.Code)
	}
}

// --- EditPrice ---

func TestEditPriceSuccess(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Edit Fish", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 20)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("PATCH", "/market/listings/1/price", `{"price":75}`, 1)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.EditPrice(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body = %s", w.Code, w.Body.String())
	}

	var resp struct {
		Price int `json:"price"`
	}
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.Price != 75 {
		t.Errorf("price = %d, want 75", resp.Price)
	}
}

func TestEditPriceNotOwner(t *testing.T) {
	db := setupMemoryDB(t)
	seedPlayer(t, db, "player2", 0)
	speciesID := seedSpecies(t, db, "Not My Listing", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 20)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("PATCH", "/market/listings/1/price", `{"price":50}`, 2)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.EditPrice(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (not owner)", w.Code)
	}
}

// --- CancelListing ---

func TestCancelListingSuccess(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Cancel Fish", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 20)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings/1/cancel", "", 1)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.CancelListing(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body = %s", w.Code, w.Body.String())
	}

	// Fish should be unlocked (listing_id = NULL).
	var lid *int64
	db.QueryRow(`SELECT listing_id FROM fish_instances WHERE id = ?`, fishID).Scan(&lid)
	if lid != nil {
		t.Error("listing_id should be NULL after cancel")
	}

	// Listing should have cancelled_at.
	var cancelledAt *string
	db.QueryRow(`SELECT cancelled_at FROM market_listings WHERE id = 1`).Scan(&cancelledAt)
	if cancelledAt == nil {
		t.Error("cancelled_at should be set")
	}
}

func TestCancelListingNotOwner(t *testing.T) {
	db := setupMemoryDB(t)
	seedPlayer(t, db, "player2", 0)
	speciesID := seedSpecies(t, db, "Not My Cancel", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 20)

	handler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings/1/cancel", "", 2)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.CancelListing(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (not owner)", w.Code)
	}
}

// --- Integration: listed fish excluded from inventory ---

func TestListedFishExcludedFromInventory(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Listed Fish", fish.Common, 100)
	catchFishForPlayer(t, db, speciesID, 1, 1)
	catchFishForPlayer(t, db, speciesID, 2, 1)

	// List fish 1.
	createListing(t, db, 1, 1, 25)

	handler := &player.Handler{DB: db}
	req := requestWithClaims("GET", "/player/inventory", "", 1)
	w := httptest.NewRecorder()
	handler.Inventory(w, req)

	var resp struct {
		Total int `json:"total"`
	}
	json.NewDecoder(w.Body).Decode(&resp)
	if resp.Total != 1 {
		t.Errorf("total = %d, want 1 (listed fish excluded)", resp.Total)
	}
}

func TestCannotReleaseListedFish(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Listed Release", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 25)

	handler := &player.Handler{DB: db}
	req := requestWithClaims("POST", "/player/inventory/1/release", "", 1)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.Release(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (fish is listed)", w.Code)
	}
}

func TestCannotQuickSellListedFish(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Listed Sell", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 25)

	handler := &player.Handler{DB: db}
	req := requestWithClaims("POST", "/player/inventory/1/sell", "", 1)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.Sell(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (fish is listed)", w.Code)
	}
}

func TestCancelledFishBackInInventory(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Cancel Return", fish.Common, 100)
	fishID := catchFishForPlayer(t, db, speciesID, 1, 1)
	createListing(t, db, fishID, 1, 25)

	// Cancel.
	marketHandler := &market.Handler{DB: db}
	req := requestWithClaims("POST", "/market/listings/1/cancel", "", 1)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	marketHandler.CancelListing(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("cancel: status = %d, want 200", w.Code)
	}

	// Should be back in inventory.
	playerHandler := &player.Handler{DB: db}
	req2 := requestWithClaims("GET", "/player/inventory", "", 1)
	w2 := httptest.NewRecorder()
	playerHandler.Inventory(w2, req2)

	var resp struct {
		Total int `json:"total"`
	}
	json.NewDecoder(w2.Body).Decode(&resp)
	if resp.Total != 1 {
		t.Errorf("total = %d, want 1 (fish returned after cancel)", resp.Total)
	}
}
