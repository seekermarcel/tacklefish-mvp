package auth

import (
	"crypto/rand"
	"database/sql"
	"encoding/json"
	"math/big"
	"net/http"
	"strings"
)

type Handler struct {
	DB     *sql.DB
	Secret string
}

// Alphabet without 0/O/1/I to avoid visual confusion.
const transferCodeAlphabet = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
const transferCodeLength = 12

type registerRequest struct {
	DeviceID string `json:"device_id"`
}

type claimRequest struct {
	DeviceID     string `json:"device_id"`
	TransferCode string `json:"transfer_code"`
}

type tokenResponse struct {
	Token    string `json:"token"`
	PlayerID int64  `json:"player_id"`
}

func (h *Handler) Register(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.DeviceID == "" {
		http.Error(w, `{"error":"device_id is required"}`, http.StatusBadRequest)
		return
	}

	// Upsert: return existing player or create new one.
	var playerID int64
	err := h.DB.QueryRow(
		`INSERT INTO players (device_id) VALUES (?) ON CONFLICT(device_id) DO UPDATE SET device_id=device_id RETURNING id`,
		req.DeviceID,
	).Scan(&playerID)
	if err != nil {
		http.Error(w, `{"error":"failed to register"}`, http.StatusInternalServerError)
		return
	}

	token, err := GenerateToken(h.Secret, playerID, req.DeviceID)
	if err != nil {
		http.Error(w, `{"error":"failed to generate token"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tokenResponse{Token: token, PlayerID: playerID})
}

func (h *Handler) Refresh(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.DeviceID == "" {
		http.Error(w, `{"error":"device_id is required"}`, http.StatusBadRequest)
		return
	}

	var playerID int64
	err := h.DB.QueryRow(`SELECT id FROM players WHERE device_id = ?`, req.DeviceID).Scan(&playerID)
	if err != nil {
		http.Error(w, `{"error":"device not registered"}`, http.StatusUnauthorized)
		return
	}

	token, err := GenerateToken(h.Secret, playerID, req.DeviceID)
	if err != nil {
		http.Error(w, `{"error":"failed to generate token"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tokenResponse{Token: token, PlayerID: playerID})
}

// GenerateTransferCode creates (or replaces) a backup code for the authenticated player.
func (h *Handler) GenerateTransferCode(w http.ResponseWriter, r *http.Request) {
	claims := GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	code, err := generateCode()
	if err != nil {
		http.Error(w, `{"error":"failed to generate code"}`, http.StatusInternalServerError)
		return
	}

	_, err = h.DB.Exec(`UPDATE players SET transfer_code = ? WHERE id = ?`, code, claims.PlayerID)
	if err != nil {
		http.Error(w, `{"error":"failed to save code"}`, http.StatusInternalServerError)
		return
	}

	formatted := formatCode(code)
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"transfer_code": formatted})
}

// GetTransferCode returns the existing backup code for the authenticated player.
func (h *Handler) GetTransferCode(w http.ResponseWriter, r *http.Request) {
	claims := GetClaims(r)
	if claims == nil {
		http.Error(w, `{"error":"unauthorized"}`, http.StatusUnauthorized)
		return
	}

	var code sql.NullString
	err := h.DB.QueryRow(`SELECT transfer_code FROM players WHERE id = ?`, claims.PlayerID).Scan(&code)
	if err != nil {
		http.Error(w, `{"error":"player not found"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	if !code.Valid {
		json.NewEncoder(w).Encode(map[string]any{"transfer_code": nil})
		return
	}
	json.NewEncoder(w).Encode(map[string]string{"transfer_code": formatCode(code.String)})
}

// ClaimTransferCode lets a new device claim an existing account using a backup code.
func (h *Handler) ClaimTransferCode(w http.ResponseWriter, r *http.Request) {
	var req claimRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, `{"error":"invalid request body"}`, http.StatusBadRequest)
		return
	}

	if req.DeviceID == "" {
		http.Error(w, `{"error":"device_id is required"}`, http.StatusBadRequest)
		return
	}

	// Normalize: strip dashes, uppercase
	code := strings.ToUpper(strings.ReplaceAll(req.TransferCode, "-", ""))
	if len(code) != transferCodeLength {
		http.Error(w, `{"error":"invalid transfer code format"}`, http.StatusBadRequest)
		return
	}

	// Atomically update device_id for the player with this transfer code.
	var playerID int64
	err := h.DB.QueryRow(
		`UPDATE players SET device_id = ? WHERE transfer_code = ? RETURNING id`,
		req.DeviceID, code,
	).Scan(&playerID)
	if err != nil {
		http.Error(w, `{"error":"invalid transfer code"}`, http.StatusNotFound)
		return
	}

	token, err := GenerateToken(h.Secret, playerID, req.DeviceID)
	if err != nil {
		http.Error(w, `{"error":"failed to generate token"}`, http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(tokenResponse{Token: token, PlayerID: playerID})
}

func generateCode() (string, error) {
	alphabetLen := big.NewInt(int64(len(transferCodeAlphabet)))
	code := make([]byte, transferCodeLength)
	for i := range code {
		n, err := rand.Int(rand.Reader, alphabetLen)
		if err != nil {
			return "", err
		}
		code[i] = transferCodeAlphabet[n.Int64()]
	}
	return string(code), nil
}

// formatCode inserts dashes for readability: ABCD-EFGH-JKLM
func formatCode(code string) string {
	if len(code) != transferCodeLength {
		return code
	}
	return code[0:4] + "-" + code[4:8] + "-" + code[8:12]
}
