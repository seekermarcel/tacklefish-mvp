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
// Each migration is tracked in a _migrations table and only applied once.
func RunMigrationsFS(database *sql.DB, migrations fs.FS) error {
	if _, err := database.Exec(`
		CREATE TABLE IF NOT EXISTS _migrations (
			name       TEXT PRIMARY KEY,
			applied_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
		)
	`); err != nil {
		return fmt.Errorf("create migrations table: %w", err)
	}

	entries, err := fs.ReadDir(migrations, ".")
	if err != nil {
		return fmt.Errorf("read migrations: %w", err)
	}

	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()

		var count int
		if err := database.QueryRow(`SELECT COUNT(*) FROM _migrations WHERE name = ?`, name).Scan(&count); err != nil {
			return fmt.Errorf("check migration %s: %w", name, err)
		}
		if count > 0 {
			log.Println("skipping migration (already applied):", name)
			continue
		}

		data, err := fs.ReadFile(migrations, name)
		if err != nil {
			return fmt.Errorf("read %s: %w", name, err)
		}
		if _, err := database.Exec(string(data)); err != nil {
			return fmt.Errorf("exec %s: %w", name, err)
		}
		if _, err := database.Exec(`INSERT INTO _migrations (name) VALUES (?)`, name); err != nil {
			return fmt.Errorf("record migration %s: %w", name, err)
		}
		log.Println("applied migration:", name)
	}

	return nil
}
