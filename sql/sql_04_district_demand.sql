-- ============================================================================
-- Step 4: District-Level Infrastructure Demand Aggregation
-- Purpose: Aggregate candidate site distribution and served population totals
--          by administrative district for regional reporting.
-- ============================================================================

CREATE OR REPLACE VIEW vw_districts_demand AS
SELECT 
    d.district_name,
    COUNT(c.id) AS id, -- Matches Count of ID for relational modeling
    COALESCE(SUM(c.pop_within_25km), 0) AS total_population
FROM districts d
LEFT JOIN vw_candidate_sites c ON d.district_name = c.district_name
GROUP BY d.district_name
ORDER BY total_population DESC;