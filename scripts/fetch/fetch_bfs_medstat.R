library(httr2)

# Downloads the BFS MedStat correspondence table for a given year.
# Output saved to raw/bfs_medstat/.
#
# Usage: Rscript scripts/fetch/fetch_bfs_medstat.R
#
# Find the correspondence table bundled with the Medical Statistics documentation at:
# https://www.bfs.admin.ch/bfs/en/home/statistics/health/health-statistics/medical-statistics-hospitals.html

YEAR <- 2022  # update as needed
OUT_DIR <- "raw/bfs_medstat"

# TODO: replace with direct download URL for the desired year from BFS
URL <- NULL

if (is.null(URL)) {
  stop("Set URL to the BFS MedStat correspondence table for year ", YEAR)
}

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
out_file <- file.path(OUT_DIR, paste0("medstat_", YEAR, ".csv"))

request(URL) |>
  req_perform() |>
  resp_body_raw() |>
  writeBin(out_file)

message("Saved to ", out_file)
