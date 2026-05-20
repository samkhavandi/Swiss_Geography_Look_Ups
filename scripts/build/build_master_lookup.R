library(dplyr)
library(readr)
library(readxl)
library(xml2)

# Builds a comprehensive master lookup table covering 2012-2022.
# One row per municipality x PLZ x year.
#
# Columns:
#   year, bfs_nr, municipality, district_id, district, canton_id,
#   canton_abbr, canton, plz, medstat_id, medstat_name
#
# PLZ assignments use a 2022 snapshot throughout. Municipalities dissolved
# before 2022 inherit the PLZs of their 2022 successor (best approximation
# without historical PLZ archives). Run build_municipality_crosswalk.R first.
#
# For ~5 PLZs absent from the MedStat source table, the MedStat region is
# imputed from the most-common region among other PLZs in the same municipality.
#
# Sources:
#   Municipality hierarchy  -> raw/Municipality_historical_directory.xml
#   PLZ -> municipality     -> raw/PLZ.csv
#   PLZ -> MedStat          -> raw/medstat.xlsx (sheet REGION=CH + REGION)
#   Crosswalk               -> lookups/harmonised/municipality_crosswalk_2012_2022.csv
#
# Usage: Rscript scripts/build/build_master_lookup.R

if (!exists("YEAR_FROM")) YEAR_FROM <- 2012
if (!exists("YEAR_TO"))   YEAR_TO   <- 2022

YEARS     <- YEAR_FROM:YEAR_TO
OUT_FILE  <- paste0("lookups/master_lookup_", YEAR_FROM, "_", YEAR_TO, ".csv")

crosswalk_file <- paste0("lookups/harmonised/municipality_crosswalk_",
                         YEAR_FROM, "_", YEAR_TO, ".csv")
if (!file.exists(crosswalk_file)) {
  stop("Crosswalk not found. Run build_municipality_crosswalk.R first.")
}

# ---------------------------------------------------------------------------
# 1. Parse XML: cantons, districts, municipalities
# ---------------------------------------------------------------------------
doc <- read_xml("raw/Municipality_historical_directory.xml")

# Cantons: cantonId, cantonAbbreviation, cantonLongName
canton_nodes <- xml_find_all(doc, ".//canton")
cantons <- bind_rows(lapply(canton_nodes, function(n) {
  g <- function(f) { v <- xml_text(xml_find_first(n, f)); if (is.na(v) || v == "") NA_character_ else v }
  tibble(
    canton_id   = as.integer(g("cantonId")),
    canton_abbr = g("cantonAbbreviation"),
    canton      = g("cantonLongName")
  )
}))

# Districts: districtHistId, districtId (BFS), districtLongName, cantonId,
#            admission/abolition dates (to pick the right district per year)
district_nodes <- xml_find_all(doc, ".//district")
districts <- bind_rows(lapply(district_nodes, function(n) {
  g <- function(f) { v <- xml_text(xml_find_first(n, f)); if (is.na(v) || v == "") NA_character_ else v }
  tibble(
    district_hist_id  = g("districtHistId"),
    district_id       = as.integer(g("districtId")),
    district          = g("districtLongName"),
    canton_id         = as.integer(g("cantonId")),
    d_admission_date  = as.Date(g("districtAdmissionDate")),
    d_abolition_date  = as.Date(g("districtAbolitionDate"))
  )
})) |>
  left_join(cantons, by = "canton_id")

# Municipalities: all historical records
muni_nodes <- xml_find_all(doc, ".//municipality")
municipalities <- bind_rows(lapply(muni_nodes, function(n) {
  g <- function(f) { v <- xml_text(xml_find_first(n, f)); if (is.na(v) || v == "") NA_character_ else v }
  tibble(
    bfs_nr           = as.integer(g("municipalityId")),
    municipality     = g("municipalityLongName"),
    district_hist_id = g("districtHistId"),
    admission_date   = as.Date(g("municipalityAdmissionDate")),
    abolition_date   = as.Date(g("municipalityAbolitionDate"))
  )
})) |>
  left_join(districts |> select(district_hist_id, district_id, district,
                                 canton_id, canton_abbr, canton),
            by = "district_hist_id")

# ---------------------------------------------------------------------------
# 2. PLZ -> BFS municipality (Swiss Post, current snapshot used for all years)
# ---------------------------------------------------------------------------
plz_raw <- read_delim("raw/PLZ.csv", delim = ";",
                      locale = locale(encoding = "UTF-8"),
                      show_col_types = FALSE)
