-- ============================================================================
-- Step 1: Geometry Preparation and Spatial Indexing
-- Purpose: Project geometries into a planar metric CRS for accurate distance 
--          computations and create spatial GiST indices.
-- ============================================================================

-- Ensure PostGIS extension is active
CREATE EXTENSION IF NOT EXISTS postgis;

-- 1.1 Transform OSM highway lines to projected metric CRS (EPSG:32644 / UTM Zone 44N)
-- Note: Replace source CRS if your raw table is in EPSG:4326 or EPSG:3857
ALTER TABLE planet_osm_line 
  ALTER COLUMN way TYPE geometry(LineString, 32644) 
  USING ST_Transform(way, 32644);

-- 1.2 Transform candidate points (fuel stations)
ALTER TABLE planet_osm_point 
  ALTER COLUMN way TYPE geometry(Point, 32644) 
  USING ST_Transform(way, 32644);

-- 1.3 Build GiST spatial indices for high-performance spatial joins
CREATE INDEX IF NOT EXISTS idx_osm_line_geom ON planet_osm_line USING GIST(way);
CREATE INDEX IF NOT EXISTS idx_osm_point_geom ON planet_osm_point USING GIST(way);

-- 1.4 Validate geometry validity
UPDATE planet_osm_line SET way = ST_MakeValid(way) WHERE NOT ST_IsValid(way);
UPDATE planet_osm_point SET way = ST_MakeValid(way) WHERE NOT ST_IsValid(way);