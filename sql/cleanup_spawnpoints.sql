-- DELETE spawnpoints
CREATE TEMPORARY TABLE IF NOT EXISTS spawnpoints_tmp AS (
  SELECT sp.id
  FROM spawnpoints sp
  LEFT JOIN sightings s ON s.spawn_id = sp.spawn_id
  LEFT JOIN mystery_sightings ms ON ms.spawn_id = sp.spawn_id
  WHERE (s.id IS NULL AND ms.id IS NULL)
  ORDER BY sp.id ASC
  LIMIT 500000
);
DELETE sp.* FROM spawnpoints sp INNER JOIN spawnpoints_tmp spt ON sp.id=spt.id;

-- Print delete counts
SELECT 'spawnpoints' AS TB_NAME, COUNT(*) AS DELETE_COUNT FROM spawnpoints_tmp
