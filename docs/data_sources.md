# Data Sources & Attribution

### 1. OpenStreetMap (OSM)
* **Provider:** Geofabrik India Extract (`chhattisgarh-latest.osm.pbf`)
* **License:** Open Database License (ODbL) © OpenStreetMap contributors
* **Features Extracted:** `planet_osm_line` (`highway IN ('motorway', 'trunk', 'primary', 'secondary')`), `planet_osm_point` (`amenity = 'fuel'`).

### 2. WorldPop Global High Resolution Population
* **Provider:** WorldPop, University of Southampton (2020 unconstrained 1 km grid)
* **License:** Creative Commons Attribution 4.0 International (CC BY 4.0)
* **Usage:** Zonal population aggregation within 25 km candidate buffers.

### 3. Administrative Boundaries
* **Provider:** Survey of India / Open Data Portals
* **CRS:** Reprojected to EPSG:32644 (WGS 84 / UTM Zone 44N) and EPSG:4326 for presentation.