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

func TestGenerateTransferCodeNoClaims(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	// Request without claims (no auth).
	req := httptest.NewRequest("POST", "/auth/transfer-code", nil)
	w := httptest.NewRecorder()
	handler.GenerateTransferCode(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", w.Code)
	}
}

func TestGetTransferCodeNoClaims(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	req := httptest.NewRequest("GET", "/auth/transfer-code", nil)
	w := httptest.NewRecorder()
	handler.GetTransferCode(w, req)

	if w.Code != http.StatusUnauthorized {
		t.Errorf("status = %d, want 401", w.Code)
	}
}

func TestGenerateTransferCode(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	req := requestWithClaims("POST", "/auth/transfer-code", "", 1)
	w := httptest.NewRecorder()
	handler.GenerateTransferCode(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200; body = %s", w.Code, w.Body.String())
	}

	var resp struct {
		TransferCode string `json:"transfer_code"`
	}
	json.NewDecoder(w.Body).Decode(&resp)

	// Code should be formatted as XXXX-XXXX-XXXX (14 chars with dashes).
	if len(resp.TransferCode) != 14 {
		t.Errorf("transfer_code length = %d, want 14 (XXXX-XXXX-XXXX)", len(resp.TransferCode))
	}
	if resp.TransferCode[4] != '-' || resp.TransferCode[9] != '-' {
		t.Errorf("transfer_code format wrong: %q", resp.TransferCode)
	}
}

func TestGetTransferCodeNone(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	req := requestWithClaims("GET", "/auth/transfer-code", "", 1)
	w := httptest.NewRecorder()
	handler.GetTransferCode(w, req)

	if w.Code != http.StatusOK {
		t.Fatalf("status = %d, want 200", w.Code)
	}

	var resp map[string]any
	json.NewDecoder(w.Body).Decode(&resp)
	if resp["transfer_code"] != nil {
		t.Errorf("expected null transfer_code, got %v", resp["transfer_code"])
	}
}

func TestGetTransferCodeExisting(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	// Generate a code first.
	genReq := requestWithClaims("POST", "/auth/transfer-code", "", 1)
	genW := httptest.NewRecorder()
	handler.GenerateTransferCode(genW, genReq)

	var genResp struct {
		TransferCode string `json:"transfer_code"`
	}
	json.NewDecoder(genW.Body).Decode(&genResp)

	// Get should return the same code.
	getReq := requestWithClaims("GET", "/auth/transfer-code", "", 1)
	getW := httptest.NewRecorder()
	handler.GetTransferCode(getW, getReq)

	var getResp struct {
		TransferCode string `json:"transfer_code"`
	}
	json.NewDecoder(getW.Body).Decode(&getResp)

	if getResp.TransferCode != genResp.TransferCode {
		t.Errorf("get code = %q, want %q", getResp.TransferCode, genResp.TransferCode)
	}
}

func TestClaimTransferCode(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	// Generate a code for player 1.
	genReq := requestWithClaims("POST", "/auth/transfer-code", "", 1)
	genW := httptest.NewRecorder()
	handler.GenerateTransferCode(genW, genReq)

	var genResp struct {
		TransferCode string `json:"transfer_code"`
	}
	json.NewDecoder(genW.Body).Decode(&genResp)

	// Claim with a new device.
	claimBody := `{"device_id":"new-device-123","transfer_code":"` + genResp.TransferCode + `"}`
	claimReq := httptest.NewRequest("POST", "/auth/transfer", bytes.NewBufferString(claimBody))
	claimW := httptest.NewRecorder()
	handler.ClaimTransferCode(claimW, claimReq)

	if claimW.Code != http.StatusOK {
		t.Fatalf("claim status = %d, want 200; body = %s", claimW.Code, claimW.Body.String())
	}

	var claimResp struct {
		Token    string `json:"token"`
		PlayerID int64  `json:"player_id"`
	}
	json.NewDecoder(claimW.Body).Decode(&claimResp)

	if claimResp.PlayerID != 1 {
		t.Errorf("claimed player_id = %d, want 1", claimResp.PlayerID)
	}
	if claimResp.Token == "" {
		t.Error("expected non-empty token")
	}

	// Old device should no longer work for refresh.
	refreshReq := httptest.NewRequest("POST", "/auth/refresh", bytes.NewBufferString(`{"device_id":"test-device"}`))
	refreshW := httptest.NewRecorder()
	handler.Refresh(refreshW, refreshReq)
	if refreshW.Code != http.StatusUnauthorized {
		t.Errorf("old device refresh: status = %d, want 401", refreshW.Code)
	}
}

