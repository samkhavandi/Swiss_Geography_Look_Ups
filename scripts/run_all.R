library(purrr)

# Master script -- runs all build scripts for the specified year range.
# Assumes raw data is already present in raw/ (run fetch scripts if updating).
#
# To extend coverage to a new year:
#   1. Update YEAR_FROM / YEAR_TO below
#   2. Replace raw/ files with updated vintages (see sources/ for URLs)
#   3. Run this script, then validate
#
# Usage: Rscript scripts/run_all.R

# --- Configuration: change these to extend coverage -------------------------
YEAR_FROM <- 2012
YEAR_TO   <- 2022
# ---------------------------------------------------------------------------

annual_scripts <- c(
  "scripts/build/build_municipality_plz.R",
  "scripts/build/build_plz_medstat.R",
  "scripts/build/build_municipality_medstat.R"
)

walk(YEAR_FROM:YEAR_TO, function(yr) {
  message("\n--- Year: ", yr, " ---")
  walk(annual_scripts, function(script) {
    message("Running: ", script)
    local({
      YEAR <- yr
      source(script, local = TRUE)
    })
  })
})

message("\n--- Building harmonisation crosswalk ---")
source("scripts/build/build_municipality_crosswalk.R")

message("\n--- Building master lookup (all years) ---")
source("scripts/build/build_master_lookup.R")

message("\n--- Building harmonised master lookup ---")
source("scripts/build/build_harmonised_master.R")

message("\n--- Building geometry files ---")
source("scripts/build/build_geometries.R")

message("\nDone. Run validation/validate.R to check outputs.")
