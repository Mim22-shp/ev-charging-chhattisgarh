# Chhattisgarh EV Fast-Charging Gap Analysis & Optimal Site Selection

> An end-to-end spatial data engineering and business intelligence pipeline identifying optimal national highway EV charging hubs across Chhattisgarh using PostGIS, QGIS, and Power BI.

![Dashboard Overview](docs/images/dashboard_overview.png)

## Executive Summary
Long-distance electric vehicle (EV) adoption along inter-district transit corridors is constrained by highway charging gaps ("range anxiety"). This project evaluates highway network coverage across Chhattisgarh to locate critical gaps beyond 50 km service thresholds, identifying **8 high-priority fast-charging candidate locations** serving a **2.64M population catchment** and targeting **1,330 km of uncovered highway corridors**.

## Key Findings & Metrics
* **8 Strategic Candidate Hubs:** Identified through spatial non-maximum suppression (60 km separation) to prevent infrastructure cannibalization.
* **1.33K km Uncovered Corridors:** Total national highway segments currently located outside a 50 km buffer of fast-charging infrastructure.
* **2.64M Catchment Population:** Aggregated population within a 25 km radius of the 8 selected priority hubs.
* **Primary Corridor Deficits:** NH-30, NH-53, and NH-130 represent the highest-priority gap segments requiring phase-one deployment.

## Tech Stack & Architecture
* **Database & Spatial Engine:** PostgreSQL 16 + PostGIS (`ST_DWithin`, `ST_Buffer`, `ST_Difference`, `ST_Centroid`, GiST indexing).
* **GIS Processing & Validation:** QGIS (Catchment modeling, raster-vector spatial joins).
* **Business Intelligence:** Microsoft Power BI (Relational star-schema modeling, spatial bubble mapping, interactive cross-filtering).
* **Data Sources:** OpenStreetMap (via Geofabrik), WorldPop 1 km Global Population Grid, Survey of India / Open Data District Boundaries.

## Data Sources
| Dataset | Source | Format | Purpose |
|---|---|---|---|
| Road Network & Fuel Stations | OpenStreetMap / Geofabrik | OSM PBF / Spatial PostGIS | Highway corridors & candidate site anchors |
| Population Density | WorldPop (1 km resolution) | GeoTIFF | 25 km catchment population estimation |
| District Boundaries | Administrative Boundary GeoJSON | Vector Polygon | District-level demand aggregation |

*Full licensing details and download references available in [`docs/data_sources.md`](docs/data_sources.md).*

## Spatial Methodology
1. **Candidate Screening:** Extracted existing fuel stations within a 1,000 m buffer of National Highways to leverage existing electrical, road-access, and commercial amenities.
2. **Gap Analysis:** Generated a 50 km buffer around candidate infrastructure to calculate uncovered linear highway segments (`ST_Difference`).
3. **Catchment Demand Estimation:** Conducted a 25 km circular buffer around each candidate to aggregate proximate WorldPop population.
4. **Spatial Non-Maximum Suppression:** Implemented a 60 km greedy spatial elimination filter to enforce minimum corridor spacing between priority hubs.
5. **Relational BI Serving:** Exposed optimized database views to Power BI via Direct/Import query with single-direction relational integrity.

## Recommendations
* **Phase 1 Priority:** Immediately deploy 60–120 kW CCS2 DC fast-chargers at the top candidates along the Durg–Raipur–Bilaspur triangle (highest population return and commercial vehicle throughput).
* **Phase 2 Expansion:** Target the southern transit corridors (Bastar/Kondagaon/Dantewada along NH-30) to eliminate remote transit gaps into neighboring states.

## Limitations
* **Proxy Candidacy:** Operational fuel retail stations were utilized as proxies for EV charging sites due to sparse charging station tagging in OSM extracts.
* **Euclidean Distances:** Spatial buffers use geodesic/Euclidean distance rather than road-network turn-by-turn routing distances.
* **Grid Resolution:** Catchment population figures rely on 1 km gridded estimations rather than census block centroid allocations.

## How to Reproduce
1. Clone the repository:
   ```bash
   git clone [https://github.com/](https://github.com/)<your-username>/ev-charging-chhattisgarh.git