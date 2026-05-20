library(httr2)

# Downloads the BFS Gemeindeverzeichnis — one file containing all municipalities
# current and historical, with the year each entry was created.
# Used for both annual lookups and the harmonisation crosswalk.
#
# Download via the BFS application at: https://www.agvchapp.bfs.admin.ch/de
# Select "Historisiertes Gemeindeverzeichnis" and export as CSV.
#
# Usage: Rscript scripts/fetch/fetch_bfs_gemeindeverzeichnis.R

OUT_DIR <- "raw/bfs_gemeindeverzeichnis"

# TODO: replace with the direct CSV download URL from the BFS application
URL <- NULL

if (is.null(URL)) {
  stop("Set URL to the BFS Gemeindeverzeichnis CSV download link.\n",
       "Export from: https://www.agvchapp.bfs.admin.ch/de")
}

dir.create(OUT_DIR, recursive = TRUE, showWarnings = FALSE)
out_file <- file.path(OUT_DIR, "gemeindeverzeichnis.csv")

request(URL) |>
  req_perform() |>
  resp_body_raw() |>
  writeBin(out_file)

message("Saved to ", out_file)
