library(dplyr)
library(readr)

# Builds municipality-to-MedStat lookup by joining municipality_plz and plz_medstat.
# Run build_municipality_plz.R and build_plz_medstat.R first.
#
# Because PLZ areas do not align with municipality boundaries, some municipalities
# span multiple MedStat regions. For these, the MedStat region with the most PLZs
# is assigned (majority rule). The `ambiguous` flag marks these cases.
#
# Usage: Rscript scripts/build/build_municipality_medstat.R

YEAR <- 2022  # update as needed

muni_plz  <- read_csv(paste0("lookups/annual/municipality_plz_",  YEAR, ".csv"),
                      show_col_types = FALSE)
plz_mstat <- read_csv(paste0("lookups/annual/plz_medstat_", YEAR, ".csv"),
                      show_col_types = FALSE)

joined <- muni_plz |>
  left_join(plz_mstat |> select(plz, medstat_id, medstat_name),
            by = "plz")

# Count PLZs per municipality-MedStat combination
plz_counts <- joined |>
  group_by(bfs_nr, municipality, canton, medstat_id, medstat_name) |>
  summarise(n_plz = n_distinct(plz), .groups = "drop")

# Flag municipalities spanning more than one MedStat region
n_regions <- plz_counts |>
  group_by(bfs_nr) |>
  summarise(n_medstat = n_distinct(medstat_id, na.rm = TRUE), .groups = "drop")

# Assign the MedStat region with the most PLZs (majority rule)
lookup <- plz_counts |>
  group_by(bfs_nr, municipality, canton) |>
  slice_max(n_plz, n = 1, with_ties = FALSE) |>
  ungroup() |>
  left_join(n_regions, by = "bfs_nr") |>
  mutate(
    ambiguous = n_medstat > 1,
    year = YEAR
  ) |>
  select(bfs_nr, municipality, canton, medstat_id, medstat_name, ambiguous, year) |>
  arrange(bfs_nr)

n_ambiguous <- sum(lookup$ambiguous, na.rm = TRUE)
message("Written: lookups/annual/municipality_medstat_", YEAR, ".csv")
message("  Total municipalities: ", nrow(lookup))
message("  Unambiguous:          ", nrow(lookup) - n_ambiguous)
message("  Majority-assigned:    ", n_ambiguous,
        " (municipality spans multiple MedStat regions)")

write_csv(lookup, paste0("lookups/annual/municipality_medstat_", YEAR, ".csv"))