func TestClaimTransferCodeInvalid(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	body := `{"device_id":"some-device","transfer_code":"XXXX-XXXX-XXXX"}`
	req := httptest.NewRequest("POST", "/auth/transfer", bytes.NewBufferString(body))
	w := httptest.NewRecorder()
	handler.ClaimTransferCode(w, req)

	if w.Code != http.StatusNotFound {
		t.Errorf("status = %d, want 404", w.Code)
	}
}

func TestClaimTransferCodeBadFormat(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	body := `{"device_id":"some-device","transfer_code":"SHORT"}`
	req := httptest.NewRequest("POST", "/auth/transfer", bytes.NewBufferString(body))
	w := httptest.NewRecorder()
	handler.ClaimTransferCode(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", w.Code)
	}
}

func TestClaimTransferCodeMissingDeviceID(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	body := `{"device_id":"","transfer_code":"XXXX-XXXX-XXXX"}`
	req := httptest.NewRequest("POST", "/auth/transfer", bytes.NewBufferString(body))
	w := httptest.NewRecorder()
	handler.ClaimTransferCode(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", w.Code)
	}
}

func TestClaimTransferCodeInvalidJSON(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	req := httptest.NewRequest("POST", "/auth/transfer", bytes.NewBufferString(`not json`))
	w := httptest.NewRecorder()
	handler.ClaimTransferCode(w, req)

	if w.Code != http.StatusBadRequest {
		t.Errorf("status = %d, want 400", w.Code)
	}
}

func TestClaimTransferCodeReusable(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	// Generate a code for player 1.
	genReq := requestWithClaims("POST", "/auth/transfer-code", "", 1)
	genW := httptest.NewRecorder()
	handler.GenerateTransferCode(genW, genReq)

	var genResp struct {
		TransferCode string `json:"transfer_code"`
	}
	json.NewDecoder(genW.Body).Decode(&genResp)

	// Claim once.
	claimBody := `{"device_id":"device-a","transfer_code":"` + genResp.TransferCode + `"}`
	claimReq := httptest.NewRequest("POST", "/auth/transfer", bytes.NewBufferString(claimBody))
	claimW := httptest.NewRecorder()
	handler.ClaimTransferCode(claimW, claimReq)
	if claimW.Code != http.StatusOK {
		t.Fatalf("first claim: status = %d, want 200", claimW.Code)
	}

	// Claim again with different device — should still work (reusable).
	claimBody2 := `{"device_id":"device-b","transfer_code":"` + genResp.TransferCode + `"}`
	claimReq2 := httptest.NewRequest("POST", "/auth/transfer", bytes.NewBufferString(claimBody2))
	claimW2 := httptest.NewRecorder()
	handler.ClaimTransferCode(claimW2, claimReq2)
	if claimW2.Code != http.StatusOK {
		t.Errorf("reuse claim: status = %d, want 200", claimW2.Code)
	}
}

func TestGenerateTransferCodeRevokesOld(t *testing.T) {
	db := setupMemoryDB(t)
	handler := &auth.Handler{DB: db, Secret: testSecret}

	// Generate first code.
	req1 := requestWithClaims("POST", "/auth/transfer-code", "", 1)
	w1 := httptest.NewRecorder()
	handler.GenerateTransferCode(w1, req1)

	var resp1 struct {
		TransferCode string `json:"transfer_code"`
	}
	json.NewDecoder(w1.Body).Decode(&resp1)

	// Generate second code (should replace first).
	req2 := requestWithClaims("POST", "/auth/transfer-code", "", 1)
	w2 := httptest.NewRecorder()
	handler.GenerateTransferCode(w2, req2)

	var resp2 struct {
		TransferCode string `json:"transfer_code"`
	}
	json.NewDecoder(w2.Body).Decode(&resp2)

	if resp1.TransferCode == resp2.TransferCode {
		t.Error("second code should be different from first")
	}

	// Old code should no longer work.
	claimBody := `{"device_id":"new-device","transfer_code":"` + resp1.TransferCode + `"}`
	claimReq := httptest.NewRequest("POST", "/auth/transfer", bytes.NewBufferString(claimBody))
	claimW := httptest.NewRecorder()
	handler.ClaimTransferCode(claimW, claimReq)

	if claimW.Code != http.StatusNotFound {
		t.Errorf("old code claim: status = %d, want 404", claimW.Code)
	}
}
