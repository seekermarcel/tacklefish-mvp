package db

import (
	"database/sql"
	"fmt"
	"io/fs"
	"log"
	"sort"

	_ "github.com/mattn/go-sqlite3"
)

func Open(path string) (*sql.DB, error) {
	db, err := sql.Open("sqlite3", path+"?_journal_mode=WAL&_foreign_keys=ON&_busy_timeout=5000")
	if err != nil {
		return nil, fmt.Errorf("open db: %w", err)
	}

	if err := db.Ping(); err != nil {
		return nil, fmt.Errorf("ping db: %w", err)
	}

	log.Println("database ready:", path)
	return db, nil
}

// RunMigrationsFS reads all .sql files from the embedded FS and executes them in order.
// Migrations are tracked in a _migrations table so each file runs only once.
func RunMigrationsFS(database *sql.DB, migrations fs.FS) error {
	// Create tracking table if it doesn't exist.
	// If the database already has tables but no _migrations table (pre-tracking upgrade),
	// mark existing migrations as applied so they don't re-run.
	var hasMigrationsTable bool
	database.QueryRow(`SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='_migrations'`).Scan(&hasMigrationsTable)

	if !hasMigrationsTable {
		if _, err := database.Exec(`CREATE TABLE _migrations (name TEXT PRIMARY KEY)`); err != nil {
			return fmt.Errorf("create migrations table: %w", err)
		}
		// Check if this is an existing database (players table exists) being upgraded.
		var hasPlayers bool
		database.QueryRow(`SELECT COUNT(*) FROM sqlite_master WHERE type='table' AND name='players'`).Scan(&hasPlayers)
		if hasPlayers {
			// Mark all .sql migrations before 003 as already applied.
			database.Exec(`INSERT OR IGNORE INTO _migrations (name) VALUES ('001_init.sql')`)
			database.Exec(`INSERT OR IGNORE INTO _migrations (name) VALUES ('002_seed_species.sql')`)
			log.Println("bootstrapped migration tracking for existing database")
		}
	}

	entries, err := fs.ReadDir(migrations, ".")
	if err != nil {
		return fmt.Errorf("read migrations: %w", err)
	}

	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	for _, entry := range entries {
		if entry.IsDir() || !isSQL(entry.Name()) {
			continue
		}

		// Skip already-applied migrations.
		var count int
		database.QueryRow(`SELECT COUNT(*) FROM _migrations WHERE name = ?`, entry.Name()).Scan(&count)
		if count > 0 {
			continue
		}

		data, err := fs.ReadFile(migrations, entry.Name())
		if err != nil {
			return fmt.Errorf("read %s: %w", entry.Name(), err)
		}
		if _, err := database.Exec(string(data)); err != nil {
			return fmt.Errorf("exec %s: %w", entry.Name(), err)
		}
		if _, err := database.Exec(`INSERT INTO _migrations (name) VALUES (?)`, entry.Name()); err != nil {
			return fmt.Errorf("record %s: %w", entry.Name(), err)
		}
		log.Println("applied migration:", entry.Name())
	}

	return nil
}

func isSQL(name string) bool {
	return len(name) > 4 && name[len(name)-4:] == ".sql"
}
