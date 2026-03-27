package tests

import (
	"bytes"
	"context"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/tacklefish/backend/internal/auth"
	"github.com/tacklefish/backend/internal/fish"
	"github.com/tacklefish/backend/internal/player"
)

// requestWithClaims creates an HTTP request with auth claims injected into context.
func requestWithClaims(method, path string, body string, playerID int64) *http.Request {
	var req *http.Request
	if body != "" {
		req = httptest.NewRequest(method, path, bytes.NewBufferString(body))
	} else {
		req = httptest.NewRequest(method, path, nil)
	}
	claims := &auth.Claims{PlayerID: playerID, DeviceID: "test"}
	ctx := context.WithValue(req.Context(), auth.ClaimsKey, claims)
	return req.WithContext(ctx)
}

func TestCatchHandlerSuccess(t *testing.T) {
	db := setupMemoryDB(t)
	seedAllMVPSpecies(t, db)

	handler := &fish.Handler{DB: db}

	req := requestWithClaims("POST", "/fish/catch", `{"timing_score":0.5}`, 1)
	w := httptest.NewRecorder()
	handler.Catch(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body = %s", w.Code, w.Body.String())
	}

	var caught fish.CaughtFish
	if err := json.NewDecoder(w.Body).Decode(&caught); err != nil {
		t.Fatal("decode:", err)
	}
	if caught.ID == 0 {
		t.Error("expected non-zero fish ID")
	}
	if caught.Species == "" {
		t.Error("expected non-empty species")
	}
	if caught.EditionNumber < 1 {
		t.Error("expected positive edition number")
	}
}

func TestCatchHandlerInvalidTimingScore(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &fish.Handler{DB: db}

	tests := []struct {
		name string
		body string
	}{
		{"too low", `{"timing_score":-0.1}`},
		{"too high", `{"timing_score":1.5}`},
		{"invalid json", `not json`},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			req := requestWithClaims("POST", "/fish/catch", tt.body, 1)
			w := httptest.NewRecorder()
			handler.Catch(w, req)

			if w.Code != http.StatusBadRequest {
				t.Errorf("status = %d, want 400", w.Code)
			}
		})
	}
}

func TestCatchHandlerNoClaims(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &fish.Handler{DB: db}

	req := httptest.NewRequest("POST", "/fish/catch", bytes.NewBufferString(`{"timing_score":0.5}`))
	w := httptest.NewRecorder()
	handler.Catch(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", w.Code)
	}
}

func TestCatchHandlerPoolDepleted(t *testing.T) {
	db := setupMemoryDB(t)

	// Create a species with edition size 1.
	speciesID := seedSpecies(t, db, "One Fish", fish.Common, 1)

	// Catch the only one.
	catchFish(t, db, speciesID, 1)

	handler := &fish.Handler{DB: db}
	req := requestWithClaims("POST", "/fish/catch", `{"timing_score":0.5}`, 1)
	w := httptest.NewRecorder()
	handler.Catch(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}

	var resp map[string]string
	json.NewDecoder(w.Body).Decode(&resp)
	if resp["result"] != "miss" {
		t.Errorf("expected miss result, got %v", resp)
	}
}

func TestPoolHandler(t *testing.T) {
	db := setupMemoryDB(t)
	seedAllMVPSpecies(t, db)

	handler := &fish.Handler{DB: db}

	req := requestWithClaims("GET", "/fish/pool", "", 1)
	w := httptest.NewRecorder()
	handler.Pool(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}

	var pool []fish.SpeciesInfo
	if err := json.NewDecoder(w.Body).Decode(&pool); err != nil {
		t.Fatal("decode:", err)
	}
	if len(pool) != 10 {
		t.Errorf("expected 10 species, got %d", len(pool))
	}

	// Check first species has full pool.
	for _, s := range pool {
		if s.Remaining != s.EditionSize {
			t.Errorf("species %q: remaining %d != edition_size %d", s.Name, s.Remaining, s.EditionSize)
		}
	}
}

