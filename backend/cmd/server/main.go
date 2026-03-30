package main

import (
	"log"
	"net/http"
	"os"
	"time"

	"github.com/tacklefish/backend/internal/auth"
	"github.com/tacklefish/backend/internal/db"
	"github.com/tacklefish/backend/internal/fish"
	"github.com/tacklefish/backend/internal/player"
	"github.com/tacklefish/backend/migrations"
)

func main() {
	dbPath := envOr("DB_PATH", "./tacklefish.db")
	jwtSecret := envOr("JWT_SECRET", "change-me-in-production")
	addr := envOr("ADDR", ":8080")

	database, err := db.Open(dbPath)
	if err != nil {
		log.Fatal("failed to open database: ", err)
	}
	defer database.Close()

	if err := db.RunMigrationsFS(database, migrations.FS); err != nil {
		log.Fatal("failed to run migrations: ", err)
	}

	authHandler := &auth.Handler{DB: database, Secret: jwtSecret}
	fishHandler := &fish.Handler{DB: database}
	playerHandler := &player.Handler{DB: database}

	mux := http.NewServeMux()

	// Public routes (no auth required).
	mux.HandleFunc("POST /auth/register", authHandler.Register)
	mux.HandleFunc("POST /auth/refresh", authHandler.Refresh)
	mux.HandleFunc("POST /auth/transfer", authHandler.ClaimTransferCode)

	// Health check.
	mux.HandleFunc("GET /health", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		w.Write([]byte(`{"status":"ok"}`))
	})

	// Rate limiter for catch endpoint (1 catch per 3 seconds per player).
	catchRateLimit := auth.RateLimitMiddleware(3 * time.Second)

	// Protected routes (auth required).
	protected := http.NewServeMux()
	protected.Handle("POST /fish/catch", catchRateLimit(http.HandlerFunc(fishHandler.Catch)))
	protected.HandleFunc("GET /fish/pool", fishHandler.Pool)
	protected.HandleFunc("GET /player/inventory", playerHandler.Inventory)
	protected.HandleFunc("GET /player/inventory/{id}", playerHandler.FishDetail)
	protected.HandleFunc("POST /auth/transfer-code", authHandler.GenerateTransferCode)
	protected.HandleFunc("GET /auth/transfer-code", authHandler.GetTransferCode)

	mux.Handle("/", auth.Middleware(jwtSecret)(protected))

	log.Printf("tacklefish server starting on %s", addr)
	if err := http.ListenAndServe(addr, logMiddleware(mux)); err != nil {
		log.Fatal("server error: ", err)
	}
}

func logMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("%s %s", r.Method, r.URL.Path)
		next.ServeHTTP(w, r)
	})
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}
