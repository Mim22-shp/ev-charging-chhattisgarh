SELECT 'districts' AS table_name, COUNT(*) AS invalid_count
FROM districts
WHERE NOT ST_IsValid(geom)
UNION ALL
SELECT 'highways_nh', COUNT(*)
FROM highways_nh
WHERE NOT ST_IsValid(geom)
UNION ALL
SELECT 'candidate_sites', COUNT(*)
FROM candidate_sites
WHERE NOT ST_IsValid(geom);

SELECT f_table_name, f_geometry_column, srid, type 
FROM geometry_columns 
WHERE f_table_name IN ('districts', 'highways_nh', 'candidate_sites');


-- 1. Drop the column if it was partially created
ALTER TABLE candidate_sites DROP COLUMN IF EXISTS geom_32644;

-- 2. Add the column allowing MultiPoint geometry
ALTER TABLE candidate_sites 
ADD COLUMN geom_32644 geometry(MultiPoint, 32644);

-- 3. Populate using ST_Multi and ST_Transform
UPDATE candidate_sites 
SET geom_32644 = ST_Multi(ST_Transform(geom, 32644));

-- 1. Drop the column if it was partially created
ALTER TABLE candidate_sites DROP COLUMN IF EXISTS geom_32644;

-- 2. Add the column allowing MultiPoint geometry
ALTER TABLE candidate_sites 
ADD COLUMN geom_32644 geometry(MultiPoint, 32644);

-- 3. Populate using ST_Multi and ST_Transform
UPDATE candidate_sites 
SET geom_32644 = ST_Multi(ST_Transform(geom, 32644));


SELECT f_table_name, f_geometry_column, srid, type 
FROM geometry_columns 
WHERE f_table_name IN ('districts', 'highways_nh', 'candidate_sites')
ORDER BY f_table_name, srid;


-- 1. Districts: Add and populate UTM Zone 44N geometry
ALTER TABLE districts 
ADD COLUMN IF NOT EXISTS geom_32644 geometry(MultiPolygon, 32644);

UPDATE districts 
SET geom_32644 = ST_Multi(ST_Transform(geom, 32644));

-- 2. Highways: Add and populate UTM Zone 44N geometry
ALTER TABLE highways_nh 
ADD COLUMN IF NOT EXISTS geom_32644 geometry(MultiLineString, 32644);

UPDATE highways_nh 
SET geom_32644 = ST_Multi(ST_Transform(geom, 32644));


SELECT f_table_name, f_geometry_column, srid, type 
FROM geometry_columns 
WHERE f_table_name IN ('districts', 'highways_nh', 'candidate_sites')
ORDER BY f_table_name, srid;

SELECT osm_id, COUNT(*) AS duplicate_count
FROM candidate_sites
GROUP BY osm_id
HAVING COUNT(*) > 1;

SELECT COUNT(*) AS missing_ref_count
FROM highways_nh
WHERE ref IS NULL OR ref = '';

-- 1. Index for districts
CREATE INDEX idx_districts_geom_32644 ON districts USING GIST (geom_32644);

-- 2. Index for highways
CREATE INDEX idx_highways_geom_32644 ON highways_nh USING GIST (geom_32644);

-- 3. Index for candidate sites
CREATE INDEX idx_sites_geom_32644 ON candidate_sites USING GIST (geom_32644);

ALTER TABLE candidate_sites
ADD COLUMN district_name varchar(100),
ADD COLUMN nearest_highway varchar(50),
ADD COLUMN distance_to_highway_m numeric(10, 2);

SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'districts';

UPDATE candidate_sites cs
SET district_name = name
FROM districts d
WHERE ST_Intersects(cs.geom_32644, d.geom_32644);

UPDATE candidate_sites cs
SET 
    nearest_highway = nh.ref,
    distance_to_highway_m = ROUND(ST_Distance(cs.geom_32644, nh.geom_32644)::numeric, 2)

SELECT 
    id, 
    osm_id, 
    district_name, 
    nearest_highway, 
    distance_to_highway_m
FROM candidate_sites
ORDER BY distance_to_highway_m ASC
LIMIT 10;
FROM (
    SELECT DISTINCT ON (c.id)
        c.id,
        h.ref,
        h.geom_32644
    FROM candidate_sites c
    CROSS JOIN LATERAL (
        SELECT ref, geom_32644
        FROM highways_nh
        ORDER BY c.geom_32644 <-> geom_32644
        LIMIT 1
    ) h
) nh
WHERE cs.id = nh.id;

SELECT 
    id, 
    osm_id, 
    district_name, 
    nearest_highway, 
    distance_to_highway_m
FROM candidate_sites
ORDER BY distance_to_highway_m ASC
LIMIT 10;


SELECT * FROM districts LIMIT 1;

UPDATE candidate_sites cs
SET district_name = name_2
FROM districts d
WHERE ST_Intersects(cs.geom_32644, d.geom_32644);


UPDATE candidate_sites cs
SET district_name = d."NAME_2"
FROM districts d
WHERE ST_Intersects(cs.geom_32644, d.geom_32644);

SELECT 
    id, 
    osm_id, 
    district_name, 
    nearest_highway, 
    distance_to_highway_m
FROM candidate_sites
ORDER BY distance_to_highway_m ASC
LIMIT 10;

ALTER TABLE districts 
ADD COLUMN population numeric;

UPDATE districts d
SET population = dp.pop_sum
FROM districts_pop dp
WHERE d."NAME_2" = dp."NAME_2";

CREATE OR REPLACE VIEW vw_candidate_sites AS
SELECT 
    id,
    osm_id,
    district_name,
    nearest_highway,
    distance_to_highway_m,
    geom  -- Keeping the EPSG:4326 geometry because Power BI maps use standard Lat/Lon
