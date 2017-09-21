-- DELETE spawnpoints
CREATE TEMPORARY TABLE IF NOT EXISTS spawnpoints_tmp AS (
  SELECT sp.id
  FROM spawnpoints sp
  WHERE sp.updated < (UNIX_TIMESTAMP() - 86400)
	AND (SELECT MAX(last_modified) last_updated from fort_sightings) > (UNIX_TIMESTAMP() - 3600)
  ORDER BY sp.id ASC
  LIMIT 500000
);
DELETE sp.* FROM spawnpoints sp INNER JOIN spawnpoints_tmp spt ON sp.id=spt.id;

-- Print delete counts
SELECT 'spawnpoints' AS TB_NAME, COUNT(*) AS DELETE_COUNT FROM spawnpoints_tmp
