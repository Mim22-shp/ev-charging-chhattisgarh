-- ============================================================================
-- Step 3: Highway Gap & Uncovered Distance Analysis
-- Purpose: Identify highway corridors beyond a 50 km service buffer of 
--          candidate charging hubs and aggregate gap lengths.
-- ============================================================================

CREATE OR REPLACE VIEW vw_highway_gaps AS
WITH candidate_buffers AS (
    -- 50 km catchment service buffer around priority candidates
    SELECT ST_Union(ST_Buffer(geom, 50000)) AS covered_corridor
    FROM vw_candidate_sites
),
linear_uncovered AS (
    -- Difference operation between highway centerlines and 50 km coverage polygons
    SELECT 
        l.ref AS highway,
        ST_Difference(l.way, cb.covered_corridor) AS uncovered_geom
    FROM planet_osm_line l
    CROSS JOIN candidate_buffers cb
    WHERE l.ref ILIKE 'NH%' OR l.highway IN ('trunk', 'primary')
)
SELECT 
    highway,
    ROUND((SUM(ST_Length(uncovered_geom)) / 1000.0)::numeric, 2) AS total_uncovered_km
FROM linear_uncovered
WHERE uncovered_geom IS NOT NULL
  AND NOT ST_IsEmpty(uncovered_geom)
GROUP BY highway
ORDER BY total_uncovered_km DESC;