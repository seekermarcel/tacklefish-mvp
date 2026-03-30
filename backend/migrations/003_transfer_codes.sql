-- Add transfer code column for account backup/recovery.
-- SQLite cannot add a UNIQUE column directly, so we add the column then create an index.
ALTER TABLE players ADD COLUMN transfer_code TEXT;
CREATE UNIQUE INDEX IF NOT EXISTS idx_players_transfer_code ON players(transfer_code);
