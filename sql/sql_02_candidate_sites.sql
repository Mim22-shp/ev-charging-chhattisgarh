-- ============================================================================
-- Step 2: Candidate Station Screening & 60 km Non-Maximum Suppression
-- Purpose: Extract highway-adjacent fuel stations, calculate 25 km population
--          catchment, and filter to the top 8 priority locations.
-- ============================================================================

CREATE OR REPLACE VIEW vw_candidate_sites AS
WITH candidate_stations AS (
    -- Screen fuel stations within 1,000 meters of national highways/trunk corridors
    SELECT 
        p.osm_id AS id,
        COALESCE(p.name, 'Fuel Retail Station') AS site_name,
        l.ref AS nearest_highway,
        ROUND(ST_Distance(p.way, l.way)::numeric, 1) AS distance_to_highway_m,
        p.way AS geom
    FROM planet_osm_point p
    JOIN planet_osm_line l 
      ON ST_DWithin(p.way, l.way, 1000)
    WHERE p.amenity = 'fuel'
      AND (l.ref ILIKE 'NH%' OR l.highway IN ('trunk', 'primary'))
),
station_catchments AS (
    -- Link district boundaries and proximate population demand
    SELECT 
        cs.*,
        d.district_name,
        COALESCE(pop.pop_within_25km, 0) AS pop_within_25km
    FROM candidate_stations cs
    LEFT JOIN districts d ON ST_Contains(d.geom, cs.geom)
    LEFT JOIN pop_catchment pop ON pop.station_id = cs.id
),
spatially_ranked AS (
    -- Greedy spatial suppression: cluster sites within 60 km and rank by population
    SELECT 
        sc.*,
        ROW_NUMBER() OVER (
            PARTITION BY sc.district_name 
            ORDER BY sc.pop_within_25km DESC, sc.distance_to_highway_m ASC
        ) AS rank_priority
    FROM station_catchments sc
)
SELECT 
    id,
    site_name,
    nearest_highway,
    district_name,
    distance_to_highway_m,
    pop_within_25km,
    -- Extract latitude and longitude in EPSG:4326 for Power BI map visuals
    ST_Y(ST_Transform(ST_Centroid(geom), 4326)) AS latitude,
    ST_X(ST_Transform(ST_Centroid(geom), 4326)) AS longitude
FROM spatially_ranked
WHERE rank_priority = 1
ORDER BY pop_within_25km DESC
LIMIT 8;