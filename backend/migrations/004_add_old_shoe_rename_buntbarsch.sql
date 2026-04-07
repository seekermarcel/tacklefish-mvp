-- Rename Buntbarsch to Cichlid (English name)
UPDATE fish_species SET name = 'Cichlid' WHERE name = 'Buntbarsch';

-- Add Old Shoe: legendary with only 2 editions
INSERT OR IGNORE INTO fish_species (name, rarity, edition_size, zone) VALUES
    ('Old Shoe', 'legendary', 2, 1);