func TestInventoryHandler(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Inv Fish", fish.Common, 100)

	// Catch 3 fish for player 1.
	catchFish(t, db, speciesID, 1)
	catchFish(t, db, speciesID, 2)
	catchFish(t, db, speciesID, 3)

	handler := &player.Handler{DB: db}

	req := requestWithClaims("GET", "/player/inventory?limit=10&offset=0", "", 1)
	w := httptest.NewRecorder()
	handler.Inventory(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body = %s", w.Code, w.Body.String())
	}

	var resp struct {
		Fish   []player.FishSummary `json:"fish"`
		Total  int                  `json:"total"`
		Offset int                  `json:"offset"`
		Limit  int                  `json:"limit"`
	}
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatal("decode:", err)
	}
	if resp.Total != 3 {
		t.Errorf("total = %d, want 3", resp.Total)
	}
	if len(resp.Fish) != 3 {
		t.Errorf("fish count = %d, want 3", len(resp.Fish))
	}
	if resp.Limit != 10 {
		t.Errorf("limit = %d, want 10", resp.Limit)
	}
}

func TestInventoryHandlerPagination(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Page Fish", fish.Common, 100)

	for i := 1; i <= 5; i++ {
		catchFish(t, db, speciesID, i)
	}

	handler := &player.Handler{DB: db}

	req := requestWithClaims("GET", "/player/inventory?limit=2&offset=0", "", 1)
	w := httptest.NewRecorder()
	handler.Inventory(w, req)

	var resp struct {
		Fish  []player.FishSummary `json:"fish"`
		Total int                  `json:"total"`
	}
	json.NewDecoder(w.Body).Decode(&resp)

	if resp.Total != 5 {
		t.Errorf("total = %d, want 5", resp.Total)
	}
	if len(resp.Fish) != 2 {
		t.Errorf("page size = %d, want 2", len(resp.Fish))
	}
}

func TestInventoryHandlerEmpty(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &player.Handler{DB: db}

	req := requestWithClaims("GET", "/player/inventory", "", 1)
	w := httptest.NewRecorder()
	handler.Inventory(w, req)

	var resp struct {
		Fish []player.FishSummary `json:"fish"`
	}
	json.NewDecoder(w.Body).Decode(&resp)

	if resp.Fish == nil {
		t.Error("fish should be empty array, not null")
	}
	if len(resp.Fish) != 0 {
		t.Errorf("fish count = %d, want 0", len(resp.Fish))
	}
}

func TestFishDetailHandler(t *testing.T) {
	db := setupMemoryDB(t)
	speciesID := seedSpecies(t, db, "Detail Fish", fish.Rare, 100)
	catchFish(t, db, speciesID, 42)

	handler := &player.Handler{DB: db}

	req := requestWithClaims("GET", "/player/inventory/1", "", 1)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.FishDetail(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body = %s", w.Code, w.Body.String())
	}

	var f player.FishSummary
	json.NewDecoder(w.Body).Decode(&f)
	if f.Species != "Detail Fish" {
		t.Errorf("species = %q, want %q", f.Species, "Detail Fish")
	}
	if f.EditionNumber != 42 {
		t.Errorf("edition_number = %d, want 42", f.EditionNumber)
	}
}

func TestFishDetailHandlerNotFound(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &player.Handler{DB: db}

	req := requestWithClaims("GET", "/player/inventory/999", "", 1)
	req.SetPathValue("id", "999")
	w := httptest.NewRecorder()
	handler.FishDetail(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404", w.Code)
	}
}

func TestFishDetailHandlerWrongOwner(t *testing.T) {
	db := setupMemoryDB(t)

	// Add a second player.
	db.Exec(`INSERT INTO players (device_id) VALUES ('other-player')`)

	speciesID := seedSpecies(t, db, "Owned Fish", fish.Common, 100)
	catchFish(t, db, speciesID, 1) // Owned by player 1.

	handler := &player.Handler{DB: db}

	// Request as player 2.
	req := requestWithClaims("GET", "/player/inventory/1", "", 2)
	req.SetPathValue("id", "1")
	w := httptest.NewRecorder()
	handler.FishDetail(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404 (wrong owner)", w.Code)
	}
}

func TestFishDetailHandlerInvalidID(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &player.Handler{DB: db}

	req := requestWithClaims("GET", "/player/inventory/abc", "", 1)
	req.SetPathValue("id", "abc")
	w := httptest.NewRecorder()
	handler.FishDetail(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", w.Code)
	}
}
