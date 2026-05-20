library(httr2)

# Downloads the Swiss Post PLZ/Ortschaftsverzeichnis.
# Output saved to raw/swiss_post_plz/.
#
# Usage: Rscript scripts/fetch/fetch_swiss_post_plz.R
#
# Current download available at:
# https://swisspost.opendatasoft.com/explore/dataset/plz_verzeichnis_v2/
#
# For historical vintages (2012-2021), check:
# https://opendata.swiss or archived versions via swisstopo.
# Note: use the vintage closest to your reference year.

YEAR <- 2022  # reference year this snapshot represents
OUT_DIR <- "raw/swiss_post_plz"

# TODO: replace with direct CSV export URL from Swiss Post open data
URL <- NULL

if (is.null(URL)) {
  stop("Set URL to the Swiss Post PLZ CSV download for year ", YEAR)
}

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
out_file <- file.path(OUT_DIR, paste0("plz_verzeichnis_", YEAR, ".csv"))

request(URL) |>
  req_perform() |>
  resp_body_raw() |>
  writeBin(out_file)

message("Saved to ", out_file)
