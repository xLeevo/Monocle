# for use with PostgreSQL and MySQL (untested)
# for SQLite, recreate database and import existing data

ALTER TABLE forts 
ADD COLUMN name VARCHAR(128),
ADD COLUMN url VARCHAR(200);

ALTER TABLE fort_sightings 
ADD COLUMN is_in_battle BOOL DEFAULT 0;

ALTER TABLE pokestops
ADD COLUMN name VARCHAR(128),
ADD COLUMN url VARCHAR(200);
