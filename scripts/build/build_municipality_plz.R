library(dplyr)
library(readr)

# Builds municipality-to-PLZ lookup for a given year.
# One municipality can have multiple PLZs (one-to-many table).
#
# Source: Swiss Post PLZ/Ortschaftsverzeichnis (raw/PLZ.csv)
# Note: the current PLZ.csv is a single snapshot. For strict annual accuracy,
# use a vintage file closest to the reference year.
#
# Usage: Rscript scripts/build/build_municipality_plz.R

YEAR <- 2022  # update as needed

raw_file <- "raw/PLZ.csv"

if (!file.exists(raw_file)) {
  stop("Raw file not found: ", raw_file)
}

# File is semicolon-delimited with a UTF-8 BOM
raw <- read_delim(raw_file, delim = ";", locale = locale(encoding = "UTF-8"),
                  show_col_types = FALSE)

# Replace umlaut in column names to avoid encoding issues across platforms
names(raw) <- gsub("\u00fc", "ue", names(raw))

ch_cantons <- c("AG","AI","AR","BE","BL","BS","FR","GE","GL","GR","JU","LU",
                "NE","NW","OW","SG","SH","SO","SZ","TG","TI","UR","VD","VS","ZG","ZH")

lookup <- raw |>
  select(
    bfs_nr       = `BFS-Nr`,
    municipality = Gemeindename,
    canton       = Kantonskuerzel,
    plz          = PLZ4,
    locality     = Ortschaftsname
  ) |>
  filter(canton %in% ch_cantons) |>   # exclude Liechtenstein entries (canton = NA)
  distinct() |>
  mutate(year = YEAR) |>
  arrange(bfs_nr, plz)

dir.create("lookups/annual", showWarnings = FALSE, recursive = TRUE)
out_file <- paste0("lookups/annual/municipality_plz_", YEAR, ".csv")
write_csv(lookup, out_file)

message("Written: ", out_file, " (", nrow(lookup), " rows, ",
        n_distinct(lookup$bfs_nr), " municipalities, ",
        n_distinct(lookup$plz), " PLZs)")
