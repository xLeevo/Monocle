# for use with PostgreSQL and MySQL (untested)
# for SQLite, recreate database and import existing data

LOCK TABLES `forts` WRITE;
ALTER TABLE forts 
ADD COLUMN name VARCHAR(128),
ADD COLUMN url VARCHAR(200);
UNLOCK TABLES;

LOCK TABLES `fort_sightings` WRITE;
ALTER TABLE fort_sightings 
ADD COLUMN slots_available SMALLINT,
ADD COLUMN is_in_battle BOOL DEFAULT 0;
UNLOCK TABLES;

LOCK TABLES `pokestops` WRITE;
ALTER TABLE pokestops
ADD COLUMN name VARCHAR(128),
ADD COLUMN url VARCHAR(200);
UNLOCK TABLES;
