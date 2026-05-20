library(dplyr)
library(readr)
library(readxl)
library(purrr)

# Runs integrity checks on all lookup tables in lookups/ subdirectories.
# Exits with a non-zero status if any check fails.
#
# Usage: Rscript validation/validate.R

# Official MedStat codes from source (used to validate master lookup)
official_medstat <- read_excel("raw/medstat.xlsx", sheet = "REGION") |>
  filter(!is.na(REGION)) |>
  pull(REGION)

lookup_files <- c(
  list.files("lookups/annual",     pattern = "\\.csv$", full.names = TRUE),
  list.files("lookups/harmonised", pattern = "\\.csv$", full.names = TRUE),
  list.files("lookups",            pattern = "\\.csv$", full.names = TRUE)
)

if (length(lookup_files) == 0) {
  message("No lookup files found -- nothing to validate.")
  quit(status = 0)
}

errors <- list()

for (f in lookup_files) {
  df   <- read_csv(f, show_col_types = FALSE)
  name <- basename(f)

  if (nrow(df) == 0) {
    errors[[name]] <- c(errors[[name]], "File is empty")
    next
  }

  # No NAs in key ID columns
  key_cols <- intersect(c("bfs_nr", "plz"), names(df))
  for (col in key_cols) {
    if (any(is.na(df[[col]]))) {
      errors[[name]] <- c(errors[[name]], paste0("NAs in column: ", col))
    }
  }

  # medstat_id: no missing values
  if ("medstat_id" %in% names(df)) {
    n_missing <- sum(is.na(df$medstat_id))
    if (n_missing > 0) {
      errors[[name]] <- c(errors[[name]],
        paste0("Missing medstat_id in ", n_missing, " rows"))
    }
  }

  # medstat_id: all codes must exist in the official REGION sheet.
  # FL00 (Liechtenstein) is the only official code with no Swiss PLZ -- its
  # absence from the lookup is expected.
  if ("medstat_id" %in% names(df)) {
    bad_codes <- setdiff(unique(na.omit(df$medstat_id)), official_medstat)
    if (length(bad_codes) > 0) {
      errors[[name]] <- c(errors[[name]],
        paste0("medstat_id values not in official REGION sheet: ",
               paste(bad_codes, collapse = ", ")))
    }
  }

  # Source IDs should be unique except in one-to-many and multi-year tables
  is_one_to_many <- grepl("municipality_plz", name) ||
                    grepl("crosswalk",        name) ||
                    grepl("master_lookup",    name)
  if (!is_one_to_many) {
    source_col <- names(df)[1]
    if (anyDuplicated(df[[source_col]]) > 0) {
      errors[[name]] <- c(errors[[name]],
        paste0("Duplicate values in: ", source_col))
    }
  }

  # Annual files should contain exactly one year
  if ("year" %in% names(df) && !grepl("master_lookup", name)) {
    n_years <- n_distinct(df$year)
    if (n_years > 1) {
      errors[[name]] <- c(errors[[name]],
        paste0("Multiple years in file: ", paste(unique(df$year), collapse = ", ")))
    }
  }

  # Harmonised master: target-year bfs_nr column must be fully populated.
  # Column is named bfs_nr_{year}, e.g. bfs_nr_2022.
  if (grepl("master_lookup_harmonised", name)) {
    bfs_target_col <- grep("^bfs_nr_[0-9]{4}$", names(df), value = TRUE)
    if (length(bfs_target_col) == 1) {
      n_missing <- sum(is.na(df[[bfs_target_col]]))
      if (n_missing > 0) {
        errors[[name]] <- c(errors[[name]],
          paste0("Missing ", bfs_target_col, " in ", n_missing, " rows"))
      }
    }
  }

  # Master lookup: cross-canton MedStat assignments must only occur between
  # geographically adjacent cantons. Non-adjacent pairs indicate a join error.
  # Note: cross-border assignments are expected and correct -- MedStat regions
  # are hospital catchment areas that deliberately cross canton boundaries.
  # This check catches implausible long-distance mismatches.
  if (grepl("^master_lookup_[0-9]", name) && !grepl("harmonised", name) &&
      all(c("canton_abbr", "medstat_id") %in% names(df))) {
    mismatches <- df |>
      mutate(medstat_canton = substr(medstat_id, 1, 2)) |>
      filter(medstat_canton != canton_abbr) |>
      distinct(canton_abbr, medstat_canton)
    # Known adjacent canton pairs where cross-border MedStat is valid
    # (symmetric -- order does not matter)
    adjacent <- rbind(
      c("AG","ZH"), c("AG","LU"), c("AG","SO"), c("AG","BL"), c("AG","BE"),
      c("AG","BS"), c("AG","ZG"),
      c("AI","AR"), c("AI","SG"),
      c("AR","SG"),
      c("BE","LU"), c("BE","JU"), c("BE","NE"), c("BE","SO"), c("BE","FR"),
      c("BE","VD"), c("BE","VS"), c("BE","OW"), c("BE","NW"),
      c("BL","AG"), c("BL","SO"), c("BL","BS"), c("BL","JU"),
      c("BS","BL"),
      c("FR","VD"), c("FR","BE"), c("FR","NE"),
      c("GE","VD"),
      c("GL","SG"), c("GL","SZ"), c("GL","GR"), c("GL","UR"),
      c("GR","SG"), c("GR","TI"), c("GR","GL"), c("GR","UR"), c("GR","SZ"),
      c("JU","BL"), c("JU","BE"), c("JU","SO"),
      c("LU","BE"), c("LU","NW"), c("LU","OW"), c("LU","UR"), c("LU","ZG"),
      c("LU","AG"), c("LU","SO"), c("LU","SZ"),
      c("NE","BE"), c("NE","VD"), c("NE","FR"), c("NE","JU"),
      c("NW","OW"), c("NW","UR"), c("NW","LU"), c("NW","BE"),
      c("OW","LU"), c("OW","NW"), c("OW","BE"), c("OW","UR"),
      c("SG","TG"), c("SG","AR"), c("SG","AI"), c("SG","SZ"), c("SG","GL"),
      c("SG","GR"), c("SG","ZH"),
      c("SH","ZH"), c("SH","TG"),
      c("SO","BL"), c("SO","AG"), c("SO","JU"), c("SO","BE"),
      c("SZ","ZH"), c("SZ","SG"), c("SZ","ZG"), c("SZ","LU"), c("SZ","GL"),
      c("SZ","UR"), c("SZ","GR"),
      c("TG","SG"), c("TG","ZH"), c("TG","SH"),
      c("TI","GR"), c("TI","VS"), c("TI","UR"),
      c("UR","SZ"), c("UR","OW"), c("UR","NW"), c("UR","GL"), c("UR","GR"),
      c("UR","TI"), c("UR","BE"), c("UR","LU"),
      c("VD","NE"), c("VD","GE"), c("VD","FR"), c("VD","VS"),
      c("VS","VD"), c("VS","TI"), c("VS","GR"), c("VS","BE"),
      c("ZG","AG"), c("ZG","SZ"), c("ZG","LU"), c("ZG","ZH"), c("ZG","SG"),
      c("ZH","TG"), c("ZH","ZG"), c("ZH","AG"), c("ZH","SH"), c("ZH","SG")
    ) |> as.data.frame() |> setNames(c("a", "b"))
    # Make symmetric lookup
    adj_pairs <- paste(adjacent$a, adjacent$b)
    adj_pairs_rev <- paste(adjacent$b, adjacent$a)
    all_adj <- c(adj_pairs, adj_pairs_rev)

    non_adj <- mismatches |>
      mutate(pair = paste(canton_abbr, medstat_canton)) |>
      filter(!pair %in% all_adj)
    if (nrow(non_adj) > 0) {
      errors[[name]] <- c(errors[[name]],
        paste0("MedStat assigned across non-adjacent cantons: ",
               paste(paste0(non_adj$canton_abbr, "->", non_adj$medstat_canton),
                     collapse = ", ")))
    }
  }

  if (is.null(errors[[name]])) message("OK: ", name)
}

if (length(errors) > 0) {
  message("\nValidation FAILED:")
  iwalk(errors, \(errs, file) {
    message("  ", file, ":")
    walk(errs, \(e) message("    - ", e))
  })
  quit(status = 1)
} else {
  message("\nAll checks passed.")
}
