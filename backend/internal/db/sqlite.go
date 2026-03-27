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
func RunMigrationsFS(database *sql.DB, migrations fs.FS) error {
	entries, err := fs.ReadDir(migrations, ".")
	if err != nil {
		return fmt.Errorf("read migrations: %w", err)
	}

	// Sort by filename to ensure order.
	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		data, err := fs.ReadFile(migrations, entry.Name())
		if err != nil {
			return fmt.Errorf("read %s: %w", entry.Name(), err)
		}
		if _, err := database.Exec(string(data)); err != nil {
			return fmt.Errorf("exec %s: %w", entry.Name(), err)
		}
		log.Println("applied migration:", entry.Name())
	}

	return nil
}
