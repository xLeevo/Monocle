-- DELETE sightings
CREATE TEMPORARY TABLE IF NOT EXISTS sightings_temp AS (
  SELECT id
  FROM sightings
  WHERE expire_timestamp < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 3 HOUR))
  LIMIT 100000
);
DELETE s.* FROM sightings s INNER JOIN sightings_temp st ON s.id=st.id;

-- DELETE mystery_sightings
CREATE TEMPORARY TABLE IF NOT EXISTS mystery_sightings_temp AS (
  SELECT id
  FROM mystery_sightings
  WHERE first_seen < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 3 HOUR))
  LIMIT 100000
);
DELETE s.* FROM mystery_sightings s INNER JOIN mystery_sightings_temp st ON s.id=st.id;

-- DELETE fort_sightings
CREATE TEMPORARY TABLE IF NOT EXISTS fort_sightings_temp AS (
  SELECT id
  FROM fort_sightings
  WHERE last_modified < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 3 HOUR))
  LIMIT 100000
);
DELETE s.* FROM fort_sightings s INNER JOIN fort_sightings_temp st ON s.id=st.id;

-- DELETE raids
CREATE TEMPORARY TABLE IF NOT EXISTS raids_temp AS (
  SELECT id
  FROM raids
  WHERE time_spawn < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 3 HOUR))
  LIMIT 100000
);
DELETE r.* FROM raids r INNER JOIN raids_temp rt ON r.id=rt.id;

-- Print delete counts
(SELECT 'sightings' AS TB_NAME, COUNT(*) AS DELETE_COUNT FROM sightings_temp)
UNION
(SELECT 'mystery_sightings' AS TB_NAME, COUNT(*) AS DELETE_COUNT FROM mystery_sightings_temp)
UNION
(SELECT 'fort_sightings' AS TB_NAME, COUNT(*) AS DELETE_COUNT FROM fort_sightings_temp)
UNION
(SELECT 'raids' AS TB_NAME, COUNT(*) AS DELETE_COUNT FROM raids_temp);
