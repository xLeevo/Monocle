CREATE TABLE `sightings_tmp` LIKE `sightings`;

LOCK TABLES `sightings` WRITE,
`sightings_tmp` WRITE;

INSERT IGNORE INTO sightings_tmp 
SELECT * 
FROM sightings 
WHERE last_updated>DATE_SUB(NOW(),INTERVAL 5 MINUTE);

ALTER TABLE `sightings` RENAME TO `sightings_trash`;
ALTER TABLE `sightings_tmp` RENAME TO `sightings`;

UNLOCK TABLES;

DROP TABLE `sightings_trash`;

