package tests

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"

	"github.com/tacklefish/backend/internal/auth"
)

const testSecret = "test-secret-key"

func TestGenerateAndValidateToken(t *testing.T) {
	token, err := auth.GenerateToken(testSecret, 42, "device-abc")
	if err != nil {
		t.Fatal("generate token:", err)
	}

	claims, err := auth.ValidateToken(testSecret, token)
	if err != nil {
		t.Fatal("validate token:", err)
	}

	if claims.PlayerID != 42 {
		t.Errorf("player_id = %d, want 42", claims.PlayerID)
	}
	if claims.DeviceID != "device-abc" {
		t.Errorf("device_id = %q, want %q", claims.DeviceID, "device-abc")
	}
}

func TestValidateTokenWrongSecret(t *testing.T) {
	token, err := auth.GenerateToken(testSecret, 1, "device")
	if err != nil {
		t.Fatal(err)
	}

	_, err = auth.ValidateToken("wrong-secret", token)
	if err == nil {
		t.Error("expected error for wrong secret")
	}
}

func TestValidateTokenGarbage(t *testing.T) {
	_, err := auth.ValidateToken(testSecret, "not-a-jwt")
	if err == nil {
		t.Error("expected error for garbage token")
	}
}

func TestRegisterHandler(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	body := `{"device_id":"test-device-register"}`
	req := httptest.NewRequest("POST", "/auth/register", bytes.NewBufferString(body))
	w := httptest.NewRecorder()

	handler.Register(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body = %s", w.Code, w.Body.String())
	}

	var resp struct {
		Token    string `json:"token"`
		PlayerID int64  `json:"player_id"`
	}
	if err := json.NewDecoder(w.Body).Decode(&resp); err != nil {
		t.Fatal("decode response:", err)
	}
	if resp.Token == "" {
		t.Error("expected non-empty token")
	}
	if resp.PlayerID == 0 {
		t.Error("expected non-zero player_id")
	}

	// Register again with same device_id -- should return same player_id.
	req2 := httptest.NewRequest("POST", "/auth/register", bytes.NewBufferString(body))
	w2 := httptest.NewRecorder()
	handler.Register(w2, req2)

	var resp2 struct {
		PlayerID int64 `json:"player_id"`
	}
	json.NewDecoder(w2.Body).Decode(&resp2)
	if resp2.PlayerID != resp.PlayerID {
		t.Errorf("re-register player_id = %d, want %d", resp2.PlayerID, resp.PlayerID)
	}
}

func TestRegisterHandlerEmptyDeviceID(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	req := httptest.NewRequest("POST", "/auth/register", bytes.NewBufferString(`{"device_id":""}`))
	w := httptest.NewRecorder()
	handler.Register(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", w.Code)
	}
}

func TestRegisterHandlerInvalidJSON(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	req := httptest.NewRequest("POST", "/auth/register", bytes.NewBufferString(`not json`))
	w := httptest.NewRecorder()
	handler.Register(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", w.Code)
	}
}

func TestRefreshHandler(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	// Register first.
	regReq := httptest.NewRequest("POST", "/auth/register", bytes.NewBufferString(`{"device_id":"refresh-test"}`))
	regW := httptest.NewRecorder()
	handler.Register(regW, regReq)

	// Refresh.
	refreshReq := httptest.NewRequest("POST", "/auth/refresh", bytes.NewBufferString(`{"device_id":"refresh-test"}`))
	refreshW := httptest.NewRecorder()
	handler.Refresh(refreshW, refreshReq)

	if refreshW.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", refreshW.Code)
	}

	var resp struct {
		Token string `json:"token"`
	}
	json.NewDecoder(refreshW.Body).Decode(&resp)
	if resp.Token == "" {
		t.Error("expected non-empty token")
	}
}

func TestRefreshHandlerUnknownDevice(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	req := httptest.NewRequest("POST", "/auth/refresh", bytes.NewBufferString(`{"device_id":"unknown"}`))
	w := httptest.NewRecorder()
	handler.Refresh(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", w.Code)
	}
}

func TestMiddleware(t *testing.T) {
	token, _ := auth.GenerateToken(testSecret, 1, "device")

	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		claims := auth.GetClaims(r)
		if claims == nil {
			t.Error("expected claims in context")
			return
		}
		if claims.PlayerID != 1 {
			t.Errorf("player_id = %d, want 1", claims.PlayerID)
		}
		w.WriteHeader(http.StatusOK)
	})

	handler := auth.Middleware(testSecret)(inner)

	// Valid token.
	req := httptest.NewRequest("GET", "/test", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	w := httptest.NewRecorder()
	handler.ServeHTTP(w, req)
	if w.Code != http.StatusOK {
		t.Errorf("valid token: status = %d, want 200", w.Code)
	}

	// Missing header.
	req2 := httptest.NewRequest("GET", "/test", nil)
	w2 := httptest.NewRecorder()
	handler.ServeHTTP(w2, req2)
	if w2.Code != http.StatusUnauthorized {
		t.Errorf("missing header: status = %d, want 401", w2.Code)
	}

	// Bad format (no "Bearer " prefix).
	req3 := httptest.NewRequest("GET", "/test", nil)
	req3.Header.Set("Authorization", token)
	w3 := httptest.NewRecorder()
	handler.ServeHTTP(w3, req3)
	if w3.Code != http.StatusUnauthorized {
		t.Errorf("bad format: status = %d, want 401", w3.Code)
	}

	// Invalid token.
	req4 := httptest.NewRequest("GET", "/test", nil)
	req4.Header.Set("Authorization", "Bearer garbage")
	w4 := httptest.NewRecorder()
	handler.ServeHTTP(w4, req4)
	if w4.Code != http.StatusUnauthorized {
		t.Errorf("invalid token: status = %d, want 401", w4.Code)
	}
}

func TestRateLimitMiddleware(t *testing.T) {
	token, _ := auth.GenerateToken(testSecret, 99, "rate-test")

	inner := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.WriteHeader(http.StatusOK)
	})

	// Chain: auth middleware -> rate limit -> handler.
	rateLimited := auth.RateLimitMiddleware(100 * time.Millisecond)(inner)
	handler := auth.Middleware(testSecret)(rateLimited)

	// First request should pass.
	req1 := httptest.NewRequest("POST", "/fish/catch", nil)
	req1.Header.Set("Authorization", "Bearer "+token)
	w1 := httptest.NewRecorder()
	handler.ServeHTTP(w1, req1)
	if w1.Code != http.StatusOK {
		t.Errorf("first request: status = %d, want 200", w1.Code)
	}

	// Second request immediately should be rate limited.
	req2 := httptest.NewRequest("POST", "/fish/catch", nil)
	req2.Header.Set("Authorization", "Bearer "+token)
	w2 := httptest.NewRecorder()
	handler.ServeHTTP(w2, req2)
	if w2.Code != http.StatusTooManyRequests {
		t.Errorf("rate limited: status = %d, want 429", w2.Code)
	}
	if w2.Header().Get("Retry-After") == "" {
		t.Error("expected Retry-After header")
	}

	// After cooldown, should pass again.
	time.Sleep(150 * time.Millisecond)
	req3 := httptest.NewRequest("POST", "/fish/catch", nil)
	req3.Header.Set("Authorization", "Bearer "+token)
	w3 := httptest.NewRecorder()
	handler.ServeHTTP(w3, req3)
	if w3.Code != http.StatusOK {
		t.Errorf("after cooldown: status = %d, want 200", w3.Code)
	}
}
