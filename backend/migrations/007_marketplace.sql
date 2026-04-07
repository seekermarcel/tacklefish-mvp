-- Marketplace: player-to-player fish trading.
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

CREATE INDEX idx_market_listings_active
    ON market_listings (sold_at, cancelled_at)
    WHERE sold_at IS NULL AND cancelled_at IS NULL;

CREATE INDEX idx_market_listings_seller
    ON market_listings (seller_id)
    WHERE sold_at IS NULL AND cancelled_at IS NULL;

ALTER TABLE fish_instances ADD COLUMN listing_id INTEGER REFERENCES market_listings(id);
