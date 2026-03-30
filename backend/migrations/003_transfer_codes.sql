-- Add transfer code column for account backup/recovery.
ALTER TABLE players ADD COLUMN transfer_code TEXT UNIQUE;
