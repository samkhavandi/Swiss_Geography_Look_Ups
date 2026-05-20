library(dplyr)
library(readr)

# Adds bfs_nr_{YEAR_TO} and municipality_{YEAR_TO} columns to the master lookup
# by joining with the municipality crosswalk. This allows consistent cross-year
# analysis: group or aggregate by bfs_nr_{YEAR_TO} to track the same geographic
# unit over time regardless of boundary changes.
#
# Prerequisite: run build_master_lookup.R and build_municipality_crosswalk.R first.
#
# When run via run_all.R, YEAR_FROM and YEAR_TO are inherited from there.
# When run standalone, the defaults below are used.
#
# Usage: Rscript scripts/build/build_harmonised_master.R

if (!exists("YEAR_FROM")) YEAR_FROM <- 2012
if (!exists("YEAR_TO"))   YEAR_TO   <- 2022

bfs_target_col  <- paste0("bfs_nr_",       YEAR_TO)
muni_target_col <- paste0("municipality_", YEAR_TO)

master_file    <- paste0("lookups/master_lookup_",            YEAR_FROM, "_", YEAR_TO, ".csv")
crosswalk_file <- paste0("lookups/harmonised/municipality_crosswalk_", YEAR_FROM, "_", YEAR_TO, ".csv")
out_file       <- paste0("lookups/master_lookup_harmonised_", YEAR_FROM, "_", YEAR_TO, ".csv")

master    <- read_csv(master_file,    show_col_types = FALSE)
crosswalk <- read_csv(crosswalk_file, show_col_types = FALSE)

# From the crosswalk take the mapping bfs_nr -> bfs_nr_{YEAR_TO}.
# A given bfs_nr may appear in multiple rows (multiple validity periods);
# we want the mapping that applies to each row's year.
crosswalk_dates <- crosswalk |>
  mutate(
    valid_from = as.Date(valid_from),
    valid_to   = as.Date(valid_to)
  ) |>
  rename(bfs_nr_target = all_of(bfs_target_col),
         municipality_target = all_of(muni_target_col)) |>
  select(bfs_nr, bfs_nr_target, municipality_target, valid_from, valid_to)

harmonised <- master |>
  mutate(ref_date = as.Date(paste0(year, "-01-01"))) |>
  left_join(crosswalk_dates, by = "bfs_nr",
            relationship = "many-to-many") |>
  filter(
    ref_date >= valid_from,
    is.na(valid_to) | ref_date <= valid_to
  ) |>
  rename(!!bfs_target_col  := bfs_nr_target,
         !!muni_target_col := municipality_target) |>
  select(-ref_date, -valid_from, -valid_to) |>
  select(year, bfs_nr, municipality,
         all_of(bfs_target_col), all_of(muni_target_col),
         district_id, district, canton_id, canton_abbr, canton,
         plz, medstat_id, medstat_name)

write_csv(harmonised, out_file)

message("Written: ", out_file)
message("  Rows:              ", nrow(harmonised))
message("  Missing ", bfs_target_col, ": ", sum(is.na(harmonised[[bfs_target_col]])))
