package tests

import (
	"database/sql"
	"os"
	"path/filepath"
	"testing"

	"github.com/tacklefish/backend/internal/fish"
	_ "github.com/mattn/go-sqlite3"
)

const schema = `
	CREATE TABLE players (
		id              INTEGER PRIMARY KEY AUTOINCREMENT,
		device_id       TEXT    UNIQUE NOT NULL,
		transfer_code   TEXT    UNIQUE,
		created_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
		xp              INTEGER NOT NULL DEFAULT 0,
		total_caught    INTEGER NOT NULL DEFAULT 0,
		total_released  INTEGER NOT NULL DEFAULT 0,
		shells          INTEGER NOT NULL DEFAULT 0
	);
	CREATE TABLE fish_species (
		id           INTEGER PRIMARY KEY AUTOINCREMENT,
		name         TEXT    NOT NULL,
		rarity       TEXT    NOT NULL,
		edition_size INTEGER NOT NULL,
		zone         INTEGER NOT NULL DEFAULT 1
	);
	CREATE TABLE fish_instances (
		id             INTEGER PRIMARY KEY AUTOINCREMENT,
		species_id     INTEGER NOT NULL REFERENCES fish_species(id),
		owner_id       INTEGER NOT NULL REFERENCES players(id),
		edition_number INTEGER NOT NULL,
		size_variant   TEXT    NOT NULL,
		color_variant  TEXT    NOT NULL,
		caught_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
		sold_at        TEXT,
		listing_id     INTEGER REFERENCES market_listings(id),
		UNIQUE(species_id, edition_number)
	);
	CREATE TABLE market_listings (
		id           INTEGER PRIMARY KEY AUTOINCREMENT,
		fish_id      INTEGER NOT NULL REFERENCES fish_instances(id),
		seller_id    INTEGER NOT NULL REFERENCES players(id),
		price        INTEGER NOT NULL CHECK (price >= 1 AND price <= 99999),
		created_at   TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
		sold_at      TEXT,
		buyer_id     INTEGER REFERENCES players(id),
		cancelled_at TEXT
	);
`

// setupMemoryDB creates an in-memory SQLite database. Suitable for single-goroutine tests.
func setupMemoryDB(t *testing.T) *sql.DB {
	t.Helper()
	db, err := sql.Open("sqlite3", ":memory:?_foreign_keys=ON")
	if err != nil {
		t.Fatal("open db:", err)
	}
	if _, err := db.Exec(schema); err != nil {
		t.Fatal("schema:", err)
	}
	if _, err := db.Exec(`INSERT INTO players (device_id) VALUES ('test-device')`); err != nil {
		t.Fatal("seed player:", err)
	}
	t.Cleanup(func() { db.Close() })
	return db
}

// setupFileDB creates a file-based SQLite database with WAL mode.
// Required for tests with concurrent goroutines.
func setupFileDB(t *testing.T) *sql.DB {
	t.Helper()
	dir := t.TempDir()
	dbPath := filepath.Join(dir, "test.db")

	db, err := sql.Open("sqlite3", dbPath+"?_journal_mode=WAL&_foreign_keys=ON&_busy_timeout=5000")
	if err != nil {
		t.Fatal("open db:", err)
	}
	if _, err := db.Exec(schema); err != nil {
		t.Fatal("schema:", err)
	}
	if _, err := db.Exec(`INSERT INTO players (device_id) VALUES ('test-device')`); err != nil {
		t.Fatal("seed player:", err)
	}
	t.Cleanup(func() {
		db.Close()
		os.RemoveAll(dir)
	})
	return db
}

func seedSpecies(t *testing.T, db *sql.DB, name string, rarity fish.Rarity, editionSize int) int64 {
	t.Helper()
	result, err := db.Exec(
		`INSERT INTO fish_species (name, rarity, edition_size, zone) VALUES (?, ?, ?, 1)`,
		name, string(rarity), editionSize,
	)
	if err != nil {
		t.Fatal("seed species:", err)
	}
	id, _ := result.LastInsertId()
	return id
}

func catchFishForPlayer(t *testing.T, db *sql.DB, speciesID int64, editionNum int, playerID int64) int64 {
	t.Helper()
	result, err := db.Exec(
		`INSERT INTO fish_instances (species_id, owner_id, edition_number, size_variant, color_variant) VALUES (?, ?, ?, 'normal', 'normal')`,
		speciesID, playerID, editionNum,
	)
	if err != nil {
		t.Fatal("catch fish:", err)
	}
	id, _ := result.LastInsertId()
	return id
}

func seedPlayer(t *testing.T, db *sql.DB, deviceID string, shells int) int64 {
	t.Helper()
	result, err := db.Exec(`INSERT INTO players (device_id, shells) VALUES (?, ?)`, deviceID, shells)
	if err != nil {
		t.Fatal("seed player:", err)
	}
	id, _ := result.LastInsertId()
	return id
}

func createListing(t *testing.T, db *sql.DB, fishID int64, sellerID int64, price int) int64 {
	t.Helper()
	result, err := db.Exec(
		`INSERT INTO market_listings (fish_id, seller_id, price) VALUES (?, ?, ?)`,
		fishID, sellerID, price,
	)
	if err != nil {
		t.Fatal("create listing:", err)
	}
	listingID, _ := result.LastInsertId()
	if _, err := db.Exec(`UPDATE fish_instances SET listing_id = ? WHERE id = ?`, listingID, fishID); err != nil {
		t.Fatal("set listing_id:", err)
	}
	return listingID
}

func catchFish(t *testing.T, db *sql.DB, speciesID int64, editionNum int) {
	t.Helper()
	_, err := db.Exec(
		`INSERT INTO fish_instances (species_id, owner_id, edition_number, size_variant, color_variant) VALUES (?, 1, ?, 'normal', 'normal')`,
		speciesID, editionNum,
	)
	if err != nil {
		t.Fatal("catch fish:", err)
	}
}

// seedAllMVPSpecies inserts the MVP fish species.
func seedAllMVPSpecies(t *testing.T, db *sql.DB) {
	t.Helper()
	_, err := db.Exec(`
		INSERT INTO fish_species (name, rarity, edition_size, zone) VALUES
			('Perch',                'common',    1000, 1),
			('Carp',                 'common',     800, 1),
			('Chub',                 'common',     600, 1),
			('Brook Trout',          'uncommon',   400, 1),
			('Moonbass',             'uncommon',   300, 1),
			('Catfish',              'uncommon',   250, 1),
			('Ice Trout',            'rare',       150, 1),
			('Night Eel',            'rare',       100, 1),
			('Obsidian Pufferfish',  'epic',        30, 1),
			('Golden Primeval Perch', 'legendary',  10, 1),
			('Cichlid',              'rare',       150, 1),
			('Unifish',              'legendary',   10, 1),
			('Old Shoe',             'legendary',    2, 1)
	`)
	if err != nil {
		t.Fatal("seed MVP species:", err)
	}
}
