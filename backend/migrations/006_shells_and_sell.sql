-- Add shells currency and sold_at soft-delete for quick-sell.
ALTER TABLE players ADD COLUMN shells INTEGER NOT NULL DEFAULT 0;
ALTER TABLE fish_instances ADD COLUMN sold_at TEXT;
