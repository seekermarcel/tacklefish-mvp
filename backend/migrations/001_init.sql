-- Tacklefish MVP schema

CREATE TABLE IF NOT EXISTS players (
    id         INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id  TEXT    UNIQUE NOT NULL,
    created_at TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now'))
);

CREATE TABLE IF NOT EXISTS fish_species (
    id           INTEGER PRIMARY KEY AUTOINCREMENT,
    name         TEXT    NOT NULL,
    rarity       TEXT    NOT NULL CHECK (rarity IN ('common', 'uncommon', 'rare', 'epic', 'legendary')),
    edition_size INTEGER NOT NULL,
    zone         INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE IF NOT EXISTS fish_instances (
    id             INTEGER PRIMARY KEY AUTOINCREMENT,
    species_id     INTEGER NOT NULL REFERENCES fish_species(id),
    owner_id       INTEGER NOT NULL REFERENCES players(id),
    edition_number INTEGER NOT NULL,
    size_variant   TEXT    NOT NULL CHECK (size_variant IN ('mini', 'normal', 'large', 'giant')),
    color_variant  TEXT    NOT NULL CHECK (color_variant IN ('normal', 'albino', 'melanistic', 'rainbow', 'neon')),
    caught_at      TEXT    NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%SZ', 'now')),
    UNIQUE(species_id, edition_number)
);

CREATE INDEX IF NOT EXISTS idx_fish_instances_owner ON fish_instances(owner_id);
CREATE INDEX IF NOT EXISTS idx_fish_instances_species ON fish_instances(species_id);
