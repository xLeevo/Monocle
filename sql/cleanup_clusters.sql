-- DELETE clusters 
CREATE TEMPORARY TABLE IF NOT EXISTS clusters_temp AS (
  SELECT timeslice, pokemon_id, place_id
  FROM clusters 
  WHERE timeslice < UNIX_TIMESTAMP(DATE_SUB(NOW(), INTERVAL 48 HOUR)) / 600
  LIMIT 100000
);
DELETE c.* FROM clusters c INNER JOIN clusters_temp ct ON ct.timeslice=c.timeslice AND ct.pokemon_id=c.pokemon_id AND ct.place_id=c.place_id;

-- Print delete counts
SELECT 'clusters' AS TB_NAME, COUNT(*) AS DELETE_COUNT FROM clusters_temp;
