library(sf)
library(dplyr)

# Builds clean WGS84 GeoJSON files for each administrative level.
# Source: BFS Generalisierte Gemeindegrenzen (raw/boundaries/Communes_*.geojson etc.)
#         MedStat regions (raw/boundaries/medstat.geojson) from versorgungsatlas.ch
#
# Input CRS: EPSG:2056 (CH1903+/LV95) -- reprojected to WGS84 (EPSG:4326)
# Join keys match the lookup CSVs: bfs_nr, district_id, canton, medstat_id
#
# Usage: Rscript scripts/build/build_geometries.R

dir.create("geometries", showWarnings = FALSE)

raw_dir <- "raw/boundaries"

# --- Municipalities ---
communes_file <- file.path(raw_dir, "Communes_G1_2056.geojson")
if (!file.exists(communes_file)) {
  stop("Not found: ", communes_file,
       "\nDownload BFS Generalisierte Gemeindegrenzen and place the Communes file there.")
}

communes <- read_sf(communes_file) |>
  st_transform(4326) |>
  select(
    bfs_nr       = GDENR,
    municipality = GDENAME,
    district_id  = BEZNR,
    district     = BEZNAME,
    canton_nr    = KTNR,
    canton       = KTKZ
  )

write_sf(communes, "geometries/municipality_2025.geojson",
         driver = "GeoJSON", delete_dsn = TRUE)
message("Written: geometries/municipality_2025.geojson (",
        nrow(communes), " municipalities)")

# --- Districts ---
districts_file <- file.path(raw_dir, "Districts_G1_2056.geojson")
if (!file.exists(districts_file)) {
  stop("Not found: ", districts_file)
}

districts <- read_sf(districts_file) |>
  st_transform(4326) |>
  select(
    district_id = BEZNR,
    district    = BEZNAME,
    canton_nr   = KTNR,
    canton      = KTKZ
  )

write_sf(districts, "geometries/district_2025.geojson",
         driver = "GeoJSON", delete_dsn = TRUE)
message("Written: geometries/district_2025.geojson (",
        nrow(districts), " districts)")

# --- Cantons ---
cantons_file <- file.path(raw_dir, "Cantons_G1_2056.geojson")
if (!file.exists(cantons_file)) {
  stop("Not found: ", cantons_file)
}

cantons <- read_sf(cantons_file) |>
  st_transform(4326) |>
  select(
    canton_nr = KTNR,
    canton    = KTKZ
  )

write_sf(cantons, "geometries/canton.geojson",
         driver = "GeoJSON", delete_dsn = TRUE)
message("Written: geometries/canton.geojson (", nrow(cantons), " cantons)")

# --- MedStat ---
medstat_file <- file.path(raw_dir, "medstat.geojson")
if (!file.exists(medstat_file)) {
  message("Skipping MedStat geometry: ", medstat_file, " not found.")
  message("Download from versorgungsatlas.ch and place as raw/boundaries/medstat.geojson")
} else {
  medstat <- read_sf(medstat_file)

  # Detect CRS and reproject if needed
  if (!is.na(st_crs(medstat)) && st_crs(medstat)$epsg != 4326) {
    medstat <- st_transform(medstat, 4326)
  }

  # Check for expected join key -- versorgungsatlas uses varying property names
  props <- names(medstat)
  message("MedStat properties found: ", paste(props, collapse = ", "))
  message("Confirm 'medstat_id' column maps correctly before committing.")

  write_sf(medstat, "geometries/medstat.geojson",
           driver = "GeoJSON", delete_dsn = TRUE)
  message("Written: geometries/medstat.geojson (", nrow(medstat), " regions)")
}

message("\nDone. Join keys: bfs_nr (municipality), district_id (district), ",
        "canton (canton), medstat_id (medstat)")
