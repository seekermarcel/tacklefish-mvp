-- Add XP and profile stats to players table.
ALTER TABLE players ADD COLUMN xp INTEGER NOT NULL DEFAULT 0;
ALTER TABLE players ADD COLUMN total_caught INTEGER NOT NULL DEFAULT 0;
ALTER TABLE players ADD COLUMN total_released INTEGER NOT NULL DEFAULT 0;

-- Backfill total_caught from existing fish_instances.
UPDATE players SET total_caught = (
    SELECT COUNT(*) FROM fish_instances WHERE owner_id = players.id
);