names(plz_raw) <- gsub("\u00fc", "ue", names(plz_raw))

plz_lookup <- plz_raw |>
  select(bfs_nr = `BFS-Nr`, plz = PLZ4) |>
  distinct()

# Dissolved municipalities have no entries in the 2022 PLZ snapshot.
# Extend the lookup by inheriting the 2022 successor's PLZs for historical
# bfs_nrs, so they appear in the master lookup with approximately correct PLZs.
crosswalk_plz <- read_csv(crosswalk_file, show_col_types = FALSE) |>
  filter(!is.na(bfs_nr_2022)) |>
  select(bfs_nr, bfs_nr_2022) |>
  distinct()

plz_lookup_ext <- bind_rows(
  plz_lookup,
  crosswalk_plz |>
    inner_join(plz_lookup, by = c("bfs_nr_2022" = "bfs_nr"),
               relationship = "many-to-many") |>
    select(bfs_nr, plz)
) |>
  distinct()

# ---------------------------------------------------------------------------
# 3. PLZ -> MedStat
# ---------------------------------------------------------------------------
medstat_region <- read_excel("raw/medstat.xlsx", sheet = "REGION=CH") |>
  select(plz = `NPA/PLZ`, medstat_id = MedStat) |>
  mutate(plz = as.integer(plz)) |>
  filter(!is.na(plz), !is.na(medstat_id)) |>
  distinct()

medstat_names <- read_excel("raw/medstat.xlsx", sheet = "REGION") |>
  select(medstat_id = REGION, medstat_name = TEXT) |>
  filter(!is.na(medstat_id))

plz_medstat <- medstat_region |>
  left_join(medstat_names, by = "medstat_id")

# Municipality-level MedStat fallback: for PLZs absent from the medstat source,
# impute using the most common MedStat region across other PLZs in the same
# municipality. Covers ~5 PLZs (e.g. 3801, 6441, 6549, 6867).
muni_medstat_fallback <- plz_lookup_ext |>
  left_join(plz_medstat, by = "plz") |>
  filter(!is.na(medstat_id)) |>
  group_by(bfs_nr, medstat_id, medstat_name) |>
  summarise(n = n(), .groups = "drop") |>
  group_by(bfs_nr) |>
  slice_max(n, n = 1, with_ties = FALSE) |>
  ungroup() |>
  select(bfs_nr, medstat_id_fallback = medstat_id, medstat_name_fallback = medstat_name)

# ---------------------------------------------------------------------------
# 4. Build one table per year, stack into master
# ---------------------------------------------------------------------------
build_year <- function(yr) {
  ref_date <- as.Date(paste0(yr, "-01-01"))

  # Active municipalities in this year
  active <- municipalities |>
    filter(
      admission_date <= ref_date,
      is.na(abolition_date) | abolition_date >= ref_date
    ) |>
    select(bfs_nr, municipality, district_id, district,
           canton_id, canton_abbr, canton) |>
    distinct()

  # Join PLZ (extended to cover dissolved municipalities via their 2022
  # successor) and MedStat; apply fallback for PLZs absent from medstat source
  active |>
    left_join(plz_lookup_ext, by = "bfs_nr") |>
    left_join(plz_medstat, by = "plz") |>
    filter(!is.na(plz)) |>
    left_join(muni_medstat_fallback, by = "bfs_nr") |>
    mutate(
      medstat_id   = coalesce(medstat_id,   medstat_id_fallback),
      medstat_name = coalesce(medstat_name, medstat_name_fallback)
    ) |>
    select(-medstat_id_fallback, -medstat_name_fallback) |>
    mutate(year = yr) |>
    select(year, bfs_nr, municipality, district_id, district,
           canton_id, canton_abbr, canton, plz, medstat_id, medstat_name)
}

master <- bind_rows(lapply(YEARS, function(yr) {
  message("Building year ", yr, "...")
  build_year(yr)
}))

# ---------------------------------------------------------------------------
# 5. Write output
# ---------------------------------------------------------------------------
dir.create("lookups", showWarnings = FALSE)
write_csv(master, OUT_FILE)

message("\nWritten: ", OUT_FILE)
message("  Rows:           ", nrow(master))
message("  Years:          ", paste(range(master$year), collapse = "-"))
message("  Municipalities: ", n_distinct(paste(master$bfs_nr, master$year)))
message("  Distinct PLZs:  ", n_distinct(master$plz))
message("  MedStat regions:", n_distinct(master$medstat_id, na.rm = TRUE))
message("  Missing MedStat:", sum(is.na(master$medstat_id)))