FROM candidate_sites;

CREATE OR REPLACE VIEW vw_districts_demand AS
SELECT 
    id,
    "NAME_2" AS district_name,
    population AS total_population,
    geom
FROM districts;

-- 1. Add the tracking column
ALTER TABLE candidate_sites 
ADD COLUMN on_highway boolean DEFAULT false;

-- 2. Flag sites within 1 km (1000 metres) of a national highway
UPDATE candidate_sites 
SET on_highway = true 
WHERE distance_to_highway_m <= 1000;

-- 3. Count how many sites qualify
SELECT COUNT(*) AS viable_sites 
FROM candidate_sites 
WHERE on_highway = true;



CREATE TABLE highway_gaps AS
WITH coverage AS (
    -- Merge 50km buffers around all viable stations into one giant polygon
    SELECT ST_Union(ST_Buffer(geom_32644, 50000)) AS safe_zone
    FROM candidate_sites
    WHERE on_highway = true
)
SELECT 
    h.ref,
    -- Cut the safe zone out of the highway lines
    ST_Multi(ST_Difference(h.geom_32644, c.safe_zone))::geometry(MultiLineString, 32644) AS geom_32644,
    -- Calculate the length of the remaining exposed gap in kilometres
    ROUND((ST_Length(ST_Difference(h.geom_32644, c.safe_zone)) / 1000.0)::numeric, 2) AS gap_length_km
FROM highways_nh h, coverage c
WHERE NOT ST_Within(h.geom_32644, c.safe_zone);



SELECT 
    ref AS highway, 
    SUM(gap_length_km) AS total_uncovered_km
FROM highway_gaps
WHERE gap_length_km > 0
GROUP BY ref
ORDER BY total_uncovered_km DESC;


CREATE TABLE site_buffers AS
SELECT 
    id, 
    osm_id,
    district_name,
    nearest_highway,
    ST_SetSRID(ST_Buffer(geom_32644, 25000), 32644)::geometry(Polygon, 32644) AS geom
FROM candidate_sites
WHERE on_highway = true;


ALTER TABLE candidate_sites 
ADD COLUMN pop_within_25km numeric;

UPDATE candidate_sites cs
SET pop_within_25km = sbp.pop25_sum
FROM site_buffers_pop sbp
WHERE cs.id = sbp.id;



SELECT id, nearest_highway, pop_within_25km FROM candidate_sites WHERE on_highway = true ORDER BY pop_within_25km DESC LIMIT 5;


CREATE TABLE priority_sites AS
SELECT *
FROM candidate_sites a
WHERE on_highway = true
AND NOT EXISTS (
    -- Look for a better station nearby
    SELECT 1
    FROM candidate_sites b
    WHERE b.on_highway = true
    AND b.id != a.id
    AND ST_Distance(a.geom_32644, b.geom_32644) <= 60000
    AND b.pop_within_25km > a.pop_within_25km
);

SELECT 
    id, 
    district_name, 
    nearest_highway, 
    pop_within_25km 
FROM priority_sites 
ORDER BY pop_within_25km DESC;



CREATE OR REPLACE VIEW vw_candidate_sites AS
SELECT 
    id,
    district_name,
    nearest_highway,
    distance_to_highway_m,
    pop_within_25km,
    ST_Y(geom) AS latitude,  -- Extracts Latitude for Power BI
    ST_X(geom) AS longitude  -- Extracts Longitude for Power BI
FROM priority_sites;



DROP VIEW IF EXISTS vw_candidate_sites;

CREATE VIEW vw_candidate_sites AS
SELECT 
    id,
    district_name,
    nearest_highway,
    distance_to_highway_m,
    pop_within_25km,
    ST_Y(geom) AS latitude,
    ST_X(geom) AS longitude
FROM priority_sites;



-- 2. The District Demand View
CREATE OR REPLACE VIEW vw_districts_demand AS
SELECT 
    id,
    "NAME_2" AS district_name,
    population AS total_population
FROM districts;

-- 3. The Highway Gaps View (For the Bar Chart)
CREATE OR REPLACE VIEW vw_highway_gaps AS
SELECT 
    ref AS highway,
    SUM(gap_length_km) AS total_uncovered_km
FROM highway_gaps
GROUP BY ref;




-- 1. Wipe the slate clean
DROP VIEW IF EXISTS vw_candidate_sites CASCADE;
DROP VIEW IF EXISTS vw_districts_demand CASCADE;

-- 2. Create the clean Candidate Sites View
CREATE VIEW vw_candidate_sites AS
SELECT 
    id,
    district_name,
    nearest_highway,
    distance_to_highway_m,
    pop_within_25km,
    ST_Y(geom) AS latitude,
    ST_X(geom) AS longitude
FROM priority_sites;

-- 3. Create the clean District Demand View
CREATE VIEW vw_districts_demand AS
SELECT 
    id,
    "NAME_2" AS district_name,
    population AS total_population
FROM districts;

-- 4. Create the Highway Gaps View
CREATE OR REPLACE VIEW vw_highway_gaps AS
SELECT 
    ref AS highway,
    SUM(gap_length_km) AS total_uncovered_km
FROM highway_gaps
GROUP BY ref;



DROP VIEW IF EXISTS vw_candidate_sites CASCADE;

CREATE VIEW vw_candidate_sites AS
SELECT 
    id,
    district_name,
    nearest_highway,
    distance_to_highway_m,
    pop_within_25km,
    ST_Y(ST_Centroid(geom)) AS latitude,
    ST_X(ST_Centroid(geom)) AS longitude
FROM priority_sites;