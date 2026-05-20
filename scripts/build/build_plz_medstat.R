library(dplyr)
library(readr)
library(readxl)

# Builds PLZ-to-MedStat lookup.
# Source: BFS MedStat file (raw/medstat.xlsx), sheet "REGION=CH"
# MedStat region names come from sheet "REGION".
#
# Usage: Rscript scripts/build/build_plz_medstat.R

YEAR <- 2022  # reference year this snapshot represents

raw_file <- "raw/medstat.xlsx"

if (!file.exists(raw_file)) {
  stop("Raw file not found: ", raw_file)
}

ch_cantons <- c("AG","AI","AR","BE","BL","BS","FR","GE","GL","GR","JU","LU",
                "NE","NW","OW","SG","SH","SO","SZ","TG","TI","UR","VD","VS","ZG","ZH")

# PLZ -> MedStat code (Swiss PLZs only; excludes foreign entries with canton "XY")
region_ch <- read_excel(raw_file, sheet = "REGION=CH") |>
  select(
    plz          = `NPA/PLZ`,
    canton       = KT,
    medstat_id   = MedStat
  ) |>
  mutate(plz = as.integer(plz)) |>
  filter(!is.na(plz), !is.na(medstat_id), canton %in% ch_cantons) |>
  distinct()

# MedStat code -> name (and MS-Region / MOBSPAT)
region_names <- read_excel(raw_file, sheet = "REGION") |>
  select(
    medstat_id   = REGION,
    medstat_name = TEXT,
    mobspat_id   = MOBSPAT
  ) |>
  filter(!is.na(medstat_id))

lookup <- region_ch |>
  left_join(region_names, by = "medstat_id") |>
  mutate(year = YEAR) |>
  arrange(plz)

dir.create("lookups/annual", showWarnings = FALSE, recursive = TRUE)
out_file <- paste0("lookups/annual/plz_medstat_", YEAR, ".csv")
write_csv(lookup, out_file)

message("Written: ", out_file, " (", nrow(lookup), " rows, ",
        n_distinct(lookup$plz), " PLZs, ",
        n_distinct(lookup$medstat_id), " MedStat regions)")
