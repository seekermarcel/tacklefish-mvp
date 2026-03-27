package auth

import (
	"database/sql"
	"encoding/json"
	"net/http"
)

type Handler struct {
	DB     *sql.DB
	Secret string
}

type registerRequest struct {
	DeviceID string `json:"device_id"`
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
