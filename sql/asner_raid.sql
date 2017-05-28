ALTER TABLE fort_sightings ADD COLUMN in_battle BOOLEAN NOT NULL DEFAULT 0 AFTER team,
ADD COLUMN slots_available TINYINT AFTER guard_pokemon_id,
ADD COLUMN time_ocuppied INT AFTER slots_available;

