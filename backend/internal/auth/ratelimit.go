package auth

import (
	"net/http"
	"sync"
	"time"
)

type rateLimiter struct {
	mu       sync.Mutex
	lastCatch map[int64]time.Time
	cooldown  time.Duration
}

func newRateLimiter(cooldown time.Duration) *rateLimiter {
	return &rateLimiter{
		lastCatch: make(map[int64]time.Time),
		cooldown:  cooldown,
	}
}

func (rl *rateLimiter) allow(playerID int64) bool {
	rl.mu.Lock()
	defer rl.mu.Unlock()

	last, exists := rl.lastCatch[playerID]
	if exists && time.Since(last) < rl.cooldown {
		return false
	}
	rl.lastCatch[playerID] = time.Now()
	return true
}

// RateLimitMiddleware limits how often a player can hit a specific endpoint.
// Returns 429 Too Many Requests if the player tries again within the cooldown.
func RateLimitMiddleware(cooldown time.Duration) func(http.Handler) http.Handler {
	rl := newRateLimiter(cooldown)

	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			claims := GetClaims(r)
			if claims == nil {
				// No claims means auth middleware hasn't run yet or failed.
				// Let the handler deal with it.
				next.ServeHTTP(w, r)
				return
			}

			if !rl.allow(claims.PlayerID) {
				w.Header().Set("Content-Type", "application/json")
				w.Header().Set("Retry-After", "3")
				w.WriteHeader(http.StatusTooManyRequests)
				w.Write([]byte(`{"error":"too many requests","retry_after_seconds":3}`))
				return
			}

			next.ServeHTTP(w, r)
		})
	}
}
